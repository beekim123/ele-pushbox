// Delivery v2 rooms, format pushbox.room/2 (docs/design/delivery-puzzle-rules.md):
// float blocks and the pole, falls, the follow camera, runs from the pool, the
// checker and its committed report, the text tables, the renderer
// (delivery-scene2.js: also the sky top edge and the ladder heads of section 8)
// and the diyu terrain and backdrop (terrain-diyu.js).
// The repository is only read.
import { test } from "node:test";
import assert from "node:assert/strict";
import fs from "node:fs";
import path from "node:path";
import vm from "node:vm";
import { checkRooms2, loadRooms2 } from "../tools/check-rooms2.mjs";
import { loadTextTables } from "../tools/lib/i18n.mjs";
import { loadCore, ROOT } from "../tools/lib/load-core.mjs";

const readJson = (p) => JSON.parse(fs.readFileSync(path.join(ROOT, p), "utf8"));
// terrain.js first: its own drawTerrain / drawBackground are kept to compare with the diyu wrapper.
const BASE = (({ drawTerrain, drawBackground }) => ({ drawTerrain, drawBackground }))(
  loadCore(["raster", "font-data", "font-small", "font-delivery", "font-rooms2", "sprites", "i18n", "tilemodel", "terrain"]).terrain);
const PB = loadCore(["terrain-diyu", "ambient", "env", "matter", "scene", "dialogue", "ui", "rooms", "mapgen", "rooms2", "mapgen2", "delivery-scene", "delivery-scene2"]);
const R = PB.rooms2, TM = PB.tilemodel, D = PB.droom2;
const bundle = {};
vm.runInNewContext(fs.readFileSync(path.join(ROOT, "workbench/data/bundle.js"), "utf8"), { window: bundle });
for (const a of bundle.PB_BUNDLE.assets) PB.sprites.register(a);
PB.i18n.setTables(loadTextTables(ROOT).tables);
PB.i18n.setLocale("zh-Hans");
const catalog = (n) => readJson(`content/catalog/${n}.json`).entries;
const worlds = new Map(catalog("worlds").map((w) => [w.id, w]));
const ROOMS = loadRooms2(ROOT).map((x) => x.room);
const MAPS2 = catalog("slices").filter((s) => s.format === 2);
const mapOf = (id) => MAPS2.find((s) => (s.rooms2 || []).includes(id));
const at = (s) => [s.player.x, s.player.y];

// A 1 x 1 test room: bedrock border and floor (rows 8-9), open air above, the
// exits cut into the border, then `cells` ([x, y, "chars"]) written in.
function testRoom(cells, exits = ["left.0.low", "right.0.low"]) {
  const g = Array.from({ length: R.SH }, (_, y) => [...(y === 0 || y >= 8 ? "#".repeat(R.SW) : "#" + ".".repeat(R.SW - 2) + "#")]);
  for (const id of exits) {
    const side = ["left", "right"].includes(R.parseExit(id).edge);
    for (const [x, y] of R.exitCells(R.SW, R.SH, id)) g[y][x] = side ? "." : "H";
  }
  for (const [x, y, s] of cells) [...s].forEach((ch, i) => { g[y][x + i] = ch; });
  const room = { format: "pushbox.room/2", world: "dungeon", id: "test", type: "room", role: "develop", size: [1, 1], name: "test",
    exits, routes: [exits[0] + ">" + exits[1]], map: g.map((r) => r.join("")) };
  assert.deepEqual(R.validate(room), []);
  return room;
}
const play = (room, from, mirror = false) => R.start(R.variant(room, mirror, null), from, null);

test("walking into a float block's end pushes it one tile with the crates on it; blocked ahead it is a wall to step onto", () => {
  // FFF at x 4-6 on the floor row, a crate on its middle.
  let M = play(testRoom([[4, 7, "FFF"], [5, 6, "B"]]), "left.0.low"), s = M.s;
  for (let i = 0; i < 3; i++) assert.equal(R.act(M, s, "R").ok, true);
  assert.deepEqual(at(s), [3, 7]);
  assert.equal(R.act(M, s, "R").kind, "float-push");
  assert.deepEqual([s.floats[0].x, s.floats[0].y], [5, 7]);
  assert.deepEqual(at(s), [4, 7], "the pusher follows the block");
  assert.ok(TM.crateAt(s, 6, 6) && !TM.crateAt(s, 5, 6), "the crate rode along");
  assert.equal(TM.terrainAt(M.L, s, 4, 7), TM.T.EMPTY);
  assert.equal(TM.terrainAt(M.L, s, 7, 7), TM.T.ROCK, "the block is solid where it went");
  assert.ok(R.floatAt(s, 7, 7) && !R.floatAt(s, 4, 7));

  // Switched off (the checker's "is it required" search) the block is just a wall: step up.
  M = play(testRoom([[4, 7, "FFF"]]), "left.0.low"); s = M.s;
  for (let i = 0; i < 3; i++) R.act(M, s, "R");
  assert.equal(R.act(M, s, "R", new Set(["float_block"])).kind, "step");
  assert.equal(s.floats[0].x, 4);

  // Rock right after the block: it does not move, the player steps up onto it...
  M = play(testRoom([[4, 7, "FFF#"]]), "left.0.low"); s = M.s;
  for (let i = 0; i < 3; i++) R.act(M, s, "R");
  assert.equal(R.act(M, s, "R").kind, "step");
  assert.deepEqual(at(s), [4, 6]);
  assert.equal(s.floats[0].x, 4);
  // ... and with a crate on the near end there is no room to step up either.
  M = play(testRoom([[4, 7, "FFF#"], [4, 6, "B"]]), "left.0.low"); s = M.s;
  for (let i = 0; i < 3; i++) R.act(M, s, "R");
  assert.deepEqual(R.act(M, s, "R"), { ok: false, reason: "blocked" });
  assert.equal(s.floats[0].x, 4);

  // A float block never moves into an exit opening.
  M = play(testRoom([[15, 7, "FFF"]]), "left.0.low"); s = M.s;
  for (let i = 0; i < 14; i++) R.act(M, s, "R");
  assert.equal(R.act(M, s, "R").kind, "float-push");
  assert.equal(s.floats[0].x, 16);
  assert.equal(R.act(M, s, "R").kind, "step", "the next tile is the right exit");
  assert.equal(s.floats[0].x, 16);
});

test("the pole: on a float block, the shovel against a wall it cannot dig moves the block the other way, rider and crates included", () => {
  for (const mirror of [false, true]) {
    const X = (x) => (mirror ? R.SW - 1 - x : x);
    const M = play(testRoom([[4, 7, "FFF"], [7, 6, "#"], [4, 6, "B"]]), mirror ? "right.0.low" : "left.0.low", mirror), s = M.s;
    s.player.x = X(6); s.player.y = 6;   // on the far end of the block, facing the wall
    const r = R.act(M, s, mirror ? "DIG_L" : "DIG_R");
    assert.equal(r.kind, "pole", mirror ? "mirrored" : "as drawn");
    const f = s.floats[0];
    assert.equal(mirror ? R.SW - f.x - f.w : f.x, 3, "the block moved one tile away from the wall");
    assert.deepEqual(at(s), [X(5), 6], "the player rode along");
    assert.ok(TM.crateAt(s, X(3), 6), "so did the crate");
  }
  // Something right behind the block: nothing moves. Switched off: refused.
  const M = play(testRoom([[3, 7, "#FFF"], [7, 6, "#"]]), "left.0.low"), s = M.s;
  s.player.x = 6; s.player.y = 6;
  assert.deepEqual(R.act(M, s, "DIG_R"), { ok: false, reason: "pole-blocked" });
  assert.equal(s.floats[0].x, 4);
  assert.deepEqual(at(s), [6, 6]);
  assert.equal(R.act(M, s, "DIG_R", new Set(["pole"])).reason, "frozen");
});

test("a fall of 3 rows or more hurts unless it lands on sand, and no route may use one", () => {
  const exits = ["left.0.high", "right.0.low"];
  const fall = (pad) => {
    const room = testRoom([[1, 4, "###"], ...(pad ? [pad] : [])], exits);
    const M = play(room, "left.0.high"), s = M.s;
    for (let i = 0; i < 3; i++) R.act(M, s, "R");
    assert.deepEqual(at(s), [3, 3]);
    const r = R.act(M, s, "R");
    return { drop: r.drop, hurt: R.hurts(M, s, r), solved: R.solve(R.variant(room, false, null), exits[0], exits[1]).solved };
  };
  assert.equal(R.FALL_HURT, 3);
  assert.deepEqual(fall(null), { drop: 4, hurt: true, solved: false }, "down to the floor");
  assert.deepEqual(fall([4, 7, "#"]), { drop: 3, hurt: true, solved: false }, "3 rows onto rock");
  assert.deepEqual(fall([4, 7, "s"]), { drop: 3, hurt: false, solved: true }, "3 rows onto sand");
  assert.deepEqual(fall([4, 6, "#"]), { drop: 2, hurt: false, solved: true }, "2 rows");
});

test("the follow camera moves in whole pixels inside the room; a one-screen room never moves", () => {
  const sized = (k) => ROOMS.find((r) => (r.size || [1, 1]).join("x") === k);
  const v1 = R.variant(sized("1x1"), false, null);
  const c1 = R.cameraStart(v1, 100, 80, 1);
  for (let t = 0; t < 200; t++) R.cameraStep(v1, c1, (t * 3) % 300, 80, t % 50 < 25 ? 1 : -1, t % 7 !== 0);
  assert.deepEqual([c1.x, c1.y], [0, 0]);
  const v = R.variant(sized("2x2"), false, null), maxX = v.W * R.TILE - R.CAM.viewW, maxY = v.H * R.TILE - R.CAM.viewH;
  const y = (v.H - 3) * R.TILE, cam = R.cameraStart(v, R.TILE, y, 1);
  let px = R.TILE, prev = [cam.x, cam.y];
  for (let t = 0; t < 600; t++) {
    const dir = t < 300 ? 1 : -1;
    px = Math.max(0, Math.min(v.W * R.TILE - R.TILE, px + dir * 2));
    R.cameraStep(v, cam, px, y, dir, true);
    assert.ok(Number.isInteger(cam.x) && Number.isInteger(cam.y));
    assert.ok(cam.x >= 0 && cam.x <= maxX && cam.y >= 0 && cam.y <= maxY, `tick ${t}: inside the room`);
    assert.ok(Math.abs(cam.x - prev[0]) <= R.CAM.maxStep && Math.abs(cam.y - prev[1]) <= R.CAM.maxStep, `tick ${t}: eases`);
    prev = [cam.x, cam.y];
    if (t === 299) assert.equal(cam.x, maxX, "followed to the right edge");
  }
  assert.ok(cam.x < maxX, "and back");
});

test("a run: the same seed and picks give the same map; picks replace a reel's result without shifting later draws", () => {
  const slices = catalog("slices"), maps = new Map(slices.filter((s) => s.format === 2).map((s) => [s.id, s]));
  const pool = slices.find((s) => s.pool);
  const cat = { recipients: new Map(catalog("recipients").map((e) => [e.id, e])), cargo: new Map(catalog("cargo").map((e) => [e.id, e])) };
  const byId = new Map(ROOMS.map((r) => [r.id, r]));
  const templatesOf = (sid) => (maps.get(sid).rooms2 || []).map((id) => byId.get(id)).filter(Boolean);
  const gen = (seed, picks) => PB.mapgen2.generate(seed, pool, maps, cat, templatesOf, picks);
  for (const seed of [1, 7, 42, 2026]) {
    const m = gen(seed);
    assert.deepEqual(gen(seed), m);
    assert.deepEqual(PB.mapgen2.joints(m), [], `seed ${seed}: exits meet`);
    // Picking exactly what the reels drew changes nothing: every reel still draws once.
    assert.deepEqual(gen(seed, { map: m.slice, recipient: m.recipient, cargo: m.cargo }), m);
  }
  assert.ok(new Set([1, 2, 3, 4, 5, 6, 7, 8].map((s) => JSON.stringify(gen(s).rooms))).size >= 6, "different seeds, different maps");
  const picks = { map: "diyu_1", recipient: "ancestor", cargo: "paper_house" };
  const a = gen(42, picks);
  assert.deepEqual(gen(42, picks), a);
  assert.deepEqual([a.slice, a.recipient, a.cargo], ["diyu_1", "ancestor", "paper_house"]);
  assert.equal(a.drawn.map, gen(42).drawn.map, "the map reel still drew");
  assert.deepEqual(PB.mapgen2.joints(a), []);
  // A pick the map does not allow falls back to the draw: paper houses only go to ancestors and the wuchang.
  assert.deepEqual(maps.get("diyu_1").cargo_only.paper_house.slice().sort(), ["ancestor", "wuchang"]);
  const b = gen(42, { map: "diyu_1", recipient: "meng_po", cargo: "paper_house" });
  assert.equal(b.recipient, "meng_po");
  assert.notEqual(b.cargo, "paper_house");
  assert.equal(gen(42, { map: "diyu_1", recipient: "nobody" }).recipient, gen(42, { map: "diyu_1" }).recipient);
});

test("every v2 room and the run pool pass the checker, and the committed report is current", () => {
  const { report, failed } = checkRooms2(ROOT, { seeds: 300 });
  assert.equal(failed, 0, JSON.stringify(report.templates.filter((t) => t.errors.length).map((t) => [t.id, t.errors])));
  assert.equal(report.templates.length, ROOMS.length);
  for (const p of report.pools) {
    assert.ok(p.ok, JSON.stringify(p.failures));
    assert.deepEqual(Object.keys(p.maps).sort(), ["diyu_1", "dungeon_2", "jeju_1"], "all three maps come up");
  }
  const noTimes = (r) => JSON.stringify(r, (k, v) => (k === "ms" ? undefined : v));
  assert.equal(noTimes(report), noTimes(readJson("content/rooms2-check.generated.json")), "run node tools/check-rooms2.mjs --write");
});

test("the v2 text tables mirror every room's name and hints, in both languages", () => {
  const zh = readJson("content/i18n-rooms2/zh-Hans.json"), en = readJson("content/i18n-rooms2/en.json");
  const want = new Set();
  for (const room of ROOMS) {
    const k = `room2.${room.id}.name`;
    want.add(k);
    assert.equal(zh[k], room.name, k);
    (room.hints || []).forEach((h, i) => { const kh = `room2.${room.id}.hint.${i}`; want.add(kh); assert.equal(zh[kh], h.text, kh); });
  }
  for (const k of Object.keys(zh)) if (k.startsWith("room2.")) assert.ok(want.has(k), `${k}: no such room text any more`);
  // What a flying hint animal says when fed (it sends you to the main one) is its catalog line.
  for (const w of worlds.values()) for (const f of w.hint_fauna || []) if (f.fed && !f.snack) assert.equal(zh[`dlg.fauna.${f.id}.fed`], f.fed, f.id);
  for (const k of Object.keys(zh)) if (k !== "_meta") assert.ok(typeof en[k] === "string" && en[k].length > 0, `en: ${k}`);
  assert.deepEqual(Object.keys(en).filter((k) => !(k in zh)), []);
});

test("every v2 room draws (whole room and camera view, mirrored too) and its solution plays to the end", () => {
  const maps = new Map(catalog("slices").filter((s) => s.format === 2).map((s) => [s.world, s]));
  const opaque = (r) => { for (let i = 3; i < r.data.length; i += 4) if (r.data[i] !== 255) return false; return true; };
  const colours = (r) => { const c = new Set(); for (let i = 0; i < r.data.length; i += 4) c.add((r.data[i] << 16) | (r.data[i + 1] << 8) | r.data[i + 2]); return c.size; };
  for (const room of ROOMS) {
    const world = worlds.get(room.world), W = (room.size || [1, 1])[0];
    const recipient = room.type === "home" ? ((room.only || {}).recipients || maps.get(room.world).recipients)[0] : undefined;
    for (const mirror of room.mirror === false ? [false] : [false, true]) {
      const name = room.id + (mirror ? " (mirrored)" : "");
      const route = room.hint_route || room.routes[0];
      const [a, b] = route.split(">").map((id) => (id === "gate" || id === "recipient" || !mirror ? id : R.mirrorExit(id, W)));
      const v = R.variant(room, mirror, [a, b].filter((x) => x !== "gate" && x !== "recipient"));
      const M = R.start(v, a, b), sc = D.scene(M, world, mapOf(room.id)), P = D.run(M, {});
      const [fw, fh] = D.size(sc, "full");
      const full = new PB.Raster(fw, fh), cam = new PB.Raster(D.VW, D.VH);
      D.draw(full, sc, P, { tick: 0, view: "full", recipient, overlays: { areas: true, patrol: true, screens: true, marks: true, hints: true } });
      D.draw(cam, sc, P, { tick: 0, view: "camera", recipient, overlays: {} });
      for (const [view, r] of [["full", full], ["camera", cam]]) {
        assert.ok(opaque(r), `${name} ${view}: every pixel drawn`);
        assert.ok(colours(r) > 12, `${name} ${view}: not a flat picture`);
      }
      if (mirror) continue;
      const sol = (room.solutions || {})[route] ? R.expand(room.solutions[route]) : R.solve(v, a, b, {}).solution;
      let tick = 0;
      sol.forEach((act, i) => {
        while (D.busy(P, tick)) { tick += 4; D.update(P, tick); }
        const res = D.act(P, act, tick);
        assert.ok(res.ok, `${name} step ${i + 1} ${act}: ${res.reason}`);
        tick += 40; D.update(P, tick);
        if (i === sol.length >> 1) D.draw(cam, sc, P, { tick, view: "camera", recipient });
      });
      assert.ok(P.done, `${name}: the solution reaches ${b}`);
      D.feed(P, tick, world);
      D.draw(full, sc, P, { tick: tick + 1, view: "full", recipient });
      assert.ok(opaque(full), `${name}: drawn at the end`);
    }
  }
});

test("diyu: the wild rock pattern leaves every rule material exactly as terrain.js draws it; approved themes are untouched", () => {
  const theme = (id) => PB.sprites.get(id).params, diyu = theme("theme.diyu");
  assert.equal(diyu.rock.pattern, "wild");
  assert.equal(diyu.background.style, "diyu");
  const MAT = PB.terrain.MAT, code = { ".": MAT.EMPTY, "#": MAT.ROCK, "%": MAT.CRACKED, e: MAT.EARTH, s: MAT.SAND, "~": MAT.WATER };
  // Every rule material next to rock, open air and the others, on all sides.
  const rows = ["..........", ".##e%s~.#.", "#e#.s#~%#.", "##%s##e~##", "#.e.#s.#e#", "#e~%#.s%.#", "##########"];
  const w = rows[0].length, h = rows.length;
  const map = { w, h, at: (x, y) => (x < 0 || y < 0 || x >= w || y >= h ? MAT.EMPTY : code[rows[y][x]]) };
  const cellDiff = (a, b, tx, ty) => {
    let n = 0;
    for (let y = ty * 16; y < ty * 16 + 16; y++) for (let x = tx * 16; x < tx * 16 + 16; x++) {
      const i = (y * a.w + x) * 4;
      if (a.data[i] !== b.data[i] || a.data[i + 1] !== b.data[i + 1] || a.data[i + 2] !== b.data[i + 2] || a.data[i + 3] !== b.data[i + 3]) n++;
    }
    return n;
  };
  for (const time of [0, 5, 37]) {
    const a = new PB.Raster(w * 16, h * 16), b = new PB.Raster(w * 16, h * 16);
    PB.terrain.drawTerrain(a, map, diyu, 0, 0, time);
    BASE.drawTerrain(b, map, diyu, 0, 0, time);
    let rockDiff = 0;
    for (let ty = 0; ty < h; ty++) for (let tx = 0; tx < w; tx++) {
      const m = map.at(tx, ty);
      if (m === MAT.ROCK) rockDiff += cellDiff(a, b, tx, ty);
      else if (m !== MAT.EMPTY) assert.equal(cellDiff(a, b, tx, ty), 0, `time ${time}: ${rows[ty][tx]} at (${tx},${ty})`);
    }
    assert.ok(rockDiff > 0, "rock is drawn in the wild pattern");
  }
  for (const id of ["theme.dungeon", "theme.ruins", "theme.cave", "theme.forest", "theme.sky", "theme.cosmos"]) {
    const a = new PB.Raster(w * 16, h * 16), b = new PB.Raster(w * 16, h * 16);
    PB.terrain.drawTerrain(a, map, theme(id), 0, 0, 3); BASE.drawTerrain(b, map, theme(id), 0, 0, 3);
    assert.deepEqual(a.data, b.data, id + " terrain");
    const c = new PB.Raster(320, 180), d = new PB.Raster(320, 180);
    PB.terrain.drawBackground(c, theme(id), 0, 0, 320, 180, 90); BASE.drawBackground(d, theme(id), 0, 0, 320, 180, 90);
    assert.deepEqual(c.data, d.data, id + " background");
  }
});

test("diyu: the backdrop fills any width, is the same at the same time, and drifts as time passes", () => {
  const diyu = PB.sprites.get("theme.diyu").params;
  const draw = (w, h, time) => { const r = new PB.Raster(w, h); PB.terrain.drawBackground(r, diyu, 0, 0, w, h, time); return r; };
  for (const [w, h] of [[320, 180], [640, 340], [320, 160]]) {
    const r = draw(w, h, 0);
    for (let i = 3; i < r.data.length; i += 4) assert.equal(r.data[i], 255, `${w}x${h}: every pixel drawn`);
    assert.deepEqual(draw(w, h, 0).data, r.data, "the same time gives the same picture");
    assert.notDeepEqual(draw(w, h, 900).data, r.data, "mist and will-o'-wisps move");
  }
});
// ---------- looks (delivery-puzzle-rules.md 8): the sky top edge and the ladder heads ----------
// Rooms open on their first route, unmirrored.
function opening(id) {
  const room = ROOMS.find((r) => r.id === id), [a, b] = room.routes[0].split(">");
  const v = R.variant(room, false, [a, b].filter((x) => x !== "gate" && x !== "recipient"));
  return { room, v, M: R.start(v, a, b) };
}
const xyOf = (cells, W) => [...cells].sort((p, q) => p - q).map((i) => [i % W, Math.floor(i / W)]);

test("top edge: in a map with top_edge sky a column's 1-2 solid cells from row 0 are sky, 3 or more stay; only the room's top counts", () => {
  const sky = MAPS2.find((s) => s.id === "diyu_1"), rock = MAPS2.find((s) => s.id === "dungeon_2");
  assert.equal(sky.top_edge, "sky");
  assert.equal(rock.top_edge, undefined);
  const rowsOf = (W, ys, stays) => ys.flatMap((y) => [...Array(W).keys()].filter((x) => !stays(x)).map((x) => [x, y]));
  // diyu_naihe: columns 3-9 hang 3 cells of rock from the top (a cliff cut off by the picture's top); the rest of rows 0-1 is sky.
  const naihe = opening("diyu_naihe").v;
  for (let x = 3; x <= 9; x++) for (let y = 0; y < 3; y++) assert.ok("#%R".includes(naihe.map[y][x]), `diyu_naihe (${x}, ${y}) is rock`);
  assert.deepEqual(xyOf(D.skyCells(naihe, sky), naihe.W), rowsOf(20, [0, 1], (x) => x >= 3 && x <= 9));
  // diyu_fengdu, 2 x 2 screens: only row 0 over its open hall; the rock on the right and the second screen's top (rows 10-11) stay.
  const fengdu = opening("diyu_fengdu").v;
  assert.equal(fengdu.H, 20);
  assert.deepEqual(xyOf(D.skyCells(fengdu, sky), fengdu.W), rowsOf(40, [0], (x) => x < 1 || x > 27));
  // Made up, two screens high: ladders, doors, crates and float blocks are not solid (column 5's float
  // block cuts the run); a thin band of rock at rows 10-11 under open air is not the room's top and stays.
  const tall = { W: 7, H: 20, map: Array.from({ length: 20 }, (_, y) =>
    (y === 0 ? "#%RH###" : y === 1 ? "#R|.BF#" : y === 2 ? "#....##" : y === 10 || y === 11 || y === 19 ? "#######" : "#.....#")) };
  assert.deepEqual(xyOf(D.skyCells(tall, sky), tall.W), [[1, 0], [2, 0], [4, 0], [5, 0], [1, 1]]);
  // No top_edge (the dungeon, a room in no map): no sky.
  for (const m of [rock, undefined, { top_edge: "rock" }]) assert.equal(D.skyCells(tall, m).size, 0);
  assert.equal(D.skyCells(naihe, rock).size, 0);
  for (const room of ROOMS.filter((r) => mapOf(r.id) === rock)) assert.equal(D.skyCells(opening(room.id).v, rock).size, 0, room.id);
});

test("top edge: sky cells show the backdrop with no terrain, plants or critters, stay bedrock in the puzzle, and nothing below the top changes", () => {
  const HUD = D.HUD_H;
  for (const id of ["diyu_naihe", "diyu_fengdu", "diyu_lantern", "dungeon2_well"]) {
    const { room, v, M } = opening(id), W = v.W;
    const drawn = (map) => {
      const sc = D.scene(M, worlds.get(room.world), map), [w, h] = D.size(sc, "full");
      D.draw(new PB.Raster(w, h), sc, D.run(M, {}), { tick: 0, view: "full", overlays: {} });
      return sc;
    };
    const sc = drawn(mapOf(id)), rockTop = drawn(undefined);
    assert.equal(sc.sky.size > 0, room.world === "diyu", `${id}: ${sc.sky.size} sky cells`);
    assert.deepEqual(xyOf(sc.sky, W), xyOf(D.skyCells(v, mapOf(id)), W));
    for (const i of sc.sky) {
      assert.equal(M.s.terrain[i], TM.T.ROCK, `${id}: sky cell ${i} is still bedrock`);
      assert.ok(sc.occ.has(i), `${id}: sky cell ${i} is kept free of plants and critters`);
      for (let y = 0; y < 16; y++) for (let x = 0; x < 16; x++) {
        const k = ((HUD + Math.floor(i / W) * 16 + y) * sc.pw + (i % W) * 16 + x) * 4;
        assert.equal(sc.ter.data[k + 3], 0, `${id}: no terrain drawn in sky cell ${i}`);
        assert.ok(sc.fr.data[k] === sc.bg.data[k] && sc.fr.data[k + 1] === sc.bg.data[k + 1] && sc.fr.data[k + 2] === sc.bg.data[k + 2], `${id}: sky cell ${i} shows the backdrop`);
      }
    }
    // Against the rock top: the terrain differs in rows 0-2 at most (row 2 rounds its corners next to the sky).
    for (let k = (HUD + 3 * 16) * sc.pw * 4; k < sc.ter.data.length; k++) if (sc.ter.data[k] !== rockTop.ter.data[k]) assert.fail(`${id}: terrain changed below row 2 (pixel ${k >> 2})`);
    if (id === "diyu_naihe") {
      // The cliff of columns 3-9 is drawn (its inside fully, the two sides with their edge).
      for (let x = 4 * 16; x < 9 * 16; x++) for (let y = HUD; y < HUD + 32; y++) assert.equal(sc.ter.data[(y * sc.pw + x) * 4 + 3], 255, `diyu_naihe cliff (${x}, ${y})`);
    }
  }
});

// Last: it loads workbench/js/app/ladder-tops.js the way index.html does (tools/art.mjs does not load it).
test("v2 ladder heads with a landing beside them keep only their lowest 4 px, by the level-mode rule of ladder-tops.js, judged on the opening map", () => {
  assert.equal(PB.ladderTops, undefined);
  const render = (sc, P, tick) => { const [w, h] = D.size(sc, "full"), r = new PB.Raster(w, h); D.draw(r, sc, P, { tick, view: "full", overlays: {} }); return r; };
  const playTo = (M, sol) => {
    const P = D.run(M, {});
    let tick = 0;
    for (const act of sol) {
      while (D.busy(P, tick)) { tick += 4; D.update(P, tick); }
      assert.ok(D.act(P, act, tick).ok, act);
      tick += 40; D.update(P, tick);
    }
    while (D.busy(P, tick)) { tick += 4; D.update(P, tick); }
    return { P, tick };
  };
  // Without ladder-tops.js: the whole ladder sprites, at the start and (author solutions) at the end of the route.
  const cases = ROOMS.map((room) => {
    const { v, M } = opening(room.id), sc = D.scene(M, worlds.get(room.world), mapOf(room.id)), sol = (room.solutions || {})[room.routes[0]];
    const end = sol ? playTo(M, R.expand(sol)) : null;
    return { room, v, M, sc, start: render(sc, D.run(M, {}), 0), end, endPic: end && render(sc, end.P, end.tick) };
  });
  vm.runInThisContext(fs.readFileSync(path.join(ROOT, "workbench/js/app/ladder-tops.js"), "utf8"));
  const LT = PB.ladderTops;
  let caps = 0, ends = 0;
  for (const c of cases) {
    const W = c.v.W, climb = new Set(LT.cells(c.M.spec));
    const tops = [...climb].filter((i) => LT.isTop(c.M.spec, climb, i % W, Math.floor(i / W))).sort((p, q) => p - q);
    if (c.room.id === "diyu_naihe") assert.deepEqual(xyOf(tops, W), [[2, 3], [7, 3], [16, 3]]);
    caps += tops.length;
    const pairs = [["start", render(c.sc, D.run(c.M, {}), 0), c.start]];
    if (c.end) { pairs.push(["end", render(c.sc, c.end.P, c.end.tick), c.endPic]); ends++; }
    for (const [when, got, was] of pairs) {
      const cut = new Set();
      for (let y = 0; y < got.h; y++) for (let x = 0; x < got.w; x++) {
        const k = (y * got.w + x) * 4;
        if (got.data[k] === was.data[k] && got.data[k + 1] === was.data[k + 1] && got.data[k + 2] === was.data[k + 2]) continue;
        const cell = Math.floor((y - D.HUD_H) / 16) * W + (x >> 4);
        assert.ok(y >= D.HUD_H && tops.includes(cell) && (y - D.HUD_H) % 16 < 16 - LT.KEEP_ROWS, `${c.room.id} (${when}): (${x}, ${y}) changed outside the upper 12 px of a ladder head`);
        cut.add(cell);
      }
      assert.deepEqual([...cut].sort((p, q) => p - q), tops, `${c.room.id} (${when}): every ladder head is cut, the same ones after crates and float blocks moved`);
    }
  }
  assert.ok(caps > 0 && ends > 0, `${caps} ladder heads, ${ends} rooms played to the end`);
});

// DLV-05: the four lab puzzles, embedded in v2 rooms without adding entry
// corridor steps. A test-only gate spawn keeps the lab's exact starting cell;
// completion predicates retain the lab sockets as well as the route goal.
loadCore(["mech/seesaw", "mech/gust"]);
const MECH_CASES = [
  { id: "G09", map: ["###########", "###########", "######H..H#", "######H##H#", "###o|PH.IX#", "####.#.####", "####B#.####", "####.#.####", "###########"],
    devices: [{ type: "seesaw", ends: [[4, 7], [6, 7]], height: 2, threshold: 1, landings: [[3, 4], [7, 4]] }, { type: "lever", at: [5, 4], action: { link: 0 } }],
    links: [{ plates: [], doors: [[4, 4]], symbol: "circle" }],
    solution: ["U", "R", "U", "U", "R", "R", "R", "D", "D", "L", "L", "R", "R"], required: ["seesaw"] },
  { id: "G10", map: ["###########", "###########", "#####H...H#", "#####H###H#", "###oeh|_.X#", "####.#.####", "####B#.####", "####.#.####", "###########"],
    devices: [{ type: "seesaw", ends: [[4, 7], [6, 7]], height: 2, threshold: 1, landings: [[3, 4], [7, 4]] }],
    links: [{ plates: [[7, 4]], doors: [[6, 4]], symbol: "triangle" }],
    solution: ["DIG_L", "U", "U", "R", "R", "R", "R", "D", "D", "L", "L", "POUR_L", "R", "R"], required: ["seesaw"] },
  { id: "F08", map: ["############", "#.X....H..H#", "#######H##H#", "#######H.Ih#", "#..B...oo###", "############"],
    devices: [{ type: "gust", area: [3, 4, 6, 1], direction: "R", period: 1, phase: 0, light_kinds: ["wood"] }],
    solution: ["L", "L", "L", "U", "U", "L", "L", "L", "L", "L"], required: ["gust"] },
  { id: "E06", map: ["############", "############", "#..#########", "#hB|########", "#H#......X##", "#H#....#####", "#H........##", "###.##.#####", "############"],
    devices: [{ type: "gust", area: [2, 3, 1, 1], direction: "R", period: 1, phase: 0, light_kinds: ["wood"] },
      { type: "seesaw", ends: [[3, 7], [6, 7]], height: 2, threshold: 1, landings: [[2, 4], [7, 4]] },
      { type: "lever", at: [2, 2], action: { link: 0 } }, { type: "lever", at: [6, 6], action: { link: 0 } }],
    links: [{ plates: [], doors: [[3, 3]], symbol: "square", latch: false }],
    solution: ["D", "D", "D", "R", "R", "R", "R", "R", "U", "R", "R"], required: ["seesaw", "gust"] },
];
function mechanismRoom(c) {
  const map = Array.from({ length: 10 }, () => Array(20).fill("#"));
  let entry, goal; const sockets = [];
  c.map.forEach((row, y) => [...row].forEach((ch, x) => {
    if (ch === "P" || ch === "h") entry = [x, y];
    if (ch === "X") goal = [x, y];
    if (ch === "o") sockets.push([x, y]);
    map[y][x] = ch === "P" ? "." : ch === "h" ? "H" : ch === "o" ? "." : ch === "X" ? "1" : ch;
  }));
  for (const y of [6, 7]) { map[y][0] = "."; map[y][1] = "."; }
  map[5][0] = map[8][0] = "#";
  const links = JSON.parse(JSON.stringify(c.links || []));
  const room = { format: "pushbox.room/2", id: "test_" + c.id, world: "jeju", type: "home", role: "develop", size: [1, 1],
    map: map.map(row => row.join("")), legend: { 1: { feature: "recipient" } }, exits: ["left.0.low"], routes: ["left.0.low>recipient"],
    devices: c.devices, links, requires: c.required,
    hints: [{ target: goal, done: { all: [{ player: [...goal, ...goal] }, ...sockets.map(crate => ({ crate }))] }, show: { at: goal, dir: "R" }, text: c.id }] };
  assert.deepEqual(R.validate(room), []);
  return { room, entry };
}
function mechanismVariant(c, mirror = false) {
  const { room, entry } = mechanismRoom(c), v = R.variant(room, mirror, null);
  v.spawns.push({ feature: "gate", x: mirror ? v.W - 1 - entry[0] : entry[0], y: entry[1] });
  return v;
}
// The G09/G10 lab goals include sockets, whereas a delivery route ends at a
// recipient. Search the fixture's completion predicate as well, without adding
// a door that would obstruct the author's earlier pass through that cell.
function mechanismSolve(v, frozen = []) {
  const M = R.start(v, "gate", "recipient", undefined, new Set(frozen)), queue = [[M.s, []]], seen = new Set([R.key(M, M.s)]);
  for (let i = 0; i < queue.length; i++) {
    const [s, actions] = queue[i];
    if (R.atGoal(M, s) && R.holds(M, s, v.hints[0].done)) return { solved: true, solution: actions };
    for (const a of R.ACTIONS) {
      const n = R.clone(s), result = R.act(M, n, a, new Set(frozen));
      if (!result.ok || R.hurts(M, n, result)) continue;
      const key = R.key(M, n); if (seen.has(key)) continue;
      seen.add(key); queue.push([n, [...actions, a]]);
    }
    assert.ok(seen.size < 10000, "fixture search must exhaust, not silently stop at a budget");
  }
  return { solved: false, exhausted: true };
}

for (const c of MECH_CASES) test(`DLV-05 ${c.id}: author, shortest, mirror, required mechanics and target hints`, () => {
  const model = loadCore(["tilemodel", "mech/seesaw", "mech/gust"]);
  const goalSpecs = [];
  c.map.forEach((row, y) => [...row].forEach((ch, x) => { if (ch === "o" || ch === "X") goalSpecs.push({ type: ch === "o" ? "socket" : "exit", at: [x, y] }); }));
  const lab = { ...c, goals: goalSpecs, bag: { sand: 0, bomb: 0 } };
  const shortest = model.tilemodel.solve(lab);
  assert.ok(shortest.solved, c.id + " lab");
  assert.ok(model.tilemodel.replay(lab, c.solution).won, "the original author solution still wins");
  for (const mirror of [false, true]) {
    const v = mechanismVariant(c, mirror), actions = mirror ? R.mirrorActions(shortest.solution) : shortest.solution;
    const rep = R.replay(v, "gate", "recipient", actions, { stopAtGoal: false });
    assert.ok(rep.reached, `${c.id} mirror=${mirror}: ${rep.reason || "unreached"}`);
    assert.equal(rep.steps.length - 1, shortest.solution.length);
    const solved = mechanismSolve(v);
    assert.ok(solved.solved);
    assert.equal(solved.solution.length, shortest.solution.length);
    const author = R.replay(v, "gate", "recipient", mirror ? R.mirrorActions(c.solution) : c.solution, { stopAtGoal: false });
    assert.ok(author.reached && R.holds(author.M, author.steps.at(-1).state, v.hints[0].done), "original author replay and socket goals");
    assert.ok(R.hintTrace(rep).ok);
    assert.deepEqual(v.hints[0].target, [rep.steps.at(-1).state.player.x, rep.steps.at(-1).state.player.y]);
    for (const frozen of c.required) {
      assert.ok(R.FREEZABLE.includes(frozen));
      const blocked = mechanismSolve(v, [frozen]);
      assert.equal(blocked.solved, false, c.id + " " + frozen);
      assert.equal(blocked.exhausted, true, "prove no solution rather than hit the search limit");
      if (c.id === "E06") assert.equal(R.solve(v, "gate", "recipient", { frozen: [frozen] }).solved, false, "production route search");
    }
  }
});

test("DLV-05: validate rejects malformed seesaw landing geometry before replay", () => {
  const { room } = mechanismRoom(MECH_CASES[0]);
  for (const landing of [[4, 4], [2, 4], [3, 5], [3, 3], null]) {
    const bad = JSON.parse(JSON.stringify(room)); bad.devices[0].landings[0] = landing;
    assert.ok(R.validate(bad).some(e => /landings/.test(e)), JSON.stringify(landing));
  }
});

test("DLV-05: custom float actions blow once; invalid actions and setup do not blow", () => {
  const room = testRoom([[4, 7, "FFF"], [10, 7, "B"]]);
  room.devices = [{ type: "gust", area: [10, 7, 7, 1], direction: "R", period: 1, phase: 0 }];
  const M = play(room, "left.0.low"), s = M.s;
  assert.ok(TM.crateAt(s, 10, 7), "no setup gust");
  assert.equal(R.act(M, s, "DIG_L").ok, false);
  assert.ok(TM.crateAt(s, 10, 7), "no gust on a rejected action");
  s.player.x = 3;
  assert.equal(R.act(M, s, "R").kind, "float-push");
  assert.ok(TM.crateAt(s, 11, 7), "one gust after a float push");
  s.terrain[6 * M.v.W + 8] = TM.T.ROCK; s.player.x = 7; s.player.y = 6;
  const result = R.act(M, s, "DIG_R");
  assert.equal(result.kind, "pole");
  assert.ok(TM.crateAt(s, 12, 7), "one gust after a pole action");
  assert.deepEqual(result.deviceEvents, [{ type: "gust", device: 0 }]);
  s.player.x = 3; s.player.y = 7;
  assert.equal(R.act(M, s, "R", new Set(["gust"])).kind, "float-push");
  assert.ok(TM.crateAt(s, 12, 7), "freezing gust also covers custom actions");
});

test("DLV-05: seesaw endpoints block float blocks, their riders and poured sand, including when frozen", () => {
  const saw = (ends) => ({ type: "seesaw", ends, height: 2, landings: ends.map(([x, y]) => [x + 1, y - 3]) });
  for (const frozen of [new Set(), new Set(["seesaw"])]) {
    const room = testRoom([[4, 7, "FFF"]]); room.devices = [saw([[7, 7], [12, 7]])];
    const M = play(room, "left.0.low"), s = M.s; s.player.x = 3;
    assert.equal(M.deviceCells.has(7 * M.v.W + 7), true);
    assert.equal(R.act(M, s, "R", frozen).kind, "step");
    assert.equal(s.floats[0].x, 4, "the float must not overwrite an endpoint");
    const riderRoom = testRoom([[4, 7, "FFF"], [5, 6, "B"]]); riderRoom.devices = [saw([[6, 6], [12, 7]])];
    const N = play(riderRoom, "left.0.low"); N.s.player.x = 3;
    assert.equal(R.act(N, N.s, "R", frozen).kind, "step");
    assert.equal(N.s.floats[0].x, 4, "the rider must not enter an endpoint");
    const pourRoom = testRoom([]); pourRoom.devices = [saw([[5, 7], [12, 7]])];
    const P = play(pourRoom, "left.0.low"); P.s.player.x = 4; P.s.bag.sand = 1;
    assert.equal(R.act(P, P.s, "POUR_R", frozen).ok, false);
  }
});

test("DLV-05: resting seesaw loads stay a baseline and clone-based undo reproduces each mechanism step", () => {
  for (const c of MECH_CASES) {
    const v = mechanismVariant(c), M = R.start(v, "gate", "recipient"), initial = R.clone(M.s);
    const original = R.key(M, initial);
    TM.settle(M.L, M.s); TM.settle(M.L, M.s);
    assert.equal(R.key(M, M.s), original, c.id + " repeated settle");
    for (const action of c.solution) {
      const before = R.clone(M.s), first = R.act(M, M.s, action), restored = R.clone(before);
      assert.ok(first.ok);
      const second = R.act(M, restored, action);
      assert.deepEqual(second, first);
      assert.deepEqual(restored, M.s, c.id + " " + action);
    }
    assert.equal(R.key(M, initial), original, "the saved opening is unchanged");
  }
});

test("DLV-05: mechanism fixtures draw idle, action feedback, mirror, filtered art and Jeju snack bubbles", () => {
  const world = worlds.get("jeju"); assert.ok(world);
  const originalDraw = PB.sprites.draw, calls = [];
  PB.sprites.draw = function (...args) { calls.push(args); return originalDraw.apply(this, args); };
  const count = (id, anim) => calls.filter(c => c[1] === id && (anim === undefined || c[2] === anim));
  const draw = (sc, P, tick) => {
    calls.length = 0;
    const [w, h] = D.size(sc, "full"), r = new PB.Raster(w, h);
    D.draw(r, sc, P, { tick, view: "full" });
    assert.ok(r.data.some((v, i) => i % 4 !== 3 && v > 0), "real raster output");
    return r;
  };
  try {
    for (const c of MECH_CASES) for (const mirror of [false, true]) {
      const v = mechanismVariant(c, mirror), M = R.start(v, "gate", "recipient"), sc = D.scene(M, world, { top_edge: "sky" }), P = D.run(M, {});
      draw(sc, P, 0);
      if (c.required.includes("seesaw")) {
        assert.equal(count("mech.jeju_seesaw", "end").length, 2);
        assert.ok(count("mech.jeju_seesaw", "pivot").length > 0);
        for (const call of count("mech.jeju_seesaw")) {
          const asset = PB.sprites.get(call[1]);
          assert.equal(asset.width || asset.w || asset.size[0], 16);
          assert.equal(asset.height || asset.h || asset.size[1], 20);
          assert.equal(call[4] % 16, 8, "bottom-centre x");
          assert.equal((call[5] - D.HUD_H) % 16, 0, "bottom-centre y");
        }
      }
      if (c.required.includes("gust")) {
        assert.ok(count("fx.jeju_gust", "drift").length > 0);
        assert.ok(count("fx.jeju_gust").every(call => !!call[6] === mirror), "gust mirrors with the room");
      }
      let tick = 0, saw = false, gust = false;
      for (const action of mirror ? R.mirrorActions(c.solution) : c.solution) {
        const result = D.act(P, action, tick); assert.ok(result.ok, c.id + " " + action);
        draw(sc, P, tick + 1);
        if ((result.deviceEvents || []).some(e => e.type === "seesaw")) {
          saw = true; assert.equal(count("mech.jeju_seesaw", "down").length, 1); assert.equal(count("mech.jeju_seesaw", "launch").length, 1);
        }
        if ((result.deviceEvents || []).some(e => e.type === "gust")) { gust = true; assert.ok(count("fx.jeju_gust", "blow").length > 0); }
        tick += 80; D.update(P, tick);
      }
      assert.equal(saw, c.required.includes("seesaw")); assert.equal(gust, c.required.includes("gust"));
      draw(sc, P, tick);
      assert.equal(count("mech.jeju_seesaw", "down").length + count("fx.jeju_gust", "blow").length, 0, "feedback ends with the action");
      D.setArtFilter(() => false); draw(sc, P, tick);
      assert.equal(count("mech.jeju_seesaw").length + count("fx.jeju_gust").length, 0, "candidate art is filtered");
      D.setArtFilter(null);
    }
    const v = mechanismVariant(MECH_CASES[3]), M = R.start(v, "gate", "recipient"), sc = D.scene(M, world), P = D.run(M, {});
    D.update(P, 0);
    P.mem.main = { x: P.s.player.x * 16 + 8, y: P.s.player.y * 16 + 16, face: 1 };
    P.mem.fly = null;
    assert.equal(D.feed(P, 0, world), "hint");
    draw(sc, P, 1);
    assert.equal(count("item.snack_jeju", "default").length, 2, "HUD and fed hint bubble use the Jeju snack");
    assert.equal(count("item.snack").length, 0);
  } finally { PB.sprites.draw = originalDraw; D.setArtFilter(null); }
});

test("DLV-05: freezing seesaw applies before setup gravity and new sand above resting sand still animates", () => {
  const room = testRoom([[4, 6, "B"], [6, 4, "I"]]);
  room.devices = [{ type: "seesaw", ends: [[4, 7], [6, 7]], height: 2, landings: [[3, 4], [7, 4]] }];
  const v = R.variant(room, false, null);
  assert.ok(TM.crateAt(R.start(v, "left.0.low", null).s, 3, 7), "the opening falling load normally launches the wood crate");
  const frozen = R.replay(v, "left.0.low", null, [], { frozen: ["seesaw"] });
  assert.ok(TM.crateAt(frozen.M.s, 4, 6), "a frozen replay must keep the wood crate on its original pad");
  const stack = testRoom([[4, 6, "B"], [6, 6, "s"]]); stack.devices = room.devices;
  const M = play(stack, "left.0.low"); M.s.player.x = 7; M.s.player.y = 7; M.s.bag.sand = 1;
  // Pour from the ledge above the resting sand; a new layer increases the load
  // while the bottom sand tile itself keeps exactly the same material.
  M.s.player.y = 5; M.s.terrain[6 * M.v.W + 7] = TM.T.ROCK;
  const result = R.act(M, M.s, "POUR_L");
  assert.ok(result.ok);
  assert.ok(result.events.includes("seesaw"));
  assert.ok((result.deviceEvents || []).some(e => e.type === "seesaw" && e.side === 1));
});

test("DLV-05: gust cannot erase feedback from a seesaw that fired earlier in the same action", () => {
  const room = testRoom([[4, 4, "B"], [3, 5, ".e"], [8, 6, "I"]]);
  room.devices = [{ type: "seesaw", ends: [[4, 7], [8, 7]], height: 2, landings: [[3, 4], [9, 4]] },
    { type: "gust", area: [4, 6, 1, 1], direction: "R", period: 1, phase: 0 }];
  const M = play(room, "left.0.low"); M.s.player.x = 3; M.s.player.y = 5;
  const result = R.act(M, M.s, "DIG_R");
  assert.ok(result.ok && result.events.includes("seesaw") && result.events.includes("gust"));
  assert.ok(TM.crateAt(M.s, 9, 7), "the iron crate was launched");
  assert.ok(TM.crateAt(M.s, 5, 7), "the gust then cleared the triggering pad");
  assert.ok((result.deviceEvents || []).some(e => e.type === "seesaw" && e.device === 0 && e.side === 0), "keep feedback even after the pad is empty");
});
