// Delivery v2 rooms, format pushbox.room/2 (docs/design/delivery-puzzle-rules.md):
// float blocks and the pole, falls, the follow camera, runs from the pool, the
// checker and its committed report, the text tables, the renderer
// (delivery-scene2.js) and the diyu terrain and backdrop (terrain-diyu.js).
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
    assert.deepEqual(Object.keys(p.maps).sort(), ["diyu_1", "dungeon_2"], "both maps come up");
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
      const M = R.start(v, a, b), sc = D.scene(M, world), P = D.run(M, {});
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