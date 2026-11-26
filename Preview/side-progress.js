"use strict";

// Walk entries newest first and sets in reverse so each side uses its last matching set.
function sideProgressCards(entries, exerciseName = null) {
  const cards = new Map();
  const target = exerciseName == null ? null : clean(exerciseName);
  for (const entry of entries) {
    if (entry.kind === "rest") continue;
    for (let i = entry.exercises.length - 1; i >= 0; i--) {
      const ex = entry.exercises[i];
      const nameKey = clean(ex.name);
      if (ex.drill || !nameKey || (target !== null && nameKey !== target)) continue;
      const equipment = (ex.equipment || "").trim();
      const equipmentKey = clean(equipment);
      for (let j = ex.sets.length - 1; j >= 0; j--) {
        const set = ex.sets[j];
        if (set.side !== "왼쪽" && set.side !== "오른쪽") continue;
        const amount = wholeNumber(set.amount);
        const kg = set.kg == null || set.kg === "" ? null : Number(set.kg);
        if (amount == null || amount <= 0 || (kg !== null && (!Number.isFinite(kg) || kg < 0))) continue;
        const key = JSON.stringify([nameKey, equipmentKey, ex.unit, kg]);
        if (!cards.has(key)) {
          cards.set(key, { name: ex.name, equipment, unit: ex.unit, kg,
            left: { latest: null, previous: null }, right: { latest: null, previous: null } });
        }
        const card = cards.get(key);
        const history = set.side === "왼쪽" ? card.left : card.right;
        const reading = { entryID: entry.id, day: entry.day, amount };
        if (!history.latest) history.latest = reading;
        else if (!history.previous && history.latest.entryID !== entry.id) history.previous = reading;
      }
    }
  }
  return [...cards.values()];
}

function sideHistoryTile(side, history, unit) {
  const { previous, latest } = history;
  let change = latest ? "첫 기록" : "기록 없음";
  if (previous) {
    const delta = latest.amount - previous.amount;
    change = delta === 0 ? "동일" : (delta > 0 ? "+" : "") + delta + unit;
  }
  function readingLink(reading, label) {
    if (!reading) return "";
    const date = dayLabel(reading.day);
    const value = label + " " + reading.amount + unit;
    return `<button type="button" class="side-reading" data-action="detail" data-id="${esc(reading.entryID)}"
      aria-label="${esc(side + " " + value + ", " + date + " 일지")}"><span>${esc(value)}</span>
      <time datetime="${esc(reading.day)}">${esc(date)}</time></button>`;
  }
  return `<div class="side-tile"><b>${side}</b><strong>${esc(change)}</strong>${latest ?
    `<div class="side-readings">${readingLink(previous, "이전")}${readingLink(latest, "최근")}</div>` : ""}</div>`;
}

function sideProgressSection(exerciseName = null) {
  const cards = sideProgressCards(latest(), exerciseName);
  if (exerciseName !== null && !cards.length) return "";
  let html = "<h3>좌우 변화</h3>";
  if (!cards.length) return html + muted("세트 방향을 왼쪽이나 오른쪽으로 기록하면 여기에 모여요.");
  for (const card of cards) {
    const load = card.kg == null ? "중량 미입력" : card.kg + " kg";
    const condition = [card.equipment, load].filter(Boolean).join(" · ");
    const header = exerciseName === null ? `<strong>${esc(card.name)}</strong>${muted(condition)}` : `<strong>${esc(condition)}</strong>`;
    html += `<article class="card side-card">${header}
      <div class="side-tiles">${sideHistoryTile("왼쪽", card.left, card.unit)}${sideHistoryTile("오른쪽", card.right, card.unit)}</div></article>`;
  }
  return html + muted("같은 도구·중량·단위에서 방향별 마지막 세트를 비교해요. 수치를 누르면 그날의 일지가 열려요.");
}
