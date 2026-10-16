import { test } from 'node:test';
import assert from 'node:assert/strict';
import { loadCore, loadMechanisms, readJson } from '../tools/lib/load-core.mjs';
const TM = loadCore(['tilemodel']).tilemodel;
loadMechanisms();
const ids = ['E01', 'E02', 'E03', 'E04', 'E05', 'E06'];
const chapters = Object.fromEntries(readJson('content/catalog/mechanisms.json').entries.map(m => [m.id, m.group]));
// Catalog layout is read without mutating it; use the established mechanism ids
// below for the two-chapter contract, independently from the authored prose.
for (const [i, id] of ids.entries()) test(`${id} is a solvable cross-chapter puzzle within its step budget`, () => {
  const spec = readJson(`content/levels/lab/experimental/${id}.json`);
  assert.equal(spec.mechanisms.length, 2, 'two primary mechanisms');
  assert.notEqual(chapters[spec.mechanisms[0]], chapters[spec.mechanisms[1]], 'mechanisms originate in different chapters');
  assert.ok(spec.discovery && spec.idea);
  const min = i < 2 ? 6 : i === 5 ? 10 : 8, max = i < 2 ? 10 : i === 5 ? 16 : 14;
  assert.ok(spec.solution.length >= min && spec.solution.length <= max, `${spec.solution.length} outside ${min}–${max}`);
  assert.equal(TM.replay(spec, spec.solution).won, true, 'author path');
  assert.deepEqual(TM.unknownMechanisms(spec), []);
  const best = TM.solve(spec, 30000);
  assert.equal(best.solved, true);
  assert.ok(spec.solution.length - best.solution.length < 2, 'unplanned shortcut');
  const dead = TM.deadEnds(spec, 30000);
  assert.equal(dead.complete, true);
  if (i >= 2) assert.ok(dead.dead > 0);
});

const replay = id => {
  const spec = readJson(`content/levels/lab/experimental/${id}.json`);
  return TM.replay(spec, spec.solution);
};
const at = (s, i = 0) => [s.crates[i].x, s.crates[i].y];

test('E01 the crate on the plate holds the door open, and the door is the dam that releases the acid', () => {
  const r = replay('E01'), w = r.level.w;
  assert.equal(r.steps[2].state.open[0], 0, 'door shut until the crate reaches the plate');
  assert.equal(r.steps[2].state.terrain[1 * w + 6], TM.T.ACID, 'acid still held above the door');
  assert.equal(r.steps[2].state.terrain[4 * w + 6], TM.T.LIME_A);
  assert.deepEqual(at(r.steps[3].state), [1, 2]);
  assert.equal(r.steps[3].state.open[0], 1);
  assert.equal(r.steps[3].state.terrain[4 * w + 6], TM.T.EMPTY, 'released acid etches the rock under the shaft');
  assert.equal([...r.steps[3].state.terrain].filter(t => t === TM.T.ACID).length, 0, 'one acid tile for one rock tile');
  assert.equal(r.steps.at(-1).state.open[0], 1);
});

test('E02 the box stays above the portal until the lamp retreats, then falls and teleports', () => {
  const r = replay('E02');
  assert.deepEqual(at(r.steps[8].state), [5, 3]);
  assert.equal(r.steps[8].state.dev[0], 1);
  assert.deepEqual(at(r.steps[9].state), [9, 3]);
  assert.equal(r.steps[9].state.dev[0], 0);
  assert.ok(r.steps[9].result.events.includes('crate-fall'));
  assert.ok(r.steps[9].result.events.includes('warp'));
});

test('E03 melt conserves one water tile at the root, whose grown vine reaches the high exit', () => {
  const r = replay('E03');
  assert.equal(r.steps[7].state.dev[2], 0);
  assert.equal(r.steps[7].state.terrain[4 * r.level.w + 4], TM.T.ICE);
  assert.equal(r.steps[8].state.dev[2], 1);
  assert.equal(r.steps[8].state.terrain[6 * r.level.w + 4], TM.T.WATER);
  assert.deepEqual(at(r.steps[8].state), [6, 3]);
  assert.deepEqual(r.steps.at(-1).state.player, { x: 6, y: 1 });
});

test('E04 bridge needs the crate and the gravel tile together before it overloads', () => {
  const r = replay('E04');
  assert.deepEqual(at(r.steps[2].state), [6, 5]);
  assert.equal(r.steps[4].state.dev[0], 0);
  assert.equal(r.steps[5].state.dev[0], 1);
  assert.deepEqual(at(r.steps[5].state), [6, 7]);
  assert.equal([...r.steps[5].state.terrain].filter(t => t === TM.T.GRAVEL).length, 1);
  assert.ok(r.steps[5].result.events.includes('bridge-break'));
});

test('E05 prepositioned cart catches the box only after the ice slide leaves the ledge', () => {
  const r = replay('E05');
  assert.equal(r.steps[4].state.dev[0], 5);
  assert.deepEqual(at(r.steps[4].state), [5, 3]);
  assert.deepEqual(at(r.steps.at(-1).state), [8, 5]);
  assert.deepEqual(r.steps.at(-1).state.player, { x: 5, y: 3 });
});

test('E06 the gate delays the gust until its falling crate can launch the prepared player', () => {
  const r = replay('E06');
  assert.deepEqual(at(r.steps[8].state), [2, 3]);
  assert.deepEqual(r.steps[8].state.player, { x: 6, y: 6 });
  assert.deepEqual(at(r.steps[9].state), [3, 6]);
  assert.deepEqual(r.steps[9].state.player, { x: 7, y: 4 });
  assert.ok(r.steps[9].result.events.includes('gust'));
  assert.ok(r.steps[9].result.events.includes('seesaw'));
});

const lures = {
  E02: ['L'],
  E03: ['R', 'U'],
  E04: ['R', 'U', 'BOMB_R'],
  E05: ['R', 'R', 'R'],
  E06: ['R', 'U'],
};
for (const [id, actions] of Object.entries(lures)) test(`${id} its tempting wrong order cannot recover a win`, () => {
  const spec = readJson(`content/levels/lab/experimental/${id}.json`), r = TM.replay(spec, actions);
  assert.equal(r.reason, undefined, 'mistake is a legal player choice');
  const L = r.level, start = r.steps.at(-1).state;
  const key = s => JSON.stringify({ ...s, moves: 0 });
  const queue = [start], seen = new Set([key(start)]);
  for (let head = 0; head < queue.length; head++) {
    const s = queue[head];
    assert.equal(TM.won(L, s), false, 'wrong order must not recover a win');
    for (const action of TM.ACTIONS) {
      const n = TM.clone(s);
      if (!TM.act(L, n, action).ok) continue;
      const k = key(n);
      if (!seen.has(k)) { seen.add(k); queue.push(n); }
    }
    assert.ok(seen.size < 5000, 'the recovery census must finish');
  }
});
