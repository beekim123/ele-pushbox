#!/usr/bin/env node
// ID completeness is separate from implementation/playability. Never overwrite
// a real mechanism; unsupported mechanisms remain explicit, inert scripts.
import fs from 'node:fs';
import path from 'node:path';
import crypto from 'node:crypto';
import { fileURLToPath, pathToFileURL } from 'node:url';

const DEFAULT_REPO = path.resolve(path.dirname(fileURLToPath(import.meta.url)), '../..');

export function importMechanicStubs({ repoRoot = DEFAULT_REPO, gameRoot = path.join(repoRoot, 'game') } = {}) {
  const map = JSON.parse(fs.readFileSync(path.join(repoRoot, 'content/export/id-map.json'), 'utf8'));
  if (map.format !== 'pushbox.idmap/1') throw new Error('unsupported id-map format');
  const created = [], existing = [];
  for (const item of map.entries.filter(e => e.domain === 'mechanic')) {
    const relative = item.game.replace(/^res:\/\//, '');
    if (!relative.startsWith('gameplay/mechanics/') || relative !== `gameplay/mechanics/${item.id}.gd` || !/^[a-z0-9_]+$/.test(item.id)) throw new Error(`unsupported mechanism mapping: ${item.uid}`);
    const destination = path.join(gameRoot, relative);
    if (fs.existsSync(destination)) { existing.push(item.uid); continue; }
    const suffix = crypto.createHash('sha256').update(item.uid).digest('hex').slice(0, 6);
    const name = item.id.split('_').map(s => s[0].toUpperCase() + s.slice(1)).join('');
    const source = `class_name Unimplemented${name}${suffix}\nextends "res://gameplay/mechanics/mechanic.gd"\n## ${item.uid}: catalog path only; not registered by any playable mode.\n\nvar unimplemented: bool = true\n\nfunc implementation_available() -> bool:\n\treturn false\n`;
    fs.mkdirSync(path.dirname(destination), { recursive: true });
    fs.writeFileSync(destination, source, { flag: 'wx' });
    created.push(item.uid);
  }
  return { created, existing };
}

if (process.argv[1] && import.meta.url === pathToFileURL(process.argv[1]).href) console.log(JSON.stringify(importMechanicStubs(), null, 2));
