// Run with Node 22+ and an installed Chrome or Edge.
import assert from "node:assert/strict";
import {until, withPreview} from "./preview-browser.mjs";

await withPreview(async ({app, newTab}) => {
  const {send,evaluate,action,input,click,visible,value,stored,tab,reload}=app;
  const name='[data-field="name"][data-ex="0"]';
  const amount='[data-field="amount"][data-ex="0"][data-set="0"]';
  const weight='[data-field="kg"][data-ex="0"][data-set="0"]';
  const note='[data-field="note"]:not([data-ex])';
  const expectValue=(selector,expected)=>until(
    selector+" shows "+JSON.stringify(expected),async()=>await value(selector)===expected);
  await action("new");
  await input(name,"케이블 로우");
  await input(weight,"12.");
  await input(amount,"");
  await input(note,"설명 보고 이어 쓰기");
  await input('[data-field="bodySignal"]',"stopped");
  await action("library");
  await action("catalog-info");
  await until("catalog detail has opened",()=>visible('[data-action="catalog-select"]'));
  await evaluate("history.back()");
  await until("library on browser back",()=>visible("#catalog-query"));
  await evaluate("history.forward()");
  await until("detail on browser forward",()=>visible('[data-action="catalog-select"]'));
  await reload();
  await until("catalog detail on reload",()=>visible('[data-action="catalog-select"]'));
  await action("back");
  await until("library after detail",()=>visible("#catalog-query"));
  await action("back");
  await until("editor after library",()=>visible(amount));
  await expectValue(amount,"");
  await expectValue(weight,"12.");
  await expectValue(note,"설명 보고 이어 쓰기");
  await action("back");
  await tab("journal"); await tab("today");
  await action("new");
  await action("confirm");
  assert.equal((await stored()).entries.length,0);
  await expectValue(weight,"12.");
  await input(amount,"8");
  await action("routine-from-draft");
  await input("#routine-name","아침 훈련");
  await action("routine-save");
  await until("parent journal after routine save",()=>visible(note));
  await expectValue(note,"설명 보고 이어 쓰기");
  await action("confirm");
  await until("confirmed journal",async()=>(await stored()).entries.length===1);
  let book=await stored();
  assert.equal(book.entries[0].exercises[0].sets[0].kg,12);
  assert.equal(book.drafts?.length ?? 0,0);
  assert.equal(book.routines[0].name,"아침 훈련");
  assert.equal(book.entries[0].bodySignal,"stopped");
  assert.match(await evaluate("document.querySelector('#screen').innerText"),/1일\s*·\s*1회\s*·\s*1세트/u);
  const entryID=book.entries[0].id;
  await click('[data-action="detail"][data-id="'+entryID+'"]');
  await action("edit"); await input(amount,"11"); await action("back");
  await tab("today"); await action("resume-draft");
  await expectValue(amount,"11");
  assert.equal((await stored()).entries[0].exercises[0].sets[0].amount,8);
  await action("confirm");
  await until("edit in place",async()=>(await stored()).entries[0].exercises[0].sets[0].amount===11);
  await click('[data-action="locker-animal"][data-value="dog"]');
  await tab("coach"); await input("#coach-input","경기 전에 긴장돼");
  await tab("journal"); await tab("coach"); await reload();
  await until("unsubmitted chat after reload",async()=>await value("#coach-input")==="경기 전에 긴장돼");
  await action("coach-send");
  await until("first coaching reply and cleared composer",async()=>
    (await stored()).coachTurns?.length===1 && await value("#coach-input")==="");
  await input("#coach-input","최근 운동 기록 알려줘"); await action("coach-send");
  await until("second coaching reply and cleared composer",async()=>
    (await stored()).coachTurns?.length===2 && await value("#coach-input")==="");
  book=await stored();
  assert.equal(book.coachTurns.at(-1).athlete.animal,"dog");
  assert.match(book.coachTurns.at(-1).answer,/1세트/u);
  await expectValue("#coach-input","");

  // A second actual browser tab uses the same storage while the first editor stays mounted.
  const other = await newTab();
  await tab("today");
  await action("new"); await input(name,"첫째 창 운동");
  await other.action("fresh"); await other.input(name,"둘째 창 운동");
  await input(note,"첫째 창 메모");
  await until("two independent editors on disk",async()=>{
    const rows=(await stored()).drafts;
    return rows.some(d=>d.entry.exercises[0].name==="첫째 창 운동" && d.entry.note==="첫째 창 메모") &&
      rows.some(d=>d.entry.exercises[0].name==="둘째 창 운동");
  });
  await evaluate("window.restoreTestStorage=Storage.prototype.setItem; Storage.prototype.setItem=function(){throw new DOMException('Test storage full','QuotaExceededError')}");
  await input(note,"저장공간 복구 뒤 보관할 말");
  await click('[data-tab="journal"]');
  await until("visible save failure",async()=>/저장/u.test(await evaluate("document.querySelector('#notice').innerText")));
  await expectValue(note,"저장공간 복구 뒤 보관할 말");
  assert.equal((await stored()).drafts.find(d=>d.entry.exercises[0].name==="첫째 창 운동").entry.note,"첫째 창 메모");
  await evaluate("Storage.prototype.setItem=window.restoreTestStorage");
  await tab("journal");
  await until("successful retry after storage recovery",async()=>(await stored()).drafts.some(d=>d.entry.note==="저장공간 복구 뒤 보관할 말"));
  await tab("today");
  await action("adventure"); await action("goal-new");
  await input("#goal-name","코어"); await input("#goal-target","5");
  await action("back"); await action("goal-new");
  await expectValue("#goal-name","코어");
  await expectValue("#goal-target","5");
  await action("goal-save");
  await until("goal saved once",async()=>(await stored()).goals.filter(g=>g.name==="코어" && g.target===5).length===1);
  await tab("today");
  const shared=(await stored()).drafts.find(d=>d.entry.exercises[0].name==="둘째 창 운동").id;
  await click('[data-action="resume-draft"][data-id="'+shared+'"]');
  await other.input(weight,"33");
  await until("other tab's version on disk",async()=>(await stored()).drafts.find(d=>d.id===shared).entry.exercises[0].sets[0].kg==="33");
  await input(weight,"44");
  await action("copy-conflict");
  await until("both conflicting weights kept",async()=>{
    const rows=(await stored()).drafts.filter(d=>d.entry.exercises[0].name==="둘째 창 운동");
    return rows.some(d=>d.entry.exercises[0].sets[0].kg==="33") && rows.some(d=>d.entry.exercises[0].sets[0].kg==="44");
  });
  await Promise.all([tab("today"),other.tab("today")]);
  await Promise.all([action("fresh"),other.action("fresh")]);
  await Promise.all([input(name,"동시 기록 A"),other.input(name,"동시 기록 B")]);
  await until("simultaneous first keystrokes from two tabs",async()=>{
    const pending=(await stored()).drafts.map(d=>d.entry.exercises[0].name);
    return pending.includes("동시 기록 A") && pending.includes("동시 기록 B");
  });
  await Promise.all([action("confirm"),other.action("confirm")]);
  await until("both simultaneous confirmations",async()=>{
    const saved=(await stored()).entries.map(e=>e.exercises[0].name);
    return saved.filter(n=>n==="동시 기록 A").length===1 && saved.filter(n=>n==="동시 기록 B").length===1;
  });
  await Promise.all([reload(),other.reload()]);
  await tab("journal");
  await until("both records visible after cold reload",async()=>{
    const contents=await evaluate("document.querySelector('#screen').innerText");
    return contents.includes("동시 기록 A") && contents.includes("동시 기록 B");
  });
  await tab("today"); await action("fresh"); await input(name,"새로고침 직전 세트");
  await until("new draft before immediate reload",async()=>(await stored()).drafts.some(d=>d.entry.exercises[0].name==="새로고침 직전 세트"));
  const previousLoad=await evaluate("performance.timeOrigin");
  await evaluate("{const field=document.querySelector("+JSON.stringify(weight)+");field.value='17.';field.dispatchEvent(new Event('input',{bubbles:true}));location.reload();}");
  await app.waitForDocumentChange(previousLoad);
  await until("last keystroke after immediate reload",async()=>(
    await stored()).drafts.find(d=>d.entry.exercises[0].name==="새로고침 직전 세트")?.entry.exercises[0].sets[0].kg==="17.");
  await expectValue(weight,"17.");
  await send("Emulation.setDeviceMetricsOverride",{width:320,height:720,deviceScaleFactor:1,mobile:false});
  assert.ok(await evaluate("document.documentElement.scrollWidth<=innerWidth && document.querySelector('#screen').scrollWidth<=document.querySelector('#screen').clientWidth"));
});
console.log("PASS · history and reload, unfinished decimals, invalid confirm, nested routine, edit identity, weekly tracking, animal chat, simultaneous edits and confirmations, conflict copy, storage failure and retry, last keystroke on reload, goal drafts and narrow layout");
