"use strict";

function copyExercises(source) {
  return structuredClone(source).map(exercise => {
    exercise.note = "";
    if (exercise.drill) {
      const running = exercise.drill.sport === "running";
      exercise.unit = running ? "m" : "회";
      const amount = running ? exercise.drill.meters : exercise.drill.attempts;
      exercise.sets = [{ amount: amount ?? 1, kg: "", side: "구분 없음" }];
      delete exercise.drill;
    }
    delete exercise.id;
    for (const set of exercise.sets) delete set.id;
    return exercise;
  });
}

// Journal and routine saves both validate a private copy before persisting it.
function normalizeExercises(exercises, original) {
  if (!exercises.length) throw Error("운동을 추가해 주세요.");
  for (const ex of exercises) {
    ex.name = ex.name.trim();
    if (!ex.name) throw Error("운동 이름을 입력해 주세요.");
    if (ex.drill) {
      const saved = original?.exercises.find(item => item.id === ex.id);
      if (!saved?.drill || JSON.stringify(saved.drill) !== JSON.stringify(ex.drill)) {
        throw Error("이전 종목의 상세 수치는 원래 일지에서 확인할 수 있어요.");
      }
      continue;
    }
    if (!ex.sets.length) throw Error("각 운동에 세트를 추가해 주세요.");
    if (ex.restSeconds != null && ex.restSeconds !== "") {
      ex.restSeconds = wholeNumber(ex.restSeconds);
      if (ex.restSeconds === null) throw Error("세트 간 휴식은 0초 이상의 정수로 입력해 주세요.");
    } else { delete ex.restSeconds; }
    for (const set of ex.sets) {
      const kg = String(set.kg ?? "").replace(",", ".");
      const amount = String(set.amount ?? "");
      if (!/^\d+$/.test(amount) || !Number.isSafeInteger(+amount) || +amount <= 0 ||
          (kg !== "" && (!/^(?:\d+(?:\.\d*)?|\.\d+)$/.test(kg) || !Number.isFinite(+kg)))) {
        throw Error("세트의 수행량과 중량을 확인해 주세요.");
      }
      set.amount = +set.amount;
      set.kg = kg === "" ? "" : +kg;
    }
  }
}

function findRoutine(notebook, id) {
  return notebook.routines?.find(routine => routine.id === id);
}

function saveRoutine(notebook, name, entry, id = null) {
  const title = name.trim();
  if (!title) throw Error("루틴 이름을 입력해 주세요.");
  if (entry.kind !== "training" && entry.kind !== "rehab") throw Error("훈련 또는 재활 동작을 루틴으로 저장해 주세요.");
  const exercises = copyExercises(entry.exercises);
  normalizeExercises(exercises);
  const list = notebook.routines ?? [];
  const routine = { id: id ?? uid(), name: title, kind: entry.kind, exercises };
  if (id !== null) {
    const index = list.findIndex(item => item.id === id);
    if (index < 0) throw Error("해당 루틴을 찾을 수 없어요.");
    list[index] = routine;
  } else {
    if (list.length === 0) notebook.defaultRoutineID = routine.id;
    list.push(routine);
  }
  notebook.routines = list;
}

function deleteRoutine(notebook, id) {
  notebook.routines = (notebook.routines ?? []).filter(item => item.id !== id);
  if (notebook.drafts) notebook.drafts = notebook.drafts.filter(item=>item.view !== "routine-editor" || item.routineID !== id);
  if (notebook.defaultRoutineID === id) notebook.defaultRoutineID = null;
}

function startRoutineEntry(routine) {
  const entry = newEntry(routine?.kind ?? "training");
  entry.recordedAthlete = athlete();
  if (routine) entry.exercises = copyExercises(routine.exercises);
  beginEditor("editor", entry, { routineName: routine?.name });
}

function openRoutineEditor(routine, entry) {
  const parentID = entry?.id ?? null, id = routine?.id ?? null;
  const pending = book.drafts?.find(item=>item.view === "routine-editor" && item.routineID === id && item.parentID === parentID);
  if (pending) return resumeEditor(pending.id);
  const source = routine ?? entry;
  const template = newEntry(source?.kind ?? "training");
  if (source) template.exercises = copyExercises(source.exercises);
  const name = routine?.name ?? (entry ? title(entry) : "");
  beginEditor("routine-editor", template, { id, routineName:name, parentID });
}

function routineListView() {
  const routines = book.routines ?? [];
  let html = backButton() + heading("내 루틴") + button("＋ 루틴 만들기", "routine-new", "primary wide");
  if (!routines.length) return html + muted("자주 하는 동작과 세트를 저장해 두면 새 일지를 열 때 바로 불러와요.");
  html += button("빈 기록으로 시작", "routine-blank", "secondary wide");
  for (const routine of routines) {
    const active = routine.id === book.defaultRoutineID;
    const ref = `data-id="${esc(routine.id)}"`;
    const summary = routine.exercises.map(ex => ex.name + " " + ex.sets.length + "세트").join(" · ");
    html += `<article class="card routine-card"><small>${active ? "기본 루틴 · " : ""}${esc(kinds[routine.kind])}</small>
      <h3>${esc(routine.name)}</h3>${muted(summary)}<div class="routine-actions">
      ${button("이 루틴으로 기록", "routine-start", "secondary", ref)}${button("루틴 편집", "routine-edit", "quiet", ref)}
      ${button(active ? "기본 루틴 해제" : "기본 루틴으로 지정", "routine-default", "quiet", ref)}</div></article>`;
  }
  return html;
}

function routineEditorView() {
  const ctx = page();
  return backButton() + heading(ctx.id ? "루틴 편집" : "루틴 만들기")
    + `<label class="field">루틴 이름<input id="routine-name" value="${esc(ctx.routineName)}"></label>`
    + segments([["training", "훈련"], ["rehab", "재활"]], draft.kind, "kind")
    + (book.routines?.length ? "" : muted("첫 루틴은 오늘의 기록을 열 때 자동으로 불러와요."))
    + draft.exercises.map(editMovement).join("") + button("＋ 운동 추가", "ex-add", "secondary wide")
    + button("루틴 저장", "routine-save", "primary wide")
    + discardButton()
    + (ctx.id ? button("루틴 삭제", "routine-delete", "quiet negative wide", `data-id="${esc(ctx.id)}"`) : "");
}
