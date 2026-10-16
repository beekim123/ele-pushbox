// Real-time rules of the delivery mode (workbench/js/core/realtime.js,
// docs/design/delivery-realtime.md). Design model only; the repository is read, never written.
import { test } from "node:test";
import assert from "node:assert/strict";
import fs from "node:fs";
import path from "node:path";
import { fileURLToPath } from "node:url";
import { loadCore, listJson } from "../tools/lib/load-core.mjs";

const REPO = path.resolve(path.dirname(fileURLToPath(import.meta.url)), "..");
const PB = loadCore(["tilemodel", "rooms", "mapgen", "realtime"]);
const read = (p) => JSON.parse(fs.readFileSync(path.join(REPO, p), "utf8"));
const cat = { monsters: read("content/catalog/monsters.json").entries, cargo: read("content/catalog/cargo.json").entries, recipients: read("content/catalog/recipients.json").entries, items: read("content/catalog/items.json").entries };
const slice = read("content/catalog/slices.json").entries.find((s) => s.id === "dungeon_1");
const room = (id) => read(`content/rooms/dungeon/${id}.json`);
const ctx = (cargo, recipient) => PB.rt.context(cat, slice, cargo || "letter", recipient || null);

// A small test room built from rows: "P" player, "1" rat swarm, "2" skeleton guard (facing left).
function lab(rows, opts) {
  const o = opts || {}, t = { format: "pushbox.room/1", id: "t", world: "dungeon", type: "room", exits: {}, legend: { 1: { monster: "rat_swarm", dir: "left" }, 2: { monster: "skeleton_guard", dir: "left" } }, map: rows.map((r) => r.replace("P", ".")) };
  const py = rows.findIndex((r) => r.includes("P")), px = rows[py].indexOf("P");
  const run = PB.rt.newRun(ctx(o.cargo, o.recipient), o.run);
  const rm = PB.rt.makeRoom(run.ctx, t, false, {});
  PB.rt.enter(run, rm, px, py, 1);
  return run;
}
const W = (s) => "#" + s.padEnd(18, ".") + "#";   // one row with the side walls
const FLOOR = "####################";
function tickUntil(run, pred, input, max) { for (let i = 0; i < (max || 2000); i++) { if (pred(run)) return i; PB.rt.step(run, typeof input === "function" ? input(i) : input || {}); } return -1; }

test("move interval: a held key walks one tile every 13 ticks (0.22 s); a press during the pause is buffered", () => {
  const run = lab([FLOOR, W(""), W(""), W(""), W(""), W(""), W(""), W("P"), FLOOR, FLOOR]);
  const seen = [];
  for (let i = 0; i < 40; i++) { const ev = PB.rt.step(run, { held: "R" }); if (ev.some((e) => e.type === "walk")) seen.push(run.tick); }
  assert.deepEqual(seen, [1, 14, 27, 40]);
  // Pressed once at tick 45 (mid-pause): it runs when the pause ends at tick 53, not later and not lost.
  for (let i = 0; i < 4; i++) PB.rt.step(run, {});
  PB.rt.step(run, { press: "L" });
  const t = tickUntil(run, (r) => r.events.some((e) => e.type === "walk" && e.t > 45));
  assert.ok(t >= 0);
  assert.equal(run.events.find((e) => e.type === "walk" && e.t > 45).t, 53);
});

test("gravity: one tile every 5 ticks; a fall of 3 rows hurts, 2 rows does not, sand cushions; the vase cracks from 2 rows", () => {
  const fallFrom = (rows, cargo) => {
    const run = lab(rows, { cargo });
    PB.rt.step(run, { press: "R" });
    tickUntil(run, (r) => r.events.some((e) => e.type === "land"));
    return run;
  };
  const three = fallFrom([FLOOR, W(""), W(""), W(""), W("P."), W("#."), W(".."), W(".."), FLOOR, FLOOR]);
  assert.equal(three.hearts, 2, "3 rows hurt");
  assert.equal(three.events.find((e) => e.type === "land").t - 1, 15, "3 rows take 15 ticks");
  const two = fallFrom([FLOOR, W(""), W(""), W(""), W(""), W("P."), W("#."), W(".."), FLOOR, FLOOR], "vase");
  assert.equal(two.hearts, 3, "2 rows do not hurt the player");
  assert.equal(PB.rt.integrity(two), 2, "but crack the vase");
  const soft = fallFrom([FLOOR, W(""), W(""), W("P."), W("#."), W(".."), W(".."), W(".s"), FLOOR, FLOOR], "vase");
  assert.equal(soft.hearts, 3, "landing on sand is soft");
  assert.equal(PB.rt.integrity(soft), 3, "and the vase survives");
});

test("push a rat: it moves one tile and is stunned; pushed off a 3-row drop it is knocked out and drops its coins", () => {
  const run = lab([FLOOR, W(""), W(""), W(""), W("P1.."), W("###"), W(""), W(""), FLOOR, FLOOR]);
  const rat = run.room.monsters[0];
  PB.rt.step(run, { press: "R" });
  assert.equal(rat.state, "stunned");
  assert.equal(rat.x, 3);
  assert.equal(rat.until, run.room.t + 30, "push_stun_secs 0.5 on the room clock");
  tickUntil(run, (r) => r.room.player.cd === 0);
  PB.rt.step(run, { press: "R" });
  tickUntil(run, (r) => rat.ko);
  assert.equal(rat.ko, true);
  assert.ok(run.events.some((e) => e.type === "ko" && e.how === "fall"));
  assert.ok(run.room.pickups.some((q) => q.kind === "coin" && q.value === 5));
});

test("crush and bury: a falling crate or poured sand knocks a monster out", () => {
  // Crate on a ledge above the skeleton's path; the player pushes it off.
  const run = lab([FLOOR, W(""), W(""), W(""), W("PB."), W("##."), W("..."), W("..2#"), FLOOR, FLOOR]);
  const sk = run.room.monsters[0];
  sk.cd = 9999;   // keep it still under the drop
  PB.rt.step(run, { press: "R" });
  tickUntil(run, () => sk.ko, {}, 200);
  assert.ok(run.events.some((e) => e.type === "ko" && e.how === "crushed"));
  // Sand poured next to a pit with a trapped rat buries it.
  const r2 = lab([FLOOR, W(""), W(""), W(""), W(""), W(""), W(""), W("P..1#"), "####.###############", FLOOR], { run: { sand: 1 } });
  const rat = r2.room.monsters[0];
  rat.state = "trapped"; rat.until = 9999; rat.y = 8; rat.x = 4;
  r2.room.player.x = 3;
  PB.rt.step(r2, { press: "POUR_R" });
  tickUntil(r2, () => rat.ko, {}, 100);
  assert.ok(r2.events.some((e) => e.type === "ko" && e.how === "buried"));
});

test("trap: a patrol walks into a one-wide pit, is stuck for trap_secs, then climbs out", () => {
  const run = lab([FLOOR, W(""), W(""), W(""), W(""), W(""), W(""), W("P......2...#"), "########.###########", FLOOR]);
  const sk = run.room.monsters[0];
  tickUntil(run, () => sk.state === "trapped", {}, 1000);
  assert.equal(sk.state, "trapped");
  assert.deepEqual([sk.x, sk.y], [8, 8]);
  const at = run.tick;
  tickUntil(run, () => sk.state !== "trapped", {}, 1000);
  assert.equal(run.tick - at, 5 * 60, "skeleton_guard: trap_secs 5");
  assert.equal(sk.y, 7, "climbed out of the pit");
});

test("a room the player is not in stands still: a trapped monster is still trapped when the player comes back", () => {
  const run = lab([FLOOR, W(""), W(""), W(""), W(""), W(""), W(""), W("P......2...#"), "########.###########", FLOOR]);
  const a = run.room, sk = a.monsters[0];
  tickUntil(run, () => sk.state === "trapped", {}, 1000);
  const left = sk.until - a.t, clock = run.clock;
  // Twenty seconds in another room, then back.
  const b = PB.rt.makeRoom(run.ctx, { format: "pushbox.room/1", id: "b", world: "dungeon", type: "room", exits: {}, legend: {}, map: [FLOOR, W(""), W(""), W(""), W(""), W(""), W(""), W(""), FLOOR, FLOOR] }, false, {});
  PB.rt.enter(run, b, 1, 7, 1);
  for (let i = 0; i < 1200; i++) PB.rt.step(run, {});
  PB.rt.enter(run, a, 1, 7, 1);
  assert.equal(sk.state, "trapped");
  assert.equal(sk.until - a.t, left, "its timer did not run while the player was away");
  assert.equal(run.clock - clock, 1200, "the delivery clock did");
});

test("walking into a trapped skeleton does not hurt", () => {
  const run = lab([FLOOR, W(""), W(""), W(""), W(""), W(""), W(""), W("P2.......#"), FLOOR, FLOOR]);
  const sk = run.room.monsters[0];
  sk.state = "trapped"; sk.until = 9999;
  for (let i = 0; i < 120; i++) PB.rt.step(run, { held: "R" });
  assert.equal(run.hearts, 3);
});

test("station: talking opens the shelf and heals once; the shelf checks stock, coins, bag and slots; items are used from their slot", () => {
  const t = room("dungeon_station");
  const { run } = PB.rt.roomRun(ctx(), t, { mirror: false, open: { left: "low", right: "low" } }, "left.low", { coins: 200 });
  assert.equal(PB.rt.buy(run, "sandbag").why, "closed", "the shelf opens by talking to the keeper");
  const talks = () => run.events.filter((e) => e.type === "talk");
  const ready = () => tickUntil(run, (r) => PB.rt.ready(r), {}, 200);
  const sp = PB.rt.scriptPlayer(run, ["R*3", "U"]);
  while (!talks().length) sp.tick();
  assert.equal(talks()[0].heal, 0, "full hearts: nothing healed, the heal is kept for later");
  run.hearts = 2; ready(); PB.rt.step(run, { press: "U" });
  assert.equal(talks()[1].heal, 1); assert.equal(run.hearts, 3);
  run.hearts = 2; ready(); PB.rt.step(run, { press: "U" });
  assert.equal(talks()[2].heal, 0, "once per station"); assert.equal(run.hearts, 2);
  assert.equal(PB.rt.buy(run, "first_aid").ok, true);
  assert.equal(PB.rt.buy(run, "first_aid").why, "stock", "one first aid kit in stock");
  assert.equal(PB.rt.buy(run, "rope_ladder").ok, true);
  assert.equal(run.coins, 200 - 50 - 25);
  run.items.push("first_aid");
  assert.equal(PB.rt.buy(run, "rope_ladder").why, "slots", "three item slots");
  run.items.pop(); run.coins = 10;
  assert.equal(PB.rt.buy(run, "rope_ladder").why, "coins");
  run.sand = 9;
  assert.equal(PB.rt.buy(run, "sandbag").why, "full", "at most 9 bags");
  run.sand = 0;
  assert.equal(PB.rt.buy(run, "sandbag").ok, true); assert.equal(run.sand, 1); assert.equal(run.coins, 0);
  assert.deepEqual(run.items, ["first_aid", "rope_ladder"]);
  run.hearts = 3; ready(); PB.rt.step(run, { press: "USE_1" });
  assert.deepEqual(run.items, ["first_aid", "rope_ladder"], "first aid is not used at full hearts");
  run.hearts = 2; ready(); PB.rt.step(run, { press: "USE_1" });
  assert.equal(run.hearts, 3); assert.deepEqual(run.items, ["rope_ladder"], "the next item moves up to slot 1");
  ready(); PB.rt.step(run, { press: "USE_1" });
  assert.deepEqual(run.items, []); assert.ok(PB.rt.pred.ladder(run.room, run.room.player.x + 1, 7), "the rope ladder hangs in front of the player");
});

test("contact: the skeleton hurts once (then i-frames); the rat steals sand, then coins, and runs away", () => {
  const run = lab([FLOOR, W(""), W(""), W(""), W(""), W(""), W(""), W("P2.......#"), FLOOR, FLOOR]);
  tickUntil(run, (r) => r.hearts < 3, {}, 200);
  assert.equal(run.hearts, 2);
  assert.equal(run.iframes > 0, true);
  const r2 = lab([FLOOR, W(""), W(""), W(""), W(""), W(""), W(""), W("P.1.......#"), FLOOR, FLOOR], { run: { sand: 1, coins: 10 } });
  tickUntil(r2, (r) => r.events.some((e) => e.type === "steal"), {}, 200);
  assert.equal(r2.sand, 0, "sand first");
  assert.equal(r2.coins, 10);
  assert.equal(r2.room.monsters[0].state, "flee");
  assert.equal(r2.room.monsters[0].carry.sand, 1);
});

test("monsters keep out of ladders and never step onto the player's head", () => {
  const run = lab([FLOOR, W(""), W(""), W(""), W(""), W(""), W(""), W(".H...2..#"), FLOOR, FLOOR].map((r, i) => (i === 7 ? r.replace(/^#\./, "#P") : r)));
  const sk = run.room.monsters[0];
  for (let i = 0; i < 600; i++) { PB.rt.step(run, {}); assert.ok(sk.x >= 3, "never enters the ladder at x=2"); }
  const r2 = lab([FLOOR, W(""), W(""), W(""), W(""), W(""), W(""), W("....2..#"), "#P##################", FLOOR]);
  r2.room.player.y = 8; r2.room.player.x = 1;
  for (let i = 0; i < 600; i++) { PB.rt.step(r2, {}); assert.ok(!(r2.room.monsters[0].x === 1 && r2.room.monsters[0].y === 7), "never on the player's head"); }
});

test("restart this room: the room and the run go back to the door, the clock does not", () => {
  const t = room("dungeon_burrow");
  const { run } = PB.rt.roomRun(ctx(), t, { mirror: false, open: { left: "low", right: "low" } }, "left.low");
  for (let i = 0; i < 300; i++) PB.rt.step(run, { held: "R", press: i === 60 ? "DIG_R" : null });
  const clock = run.clock;
  PB.rt.resetRoom(run);
  assert.equal(run.sand, 0);
  assert.equal(run.room.player.x, 0);
  assert.equal(run.room.terrain[7 * 20 + 6], PB.tilemodel.T.EARTH, "the dug earth is back");
  assert.equal(run.clock, clock, "time keeps running");
});

test("given time to settle, the real-time rules end where the lab tile model ends (basics M01-M07)", () => {
  for (const rel of listJson("content/levels/lab/basics")) {
    const spec = read(rel), lab0 = PB.tilemodel.replay(spec, spec.solution), want = lab0.steps[lab0.steps.length - 1].state;
    const run = PB.rt.roomFromSpec(ctx(), spec);
    for (const a of spec.solution) {
      tickUntil(run, (r) => r.room.player.cd === 0 && PB.rt.ready(r), {}, 400);
      PB.rt.step(run, { press: a });
      tickUntil(run, (r) => PB.rt.ready(r) && !r.room.crates.some((c) => c.fallT) && r.room.sandFall.size === 0 && r.room.player.fallT === 0 && r.room.player.cd === 0, {}, 400);
    }
    const rm = run.room;
    assert.deepEqual([rm.player.x, rm.player.y], [want.player.x, want.player.y], spec.id + " player");
    assert.deepEqual(rm.crates.map((c) => [c.x, c.y]).sort(), want.crates.map((c) => [c.x, c.y]).sort(), spec.id + " crates");
    assert.deepEqual(Array.from(rm.terrain), Array.from(want.terrain), spec.id + " terrain");
    assert.equal(run.sand, want.bag.sand, spec.id + " bag");
  }
});

test("every recorded replay in the golden file plays back frame for frame", () => {
  const golden = read("content/export/delivery-golden.json");
  assert.ok(golden.replays.length >= 20);
  for (const g of golden.replays) {
    const t = room(g.template), d = t.demos.find((x) => x.id === g.demo);
    const r = PB.rt.runDemo(cat, slice, t, d, g.mirror);
    assert.equal(r.ok, true, `${g.template}/${g.demo}${g.mirror ? "~m" : ""}`);
    assert.deepEqual(r.frames, g.frames, `${g.template}/${g.demo} frames`);
  }
});

test("settlement: tip = pay x integrity x time x like, in integers; failure keeps half the coins", () => {
  const run = PB.rt.newRun(ctx("letter", "old_miner"));
  run.coins = 20; run.clock = 600; run.done = { ok: true, reason: "delivered" };
  let q = PB.rt.settlement(run, 900);
  assert.equal(q.timePct, 150); assert.equal(q.likePct, 150, "the old miner likes letters");
  assert.equal(q.tip, Math.round(30 * 1 * 1.5 * 1.5)); assert.equal(q.rating, "S"); assert.equal(q.total, 20 + q.tip);
  run.clock = 1800; run.cargo.damage = 1;
  q = PB.rt.settlement(run, 900);
  assert.equal(q.timePct, 50); assert.equal(q.rating, "C");
  run.done = { ok: false, reason: "hearts" };
  q = PB.rt.settlement(run, 900);
  assert.equal(q.tip, 0); assert.equal(q.total, 10);
});

test("a whole map: the run walks from the gate into the next room through the matching exit", () => {
  const list = read("content/catalog/slices.json").entries[0].rooms.map(room).sort((a, b) => a.id.localeCompare(b.id));
  const map = PB.mapgen.generate(11, slice, list);
  const run = PB.rt.startRun(ctx(), map, new Map(list.map((t) => [t.id, t])));
  const first = map.rooms[0], second = map.rooms[1], edge = PB.rooms.edgeToward([first.x, first.y], [second.x, second.y]);
  const key = { left: "L", right: "R", top: "U", bottom: "D" }[edge];
  // Walk toward the exit (sideways, or to the shaft and along it).
  for (let i = 0; i < 4000 && run.roomIndex === 0; i++) {
    const p = run.room.player;
    let held = key;
    if (edge === "top" || edge === "bottom") held = p.x < 9 ? "R" : p.x > 9 ? "L" : key;
    PB.rt.stepRun(run, { held });
  }
  assert.equal(run.roomIndex, 1, "entered the second room of the path");
  assert.ok(run.events.some((e) => e.type === "room" && e.index === 1));
  const p = run.room.player;
  if (edge === "left") assert.equal(p.x, 19); else if (edge === "right") assert.equal(p.x, 0);
});
