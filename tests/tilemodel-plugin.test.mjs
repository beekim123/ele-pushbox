// Tile-model plugin interface tests (workbench/js/core/tilemodel.js + core/mech/*.js).
// Pure in-memory specs; nothing is written to the repository.
import { test } from "node:test";
import assert from "node:assert/strict";
import { loadCore, loadMechanisms } from "../tools/lib/load-core.mjs";

const PB = loadCore(["tilemodel"]);
const TM = PB.tilemodel;
const loaded = loadMechanisms();

const lantern = (map, cells, solution) => ({ id: "T", map, devices: [{ type: "lantern_reveal", cells }], goals: [], solution });
const Q08 = () => lantern(["############", "############", "############", "#.P..B.....#", "######.#####", "######o#####", "############"], [[6, 4]]);
const Q09 = (accept) => ({ id: "T", mechanisms: ["nested_box"], bag: { bomb: 1 },
  map: ["############", "############", "############", "#P...B..o..#", "############"],
  devices: [{ type: "nested_box", at: [5, 3], layers: ["wood", "wood"] }],
  goals: [{ type: "socket", at: [8, 3], accept }] });

test("plugin files are discovered and registered", () => {
  assert.ok(loaded.includes("lantern_reveal") && loaded.includes("nested_box"));
  assert.deepEqual(TM.plugins.map((p) => p.id).sort(), loaded.slice().sort());
});

test("register rejects a plugin without id and a taken char; loading twice is harmless", () => {
  assert.throws(() => TM.register({}), /id/);
  assert.throws(() => TM.register({ id: "x_clash", chars: { "#": {} } }), /taken/);
  const n = TM.plugins.length;
  loadMechanisms();
  assert.equal(TM.plugins.length, n);
});

test("a registered plugin adds chars, device init, settle, solid, key", () => {
  TM.register({ id: "t_pad", device: "t_pad", chars: { "Z": { m: 0, t: 0 } },
    init: () => 5, settle: () => false, solid: () => false, key: () => "pad" });
  const spec = { id: "T", mechanisms: ["t_pad"], map: ["####", "#PZ#", "####"], devices: [{ type: "t_pad" }] };
  const { state } = TM.parse(spec);
  assert.equal(state.dev[0], 5);
  assert.deepEqual(TM.unknownMechanisms(spec), []);
});

test("unknownMechanisms lists mechanisms and device types nothing models", () => {
  assert.deepEqual(TM.unknownMechanisms({ mechanisms: ["push", "lever", "test_missing_mechanism"], devices: [{ type: "lever" }, { type: "test_missing_device" }] }), ["test_missing_mechanism", "test_missing_device"]);
  assert.deepEqual(TM.unknownMechanisms({ mechanisms: ["lantern_reveal", "nested_box"], devices: [{ type: "nested_box" }] }), []);
});

test("lantern_reveal: box rests on the lit plank, falls when the player steps away", () => {
  const spec = Q08();
  const r = TM.replay(spec, ["R", "R", "R"]);
  assert.ok(!r.failedAt);
  const s3 = r.steps[3].state;
  assert.deepEqual([s3.crates[0].x, s3.crates[0].y], [6, 3]); // held at distance^2 = 2
  const r4 = TM.replay(spec, ["R", "R", "R", "L"]);
  assert.ok(r4.won);
  assert.deepEqual(TM.solve(spec).solution, ["R", "R", "R", "L"]); // no shortcut: without the plugin it is 3 steps
});

test("lantern_reveal: exactly 2 tiles lights the plank, 3 does not", () => {
  const spec = lantern(["######", "#PB..#", "######"], [[3, 1]]);
  // player at x=1, plank at x=3: distance 2 -> solid
  const { level: L, state: s } = TM.parse(spec);
  assert.equal(s.dev[0], 1);
  s.player.x = 0; // distance 3
  TM.settle(L, s);
  assert.equal(s.dev[0], 0);
});

test("nested_box: a bomb peels one layer per explosion; both layers need two bombs", () => {
  const spec = Q09({ nested_layers: 1 });
  const { level: L, state } = TM.parse(spec);
  assert.equal(state.crates[0].nest, 2);
  for (const a of ["R", "R", "R", "BOMB_R"]) assert.ok(TM.act(L, state, a).ok, a);
  assert.equal(state.crates[0].nest, 1);
  assert.equal(state.bag.bomb, 0);
  assert.equal(TM.act(L, state, "BOMB_R").ok, false); // no bomb left; layer count unchanged
  assert.equal(state.crates[0].nest, 1);
});

test("nested_box: the author solution wins, the unpeeled box does not light the slot", () => {
  const spec = Q09({ nested_layers: 1 });
  assert.ok(TM.replay(spec, ["R", "R", "R", "BOMB_R", "R", "R", "R"]).won);
  assert.ok(!TM.replay(spec, ["R", "R", "R", "R", "R", "R", "R"]).won);
  assert.equal(TM.solve(spec).solution.length, 7);
  // without accept the unpeeled box lights the socket (ordinary rule)
  assert.ok(TM.replay(Q09(undefined), ["R", "R", "R", "R", "R", "R"]).won);
});

test("nested_box: undo-style clone keeps layers; state key distinguishes layer counts", () => {
  const { level: L, state } = TM.parse(Q09({ nested_layers: 1 }));
  const copy = TM.clone(state);
  for (const a of ["R", "R", "R", "BOMB_R"]) TM.act(L, state, a);
  assert.equal(copy.crates[0].nest, 2);
  assert.equal(state.crates[0].nest, 1);
});

test("chapter 1 and 2 models are untouched by plugins (author solutions still win)", async () => {
  const { listJson, readJson } = await import("../tools/lib/load-core.mjs");
  let n = 0;
  for (const rel of listJson("content/levels/lab/basics").concat(listJson("content/levels/lab/water"))) {
    const spec = readJson(rel);
    assert.ok(TM.replay(spec, spec.solution).won, spec.id); n++;
  }
  assert.equal(n, 16);
});

test('mechanism plugins leave approved showcase illustration parsing unchanged', async () => {
  const fs = await import('node:fs'); const vm = await import('node:vm');
  const context = vm.createContext({});
  vm.runInContext(fs.readFileSync(new URL('../workbench/js/core/tilemodel.js', import.meta.url),'utf8'),context);
  const spec = {id:'showcase.test',showcase:true,map:['#######','#Ppb..#','#######'],devices:[{type:'release',cells:[[2,1]],to:'plug_decay'}]};
  const original = context.PB.tilemodel.parse(spec), current = TM.parse(spec);
  assert.equal(JSON.stringify(current.state),JSON.stringify(original.state));
  assert.equal(JSON.stringify(TM.goals(current.level,current.state)),JSON.stringify(context.PB.tilemodel.goals(original.level,original.state)));
});
