#!/usr/bin/env node
// Design-model check for level specs in content/levels/.
// Proves only that a layout works under the tile rules of game-design.md §4;
// it is not SDK verification. Usage: node tools/check-levels.mjs [--write] [ID...]
import fs from "node:fs";
import path from "node:path";
import { ROOT, loadCore, listJson, readJson } from "./lib/load-core.mjs";

const PB = loadCore(["tilemodel"]);
const TM = PB.tilemodel;
const args = process.argv.slice(2);
const write = args.includes("--write");
const only = args.filter((a) => !a.startsWith("--"));

function sandWarnings(spec) {
  // Loose sand next to open air slumps into a slope in the SDK (2.1 powder rule),
  // so the tile model cannot predict it. Flag every such tile at start.
  const out = [];
  spec.map.forEach((row, y) => [...row].forEach((ch, x) => {
    if (ch !== "s") return;
    for (const dx of [-1, 1]) {
      const side = spec.map[y][x + dx], below = (spec.map[y + 1] || "")[x + dx];
      if (".HoX_P".includes(side) && below !== undefined && ".HoX_~".includes(below)) out.push(`loose sand at ${x},${y} can slump toward ${x + dx}`);
    }
  }));
  return out;
}

const report = [];
let failed = 0;
for (const rel of listJson("content/levels")) {
  const spec = readJson(rel);
  if (spec.format !== "pushbox.levelspec/1") continue;
  if (only.length && !only.includes(spec.id)) continue;
  const entry = { id: spec.id, file: rel, title: spec.title };
  try {
    const author = spec.solution ? TM.replay(spec, spec.solution) : null;
    entry.author_steps = spec.solution ? spec.solution.length : null;
    entry.author_ok = !!(author && author.won);
    if (author && !author.won) entry.author_error = author.reason ? `${author.action} rejected (${author.reason}) at step ${author.failedAt}` : "does not win";
    const best = TM.solve(spec, 400000);
    entry.shortest = best.solved ? best.solution.length : null;
    entry.shortest_solution = best.solved ? best.solution : null;
    entry.explored = best.explored;
    const dead = TM.deadEnds(spec, 80000);
    entry.reachable_states = dead.states;
    entry.dead_end_states = dead.complete ? dead.dead : null;
    entry.warnings = sandWarnings(spec);
    if (!entry.author_ok || !best.solved) failed++;
  } catch (error) {
    entry.error = String(error.message || error); failed++;
  }
  report.push(entry);
  const flag = entry.error ? "ERROR" : entry.author_ok && entry.shortest ? "ok" : "FAIL";
  console.log(`${flag.padEnd(5)} ${entry.id.padEnd(4)} author=${entry.author_steps} shortest=${entry.shortest} states=${entry.reachable_states} dead=${entry.dead_end_states}${entry.warnings && entry.warnings.length ? " warn=" + entry.warnings.length : ""}${entry.author_error ? " " + entry.author_error : ""}${entry.error ? " " + entry.error : ""}`);
}
if (write) {
  const out = path.join(ROOT, "content/model-check.generated.json");
  fs.writeFileSync(out, JSON.stringify({ note: "Design-model check only (tools/check-levels.mjs). Not SDK verification.", levels: report }, null, 2) + "\n");
  console.log("wrote", path.relative(ROOT, out));
}
process.exit(failed ? 1 : 0);
