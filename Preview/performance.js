"use strict";

const requiredSessions = 3;

function wholeNumber(input) {
  const text = String(input ?? "").trim();
  const value = Number(text);
  return /^\d+$/.test(text) && Number.isSafeInteger(value) ? value : null;
}

// Preserve the result in old entries. Copies use an ordinary distance or repetition set.
function drillSummary(drill) {
  const parts = [drill.reference];
  if (drill.meters) parts.push(drill.meters + " m");
  if (drill.sport === "running") {
    parts.push(drill.elapsed);
    if (drill.averageBPM) parts.push("평균 " + drill.averageBPM + " bpm");
    if (drill.talk) parts.push(drill.talk);
  } else {
    parts.push(drill.sport === "fieldHockey" ? `${drill.attempts}회 중 ${drill.hits}회 성공` :
      `${drill.attempts}회 중 손 짚기 ${drill.assisted}회`);
  }
  return parts.join(" · ");
}

function performanceReading(entry, ex, index) {
  if (entry.kind === "rest" || ex.drill || ex.unit !== "회" || !ex.sets.length) return null;
  // This value identifies a set goal in the v1 file format, independently of the outfit.
  const condition = { sport: "weightTraining", name: clean(ex.name), equipment: clean(ex.equipment || "") };
  if (ex.sets.length > 1) {
    condition.rest = wholeNumber(ex.restSeconds);
    if (condition.rest === null) return null;
  }
  condition.sets = ex.sets.map((s, i) => [s.kg === "" || s.kg == null ? null : Number(s.kg),
    s.side, i < ex.sets.length - 1 ? Number(s.amount) : null]);
  const value = Number(ex.sets.at(-1).amount);
  return Number.isSafeInteger(value) ? { entry, index, name: ex.name, condition, value } : null;
}

function conditionKey(c) {
  return JSON.stringify([c.name, c.equipment, c.rest, c.sets]);
}

function conditionLabel(c) {
  const parts = [c.equipment].filter(Boolean);
  parts.push(c.sets.map(([kg, side, reps]) =>
    [kg == null ? "맨몸" : kg + " kg", side === "구분 없음" ? "" : side, reps == null ? "" : "× " + reps]
      .filter(Boolean).join(" ")).join(" / "));
  if (c.rest != null) parts.push("휴식 " + c.rest + "초");
  return parts.join(" · ");
}

function growthBoard() {
  const cards = new Map();
  for (const entry of latest()) {
    for (let index = entry.exercises.length - 1; index >= 0; index--) {
      const reading = performanceReading(entry, entry.exercises[index], index);
      if (!reading) continue;
      const key = conditionKey(reading.condition), card = cards.get(key);
      if (!card) cards.set(key, { current: reading, previous: null });
      else if (!card.previous && entry.id !== card.current.entry.id) card.previous = reading;
    }
  }
  return [...cards.values()];
}

function growthFeedback({current, previous}) {
  if (!previous) return "같은 조건의 다음 훈련을 확정하면 변화를 볼 수 있어요.";
  const change = current.value - previous.value;
  if (!change) return "지난번과 같은 기록이에요.";
  return `마지막 세트에서 ${Math.abs(change)}회 ${change > 0 ? "더" : "적게"} 수행했어요.`;
}

function activeSkillGoals() {
  return (book.skillGoals || []).filter((g) => g.condition.sport === "weightTraining" && g.condition.sets?.length);
}

function thresholdText(goal) { return `마지막 세트 ${goal.target}회 이상`; }

function skillMatches(goal) {
  const matches = [], key = conditionKey(goal.condition);
  for (const entry of latest().reverse()) {
    if (entry.day < goal.start) continue;
    const qualifies = entry.exercises.some((ex, i) => {
      const r = performanceReading(entry, ex, i);
      return r && conditionKey(r.condition) === key && r.value >= goal.target;
    });
    if (qualifies) matches.push(entry);
    if (matches.length === requiredSessions) break;
  }
  return matches;
}

function earnedSkillGoalIDs() {
  return new Set(activeSkillGoals().filter((g) => skillMatches(g).length === requiredSessions).map((g) => g.id));
}
