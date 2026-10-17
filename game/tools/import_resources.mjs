#!/usr/bin/env node
// Read-only authoring inputs; generated output is owned by this importer.
import fs from 'node:fs';
import path from 'node:path';
import crypto from 'node:crypto';
import { fileURLToPath, pathToFileURL } from 'node:url';
import { loadTextTables } from '../../tools/lib/i18n.mjs';

const DEFAULT_REPO = path.resolve(path.dirname(fileURLToPath(import.meta.url)), '../..');
const sha = (bytes) => crypto.createHash('sha256').update(bytes).digest('hex');
const json = (name) => JSON.parse(fs.readFileSync(name, 'utf8'));
const walk = (dir) => fs.existsSync(dir) ? fs.readdirSync(dir, { withFileTypes: true }).sort((a, b) => a.name.localeCompare(b.name)).flatMap(e => e.isDirectory() ? walk(path.join(dir, e.name)) : [path.join(dir, e.name)]) : [];
const slash = (name) => name.split(path.sep).join('/');
const encode = (value) => JSON.stringify(value, null, 1) + '\n';
const safe = (root, relative) => {
  const resolved = path.resolve(root, relative);
  if (resolved !== path.resolve(root) && !resolved.startsWith(path.resolve(root) + path.sep)) throw new Error(`path escapes root: ${relative}`);
  return resolved;
};
const gamePath = (root, resource) => safe(root, resource.replace(/^res:\/\//, '').split('#')[0]);
const write = (file, data) => { fs.mkdirSync(path.dirname(file), { recursive: true }); fs.writeFileSync(file, data); };
const resourceText = (metadata) => `[gd_resource type="Resource" format=3]\n\n[resource]\nmetadata/json = ${JSON.stringify(JSON.stringify(metadata))}\n`;

function inputs(repoRoot) {
  const map = json(path.join(repoRoot, 'content/export/id-map.json'));
  const content = json(path.join(repoRoot, 'content/export/content-manifest.json'));
  const art = json(path.join(repoRoot, 'art/export/manifest.json'));
  if (map.format !== 'pushbox.idmap/1' || content.format !== 'pushbox.content-manifest/1' || art.format !== 'pushbox.art-manifest/1') throw new Error('unsupported input manifest format');
  const { tables: texts, source: textSource, problems } = loadTextTables(repoRoot);
  if (problems.length) throw new Error('translation tables: ' + problems.map(p => `${p.where}: ${p.msg}`).join('; '));
  for (const [locale, table] of Object.entries(texts)) {
    for (const [key, value] of Object.entries(table)) {
      // Workbench-only groups (e.g. content/i18n-audio "audio.dom") are nested objects; the game never reads them.
      if (key !== '_meta' && value && typeof value === 'object' && !Array.isArray(value)) { delete table[key]; continue; }
      if (key !== '_meta' && typeof value !== 'string') throw new Error(`translation must be a string: ${locale}/${key}`);
    }
  }
  const baseText = new Set(map.entries.filter(e => e.domain === 'text').map(e => e.id));
  for (const key of Object.keys(texts['zh-Hans']).filter(k => k !== '_meta' && !baseText.has(k))) {
    map.entries.push({ uid: `text:${key}`, domain: 'text', id: key, name: texts['zh-Hans'][key], source: textSource[key], game: `tr:${key}` });
  }
  if (map.domains?.text) map.domains.text.count = map.entries.filter(e => e.domain === 'text').length;
  const uids = new Set();
  for (const e of map.entries) {
    if (uids.has(e.uid)) throw new Error(`duplicate uid: ${e.uid}`);
    uids.add(e.uid);
  }
  return { map, content, art, texts };
}

function existingRoutes(gameRoot, map) {
  // Keep only bytes owned by the previous import and still tied to this spec.
  // A missing, edited, or stale route is replaced by runtime author-prefix data.
  const previousMapPath = path.join(gameRoot, 'generated/id-map.json');
  const inventoryPath = path.join(gameRoot, 'generated/import-inventory.json');
  if (!fs.existsSync(previousMapPath) || !fs.existsSync(inventoryPath)) return [];
  let previousMap, inventory;
  try {
    previousMap = json(previousMapPath);
    inventory = json(inventoryPath);
  } catch {
    return [];
  }
  if (previousMap.format !== 'pushbox.idmap/1' || inventory.format !== 'portitor.import-inventory/1' || !Array.isArray(previousMap.entries) || !Array.isArray(inventory.files)) return [];
  const previousLevels = new Map(previousMap.entries.filter(e => e.domain === 'level').map(e => [e.uid, e]));
  const files = new Map(inventory.files.map(item => [item.path, item]));
  const preserved = [];
  for (const entry of map.entries.filter(e => e.domain === 'level')) {
    const previous = previousLevels.get(entry.uid);
    if (!entry.sha256 || previous?.sha256 !== entry.sha256) continue;
    const relative = `generated/content/routes/${entry.id}.json`;
    const owned = files.get(relative);
    if (!owned?.sha256 || !Array.isArray(owned.owners) || !owned.owners.includes(entry.uid)) continue;
    const location = safe(gameRoot, relative);
    if (!fs.existsSync(location)) continue;
    const bytes = fs.readFileSync(location);
    if (sha(bytes) !== owned.sha256) continue;
    try {
      const states = JSON.parse(bytes.toString('utf8'));
      if (!Array.isArray(states) || states.some(state => !state || typeof state !== 'object' || Array.isArray(state))) continue;
    } catch {
      continue;
    }
    preserved.push({ relative, bytes, uid: entry.uid });
  }
  return preserved;
}

export function importResources({ repoRoot = DEFAULT_REPO, gameRoot = path.join(repoRoot, 'game'), routes = null, preserveRoutes = true } = {}) {
  const { map, content, art, texts } = inputs(repoRoot);
  const preservedRoutes = preserveRoutes ? existingRoutes(gameRoot, map) : [];
  const staged = new Map();
  const allOwners = map.entries.map(e => e.uid);
  const put = (relative, data, owners) => {
    safe(gameRoot, relative);
    staged.set(relative, { data: typeof data === 'string' || Buffer.isBuffer(data) ? data : encode(data), owners: [...new Set(owners)].sort() });
  };
  const copy = (source, destination, owners, expected = null) => {
    const bytes = fs.readFileSync(safe(repoRoot, source));
    if (expected && sha(bytes) !== expected) throw new Error(`sha256 hash mismatch: ${source}`);
    put(destination, bytes, owners);
  };
  const local = (resource) => resource.replace(/^res:\/\//, '').split('#')[0];
  put('generated/id-map.json', map, allOwners);
  put('generated/content-manifest.json', content, allOwners.filter(uid => !uid.startsWith('art:') && !uid.startsWith('text:')));
  const names = new Set();
  const constants = map.entries.map(e => {
    const name = e.uid.replace(/[^A-Za-z0-9]/g, '_').toUpperCase();
    if (names.has(name)) throw new Error(`generated constant collision: ${name}`);
    names.add(name);
    return `const ${name}: String = ${JSON.stringify(e.uid)}`;
  });
  put('generated/ids.gd', '# Generated by game/tools/import_resources.mjs.\nclass_name ResourceIds\nextends RefCounted\n\n' + constants.join('\n') + '\n', allOwners);
  const whitelist = new Map();
  for (const group of content.groups || []) for (const level of group.levels || []) if (level.spec) whitelist.set(level.id, level);
  for (const entry of map.entries.filter(e => e.domain === 'level')) {
    const expected = whitelist.get(entry.id);
    if (!expected || expected.spec !== entry.source || expected.sha256 !== entry.sha256) throw new Error(`level missing from content manifest or hash mismatch: ${entry.uid}`);
    copy(entry.source, local(entry.game), [entry.uid], entry.sha256);
  }
  for (const entry of map.entries.filter(e => e.domain === 'room')) copy(entry.source, local(entry.game), [entry.uid], entry.sha256);
  const catalogFiles = new Map();
  for (const e of map.entries) if (e.game.includes('/content/catalog/') && e.source) {
    const destination = local(e.game);
    if (!catalogFiles.has(destination)) catalogFiles.set(destination, { source: e.source, owners: [] });
    catalogFiles.get(destination).owners.push(e.uid);
  }
  for (const [destination, item] of catalogFiles) copy(item.source, destination, item.owners);
  const textOwners = map.entries.filter(e => e.domain === 'text').map(e => e.uid);
  for (const locale of ['zh-Hans', 'en']) put(`generated/content/i18n/${locale}.json`, texts[locale], textOwners);
  const artIndex = {};
  for (const e of map.entries.filter(e => e.domain === 'art')) {
    const a = art.assets.find(item => item.id === e.id);
    if (!a) throw new Error(`art missing from manifest: ${e.uid}`);
    if (a.current.version !== e.version || a.current.hash !== e.hash) throw new Error(`art id-map version/hash mismatch: ${e.uid}`);
    const approved = a.current_is_approved === true;
    if (approved && (!a.approved || a.approved.version !== a.current.version || a.approved.hash !== a.current.hash)) throw new Error(`stale approval version/hash: ${e.uid}`);
    if (approved !== e.approved) throw new Error(`art approval mismatch: ${e.uid}`);
    const metadata = { uid: e.uid, id: e.id, kind: a.kind, version: e.version, hash: e.hash, approved, placeholder: !approved,
      texture: '', texture_path: '', png_sha256: '', size: a.frame_size || [0, 0], frame_count: a.frame_count || 0, anchor: a.anchor || [0, 0],
      animations: a.animations || {}, ninepatch: a.ninepatch || null, params: approved ? (a.params || {}) : {}, palette: art.palette || {}, depends: a.depends || [] };
    if (approved) {
      // Even procedural entries have an immutable approval PNG: verify it, but
      // only sprite sheets are runtime textures. Procedural art uses params.
      const pngBytes = fs.readFileSync(safe(repoRoot, a.approved.png));
      if (sha(pngBytes) !== a.approved.png_sha256) throw new Error(`approved PNG sha256 hash mismatch: ${e.uid}`);
      if (a.kind === 'sprite') {
        const destination = `generated/art/sheets/${e.id}.png`;
        put(destination, pngBytes, [e.uid]);
        metadata.texture = `res://${destination}`;
        metadata.texture_path = metadata.texture;
        metadata.png_sha256 = a.approved.png_sha256;
      }
    }
    const destination = e.game.endsWith('.tscn') ? `generated/art/metadata/${e.id}.tres` : local(e.game);
    metadata.resource = `res://${destination}`;
    put(destination, resourceText(metadata), [e.uid]);
    artIndex[e.uid] = metadata;
    if (e.game.endsWith('.tscn')) {
      const name = e.id.slice('ui.screen.'.length);
      const implementation = `res://presentation/ui/screens/${name}.tscn`;
      const nodeName = name.split('_').map(s => s[0].toUpperCase() + s.slice(1)).join('');
      const implemented = fs.existsSync(gamePath(gameRoot, implementation));
      const scene = implemented
        ? `[gd_scene load_steps=2 format=3]\n\n[ext_resource type="PackedScene" path="${implementation}" id="1"]\n\n[node name="${nodeName}" instance=ExtResource("1")]\n`
        : `[gd_scene format=3]\n\n[node name="${nodeName}" type="Control"]\nmetadata/implementation_available = false\nmetadata/art_uid = ${JSON.stringify(e.uid)}\n`;
      put(local(e.game), scene, [e.uid]);
    }
  }
  put('generated/art-index.json', artIndex, map.entries.filter(e => e.domain === 'art').map(e => e.uid));
  for (const route of preservedRoutes) put(route.relative, route.bytes, [route.uid]);
  if (routes) for (const [uid, steps] of Object.entries(routes)) {
    const entry = map.entries.find(e => e.uid === uid && e.domain === 'level');
    if (!entry) throw new Error(`author route has unknown level uid: ${uid}`);
    put(`generated/content/routes/${entry.id}.json`, steps, [uid]);
  }
  const generated = [...staged].filter(([p]) => p.startsWith('generated/')).map(([p, item]) => ({ path: p, owners: item.owners, sha256: sha(item.data) }));
  generated.push({ path: 'generated/import-inventory.json', owners: allOwners, sha256: null });
  put('generated/import-inventory.json', { format: 'portitor.import-inventory/1', source_id_map_sha256: sha(fs.readFileSync(path.join(repoRoot, 'content/export/id-map.json'))), files: generated }, allOwners);
  // Complete validation precedes any destructive output operation.
  fs.rmSync(path.join(gameRoot, 'generated'), { recursive: true, force: true });
  for (const [destination, item] of staged) write(safe(gameRoot, destination), item.data);
  // Font files are infrastructure, not authoring uids. Preserve exact bytes and
  // the complete license trees outside generated/; never redraw or convert.
  const fontRoot = path.join(repoRoot, 'third_party/fonts');
  for (const file of walk(fontRoot)) {
    const relative = slash(path.relative(fontRoot, file));
    write(safe(gameRoot, `bin/fonts/${relative}`), fs.readFileSync(file));
  }
  return { uid_count: map.entries.length, generated_files: generated.length, preserved_routes: preservedRoutes.length, approved_art: Object.values(artIndex).filter(a => a.approved).length, pending_art: Object.values(artIndex).filter(a => !a.approved).map(a => a.uid) };
}

export function checkIds({ repoRoot = DEFAULT_REPO, gameRoot = path.join(repoRoot, 'game'), scanSources = true } = {}) {
  const errors = [];
  const add = (check, uid, location, detail) => errors.push({ check, uid, path: slash(location), detail });
  const map = json(path.join(gameRoot, 'generated/id-map.json'));
  const index = json(path.join(gameRoot, 'generated/art-index.json'));
  const inventory = json(path.join(gameRoot, 'generated/import-inventory.json'));
  const valid = new Set(map.entries.map(e => e.uid));
  const texts = ['zh-Hans', 'en'].map(locale => json(path.join(gameRoot, `generated/content/i18n/${locale}.json`)));
  for (const entry of map.entries) {
    if (entry.domain === 'text') {
      for (const [i, text] of texts.entries()) if (typeof text[entry.id] !== 'string') add('a', entry.uid, ['zh-Hans', 'en'][i], 'missing translation key');
      continue;
    }
    const target = gamePath(gameRoot, entry.game);
    if (!fs.existsSync(target)) { add('a', entry.uid, target, 'missing game path'); continue; }
    if (entry.game.includes('#')) {
      const catalog = json(target);
      const entries = Array.isArray(catalog) ? catalog : catalog.entries;
      if (!Array.isArray(entries) || !entries.some(e => e.id === entry.id)) add('a', entry.uid, target, 'missing catalog fragment');
    }
    if (['level', 'room'].includes(entry.domain) && sha(fs.readFileSync(target)) !== entry.sha256) add('a', entry.uid, target, 'level sha256 mismatch');
    if (entry.domain === 'art') {
      const art = index[entry.uid];
      if (!art || art.hash !== entry.hash || art.version !== entry.version || art.approved !== entry.approved) add('a', entry.uid, target, 'art metadata version/hash mismatch');
      else if (art.texture && (!fs.existsSync(gamePath(gameRoot, art.texture)) || sha(fs.readFileSync(gamePath(gameRoot, art.texture))) !== art.png_sha256)) add('a', entry.uid, art.texture, 'art PNG sha256 mismatch');
    }
  }
  if (scanSources) {
    // Inspect complete resource-string literals, including misspelled domains.
    // Test fixtures deliberately contain unknown ids and are not runtime code.
    const pattern = /["']([a-z][a-z0-9_]*:[A-Za-z0-9_][A-Za-z0-9_.-]*)["']/g;
    for (const file of walk(gameRoot).filter(p => /\.(gd|tscn)$/.test(p) && !/^(generated|tests)\//.test(slash(path.relative(gameRoot, p))))) {
      const literals = [...fs.readFileSync(file, 'utf8').matchAll(pattern)].map(match => match[1]);
      for (const uid of new Set(literals)) {
        // Concatenated domain/prefix strings are checked after resolution by
        // Registry. They are not complete authored uid literals.
        if (uid.endsWith('.')) continue;
        if (!valid.has(uid)) add('b', uid, file, 'unknown uid in game code or scene');
      }
    }
  }
  const listed = new Map(inventory.files.map(item => [item.path, item]));
  for (const file of walk(path.join(gameRoot, 'generated'))) {
    const relative = slash(path.relative(gameRoot, file));
    // Only a sidecar for an owned source belongs to Godot. Arbitrary orphan
    // .import/.uid files must not bypass the generated-file ownership check.
    if ((relative.endsWith('.uid') || relative.endsWith('.import')) && listed.has(relative.replace(/\.(uid|import)$/, ''))) continue;
    const item = listed.get(relative);
    if (!item || !item.owners.length || item.owners.some(uid => !valid.has(uid))) add('c', '', relative, 'unowned generated file');
    else if (item.sha256 && sha(fs.readFileSync(file)) !== item.sha256) add('c', '', relative, 'generated file changed after import');
  }
  for (const item of inventory.files) if (!fs.existsSync(safe(gameRoot, item.path))) add('c', '', item.path, 'listed generated file is missing');
  return { format: 'portitor.id-checks/1', checks: ['a', 'b', 'c'].map(id => ({ id, ok: !errors.some(e => e.check === id) })), errors, uid_count: map.entries.length };
}

export function validateRelease({ gameRoot = path.join(DEFAULT_REPO, 'game'), requiredUids = null } = {}) {
  const index = json(path.join(gameRoot, 'generated/art-index.json'));
  const requested = requiredUids || [
    ...['lobby', 'chapters', 'levels', 'pause', 'hint', 'complete', 'settings', 'rulecard'].map(name => `art:ui.screen.${name}`),
    'art:ui.bubble', 'art:ui.bubble_tail',
  ];
  const errors = [], checked = new Set();
  const visit = (uid) => {
    if (checked.has(uid)) return;
    checked.add(uid);
    const art = index[uid];
    if (!art) { errors.push({ uid, detail: 'Required art uid is missing' }); return; }
    if (!art.approved || art.placeholder) errors.push({ uid, detail: 'Current art approval is pending; release build refused' });
    if (art.approved && art.texture_path) {
      const target = gamePath(gameRoot, art.texture_path);
      if (!fs.existsSync(target) || sha(fs.readFileSync(target)) !== art.png_sha256) errors.push({ uid, detail: 'Approved runtime PNG sha256 mismatch; release build refused' });
    }
    for (const dependency of art.depends || []) visit(dependency.startsWith('art:') ? dependency : `art:${dependency}`);
  };
  for (const uid of requested) visit(uid);
  return { format: 'portitor.release-art-check/1', checked: [...checked], errors, ok: errors.length === 0 };
}

if (process.argv[1] && import.meta.url === pathToFileURL(process.argv[1]).href) {
  const command = process.argv[2] || 'import';
  const repoRoot = process.env.PORTITOR_REPO_ROOT || DEFAULT_REPO;
  const options = { repoRoot, gameRoot: path.join(repoRoot, 'game') };
  if (command === 'import') {
    const flags = process.argv.slice(3);
    if (flags.some(flag => !['--model-routes', '--no-model-routes'].includes(flag)) || (flags.includes('--model-routes') && flags.includes('--no-model-routes'))) throw new Error('import flags: --no-model-routes (default) or explicit --model-routes');
    if (flags.includes('--model-routes')) {
      // Design-model execution is opt-in; normal launch/package only preserve.
      const exporter = path.join(repoRoot, 'game/tools/export_model.mjs');
      const module = await import(pathToFileURL(exporter).href);
      if (typeof module.buildModelRoutes !== 'function') throw new Error('model route exporter is unavailable');
      options.routes = module.buildModelRoutes(repoRoot);
    }
    console.log(JSON.stringify(importResources(options), null, 2));
  } else if (command === 'check') {
    const result = checkIds(options);
    console.log(JSON.stringify(result, null, 2));
    process.exitCode = result.errors.length ? 1 : 0;
  } else if (command === 'release') {
    const requiredUids = process.argv[3] ? process.argv[3].split(',') : null;
    const result = validateRelease({ gameRoot: options.gameRoot, requiredUids });
    console.log(JSON.stringify(result, null, 2));
    process.exitCode = result.ok ? 0 : 1;
  } else throw new Error('usage: node game/tools/import_resources.mjs [import [--no-model-routes|--model-routes]|check|release [art:uid,...]]');
}
