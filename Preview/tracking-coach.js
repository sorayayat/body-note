"use strict";

const bodySignals = {
  comfortable: "특이사항 없음", discomfort: "불편함이 있었어요",
  stopped: "통증으로 중단했어요", worsening: "통증이 심해졌어요"
};
const painGuidance = "아픈 동작은 멈추세요. 통증이 심해지거나 체중을 싣기 어렵다면 의료진에게 진료를 받으세요.";
function signalGuidance(signal) {
  if (signal === "discomfort") return "어떤 동작에서 불편했는지 메모하고 다음 운동 전에 다시 확인해요.";
  return ["stopped", "worsening"].includes(signal) ? painGuidance : "";
}

function trackingWeek(entries, now = new Date()) {
  const days = Array.from({length:14}, (_, i) => {
    const date = new Date(now);
    date.setDate(date.getDate() + i - 13);
    return {day:dayKey(date), sessions:0, sets:0, rested:false};
  });
  const byDay = new Map(days.map(day => [day.day, day]));
  const activeDates = new Set();
  for (const entry of entries) {
    if (entry.kind !== "rest") activeDates.add(entry.day);
    const day = byDay.get(entry.day);
    if (!day) continue;
    if (entry.kind === "rest") day.rested = true;
    else {
      day.sessions++;
      for (const ex of entry.exercises) if (!ex.drill) day.sets += ex.sets.length;
    }
  }
  const week = days.slice(7);
  const recent = [...entries].reverse().filter(e => e.day >= week[0].day && e.day <= week[6].day).sort((a,b) => b.time-a.time);
  const checked = recent.find(e => Object.hasOwn(bodySignals, e.bodySignal));
  const cues = [];
  if (checked && signalGuidance(checked.bodySignal)) cues.push({entry:checked, title:bodySignals[checked.bodySignal], detail:signalGuidance(checked.bodySignal)});
  const cursor = new Date(now);
  if (!week[6].sessions && !week[6].rested) cursor.setDate(cursor.getDate()-1);
  let streak = 0;
  while (activeDates.has(dayKey(cursor))) {
    streak++;
    cursor.setDate(cursor.getDate()-1);
  }
  if (streak >= 3 && recent[0]?.kind !== "rest") cues.push({entry:recent[0], title:"연속 "+streak+"일 운동했어요", detail:"오늘의 피로를 살펴보고 쉬는 날을 계획해 볼까요?"});
  return {days:week, active:week.filter(d=>d.sessions).length, previous:days.slice(0,7).filter(d=>d.sessions).length,
    sessions:week.reduce((n,d)=>n+d.sessions,0), sets:week.reduce((n,d)=>n+d.sets,0), cues};
}

function trackingPanel() {
  const week = trackingWeek(book.entries);
  const strip = week.days.map(d => button(Number(d.day.slice(-2))+"일", "tracking-day",
    "day-mark "+(d.sessions ? "trained" : d.rested ? "rested" : ""), 'data-value="'+d.day+'" aria-label="'+dayLabel(d.day)+' 운동 '+d.sessions+'회'+(d.rested ? ' 휴식 기록' : '')+'"')).join("");
  return '<section class="tracking-panel"><h3>최근 7일</h3><strong>운동 '+week.active+'일 · '+week.sessions+'회 · '+week.sets+'세트</strong>'
    +'<div class="day-strip">'+strip+'</div>'+muted("그전 7일은 운동 "+week.previous+"일")+'</section>'
    +week.cues.map(c=>'<article class="recovery-cue"><strong>'+esc(c.title)+'</strong>'+muted(c.detail)
      +button(dayLabel(c.entry.day)+" 기록 보기","detail","quiet",'data-id="'+esc(c.entry.id)+'"')+'</article>').join("");
}

function coachReply(question, week, previous) {
  const text = question.toLowerCase().replace(/\s+/gu,"");
  // Removing spaces joins 운동 and 기록. Match 동기 as a word or a motivation expression.
  const mentionsMotivation = /(?:^|[\s\p{P}])동기(?:$|[\s\p{P}])/u.test(question) || /동기(?:부여|가|를|는|도|부족|없)/u.test(text);
  const confidence = mentionsMotivation || /자신|실수|속상|좌절|의욕|부담|못했|비교/u.test(text);
  const logRequest = /(?:기록|일지|통계|운동량|세트수|횟수|일수)(?:[은는을를이가]|좀|한번|다시|간단히|짧게)*(?:알려|보여|요약|정리|조회|확인|궁금|볼래|보고싶)/u.test(text)
    || /(?:운동기록|운동일지|운동량|운동횟수)$/u.test(text);
  let topic = "conversation";
  if (/자해|자살|죽고싶|목숨을끊|killmyself|suicide/u.test(text)) topic = "safety";
  else if (/통증|아파|아프|다쳤|부상|붓|부었|골절|pain|injur/u.test(text)) topic = "discomfort";
  else if (/우울증|공황|정신과|정신건강|약물|약복용|트라우마|불안장애|우울해|depress|panic/u.test(text)) topic = "support";
  else if (/진단|치료/u.test(text)) topic = "discomfort";
  else if (logRequest || /얼마나운동|몇세트|몇회|며칠운동|운동을돌아/u.test(text)) topic = "review";
  else if (/휴식|쉬|피곤|rest|지쳤/u.test(text) || (!confidence && text.includes("회복"))) topic = "recovery";
  else if (/긴장|떨|집중|시합|불안|경기|focus/u.test(text)) topic = "focus";
  else if (confidence) topic = "confidence";
  else if (/기록|요약|세트|운동량|지난주|이번주|얼마|운동을돌아/u.test(text)) topic = "review";
  else if (["focus","confidence"].includes(previous)) topic = previous;
  const replies = {
    safety:"지금은 네 안전이 먼저야. 당장 다칠 위험이 있다면 현지 응급 서비스에 연락하고, 가까운 사람에게 곁에 있어 달라고 해 줘.",
    discomfort:"어떤 동작에서 불편했는지 일지에 남겨 줘. "+painGuidance,
    support:"이야기해 줘서 고마워. 이런 어려움은 정신건강 전문가나 의료진과 상의해 봐. 믿을 만한 사람에게 지금 어떤 도움이 필요한지도 이야기해 볼 수 있어.",
    recovery:week.cues.length ? week.cues[0].title+". "+week.cues[0].detail : "오늘 몸은 어때? 쉬기로 했다면 일지에서 ‘휴식’을 골라 이유를 한 줄 남겨 봐.",
    focus:previous==="focus" ? "그 순간에 네가 직접 바꿀 수 있는 행동은 뭐야? 경기 전에 떠올릴 짧은 말 하나로 정해 볼까?" : "경기를 앞두고 긴장되는구나. 결과 말고 첫 동작에만 집중해 보자. 시작할 때 해낼 수 있는 행동 한 가지가 뭐야?",
    confidence:previous==="confidence" ? "그 장면에서 다음에도 해 보고 싶은 행동을 한 줄로 적어 볼까?" : "마음에 걸리는 장면이 있었구나. 결과와 별개로 끝까지 시도한 일 한 가지를 들려줄래?",
    review:week.sessions ? "최근 7일은 "+week.active+"일에 걸쳐 "+week.sessions+"회 운동했고 "+week.sets+"세트를 기록했어. 그전 7일은 "+week.previous+"일이었어. 어떤 운동을 다시 보고 싶어?" : "최근 7일에 확정한 운동이 아직 없어. 첫 운동을 남기면 같이 돌아볼 수 있어.",
    conversation:"오늘 운동에서 기억에 남는 순간이 뭐야? 운동 기록이나 다음에 해 보고 싶은 행동을 이야기해도 좋아."
  };
  return {topic, answer:replies[topic]};
}

function coachView(a = athlete()) {
  const turns = (book.coachTurns ?? []).filter(t=>t.athlete.animal===a.animal);
  return heading("코치")+'<div class="record-look">'+recordPortrait(a)+'<div><strong>'+animals[a.animal]+' 코치</strong>'
    +muted("기록 돌아보기 · 경기 마음 준비")+'</div></div>'+muted("오프라인 기본 코칭")
    +(turns.length ? "" : ["최근 운동을 돌아볼래","경기 전에 긴장돼","오늘은 쉬어도 될까?"].map(q=>button(q,"coach-prompt","secondary", 'data-value="'+esc(q)+'"')).join(" "))
    +turns.map(t=>'<article class="coach-turn"><strong>'+esc(t.question)+'</strong><div>'+recordPortrait(t.athlete)+'<p>'+esc(t.answer)+'</p></div></article>').join("");
}

function coachComposer(a = athlete()) {
  const key = "chat-"+a.animal;
  return '<div class="coach-composer"><label class="field">동료에게 이야기하기<textarea id="coach-input" rows="2" '
    +'data-animal="'+esc(a.animal)+'" data-sport="'+esc(a.sport)+'" data-form-key="'+esc(key)+'">'
    +esc(formText("coach-input","",key))+'</textarea></label>'
    +button("보내기","coach-send","primary")+'</div>';
}

function captureCoachSend(event) {
  if (!event.target.closest('button[data-action="coach-send"]')) return null;
  const field = $("#coach-input");
  return {text:field.value, field, athlete:{animal:field.dataset.animal, sport:field.dataset.sport}};
}
function sendCoach(submission) {
  const a = submission.athlete, question = submission.text.trim();
  if (!question) { $("#coach-input").focus(); return; }
  // Read inside this write transaction. Keep the editor's original base for conflict detection in save().
  let current;
  try {
    const raw = currentStoredJSON();
    current = raw === storedJSON ? book : readBook(raw);
  } catch {
    notify("최신 일지를 읽을 수 없어요. 입력한 이야기를 보관하고 있어요.");
    return;
  }
  const next = structuredClone(book);
  const previous = (current.coachTurns ?? []).findLast(t=>t.athlete.animal===a.animal)?.topic;
  const reply = coachReply(question, trackingWeek(current.entries), previous);
  (next.coachTurns ??= []).push({id:uid(), athlete:a, question, ...reply});
  const key = "chat-"+a.animal;
  if (submission.field.value !== submission.text) (next.formInputs ??= {})[key] = submission.field.value;
  else if (current.formInputs?.[key] === submission.text && next.formInputs) delete next.formInputs[key];
  if (save(next)) { render(false,a); $("#screen").scrollTop = $("#screen").scrollHeight; $("#coach-input").focus(); }
}
