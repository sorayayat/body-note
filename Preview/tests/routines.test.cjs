const { test } = require("node:test");
const assert = require("node:assert/strict");
const { randomUUID } = require("node:crypto");
const fs = require("node:fs");
const path = require("node:path");
const vm = require("node:vm");

const context = vm.createContext({ structuredClone, uid: randomUUID });
for (const filename of ["performance.js", "routines.js"]) {
  vm.runInContext(fs.readFileSync(path.join(__dirname, "..", filename), "utf8"), context);
}
const { saveRoutine, findRoutine, deleteRoutine, copyExercises } = context;
const entry = () => ({
  kind: "rehab", note: "그날의 메모", recordedAthlete: { animal: "dog", sport: "basic" },
  exercises: [{ id: "old", name: " 로우 ", equipment: "케이블", unit: "회", restSeconds: "60", note: "힘듦",
    sets: [{ id: "set", side: "왼쪽", kg: "20", amount: "12" }, { side: "오른쪽", kg: "22.5", amount: "8" }] }]
});

test("a v1 journal's first routine is its default and saves independent normalized sets", () => {
  const original = entry();
  const book = { entries: [original] };
  assert.equal(findRoutine(book, book.defaultRoutineID), undefined);
  saveRoutine(book, " 아침 운동 ", original);
  const saved = findRoutine(book, book.defaultRoutineID);
  assert.equal(saved.name, "아침 운동");
  assert.equal(saved.kind, "rehab");
  assert.equal(saved.recordedAthlete, undefined);
  assert.equal(saved.note, undefined);
  const [row] = saved.exercises;
  assert.deepEqual([row.name, row.id, row.equipment, row.note, row.restSeconds], ["로우", undefined, "케이블", "", 60]);
  assert.deepEqual(row.sets, [{ side: "왼쪽", kg: 20, amount: 12 }, { side: "오른쪽", kg: 22.5, amount: 8 }]);
  const [copy] = copyExercises(saved.exercises);
  copy.sets[0].kg = 25;
  assert.equal(row.sets[0].kg, 20);
  assert.deepEqual(book.entries, [entry()]);
});

test("additional routines, edits, clearing and deletion preserve the user's chosen default", () => {
  const book = {};
  saveRoutine(book, "아침", entry());
  const first = book.defaultRoutineID;
  saveRoutine(book, "저녁", entry());
  const second = book.routines[1].id;
  assert.equal(book.defaultRoutineID, first);
  book.defaultRoutineID = second;
  saveRoutine(book, "저녁 B", entry(), second);
  const restored = JSON.parse(JSON.stringify(book));
  assert.equal(findRoutine(restored, restored.defaultRoutineID).name, "저녁 B");
  deleteRoutine(restored, first);
  assert.equal(restored.defaultRoutineID, second);
  restored.defaultRoutineID = null;
  saveRoutine(restored, "추가", entry());
  assert.equal(restored.defaultRoutineID, null);
  restored.defaultRoutineID = second;
  deleteRoutine(restored, second);
  assert.equal(restored.defaultRoutineID, null);
  assert.deepEqual(restored.routines.map(r => r.name), ["추가"]);
});

test("invalid saves do not change a template, and historical drills copy as ordinary sets", () => {
  const book = {};
  const legacy = entry();
  legacy.exercises[0].drill = { sport: "running", meters: 80 };
  saveRoutine(book, "달리기", legacy);
  const row = book.routines[0].exercises[0];
  assert.equal(row.drill, undefined);
  assert.equal(row.unit, "m");
  assert.equal(row.sets[0].amount, 80);
  assert.equal(legacy.exercises[0].drill.meters, 80);
  const before = JSON.stringify(book);
  const invalid = entry();
  invalid.exercises[0].sets[1].amount = 0;
  assert.throws(() => saveRoutine(book, "수정", invalid, book.defaultRoutineID), /수행량/);
  assert.throws(() => saveRoutine(book, " ", entry()), /루틴 이름/);
  assert.throws(() => saveRoutine(book, "휴식", { kind: "rest", exercises: [] }), /훈련 또는 재활/);
  assert.throws(() => saveRoutine(book, "누락", entry(), "missing"), /찾을 수 없/);
  assert.equal(JSON.stringify(book), before);
});
