"use strict";

const animals = { cat: "고양이", dog: "강아지", rabbit: "토끼", raccoon: "너구리" };
// The key order matches the four sport rows in each motion sheet.
const sports = { running: "러닝", fieldHockey: "필드하키", weightTraining: "웨이트", basic: "기초 재활" };
const retiredSports = { soccer: "축구", basketball: "농구" };
const gear = { running: "👟", fieldHockey: "🏑", weightTraining: "🏋️", basic: "✚" };
const assetRoot = "../BodyNote/Assets.xcassets/";
const xpPerLevel = 100;
const motions = { idle:"대기", stretch:"스트레칭", ready:"준비", run:"달리기", levelUp:"성장" };
let fieldMotion = null;
let previewMotion = "stretch";
let motionTimer;
let levelReward = false;

function showMotion(value, duration, reward = false) {
  clearTimeout(motionTimer);
  fieldMotion = value;
  levelReward = reward;
  const redraw = () => {
    const ground = $(".hero:not([data-preview])");
    if (ground) ground.outerHTML = scene();
  };
  redraw();
  motionTimer = setTimeout(() => {
    fieldMotion = null;
    levelReward = false;
    redraw();
  }, duration);
}

function athlete(notebook = book) {
  const saved = notebook.athlete || {};
  return { animal: Object.hasOwn(animals, saved.animal) ? saved.animal : "cat",
    sport: Object.hasOwn(sports, saved.sport) ? saved.sport : "running" };
}

function recordAppearance(entry, fallback = athlete()) {
  if (entry.recordedAthlete) return athlete({ athlete: entry.recordedAthlete });
  const skin = Object.hasOwn(sports, entry.sport) ? entry.sport :
    Object.hasOwn(retiredSports, entry.sport) ? "running" : fallback.sport;
  return { animal: fallback.animal, sport: skin };
}

function recordPortrait(a) {
  return `<span class="record-portrait" data-animal="${a.animal}" data-skin="${a.sport}" aria-hidden="true">${sprite(a.animal, a.sport)}</span>`;
}
function setKit(animal, sport) {
  if (!Object.hasOwn(animals, animal) || !Object.hasOwn(sports, sport)) return;
  const next = structuredClone(book);
  next.athlete = { animal, sport };
  if (!save(next)) return false;
  if (!book.entries.some((entry) => entry.kind !== "rest")) showMotion("ready",850);
  if (["today","profile","adventure"].includes(page().view)) render();
  else renderLocker();
  return true;
}
function sprite(animal, sport) {
  return `<img class="sprite" src="${assetRoot}${animal}-${sport}.imageset/art.png" alt="">`;
}
function poseSprite(animal, sport, motion) {
  if (motion === "idle") return sprite(animal,sport);
  const col = Object.keys(animals).indexOf(animal), row = Object.keys(sports).indexOf(sport);
  return `<i class="pose-sprite" aria-hidden="true" style="background-image:url('${assetRoot}Motion-${motion}.imageset/art.png');background-position:${col*100/3}% ${row*100/3}%"></i>`;
}
function motionPlayer(animal, sport, motion) {
  let alternate = "";
  if (motion === "run") alternate = poseSprite(animal, sport, "runContact");
  if (motion === "levelUp") alternate = sprite(animal, sport);
  return `<span class="motion-player" data-motion="${motion}">${poseSprite(animal,sport,motion)}${alternate}</span>`;
}
function motionChoices() {
  const a = athlete();
  return Object.entries(motions).map(([value,title]) =>
    `<button data-action="motion" data-value="${value}" aria-pressed="${previewMotion===value}">${motionPlayer(a.animal,a.sport,value)}<b>${title}</b></button>`).join("");
}
function playPreview(motion) {
  if (!Object.hasOwn(motions, motion)) return;
  previewMotion = motion;
  document.querySelectorAll('.motion-list [data-action="motion"]').forEach((button) => {
    button.setAttribute("aria-pressed", String(button.dataset.value === motion));
  });
  const ground = $(".hero");
  if (!ground) return;
  if (ground.hasAttribute("data-preview")) {
    ground.outerHTML = scene(motion);
  } else {
    clearTimeout(motionTimer);
    fieldMotion = null;
    levelReward = false;
    page().playsPreview = true;
    ground.outerHTML = scene();
  }
}
function canvasIcon(name) { return `<canvas data-icon="${name}" aria-hidden="true"></canvas>`; }

function paintIcons() {
  const paths = {
    bell: "M4 16.5 Q6.5 15.5 6.5 12 V10 A5.5 5.5 0 0 1 17.5 10 V12 Q17.5 15.5 20 16.5 V18 H4 Z M10 20 Q12 23 14 20",
    person: "M16.5 7 A4.5 4.5 0 1 1 7.5 7 A4.5 4.5 0 1 1 16.5 7 M3.5 21 Q3.5 14 9.5 14 H14.5 Q20.5 14 20.5 21 Z",
    calendar: "M4 6 H20 V20 H4 Z M8 3 V8 M16 3 V8 M4 10 H20 M8 14 H9 M13 14 H14 M10 17 H11",
    journal: "M5 3 H17 Q20 3 20 6 V21 H7 Q4 21 4 18 V5 Q4 3 5 3 Z M8 8 H16 M8 12 H16 M8 16 H14",
    adventure: "M2 20 L9 10 L13 15 L16 11 L22 20 Z M14 11 V3 M14 3 L20 4 L17 7 L14 7",
    info: "M21 12 A9 9 0 1 1 3 12 A9 9 0 1 1 21 12 M12 11 V16 M12 8 V8.3",
    dumbbell: "M2 8 H4 V16 H2 Z M5.5 5.5 H8.5 V18.5 H5.5 Z M10 10.5 H14 V13.5 H10 Z M15.5 5.5 H18.5 V18.5 H15.5 Z M20 8 H22 V16 H20 Z"
  };
  document.querySelectorAll("canvas[data-icon]").forEach((canvas) => {
    canvas.width = canvas.height = 72;
    const ctx = canvas.getContext("2d");
    ctx.scale(3,3);
    ctx.lineWidth = 1.8;
    ctx.lineCap = ctx.lineJoin = "round";
    ctx.fillStyle = ctx.strokeStyle = getComputedStyle(canvas).color;
    const path = new Path2D(paths[canvas.dataset.icon]);
    if (canvas.dataset.icon === "dumbbell") ctx.fill(path); else ctx.stroke(path);
  });
}

function scene(preview = null) {
  const recent = preview ? null : latest().find((entry) => entry.kind !== "rest");
  const a = recent ? recordAppearance(recent) : athlete(), s = stats();
  const resting = book.entries.some((e) => e.kind === "rest" && e.day === dayKey());
  const playback = preview || fieldMotion || (page().playsPreview ? previewMotion : null);
  const motion = playback || (resting ? "idle" : "stretch");
  const stamps = Array.from({length: Math.min(5,s.days)}, (_,i) =>
    `<i class="stamp" style="left:${67.1+i*5.65}%">✓</i>`).join("");
  const zone = s.matArea ? "매트 구역 개방" : s.days >= 3 ? "콘 코스 개방" : "";
  return `<div class="hero" ${preview ? "data-preview" : ""} data-motion="${motion}" data-animal="${a.animal}" data-sport="${a.sport}"><div class="scene-art"><img class="track" src="${assetRoot}TrainingTrack.imageset/art.png"
      alt="기초 훈련장의 ${sports[a.sport]} 복장을 입은 ${animals[a.animal]}, ${motions[motion]}, 도장 ${Math.min(s.days,5)}개">
    <div class="field-player${playback ? " playing" : ""}">${motionPlayer(a.animal,a.sport,motion)}</div>
    <div aria-hidden="true">${stamps}</div>${zone ? `<span class="zone-tag">${zone}</span>` : ""}
    ${recent ? `<span class="record-skin-tag">최근 훈련 · ${sports[a.sport]} 스킨</span>` : ""}
    ${!preview && levelReward ? '<span class="level-tag">✦ 레벨 업!</span>' : ""}${resting ? '<span class="rest-tag">휴식일</span>' : ""}</div></div>`;
}
function progressPanel() {
  const s = stats(), within = s.xp % xpPerLevel;
  return `<div class="ground-name"><img src="${assetRoot}TrackBadge.imageset/art.png" alt="">
    <div><h3>기초 훈련장</h3><p>기본기를 다지고, 꾸준히 몸을 회복하는 첫 훈련장!</p></div></div>
    <div class="xp-card"><div class="spread"><b class="xp">Lv. ${s.level} · ${s.xp} XP</b>
    <small>다음 레벨까지 ${xpPerLevel-within} XP</small></div>
    <progress aria-label="다음 레벨 진행도" value="${within}" max="${xpPerLevel}"></progress></div>`;
}

function outfitCard(animal, sport, forAnimal = false) {
  const current = athlete();
  const selected = forAnimal ? current.animal === animal : current.sport === sport;
  const label = forAnimal ? animals[animal] : sports[sport];
  return `<button class="outfit" data-action="${forAnimal ? "animal" : "sport"}" data-value="${forAnimal ? animal : sport}"
    aria-pressed="${selected}" aria-label="${label}"><span class="outfit-tile">${sprite(animal,sport)}
    ${selected ? '<i aria-hidden="true">✓</i>' : ""}</span><b>${forAnimal ? "" : `<span aria-hidden="true">${gear[sport]}</span> `}${label}</b></button>`;
}

function trainingHome() {
  const a = athlete();
  const unread = book.lastReadTrainingDays !== stats().days;
  return `<header class="app-head"><b>${canvasIcon("dumbbell")}Body Note</b><span>
    <button class="icon-button" data-action="news" aria-label="${unread ? "새 훈련 소식" : "훈련 소식"}">
      ${canvasIcon("bell")}${unread ? '<i class="unread"></i>' : ""}</button>
    <button class="icon-button" data-action="profile" aria-label="선수 선택">${canvasIcon("person")}</button></span></header>
    <h2 class="today-title">오늘</h2><p class="intro">오늘의 훈련을 기록하고<br>선수를 성장시켜요!</p>
    ${scene()}${progressPanel()}
    <div class="sport-heading"><h3>다음 기록의 스킨</h3><button class="icon-button" data-action="sport-help" aria-label="스킨 안내">${canvasIcon("info")}</button></div>
    <div class="outfit-strip">${Object.keys(sports).map((s) => outfitCard(a.animal,s)).join("")}</div>
    ${book.entries.length ? button("기초 훈련장 기록판","growth","secondary wide")+
      button("↻ 지난 기록 가져오기","pick","secondary wide")+"<h3>최근 기록</h3>"+rows(latest().slice(0,3)) : ""}`;
}
function recordButton() {
  return `<button class="start" data-action="new"><i aria-hidden="true">＋</i>${book.entries.length ? "오늘 훈련 기록하기" : "첫 훈련 기록하기"}<b aria-hidden="true">›</b></button>`;
}
function profileView() {
  return backButton()+heading("선수 선택")+muted("함께 훈련할 선수를 선택하세요.")
    + `<div class="outfit-strip">${Object.keys(animals).map((a) => outfitCard(a,athlete().sport,true)).join("")}</div>
      <h3>동작 미리보기</h3>${scene(previewMotion)}<div class="motion-list">${motionChoices()}</div>`;
}
function newsView() {
  const s = stats();
  return backButton()+heading("훈련 소식")+'<h3>훈련 기록판</h3>'+muted(s.days ?
    `재활·훈련을 ${s.days}일 기록했어요. 현재 ${s.xp} XP예요.` : "첫 재활·훈련 일지를 확정하면 첫 도장과 10 XP를 받아요.");
}
function renderLocker() {
  const a = athlete();
  $("#motion-list").innerHTML = motionChoices();
  $("#species-list").innerHTML = Object.keys(animals).map((name) =>
    `<button data-action="locker-animal" data-value="${name}" aria-pressed="${a.animal===name}">${sprite(name,a.sport)}<b>${animals[name]}</b></button>`).join("");
  $("#kit-matrix").innerHTML = Object.keys(sports).map((s) => `<div class="kit-line"><b>${sports[s]}</b>
    ${Object.keys(animals).map((name) => `<button data-action="locker-kit" data-animal="${name}" data-value="${s}"
      aria-label="${animals[name]} ${sports[s]}" aria-pressed="${a.animal===name && a.sport===s}">${sprite(name,s)}</button>`).join("")}</div>`).join("");
}
