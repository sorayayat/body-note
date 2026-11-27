"use strict";

const queuedEvents = new Set();
let database;
let activeWrite;
let settlingWrite;
let singleWindowFallback = false;
let fallbackBase;
let fallbackKey;

function openPreviewDatabase() {
  if (database) return database;
  database = new Promise(resolve=>{
    try {
      const request = indexedDB.open("workout-log-preview",1);
      request.onupgradeneeded = () => request.result.createObjectStore("notebooks");
      request.onsuccess = () => resolve(request.result);
      request.onerror = () => resolve(null);
      request.onblocked = () => resolve(null);
    } catch { resolve(null); }
  });
  return database;
}
function currentStoredJSON() {
  return activeWrite ? activeWrite.raw : localStorage.getItem(key);
}
function writeSnapshot(encoded) {
  if (singleWindowFallback && !activeWrite) {
    fallbackBase ??= book;
    fallbackKey ??= pendingKey();
    const previous = localStorage.getItem(fallbackKey);
    saveInterrupted(fallbackBase,JSON.parse(encoded),fallbackKey);
    try { localStorage.setItem(key,encoded); }
    catch (error) {
      if (previous === null) localStorage.removeItem(fallbackKey);
      else localStorage.setItem(fallbackKey,previous);
      throw error;
    }
  } else { localStorage.setItem(key,encoded); }
  if (!activeWrite) return;
  activeWrite.raw = encoded;
  activeWrite.table.put({raw:encoded, recovered:activeWrite.recovered},key);
}

// A tab may close before its queued input or the final transaction settles.
// Save only changed notebook fields under a unique key until the next transaction.
function pendingKey() { return key+".pending."+Date.now()+"."+uid(); }
function saveInterrupted(base, next, id) {
  if (sameValue(base,next)) { if (id) localStorage.removeItem(id); return; }
  const before = {}, after = {};
  for (const k of new Set([...Object.keys(base),...Object.keys(next)])) {
    if (sameValue(base[k],next[k])) continue;
    if (Array.isArray(base[k]) || Array.isArray(next[k])) {
      const a = new Map((base[k] ?? []).map(row=>[row.id,row]));
      const b = new Map((next[k] ?? []).map(row=>[row.id,row]));
      before[k] = [...a.values()].filter(row=>!sameValue(row,b.get(row.id)));
      after[k] = [...b.values()].filter(row=>!sameValue(row,a.get(row.id)));
    } else {
      before[k] = base[k];
      after[k] = next[k];
    }
  }
  localStorage.setItem(id ?? pendingKey(),JSON.stringify({epoch:base.previewEpoch,before,after}));
}
function recoverInterrupted(write) {
  const pending = Object.keys(localStorage).filter(k=>k.startsWith(key+".pending.")).sort();
  if (!pending.length || !canPersist) return;
  let current = readBook(write.raw);
  for (const id of pending) {
    if (write.recovered.includes(id)) { write.cleanup.push(id); continue; }
    let data;
    try { data = JSON.parse(localStorage.getItem(id)); }
    catch { continue; }
    if (!data?.before || !data.after) continue;
    if (data.epoch === current.previewEpoch) {
      try { current = mergeBook(data.before,data.after,current); }
      catch {
        // A closing editor may conflict with a newer edit from another tab.
        // Preserve its exercise fields in a separate, unconfirmed journal or routine.
        const copies = (data.after.drafts ?? []).map(item=>{
          const nextID = uid();
          return {...item,id:nextID,entry:{...item.entry,id:nextID},editing:false,routineID:null};
        });
        if (!copies.length) continue;
        current.drafts = [...copies,...(current.drafts ?? [])];
      }
    }
    write.recovered.push(id);
    write.cleanup.push(id);
  }
  if (write.cleanup.length) writeSnapshot(JSON.stringify(current));
}

// Read the current revision inside a readwrite transaction. Separate file://
// renderers may briefly see different localStorage values even with Web Locks.
async function coordinateWrite(run) {
  const db = await openPreviewDatabase();
  if (!db) {
    singleWindowFallback = true;
    $("#storage-state").textContent = "브라우저의 동시 쓰기 저장소가 꺼져 있어요. 한 창에서 작성해 주세요.";
    run(); return;
  }
  await new Promise((resolve,reject)=>{
    const transaction = db.transaction("notebooks","readwrite");
    const table = transaction.objectStore("notebooks");
    const request = table.get(key);
    let write;
    request.onsuccess = () => {
      try {
        const saved = request.result;
        const raw = typeof saved === "string" ? saved : saved?.raw ?? localStorage.getItem(key);
        write = {table,raw,recovered:(saved?.recovered ?? []).slice(-64),cleanup:[], start:book};
        activeWrite = settlingWrite = write;
        recoverInterrupted(write);
        run();
      } catch (error) { transaction.abort(); reject(error); }
      finally { activeWrite = null; }
    };
    transaction.oncomplete = () => {
      if (settlingWrite === write) settlingWrite = null;
      try { for (const id of write?.cleanup ?? []) localStorage.removeItem(id); }
      finally { resolve(); }
    };
    transaction.onabort = () => {
      if (settlingWrite === write) settlingWrite = null;
      try { if (write) saveInterrupted(write.start,book); }
      finally { reject(transaction.error ?? Error("저장 트랜잭션이 중단됐어요.")); }
    };
  });
}

// Chromium coordinates writes from every preview window for this origin. A closing
// tab drains already-delivered input events before the browser releases the document.
function writeWithPreviewLock(run) {
  const commit = () => coordinateWrite(run);
  return globalThis.navigator?.locks
    ? navigator.locks.request("workout-log-preview",commit).catch(error=>{
      if (error.name === "SecurityError" || error.name === "NotSupportedError") return commit();
      throw error;
    }) : commit();
}
function listenToWrites(target, type, handler, capture = event=>event.target?.value) {
  target.addEventListener(type,event=>{
    const value = capture(event);
    const run = () => { if (queuedEvents.delete(run)) handler(event,value); };
    queuedEvents.add(run);
    writeWithPreviewLock(run).catch(error=>{ console.error(error); notify("저장 처리가 중단됐어요. 브라우저 저장 공간을 확인해 주세요."); });
  });
}
