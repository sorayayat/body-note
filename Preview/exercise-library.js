"use strict";

const catalogUnits = { reps: "회", seconds: "초", minutes: "분", meters: "m" };
const catalogArt = "../BodyNoteCore/Sources/BodyNoteCore/Resources/ExerciseArt/";

function catalogKey(text) {
  return text.normalize("NFKC").toLowerCase().replace(/[^\p{L}\p{N}]/gu, "");
}

function searchCatalog(query, region = "") {
  const pool = exerciseCatalog.items.filter(item => !region || item.regions.includes(region));
  if (!query.trim()) return pool;
  const phrase = catalogKey(query);
  if (!phrase) return [];
  const words = query.trim().split(/\s+/u).map(catalogKey).filter(Boolean);
  function rank(item) {
    const names = [item.name, ...item.aliases].map(catalogKey);
    if (names[0] === phrase) return 0;
    if (names.includes(phrase)) return 1;
    if (names.some(name => name.startsWith(phrase))) return 2;
    if (names.some(name => name.includes(phrase))) return 3;
    const fields = names.concat([...item.regions, ...item.keywords, item.equipment].map(catalogKey));
    return words.every(word => fields.some(field => field.includes(word))) ? 4 : Infinity;
  }
  return pool.map(item => ({ item, rank: rank(item) })).filter(match => Number.isFinite(match.rank))
    .sort((a, b) => a.rank - b.rank).map(match => match.item);
}

function catalogNameField(exercise, index) {
  const ref = `data-ex="${index}"`;
  return `<div class="catalog-name">${field("운동 이름", "name", exercise.name,
    ref + ` autocomplete="off" aria-controls="suggest-${index}"`)}
    <div class="catalog-suggestions" id="suggest-${index}"></div>
    ${button("부위별 동작 찾기", "library", "quiet", ref)}</div>`;
}

function updateNameSuggestions(input) {
  const list = document.getElementById("suggest-" + input.dataset.ex);
  if (!list) return;
  const matches = input.value.trim() ? searchCatalog(input.value).slice(0, 4) : [];
  list.innerHTML = matches.map(item => `<button type="button" data-action="catalog-select"
    data-ex="${esc(input.dataset.ex)}" data-id="${esc(item.id)}"><span>${esc(item.name)}</span>
    <small>${esc(item.regions[0])}</small></button>`).join("");
}

function catalogImage(item, detailed = false) {
  return `<img class="catalog-art${detailed ? " large" : ""}" src="${catalogArt}${encodeURIComponent(item.id)}.png"
    alt="${detailed ? esc(item.name + " 동작 자세") : ""}" ${detailed ? "" : 'loading="lazy"'}>`;
}

function recordedExerciseInfo(exercise) {
  if (exercise.drill) return "";
  const item = exerciseCatalog.items.find(item => clean(item.name) === clean(exercise.name));
  return item ? button("동작 그림과 설명", "catalog-info", "quiet", `data-id="${esc(item.id)}"`) : "";
}

function catalogResults() {
  const results = searchCatalog(page().query, page().region);
  const count = `<p class="catalog-count" role="status">동작 ${results.length}개</p>`;
  if (!results.length) return count + muted("찾은 동작이 없어요. 다른 단어나 훈련 부위를 선택해 보세요.")
    + button("검색 초기화", "catalog-reset", "secondary");
  return count + '<div class="catalog-grid">' + results.map(item =>
    `<button type="button" class="catalog-row" data-action="catalog-info" data-id="${esc(item.id)}">
    ${catalogImage(item)}<span><strong>${esc(item.name)}</strong><small>${esc([...item.regions, item.equipment].join(" · "))}</small></span>
    </button>`).join("") + "</div>";
}

function libraryView() {
  const { query, region } = page();
  return backButton() + heading("동작 도감") + `<label class="field catalog-search">동작 검색
    <input id="catalog-query" type="search" value="${esc(query)}" placeholder="이름, 부위, 도구로 검색" autocomplete="off"></label>
    <h3>훈련 부위</h3><div class="catalog-regions">${["", ...exerciseCatalog.regions].map(label =>
      button(label || "전체", "catalog-region", "catalog-chip", `data-value="${esc(label)}" aria-pressed="${label === region}"`)).join("")}
    </div><div id="catalog-results">${catalogResults()}</div>`;
}

function catalogDetailView() {
  const item = exerciseCatalog.items.find(item => item.id === page().id);
  const index = page().ex;
  return backButton() + heading(item.name) + catalogImage(item, true) + `<p>${esc(item.description)}</p>`
    + (index == null ? "" : button("＋ 이 동작 선택", "catalog-select", "primary wide", `data-id="${esc(item.id)}" data-ex="${index}"`))
    + `<dl class="catalog-info"><dt>훈련 부위</dt><dd>${esc(item.regions.join(" · "))}</dd>
      <dt>도구</dt><dd>${esc(item.equipment)}</dd><dt>기본 기록 단위</dt><dd>${catalogUnits[item.unit]}</dd></dl>
      <p class="catalog-credit">그림 <a href="https://github.com/AlexMollard/Open-Exercise-Art" target="_blank" rel="noopener">Open Exercise Art · Alex Mollard</a>
      · <a href="https://creativecommons.org/licenses/by-sa/4.0/" target="_blank" rel="noopener">CC BY-SA 4.0</a></p>`;
}

function chooseCatalogExercise(id, index) {
  const item = exerciseCatalog.items.find(item => item.id === id);
  const exercise = draft?.exercises[index];
  if (!item || !exercise || exercise.drill) return;
  exercise.name = item.name;
  if (rowsWithDefaultUnit.delete(exercise)) exercise.unit = catalogUnits[item.unit];
  const owner = pages.findLastIndex(ctx=>ctx.draftID);
  if (owner < 0 || !persistEditor(pages[owner])) return;
  const levels = pages.length - 1 - owner;
  if (levels > 0) { back(levels); return; }
  render();
  document.querySelector(`input[data-field="amount"][data-ex="${index}"]`)?.focus();
}
