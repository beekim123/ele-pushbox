#!/usr/bin/env node
// Read-only oracle: runs the frozen workbench renderers; writes only test fixtures.
import fs from "node:fs";
import path from "node:path";
import { fileURLToPath } from "node:url";
import { ROOT, loadCore, listJson, readJson } from "../../../tools/lib/load-core.mjs";

const PB = loadCore(["raster", "sprites", "terrain", "ambient", "env", "tilemodel", "matter", "scene"]);
for (const file of listJson("art/source")) PB.sprites.register(readJson(file));
const themes = ["dungeon", "ruins", "cave", "forest", "sky", "cosmos"];
const fixture = { format: "portitor.render-reference/1", hashes: [], triangles: [], frames: [], cases: [], showcases: [] };
for (const p of [[0, 0, 0], [319, 191, 41], [-1, 8, 23], [2147483647, 37, 907], [777, 999, 901]]) fixture.hashes.push({ p, expected: PB.h32(...p) });
for (const p of [[0, 120, 3], [119, 120, 3], [60, 120, 3], [-1, 120, 3], [729, 900, 60]]) fixture.triangles.push({ p, expected: PB.ambient.tri(...p) });
const rows = ["11111111", "10000001", "10322001", "10004501", "11111111"];
const map = { w: 8, h: 5, at(x, y) { return x < 0 || y < 0 || x >= 8 || y >= 5 ? 0 : +rows[y][x]; } };
const codes = (r) => Array.from({ length: r.h }, (_, y) => Array.from({ length: r.w }, (_, x) => r.get(x, y)).join(""));
fixture.lighting_edges = [];
const lightingFixture = (label, width, height, env, lights, tick, area) => {
  const raster = new PB.Raster(width, height), palette = [".", ...PB.CODES];
  for (let y = 0; y < height; y++) for (let x = 0; x < width; x++) raster.set(x, y, palette[(y * width + x) % palette.length]);
  const base = codes(raster);
  PB.env.draw(raster, { env }, "back", { tick, lights, area, level: "full" });
  fixture.lighting_edges.push({ label, w: width, h: height, env, lights, tick, area: [area.x, area.y, area.w, area.h], base, expected: codes(raster) });
};
// All Bayer centre phases, HUD/negative/edge clipping, zero/negative radii and
// repeated pools. Uses an existing decoration id; never edits an art asset.
for (const radius of [-1, 0, 1, 3, 28]) for (let phase = 0; phase < 16; phase++) {
  const x = (phase & 3) - 2, y = 19 + (phase >> 2), id = "deco.dungeon_torch";
  lightingFixture(`pool/r${radius}/phase${phase}`, 12, 32, { lights: { sources: { [id]: { radius, flicker: false } } } }, [{ id, x, y }, { id, x: x + 2, y: y + 1 }, { id, x, y }, { id, x: 11 + (phase & 3), y: 31 + (phase >> 2) }], 0, { x: 3, y: 22, w: 4, h: 4 });
}
for (const tick of [0, 127, 600, 1199]) for (const slope of [[1, 2], [-1, 3]]) {
  lightingFixture(`beam/${tick}/${slope.join(":")}`, 32, 40, { beams: { slope, count: 3, width: 18 }, mist: true }, [], tick, { x: -3, y: 18, w: 40, h: 22 });
}
const seamRows = ["00000000000000000000", "00000000000000111000", "00000000000000133000", "00000000000000113000", "00000000000000000000"];
const seamMap = { w: 20, h: 5, at(x, y) { return x < 0 || y < 0 || x >= 20 || y >= 5 ? 0 : +seamRows[y][x]; } };
fixture.seam = { materials: seamRows, expected: {} };
for (const name of ["idle", "walk", "win", "dig"]) for (const tick of [0, 7, 15, 59, 127]) fixture.frames.push({ uid: "art:char.portitor", name, tick, expected: PB.sprites.frameAt(PB.sprites.get("char.portitor"), name, tick) });
for (const name of themes) {
  const theme = PB.sprites.get("theme." + name).params;
  const seam = new PB.Raster(320, 80);
  PB.terrain.drawTerrain(seam, seamMap, theme, 0, 0, 0);
  fixture.seam.expected["art:theme." + name] = codes(seam);
  const showcase = new PB.Raster(320, 180);
  PB.scene.renderLevel(showcase, PB.scene.SHOWCASE, null, { theme: "theme." + name, tick: 0, hud: false });
  const parsed = PB.tilemodel.parse(PB.scene.SHOWCASE);
  fixture.showcases.push({ theme: "art:theme." + name, spec: PB.scene.SHOWCASE, state: { ...parsed.state, terrain: Array.from(parsed.state.terrain), w: parsed.level.w, h: parsed.level.h, doors: parsed.state.open.map(Boolean), won: false }, expected: codes(showcase) });
  for (const tick of [0, 127]) {
    const background = new PB.Raster(320, 180);
    PB.terrain.drawBackground(background, theme, 0, 0, 320, 180, tick);
    const terrain = new PB.Raster(128, 80);
    PB.terrain.drawTerrain(terrain, map, theme, 0, 0, tick >> 3);
    const result = { theme: "art:theme." + name, tick, background: codes(background), terrain: codes(terrain), materials: rows };
    result.ambient = {};
    const originalDraw = PB.sprites.draw;
    for (const mode of ["sparse", "one", "full"]) {
      const commands = [];
      PB.sprites.draw = (_r, id, anim, tick, x, y, flip) => commands.push({ uid: "art:" + id, anim, tick, x, y, flip: !!flip });
      for (const layer of ["back", "front"]) PB.ambient.draw(null, theme, map, 40, 30, tick, layer, (x, y) => x === 1 && y === 1, { x: 56, y: 46, w: 96, h: 48 }, null, { mode, seed: PB.ambient.seedOf("M03") });
      result.ambient[mode] = commands;
    }
    PB.sprites.draw = originalDraw;
    for (const mode of ["full", "lite", "off"]) {
      const r = new PB.Raster(320, 180);
      r.blit(background, 0, 0);
      const ctx = { tick, area: { x: 40, y: 30, w: 240, h: 140 }, lights: [{ id: "deco.dungeon_torch", x: 80, y: 50 }], level: mode };
      for (const phase of ["back", "light", "front"]) PB.env.draw(r, theme, phase, ctx);
      result[mode] = codes(r);
    }
    fixture.cases.push(result);
  }
}
const out = path.join(path.dirname(fileURLToPath(import.meta.url)), "workbench.reference.json");
fs.writeFileSync(out, JSON.stringify(fixture));
console.log(path.relative(ROOT, out));
