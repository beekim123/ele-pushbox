// LV-04 chapter quality regression. Serial, bounded tile-model searches only.
import { test } from 'node:test';
import assert from 'node:assert/strict';
import { loadCore, loadMechanisms, readJson } from '../tools/lib/load-core.mjs';
const TM = loadCore(['tilemodel']).tilemodel;
loadMechanisms();
for (const [index, id] of ['F01', 'F02', 'F03', 'F04', 'F07', 'F08', 'F09'].entries()) {
  test(`LV04 ${id}: author, shortest, dead ends and discovery stay within the chapter contract`, () => {
    const s = readJson(`content/levels/lab/thermal/${id}.json`);
    assert.ok(s.discovery.length > 12 && s.idea.length > 12);
    assert.deepEqual(TM.unknownMechanisms(s), []);
    const author = TM.replay(s, s.solution);
    assert.ok(author.won, `${id} author failed at ${author.failedAt}: ${author.reason}`);
    const [min, max] = index < 2 ? [6, 10] : id === 'F09' ? [10, 16] : [8, 14];
    assert.ok(s.solution.length >= min && s.solution.length <= max, `${id} author steps ${s.solution.length}`);
    const shortest = TM.solve(s, 80000);
    assert.ok(shortest.solved, `${id} shortest search capped/exhausted at ${shortest.explored}`);
    assert.ok(s.solution.length - shortest.solution.length < 2, `${id}: author ${s.solution.length}, shortest ${shortest.solution.length}`);
    const dead = TM.deadEnds(s, 80000);
    assert.ok(dead.complete, `${id} dead-end enumeration capped at ${dead.states}`);
    if (index >= 2) assert.ok(dead.dead > 0, `${id} must have a meaningful irreversible mistake`);
  });
}
