import { test } from "node:test";
import assert from "node:assert/strict";
import { loadCore, loadMechanisms, listJson, readJson } from "../tools/lib/load-core.mjs";

const TM = loadCore(["tilemodel"]).tilemodel;
loadMechanisms();
const spec = (map, devices = [], extra = {}) => ({ id: "LV03-test", map, devices, ...extra });
const count = (s, t) => [...s.terrain].filter((n) => n === t).length;
const run = (source, actions) => {
  const { level, state } = TM.parse(source);
  for (const action of actions) assert.ok(TM.act(level, state, action).ok, action);
  return { level, state };
};

test("LV03 registers all eight mechanisms without claiming unrelated mechanisms", () => {
  const mechanisms = ["acid", "etch_tag", "gas_rise", "gas_sink", "lifetime", "vine", "bounce", "seesaw"];
  assert.deepEqual(TM.unknownMechanisms({ mechanisms }), []);
  assert.ok(TM.unknownMechanisms({ mechanisms: ["not_a_real_mechanism"] }).includes("not_a_real_mechanism"));
});

test("acid: sealed source waits for excavation, consumes one acid per tagged rock and leaves hard rock", () => {
  const source = spec(["########", "#.aae.P#", "##RRL###", "####M###", "####X###", "########"]);
  const initial = TM.parse(source);
  assert.equal(count(initial.state, TM.T.LIME_A), 1);
  const { state } = run(source, ["L", "DIG_L"]);
  assert.equal(count(state, TM.T.ACID), 0);
  assert.equal(count(state, TM.T.LIME_A) + count(state, TM.T.LIME_B), 0);
  assert.equal(count(state, TM.T.HARD), 2);
});

test("acid: insufficient reagent does not silently clear a second tagged rock", () => {
  const { state } = TM.parse(spec(["######", "#Pa###", "##L###", "##M###", "######"]));
  assert.equal(count(state, TM.T.ACID), 0);
  assert.equal(count(state, TM.T.LIME_A) + count(state, TM.T.LIME_B), 1);
});

test("gas: smoke rises through an open connected volume and conserves quantity", () => {
  const { state } = TM.parse(spec(["########", "###..###", "###.####", "#P#^^###", "########"]));
  assert.equal(count(state, TM.T.SMOKE), 2);
  assert.equal(state.terrain[1 * 8 + 3], TM.T.SMOKE);
  assert.equal(state.terrain[1 * 8 + 4], TM.T.SMOKE);
});

test("gas: fog sinks, cannot replace water, and a closed gate blocks gas", () => {
  const source = spec(["########", "#P#vv###", "###.|###", "###~.###", "########"], [], { links: [{ plates: [], doors: [[4, 2]] }] });
  const { state } = TM.parse(source);
  assert.equal(count(state, TM.T.FOG), 2);
  assert.equal(state.terrain[2 * 8 + 3], TM.T.FOG);
  assert.equal(state.terrain[3 * 8 + 3], TM.T.WATER);
  assert.equal(state.terrain[3 * 8 + 4], TM.T.EMPTY);
});

test("lifetime: ordinary actions preserve static plug; release contracts the complete fixed phase once", () => {
  const source = spec(["########", "###s####", "###p####", "#P.....#", "###.####", "########"], [
    { type: "release", cells: [[3, 2]], to: "plug_decay", phase_ticks: 180 },
    { type: "lever", at: [2, 3], action: { release: 0 } },
  ]);
  const { level, state } = run(source, ["R"]);
  assert.equal(count(state, TM.T.PLUG), 1);
  assert.ok(TM.act(level, state, "U").ok);
  assert.equal(count(state, TM.T.PLUG), 0);
  assert.equal(count(state, TM.T.SAND), 1);
  const before = state.terrain.slice();
  assert.ok(TM.act(level, state, "U").ok);
  assert.deepEqual(state.terrain, before);
});

test("vine: root water latches state-aware climb cells, never leaks growth into a cloned dry branch", () => {
  const source = spec(["#######", "###X###", "###.###", "#P..###", "###.###", "#######"], [
    { type: "vine", root: [3, 4], height: 4, need: 256 },
  ]);
  const { level, state: dry } = TM.parse(source);
  const wet = TM.clone(dry);
  wet.terrain[4 * 7 + 3] = TM.T.WATER;
  TM.settle(level, wet);
  assert.equal(wet.dev[0], 1);
  assert.equal(dry.dev[0], 0);
  dry.player = { x: 3, y: 3 };
  wet.player = { x: 3, y: 3 };
  assert.equal(TM.act(level, dry, "U").ok, false);
  assert.equal(TM.act(level, wet, "U").ok, true);
  wet.terrain[4 * 7 + 3] = TM.T.EMPTY;
  TM.settle(level, wet);
  assert.equal(wet.dev[0], 1);
});

test("bounce: a real downward arrival launches two cells to a stable ladder, horizontal arrival does not", () => {
  const falling = spec(["#######", "###H###", "#P..###", "###.###", "###.###", "#######"], [{ type: "bounce", at: [3, 4], height: 2 }]);
  const { state } = run(falling, ["R", "R"]);
  assert.deepEqual(state.player, { x: 3, y: 1 });
  const flat = spec(["#######", "###H###", "###.###", "#P..###", "#######"], [{ type: "bounce", at: [3, 4], height: 2 }]);
  const r = run(flat, ["R", "R"]);
  assert.deepEqual(r.state.player, { x: 3, y: 3 });
});

test("bounce: blocked sweep refuses launch and repeated settling does not create a loop", () => {
  const source = spec(["#######", "#######", "#P..###", "###.###", "###.###", "#######"], [{ type: "bounce", at: [3, 4], height: 2 }]);
  const { level, state } = run(source, ["R", "R"]);
  assert.deepEqual(state.player, { x: 3, y: 3 });
  TM.settle(level, state);
  assert.deepEqual(state.player, { x: 3, y: 3 });
});

const board = (blocked = false) => spec([
  "###########", "###########", "###o.#..I.#", "####.#.####", "####B#.####", "####.#.####", "###########",
], [{ type: "seesaw", ends: [[4, 5], [6, 5]], height: 2, threshold: 1, landings: [[3, 2], [7, 2]] }]);

test("seesaw: initial loads are a baseline; a new falling iron crate launches the opposite box once", () => {
  const source = board();
  source.map[2] = "###o.#..IP#";
  const { level, state } = TM.parse(source);
  assert.deepEqual([state.crates[0].x, state.crates[0].y], [8, 2]);
  assert.deepEqual([state.crates[1].x, state.crates[1].y], [4, 4]);
  assert.ok(TM.act(level, state, "L").ok);
  assert.ok(TM.act(level, state, "L").ok);
  const box = state.crates.find((c) => c.kind === "wood");
  assert.deepEqual([box.x, box.y], [3, 2]);
  const clone = TM.clone(state);
  TM.settle(level, state);
  assert.deepEqual(state.crates, clone.crates);
});

test("seesaw: a blocked vertical sweep preserves both crates and consumes the arrival event", () => {
  const source = board();
  source.map[2] = "###o.#..IP#";
  source.map[3] = "######.####";
  const { level, state } = run(source, ["L", "L"]);
  assert.equal(state.crates.length, 2);
  assert.deepEqual([state.crates.find((c) => c.kind === "wood").x, state.crates.find((c) => c.kind === "wood").y], [4, 4]);
  TM.settle(level, state);
  assert.equal(TM.won(level, state), false);
});

test("LV03 candidates meet author route and quality budgets in the design model", () => {
  for (const file of listJson("content/levels/lab/react")) {
    const source = readJson(file);
    const author = TM.replay(source, source.solution);
    assert.ok(author.won, source.id + " author solution");
    const minimum = source.order <= 2 ? 6 : source.id === "G10" ? 10 : 8;
    const maximum = source.order <= 2 ? 10 : source.id === "G10" ? 16 : 14;
    assert.ok(source.solution.length >= minimum && source.solution.length <= maximum, source.id + " budget");
    assert.deepEqual(TM.unknownMechanisms(source), [], source.id + " known mechanisms");
    assert.ok(source.discovery && source.idea, source.id + " discovery and bait/order");
  }
});
