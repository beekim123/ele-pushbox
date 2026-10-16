// LV-04: in-memory mechanism contracts, with no writes to art or approvals.
import { test } from 'node:test';
import assert from 'node:assert/strict';
import { loadCore, loadMechanisms } from '../tools/lib/load-core.mjs';
const TM = loadCore(['tilemodel']).tilemodel;
loadMechanisms();
const spec = (map, mechanisms, devices = [], bag = {}) => ({ id: 'LV04-TEST', map, mechanisms, devices, bag });
const terrain = (r, x, y, step = r.steps.length - 1) => r.steps[step].state.terrain[y * r.level.w + x];
const lever = (at, device = 0) => ({ type: 'lever', at, action: { device } });

test('LV04 registers all six thermal mechanisms and their device contracts', () => {
  assert.deepEqual(TM.unknownMechanisms({ mechanisms: ['burn', 'freeze', 'melt', 'blast_ignite', 'ice_slide', 'gust'], devices: [{ type: 'torch' }, { type: 'frost_vent' }, { type: 'heat_vent' }, { type: 'gust' }] }), []);
});

test('burn consumes a torch pulse and burns connected wood, leaving crates and rock intact', () => {
  const s = spec(['#########', '#P...wwB#', '#########'], ['burn'], [{ type: 'torch', area: [5, 1, 1, 1], temperature: 6000, phase_ticks: 180 }, lever([1, 1])]);
  const r = TM.replay(s, ['U']);
  assert.equal(terrain(r, 5, 1), TM.T.EMPTY);
  assert.equal(terrain(r, 6, 1), TM.T.EMPTY);
  assert.equal(r.steps[1].state.crates.length, 1);
  assert.equal(terrain(r, 5, 2), TM.T.ROCK);
  assert.equal(r.steps[1].state.dev[0], 0);
});

test('burn respects the visible circle and does not claim low encoded temperature ignites wood', () => {
  const base = spec(['#########', '#P.....w#', '##...w..#', '#########'], ['burn'], [{ type: 'torch', area: [3, 1, 5, 2], temperature: 600, phase_ticks: 180 }, lever([1, 1])]);
  assert.equal(terrain(TM.replay(base, ['U']), 5, 2), TM.T.WOOD);
  base.devices[0].temperature = 6000;
  const r = TM.replay(base, ['U']);
  assert.equal(terrain(r, 5, 2), TM.T.EMPTY);
  assert.equal(terrain(r, 7, 1), TM.T.WOOD); // inside area rectangle, outside the circle
});

test('freeze and melt convert only their area; pulses reset, cell count and marker survive', () => {
  const s = spec(['########', '#P.....#', '###H~~##', '########'], ['freeze', 'melt'], [{ type: 'frost_vent', area: [3, 2, 2, 1] }, lever([1, 1]), { type: 'heat_vent', area: [3, 2, 2, 1] }, lever([2, 1], 2)]);
  s.water = [[3, 2]];
  const r = TM.replay(s, ['U', 'R', 'U']);
  assert.equal(terrain(r, 3, 2, 1), TM.T.ICE);
  assert.equal(terrain(r, 4, 2, 1), TM.T.ICE);
  assert.equal(terrain(r, 5, 2, 1), TM.T.WATER);
  assert.equal(terrain(r, 3, 2), TM.T.WATER);
  assert.equal(r.level.marker[2 * r.level.w + 3], TM.M.LADDER);
  assert.equal(r.steps[3].state.terrain.filter(t => t === TM.T.WATER).length, 3);
  assert.equal(r.steps[3].state.dev[0], 0);
  assert.equal(r.steps[3].state.dev[2], 0);
});

test('blast_ignite models adjacent inner-ring ignition and connected burn, not diagonal ignition', () => {
  const s = spec(['########', '#P.....#', '###ww###', '########'], ['blast_ignite'], [], { bomb: 1 });
  const r = TM.replay(s, ['R', 'BOMB_R']);
  assert.equal(terrain(r, 3, 2), TM.T.EMPTY);
  assert.equal(terrain(r, 4, 2), TM.T.EMPTY);
  const d = spec(['#######', '#P....#', '###w###', '#######'], ['blast_ignite'], [], { bomb: 1 });
  assert.equal(terrain(TM.replay(d, ['BOMB_R']), 3, 2), TM.T.WOOD);
});

test('ice_slide sweeps a pushed box, preserves the pusher, and stops at a wall or first dry tile', () => {
  const s = spec(['##########', '#PB....o##', '###iiiii##', '##########'], ['ice_slide']);
  const r = TM.replay(s, ['R']);
  assert.ok(r.won);
  assert.deepEqual([r.steps[1].state.player.x, r.steps[1].state.crates[0].x], [2, 7]);
  const dry = spec(['##########', '#PB.....o#', '###iii####', '##########'], ['ice_slide']);
  assert.equal(TM.replay(dry, ['R']).steps[1].state.crates[0].x, 6);
});

test('ice_slide does not slide walking people or unpushed boxes; occupied tiles stop the sweep', () => {
  const s = spec(['##########', '#P.B..I..#', '##iiiiiii#', '##########'], ['ice_slide']);
  const r = TM.replay(s, ['R', 'R']);
  assert.equal(r.steps[1].state.player.x, 2);
  assert.equal(r.steps[1].state.crates[0].x, 3);
  assert.equal(r.steps[2].state.crates[0].x, 5);
  assert.equal(r.steps[2].state.crates[1].x, 6);
});

test('gust never blows at parse, invalid actions or repeated settle; only light kinds move once', () => {
  const s = spec(['##########', '#PB..I...#', '##########'], ['gust'], [{ type: 'gust', area: [1, 1, 8, 1], direction: 'R', period: 1, phase: 0, light_kinds: ['wood'] }]);
  const { level: L, state } = TM.parse(s);
  assert.equal(state.crates[0].x, 2);
  assert.equal(TM.act(L, state, 'U').ok, false);
  TM.settle(L, state); TM.settle(L, state);
  assert.equal(state.crates[0].x, 2);
  assert.equal(TM.act(L, state, 'R').ok, true);
  assert.equal(state.crates[0].x, 4); // one player push + one gust
  assert.equal(state.crates[1].x, 5);
  TM.settle(L, state);
  assert.equal(state.crates[0].x, 4);
});

test('gust uses rollback-safe period/phase and acts after gravity has completed', () => {
  const s = spec(['#########', '#P.B....#', '###.....#', '#########'], ['gust'], [{ type: 'gust', area: [1, 2, 7, 1], direction: 'R', period: 2, phase: 0, light_kinds: ['wood'] }]);
  const r = TM.replay(s, ['R', 'L', 'R', 'L']);
  assert.deepEqual(r.steps.slice(0).map(v => v.state.crates[0].x), [3, 3, 4, 4, 5]);
  const restored = TM.clone(r.steps[1].state);
  assert.ok(TM.act(r.level, restored, 'L').ok);
  assert.equal(restored.crates[0].x, r.steps[2].state.crates[0].x);
  assert.equal(restored.dev[0], r.steps[2].state.dev[0]);
});
