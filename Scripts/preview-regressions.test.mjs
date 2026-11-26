import assert from "node:assert/strict";
import test from "node:test";
import {until, withPreview} from "./preview-browser.mjs";

const exerciseName = '[data-field="name"][data-ex="0"]';
const action = (name, attribute, value) =>
  `[data-action="${name}"][data-${attribute}="${value}"]`;
const screenText = app => app.evaluate("document.querySelector('#screen').innerText");

// Input and click handlers queue their writes under this Web Lock before rendering.
const afterWrites = app => app.evaluate("navigator.locks.request('workout-log-preview', () => true)");

async function loadExamples(app) {
  await app.evaluate("window.confirm = () => true");
  await app.click('[data-reset="sample"]');
  await until("sample workouts loaded", async () => (await app.stored())?.entries.length > 0);
  return (await app.stored()).entries;
}

test("도감을 새로고침하면 검색어와 선택한 부위를 함께 복원한다", () => withPreview(async ({app}) => {
  await app.tab("journal");
  await app.action("library");
  await app.click(action("catalog-region", "value", "무릎"));
  await app.input("#catalog-query", "무릎 펴기");
  const view = () => app.evaluate(`({
    query: document.querySelector("#catalog-query")?.value,
    region: document.querySelector('.catalog-chip[aria-pressed="true"]')?.textContent,
    results: Array.from(document.querySelectorAll('[data-action="catalog-info"]'), item => item.dataset.id)
  })`);
  const expected = {query: "무릎 펴기", region: "무릎", results: ["leg-extension"]};
  await afterWrites(app);
  assert.deepEqual(await view(), expected);
  await app.reload();
  assert.deepEqual(await view(), expected);
}));

test("날짜별 일지에서 상세를 보고 돌아오거나 새로고침해도 같은 날짜를 보여준다", () => withPreview(async ({app}) => {
  const [entry] = await loadExamples(app);
  await app.tab("journal");
  await app.click(action("filter", "value", "날짜별"));
  await app.input("#calendar-day", entry.day);
  await app.click(action("detail", "id", entry.id));
  await app.action("back");
  await until("date filter restored on back", async () => await app.value("#calendar-day") === entry.day);
  const snapshot = () => app.evaluate(`({
    filter: document.querySelector(".segments .on")?.textContent,
    day: document.querySelector("#calendar-day")?.value ?? null,
    records: Array.from(document.querySelectorAll('#screen [data-action="detail"]'), row => row.dataset.id)
  })`);
  const expected = {filter: "날짜별", day: entry.day, records: [entry.id]};
  assert.deepEqual(await snapshot(), expected);
  await app.reload();
  assert.deepEqual(await snapshot(), expected);
}));

test("운동명을 직접 입력하거나 바꾸면 고정 메모도 그 운동에 맞춰 바뀐다", () => withPreview(async ({app}) => {
  const entries = await loadExamples(app);
  const cable = entries.find(entry => entry.exercises.some(exercise => exercise.name === "케이블 로우"));
  const note = "고정 메모 · 기구 좌석 4칸";
  await app.action("new");
  await app.input(exerciseName, "케이블 로우");
  await afterWrites(app);
  const shownOnTypedName = (await screenText(app)).includes(note);

  await app.tab("today");
  await app.click(action("detail", "id", cable.id));
  await app.action("copy");
  await until("copied cable row displays its pin", async () => (await screenText(app)).includes(note));
  await app.input(exerciseName, "스쿼트");
  await afterWrites(app);
  const oldNoteShownOnSquat = (await screenText(app)).includes(note);
  assert.deepEqual({shownOnTypedName, oldNoteShownOnSquat}, {shownOnTypedName: true, oldNoteShownOnSquat: false});
}));

test("다른 창에서 원본 기록을 바꿔도 숙련 목표를 잘못 저장하거나 다시 연결하지 않는다", async t => {
  for (const [label, edit, submit] of [
    ["휴식으로 바꾼 뒤 이전 창에서 목표 저장", "rest", true],
    ["휴식으로 바꾼 뒤 목표 화면 새로고침", "rest", false],
    ["다른 운동으로 바꾼 뒤 목표 화면 새로고침", "rename", false]
  ]) {
    await t.test(label, () => withPreview(async ({app, newTab}) => {
      const newName = "새로운 운동";
      const rawTarget = "11";
      await app.action("new");
      await app.input(exerciseName, "원본 체크");
      await app.action("confirm");
      await until("source workout confirmed", async () => (await app.stored())?.entries.length === 1);
      const entry = (await app.stored()).entries[0];
      await app.action("growth");
      await app.action("skill-new");
      await app.input("#skill-target", rawTarget);
      await afterWrites(app);
      const originalKey = Object.keys((await app.stored()).formInputs ?? {}).find(key => key.startsWith("skill-target"));
      assert.ok(originalKey, "목표 원문이 저장되어야 합니다");

      const other = await newTab();
      await other.click(action("detail", "id", entry.id));
      await other.action("edit");
      if (edit === "rest") await other.click(action("kind", "value", "rest"));
      else await other.input(exerciseName, newName);
      await other.action("confirm");
      await until("original workout changed in second tab", async () => {
        const current = (await other.stored()).entries.find(row => row.id === entry.id);
        return edit === "rest" ? current.kind === "rest" : current.exercises[0]?.name === newName;
      });

      if (submit) {
        if (await app.visible('[data-action="skill-save"]')) await app.action("skill-save");
      } else {
        // A broken route can leave #screen empty. Inspect the actual new document in that case.
        await app.reload({requireScreen: false});
      }
      await afterWrites(app);
      const stored = await app.stored();
      const currentName = await app.evaluate("document.querySelector('#screen strong')?.textContent");
      const reboundToOtherExercise = currentName === newName && await app.value("#skill-target") === rawTarget;
      assert.deepEqual({
        usableScreen: Boolean((await screenText(app)).trim()),
        savedGoals: (stored.skillGoals ?? []).map(goal => goal.name),
        originalInput: stored.formInputs?.[originalKey] ?? null,
        reboundToOtherExercise
      }, {usableScreen: true, savedGoals: [], originalInput: rawTarget, reboundToOtherExercise: false});
    }));
  }
});
