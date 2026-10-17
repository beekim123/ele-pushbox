// Merge-conflict helper for content/catalog/*.json during an in-progress git merge:
// keeps HEAD, adds MERGE_HEAD entries missing by id, takes MERGE_HEAD edits to entries it changed vs the merge base.
// Usage: node tools/dev/json-merge-by-id.mjs content/catalog/cargo.json ...  (prints what it took; review "BOTH CHANGED")
import { execSync } from 'child_process'; import fs from 'fs';
const show = (rev, f) => { try { return JSON.parse(execSync(`git show ${rev}:${f}`, { maxBuffer: 1e8 }).toString()); } catch { return null; } };
const base = execSync('git merge-base HEAD MERGE_HEAD').toString().trim();
for (const f of process.argv.slice(2)) {
  const O = show('HEAD', f), T = show('MERGE_HEAD', f), B = show(base, f);
  const out = structuredClone(O); const log = [];
  for (const k of Object.keys(T)) {
    if (Array.isArray(T[k]) && T[k].every(e => e && e.id)) {
      const o = out[k] || (out[k] = []), b = (B && B[k]) || [];
      for (const t of T[k]) {
        const i = o.findIndex(e => e.id === t.id), bi = b.find(e => e.id === t.id);
        if (i < 0) { o.push(t); log.push(`${k}+${t.id}`); }
        else if (JSON.stringify(t) !== JSON.stringify(bi)) {
          if (JSON.stringify(o[i]) !== JSON.stringify(bi)) log.push(`BOTH CHANGED ${k}.${t.id}`);
          o[i] = t; log.push(`${k}~${t.id}`);
        }
      }
    } else if (JSON.stringify(T[k]) !== JSON.stringify(B && B[k]) && JSON.stringify(O[k]) === JSON.stringify(B && B[k])) { out[k] = T[k]; log.push(`key ${k}`); }
    else if (JSON.stringify(T[k]) !== JSON.stringify(B && B[k]) && JSON.stringify(O[k]) !== JSON.stringify(T[k])) log.push(`CONFLICT key ${k}`);
  }
  fs.writeFileSync(f, JSON.stringify(out, null, 1) + '\n'); console.log(f, log.join(' '));
}
