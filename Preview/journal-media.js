"use strict";

const attachmentJobs = new Set();
const imageURLs = new Map();
const mediaPrefix = "journal-media.";
const sketchPrefix = "workout-log.drawing.";
const retiredPrefix = "unused-journal-media.";
const displayPins = new Map();
const collecting = new Set();

function entryMedia(entry) {
  if (!entry) return [];
  const ids = (entry.attachments ?? []).map(item=>mediaPrefix+item.id);
  if (entry.workingSketch) ids.push(sketchPrefix+entry.workingSketch);
  return ids;
}
function notebookMedia(notebook) {
  return [...notebook.entries, ...(notebook.drafts ?? []).map(item=>item.entry)].flatMap(entryMedia);
}
// An open editor in another window can still save a conflict copy from an older record.
// Its shared lock pins those immutable images and strokes until it releases the view.
function pinMedia(id) {
  if (!navigator.locks) return ()=>{};
  let release;
  const held = new Promise(resolve=>{ release = resolve; });
  navigator.locks.request(id,{mode:"shared"},()=>held).catch(()=>{});
  return release;
}
function updateMediaPins() {
  const detail = pages.findLast(p=>p.view==="detail");
  const needed = new Set([...entryMedia(draft),...entryMedia(detail && book.entries.find(e=>e.id===detail.id))]);
  for (const [id,release] of displayPins) {
    if (!needed.has(id)) { release(); displayPins.delete(id); }
  }
  for (const id of needed) if (!displayPins.has(id)) displayPins.set(id,pinMedia(id));
}
async function collectReleasedMedia(id) {
  if (!navigator.locks || collecting.has(id)) return;
  collecting.add(id);
  try {
    await navigator.locks.request(id,()=>writeWithPreviewLock(()=>{
      if (!activeWrite) return;
      const current = readBook(currentStoredJSON());
      if (!notebookMedia(current).includes(id)) {
        if (id.startsWith(sketchPrefix)) activeWrite.cleanup.push(id);
        else activeWrite.table.delete(id);
      }
      activeWrite.table.delete(retiredPrefix+id);
    }));
  } catch { /* Retry durable removal requests on the next launch. */ }
  finally { collecting.delete(id); }
}
function retireJournalMedia(candidates) {
  // Reap only references removed by this edit. A different tab can have a photo import in flight.
  if (!candidates.length || !activeWrite) return;
  const retained = new Set(notebookMedia(book));
  for (const id of new Set(candidates)) {
    if (retained.has(id)) continue;
    activeWrite.table.put(true,retiredPrefix+id);
    void collectReleasedMedia(id);
  }
}

async function mediaDatabase() {
  const db = await openPreviewDatabase();
  if (!db) throw Error("첨부 저장소를 열 수 없어요. 이 브라우저의 사이트 저장 권한을 확인해 주세요.");
  return db;
}
async function readAttachmentBlob(id) {
  const db = await mediaDatabase();
  return new Promise((resolve,reject)=>{
    const request = db.transaction("notebooks").objectStore("notebooks").get(mediaPrefix+id);
    request.onsuccess = () => request.result instanceof Blob ? resolve(request.result) : reject(Error("첨부 파일을 찾을 수 없어요."));
    request.onerror = () => reject(request.error);
  });
}
async function stageAttachmentBlobs(items) {
  const db = await mediaDatabase();
  await new Promise((resolve,reject)=>{
    const transaction = db.transaction("notebooks","readwrite");
    const table = transaction.objectStore("notebooks");
    for (const {id,blob} of items) {
      table.add(blob,mediaPrefix+id);
      table.put(true,retiredPrefix+mediaPrefix+id);
    }
    transaction.oncomplete = resolve;
    transaction.onabort = () => reject(transaction.error);
  });
}

function attachmentSection(entry, editing) {
  const items = entry.attachments ?? [];
  if (!items.length && !editing) return "";
  const tiles = items.map(({id,kind}, i)=>{
    const name = `${kind==="drawing" ? "그림" : "사진"} ${i+1}`;
    return `<div class="attachment-tile"><button type="button" data-action="attachment-open" data-id="${esc(id)}"
      data-source="${esc(entry.id)}" aria-label="${name} 크게 보기">
      <img data-media-blob="${esc(id)}" alt=""><strong>${name}</strong></button>
      ${editing ? button("삭제","attachment-remove","quiet negative",`data-id="${esc(id)}" aria-label="${name} 삭제"`) : ""}</div>`;
  }).join("");
  const editor = editing ? `<div class="media-actions"><label class="secondary file-control">
    사진 첨부<input type="file" accept="image/*" multiple id="journal-photos" aria-label="사진 첨부"></label>
    ${tabletPreview ? button(entry.workingSketch ? "그림 이어 그리기" : "그림 그리기","drawing-open","secondary") : ""}
    </div><small data-media-status role="status">${attachmentJobs.has(entry.id) ? "첨부 저장 중…" : ""}</small>` : "";
  return `<section class="media-section" aria-label="일지 첨부"><h3>사진과 그림</h3>${editor}
    ${tiles ? `<div class="attachment-grid">${tiles}</div>` : ""}</section>`;
}
function entryForMediaRoute(parent, id, editor = draft) {
  if (parent?.view==="editor" && parent.draftID===id && editor?.id===id) return editor;
  if (parent?.view==="detail" && parent.id===id) return book.entries.find(e=>e.id===id);
}
function attachmentView() {
  const ctx = page();
  const entry = entryForMediaRoute(pages.at(-2),ctx.sourceID);
  const item = entry?.attachments?.find(a=>a.id===ctx.attachmentID);
  if (!item) return backButton()+heading("첨부 보기")+muted("이 일지에서 첨부를 찾을 수 없어요.");
  const name = item.kind==="drawing" ? "그림" : "사진";
  return backButton()+heading(name)+`<img class="attachment-full" data-media-blob="${esc(item.id)}" alt="일지에 첨부한 ${name}">`;
}
function loadMediaImages() {
  const elements = Array.from(document.querySelectorAll("img[data-media-blob]"));
  const visible = new Set(elements.map(el=>el.dataset.mediaBlob));
  for (const [id,url] of imageURLs) {
    if (!visible.has(id)) { URL.revokeObjectURL(url); imageURLs.delete(id); }
  }
  for (const image of elements) {
    const id = image.dataset.mediaBlob;
    if (imageURLs.has(id)) { image.src = imageURLs.get(id); continue; }
    readAttachmentBlob(id).then(blob=>{
      if (!image.isConnected) return;
      if (!imageURLs.has(id)) imageURLs.set(id,URL.createObjectURL(blob));
      image.src = imageURLs.get(id);
    }).catch(()=>{
      if (image.isConnected) image.alt = "첨부 이미지를 열 수 없어요.";
    });
  }
}
function removeJournalAttachment(id) {
  if (page().view!=="editor" || !draft.attachments?.some(a=>a.id===id) || !editorIsCurrent(page())) return;
  draft.attachments = draft.attachments.filter(a=>a.id!==id);
  if (persistEditor()) retireJournalMedia([mediaPrefix+id]);
  render();
}
function setMediaBusy(id, busy) {
  if (busy) attachmentJobs.add(id); else attachmentJobs.delete(id);
  if (draft?.id !== id) return;
  const status = $("[data-media-status]");
  if (status) status.textContent = busy ? "첨부 저장 중…" : "";
  for (const el of document.querySelectorAll("#journal-photos,[data-action=confirm],[data-action=drawing-open],[data-action=discard-draft]")) {
    el.disabled = busy;
  }
  updateDrawingButtons();
}
function canLeaveJournal() {
  if (!attachmentJobs.has(draft?.id)) return true;
  notify("첨부 저장이 끝나면 이동할 수 있어요.");
  return false;
}
function canvasBlob(canvas, type, quality) {
  return new Promise((resolve,reject)=>canvas.toBlob(blob=>blob ? resolve(blob) : reject(Error("이미지를 만들 수 없어요.")),type,quality));
}
async function photoBlob(file) {
  let bitmap;
  try { bitmap = await createImageBitmap(file,{imageOrientation:"from-image"}); }
  catch { throw Error("이 사진을 열 수 없어요. 브라우저가 지원하는 사진 파일을 선택해 주세요."); }
  try {
    const scale = Math.min(1,2048/Math.max(bitmap.width,bitmap.height));
    const canvas = document.createElement("canvas");
    canvas.width = Math.max(1,Math.round(bitmap.width*scale));
    canvas.height = Math.max(1,Math.round(bitmap.height*scale));
    const context = canvas.getContext("2d");
    context.fillStyle = "#fff";
    context.fillRect(0,0,canvas.width,canvas.height);
    context.drawImage(bitmap,0,0,canvas.width,canvas.height);
    return await canvasBlob(canvas,"image/jpeg",0.84);
  } finally { bitmap.close(); }
}

async function attachToJournal(ctx, kind, prepare, sketchID=null) {
  if (!ctx || ctx.view!=="editor" || ctx.draftID!==draft?.id || attachmentJobs.has(ctx.draftID)) return false;
  const id = ctx.draftID, epoch = book.previewEpoch;
  let staged = [], linked = false, returnToEditor = false;
  const releases = [];
  setMediaBusy(id,true);
  try {
    const blobs = await prepare();
    staged = blobs.map(blob=>({id:uid(),kind,blob}));
    for (const item of staged) releases.push(pinMedia(mediaPrefix+item.id));
    // Commit binary data first. Quota failure must never leave a published reference to a missing image.
    await stageAttachmentBlobs(staged);
    await writeWithPreviewLock(()=>{
      if (book.previewEpoch!==epoch || !pages.includes(ctx) || draft?.id!==id) {
        notify("원래 일지를 나가서 첨부를 취소했어요.");
        return;
      }
      if (!editorIsCurrent(ctx)) return;
      const old = draft.attachments ?? [];
      draft.attachments = old.concat(staged.map(({id,kind})=>({id,kind})));
      if (sketchID && draft.workingSketch===sketchID) delete draft.workingSketch;
      if (!persistEditor(ctx)) {
        draft.attachments = old;
        if (sketchID) draft.workingSketch = sketchID;
        return;
      }
      linked = true;
      for (const item of staged) activeWrite.table.delete(retiredPrefix+mediaPrefix+item.id);
      if (sketchID) retireJournalMedia([sketchPrefix+sketchID]);
      if (page()===ctx) render();
      else if (page().view==="journal-drawing" && kind==="drawing") returnToEditor = true;
    });
    return linked;
  } catch (error) {
    notify(error?.name==="Error" ? error.message : "첨부를 저장하지 못했어요. 브라우저의 저장 공간을 확인해 주세요.");
    return false;
  } finally {
    for (const release of releases) release();
    setMediaBusy(id,false);
    if (returnToEditor && pages.at(-2)===ctx && page().view==="journal-drawing") back();
    if (!linked && staged.length) {
      try { await writeWithPreviewLock(()=>retireJournalMedia(staged.map(a=>mediaPrefix+a.id))); }
      catch { /* A storage outage can also prevent reclamation. */ }
    }
  }
}
document.addEventListener("change",event=>{
  if (event.target.id!=="journal-photos" || page().view!=="editor") return;
  const files = [...event.target.files];
  if (!files.length) return;
  event.target.value = "";
  void attachToJournal(page(),"photo",async()=>{
    const photos = [];
    for (const file of files) photos.push(await photoBlob(file));
    return photos;
  });
});

let tabletPreview = false;
try { tabletPreview = sessionStorage.getItem("workout-log.preview-device")==="ipad"; } catch {}
function applyPreviewDevice() {
  document.body.classList.toggle("tablet-preview",tabletPreview);
  document.querySelector(".phone").setAttribute("aria-label",`운동일지 ${tabletPreview ? "iPad" : "iPhone"} 미리보기`);
  for (const device of document.querySelectorAll("[data-device]"))
    device.setAttribute("aria-pressed",String((device.dataset.device==="ipad")===tabletPreview));
}
document.addEventListener("click",event=>{
  const device = event.target.closest("[data-device]");
  if (!device) return;
  tabletPreview = device.dataset.device==="ipad";
  try { sessionStorage.setItem("workout-log.preview-device",device.dataset.device); } catch {}
  applyPreviewDevice();
  if (page().view==="editor") render();
});
applyPreviewDevice();
function mountJournalMedia() {
  updateMediaPins();
  loadMediaImages();
  mountJournalDrawing();
  if (draft && attachmentJobs.has(draft.id)) setMediaBusy(draft.id,true);
}

// A process may close during image import or while a different editor still holds the last pin.
openPreviewDatabase().then(db=>{
  if (!db) return;
  const range = IDBKeyRange.bound(retiredPrefix,retiredPrefix+"\uffff");
  const request = db.transaction("notebooks").objectStore("notebooks").getAllKeys(range);
  request.onsuccess = () => { for (const key of request.result) void collectReleasedMedia(key.slice(retiredPrefix.length)); };
}).catch(()=>{});
