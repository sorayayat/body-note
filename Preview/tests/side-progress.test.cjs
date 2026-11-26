const { test } = require("node:test");
const assert = require("node:assert/strict");
const fs = require("node:fs");
const path = require("node:path");
const vm = require("node:vm");

const context = vm.createContext({});
for (const file of ["performance.js", "side-progress.js"]) {
  vm.runInContext(fs.readFileSync(path.join(__dirname, "..", file), "utf8"), context);
}
const { sideProgressCards } = context;
const set = (side, amount, kg = "") => ({ side, amount, kg });
const ex = (sets, overrides = {}) => ({ name: "밴드 외회전", equipment: "노란 밴드", unit: "회", sets, ...overrides });
const entry = (id, exercises, kind = "training") => ({ id, exercises, kind, day: "2026-11-" + id });

test("each direction uses the last set per condition and links to its own latest two journals", () => {
  const first = entry("21", [ex([set("왼쪽",6), set("왼쪽",8), set("오른쪽",10), set("양쪽",45)])], "rehab");
  const right = entry("23", [ex([set("오른쪽",10)])]);
  const left = entry("25", [ex([set("왼쪽",12)]), ex([set("왼쪽",10)], { name: " 밴드   외회전 ", equipment: "노란  밴드" })]);
  const sessions = [entry("26", [ex([set("왼쪽",44)])], "rest"), left, right, first];
  const [card] = sideProgressCards(sessions);
  assert.equal(sideProgressCards(sessions).length,1);
  assert.equal(card.left.latest.entryID,"25");
  assert.equal(card.left.previous.entryID,"21");
  assert.equal(card.left.latest.amount - card.left.previous.amount,2);
  assert.equal(card.right.latest.entryID,"23");
  assert.equal(card.right.previous.entryID,"21");
  assert.equal(card.right.latest.amount - card.right.previous.amount,0);
  first.exercises[0].sets[1].amount = 12;
  const updated = sideProgressCards(sessions)[0].left;
  assert.equal(updated.latest.amount - updated.previous.amount,-2);
});

test("units, equipment and weights keep separate cards, including zero vs absent weights", () => {
  const current = entry("25", [
    ex([set("왼쪽",7), set("왼쪽",9,0), set("왼쪽",11,2.5)]),
    ex([set("왼쪽",20,2.5)], { unit: "초" }), ex([set("왼쪽",1,2.5)], { unit: "분" }),
    ex([set("오른쪽",10,2.5)], { equipment: "파란 밴드" }),
    ex([set("왼쪽",5)], { name: "내 동작", unit: "m" })
  ]);
  const before = entry("24", [ex([set("왼쪽",6,"2.5")])]);
  const cards = sideProgressCards([current, before]);
  assert.equal(cards.length,7);
  const paired = cards.find(card => card.left.previous);
  assert.equal(paired.left.latest.amount,11);
  assert.equal(paired.left.previous.amount,6);
  assert.equal(paired.right.latest,null);
  assert.equal(cards.filter(card => card.left.previous || card.right.previous).length,1);
  assert.equal(sideProgressCards([current, before], " 내 동작 ")[0].unit,"m");
  assert.equal(sideProgressCards([current, before], "다른 운동").length,0);
});

test("unassigned, bilateral, archived and invalid sets do not supply a missing side", () => {
  const sessions = [entry("25", [
    ex([set("구분 없음",99), set("양쪽",99), set("왼쪽",0), set("왼쪽",7,-1), set("왼쪽",9,"잘못된 값")]),
    ex([set("왼쪽",20)], { drill: { sport: "basic" } }),
    ex([set("오른쪽",10)])
  ])];
  const [card] = sideProgressCards(sessions);
  assert.equal(sideProgressCards(sessions).length,1);
  assert.equal(card.left.latest,null);
  assert.equal(card.right.previous,null);
  assert.equal(card.right.latest.amount,10);
});
