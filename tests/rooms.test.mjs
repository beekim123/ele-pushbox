// Delivery rooms and maps (tools/check-rooms.mjs, workbench/js/core/rooms.js,
// mapgen.js). Mutating tests work on a temporary copy of content/; the
// repository is only read.
import { test } from "node:test";
import assert from "node:assert/strict";
import fs from "node:fs";
import os from "node:os";
import path from "node:path";
import { fileURLToPath } from "node:url";
import { checkRooms, loadRooms } from "../tools/check-rooms.mjs";
import { buildContent } from "../tools/content.mjs";
import { loadCore } from "../tools/lib/load-core.mjs";

const REPO = path.resolve(path.dirname(fileURLToPath(import.meta.url)), "..");
const PB = loadCore(["tilemodel", "rooms", "mapgen"]);
const readJson = (p) => JSON.parse(fs.readFileSync(path.join(REPO, p), "utf8"));
const slice = () => readJson("content/catalog/slices.json").entries.find((s) => s.id === "dungeon_1");
const templates = (sl) => loadRooms(REPO).map((x) => x.room).filter((t) => sl.rooms.includes(t.id)).sort((a, b) => a.id.localeCompare(b.id));
function sandbox() {
  const dir = fs.mkdtempSync(path.join(os.tmpdir(), "pb-rooms-"));
  for (const d of ["content", "art/source", "art/approvals.json"]) fs.cpSync(path.join(REPO, d), path.join(dir, d), { recursive: true });
  return dir;
}
const editRoom = (root, id, fn) => { const f = path.join(root, "content/rooms/dungeon", id + ".json"); const v = JSON.parse(fs.readFileSync(f, "utf8")); fn(v); fs.writeFileSync(f, JSON.stringify(v, null, 1)); };

test("every slice template passes and maps from 60 seeds only use checked placements", () => {
  const { report, failed } = checkRooms(REPO, { seeds: 60 });
  assert.equal(failed, 0, JSON.stringify(report.slices.map((s) => s.failures)));
  const sl = report.slices.find((s) => s.id === "dungeon_1");
  assert.ok(sl.ok && Object.keys(sl.directions).length === 2, "maps run both down and up");
  for (const t of report.templates) assert.deepEqual(t.errors, [], t.id);
});

test("the same seed gives the same map; the committed golden table still matches", () => {
  const sl = slice(), list = templates(sl);
  const a = PB.mapgen.generate(4242, sl, list), b = PB.mapgen.generate(4242, sl, list);
  assert.deepEqual(a, b);
  const shapes = new Set([1, 2, 3, 4, 5, 6, 7, 8].map((s) => JSON.stringify(PB.mapgen.generate(s, sl, list).rooms.map((r) => [r.x, r.y, r.template]))));
  assert.ok(shapes.size >= 6, "different seeds give different maps");
  const golden = readJson("content/export/delivery-golden.json").maps;
  assert.ok(golden.length >= 30);
  for (const g of golden) {
    const m = PB.mapgen.generate(g.seed, sl, list);
    assert.deepEqual({ path: m.path, rooms: m.rooms, dir: m.dir, attempt: m.attempt }, { path: g.path, rooms: g.rooms, dir: g.dir, attempt: g.attempt }, "seed " + g.seed);
  }
});

test("xorshift32 matches its reference values (a port must reproduce these)", () => {
  const r = PB.mapgen.makeRng(1);
  assert.deepEqual([r.next(), r.next(), r.next()], [r0(1)[0], r0(1)[1], r0(1)[2]]);
  // Independent reference implementation with BigInt.
  function r0(seed) {
    let x = (BigInt(seed) ^ 0x9e3779b9n) & 0xffffffffn; if (x === 0n) x = 1n;
    const out = [];
    for (let i = 0; i < 7; i++) { x ^= (x << 13n) & 0xffffffffn; x ^= x >> 17n; x ^= (x << 5n) & 0xffffffffn; if (i >= 4) out.push(Number(x)); }
    return out;
  }
});

test("neighbouring rooms always open the same slot on their shared edge; one-way rooms face the path", () => {
  const sl = slice(), list = templates(sl), byId = new Map(list.map((t) => [t.id, t]));
  for (let seed = 1; seed <= 80; seed++) {
    const m = PB.mapgen.generate(seed, sl, list);
    for (let i = 0; i + 1 < m.rooms.length; i++) {
      const a = m.rooms[i], b = m.rooms[i + 1], e = PB.rooms.edgeToward([a.x, a.y], [b.x, b.y]);
      assert.ok(e, `seed ${seed}: rooms ${i} and ${i + 1} are neighbours`);
      assert.equal(a.open[e], b.open[PB.rooms.OPPOSITE[e]], `seed ${seed}: slot on ${e}`);
      if (i > 0) {
        const into = PB.rooms.edgeToward([a.x, a.y], [m.rooms[i - 1].x, m.rooms[i - 1].y]);
        assert.ok(PB.rooms.allows(byId.get(a.template), a.mirror, into, e), `seed ${seed}: room ${i} (${a.template}) is walked ${into}>${e}`);
      }
    }
    assert.equal(m.rooms[0].role, "gate");
    assert.equal(m.rooms[m.rooms.length - 1].role, "home");
    assert.equal(m.rooms.filter((r) => r.role === "station").length, 1);
  }
});

test("static rules: border, legend, monster spacing and exits are enforced", () => {
  const base = readJson("content/rooms/dungeon/dungeon_hall.json"), monsters = new Map(readJson("content/catalog/monsters.json").entries.map((m) => [m.id, m]));
  const bad = (fn) => { const t = JSON.parse(JSON.stringify(base)); fn(t); return PB.rooms.validate(t, { monsters, world: "dungeon" }).errors.join(" | "); };
  assert.equal(bad(() => {}), "");
  assert.match(bad((t) => { t.map[0] = "." + t.map[0].slice(1); }), /边框/);
  assert.match(bad((t) => { t.map[7] = "7" + t.map[7].slice(1); }), /legend|出入口/);
  assert.match(bad((t) => { t.map[7] = t.map[7].slice(0, 2) + "1" + t.map[7].slice(3); }), /离出入口/);
  assert.match(bad((t) => { t.legend["1"].monster = "ghost"; }), /不属于 dungeon/);
  assert.match(bad((t) => { t.exits.top = ["mid"]; }), /竖井口/);
});

test("an unreachable route fails the check and the content check reports a stale or failing room", () => {
  const root = sandbox();
  // Wall the hall off in the middle: no route from left to right any more.
  editRoom(root, "dungeon_hall", (t) => { for (let y = 1; y < 9; y++) t.map[y] = t.map[y].slice(0, 10) + "#" + t.map[y].slice(11); });
  const errs = () => buildContent(root).issues.filter((i) => i.level === "error").map((i) => i.where + ": " + i.msg);
  assert.ok(errs().some((e) => e.includes("dungeon_hall") && e.includes("过期")), "edited template without a new check is stale");
  const { report, failed } = checkRooms(root, { seeds: 20 });
  assert.ok(failed > 0);
  const hall = report.templates.find((t) => t.id === "dungeon_hall");
  assert.ok(hall.placements.some((p) => p.routes.some((r) => !r.ok)));
  fs.writeFileSync(path.join(root, "content/rooms-check.generated.json"), JSON.stringify(report));
  assert.ok(errs().some((e) => e.includes("dungeon_hall") && e.includes("走不通")));
});

test("a fall of 3 rows that does not land on sand is not a route", () => {
  // Ledge at row 4, floor at row 8: dropping off the ledge falls 3 rows.
  const rows = ["####################", "#..................#", "#..................#", "#..................#", "#.....#############.", "#..................#", "#..................#", "#..................#", "####################", "####################"];
  const v = { id: "t", mirror: false, rows, spawns: [], coins: [], exits: {}, world: "dungeon" };
  const spec = PB.rooms.specOf(v, 6, 3);
  assert.equal(PB.rooms.reach(spec, { goal: [[3, 7]] }).ok, false, "jumping off the ledge hurts, so it is not a route");
  rows[7] = "#....s.............#";   // a sand cushion where the fall lands (column 5)
  const soft = PB.rooms.reach(PB.rooms.specOf(Object.assign({}, v, { rows }), 6, 3), { goal: [[3, 7]] });
  assert.equal(soft.ok, true, "landing on sand is safe");
});
