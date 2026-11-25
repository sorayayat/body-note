const { test } = require("node:test");
const assert = require("node:assert/strict");
const fs = require("node:fs");
const path = require("node:path");
const vm = require("node:vm");

const preview = path.resolve(__dirname, "..");
const context = vm.createContext({});
for (const script of ["exercise-catalog-data.js", "exercise-library.js"]) {
  vm.runInContext(fs.readFileSync(path.join(preview, script), "utf8"), context);
}
const ids = (query, region) => Array.from(context.searchCatalog(query, region), item => item.id);

test("offline preview uses the same data as the iPhone app", () => {
  const file = path.join(preview, "../BodyNoteCore/Sources/BodyNoteCore/Resources/exercise-catalog.json");
  assert.deepEqual(JSON.parse(vm.runInContext("JSON.stringify(exerciseCatalog)", context)),
    JSON.parse(fs.readFileSync(file, "utf8")));
});

test("canonical names lead aliases, related terms and body-region matches", () => {
  assert.deepEqual(ids("플랭"), ["plank", "side-plank"]);
  assert.equal(ids("  스퀏 ")[0], "bodyweight-squat");
  assert.equal(ids("ＳＱＵＡＴ")[0], "bodyweight-squat");
  assert.equal(ids(" side-PLANK ")[0], "side-plank");
  assert.deepEqual(ids("등 밴드", "어깨"), ["band-pull-apart"]);
  assert.equal(ids("무릎 펴기", "하체")[0], "leg-extension");
  assert.deepEqual(ids("팔굽혀", "코어"), []);
  assert.deepEqual(ids("???"), []);
  assert.ok(ids("", "무릎").includes("wall-sit"));
});
