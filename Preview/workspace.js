"use strict";

const liveEditors = new Map();
const editorBases = new Map();
const unsavedForms = new Map();
const sameValue = (a,b) => JSON.stringify(a) === JSON.stringify(b);
// Merge independent writes from two windows. Conflicting edits stay open for the user.
function mergeBook(base, next, current) {
  const result = structuredClone(current);
  function changed(old, value, other) {
    if (!sameValue(old, other) && !sameValue(value, other)) throw Error("다른 창에서 같은 내용을 수정했어요. 입력값을 확인해 주세요.");
    return value;
  }
  for (const key of new Set([...Object.keys(base), ...Object.keys(next)])) {
    if (sameValue(base[key], next[key])) continue;
    if (["drafts","entries","routines","goals","skillGoals","coachTurns"].includes(key)) {
      const list = new Map((current[key] ?? []).map(item=>[item.id,item]));
      const before = new Map((base[key] ?? []).map(item=>[item.id,item]));
      const after = new Map((next[key] ?? []).map(item=>[item.id,item]));
      for (const id of new Set([...before.keys(), ...after.keys()])) {
        if (sameValue(before.get(id), after.get(id))) continue;
        changed(before.get(id), after.get(id), list.get(id));
        if (after.has(id)) list.set(id, after.get(id)); else list.delete(id);
      }
      result[key] = [...list.values()];
      if (key === "drafts") result[key].sort((a,b)=>b.updated-a.updated);
    } else if (["formInputs","pins"].includes(key)) {
      const fields = Object.assign(Object.create(null), current[key]);
      for (const name of new Set([...Object.keys(base[key] ?? {}), ...Object.keys(next[key] ?? {})])) {
        const old = base[key]?.[name], value = next[key]?.[name];
        if (sameValue(old,value)) continue;
        changed(old,value,fields[name]);
        if (value === undefined) delete fields[name]; else fields[name] = value;
      }
      result[key] = fields;
    } else { result[key] = changed(base[key],next[key],current[key]); }
  }
  return result;
}

function editorSnapshot(ctx, entry) {
  return {id:entry.id, view:ctx.view, entry:structuredClone(entry), editing:!!ctx.editing,
    routineID:ctx.id ?? null, routineName:ctx.routineName ?? "", parentID:ctx.parentID ?? null,
    defaultUnits:entry.exercises.map(ex=>rowsWithDefaultUnit.has(ex)),
    sideInputs:entry.exercises.map(ex=>rowsWithSideInput.has(ex))};
}
function installEditor(item) {
  draft = structuredClone(item.entry);
  draft.exercises.forEach((ex,i)=>{
    if (item.defaultUnits?.[i]) rowsWithDefaultUnit.add(ex);
    if (item.sideInputs?.[i]) rowsWithSideInput.add(ex);
  });
  const {updated, ...snapshot} = item;
  liveEditors.set(item.id,snapshot);
  const source = item.editing ? book.entries.find(e=>e.id===item.id) : item.routineID ? findRoutine(book,item.routineID) : undefined;
  editorBases.set(item.id, {draft:book.drafts?.find(d=>d.id===item.id),source,epoch:book.previewEpoch});
}
function beginEditor(view, entry, options = {}, saved = null) {
  if (!flushWorkspace()) return;
  if (view === "routine-editor" && !persistEditor(page(),true)) return;
  const item = saved ?? editorSnapshot({view,...options},entry);
  installEditor(item);
  go(item.view,{draftID:item.id, editing:item.editing, id:item.routineID, routineName:item.routineName, parentID:item.parentID});
}
function persistEditor(ctx = page(), keepInitial = false) {
  if (!draft || ctx.draftID !== draft.id) return true;
  const item = editorSnapshot(ctx,draft);
  if (sameValue(liveEditors.get(item.id),item) &&
      (!keepInitial || book.drafts?.some(d => d.id === item.id))) return true;
  if (!editorIsCurrent(ctx)) return false;
  const next = structuredClone(book);
  next.drafts = [{...item,updated:Date.now()}, ...(next.drafts ?? []).filter(d=>d.id!==item.id)];
  if (!save(next)) return false;
  liveEditors.set(item.id,item);
  editorBases.get(item.id).draft = book.drafts.find(d=>d.id===item.id);
  return true;
}
function editorIsCurrent(ctx) {
  const base = editorBases.get(ctx.draftID);
  if (!base) return true;
  try {
    const raw = currentStoredJSON();
    const current = raw === storedJSON ? book : readBook(raw);
    const source = ctx.editing ? current.entries.find(e=>e.id===ctx.draftID) : ctx.id ? findRoutine(current,ctx.id) : undefined;
    if (base.epoch === current.previewEpoch && sameValue(base.draft,current.drafts?.find(d=>d.id===ctx.draftID)) && sameValue(base.source,source)) return true;
  } catch { notify("브라우저 저장소를 읽을 수 없어요. 입력을 유지하고 있어요."); return false; }
  notify("다른 창에서 이 기록이 바뀌었어요. 내 입력을 별도 초안으로 보관할 수 있어요.");
  clearTimeout(noticeTimer);
  $("#notice").insertAdjacentHTML("beforeend",button("새 초안으로 보관","copy-conflict","quiet"));
  return false;
}
function keepConflictCopy() {
  const owner = pages.findLastIndex(ctx=>ctx.draftID);
  if (!draft || owner < 0) return;
  const ctx = pages[owner], item = editorSnapshot(ctx,draft);
  const oldID = item.id;
  item.id = uid();
  item.entry.id = item.id;
  item.editing = false;
  item.routineID = null;
  if (!refreshBook()) return;
  const next = structuredClone(book);
  next.drafts = [{...item,updated:Date.now()}, ...(next.drafts ?? [])];
  if (!save(next)) return;
  liveEditors.delete(oldID);
  editorBases.delete(oldID);
  installEditor(item);
  pages = [...pages.slice(0,owner),{...ctx,draftID:item.id,id:null,editing:false}];
  saveRoute(true); render(true); notify("내 입력을 별도 초안에 보관했어요.");
}
function finishEditor(next, id) {
  if (!editorIsCurrent(page())) return false;
  next.drafts = (next.drafts ?? []).filter(item=>item.id!==id);
  if (!save(next)) return false;
  liveEditors.delete(id);
  editorBases.delete(id);
  draft = null;
  return true;
}
function resumeEditor(id) {
  const item = book.drafts?.find(d=>d.id===id);
  if (item) beginEditor(item.view,item.entry,{},item);
}
function draftSummary(entry) {
  const exercise = entry.kind === "rest" ? null : entry.exercises[0];
  const first = exercise?.sets[0];
  const weight = String(first?.kg ?? "").trim();
  const amount = String(first?.amount ?? "").trim();
  const measures = [weight && weight+" kg", amount && amount+(exercise?.unit ?? "")].filter(Boolean);
  const note = (entry.note || exercise?.note || entry.before || "").trim();
  const characters = Array.from(note);
  if (characters.length) measures.push(characters.slice(0,48).join("")+(characters.length>48 ? "…" : ""));
  return measures.join(" · ");
}
function draftShelf() {
  const pending = book.drafts ?? [];
  if (!pending.length) return "";
  return "<h3>작성 중</h3>"+pending.map(item=>{
    const routine = item.view === "routine-editor";
    const name = routine ? item.routineName || "새 루틴" : title(item.entry) || kinds[item.entry.kind]+" 기록";
    const detail = draftSummary(item.entry);
    return '<button type="button" class="row draft-row" data-action="resume-draft" data-id="'+esc(item.id)+'"><span class="row-text"><strong>'
      +esc((routine ? "루틴 · " : "일지 · ")+name)+'</strong>'
      +(detail ? '<small>'+esc(detail)+'</small>' : '')+'</span><span class="arrow" aria-hidden="true">›</span></button>';
  }).join("")+button("새 운동 기록 시작","fresh","quiet");
}
function saveRoute(replace = false) {
  const routes = pages.map(({text,...ctx})=>ctx);
  history[replace ? "replaceState" : "pushState"]({workoutRoutes:routes, epoch:book.previewEpoch},"");
}
function restoreRoutes(routes) {
  const valid = [];
  let item;
  for (const ctx of routes ?? []) {
    if (ctx.draftID) {
      item = book.drafts?.find(d=>d.id===ctx.draftID) ?? liveEditors.get(ctx.draftID);
      if (!item) break;
    }
    if ((["detail","skill-new"].includes(ctx.view) || ctx.purpose === "follow") && !book.entries.some(e=>e.id===ctx.id)) break;
    if (ctx.view === "goal-detail" && !book.goals.some(g=>g.id===ctx.id)) break;
    if (ctx.view === "skill-detail" && !book.skillGoals?.some(g=>g.id===ctx.id)) break;
    if (ctx.purpose === "follow") ctx.text = book.entries.find(e=>e.id===ctx.id)?.followUp ?? "";
    if (ctx.purpose === "pin") ctx.text = Object.hasOwn(book.pins,clean(ctx.name)) ? book.pins[clean(ctx.name)] : "";
    if (ctx.purpose === "reflection") ctx.text = book.reflection;
    valid.push({...ctx, ...(ctx.draftID ? {routineName:item.routineName} : {})});
  }
  pages = valid.length ? valid : [{view:"today"}];
  const owner = pages.findLast(ctx=>ctx.draftID);
  if (owner) installEditor(book.drafts?.find(d=>d.id===owner.draftID) ?? liveEditors.get(owner.draftID));
  else draft = null;
}
function formKey(id, ctx = page()) {
  if (id === "coach-input") return "chat-"+athlete().animal;
  if (id === "note-text") return ctx.purpose+"-"+(ctx.id ?? ctx.name ?? "");
  if (id === "skill-target") return id+"-"+ctx.id+"-"+ctx.ex;
  return ["goal-name","goal-target"].includes(id) ? id : null;
}
function formText(id, fallback = "") { return unsavedForms.get(formKey(id)) ?? book.formInputs?.[formKey(id)] ?? fallback; }
function rememberForm(id, text) {
  const key = formKey(id);
  if (!key) return false;
  unsavedForms.set(key,text);
  flushForms();
  return true;
}
function flushForms() {
  if (!unsavedForms.size) return true;
  const next = structuredClone(book);
  for (const [key,text] of unsavedForms) (next.formInputs ??= {})[key] = text;
  if (!save(next)) return false;
  unsavedForms.clear();
  return true;
}
function flushWorkspace() { return persistEditor() && flushForms(); }
function clearForm(next,...ids) {
  if (next.formInputs) for (const id of ids) delete next.formInputs[formKey(id)];
}
