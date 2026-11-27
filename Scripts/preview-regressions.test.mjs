import assert from "node:assert/strict";
import test from "node:test";
import {fileURLToPath} from "node:url";
import {until, withPreview} from "./preview-browser.mjs";
import {preparePreviewScreenshots, savePreviewScreenshot} from "./preview-screenshots.mjs";

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

test("세트 간 휴식이 숨겨지면 운동 기록과 루틴을 저장할 수 있다", async t => {
  for (const isRoutine of [false, true]) {
    await t.test(isRoutine ? "루틴의 단위를 초로 바꿀 때" : "일지의 마지막 한 세트만 남길 때",
      () => withPreview(async ({app}) => {
        if (isRoutine) {
          await app.action("routines");
          await app.action("routine-new");
          await app.input("#routine-name", "가벼운 운동");
        } else {
          await app.action("new");
        }
        await app.input(exerciseName, "스쿼트");
        await app.action("set-add");
        const rest = '[data-field="restSeconds"]';
        const save = isRoutine ? "routine-save" : "confirm";
        await app.input(rest, "3.");
        await app.action(save);
        await afterWrites(app);
        assert.match(await app.evaluate("document.querySelector('#notice').textContent"), /세트 간 휴식/);

        if (isRoutine) await app.input('[data-field="unit"]', "초");
        else await app.click('[data-action="set-drop"][data-set="1"]');
        await afterWrites(app);
        assert.equal(await app.visible(rest), false);
        await app.action(save);
        await afterWrites(app);
        const notebook = await app.stored();
        const saved = isRoutine ? notebook.routines : notebook.entries;
        assert.equal(saved?.length, 1);
        const [exercise] = saved[0].exercises;
        assert.equal(exercise.sets.length, isRoutine ? 2 : 1);
        assert.equal(exercise.unit, isRoutine ? "초" : "회");
        assert.equal(exercise.restSeconds, undefined);
      }));
  }
});

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

test("다른 창에서 확정한 세트를 코치가 답변에 포함하고 다른 창의 미전송 글도 보관한다",
  () => withPreview(async ({app, newTab}) => {
    const question = "최근 운동을 돌아볼래";
    const pending = "다음 세션에 대해 이야기하고 싶어";
    await app.tab("coach");
    await app.input("#coach-input", question);
    await afterWrites(app);

    const other = await newTab();
    await other.action("new");
    await other.input(exerciseName, "케이블 로우");
    await other.action("set-add");
    await other.action("confirm");
    await afterWrites(other);
    assert.equal((await other.stored()).entries[0].exercises[0].sets.length, 2);
    await other.tab("coach");
    await other.input("#coach-input", pending);
    await afterWrites(other);

    await app.action("coach-send");
    await afterWrites(app);
    const result = await app.stored();
    const [turn] = result.coachTurns;
    assert.equal(turn.question, question);
    assert.equal(turn.topic, "review");
    assert.match(turn.answer, /1일에 걸쳐 1회 운동했고 2세트/u);
    assert.equal(await app.evaluate("document.querySelector('.coach-turn p').textContent"), turn.answer);
    assert.equal(result.formInputs["chat-cat"], pending);
    assert.equal(await app.value("#coach-input"), pending);
  }));

test("세트 추가 직후 저장을 두 번 눌러도 두 세트를 한 번만 저장한다", async t => {
  for (const routine of [false, true]) {
    await t.test(routine ? "루틴" : "운동 일지", () => withPreview(async ({app}) => {
      if (routine) {
        await app.action("routines");
        await app.action("routine-new");
        await app.input("#routine-name", "아침 운동");
      } else {
        await app.action("new");
      }
      await app.input(exerciseName, "스쿼트");
      await afterWrites(app);
      const save = routine ? "routine-save" : "confirm";
      await app.evaluate(`{
        const button = document.querySelector('[data-action="${save}"]');
        document.querySelector('[data-action="set-add"]').click();
        button.click();
        button.click();
      }`);
      await afterWrites(app);
      const notebook = await app.stored();
      const saved = routine ? notebook.routines : notebook.entries;
      assert.equal(saved?.length, 1);
      assert.equal(saved[0].exercises[0].sets.length, 2);
      assert.equal(notebook.drafts.length, 0);
    }));
  }
});

test("다른 화면으로 이동하면서 누른 이전 편집기의 확정은 초안을 유지한다", () => withPreview(async ({app}) => {
  await app.action("new");
  await app.input(exerciseName, "스쿼트");
  await afterWrites(app);
  await app.evaluate(`{
    const confirm = document.querySelector('[data-action="confirm"]');
    document.querySelector('[data-tab="coach"]').click();
    confirm.click();
  }`);
  await afterWrites(app);
  assert.ok(await app.visible("#coach-input"));
  const notebook = await app.stored();
  assert.equal(notebook.entries.length, 0);
  assert.equal(notebook.drafts[0].entry.exercises[0].name, "스쿼트");
}));

test("코치는 화면에서 선택한 동물의 최신 대화를 이어가고 보내는 중 쓴 다음 글을 보관한다",
  () => withPreview(async ({app, newTab}) => {
    const followUp = "그다음은 어떻게 하지?";
    const dogDraft = "강아지와 이어갈 이야기";
    await app.tab("coach");
    await app.input("#coach-input", followUp);
    await afterWrites(app);

    const other = await newTab();
    await other.tab("coach");
    await other.input("#coach-input", "경기 전에 긴장돼");
    await other.action("coach-send");
    await afterWrites(other);
    await other.click(action("locker-animal", "value", "dog"));
    await other.input("#coach-input", "실수해서 자신이 없어");
    await other.action("coach-send");
    await other.input("#coach-input", dogDraft);
    await afterWrites(other);

    await app.action("coach-send");
    await afterWrites(app);
    const before = await app.stored();
    const [cat, dog, reply] = before.coachTurns;
    assert.deepEqual([cat.topic, dog.topic, reply.topic], ["focus", "confidence", "focus"]);
    assert.equal(reply.athlete.animal, "cat");
    assert.equal(reply.question, followUp);
    assert.match(reply.answer, /그 순간에 네가 직접 바꿀/u);
    assert.equal(before.athlete.animal, "dog");
    assert.equal(await app.evaluate("document.querySelector('#screen .record-portrait').dataset.animal"), "cat");
    assert.equal(await app.evaluate("document.querySelector('.coach-turn:last-child p').textContent"), reply.answer);

    const outgoing = "최근 운동 기록을 알려줘";
    const nextInput = "다음으로 보낼 새 문장";
    await app.input("#coach-input", outgoing);
    await afterWrites(app);
    await app.evaluate(`{
      const field = document.querySelector("#coach-input");
      document.querySelector('[data-action="coach-send"]').click();
      field.value = ${JSON.stringify(nextInput)};
      field.dispatchEvent(new Event("input", {bubbles: true}));
    }`);
    await afterWrites(app);
    const final = await app.stored();
    assert.equal(final.coachTurns.length, 4);
    assert.equal(final.coachTurns.at(-1).question, outgoing);
    assert.equal(final.coachTurns.at(-1).athlete.animal, "cat");
    assert.equal(final.athlete.animal, "dog");
    assert.equal(final.formInputs["chat-cat"], nextInput);
    assert.equal(final.formInputs["chat-dog"], dogDraft);
    assert.equal(await app.value("#coach-input"), nextInput);
  }));

async function waitForHeading(app, heading) {
  await until("screen heading " + heading,
    async () => await app.evaluate("document.querySelector('#screen h2')?.textContent.trim()") === heading);
}

async function pressVisibleButton(app, selector, label) {
  const target = await app.evaluate(`(async () => {
    const el = document.querySelector(${JSON.stringify(selector)});
    if (!el?.checkVisibility() || el.disabled) return null;
    el.scrollIntoView({block: "center", inline: "nearest", behavior: "instant"});
    await new Promise(resolve => requestAnimationFrame(resolve));
    const rect = el.getBoundingClientRect(), x = rect.x + rect.width / 2, y = rect.y + rect.height / 2;
    const hit = document.elementFromPoint(x, y);
    return {x, y, reachable: el.contains(hit), name: el.getAttribute("aria-label") ?? el.innerText};
  })()`);
  assert.ok(target?.reachable, selector + " must receive a pointer on the visible button");
  assert.ok(target.name.includes(label), label + " must be in the button's accessible name: " + target.name);
  const point = {x: target.x, y: target.y, button: "left", clickCount: 1};
  await app.send("Input.dispatchMouseEvent", {type: "mousePressed", ...point});
  await app.send("Input.dispatchMouseEvent", {type: "mouseReleased", ...point});
  await afterWrites(app);
}

test("오늘의 훈련장 보기와 선수 라커룸이 확정한 스킨·현재 선택·돌아갈 화면을 구분한다",
  () => withPreview(async ({app}) => {
    await preparePreviewScreenshots(app);
    await app.action("new");
    await app.input(exerciseName, "케이블 로우");
    await app.input('[data-field="kg"][data-ex="0"][data-set="0"]', "12.5");
    await app.action("confirm");
    await waitForHeading(app, "오늘");
    await until("weekly tracking shows the confirmed set", async () => /1일\s*·\s*1회\s*·\s*1세트/u.test(await screenText(app)));
    const recorded = (await app.stored()).entries[0];
    assert.deepEqual(recorded.recordedAthlete, {animal: "cat", sport: "running"});
    await until("the save message has closed", () => app.evaluate("document.querySelector('#notice').hidden"));
    await savePreviewScreenshot(app, "today");

    const ground = '#screen [data-action="adventure"]';
    const locker = '#screen [data-action="profile"]';
    const back = '#screen [data-action="back"]';
    await pressVisibleButton(app, ground, "훈련장 보기");
    await waitForHeading(app, "기초 훈련장");
    await savePreviewScreenshot(app, "ground");
    await pressVisibleButton(app, '#screen [data-action="growth"]', "훈련 기록판 보기");
    await waitForHeading(app, "훈련 기록판");
    await pressVisibleButton(app, back, "돌아가기");
    await waitForHeading(app, "기초 훈련장");

    await pressVisibleButton(app, locker, "선수·스킨 변경");
    await waitForHeading(app, "선수 라커룸");
    const rabbit = '#screen [data-action="animal"][data-value="rabbit"]';
    const hockey = '#screen [data-action="sport"][data-value="fieldHockey"]';
    await pressVisibleButton(app, rabbit, "토끼");
    await waitForHeading(app, "선수 라커룸");
    await pressVisibleButton(app, hockey, "필드하키");
    await waitForHeading(app, "선수 라커룸");
    assert.ok(await app.visible(rabbit + '[aria-pressed="true"]'));
    assert.ok(await app.visible(hockey + '[aria-pressed="true"]'));
    assert.ok(await app.visible('#screen .hero[data-preview][data-animal="rabbit"][data-sport="fieldHockey"]'));
    await app.evaluate("document.querySelector('#screen').scrollTo({top:0,behavior:'instant'})");
    await savePreviewScreenshot(app, "locker");
    const changed = await app.stored();
    assert.deepEqual(changed.athlete, {animal: "rabbit", sport: "fieldHockey"});
    assert.deepEqual(changed.entries, [recorded]);

    await app.evaluate("history.back()");
    await waitForHeading(app, "기초 훈련장");
    assert.ok(await app.visible('#screen .hero[data-animal="cat"][data-sport="running"]'));
    await app.evaluate("history.forward()");
    await waitForHeading(app, "선수 라커룸");
    await app.reload();
    await waitForHeading(app, "선수 라커룸");
    assert.ok(await app.visible(hockey + '[aria-pressed="true"]'));
    await pressVisibleButton(app, back, "돌아가기");
    await waitForHeading(app, "기초 훈련장");
    await pressVisibleButton(app, back, "돌아가기");
    await waitForHeading(app, "오늘");
    assert.ok(await app.visible(ground + ' .record-portrait[data-animal="cat"][data-skin="running"]'));
    await pressVisibleButton(app, locker, "선수·스킨 변경");
    await waitForHeading(app, "선수 라커룸");
    await pressVisibleButton(app, back, "돌아가기");
    await waitForHeading(app, "오늘");
  }));

test("기록 작성 중 오른쪽 동작 미리보기를 열고 돌아오면 미완성 숫자와 초안이 복원된다",
  () => withPreview(async ({app}) => {
    await app.action("new");
    const weight = '[data-field="kg"][data-ex="0"][data-set="0"]';
    const note = '[data-field="note"][data-ex="0"]';
    await app.input(exerciseName, "미완성 로우");
    await app.input(note, "다음에 자세 확인");
    await app.input(weight, "17.");
    await pressVisibleButton(app, '#motion-list [data-action="motion"][data-value="run"]', "달리기");
    await waitForHeading(app, "선수 라커룸");
    assert.ok(await app.visible('#screen .hero[data-preview][data-motion="run"]'));
    assert.ok(await app.visible('#screen [data-action="motion"][data-value="run"][aria-pressed="true"]'));
    await pressVisibleButton(app, '#motion-list [data-action="motion"][data-value="ready"]', "준비");
    const animation = '#screen .hero[data-preview][data-motion="ready"]';
    assert.ok(await app.visible(animation));
    assert.ok(await app.visible('#screen [data-action="motion"][data-value="ready"][aria-pressed="true"]'));
    const pending = await app.stored();
    assert.equal(pending.entries.length, 0);
    assert.equal(pending.drafts.length, 1);
    const [before] = pending.drafts;
    assert.equal(before.entry.exercises[0].sets[0].kg, "17.");
    assert.equal(before.entry.exercises[0].note, "다음에 자세 확인");

    await app.reload();
    await waitForHeading(app, "선수 라커룸");
    assert.ok(await app.visible(animation));
    await pressVisibleButton(app, '#screen [data-action="back"]', "돌아가기");
    await waitForHeading(app, "오늘의 기록");
    assert.equal(await app.value(weight), "17.");
    await app.reload();
    await waitForHeading(app, "오늘의 기록");
    assert.equal(await app.value(exerciseName), "미완성 로우");
    assert.equal(await app.value(note), "다음에 자세 확인");
    assert.equal(await app.value(weight), "17.");
    const after = await app.stored();
    assert.deepEqual(after.drafts.map(draft => draft.id), [before.id]);
    assert.equal(after.entries.length, 0);

    await app.tab("today");
    assert.match(await screenText(app), /0일\s*·\s*0회\s*·\s*0세트/u);
  }));

async function selectJournalPhoto(app, asset) {
  const {root} = await app.send("DOM.getDocument",{depth:0});
  const {nodeId} = await app.send("DOM.querySelector",{nodeId:root.nodeId,selector:"#journal-photos"});
  assert.ok(nodeId, "사진 선택 입력");
  await app.send("DOM.setFileInputFiles",{nodeId,files:[fileURLToPath(new URL(asset,import.meta.url))]});
}

async function inkLine(app, type, from, to, through = []) {
  const bounds = await app.evaluate(`{
    const canvas=document.querySelector("#journal-ink");
    canvas.scrollIntoView({block:"center",behavior:"instant"});
    const r=canvas.getBoundingClientRect();
    ({x:r.x,y:r.y,width:r.width,height:r.height});
  }`);
  const point = ([x,y])=>({x:Math.round(bounds.x+bounds.width*x),y:Math.round(bounds.y+bounds.height*y)});
  if (type==="touch") {
    await app.send("Emulation.setTouchEmulationEnabled",{enabled:true,maxTouchPoints:2});
    await app.send("Input.dispatchTouchEvent",{type:"touchStart",touchPoints:[point(from)]});
    for (const step of [...through,to]) await app.send("Input.dispatchTouchEvent",{type:"touchMove",touchPoints:[point(step)]});
    await app.send("Input.dispatchTouchEvent",{type:"touchEnd",touchPoints:[]});
  } else {
    await app.send("Input.dispatchMouseEvent",{type:"mousePressed",pointerType:type,button:"left",buttons:1,clickCount:1,...point(from)});
    for (const step of [...through,to]) await app.send("Input.dispatchMouseEvent",{type:"mouseMoved",pointerType:type,buttons:1,...point(step)});
    await app.send("Input.dispatchMouseEvent",{type:"mouseReleased",pointerType:type,button:"left",buttons:0,clickCount:1,...point(to)});
  }
  await afterWrites(app);
}

test("사진과 펜·손가락 그림은 Edge를 종료한 뒤에도 같은 일지에만 남는다", async () => {
  let journalID, photoID;
  const weight = '[data-field="kg"][data-ex="0"][data-set="0"]';
  // A physical pointer coordinate can map to a neighboring backing pixel at different device scales.
  const hasInk = (app,x,y)=>app.evaluate(`document.querySelector("#journal-ink").getContext("2d")
    .getImageData(${x-6},${y-6},12,12).data.some((value,i)=>i%4===0 && value<140)`);
  const rendered = (app,selector)=>until("visible stored attachment pixels",()=>app.evaluate(`Boolean(document.querySelector(${JSON.stringify(selector)})?.naturalWidth)`));
  await withPreview(async ({app})=>{
    await app.action("new");
    await app.input(exerciseName,"스쿼트");
    await app.input(weight,"17.");
    await app.input('[data-field="note"][data-ex="0"]',"오른무릎 동작");
    await selectJournalPhoto(app,"../BodyNote/Assets.xcassets/TrainingTrack.imageset/art.png");
    await until("file picker photo persisted",async()=>(await app.stored())?.drafts?.[0].entry.attachments?.length===1);
    const entry = (await app.stored()).drafts[0].entry;
    journalID = entry.id;
    photoID = entry.attachments[0].id;
    assert.deepEqual(Object.keys(entry.attachments[0]).sort(),["id","kind"]);
    assert.equal(entry.attachments[0].kind,"photo");
    assert.equal(await app.visible('[data-action="drawing-open"]'),false);
    await rendered(app,'[data-media-blob]');
    await app.action("attachment-open");
    await rendered(app,"#screen img.attachment-full");
    await app.action("back");
    await waitForHeading(app,"오늘의 기록");
    await app.click('[data-device="ipad"]');
    await app.action("drawing-open");
    await waitForHeading(app,"그림 그리기");
    assert.equal(await app.evaluate('document.querySelector("[data-action=drawing-attach]").disabled'),true);
    await inkLine(app,"pen",[0.30,0.5],[0.65,0.5]);
    await until("unfinished ink saved",async()=>!!(await app.stored()).drafts[0].entry.workingSketch);
    assert.equal(await hasInk(app,512,384),true,"pen line crosses the middle of the page");
    assert.equal((await app.stored()).entries.length,0);
    // Close the entire Edge process while the drawing is still open.
  },{afterRelaunch:async ({app,newTab})=>{
    const initial = await app.stored();
    assert.equal(initial.drafts[0].id,journalID);
    assert.equal(initial.entries.length,0);
    await preparePreviewScreenshots(app);
    await app.click('[data-device="ipad"]');
    await app.action("new");
    await waitForHeading(app,"오늘의 기록");
    assert.equal(await app.value(weight),"17.");
    assert.equal(await app.value('[data-field="note"][data-ex="0"]'),"오른무릎 동작");
    assert.match(await screenText(app),/그림 이어 그리기/);
    await app.send("Emulation.setDeviceMetricsOverride",{width:620,height:820,deviceScaleFactor:1,mobile:false});
    assert.equal(await app.evaluate('document.querySelector("#tabs").getBoundingClientRect().top >= document.querySelector("#screen").getBoundingClientRect().bottom-1'),true);
    await app.send("Emulation.setDeviceMetricsOverride",{width:1450,height:980,deviceScaleFactor:1,mobile:false});
    assert.equal(await app.evaluate('document.querySelector("#tabs").getBoundingClientRect().right <= document.querySelector("#screen").getBoundingClientRect().left+1'),true);
    await app.evaluate("window.confirm=()=>false");
    await app.action("confirm"); await afterWrites(app);
    assert.equal((await app.stored()).entries.length,0);
    assert.equal(await app.value(weight),"17.");
    await app.action("drawing-open");
    await waitForHeading(app,"그림 그리기");
    assert.equal(await hasInk(app,512,384),true,"the saved pen stroke keeps its location after restart");
    await inkLine(app,"touch",[0.65,0.5],[0.65,0.8]);
    assert.equal(await hasInk(app,666,475),true,"finger draws a second stroke");
    await app.action("drawing-undo"); await afterWrites(app);
    assert.equal(await hasInk(app,666,475),false,"undo removes the second stroke");
    await inkLine(app,"touch",[0.65,0.5],[0.65,0.8]);
    await inkLine(app,"pen",[0.65,0.8],[0.77,0.8]);
    await inkLine(app,"pen",[0.30,0.5],[0.39,0.26]);
    await inkLine(app,"pen",[0.375,0.30],[0.61,0.27],[[0.45,0.38]]);
    const head = Array.from({length:17},(_,i)=>[
      .395+.038*Math.cos(i*Math.PI/8), .208+.051*Math.sin(i*Math.PI/8)
    ]);
    await inkLine(app,"pen",head[0],head.at(-1),head.slice(1,-1));
    await savePreviewScreenshot(app,"ipad-drawing");
    await app.action("drawing-attach");
    await waitForHeading(app,"오늘의 기록");
    await until("two attachments persisted",async()=>(await app.stored()).drafts[0].entry.attachments.length===2);
    const complete = (await app.stored()).drafts[0].entry;
    assert.deepEqual(complete.attachments.map(a=>a.kind),["photo","drawing"]);
    assert.equal(complete.workingSketch,undefined);
    await app.input(weight,"17.5");
    await app.action("confirm");
    await until("attachments committed once",async()=>(await app.stored()).entries.length===1);
    await app.click(action("detail","id",journalID));
    await waitForHeading(app,"스쿼트");
    await rendered(app,`[data-media-blob="${photoID}"]`);
    await rendered(app,`[data-media-blob="${complete.attachments[1].id}"]`);
    if (process.env.WORKOUT_PREVIEW_SCREENSHOTS) await until("save notice closed before iPad capture",()=>app.evaluate('document.querySelector("#notice").hidden'));
    await app.evaluate('document.querySelector(".media-section").scrollIntoView({block:"center",behavior:"instant"})');
    await savePreviewScreenshot(app,"ipad-journal");
    await app.click(action("attachment-open","id",complete.attachments[1].id));
    await waitForHeading(app,"그림");
    await app.reload();
    await rendered(app,".attachment-full");
    await app.action("back"); await waitForHeading(app,"스쿼트");
    await app.action("copy"); await waitForHeading(app,"오늘의 기록");
    assert.equal(await app.visible("[data-media-blob]"),false);
    await app.action("back"); await waitForHeading(app,"스쿼트");
    await app.action("edit");
    await waitForHeading(app,"기록 수정");
    await app.click(action("attachment-remove","id",photoID));
    await afterWrites(app);
    assert.equal((await app.stored()).entries[0].attachments.length,2);
    const other = await newTab();
    await other.click(action("detail","id",journalID));
    await rendered(other,`[data-media-blob="${photoID}"]`);
    await app.action("confirm"); await waitForHeading(app,"오늘");
    assert.deepEqual((await app.stored()).entries[0].attachments,[complete.attachments[1]]);
    await other.tab("today");
    await until("unreferenced photo reclaimed after closing its last view",
      ()=>app.evaluate(`readAttachmentBlob(${JSON.stringify(photoID)}).then(()=>false,()=>true)`));
  }});
});

test("읽을 수 없는 사진은 추가되지 않고 일지 초안은 그대로 남는다",()=>withPreview(async ({app})=>{
  await app.action("new");
  await app.input(exerciseName,"플랭크");
  await selectJournalPhoto(app,"../BodyNoteCore/Sources/BodyNoteCore/Resources/exercise-catalog.json");
  await until("unreadable photo is explained",()=>app.evaluate('document.querySelector("#notice").textContent.includes("이 사진을 열 수 없어요")'));
  const entry = (await app.stored()).drafts[0].entry;
  assert.equal(entry.exercises[0].name,"플랭크");
  assert.equal(entry.attachments,undefined);
  assert.equal(await app.evaluate('document.querySelector("[data-action=confirm]").disabled'),false);
}));

test("다른 창이 사진을 제거해도 열린 수정 초안의 충돌 복사본에는 실제 이미지가 남는다",()=>withPreview(async ({app,newTab})=>{
  await app.action("new");
  await app.input(exerciseName,"스쿼트");
  await selectJournalPhoto(app,"../BodyNoteCore/Sources/BodyNoteCore/Resources/ExerciseArt/bodyweight-squat.png");
  await until("attached",async()=>(await app.stored())?.drafts[0].entry.attachments?.length===1);
  await app.action("confirm"); await waitForHeading(app,"오늘");
  const [original] = (await app.stored()).entries, [photo] = original.attachments;
  const kept = await newTab();
  for (const tab of [kept,app]) {
    await tab.click(action("detail","id",original.id));
    await tab.action("edit"); await waitForHeading(tab,"기록 수정");
    await until("original pixels in editor",()=>tab.evaluate('Boolean(document.querySelector("[data-media-blob]")?.naturalWidth)'));
  }
  await app.click(action("attachment-remove","id",photo.id));
  await app.action("confirm"); await waitForHeading(app,"오늘");
  await kept.input('[data-field="note"][data-ex="0"]',"다른 창에 남긴 버전");
  await until("conflict copy available",()=>kept.visible('[data-action="copy-conflict"]'));
  await kept.action("copy-conflict");
  await kept.action("confirm"); await waitForHeading(kept,"오늘");
  const entries = (await kept.stored()).entries;
  assert.equal(entries.length,2);
  assert.equal(entries.find(e=>e.id===original.id).attachments.length,0);
  const copy = entries.find(e=>e.id!==original.id);
  assert.deepEqual(copy.attachments,[photo]);
  await kept.click(action("detail","id",copy.id));
  await kept.action("attachment-open"); await kept.reload();
  await until("conflict copy can still open real photo",()=>kept.evaluate('Boolean(document.querySelector(".attachment-full")?.naturalWidth)'));
}));

test("이미지 저장 트랜잭션이 실패하면 일지에는 빈 이미지 참조가 생기지 않고 재시도할 수 있다",()=>withPreview(async ({app})=>{
  await app.action("new"); await app.input(exerciseName,"로우");
  await app.evaluate(`{
    window.realMediaAdd=IDBObjectStore.prototype.add;
    IDBObjectStore.prototype.add=function(value,id) {
      if (value instanceof Blob) { this.transaction.abort(); return; }
      return window.realMediaAdd.call(this,value,id);
    };
  }`);
  const source = "../BodyNoteCore/Sources/BodyNoteCore/Resources/ExerciseArt/bodyweight-squat.png";
  await selectJournalPhoto(app,source);
  await until("save error surfaced",()=>app.evaluate('document.querySelector("#notice").textContent.includes("저장하지 못했어요")'));
  assert.equal((await app.stored()).drafts[0].entry.attachments,undefined);
  assert.equal(await app.value(exerciseName),"로우");
  await app.evaluate("IDBObjectStore.prototype.add=window.realMediaAdd");
  await selectJournalPhoto(app,source);
  await until("one attachment after retry",async()=>(await app.stored()).drafts[0].entry.attachments?.length===1);
}));
