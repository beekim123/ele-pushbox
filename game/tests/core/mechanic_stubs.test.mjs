import { test } from 'node:test';
import assert from 'node:assert/strict';
import fs from 'node:fs';
import path from 'node:path';
import os from 'node:os';
import { fileURLToPath } from 'node:url';

test('adds explicitly unavailable scripts only for missing authoring mechanic destinations', async (t) => {
  const url = new URL('../../tools/import_mechanic_stubs.mjs', import.meta.url);
  assert.ok(fs.existsSync(fileURLToPath(url)), 'mechanic stub importer has not been implemented');
  const { importMechanicStubs } = await import(url.href);
  const root = fs.mkdtempSync(path.join(os.tmpdir(), 'portitor-stubs-'));
  t.after(() => fs.rmSync(root, { recursive: true, force: true }));
  const gameRoot = path.join(root, 'game');
  fs.mkdirSync(path.join(root, 'content/export'), { recursive: true });
  const mapFile = path.join(root, 'content/export/id-map.json');
  const authored = JSON.stringify({ format: 'pushbox.idmap/1', entries: [
    { uid: 'mechanic:push', domain: 'mechanic', id: 'push', game: 'res://gameplay/mechanics/push.gd' },
    { uid: 'mechanic:water_flow', domain: 'mechanic', id: 'water_flow', game: 'res://gameplay/mechanics/water_flow.gd' },
  ] });
  fs.writeFileSync(mapFile, authored);
  fs.mkdirSync(path.join(gameRoot, 'gameplay/mechanics'), { recursive: true });
  const realScript = 'class_name RealPush\nextends RefCounted\n';
  fs.writeFileSync(path.join(gameRoot, 'gameplay/mechanics/push.gd'), realScript);
  const result = importMechanicStubs({ repoRoot: root, gameRoot });
  assert.deepEqual(result.created, ['mechanic:water_flow']);
  assert.deepEqual(result.existing, ['mechanic:push']);
  assert.equal(fs.readFileSync(path.join(gameRoot, 'gameplay/mechanics/push.gd'), 'utf8'), realScript);
  assert.equal(fs.readFileSync(mapFile, 'utf8'), authored);
  assert.ok(fs.existsSync(path.join(gameRoot, 'gameplay/mechanics/water_flow.gd')));
  assert.deepEqual(importMechanicStubs({ repoRoot: root, gameRoot }).created, []);
});
