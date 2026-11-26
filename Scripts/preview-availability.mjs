// Windows, Node 22+, Microsoft Edge. One fresh browser profile per journey.
import assert from "node:assert/strict";
import {execFileSync} from "node:child_process";
import {randomUUID} from "node:crypto";
import {existsSync} from "node:fs";
import {mkdir, rename, rm, writeFile} from "node:fs/promises";
import path from "node:path";
import {fileURLToPath} from "node:url";
import {parseArgs} from "node:util";
import {until, withPreview} from "./preview-browser.mjs";

const repo = fileURLToPath(new URL("../", import.meta.url));
const nameField = '[data-field="name"][data-ex="0"]';
const repsField = '[data-field="amount"][data-ex="0"][data-set="0"]';
const kgField = '[data-field="kg"][data-ex="0"][data-set="0"]';
const noteField = '[data-field="note"]:not([data-ex])';
const workoutName = "케이블 로우";
const weeklyTotals = app => app.evaluate("document.querySelector('.tracking-panel > strong')?.textContent");
const selectedAction = (action, id) => '[data-action="'+action+'"][data-id="'+id+'"]';

async function journal({app, newTab}, stage) {
  stage("세트와 일지 메모 입력");
  const editor = await newTab();
  const note = "동작 설명을 보고 이어서 기록";
  await editor.action("new");
  await editor.input(nameField,workoutName);
  await editor.input(kgField,"17.");
  await editor.input(repsField,"8");
  await editor.input(noteField,note);

  stage("작성 중 동작 설명 열기");
  await editor.action("library");
  await editor.click(selectedAction("catalog-info","seated-cable-row"));
  await until("케이블 로우 자세 설명",()=>editor.visible(".catalog-art.large"));
  assert.equal(await editor.evaluate("document.querySelector('#screen h2').textContent"),workoutName);

  stage("편집 창 종료 후 새 창에서 초안 복원");
  const {targetInfo} = await editor.send("Target.getTargetInfo");
  await app.send("Target.closeTarget",{targetId:targetInfo.targetId});
  await until("편집 창 종료",async()=>!(await app.send("Target.getTargets")).targetInfos.some(item=>item.targetId===targetInfo.targetId));
  const reopened = await newTab();
  await reopened.action("resume-draft");
  await until("복원된 세트 입력란",()=>reopened.visible(kgField));
  assert.deepEqual(await Promise.all([nameField,kgField,repsField,noteField].map(selector=>reopened.value(selector))),
    [workoutName,"17.","8",note]);
  assert.equal((await reopened.stored()).entries.length,0);

  stage("훈련 확정 후 1회·1세트 확인");
  await reopened.action("confirm");
  await until("홈에 확정한 일지 표시",()=>reopened.visible(".tracking-panel"));
  await reopened.reload();
  assert.equal(await weeklyTotals(reopened),"운동 1일 · 1회 · 1세트");
  const saved = await reopened.stored();
  assert.equal(saved.entries.length,1);
  assert.equal(saved.drafts?.length ?? 0,0);
  const entry = saved.entries[0];
  assert.equal(entry.note,note);
  assert.equal(entry.exercises[0].name,workoutName);
  assert.equal(entry.exercises[0].sets[0].kg,17);
  assert.equal(entry.exercises[0].sets[0].amount,8);
  await reopened.tab("journal");
  assert.equal(await reopened.evaluate("document.querySelectorAll('#screen [data-action=detail]').length"),1);
  assert.ok(await reopened.visible(selectedAction("detail",entry.id)));
}

async function routine({app}, stage) {
  const title = "아침 재활 루틴";
  const exercise = "스쿼트";
  stage("운동 이력 없이 기본 루틴 저장");
  await app.action("routines");
  await app.action("routine-new");
  await app.input("#routine-name",title);
  await app.click('[data-action="kind"][data-value="rehab"]');
  await app.input(nameField,exercise);
  await app.input(kgField,"2.5");
  await app.input(repsField,"8");
  await app.action("routine-save");
  await until("기본 루틴 카드",()=>app.visible(".routine-card"));
  const original = await app.stored();
  assert.equal(original.entries.length,0);
  assert.equal(original.routines.length,1);
  assert.equal(original.routines[0].id,original.defaultRoutineID);

  stage("새 일지에 기본 루틴 적용");
  await app.tab("today");
  await app.action("new");
  await until("기본 루틴에서 운동 입력란 열기",()=>app.visible(nameField));
  assert.deepEqual(await Promise.all([nameField,kgField,repsField].map(selector=>app.value(selector))),[exercise,"2.5","8"]);
  assert.equal(await app.evaluate("document.querySelector('.segments .on').textContent"),"재활");
  assert.ok((await app.evaluate("document.querySelector('#screen').innerText")).includes(title));

  stage("수행량 변경 후 초안의 미집계·루틴 원본 확인");
  await app.input(repsField,"13");
  await app.tab("today");
  assert.equal(await weeklyTotals(app),"운동 0일 · 0회 · 0세트");
  const pending = await app.stored();
  assert.equal(pending.entries.length,0);
  assert.equal(pending.drafts?.length,1);
  assert.equal(pending.drafts[0].entry.exercises[0].sets[0].amount,"13");
  assert.deepEqual(pending.routines,original.routines);

  stage("변경한 훈련만 확정");
  await app.action("resume-draft");
  await app.action("confirm");
  await until("홈에 확정한 루틴 훈련 표시",()=>app.visible(".tracking-panel"));
  const saved = await app.stored();
  assert.equal(saved.entries.length,1);
  assert.equal(saved.entries[0].exercises[0].sets[0].amount,13);
  assert.deepEqual(saved.routines,original.routines);
  assert.equal(saved.defaultRoutineID,original.defaultRoutineID);
}

async function catalog({app}, stage) {
  stage("운동 이름 일부만 입력한 새 행 복원");
  await app.action("new");
  await app.input(nameField,"플랭");
  await app.reload();
  assert.equal(await app.value(nameField),"플랭");
  assert.equal(await app.value('[data-field="unit"][data-ex="0"]'),"회");

  stage("복원한 운동에서 부위와 별칭으로 검색");
  await app.action("library");
  await app.click('[data-action="catalog-region"][data-value="무릎"]');
  await app.input("#catalog-query","팔꿈치 플랭크");
  await until("무릎에는 이 별칭의 결과가 없음",()=>app.visible('[data-action="catalog-reset"]'));
  await app.click('[data-action="catalog-region"][data-value="코어"]');
  const candidate = selectedAction("catalog-info","plank");
  await until("코어 부위의 플랭크 검색 결과",()=>app.visible(candidate));
  assert.deepEqual(await app.evaluate("Array.from(document.querySelectorAll('.catalog-row'),row=>row.dataset.id)"),["plank"]);

  stage("동작 그림·기본 단위 확인");
  await app.click(candidate);
  await until("플랭크 상세 그림",()=>app.visible(".catalog-art.large"));
  assert.equal(await app.evaluate("document.querySelector('#screen h2').textContent"),"플랭크");
  assert.ok(await app.evaluate("document.querySelector('.catalog-art.large').decode().then(()=>document.querySelector('.catalog-art.large').naturalWidth>0)"));
  assert.equal(await app.evaluate("document.querySelector('.catalog-info dd:last-child').textContent"),"초");

  stage("동작을 선택해 이름과 초 단위 채우기");
  await app.action("catalog-select");
  await until("운동 편집기로 복귀",()=>app.visible(nameField));
  assert.equal(await app.value(nameField),"플랭크");
  assert.equal(await app.value('[data-field="unit"][data-ex="0"]'),"초");
}

async function coach({app}, stage) {
  const question = "최근 운동 기록 알려줘";
  stage("빈 일지에서 동물 코치에게 질문 작성");
  assert.equal(await weeklyTotals(app),"운동 0일 · 0회 · 0세트");
  await app.tab("coach");
  await app.input("#coach-input",question);

  stage("새로고침 후 보내기 전 문장 복원");
  await app.reload();
  assert.equal(await app.value("#coach-input"),question);
  assert.equal(await app.evaluate("document.querySelectorAll('.coach-turn').length"),0);

  stage("빈 기록에 대한 답과 실제 대화 저장 확인");
  await app.action("coach-send");
  await until("코치 답변과 비워진 입력란",async()=>await app.visible(".coach-turn p") && await app.value("#coach-input")==="");
  const reply = await app.evaluate("document.querySelector('.coach-turn p').textContent");
  assert.match(reply,/없|0\s*(?:회|세트|일)/u);
  const activity = reply.replace(/(?:최근|지난|그전)\s*7\s*일/gu,"");
  assert.doesNotMatch(activity,/[1-9]\d*(?:[.,]\d+)?\s*(?:세트|회|일|kg|분|km)/iu);
  const saved = await app.stored();
  assert.equal(saved.entries.length,0);
  assert.equal(saved.coachTurns.length,1);
  assert.equal(saved.coachTurns[0].question,question);
  assert.equal(saved.coachTurns[0].answer,reply);
}

const journeys = {journal,routine,catalog,coach};

function parseCommand() {
  const {values} = parseArgs({options:{round:{type:"string"},commit:{type:"string"},out:{type:"string"}}});
  const round = Number(values.round);
  if (!/^[1-9]\d*$/u.test(values.round) || !Number.isSafeInteger(round) ||
      !/^[0-9a-f]{40}$/iu.test(values.commit) || !values.out?.trim()) {
    throw Error("실행 형식\nnode Scripts/preview-availability.mjs --round N --commit <40-character SHA> --out <JSON path>");
  }
  return {round,commit:values.commit.toLowerCase(),out:path.resolve(values.out)};
}

function edgeBinary(commit) {
  const head = execFileSync("git",["rev-parse","--verify","HEAD"],{cwd:repo,encoding:"utf8"}).trim();
  if (head!==commit) throw Error("요청한 커밋 "+commit+"과 현재 HEAD "+head+"가 다릅니다.");
  if (process.platform!=="win32") throw Error("Windows Edge가 필요한 측정입니다.");
  const standard = [process.env["ProgramFiles(x86)"],process.env.ProgramFiles,process.env.LOCALAPPDATA]
    .filter(Boolean).map(base=>path.join(base,"Microsoft","Edge","Application","msedge.exe"));
  const override = process.env.WORKOUT_TEST_BROWSER;
  const candidates = override ? [override] : [...standard,process.env.CHROME_BIN];
  const binary = candidates.find(candidate=>candidate && existsSync(candidate));
  if (!binary || path.basename(binary).toLowerCase()!=="msedge.exe") {
    throw Error("Microsoft Edge를 찾을 수 없습니다. WORKOUT_TEST_BROWSER에 msedge.exe 경로를 지정하세요.");
  }
  return binary;
}

async function measure(name, binary, environmentError) {
  let stage = "Windows Edge 실행 환경";
  let status = "missing";
  try {
    if (environmentError) throw environmentError;
    await withPreview(async session=>{
      await journeys[name](session,label=>{stage=label;});
      stage="브라우저 오류 확인";
    },{binary,onBrowserReady:async app=>{
      const version = await app.send("Browser.getVersion");
      if (!/^Edg\//u.test(version.product) || !/\bWindows NT\b/u.test(version.userAgent)) {
        throw Error("Windows용 Microsoft Edge를 확인할 수 없습니다 ("+version.product+").");
      }
      status="fail";
      stage="첫 화면 열기";
    }});
    return "pass";
  } catch (error) {
    console.error("["+name+"] "+status+" · "+stage+"\n"+(error?.message ?? String(error)));
    return status;
  }
}

async function main() {
  const {round,commit,out} = parseCommand();
  let binary, environmentError;
  try { binary=edgeBinary(commit); } catch (error) { environmentError=error; }
  const results={};
  for (const name of Object.keys(journeys)) results[name]=await measure(name,binary,environmentError);
  const report=JSON.stringify({platform:"edge",round,commit,results},null,2)+"\n";
  await mkdir(path.dirname(out),{recursive:true});
  const temporary=out+"."+randomUUID()+".tmp";
  try {
    await writeFile(temporary,report,{flag:"wx"});
    await rename(temporary,out);
  } finally { await rm(temporary,{force:true}); }
  process.stdout.write(report);
  if (Object.values(results).some(status=>status!=="pass")) process.exitCode=1;
}

main().catch(error=>{console.error(error.message);process.exitCode=2;});
