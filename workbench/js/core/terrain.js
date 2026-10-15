/* Terrain and background rendering. This file IS the specification for the
 * game's terrain shader (docs/design/art-direction.md §5): static materials are
 * coloured from material, pixel position hash and same-material neighbours only.
 * Theme parameters come from procedural art sources (art/source/terrain/*.json). */
(function (root) {
  "use strict";
  const PB = (root.PB = root.PB || {});
  const h32 = PB.h32;

  // Material ids used by the renderer (independent of the design model codes).
  const MAT = { EMPTY: 0, ROCK: 1, CRACKED: 2, EARTH: 3, SAND: 4, WATER: 5 };
  const SEED = { 1: 11, 2: 23, 3: 37, 4: 41, 5: 53 };

  function pick(list, n) { return list[n % list.length]; }

  // map: {w, h, at(tx, ty) -> MAT}. Draws tiles at (ox, oy) in pixels.
  function drawTerrain(r, map, theme, ox, oy, time) {
    const T = theme;
    for (let ty = 0; ty < map.h; ty++) for (let tx = 0; tx < map.w; tx++) {
      const m = map.at(tx, ty);
      if (m === MAT.EMPTY) continue;
      const up = map.at(tx, ty - 1), down = map.at(tx, ty + 1), left = map.at(tx - 1, ty), right = map.at(tx + 1, ty);
      for (let py = 0; py < 16; py++) for (let px = 0; px < 16; px++) {
        const wx = tx * 16 + px, wy = ty * 16 + py;
        const c = shade(T, m, wx, wy, px, py, { up, down, left, right, tx, ty }, time | 0);
        if (c) r.set(ox + wx, oy + wy, c);
      }
    }
  }

  function solidish(m) { return m === MAT.ROCK || m === MAT.CRACKED || m === MAT.EARTH; }

  function shade(T, m, wx, wy, px, py, n, time) {
    const hash = h32(wx, wy, SEED[m]);
    if (m === MAT.ROCK) {
      const P = T.rock;
      const row = Math.floor(wy / 6), off = (row & 1) * 5;
      const col = Math.floor((wx + off) / 10);
      const seam = wy % 6 === 5 || (wx + off) % 10 === 9;
      let c = seam ? P.seam : pick(P.base, h32(col, row, 7) % 4 === 0 ? 1 : 0);
      if (!seam && hash % 29 === 0) c = P.speck;
      if (py === 0 && n.up !== MAT.ROCK) c = n.up === MAT.EMPTY || n.up === MAT.WATER || n.up === MAT.SAND ? P.light : c;
      if (py === 1 && n.up === MAT.EMPTY && !seam) c = P.light2;
      if (py === 15 && n.down === MAT.EMPTY) c = P.dark;
      if (px === 0 && n.left === MAT.EMPTY && py > 0) c = P.edge;
      if (px === 15 && n.right === MAT.EMPTY && py > 0) c = P.edge;
      return c;
    }
    if (m === MAT.EARTH) {
      const P = T.earth;
      let c = pick(P.base, (hash >>> 3) % 5 === 0 ? 1 : 0);
      const clump = h32(wx >> 2, wy >> 2, 5) % 9;
      if (clump === 0) c = P.clump;
      if (hash % 37 === 0) c = P.pebble;
      else if (h32(wx, wy - 1, SEED[m]) % 37 === 0) c = P.pebbleShade;
      if (n.up !== MAT.EARTH && n.up !== MAT.ROCK) {
        if (py === 0) c = P.crust; else if (py === 1 && hash % 3) c = P.crust2;
      }
      if (py === 15 && n.down === MAT.EMPTY) c = P.dark;
      if ((px === 0 && n.left === MAT.EMPTY) || (px === 15 && n.right === MAT.EMPTY)) c = P.dark;
      return c;
    }
    if (m === MAT.CRACKED) {
      const P = T.cracked;
      let c = pick(P.base, hash % 7 === 0 ? 1 : 0);
      if (crack(n.tx, n.ty, px, py)) c = P.crack;
      else if (crack(n.tx, n.ty, px - 1, py)) c = P.crackLight;
      if (py === 0 && n.up === MAT.EMPTY) c = P.light;
      if (py === 15 && n.down === MAT.EMPTY) c = P.dark;
      return c;
    }
    if (m === MAT.SAND) {
      const P = T.sand;
      let c = pick(P.base, hash % 3);
      if (hash % 17 === 0) c = P.grain;
      if (py === 0 && n.up !== MAT.SAND) c = P.top;
      return c;
    }
    if (m === MAT.WATER) {
      const P = T.water;
      let c = py < 4 && n.up === MAT.WATER ? P.body : py < 6 ? P.upper : P.body;
      if (n.up !== MAT.WATER && n.up !== MAT.SAND) {
        if (py === 0) c = P.surface;
        else if (py === 1 && ((wx + time) % 7 === 0 || (wx + time * 2) % 11 === 0)) c = P.glint;
        else if (py < 4) c = P.upper;
      }
      if (n.up === MAT.WATER && h32(wx, wy, 3 + (time >> 1)) % 97 === 0) c = P.glint;
      return c;
    }
    return null;
  }

  // Deterministic crack polyline for one cracked tile.
  function crack(tx, ty, px, py) {
    if (px < 0 || px > 15) return false;
    const a = h32(tx, ty, 91);
    const x0 = 3 + (a % 6), x1 = 6 + ((a >>> 4) % 6), x2 = 4 + ((a >>> 8) % 8);
    // main line from top (x0,0) to middle (x1,8) to bottom (x2,15)
    const lerp = (xa, ya, xb, yb) => py >= ya && py <= yb && px === Math.round(xa + (xb - xa) * (py - ya) / Math.max(1, yb - ya));
    if (lerp(x0, 0, x1, 8) || lerp(x1, 8, x2, 15)) return true;
    // branch
    const bx = (a >>> 12) % 2 ? 1 : -1;
    return py >= 8 && py <= 11 && px === x1 + bx * (py - 8);
  }

  // ---------- backgrounds ----------
  function drawBackground(r, theme, x0, y0, w, h, time, sprites) {
    const B = theme.background;
    for (let y = y0; y < y0 + h; y++) for (let x = x0; x < x0 + w; x++) {
      const hash = h32(x >> 1, y >> 1, 401);
      let c = B.base[0];
      // Irregular rock strata: wavy bands broken by noise, low contrast.
      const band = (y + ((h32(x >> 3, 0, 405) % 5) - 2) + (x >> 4) % 3) % 13;
      if (band === 0 && hash % 3) c = B.base[1];
      else if (h32(x >> 2, y >> 2, 403) % 11 === 0 && hash % 2) c = B.base[1];
      if (hash % 41 === 0) c = B.speck;
      r.set(x, y, c);
    }
    if (B.style === "mine") {
      // Timber frames every 80 px, crossbeam near the top.
      for (let bx = x0 + 24; bx < x0 + w; bx += 80) {
        for (let y = y0; y < y0 + h; y++) { r.set(bx, y, B.timberDark); r.set(bx + 1, y, B.timber); r.set(bx + 2, y, B.timber); r.set(bx + 3, y, B.timberDark); }
      }
      for (let x = x0; x < x0 + w; x++) { r.set(x, y0 + 22, B.timberDark); r.set(x, y0 + 23, B.timber); r.set(x, y0 + 24, B.timberDark); }
      // Rail line along the bottom.
      for (let x = x0; x < x0 + w; x++) if (x % 6 < 4) r.set(x, y0 + h - 6, B.timberDark);
    } else if (B.style === "aqueduct") {
      for (let ax = x0 + 8; ax < x0 + w; ax += 64) {
        for (let y = y0 + 30; y < y0 + h; y++) for (let k = 0; k < 6; k++) r.set(ax + k, y, k === 0 || k === 5 ? B.timberDark : B.timber);
        for (let k = 0; k < 64; k++) {
          const dy = Math.round(Math.sqrt(Math.max(0, 900 - (k - 32) * (k - 32))) * 0.6);
          r.set(ax + k, y0 + 48 - dy, B.timber); r.set(ax + k, y0 + 49 - dy, B.timberDark);
        }
      }
    }
  }

  PB.terrain = { MAT, drawTerrain, drawBackground, crack };
})(typeof window !== "undefined" ? window : globalThis);
