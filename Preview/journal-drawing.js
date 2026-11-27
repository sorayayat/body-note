"use strict";

let inkSession;
function drawingView() {
  return backButton()+heading("그림 그리기")
    + '<div class="drawing-tools"><label>펜 색상 <input type="color" id="ink-color" value="#174e41"></label>'
    + button("되돌리기","drawing-undo","secondary")+'</div>'
    + '<canvas id="journal-ink" width="1024" height="768" aria-label="일지 그림 캔버스"></canvas>'
    + '<p id="drawing-status" class="muted" role="status"></p>'
    + button("일지에 첨부","drawing-attach","primary wide");
}
function paintStroke(context, stroke) {
  const p = stroke.points;
  context.fillStyle = context.strokeStyle = stroke.color;
  context.lineWidth = 4;
  context.lineCap = context.lineJoin = "round";
  if (p.length===2) {
    context.beginPath(); context.arc(p[0],p[1],2,0,Math.PI*2); context.fill();
    return;
  }
  context.beginPath(); context.moveTo(p[0],p[1]);
  for (let i=2;i<p.length;i+=2) context.lineTo(p[i],p[i+1]);
  context.stroke();
}
function paintJournalDrawing(session) {
  const {canvas,strokes} = session, context = canvas.getContext("2d");
  context.fillStyle = "#fff";
  context.fillRect(0,0,canvas.width,canvas.height);
  for (const stroke of strokes) paintStroke(context,stroke);
}
function updateDrawingButtons() {
  if (!inkSession?.canvas.isConnected) return;
  const busy = attachmentJobs.has(inkSession.entry.id);
  const disabled = busy || !!inkSession.readError || !inkSession.strokes.length;
  $("[data-action=drawing-undo]").disabled = disabled;
  $("[data-action=drawing-attach]").disabled = disabled;
  $("#drawing-status").textContent = inkSession.readError || (busy ? "그림을 첨부하는 중…" :
    inkSession.unsaved ? "그림 초안을 저장하지 못했어요. 저장 공간을 확인해 주세요." :
    inkSession.strokes.length ? "그림 초안을 저장했어요." : "");
}
function saveSketch(session) {
  const previous = session.entry.workingSketch;
  const next = session.strokes.length ? uid() : null;
  try {
    // The editable strokes are small normalized coordinates. Write them before the reference so
    // even closing/reloading immediately after pointer-up keeps the most recent pen stroke.
    if (next) localStorage.setItem(sketchPrefix+next,JSON.stringify(session.strokes));
  } catch {
    session.unsaved = true;
    updateDrawingButtons();
    return false;
  }
  if (next) session.entry.workingSketch = next;
  else delete session.entry.workingSketch;
  session.unsaved = false;
  window.dispatchEvent(new CustomEvent("journal-sketch-save",{detail:{session,previous}}));
  updateDrawingButtons();
  return true;
}
listenToWrites(window,"journal-sketch-save",(_event,{session,previous})=>{
  if (draft===session.entry && pages.includes(session.parent) && persistEditor(session.parent)) {
    if (previous) retireJournalMedia([sketchPrefix+previous]);
    updateMediaPins();
  }
},event=>event.detail);
function finishActiveStroke() {
  const session = inkSession;
  if (session?.pointer == null) return;
  session.pointer = null;
  saveSketch(session);
}
function flushJournalDrawing() {
  if (!inkSession || !inkSession.canvas.isConnected) return true;
  finishActiveStroke();
  return !inkSession.unsaved || saveSketch(inkSession);
}
function mountJournalDrawing() {
  const canvas = $("#journal-ink");
  if (!canvas) { inkSession = null; return; }
  const session = {canvas,entry:draft,parent:pages.at(-2),pointer:null,strokes:[],unsaved:false};
  inkSession = session;
  if (draft.workingSketch) {
    try {
      const raw = localStorage.getItem(sketchPrefix+draft.workingSketch);
      const strokes = raw && JSON.parse(raw);
      if (!Array.isArray(strokes) || !strokes.every(s=>Array.isArray(s?.points) && s.points.length>=2 && s.points.length%2===0)) throw Error();
      session.strokes = strokes;
      if (strokes.length) $("#ink-color").value = strokes.at(-1).color;
    } catch { session.readError = "그림 초안을 열 수 없어요. 뒤로 가서 다시 열어 주세요."; }
  }
  paintJournalDrawing(session);
  updateDrawingButtons();
  function appendPoint(event) {
    const r = canvas.getBoundingClientRect(), points = session.strokes.at(-1).points;
    const x = Math.round(Math.max(0,Math.min(canvas.width,(event.clientX-r.left)*canvas.width/r.width)));
    const y = Math.round(Math.max(0,Math.min(canvas.height,(event.clientY-r.top)*canvas.height/r.height)));
    if (points.length<2 || points.at(-2)!==x || points.at(-1)!==y) points.push(x,y);
  }
  canvas.addEventListener("pointerdown",e=>{
    if (e.button!==0 || session.pointer!=null || session.readError || attachmentJobs.has(draft.id)) return;
    e.preventDefault();
    session.pointer = e.pointerId;
    canvas.setPointerCapture(e.pointerId);
    session.strokes.push({color:$("#ink-color").value,points:[]});
    appendPoint(e);
    paintStroke(canvas.getContext("2d"),session.strokes.at(-1));
  });
  canvas.addEventListener("pointermove",e=>{
    if (session.pointer!==e.pointerId) return;
    const stroke = session.strokes.at(-1), start = stroke.points.length-2;
    for (const point of e.getCoalescedEvents?.() ?? []) appendPoint(point);
    appendPoint(e);
    paintStroke(canvas.getContext("2d"),{color:stroke.color,points:stroke.points.slice(start)});
  });
  canvas.addEventListener("pointerup",e=>{
    if (session.pointer!==e.pointerId) return;
    appendPoint(e);
    finishActiveStroke();
    paintJournalDrawing(session);
  });
  canvas.addEventListener("lostpointercapture",e=>{
    if (session.pointer===e.pointerId) finishActiveStroke();
  });
}
function undoJournalStroke() {
  if (!inkSession?.strokes.length || attachmentJobs.has(inkSession.entry.id)) return;
  finishActiveStroke();
  inkSession.strokes.pop();
  paintJournalDrawing(inkSession);
  saveSketch(inkSession);
}
function attachJournalDrawing() {
  if (!inkSession?.strokes.length || inkSession.readError) return;
  finishActiveStroke();
  const {parent,canvas,entry} = inkSession;
  void attachToJournal(parent,"drawing",async()=>[await canvasBlob(canvas,"image/png")],entry.workingSketch);
}
