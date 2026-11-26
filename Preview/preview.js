"use strict";

const $ = (selector) => document.querySelector(selector);
const key = "body-note-demo.v1";
const kinds = { training: "훈련", rehab: "재활", rest: "휴식" };
const amountLabels = { "회": "횟수 (회)", "초": "시간 (초)", "분": "시간 (분)", "m": "거리 (m)" };
const sides = ["구분 없음", "왼쪽", "오른쪽", "양쪽"];
const rowsWithDefaultUnit = new WeakSet();
const rowsWithSideInput = new WeakSet();
const uid = () => crypto.randomUUID();
const esc = (s) => String(s ?? "").replace(/[&<>"']/g, (c) =>
  ({ "&": "&amp;", "<": "&lt;", ">": "&gt;", '"': "&quot;", "'": "&#39;" })[c]);

function dayKey(date = new Date()) {
  const two = (n) => String(n).padStart(2, "0");
  return `${date.getFullYear()}-${two(date.getMonth() + 1)}-${two(date.getDate())}`;
}
function dayLabel(key) {
  const [year, month, day] = key.split("-").map(Number);
  return `${year}년 ${month}월 ${day}일`;
}
function movement(name = "") {
  const exercise = { name, unit: "회", equipment: "", note: "", sets: [{ amount: 10, kg: "", side: "구분 없음" }] };
  if (!name) rowsWithDefaultUnit.add(exercise);
  return exercise;
}
function newEntry(kind = "training") {
  return { id: uid(), day: dayKey(), time: Date.now(), kind, exercises: [movement()],
    before: "", after: "", effort: "", note: "", followUp: "" };
}
function emptyBook() { return { entries: [], pins: {}, goals: [], reflection: "" }; }
function sampleBook() {
  const data = emptyBook();
  const rehab = newEntry("rehab"), training = newEntry();
  const animal = athlete().animal;
  rehab.recordedAthlete = { animal, sport: "basic" };
  training.recordedAthlete = { animal, sport: "weightTraining" };
  for (const [entry, offset] of [[rehab, 3], [training, 1]]) {
    const date = new Date();
    date.setDate(date.getDate() - offset);
    entry.day = dayKey(date);
    entry.time = date.getTime();
  }
  const band = movement("밴드 외회전");
  band.equipment = "노란 밴드";
  band.sets = [{ amount: 8, kg: "", side: "왼쪽" }, { amount: 10, kg: "", side: "오른쪽" }];
  rehab.exercises = [band];
  rehab.followUp = "아침에 느낀 점을 남겼어요.";
  training.exercises = [movement("케이블 로우")];
  training.exercises[0].sets = [
    { amount: 12, kg: 20, side: "구분 없음" },
    { amount: 10, kg: 22.5, side: "구분 없음" },
    { amount: 8, kg: 25, side: "구분 없음" }
  ];
  training.exercises[0].note = "마지막 세트가 조금 힘들었다.";
  training.exercises[0].restSeconds = 60;
  const recentBand = structuredClone(band);
  recentBand.sets[0].amount = 10;
  training.exercises.push(recentBand);
  data.pins["케이블 로우"] = "기구 좌석 4칸";
  data.entries = [rehab, training];
  return data;
}

let canPersist = true;
let storedJSON = null;
function readBook(raw) {
  if (raw === null) return emptyBook();
  const saved = JSON.parse(raw);
  if (!Array.isArray(saved.entries) || !Array.isArray(saved.goals) || !saved.pins) throw Error("일지 파일을 읽을 수 없어요.");
  if (saved.athlete) saved.athlete = athlete(saved);
  const fallback = athlete(saved);
  for (const entry of saved.entries) {
    if (entry.kind !== "rest" && !entry.recordedAthlete) entry.recordedAthlete = recordAppearance(entry, fallback);
    entry.exercises.forEach((ex,i) => { if (ex.drill && !ex.id) ex.id = entry.id+"-drill-"+i; });
  }
  return saved;
}
function loadBook() {
  try {
    storedJSON = localStorage.getItem(key);
    return readBook(storedJSON);
  } catch {
    canPersist = false;
    $("#storage-state").textContent = "브라우저 저장소를 열 수 없어요. 기존 저장 내용을 확인해 주세요.";
  }
  return emptyBook();
}
let book = loadBook();
let pages = [{ view: "today" }];
let journalFilter = "전체";
let calendarDate = dayKey();
let draft = null;
let noticeTimer;

function refreshBook() {
  try {
    if (!canPersist) readBook(localStorage.getItem(key));
    const raw = currentStoredJSON();
    if (canPersist && raw === storedJSON) return true;
    const current = readBook(raw);
    storedJSON = raw;
    book = current;
    canPersist = true;
    $("#storage-state").textContent = "이 시안의 기록은 이 브라우저에 저장돼요.";
    return true;
  } catch {
    canPersist = false;
    notify("저장소를 열 수 없어요. 기존 내용을 확인해 주세요.");
    return false;
  }
}
function save(next, replace = false) {
  if (!canPersist && !replace) { notify("브라우저 저장소를 열 수 없어요. 입력은 현재 화면에 남아 있어요."); return false; }
  try {
    const raw = currentStoredJSON();
    if (!replace) {
      const mirror = localStorage.getItem(key);
      if (mirror !== storedJSON && mirror !== raw) readBook(mirror);
    }
    if (!replace && raw !== storedJSON) {
      const current = readBook(raw);
      if (current.previewEpoch !== book.previewEpoch) throw Error("다른 창에서 미리보기 데이터를 바꿨어요. 최신 일지를 확인해 주세요.");
      next = mergeBook(book,next,current);
    }
    const encoded = JSON.stringify(next);
    writeSnapshot(encoded);
    storedJSON = encoded;
    book = next;
    if (!canPersist) $("#storage-state").textContent = "이 시안의 기록은 이 브라우저에 저장돼요.";
    canPersist = true;
    return true;
  } catch (error) {
    notify(error.name === "Error" ? error.message : "저장에 실패했어요. 입력을 유지하고 있어요. 브라우저 저장 공간을 확인해 주세요.");
    return false;
  }
}
function notify(text) {
  clearTimeout(noticeTimer);
  $("#notice").hidden = false;
  $("#notice").textContent = text;
  noticeTimer = setTimeout(() => { $("#notice").hidden = true; }, 4500);
}
function page() { return pages[pages.length - 1]; }
function go(view, options = {}) {
  if (!flushWorkspace()) return;
  if (["library","routine-editor"].includes(view) && !persistEditor(page(),true)) return;
  saveRoute(true);
  pages.push({ view, ...options }); saveRoute(); render(true);
}
function home(tab, replace = false) {
  if (!flushWorkspace()) return;
  refreshBook();
  if (pages.length === 1 && page().view === tab) return render(true);
  draft = null; pages = [{ view: tab }]; saveRoute(replace); render(true);
}
function back(levels = 1) {
  if (!flushWorkspace()) return;
  const distance = Math.min(levels,pages.length - 1);
  if (distance > 0) history.go(-distance);
}
function restoreNavigation(state) {
  const routes = state?.epoch === book.previewEpoch ? state?.workoutRoutes : null;
  restoreRoutes(routes);
  saveRoute(true);
  render(true);
}
function latest() { return [...book.entries].reverse().sort((a, b) => b.time - a.time); }
function title(entry) {
  if (entry.kind === "rest") return "휴식 기록";
  return entry.exercises[0].name + (entry.exercises.length > 1 ? ` 외 ${entry.exercises.length - 1}개` : "");
}
function stats() {
  const days = new Set(book.entries.filter((e) => e.kind !== "rest").map((e) => e.day)).size;
  const xp = days * 10;
  return { days, xp, level: 1 + Math.floor(xp / xpPerLevel), matArea: days >= 6 && !!book.reflection };
}
function button(label, action, cls = "secondary", attrs = "") {
  return `<button type="button" class="${cls}" data-action="${action}" ${attrs}>${esc(label)}</button>`;
}
function backButton() { return button("‹ 돌아가기", "back", "back"); }
function heading(text) { return `<h2>${esc(text)}</h2>`; }
function muted(text) { return `<p class="muted">${esc(text)}</p>`; }
function entryRow(entry, action = "detail") {
  const a = entry.kind === "rest" ? null : recordAppearance(entry);
  const subtitle = [dayLabel(entry.day), kinds[entry.kind], a && sports[a.sport] + " 스킨", a && animals[a.animal]]
    .filter(Boolean).join(" · ");
  return `<button class="row" data-action="${action}" data-id="${esc(entry.id)}">
    ${a ? recordPortrait(a) : '<span class="badge rest">휴식</span>'}
    <span class="row-text"><strong>${esc(title(entry))}</strong><small>${esc(subtitle)}</small></span>
    <span class="arrow" aria-hidden="true">›</span></button>`;
}
function rows(entries, action) {
  return entries.length ? entries.map((e) => entryRow(e, action)).join("") : muted("아직 기록이 없어요.");
}
function segments(items, selected, action) {
  return `<div class="segments">${items.map(([value, label]) =>
    button(label, action, value === selected ? "on" : "", `data-value="${esc(value)}" aria-pressed="${value===selected}"`)).join("")}</div>`;
}
function journalView() {
  const filters = ["전체", "날짜별", "운동별"];
  let content;
  if (journalFilter === "운동별") {
    const names = new Map();
    latest().forEach((e) => e.exercises.forEach((ex) => { if (!names.has(clean(ex.name))) names.set(clean(ex.name), ex.name); }));
    content = Array.from(names.values()).sort((a, b) => a.localeCompare(b, "ko")).map((name) =>
      button(name + "  ›", "exercise", "row", `data-name="${esc(name)}"`)).join("") || muted("기록한 운동이 여기에 모여요.");
  } else if (journalFilter === "날짜별") {
    content = `<label class="field">날짜<input id="calendar-day" type="date" value="${calendarDate}" max="${dayKey()}"></label>`
      + rows(latest().filter((e) => e.day === calendarDate));
  } else { content = rows(latest()); }
  return heading("일지") + button("동작 도감", "library", "secondary wide")
    + segments(filters.map((s) => [s,s]), journalFilter, "filter") + content;
}
function contributing(goal) {
  const days = new Set();
  return latest().reverse().filter((e) => {
    if (e.day < goal.start || days.has(e.day) || !e.exercises.some((ex) => clean(ex.name) === clean(goal.name))) return false;
    days.add(e.day);
    return true;
  }).slice(0, goal.target);
}
function adventureView() {
  const s = stats();
  const points = [["첫 훈련 도장", "재활·훈련 첫 기록", s.days >= 1], ["콘 코스 개방", "서로 다른 3일 기록", s.days >= 3],
    ["매트 구역 개방", "누적 6일 기록과 한 줄 회고", s.matArea]];
  return backButton() + heading("모험") + scene() + progressPanel() + growthBoardView() + "<h3>기초 훈련장 마일스톤</h3>"
    + points.map(([name, desc, done]) => `<div class="row"><span class="badge">${done ? "✓" : "○"}</span>
      <div class="row-text"><strong>${name}</strong><small>${desc}</small></div></div>`).join("")
    + (s.days >= 6 ? button(book.reflection || "한 줄 회고 쓰기", "reflection", "secondary wide") : "")
    + "<h3>나의 마일스톤</h3>" + book.goals.map((g) =>
      button(`⚑ ${g.name} · ${contributing(g).length} / ${g.target}일`, "goal-detail", "row", `data-id="${g.id}"`)).join("")
    + button("＋ 목표 만들기", "goal-new", "secondary wide");
}

function field(label, name, value, extra = "", type = "text") {
  return `<label class="field">${esc(label)}<input type="${type}" data-field="${name}" value="${esc(value)}" ${extra}></label>`;
}
function choice(label, name, value, options, extra = "") {
  return `<label class="field">${esc(label)}<select data-field="${name}" ${extra}>${options.map((v) =>
    `<option value="${esc(v)}" ${v===value ? "selected" : ""}>${esc(v || "선택 안 함")}</option>`).join("")}</select></label>`;
}


function growthBoardView(standalone = false) {
  const cards = growthBoard(), goals = activeSkillGoals();
  const readingLink = (r, label) => button(`${label} · ${dayLabel(r.entry.day)} · ${r.value}회`,
    "detail", "reading-link", `data-id="${esc(r.entry.id)}"`);
  let html = standalone ? backButton() + heading("기초 훈련장 기록판") : "<h3>기초 훈련장 기록판</h3>";
  if (!cards.length) html += muted("같은 운동의 마지막 세트 횟수를 비교해요. 여러 세트라면 세트 간 휴식 시간도 입력해 주세요.");
  for (const card of cards) {
    const r = card.current, c = r.condition;
    html += `<article class="card growth"><div class="growth-look">${recordPortrait(recordAppearance(r.entry))}
      <div><strong>${esc(r.name)}</strong>${muted(conditionLabel(c))}</div></div><b>마지막 세트 · ${r.value}회</b>
      ${card.previous ? readingLink(card.previous, "이전") : ""}${readingLink(r, "최근")}<p>${esc(growthFeedback(card))}</p>
      ${button("이 조건으로 목표 만들기", "skill-new", "secondary", `data-id="${esc(r.entry.id)}" data-ex="${r.index}"`)}</article>`;
  }
  html += sideProgressSection();
  if (goals.length) html += "<h3>숙련 배지</h3>";
  for (const goal of goals) {
    const matches = skillMatches(goal), earned = matches.length === requiredSessions;
    const first = matches.length ? " · 첫 달성 " + dayLabel(matches[0].day) : "";
    html += `<button class="row" data-action="skill-detail" data-id="${esc(goal.id)}"><span class="badge">${earned ? "★" : "☆"}</span>
      <span class="row-text"><strong>${esc(goal.name)} · ${esc(thresholdText(goal))}</strong>
      <small>${earned ? "배지 획득 · " : ""}${matches.length}/3회${esc(first)}</small></span><span aria-hidden="true">›</span></button>`;
  }
  return html;
}

function selectedReading() {
  const entry = book.entries.find((e) => e.id === page().id);
  return performanceReading(entry, entry.exercises[page().ex], page().ex);
}

function skillGoalForm() {
  const r = selectedReading();
  return backButton() + heading("숙련 목표 만들기") + "<strong>" + esc(r.name) + "</strong>" + muted(conditionLabel(r.condition))
    + field("마지막 세트 목표 (회 이상)", "skill-target", formText("skill-target",r.value), 'id="skill-target" inputmode="numeric"')
    + muted("오늘부터 같은 조건의 목표를 달성한 훈련을 세어요. 서로 다른 훈련 3회에서 달성하면 배지를 받아요.")
    + button("만들기", "skill-save", "primary wide");
}

function saveSkillGoal() {
  const r = selectedReading(), c = r.condition, input = $("#skill-target").value;
  const target = wholeNumber(input);
  if (target === null || target < 1) {
    notify("이 기록의 단위와 범위에 맞는 목표를 입력해 주세요."); return;
  }
  const next = structuredClone(book);
  if (!activeSkillGoals().some((g) => conditionKey(g.condition) === conditionKey(c) && g.target === target)) {
    (next.skillGoals ??= []).push({ id: uid(), name: r.name, condition: c, target, start: dayKey() });
  }
  clearForm(next,"skill-target");
  if (save(next)) back();
}

function skillDetail() {
  const goal = book.skillGoals.find((g) => g.id === page().id), matches = skillMatches(goal);
  return backButton() + heading(goal.name) + "<strong>" + esc(thresholdText(goal)) + "</strong>"
    + muted(conditionLabel(goal.condition)) + muted("시작일 · " + dayLabel(goal.start))
    + (matches.length ? muted("첫 달성 · " + dayLabel(matches[0].day)) : "")
    + (matches.length === requiredSessions ? muted("배지 획득 · " + dayLabel(matches.at(-1).day)) : "")
    + "<h3>목표를 채운 기록</h3>" + rows(matches);
}
function editMovement(ex, index) {
  const ref = `data-ex="${index}"`;
  const pin = Object.hasOwn(book.pins, clean(ex.name)) ? book.pins[clean(ex.name)] : "";
  const amountLabel = amountLabels[ex.unit] ?? "수행량";
  if (ex.drill) return `<div class="card">${field("운동 이름", "name", ex.name, ref)}
    ${pin ? muted("고정 메모 · " + pin) : ""}${muted("이전 종목 기록 · " + drillSummary(ex.drill))}
    ${field("이번 운동 메모 (선택)", "note", ex.note, ref)}
    ${button("운동 빼기", "ex-drop", "quiet negative", ref)}</div>`;
  const showSides = draft.kind === "rehab" || rowsWithSideInput.has(ex) || ex.sets.some(set => set.side && set.side !== "구분 없음");
  const sets = ex.sets.map((set, n) => {
    const pos = `${ref} data-set="${n}"`;
    const row = `${n+1}세트`;
    const remove = ex.sets.length > 1 ? button("−", "set-drop", "quiet negative", `${pos} aria-label="${row} 빼기"`) : "";
    return `<tr><th scope="row">${row}</th>
      <td><input type="text" inputmode="decimal" placeholder="선택" aria-label="${row} 무게 (kg)" data-field="kg" ${pos} value="${esc(set.kg)}"></td>
      <td><input type="text" inputmode="numeric" aria-label="${row} ${amountLabel}" data-field="amount" ${pos} value="${esc(set.amount)}"></td>
      <td class="set-action">${remove}</td></tr>`
      + (showSides
        ? `<tr><td colspan="4">${choice(row+" 방향", "side", set.side, sides, pos)}</td></tr>` : "");
  }).join("");
  return `<div class="card">${catalogNameField(ex, index)}
    ${pin ? `<p class="pin">고정 메모 · ${esc(pin)}</p>` : ""}
    ${field("도구 · 밴드 색 (선택)", "equipment", ex.equipment, ref)}
    ${choice("단위", "unit", ex.unit, Object.keys(amountLabels), ref)}
    ${showSides ? "" : button("좌우 나눠 기록", "enable-sides", "quiet", ref)}
    <table class="set-table" aria-label="운동별 세트 입력"><thead><tr>
      <th scope="col">세트</th><th scope="col">무게 (kg)</th><th scope="col">${amountLabel}</th>
      <th scope="col" class="set-action" aria-label="세트 빼기"></th></tr></thead><tbody>${sets}</tbody></table>
    ${button("＋ 세트 추가", "set-add", "quiet", ref)}
    ${ex.unit === "회" && ex.sets.length > 1 ?
      field("세트 간 휴식 (초)", "restSeconds", ex.restSeconds, ref + ' inputmode="numeric" placeholder="비교하려면 입력"') : ""}
    ${page().view === "routine-editor" ? "" : field("이번 운동 메모 (선택)", "note", ex.note, ref)}
    ${draft.exercises.length > 1 ? button("운동 빼기", "ex-drop", "quiet negative", ref) : ""}</div>`;
}
function discardButton() {
  return button("초안 삭제","discard-draft","quiet negative wide");
}
function signalPicker(signal) {
  return '<label class="field">통증·불편 확인<select data-field="bodySignal"><option value="">기록 안 함</option>'
    + Object.entries(bodySignals).map(([key,label])=>'<option value="'+key+'"'+(signal===key?' selected':'')+'>'+label+'</option>').join("")
    + '</select></label><div id="body-guidance" aria-live="polite">'+(signalGuidance(signal) ? muted(signalGuidance(signal)) : "")+'</div>';
}
function editorView() {
  const editing = page().editing;
  const a = recordAppearance(draft);
  return backButton() + heading(editing ? "기록 수정" : "오늘의 기록")
    + (page().routineName && draft.kind !== "rest" ? muted("가져온 루틴 · " + page().routineName) : "")
    + segments(Object.entries(kinds), draft.kind, "kind")
    + (draft.kind === "rest" ? "" : `<div class="record-look">${recordPortrait(a)}
      <label class="field">${animals[a.animal]} · 이 기록의 스킨<select data-field="skin">${Object.entries(sports).map(([key, label]) =>
        `<option value="${key}" ${a.sport === key ? "selected" : ""}>${label}</option>`).join("")}</select></label></div>`)
    + (draft.kind === "rest" ? "" : draft.exercises.map(editMovement).join("") + button("＋ 운동 추가", "ex-add", "secondary wide")
       + button("루틴만 저장", "routine-from-draft", "secondary wide"))
    + "<h3>오늘의 몸 상태</h3>" + signalPicker(draft.bodySignal) + field("시작 전 느낌 (선택)", "before", draft.before)
    + (draft.kind === "rest" ? "" : field("운동 후 느낌 (선택)", "after", draft.after)
       + choice("체감 난이도", "effort", draft.effort, ["", "가벼움", "보통", "힘듦"]))
    + field("일지 메모 (선택)", "note", draft.note)
    + button(editing ? "수정 내용 확정" : "오늘 기록으로 확정", "confirm", "primary wide") + discardButton();
}
function summaries(ex) {
  if (ex.drill) return muted(drillSummary(ex.drill)) + (ex.note ? muted(ex.note) : "");
  return ex.sets.map((s, i) => `<p class="summary">${i+1}세트　${s.side==="구분 없음" ? "" : esc(s.side)+" "}
    ${s.kg != null && s.kg !== "" ? esc(s.kg) + " kg · " : ""}${esc(s.amount)}${esc(ex.unit)}</p>`).join("")
    + (ex.restSeconds != null && ex.restSeconds !== "" ? muted("세트 간 휴식 · " + ex.restSeconds + "초") : "")
    + (ex.equipment ? muted(ex.equipment) : "") + (ex.note ? muted(ex.note) : "");
}
function detailView() {
  const e = book.entries.find((e) => e.id === page().id);
  const a = e.kind === "rest" ? null : recordAppearance(e);
  const oldSport = sports[e.sport] ?? retiredSports[e.sport];
  return backButton() + heading(title(e)) + (a ? `<div class="record-look">${recordPortrait(a)}<div>
    <strong>${sports[a.sport]} 스킨 · ${animals[a.animal]}</strong>${muted(dayLabel(e.day) + " · " + kinds[e.kind])}</div></div>` :
    muted(dayLabel(e.day) + " · 휴식")) + (oldSport ? muted("이전 기록 종목 · " + oldSport) : "")
    + e.exercises.map((ex) => `<div class="card"><strong>${esc(ex.name)}</strong>${summaries(ex)}${recordedExerciseInfo(ex)}
      ${button("이 운동의 기록 카드", "exercise", "quiet", `data-name="${esc(ex.name)}"`)}</div>`).join("")
    + [["통증·불편 확인",bodySignals[e.bodySignal]],["시작 전",e.before],["운동 후",e.after],["체감 난이도",e.effort],["메모",e.note]].filter(([,v]) => v)
      .map(([k,v]) => muted(`${k} · ${v}`)).join("")
    + (e.day < dayKey() ? "<h3>다음 날 몸 상태</h3>" + (e.followUp ? muted(e.followUp) : "") +
      button(e.followUp ? "다음 날 메모 수정" : "한 줄 덧붙이기", "follow", "quiet", `data-id="${e.id}"`) : "")
    + `<div class="actions">${button("오늘 기록으로 가져오기", "copy", "primary", `data-id="${e.id}"`)}
      ${button("기록 수정", "edit", "secondary", `data-id="${e.id}"`)}
      ${e.kind === "rest" ? "" : button("내 루틴으로 저장", "routine-from", "secondary", `data-id="${esc(e.id)}"`)}</div>`;
}
function exerciseView() {
  const name = page().name, normalized = clean(name);
  const pin = Object.hasOwn(book.pins, normalized) ? book.pins[normalized] : "";
  let content = backButton()+heading(name)+sideProgressSection(name)+"<h3>다음에 볼 메모</h3>"
    + (pin ? `<p class="pin">${esc(pin)}</p>` : "") + button(pin ? "고정 메모 수정" : "메모 고정","pin","quiet");
  for (const entry of latest()) {
    entry.exercises.forEach((ex,i) => {
      if (clean(ex.name) !== normalized) return;
      content += `<div class="card"><strong>${esc(dayLabel(entry.day))}</strong>${summaries(ex)}
        ${entry.followUp ? muted("다음 날 · "+entry.followUp) : ""}
        ${button("이 운동만 가져오기","copy","secondary",`data-id="${entry.id}" data-ex="${i}"`)}
        ${button("일지 보기","detail","quiet",`data-id="${entry.id}"`)}</div>`;
    });
  }
  return content;
}
function noteView() {
  return backButton() + heading(page().title) + `<label class="field">메모<textarea id="note-text">${esc(formText("note-text",page().text))}</textarea></label>`
    + button("저장","note-save","primary wide");
}
function goalView() {
  if (page().view === "goal-new") return backButton()+heading("나의 마일스톤")
    + field("목표 운동 이름","goal-name",formText("goal-name"),'id="goal-name"')
    + field("목표 일수","goal-target",formText("goal-target",4),'id="goal-target" inputmode="numeric"')
    + muted("오늘부터 이 운동을 기록한 날짜를 세어요.") + button("만들기","goal-save","primary wide");
  const g = book.goals.find((goal) => goal.id === page().id);
  return backButton() + heading(g.name + " " + g.target + "일 기록") + muted("시작일 · "+dayLabel(g.start))
    + "<h3>목표를 채운 기록</h3>" + rows(contributing(g));
}

function render(navigate = false) {
  const views = { today: trainingHome, coach: coachView,
    "tracking-day": () => backButton()+heading(dayLabel(page().date))+rows(latest().filter(e=>e.day===page().date)), profile: profileView, news: newsView,
    "sport-help": () => backButton()+heading("훈련 스킨")+muted("새 일지에 입힐 스킨을 고르세요. 훈련을 확정하면 그날의 선수와 스킨이 일지와 훈련장에 보여요."), journal: journalView, adventure: adventureView, detail: detailView,
    exercise: exerciseView, editor: editorView, library: libraryView, "catalog-info": catalogDetailView,
    routines: routineListView, "routine-editor": routineEditorView,
    note: noteView, "goal-new": goalView, "goal-detail": goalView,
    growth: () => growthBoardView(true), "skill-new": skillGoalForm, "skill-detail": skillDetail,
    pick: () => backButton() + heading("지난 기록 가져오기") + rows(latest(), "copy") };
  $("#screen").innerHTML = views[page().view]();
  document.title = "운동일지 · " + ($("#screen h2")?.textContent ?? "오늘");
  document.querySelectorAll("[data-tab]").forEach((el) => {
    if (el.dataset.tab === pages[0].view) el.setAttribute("aria-current","page");
    else el.removeAttribute("aria-current");
  });
  const isHome = page().view === "today";
  const isCoach = page().view === "coach";
  $("#screen").classList.toggle("home-screen", isHome);
  $("#record-bar").hidden = !(isHome || isCoach);
  $("#record-bar").innerHTML = isHome ? recordButton() : isCoach ? coachComposer() : "";
  renderLocker();
  paintIcons();
  if (navigate) { $("#screen").scrollTop = isCoach ? $("#screen").scrollHeight : 0; $("#screen").focus({ preventScroll: true }); }
}

function openCopy(entry, index) {
  const copy = newEntry(entry.kind);
  if (entry.kind !== "rest") copy.recordedAthlete = { animal: athlete().animal, sport: recordAppearance(entry).sport };
  const source = index === undefined ? entry.exercises : [entry.exercises[Number(index)]];
  copy.exercises = copyExercises(source);
  beginEditor("editor",copy);
}
function confirmEntry() {
  const next = structuredClone(book);
  const entry = structuredClone(draft);
  const old = next.entries.findIndex((e) => e.id === entry.id);
  if (entry.kind === "rest") {
    entry.exercises = []; entry.after = ""; entry.effort = ""; delete entry.sport; delete entry.recordedAthlete;
  } else {
    entry.recordedAthlete = recordAppearance(entry);
    try { normalizeExercises(entry.exercises, next.entries[old]); }
    catch (error) { notify(error.message); return; }
  }
  const before = stats();
  const previousBadges = earnedSkillGoalIDs();
  if (old >= 0) {
    entry.followUp = next.entries[old].followUp;
    next.entries[old] = entry;
  }
  else {
    if (!Object.hasOwn(sports, entry.sport)) delete entry.sport;
    entry.day = dayKey();
    entry.time = Date.now();
    next.entries.push(entry);
  }
  if (!finishEditor(next,entry.id)) return;
  home("today",true);
  const after = stats();
  if (after.xp > before.xp) {
    const levelUp = after.level > before.level;
    showMotion(levelUp ? "levelUp" : "run", 2400, levelUp);
  }
  const earned = [...earnedSkillGoalIDs()].filter((id) => !previousBadges.has(id)).length;
  notify("일지를 저장했어요" + (after.xp > before.xp ? " · +10 XP" : "") +
    (after.level > before.level ? ` · 레벨 ${after.level}!` : "") + (earned ? ` · 숙련 배지 ${earned}개 획득` : ""));
}

listenToWrites(document,"input", ({target: t}, value) => {
  if (rememberForm(t.id,value)) return;
  if (t.id === "routine-name") { page().routineName = value; persistEditor(); return; }
  if (t.id === "catalog-query") {
    page().query = value;
    $("#catalog-results").innerHTML = catalogResults();
    return;
  }
  if (!draft || !page().draftID || !t.dataset.field) return;
  const ex = draft.exercises[t.dataset.ex];
  if (t.dataset.field === "skin") return;
  const obj = t.dataset.set !== undefined ? ex.sets[t.dataset.set] : ex || draft;
  obj[t.dataset.field] = value;
  if (t.dataset.set !== undefined || t.dataset.field === "unit") rowsWithDefaultUnit.delete(ex);
  if (t.dataset.field === "name") updateNameSuggestions(t);
  if (t.dataset.field === "bodySignal") $("#body-guidance").innerHTML = signalGuidance(value) ? muted(signalGuidance(value)) : "";
  persistEditor();
});
document.addEventListener("focusin", ({target: t}) => {
  if (t.dataset?.field === "name") updateNameSuggestions(t);
});
listenToWrites(document,"change", ({target: t}) => {
  if (t.id === "calendar-day") { calendarDate = t.value || dayKey(); render(); }
  if (t.dataset.field === "unit") render();
  if (draft && t.dataset.field === "skin" && Object.hasOwn(sports, t.value)) {
    draft.recordedAthlete = { ...recordAppearance(draft), sport: t.value };
    const portrait = t.closest(".record-look").querySelector(".record-portrait");
    portrait.outerHTML = recordPortrait(draft.recordedAthlete);
    persistEditor();
  }
});
listenToWrites(document,"click", (event, submission) => {
  const el = event.target.closest("button");
  if (!el || !el.isConnected) return;
  if (el.dataset.tab) { home(el.dataset.tab); return; }
  if (el.dataset.reset) {
    if (!window.confirm("이 브라우저의 시안 기록을 선택한 데이터로 바꿀까요?")) return;
    const next = el.dataset.reset === "sample" ? sampleBook() : emptyBook();
    next.athlete = athlete();
    next.previewEpoch = uid();
    if (save(next,true)) {
      draft = null;
      liveEditors.clear();
      editorBases.clear();
      unsavedForms.clear();
      clearTimeout(motionTimer);
      fieldMotion = null;
      levelReward = false;
      pages = [{view:"today"}]; saveRoute(true); render(true);
    }
    return;
  }
  const { action, id, ex, value } = el.dataset;
  if (action === "copy-conflict") { keepConflictCopy(); return; }
  if (!flushWorkspace()) return;
  const entry = book.entries.find((e) => e.id === id);
  switch (action) {
  case "back": back(); break;
  case "new": {
    const latest = book.drafts?.find(d=>d.view==="editor");
    if (latest) resumeEditor(latest.id); else startRoutineEntry(findRoutine(book, book.defaultRoutineID));
    break;
  }
  case "fresh": startRoutineEntry(findRoutine(book,book.defaultRoutineID)); break;
  case "resume-draft": resumeEditor(id); break;
  case "discard-draft":
    if (draft && window.confirm("작성 중인 초안을 삭제할까요?") && finishEditor(structuredClone(book),draft.id)) back();
    break;
  case "tracking-day": go("tracking-day",{date:value}); break;
  case "adventure": go("adventure"); break;
  case "coach-prompt": {
    const input = $("#coach-input"); input.value = value; rememberForm(input.id,value); input.focus(); break;
  }
  case "coach-send": sendCoach(submission); break;
  case "routines": go("routines"); break;
  case "routine-blank": startRoutineEntry(); break;
  case "routine-start": startRoutineEntry(findRoutine(book, id)); break;
  case "routine-new": openRoutineEditor(); break;
  case "routine-from": openRoutineEditor(null, entry); break;
  case "routine-from-draft": openRoutineEditor(null, draft); break;
  case "routine-edit": openRoutineEditor(findRoutine(book, id)); break;
  case "routine-default": {
    const next = structuredClone(book);
    next.defaultRoutineID = next.defaultRoutineID === id ? null : id;
    if (save(next)) render();
    break;
  }
  case "routine-save": {
    const next = structuredClone(book);
    try { saveRoutine(next, page().routineName, draft, page().id); }
    catch (error) { notify(error.message); return; }
    if (finishEditor(next,draft.id)) { back(); notify("내 루틴에 저장했어요."); }
    break;
  }
  case "routine-delete": {
    if (!window.confirm("이 루틴을 삭제할까요?")) return;
    const next = structuredClone(book);
    deleteRoutine(next, id);
    if (finishEditor(next,draft.id)) back();
    break;
  }
  case "news": {
    const next = structuredClone(book);
    next.lastReadTrainingDays = stats().days;
    if (save(next)) go("news");
    break;
  }
  case "profile": go("profile"); break;
  case "growth": go("growth"); break;
  case "sport-help": go("sport-help"); break;
  case "motion": playPreview(value); break;
  case "sport": setKit(athlete().animal,value); break;
  case "animal": if (setKit(value,athlete().sport)) back(); break;
  case "locker-animal": setKit(value,athlete().sport); break;
  case "locker-kit": setKit(el.dataset.animal,value); break;
  case "pick": go("pick"); break;
  case "copy": openCopy(entry, ex); break;
  case "edit":
    if (entry) beginEditor("editor",entry,{editing:true},book.drafts?.find(item=>item.id===entry.id));
    break;
  case "detail": go("detail", { id }); break;
  case "exercise": go("exercise", { name: el.dataset.name }); break;
  case "library": go("library", { ex: ex == null ? null : Number(ex), query: "", region: "" }); break;
  case "catalog-info": go("catalog-info", { id, ex: page().ex }); break;
  case "catalog-region":
    page().region = value;
    document.querySelectorAll('[data-action="catalog-region"]').forEach(chip =>
      chip.setAttribute("aria-pressed", String(chip.dataset.value === value)));
    $("#catalog-results").innerHTML = catalogResults();
    saveRoute(true);
    break;
  case "catalog-reset": page().query = ""; page().region = ""; render(); $("#catalog-query").focus(); break;
  case "catalog-select": chooseCatalogExercise(id, Number(ex)); break;
  case "filter": journalFilter = value; render(); break;
  case "kind":
    draft.kind = value;
    if (value !== "rest" && !draft.exercises.length) draft.exercises.push(movement());
    render(); break;
  case "ex-add": draft.exercises.push(movement()); render(); break;
  case "enable-sides":
    rowsWithSideInput.add(draft.exercises[ex]);
    render();
    document.querySelector(`[data-field="side"][data-ex="${ex}"]`)?.focus();
    break;
  case "ex-drop":
    draft.exercises.splice(Number(ex),1);
    if (!draft.exercises.length) draft.exercises.push(movement());
    render(); break;
  case "set-add": {
    rowsWithDefaultUnit.delete(draft.exercises[ex]);
    const sets = draft.exercises[ex].sets;
    sets.push(structuredClone(sets[sets.length-1])); render(); break;
  }
  case "set-drop":
    rowsWithDefaultUnit.delete(draft.exercises[ex]);
    draft.exercises[ex].sets.splice(Number(el.dataset.set),1); render(); break;
  case "confirm": confirmEntry(); break;
  case "pin": {
    const name = page().name, k = clean(name);
    go("note", { title: "다음에 볼 메모", purpose: "pin", name, text: Object.hasOwn(book.pins,k) ? book.pins[k] : "" }); break;
  }
  case "follow": go("note", { title: "다음 날 몸 상태", purpose: "follow", id, text: entry.followUp }); break;
  case "reflection": go("note", { title: "한 줄 회고", purpose: "reflection", text: book.reflection }); break;
  case "note-save": {
    const text = $("#note-text").value.trim(), next = structuredClone(book), ctx = page();
    if (ctx.purpose === "pin") {
      // An exercise name is user text, including names that happen to be object property names.
      Object.defineProperty(next.pins, clean(ctx.name), { value:text, enumerable:true, configurable:true, writable:true });
    } else if (ctx.purpose === "follow") next.entries.find((e) => e.id === ctx.id).followUp = text;
    else {
      if (!text) { notify("회고를 한 줄 입력해 주세요."); return; }
      next.reflection = text;
    }
    clearForm(next,"note-text");
    if (save(next)) back();
    break;
  }
  case "goal-new": go("goal-new"); break;
  case "skill-new": go("skill-new", { id, ex: Number(ex) }); break;
  case "skill-detail": go("skill-detail", { id }); break;
  case "skill-save": saveSkillGoal(); break;
  case "goal-detail": go("goal-detail", { id }); break;
  case "goal-save": {
    const name = $("#goal-name").value.trim(), target = wholeNumber($("#goal-target").value);
    if (!name || target === null || target < 1 || target > 30) { notify("운동 이름과 1~30일 목표를 입력해 주세요."); return; }
    const next = structuredClone(book);
    next.goals.push({ id: uid(), name, target, start: dayKey() });
    clearForm(next,"goal-name","goal-target");
    if (save(next)) back();
    break;
  }
  }
  if (page().draftID) persistEditor();
},captureCoachSend);
function updateClock() { $("#clock").textContent = new Date().toLocaleTimeString("ko-KR", { hour:"2-digit", minute:"2-digit", hour12:false }); }
updateClock();
setInterval(updateClock, 60000);
document.addEventListener("toggle",({target})=>{
  if (target.id === "training-ground" && target.isConnected && page().view === "today") {
    page().showGround = target.open; saveRoute(true);
  }
},true);
window.addEventListener("popstate",event=>{
  for (const complete of [...queuedEvents]) complete();
  if (!flushWorkspace()) { saveRoute(); return; }
  refreshBook();
  restoreNavigation(event.state);
});
window.addEventListener("pagehide",()=>{
  const base = settlingWrite?.start ?? book;
  for (const complete of [...queuedEvents]) complete();
  flushWorkspace();
  if (canPersist) saveInterrupted(base,book);
});
window.addEventListener("storage",event=>{
  if (event.key !== key || queuedEvents.size || unsavedForms.size || pages.some(ctx=>ctx.draftID) ||
      ["note","goal-new","skill-new","coach"].includes(page().view)) return;
  if (refreshBook()) restoreNavigation(history.state);
});
coordinateWrite(()=>{
  if (canPersist) refreshBook();
  restoreNavigation(history.state);
}).catch(()=>restoreNavigation(history.state));
