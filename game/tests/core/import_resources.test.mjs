import { test } from 'node:test';
import assert from 'node:assert/strict';
import fs from 'node:fs';
import os from 'node:os';
import path from 'node:path';
import crypto from 'node:crypto';
import { fileURLToPath } from 'node:url';

const SCRIPT = new URL('../../tools/import_resources.mjs', import.meta.url);
const REPO = path.resolve(path.dirname(fileURLToPath(import.meta.url)), '../../..');
const hash = (data) => crypto.createHash('sha256').update(data).digest('hex');
const write = (root, name, data) => {
  const target = path.join(root, name);
  fs.mkdirSync(path.dirname(target), { recursive: true });
  fs.writeFileSync(target, typeof data === 'string' || Buffer.isBuffer(data) ? data : JSON.stringify(data));
};
const read = (root, name) => JSON.parse(fs.readFileSync(path.join(root, name), 'utf8'));
async function implementation() {
  assert.ok(fs.existsSync(fileURLToPath(SCRIPT)), 'resource importer has not been implemented');
  return import(SCRIPT.href);
}
function fixture(t) {
  const root = fs.mkdtempSync(path.join(os.tmpdir(), 'portitor-import-'));
  t.after(() => fs.rmSync(root, { recursive: true, force: true }));
  const gameRoot = path.join(root, 'game');
  const png = Buffer.from('approved sprite fixture');
  const spec = JSON.stringify({ format: 'pushbox.levelspec/1', id: 'M01', mode: 'lab', group: 'basics', map: ['#####', '#@.E#', '#####'] });
  const approved = { version: 1, hash: 'a'.repeat(64), png: 'art/export/approved/obj.crate_wood@v1.png', png_sha256: hash(png) };
  const entries = [
    { uid: 'art:obj.crate_wood', domain: 'art', id: 'obj.crate_wood', game: 'res://generated/art/obj.crate_wood.tres', version: 1, hash: approved.hash, approved: true },
    { uid: 'art:ui.bubble', domain: 'art', id: 'ui.bubble', game: 'res://generated/art/ui.bubble.tres', version: 1, hash: 'b'.repeat(64), approved: false },
    { uid: 'art:theme.dungeon', domain: 'art', id: 'theme.dungeon', game: 'res://generated/themes/theme.dungeon.tres', version: 1, hash: 'c'.repeat(64), approved: true },
    { uid: 'art:ui.screen.hint', domain: 'art', id: 'ui.screen.hint', game: 'res://ui/screens/hint.tscn', version: 2, hash: 'd'.repeat(64), approved: false },
    { uid: 'level:M01', domain: 'level', id: 'M01', source: 'content/levels/lab/basics/M01.json', game: 'res://generated/content/levels/lab/basics/M01.json', sha256: hash(spec) },
    { uid: 'mode:lab', domain: 'mode', id: 'lab', source: 'content/catalog/modes.json', game: 'res://generated/content/catalog/modes.json#lab' },
    { uid: 'mechanic:push', domain: 'mechanic', id: 'push', game: 'res://gameplay/mechanics/push.gd' },
    { uid: 'text:hint.title', domain: 'text', id: 'hint.title', game: 'tr:hint.title' },
  ];
  write(root, 'content/export/id-map.json', { format: 'pushbox.idmap/1', entries });
  write(root, 'content/export/content-manifest.json', { format: 'pushbox.content-manifest/1', modes: [{ id: 'lab' }], groups: [{ id: 'basics', mode: 'lab', levels: [{ id: 'M01', spec: entries[4].source, sha256: hash(spec) }] }] });
  write(root, entries[4].source, spec);
  write(root, 'content/catalog/modes.json', { format: 'pushbox.catalog/1', kind: 'modes', entries: [{ id: 'lab', name: 'Lab' }] });
  write(root, 'content/i18n/zh-Hans.json', { 'hint.title': '提示 {n}' });
  write(root, 'content/i18n/en.json', { 'hint.title': 'Hint {n}' });
  write(root, approved.png, png);
  write(root, 'art/export/preview/ui.bubble.png', 'PREVIEW MUST NEVER BE COPIED');
  write(root, 'art/export/manifest.json', { format: 'pushbox.art-manifest/1', palette: { a: '#be4a2f' }, assets: [
    { id: 'obj.crate_wood', kind: 'sprite', current: { version: 1, hash: approved.hash }, approved, current_is_approved: true, frame_size: [16, 16], frame_count: 1, anchor: [8, 16], animations: { idle: { fps: 1, loop: true, frames: [0] } } },
    { id: 'ui.bubble', kind: 'sprite', current: { version: 1, hash: 'b'.repeat(64), preview: 'art/export/preview/ui.bubble.png' }, approved: null, current_is_approved: false, frame_size: [12, 12], frame_count: 3, anchor: [0, 0] },
    { id: 'theme.dungeon', kind: 'procedural', current: { version: 1, hash: 'c'.repeat(64) }, approved: { version: 1, hash: 'c'.repeat(64), png: approved.png, png_sha256: hash(png) }, current_is_approved: true, params: { rock: { pattern: 'brick' } } },
    { id: 'ui.screen.hint', kind: 'procedural', current: { version: 2, hash: 'd'.repeat(64) }, approved: { ...approved }, current_is_approved: false, params: { screen: 'hint' } },
  ] });
  write(gameRoot, 'gameplay/mechanics/push.gd', 'class_name PushMechanic\nextends RefCounted\n');
  write(gameRoot, 'presentation/ui/screens/hint.tscn', '[gd_scene format=3]\n[node name="Hint" type="Control"]\n');
  return { repoRoot: root, gameRoot, entries, png };
}

test('imports only verified approved sprite bytes and preserves uid resource metadata', async (t) => {
  const api = await implementation();
  const f = fixture(t);
  const result = api.importResources(f);
  assert.equal(result.uid_count, 8);
  const arts = read(f.gameRoot, 'generated/art-index.json');
  assert.equal(arts['art:obj.crate_wood'].approved, true);
  assert.deepEqual(fs.readFileSync(path.join(f.gameRoot, arts['art:obj.crate_wood'].texture.slice(6))), f.png);
  assert.deepEqual(arts['art:obj.crate_wood'].anchor, [8, 16]);
  assert.equal(arts['art:ui.bubble'].approved, false);
  assert.equal(arts['art:ui.bubble'].texture, '');
  assert.deepEqual(arts['art:theme.dungeon'].params, { rock: { pattern: 'brick' } });
  assert.deepEqual(arts['art:ui.screen.hint'].params, {});
  assert.equal(fs.existsSync(path.join(f.gameRoot, 'generated/art/preview/ui.bubble.png')), false);
  assert.ok(fs.existsSync(path.join(f.gameRoot, 'ui/screens/hint.tscn')));
});

test('refuses a corrupted level before destroying the previous generated tree', async (t) => {
  const api = await implementation();
  const f = fixture(t);
  write(f.gameRoot, 'generated/keep.txt', 'old import');
  write(f.repoRoot, 'content/levels/lab/basics/M01.json', '{}');
  assert.throws(() => api.importResources(f), /hash|sha256/i);
  assert.equal(fs.readFileSync(path.join(f.gameRoot, 'generated/keep.txt'), 'utf8'), 'old import');
});

test('refuses approved PNG hash mismatch and stale approval metadata', async (t) => {
  const api = await implementation();
  const f = fixture(t);
  write(f.repoRoot, 'art/export/approved/obj.crate_wood@v1.png', 'corrupt');
  assert.throws(() => api.importResources(f), /hash|sha256/i);
  write(f.repoRoot, 'art/export/approved/obj.crate_wood@v1.png', f.png);
  const m = read(f.repoRoot, 'art/export/manifest.json');
  m.assets[0].current.hash = 'e'.repeat(64);
  write(f.repoRoot, 'art/export/manifest.json', m);
  assert.throws(() => api.importResources(f), /hash|approval|stale/i);
});

test('checks id destinations, code uid references and unowned generated files separately', async (t) => {
  const api = await implementation();
  const f = fixture(t);
  api.importResources(f);
  assert.deepEqual(api.checkIds(f).errors, []);
  write(f.gameRoot, 'app/test.gd', 'extends Node\nvar unknown = "art:missing"\nvar unknown_domain = "npc:not_registered"\n');
  write(f.gameRoot, 'generated/stray.json', '{}');
  fs.rmSync(path.join(f.gameRoot, 'gameplay/mechanics/push.gd'));
  const result = api.checkIds(f);
  assert.ok(result.errors.some(e => e.check === 'a' && e.uid === 'mechanic:push'));
  assert.ok(result.errors.some(e => e.check === 'b' && e.uid === 'art:missing'));
  assert.ok(result.errors.some(e => e.check === 'b' && e.uid === 'npc:not_registered'));
  assert.ok(result.errors.some(e => e.check === 'c' && e.path.endsWith('stray.json')));
});

test('reimport removes stale generated output and tracks every generated dependency owner', async (t) => {
  const api = await implementation();
  const f = fixture(t);
  api.importResources(f);
  write(f.gameRoot, 'generated/stale.txt', 'stale');
  api.importResources(f);
  assert.equal(fs.existsSync(path.join(f.gameRoot, 'generated/stale.txt')), false);
  const inventory = read(f.gameRoot, 'generated/import-inventory.json');
  assert.ok(inventory.files.every(item => item.owners.length > 0 && item.owners.every(uid => f.entries.some(e => e.uid === uid))));
  assert.deepEqual(api.checkIds(f).errors, []);
});

test('release validation refuses pending UI and traverses required art dependencies', async (t) => {
  const api = await implementation();
  const f = fixture(t);
  api.importResources(f);
  assert.equal(typeof api.validateRelease, 'function', 'release validation has not been implemented');
  assert.deepEqual(api.validateRelease({ gameRoot: f.gameRoot, requiredUids: ['art:obj.crate_wood'] }).errors, []);
  const pending = api.validateRelease({ gameRoot: f.gameRoot, requiredUids: ['art:ui.screen.hint'] });
  assert.ok(pending.errors.some(e => e.uid === 'art:ui.screen.hint' && /approv|pending/i.test(e.detail)));
  const index = read(f.gameRoot, 'generated/art-index.json');
  index['art:obj.crate_wood'].depends = ['ui.bubble'];
  write(f.gameRoot, 'generated/art-index.json', index);
  assert.ok(api.validateRelease({ gameRoot: f.gameRoot, requiredUids: ['art:obj.crate_wood'] }).errors.some(e => e.uid === 'art:ui.bubble'));
});

test('unowned Godot sidecars are rejected while owned texture sidecars are tolerated', async (t) => {
  const api = await implementation();
  const f = fixture(t);
  api.importResources(f);
  write(f.gameRoot, 'generated/art/sheets/obj.crate_wood.png.import', '; Godot texture cache metadata');
  write(f.gameRoot, 'generated/orphan.import', '; unowned');
  const result = api.checkIds(f);
  assert.ok(result.errors.some(e => e.check === 'c' && e.path.endsWith('orphan.import')));
  assert.equal(result.errors.some(e => e.path.endsWith('obj.crate_wood.png.import')), false);
});
