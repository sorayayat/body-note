const { test } = require("node:test");
const assert = require("node:assert/strict");
const fs = require("node:fs");
const path = require("node:path");
const vm = require("node:vm");

const dayKey = date => [date.getFullYear(), String(date.getMonth()+1).padStart(2,"0"),
  String(date.getDate()).padStart(2,"0")].join("-");
const app = vm.createContext({structuredClone, dayKey, Date});
for (const file of ["tracking-coach.js","workspace.js"]) {
  vm.runInContext(fs.readFileSync(path.join(__dirname,"..",file),"utf8"),app);
}
const today = new Date(2025,10,4,12);
function entry(offset, sets = 1, overrides = {}) {
  const date = new Date(today);
  date.setDate(date.getDate()+offset);
  return {id:crypto.randomUUID(),day:dayKey(date),time:date.getTime(),kind:"training",
    exercises:[{sets:Array.from({length:sets},()=>({amount:8}))}],...overrides};
}

test("rolling 7 days count distinct active dates, sessions and real sets across the month boundary",()=>{
  const items = [-14,-13,-7,-7,-6,-2,0,0,1].map(offset=>entry(offset,2));
  items.push(entry(-1,0,{kind:"rest"}));
  const week = app.trackingWeek(items,today);
  assert.equal(week.days.length,7);
  assert.equal(week.days[0].day,"2025-10-29");
  assert.equal(week.active,3);
  assert.equal(week.previous,2);
  assert.equal(week.sessions,4);
  assert.equal(week.sets,8);
  assert.equal(week.days[5].rested,true);
  assert.equal(week.cues.length,0);
});

test("injury check-in and rest prompts point to the source; a later comfortable rest resolves both",()=>{
  const items = [entry(-2),entry(-1),entry(0,1,{bodySignal:"stopped"})];
  const week = app.trackingWeek(items,today);
  assert.equal(week.cues.length,2);
  assert.equal(week.cues[0].entry.id,items[2].id);
  assert.match(week.cues[0].detail,/의료진/u);
  assert.match(week.cues[1].title,/3일/u);
  items.push(entry(0,0,{kind:"rest",bodySignal:"comfortable",time:today.getTime()+3000}));
  assert.equal(app.trackingWeek(items,today).cues.length,0);
});

test("an unanswered check-in is neither a negative finding nor a new alert",()=>{
  const items = [entry(-6,1,{bodySignal:"discomfort"}),entry(-2)];
  assert.equal(app.trackingWeek(items,today).cues[0].entry.id,items[0].id);
  assert.equal(app.trackingWeek(items,new Date(2025,10,5,12)).cues.length,0);
  assert.equal(app.trackingWeek([entry(0,1,{exercises:[{drill:{},sets:[{}]}]})],today).sets,0);
});

test("offline coach uses real totals, continues a sports mindset exchange and prioritizes pain",()=>{
  const week = app.trackingWeek([entry(0,3)],today);
  assert.match(app.coachReply("최근 운동을 돌아볼래",week).answer,/3세트/u);
  const first = app.coachReply("경기 전에 긴장돼",week);
  const follow = app.coachReply("첫 패스가 떠올라",week,first.topic);
  assert.equal(first.topic,"focus");
  assert.equal(follow.topic,"focus");
  assert.notEqual(follow.answer,first.answer);
  assert.equal(app.coachReply("무릎이 아파",week,"confidence").topic,"discomfort");
  assert.equal(app.coachReply("죽고 싶어",week,"review").topic,"safety");
  assert.equal(app.coachReply("공황 증상이 자주 와",week,"confidence").topic,"support");
});

test("a streak longer than the visible chart retains its actual length",()=>{
  const items = Array.from({length:10},(_,i)=>entry(i-10));
  assert.match(app.trackingWeek(items,today).cues[0].title,/10일/u);
  assert.equal(app.trackingWeek(items,new Date(2025,10,5,12)).cues.length,0);
});

test("two windows can independently save routines, messages and partial set drafts",()=>{
  const base = {entries:[], formInputs:{"chat-cat":"첫 질문"}, drafts:[]};
  const mine = structuredClone(base), theirs = structuredClone(base);
  mine.drafts.push({id:"a", updated:2, entry:{sets:[{kg:"12.",amount:""}]}});
  mine.formInputs["chat-cat"]="다음 질문";
  theirs.drafts.push({id:"b",updated:1,entry:{note:"다른 창"}});
  theirs.formInputs["chat-dog"]="다른 동물";
  theirs.routines = [{id:"r",name:"아침"}];
  const merged = app.mergeBook(base,mine,theirs);
  assert.deepEqual(Array.from(merged.drafts,d=>d.id),["a","b"]);
  assert.equal(merged.drafts[0].entry.sets[0].kg,"12.");
  assert.equal(merged.drafts[0].entry.sets[0].amount,"");
  assert.equal(merged.formInputs["chat-cat"],"다음 질문");
  assert.equal(merged.formInputs["chat-dog"],"다른 동물");
  assert.equal(merged.routines[0].name,"아침");
});

test("conflicting writes on the same record raise a visible conflict instead of replacing it",()=>{
  const base = {entries:[{id:"a",note:"기존"}]};
  const mine = {entries:[{id:"a",note:"내 입력"}]};
  const theirs = {entries:[{id:"a",note:"다른 입력"}]};
  assert.throws(()=>app.mergeBook(base,mine,theirs),/다른 창/u);
  assert.equal(theirs.entries[0].note,"다른 입력");
});
