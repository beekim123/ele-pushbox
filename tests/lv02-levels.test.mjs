import { test } from 'node:test';
import assert from 'node:assert/strict';
import { loadCore, loadMechanisms, readJson } from '../tools/lib/load-core.mjs';
const TM = loadCore(['tilemodel']).tilemodel;
loadMechanisms();
const IDS = ['Q01', 'Q02', 'Q03', 'Q04', 'Q07', 'Q08', 'Q09', 'Q10'];

// Catches an author path bypassing the lesson, padding a shorter solution, or
// leaving an irreversible mechanism without a reachable losing choice.
for (const [i, id] of IDS.entries()) test(`${id} meets LV-02 step/solvability/trap quality gates`, () => {
  const spec = readJson(`content/levels/lab/blast/${id}.json`);
  const min = i < 2 ? 6 : i === 7 ? 10 : 8;
  const max = i < 2 ? 10 : i === 7 ? 16 : 14;
  assert.ok(spec.solution.length >= min && spec.solution.length <= max, `${spec.solution.length} is outside ${min}–${max}`);
  assert.ok(spec.discovery && spec.idea, 'discovery and the choice/order must be explicit');
  assert.equal(TM.replay(spec, spec.solution).won, true, 'author path');
  assert.deepEqual(TM.unknownMechanisms(spec), []);
  const shortest = TM.solve(spec, 30000);
  assert.equal(shortest.solved, true, 'shortest search must finish');
  assert.ok(spec.solution.length - shortest.solution.length < 2, 'unplanned shortcut');
  const dead = TM.deadEnds(spec, 30000);
  assert.equal(dead.complete, true, 'dead-state census must finish');
  if (i >= 2) assert.ok(dead.dead > 0, 'non-intro rooms have an irreversible wrong choice');
});

// Search the actual post-mistake state. This catches a trap that merely looks
// irreversible in prose while a route can recover it in the real design model.
const lures = {
  Q01: ['R', 'R', 'BOMB_R'],
  Q02: ['R', 'R', 'U', 'U', 'BOMB_R'],
  Q03: ['BOMB_L'],
  Q04: ['R', 'R', 'R', 'BOMB_R', 'L', 'U', 'U', 'BOMB_R'],
  Q07: ['R', 'R', 'D', 'D', 'R', 'R'],
  Q08: ['L'],
  Q09: ['R', 'R', 'U', 'U', 'U', 'R', 'BOMB_R', 'R', 'R'],
  Q10: ['R', 'R', 'R', 'BOMB_D'],
};
for (const [id, actions] of Object.entries(lures)) test(`${id} visible lure is an actual unrecoverable choice`, () => {
  const spec = readJson(`content/levels/lab/blast/${id}.json`);
  const replay = TM.replay(spec, actions);
  assert.equal(replay.reason, undefined, 'the lure must be a legal choice');
  const L = replay.level, start = replay.steps.at(-1).state;
  const key = s => JSON.stringify({ ...s, moves: 0 });
  const queue = [start], seen = new Set([key(start)]);
  for (let head = 0; head < queue.length; head++) {
    const s = queue[head];
    assert.equal(TM.won(L, s), false, 'the supposed lure must not recover a win');
    for (const action of TM.ACTIONS) {
      const n = TM.clone(s);
      if (!TM.act(L, n, action).ok) continue;
      const k = key(n);
      if (!seen.has(k)) { seen.add(k); queue.push(n); }
    }
    assert.ok(seen.size < 5000, 'lure census must finish below its bound');
  }
});
