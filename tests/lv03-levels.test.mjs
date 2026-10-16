import { test } from "node:test";
import assert from "node:assert/strict";
import { loadCore, loadMechanisms, listJson, readJson } from "../tools/lib/load-core.mjs";

const TM = loadCore(["tilemodel"]).tilemodel;
loadMechanisms();
const sources = listJson("content/levels/lab/react").map(readJson);

// Continue a deliberately wrong route using the real public action API. Omit
// moves (a display counter) so a walk cycle cannot create infinitely many keys.
function canStillWin(level, initial, budget = 3000) {
  const key = (s) => JSON.stringify([s.player, [...s.terrain], s.crates, s.bag, s.open, s.dev, s.held, s.warped]);
  const queue = [initial], seen = new Set([key(initial)]);
  for (let i = 0; i < queue.length; i++) {
    const state = queue[i];
    if (TM.won(level, state)) return true;
    for (const action of TM.ACTIONS) {
      const next = TM.clone(state);
      if (!TM.act(level, next, action).ok) continue;
      const value = key(next);
      if (seen.has(value)) continue;
      seen.add(value); queue.push(next);
      assert.ok(seen.size <= budget, "wrong-route continuation exceeded its test budget");
    }
  }
  return false;
}

for (const [id, actions, reason] of [
  ["G02", ["L", "L", "L", "L", "L", "DIG_L"], "bottom outlet wastes reagent on the decoy rock"],
  ["G03", ["L", "L", "L", "L", "DIG_L", "L"], "following smoke down loses the separate exit"],
  ["G04", ["L", "L", "DIG_D"], "the tempting floor plug opens a sealed water pit"],
  ["G06", ["L", "L", "L", "L", "L", "DIG_L"], "left outlet drains water away from the root"],
  ["G08", ["D", "D"], "the near well has no mushroom"],
  ["G10", ["DIG_L", "U", "U", "R", "R", "R", "R", "D", "D", "L", "L", "L"], "the player can launch the box but cannot return to the exit"],
]) test(id + ": real bait route is a dead end - " + reason, () => {
  const source = sources.find((s) => s.id === id), { level, state } = TM.parse(source);
  for (const action of actions) assert.ok(TM.act(level, state, action).ok, id + ": " + action);
  assert.equal(canStillWin(level, state), false, reason);
});

for (const source of sources) test(source.id + ": author route, shortest route, and complete dead-end graph", () => {
  const author = TM.replay(source, source.solution);
  assert.ok(author.won, source.id + " author route");
  const best = TM.solve(source, 30000);
  assert.ok(best.solved, source.id + " solve must not hit the 30000-state test budget");
  assert.ok(source.solution.length - best.solution.length < 2, source.id + " shortcut " + best.solution.join(","));
  const graph = TM.deadEnds(source, 30000);
  assert.ok(graph.complete, source.id + " graph must be complete");
  if (source.order > 2) assert.ok(graph.dead > 0, source.id + " non-introduction needs an irreversible mistake");
});

test("G05: firing the lifetime stage before loading the lift cannot be repaired by toggling again", () => {
  const source = sources.find((s) => s.id === "G05"), { level, state } = TM.parse(source);
  for (const action of ["R", "U", "U"]) assert.ok(TM.act(level, state, action).ok, action);
  assert.equal(state.dev[3], 1);
  for (const action of ["L", "L", "L", "L", "L"]) TM.act(level, state, action);
  assert.equal(TM.won(level, state), false);
  assert.equal(canStillWin(level, state), false);
});

test("G09: opening clearance after a blocked arrival does not replay the same seesaw impact", () => {
  const source = sources.find((s) => s.id === "G09"), { level, state } = TM.parse(source);
  for (const action of source.solution.slice(1, -2)) assert.ok(TM.act(level, state, action).ok, action);
  assert.equal(TM.goals(level, state).find((g) => g.kind === "socket").lit, false);
  state.dev[1] = 1; // isolated game-layer lever state, then settle without another fall
  TM.settle(level, state);
  assert.equal(TM.goals(level, state).find((g) => g.kind === "socket").lit, false);
  assert.equal(canStillWin(level, state), false);
});

test("G10: dug sand cannot be poured from the starting shore; the far plate opens its inlet", () => {
  const source = sources.find((s) => s.id === "G10"), { level, state } = TM.parse(source);
  assert.ok(TM.act(level, state, "DIG_L").ok);
  assert.equal(state.bag.sand, 1);
  assert.equal(TM.act(level, state, "POUR_R").ok, false);
  for (const action of source.solution.slice(1, 11)) assert.ok(TM.act(level, state, action).ok, action);
  assert.deepEqual(state.player, { x: 7, y: 4 });
  assert.ok(TM.act(level, state, "POUR_L").ok);
  assert.equal(state.bag.sand, 0);
  assert.equal(TM.goals(level, state).find((g) => g.kind === "socket").lit, true);
});
