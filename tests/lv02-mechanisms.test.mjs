// LV-02 behaviour tests. Fixtures stay in memory; no approval or art files change.
import { test } from 'node:test';
import assert from 'node:assert/strict';
import { loadCore, loadMechanisms } from '../tools/lib/load-core.mjs';
const TM = loadCore(['tilemodel']).tilemodel;
loadMechanisms();

// Catches a fuse being treated as a wall, or the first blast directly opening a remote wall.
test('fuse relays a blast through connected cells, but not across a gap', () => {
  const spec = { id: 'LV02-fuse', mechanisms: ['fuse'], bag: { bomb: 1 },
    map: ['############', '############', '#P.fff%f%X##', '############'] };
  const { level: L, state: s } = TM.parse(spec);
  assert.ok(TM.act(L, s, 'BOMB_R').ok);
  assert.equal(s.terrain[2 * L.w + 6], TM.T.EMPTY, 'remote cracked wall reached by the last connected fuse');
  assert.equal(s.terrain[2 * L.w + 7], TM.T.FUSE, 'isolated fuse is not reached through the cracked-wall gap');
  assert.equal(s.terrain[2 * L.w + 8], TM.T.CRACKED);
});

// Catches unbounded chain recursion and missing secondary explosion hooks.
test('each fuse burns once and a secondary blast peels a nearby nested box once', () => {
  const spec = { id: 'LV02-fuse-nest', bag: { bomb: 1 },
    map: ['##########', '######B###', '#P.ffff###', '##########'],
    devices: [{ type: 'nested_box', at: [6, 1], layers: ['wood', 'wood', 'wood'] }] };
  const r = TM.replay(spec, ['BOMB_R']);
  assert.equal(r.steps.at(-1).state.crates[0].nest, 2);
  assert.equal([...r.steps.at(-1).state.terrain].filter(t => t === TM.T.FUSE).length, 0);
});

const cart = (overhead = '#####B...o##', rail = '#P........##') => ({
  id: 'LV02-cart', mechanisms: ['mine_cart'],
  map: ['############', '############', '############', overhead, rail, '############'],
  devices: [{ type: 'mine_cart', at: [5, 4], track: [[5, 4], [6, 4], [7, 4], [8, 4], [9, 4]], width: 1 }],
});

// Catches the cart falling, moving only one tile, or teleporting the pusher with its cargo.
test('one side push sweeps the cart and cargo to the rail end; the pusher follows one tile', () => {
  const spec = cart();
  const r = TM.replay(spec, ['R', 'R', 'R', 'R']);
  assert.equal(r.won, true);
  assert.deepEqual(r.steps.at(-1).state.player, { x: 5, y: 4 });
  assert.deepEqual([r.steps.at(-1).state.crates[0].x, r.steps.at(-1).state.crates[0].y], [9, 3]);
  assert.equal(r.steps.at(-1).state.dev[0], 4);
});

// Catches the cart checking only its destination and passing through intermediate obstructions.
test('cart stops before a deck obstacle and before an obstacle at cargo height', () => {
  for (const spec of [cart('#####B...o##', '#P.....%..##'), cart('#####B.#.o##')]) {
    const r = TM.replay(spec, ['R', 'R', 'R', 'R']);
    assert.equal(r.steps.at(-1).state.dev[0], 1);
    assert.deepEqual([r.steps.at(-1).state.crates[0].x, r.steps.at(-1).state.crates[0].y], [6, 3]);
  }
});

// Catches an attempted push consuming a turn, and clone/undo losing cart position.
test('a blocked cart push is rejected without spending a turn; clones preserve the whole roll', () => {
  const spec = cart('#####B...o##', '#P....%...##');
  const { level: L, state: s } = TM.parse(spec);
  for (const a of ['R', 'R', 'R']) assert.ok(TM.act(L, s, a).ok);
  const before = TM.clone(s);
  assert.equal(TM.act(L, s, 'R').ok, false);
  assert.deepEqual(s, before);
  assert.deepEqual(TM.unknownMechanisms(spec), []);
});

// Catches a direction/index assumption on descending tracks, and endpoint overrun.
test('cart can roll left on a track listed right-to-left', () => {
  const spec = { id: 'LV02-left', map: ['##########', '##########', '###o..B###', '#......P.#', '##########'],
    devices: [{ type: 'mine_cart', at: [6, 3], track: [[6, 3], [5, 3], [4, 3], [3, 3]], width: 1 }] };
  const r = TM.replay(spec, ['L']);
  assert.equal(r.won, true);
  assert.deepEqual(r.steps.at(-1).state.player, { x: 6, y: 3 });
  assert.equal(r.steps.at(-1).state.dev[0], 3);
});

// Catches a change to the core cross-shaped blast footprint or gravel's blast resistance.
test('a solid blast centre does not shield cracked rock; gravel is conserved in a narrow shaft', () => {
  const spec = { id: 'LV02-core-blast', bag: { bomb: 1 }, map: [
    '########', '#####g##', '###P#%##', '#####.##', '#####.##', '########',
  ] };
  const r = TM.replay(spec, ['BOMB_R']);
  const s = r.steps.at(-1).state;
  assert.equal(s.terrain[2 * 8 + 4], TM.T.ROCK);
  assert.equal(s.terrain[4 * 8 + 5], TM.T.GRAVEL);
  assert.equal([...s.terrain].filter(t => t === TM.T.GRAVEL).length, 1);
});
