// Content pipeline tests (tools/content.mjs). Each test works on a temporary
// copy of content/ and art/; the repository is only read.
import { test } from "node:test";
import assert from "node:assert/strict";
import { execFileSync } from "node:child_process";
import fs from "node:fs";
import os from "node:os";
import path from "node:path";
import { fileURLToPath } from "node:url";
import { buildContent } from "../tools/content.mjs";

const REPO = path.resolve(path.dirname(fileURLToPath(import.meta.url)), "..");
function sandbox() {
  const dir = fs.mkdtempSync(path.join(os.tmpdir(), "pb-content-"));
  for (const d of ["content", "art/source", "art/approvals.json"]) if (fs.existsSync(path.join(REPO, d))) fs.cpSync(path.join(REPO, d), path.join(dir, d), { recursive: true });
  return dir;
}
const edit = (root, p, fn) => { const f = path.join(root, p); const v = JSON.parse(fs.readFileSync(f, "utf8")); fn(v); fs.writeFileSync(f, JSON.stringify(v, null, 1)); };
const errors = (res) => res.issues.filter((i) => i.level === "error").map((i) => i.where + ": " + i.msg);

test("the repository's catalogs and level specs pass without errors", () => {
  const res = buildContent(REPO);
  assert.deepEqual(errors(res), []);
  assert.ok(res.levels.some((l) => l.id === "M01" && l.has_spec && l.model && l.model.ok));
});

test("a level spec naming an unknown mechanism is an error", () => {
  const root = sandbox();
  edit(root, "content/levels/lab/basics/M01.json", (s) => { s.mechanisms = ["teleport"]; });
  assert.ok(errors(buildContent(root)).some((e) => e.includes("M01.json") && e.includes("不一致")));
  edit(root, "content/catalog/groups.json", (g) => { g.entries[0].levels[0].mechanisms = ["teleport"]; });
  assert.ok(errors(buildContent(root)).some((e) => e.includes("teleport")));
});

test("missing art, misplaced specs and duplicate ids are errors", () => {
  const root = sandbox();
  edit(root, "content/catalog/mechanisms.json", (m) => { m.entries[0].assets.push("obj.nonexistent"); m.entries.push(Object.assign({}, m.entries[1])); });
  fs.renameSync(path.join(root, "content/levels/lab/basics/M02.json"), path.join(root, "content/levels/lab/M02.json"));
  const e = errors(buildContent(root));
  assert.ok(e.some((x) => x.includes("obj.nonexistent")));
  assert.ok(e.some((x) => x.includes("编号重复")));
  assert.ok(e.some((x) => x.includes("content/levels/lab/basics/M02.json")));
});

test("statuses come from data: a passing verification report marks the level verified", () => {
  const root = sandbox();
  let res = buildContent(root);
  assert.equal(res.mechanisms.find((m) => m.id === "push").status, "specified");
  assert.equal(res.mechanisms.find((m) => m.id === "power").status, "proposed");
  fs.mkdirSync(path.join(root, "game/reports"), { recursive: true });
  const ok = { id: "M01", won: true, replays: 3, consistent: true, undo_ok: true, max_ticks: 300, tick_limit: 4000, checks: [{ text: "x", ok: true }] };
  fs.writeFileSync(path.join(root, "game/reports/verification.json"), JSON.stringify({ format: "pushbox.verification/1", levels: res.levels.filter(l => l.mechanisms.includes("push")).map(l => ({ ...ok, id: l.id })) }));
  res = buildContent(root);
  assert.equal(res.levels.find((l) => l.id === "M01").verified.ok, true);
  assert.equal(res.mechanisms.find((m) => m.id === "push").status, "playable"); // its art is approved
  fs.writeFileSync(path.join(root, "game/reports/verification.json"), JSON.stringify({ format: "pushbox.verification/1", levels: [Object.assign({}, ok, { replays: 1 })] }));
  assert.equal(buildContent(root).mechanisms.find((m) => m.id === "push").status, "specified");
});

test("build writes the Godot content manifest and the workbench data; check exits non-zero on errors", () => {
  const root = sandbox();
  execFileSync(process.execPath, [path.join(REPO, "tools/content.mjs"), "build", "--root", root]);
  const man = JSON.parse(fs.readFileSync(path.join(root, "content/export/content-manifest.json"), "utf8"));
  assert.equal(man.format, "pushbox.content-manifest/1");
  const basics = man.groups.find((g) => g.id === "basics");
  assert.equal(basics.levels[0].spec, "content/levels/lab/basics/M01.json");
  assert.match(fs.readFileSync(path.join(root, "workbench/data/content.js"), "utf8"), /^\/\* Generated/);
  edit(root, "content/catalog/groups.json", (g) => { g.entries[0].theme = "theme.nowhere"; });
  assert.throws(() => execFileSync(process.execPath, [path.join(REPO, "tools/content.mjs"), "check", "--root", root], { stdio: "pipe" }));
});

test("a playable slice must reference real cargo, residents of its region and its own monsters", () => {
  const res = buildContent(REPO);
  const sl = res.catalogs.slices.find((s) => s.id === "dungeon_1");
  assert.ok(sl && sl.cargo.length === 3 && sl.recipients.length === 3 && sl.monsters.length === 2);
  assert.ok(res.ids.entries.some((e) => e.uid === "slice:dungeon_1"));
  const root = sandbox();
  edit(root, "content/catalog/slices.json", (c) => {
    const s = c.entries[0];
    s.cargo.push("piano_x"); s.recipients.push("alien"); s.monsters.push("ghost"); s.station.items.push("teleporter");
  });
  const e = errors(buildContent(root));
  assert.ok(e.some((x) => x.includes("piano_x")), "unknown cargo");
  assert.ok(e.some((x) => x.includes("alien") && x.includes("dungeon")), "recipient living elsewhere");
  assert.ok(e.some((x) => x.includes("ghost") && x.includes("graveyard")), "monster of another region");
  assert.ok(e.some((x) => x.includes("teleporter")), "unknown station item");
  edit(root, "content/catalog/slices.json", (c) => { c.entries[0] = Object.assign(c.entries[0], { cargo: ["brains"], recipients: ["old_miner"], monsters: [], station: {} }); });
  assert.ok(errors(buildContent(root)).some((x) => x.includes("brains") && x.includes("params.pay")), "slice cargo needs a base pay");
});

test("every resource gets one global uid and a fixed game path", () => {
  const res = buildContent(REPO);
  const uids = res.ids.entries.map((e) => e.uid);
  assert.equal(new Set(uids).size, uids.length);
  const w08 = res.ids.entries.find((e) => e.uid === "level:W08");
  assert.equal(w08.source, "content/levels/lab/water/W08.json");
  assert.equal(w08.game, "res://generated/content/levels/lab/water/W08.json");
  // Same local id in two domains is fine (recipient:ghost, monster:ghost); a bad id format is not.
  assert.ok(uids.includes("recipient:ghost") && uids.includes("monster:ghost"));
  const root = sandbox();
  edit(root, "content/catalog/cargo.json", (c) => { c.entries[0].id = "Bad Id"; });
  assert.ok(errors(buildContent(root)).some((e) => e.includes("编号格式不对")));
});
