/* Game UI screens at 320x180. Layout code + strings from art/source/screen/*.json.
 * These are layout and look references for the Godot UI; interaction in the
 * workbench is simulated (no game state is read or written). */
(function (root) {
  "use strict";
  const PB = (root.PB = root.PB || {});
  const S = () => PB.sprites, TX = () => PB.text;
  const W = 320, H = 180;

  function text2x(r, str, x, y, color, shadow) {
    // Pixel-doubled title text.
    const tmp = new PB.Raster(PB.text.measure(str) + 2, 16);
    PB.text.draw(tmp, str, 0, 0, color);
    for (let yy = 0; yy < tmp.h; yy++) for (let xx = 0; xx < tmp.w; xx++) {
      const c = tmp.get(xx, yy); if (c === ".") continue;
      if (shadow) { r.rect(x + xx * 2 + 1, y + yy * 2 + 2, 2, 2, shadow); }
      r.rect(x + xx * 2, y + yy * 2, 2, 2, c);
    }
    return tmp.w * 2;
  }
  function panel(r, x, y, w, h, frame) { S().ninepatch(r, "ui.panel", frame, x, y, w, h); }
  function icon(r, name, x, y) { S().draw(r, "ui.icons", S().get("ui.icons").animations[name].frames[0], 0, x, y); }
  function key(r, name, x, y) { S().draw(r, "ui.keycap", S().get("ui.keycap").animations[name].frames[0], 0, x, y); }
  function wideKey(r, label, x, y) {
    const w = TX().measure(label) + 8;
    r.rect(x + 1, y, w - 2, 13, "z"); r.rect(x, y + 1, w, 11, "z");
    r.rect(x + 1, y + 1, w - 2, 10, "u"); r.hline(x + 1, y + 11, w - 2, "v");
    TX().draw(r, label, x + 4, y - 1, "y");
    return w;
  }
  function wrap(str, width) {
    const lines = []; let line = "";
    const NO_START = "，。：；、！？）」』”";
    for (const ch of str) {
      if (TX().measure(line + ch) > width && !NO_START.includes(ch)) { lines.push(line); line = ch === " " ? "" : ch; } else line += ch;
    }
    if (line) lines.push(line);
    return lines;
  }
  function dim(r) { r.remap(0, 0, W, H, PB.DIM); r.remap(0, 0, W, H, PB.DIM); }

  function themeId(st, p) { return (st && st.theme) || (p && p.theme) || "theme.dungeon"; }

  // Themed backdrop: background, a floor (plus optional extra solid tiles), ambient life.
  // Floor top is at y = 156. extraSolid / occupied use tile coords with oy = 12.
  function backdrop(r, theme, tick, extraSolid, occupied) {
    const T = S().get(theme).params, M = PB.terrain.MAT, oy = 12;
    const map = { w: 21, h: 11, at: (x, y) => (x < 0 || x >= 21 || y < 0 ? M.EMPTY : y >= 9 ? M.ROCK : extraSolid && extraSolid(x, y) ? M.ROCK : M.EMPTY) };
    PB.terrain.drawBackground(r, T, 0, 0, W, H, tick);
    const area = { x: 0, y: 0, w: W, h: 150 };
    PB.ambient.draw(r, T, map, 0, oy, tick, "back", occupied, area);
    PB.terrain.drawTerrain(r, map, T, 0, oy, tick >> 3);
    PB.ambient.draw(r, T, map, 0, oy, tick, "front", occupied, area);
    return T;
  }

  // ---------- screens ----------
  function lobby(r, tick, p, st) {
    const th = themeId(st, p);
    // A small diorama on the right: a two-tile ledge with the exit flag, stacked crates, the miner pushing.
    const ledge = (x, y) => (x === 18 || x === 19) && (y === 7 || y === 8);
    const busy = (x, y) => (y === 8 && x >= 12 && x <= 15) || (y === 7 && x === 15) || (y === 6 && (x === 18 || x === 19));
    const T = backdrop(r, th, tick, ledge, busy);
    const title = T.title || "";
    // Title plate.
    text2x(r, p.title, 20, 14, "l", "z");
    TX().draw(r, p.subtitle, 22, 46, "c", "z");
    const chap = T.chapter <= 5 ? p.chapter_label.replace("{n}", String(T.chapter)) : p.chapter_extra;
    TX().draw(r, chap + title, 22, 60, "k", "z");
    S().draw(r, "obj.crate_wood", "default", 0, 14 * 16 + 8, 156);
    S().draw(r, "obj.crate_wood", "default", 0, 15 * 16 + 8, 156);
    S().draw(r, "obj.crate_wood", "default", 0, 15 * 16 + 8, 140);
    S().draw(r, "char.miner", "push", tick, 13 * 16 + 8, 156);
    S().draw(r, "mech.exit_flag", "idle", tick, 18 * 16 + 12, 124);
    const sel = st.focus | 0, x = 16, y0 = 80, w = 104, h = 10 + p.items.length * 16;
    panel(r, x, y0, w, h, 0);
    p.items.forEach((label, i) => {
      const y = y0 + 5 + i * 16;
      if (i === sel) { panel(r, x + 4, y - 1, w - 8, 15, 1); r.rect(x + 9, y + 5, 2, 4, "k"); r.rect(x + 11, y + 6, 1, 2, "k"); }
      TX().draw(r, label, x + 16, y, i === sel ? "l" : "u");
    });
    let kx = 16; const ky = H - 16;
    r.rect(0, ky - 3, W, 19, "z");
    key(r, "up", kx, ky); key(r, "down", kx + 14, ky); kx += 30;
    kx += TX().draw(r, p.hint_select, kx, ky - 1, "v") + 8;
    kx += wideKey(r, "Enter", kx, ky) + 3;
    TX().draw(r, p.hint_confirm, kx, ky - 1, "v");
  }

  function chapters(r, tick, p, st) {
    const sel = st.focus | 0, cur = p.chapters[sel];
    backdrop(r, cur.theme || "theme.dungeon", tick);
    dim(r);
    TX().draw(r, p.heading, 10, 5, "l", "z");
    const n = p.chapters.length, gap = 4, cw = Math.floor((W - 12 - gap * (n - 1)) / n), x0 = (W - (cw * n + gap * (n - 1))) >> 1, y0 = 24;
    p.chapters.forEach((ch, i) => {
      const x = x0 + i * (cw + gap), y = y0 + (i === sel ? -2 : 0);
      panel(r, x, y, cw, 112, i === sel ? 1 : 0);
      const th = { x: x + 5, y: y + 5, w: cw - 10, h: 46 };
      const tmp = new PB.Raster(th.w, th.h);
      if (ch.theme && S().has(ch.theme)) {
        const T = S().get(ch.theme).params, M = PB.terrain.MAT;
        const map = { w: 3, h: 3, at: (tx, ty) => (ty >= 2 && tx >= 0 && tx < 3 ? M.ROCK : M.EMPTY) };
        const area = { x: 0, y: 0, w: th.w, h: 30 };
        PB.terrain.drawBackground(tmp, T, 0, 0, th.w, th.h, tick);
        PB.ambient.draw(tmp, T, map, -4, -4, tick + i * 97, "back", null, area);
        PB.terrain.drawTerrain(tmp, map, T, -4, -4, tick >> 3);
        PB.ambient.draw(tmp, T, map, -4, -4, tick + i * 97, "front", null, area);
      } else tmp.rect(0, 0, th.w, th.h, "y");
      if (ch.locked) { tmp.remap(0, 0, th.w, th.h, PB.DIM); }
      r.blit(tmp, th.x, th.y);
      if (ch.locked) icon(r, "lock", x + (cw >> 1) - 6, th.y + 14);
      r.rect(th.x - 1, th.y - 1, th.w + 2, 1, "z"); r.rect(th.x - 1, th.y + th.h, th.w + 2, 1, "z");
      TX().centered(r, ch.num, x + (cw >> 1), y + 54, "v");
      TX().centered(r, ch.name, x + (cw >> 1), y + 70, ch.locked ? "w" : i === sel ? "l" : "u");
      TX().centered(r, ch.progress, x + (cw >> 1), y + 88, ch.locked ? "w" : i === sel ? "l" : "k");
    });
    panel(r, 6, 142, W - 12, 32, 0);
    TX().draw(r, cur.full, 14, 144, "l");
    TX().draw(r, cur.locked ? cur.unlock : cur.blurb, 14, 158, cur.locked ? "v" : "u");
  }

  function levels(r, tick, p, st) {
    backdrop(r, themeId(st, p), tick);
    dim(r);
    TX().draw(r, p.heading, 12, 6, "l", "z");
    TX().draw(r, p.progress, W - 12 - TX().measure(p.progress), 6, "k", "z");
    const sel = st.focus | 0;
    p.levels.forEach((lv, i) => {
      const x = 12, y = 24 + i * 18, w = 168;
      panel(r, x, y, w, 16, i === sel ? 1 : 0);
      if (i === sel) { r.rect(x + 4, y + 6, 2, 4, "k"); }
      TX().draw(r, lv.id, x + 9, y + 1, i === sel ? "l" : "k");
      TX().draw(r, lv.title, x + 36, y + 1, i === sel ? "l" : "u");
      if (lv.state === "cleared") icon(r, "check", x + w - 16, y + 2);
      if (lv.state === "skipped") icon(r, "skip", x + w - 16, y + 2);
      if (lv.recommended) TX().draw(r, p.recommended, x + w - 16 - TX().measure(p.recommended), y + 1, "m");
    });
    // Mini map of the selected level.
    const lv = p.levels[sel], spec = st.specs && st.specs[lv.id];
    const px = 188, py = 24, pw = 120, ph = 124;
    panel(r, px, py, pw, ph, 0);
    if (spec) {
      const rows = spec.map, cell = Math.max(3, Math.min(6, Math.floor(Math.min((pw - 12) / rows[0].length, (ph - 40) / rows.length))));
      const mw = rows[0].length * cell, mh = rows.length * cell, mx = px + ((pw - mw) >> 1), my = py + 8;
      const COL = { "#": "w", "%": "F", e: "e", s: "c", "~": "r", "|": "v", H: "f", o: "k", b: "b", X: "l", _: "s", P: "i", h: "i", B: "b", I: "u", ".": "y" };
      rows.forEach((row, ty) => [...row].forEach((ch, tx) => r.rect(mx + tx * cell, my + ty * cell, cell, cell, COL[ch] || "y")));
      wrap(spec.discovery || "", pw - 12).slice(0, 3).forEach((line, i) => TX().draw(r, line, px + 6, my + mh + 4 + i * 13, "u"));
    }
    let kx = 12; const ky = H - 16;
    key(r, "left", kx, ky); key(r, "right", kx + 14, ky); key(r, "up", kx + 28, ky); key(r, "down", kx + 42, ky); kx += 60;
    kx += TX().draw(r, p.hint_select, kx, ky - 1, "v") + 8;
    kx += wideKey(r, "Enter", kx, ky) + 3; kx += TX().draw(r, p.hint_enter, kx, ky - 1, "v") + 8;
    kx += wideKey(r, "Esc", kx, ky) + 3; TX().draw(r, p.hint_back, kx, ky - 1, "v");
  }

  function inLevel(r, tick, spec, extra) {
    PB.scene.renderLevel(r, spec, null, Object.assign({ tick }, extra || {}));
  }

  function pause(r, tick, p, st) {
    inLevel(r, tick, st.levelSpec);
    dim(r);
    const sel = st.focus | 0, w = 120, h = 18 + p.items.length * 16, x = (W - w) >> 1, y = (H - h) >> 1;
    panel(r, x, y, w, h, 2);
    TX().centered(r, p.heading, W >> 1, y + 3, "l", "g");
    p.items.forEach((label, i) => {
      const iy = y + 18 + i * 16;
      if (i === sel) { panel(r, x + 6, iy - 1, w - 12, 15, 1); r.rect(x + 11, iy + 5, 2, 4, "k"); }
      TX().draw(r, label, x + 18, iy, i === sel ? "l" : "c");
    });
  }

  function hint(r, tick, p, st) {
    inLevel(r, tick, st.levelSpec);
    const spec = st.levelSpec, level = Math.min(3, (st.focus | 0) + 1);
    const x = 8, w = W - 16, y = H - 58, h = 52;
    panel(r, x, y, w, h, 0);
    icon(r, "hint", x + 6, y + 5);
    TX().draw(r, p.heading + " " + level + "/3", x + 22, y + 3, "l");
    const lines = wrap(spec.hints[level - 1] || "", w - 20);
    lines.slice(0, 2).forEach((line, i) => TX().draw(r, line, x + 8, y + 18 + i * 13, "u"));
    if (level === 3) {
      const bx = x + w - 150;
      panel(r, bx, y + 3, 64, 14, 1); TX().centered(r, p.demo, bx + 32, y + 3, "l");
      panel(r, bx + 68, y + 3, 76, 14, 0); TX().centered(r, p.rewind, bx + 106, y + 3, "u");
    } else {
      let kx = x + w - 60; key(r, "H", kx, y + 4); TX().draw(r, p.more, kx + 16, y + 3, "v");
    }
  }

  function complete(r, tick, p, st) {
    const spec = st.levelSpec;
    const TM = PB.tilemodel, parsed = TM.parse(spec);
    for (const a of spec.solution) TM.act(parsed.level, parsed.state, a);
    PB.scene.renderLevel(r, spec, parsed, { tick, pose: "win" });
    const w = 150, h = 54, x = (W - w) >> 1, y = 34;
    panel(r, x, y, w, h, 2);
    text2x(r, p.heading, x + ((w - PB.text.measure(p.heading) * 2) >> 1), y + 4, "l", "g");
    const steps = p.steps.replace("{n}", String(spec.solution.length));
    TX().centered(r, steps, W >> 1, y + 36, "c");
    const by = y + h + 4;
    panel(r, (W >> 1) - 74, by, 70, 16, 1); TX().centered(r, p.next, (W >> 1) - 39, by + 1, "l");
    panel(r, (W >> 1) + 4, by, 70, 16, 0); TX().centered(r, p.select, (W >> 1) + 39, by + 1, "u");
  }

  function settings(r, tick, p, st) {
    backdrop(r, themeId(st, p), tick);
    dim(r);
    const sel = st.focus | 0, w = 220, x = (W - w) >> 1, y = 22, h = 22 + p.items.length * 18;
    panel(r, x, y, w, h, 0);
    TX().draw(r, p.heading, x + 8, y + 4, "l");
    p.items.forEach((it, i) => {
      const iy = y + 22 + i * 18;
      if (i === sel) panel(r, x + 4, iy - 2, w - 8, 17, 1);
      TX().draw(r, it.label, x + 12, iy, i === sel ? "l" : "u");
      const vx = x + w - 84;
      if (it.type === "slider") {
        for (let k = 0; k < 10; k++) r.rect(vx + k * 7, iy + 4, 5, 6, k < it.value ? (i === sel ? "k" : "d") : "x");
      } else if (it.type === "toggle") {
        panel(r, vx + 40, iy, 30, 12, it.value ? 1 : 0);
        TX().centered(r, it.value ? p.on : p.off, vx + 55, iy - 1, it.value ? "l" : "v");
      } else {
        TX().draw(r, it.value, vx + 70 - TX().measure(it.value), iy, "c");
      }
    });
  }

  function rulecard(r, tick, p, st) {
    inLevel(r, tick, st.ruleSpec || st.levelSpec);
    dim(r);
    const w = 200, h = 104, x = (W - w) >> 1, y = 36;
    panel(r, x, y, w, h, 0);
    TX().draw(r, p.heading, x + 8, y + 4, "l");
    // Two-step illustration: earth beside the miner, then dug out with one bag.
    const T = S().get(PB.scene.themeFor(st.ruleSpec || st.levelSpec)).params;
    const ill = new PB.Raster(56, 32);
    PB.terrain.drawBackground(ill, T, 0, 0, 56, 32, tick);
    const dug = Math.floor(tick / 60) % 2 === 1;
    PB.terrain.drawTerrain(ill, { w: 4, h: 2, at: (tx, ty) => (ty === 1 ? 1 : ty === 0 && tx === 2 && !dug ? 3 : 0) }, T, -4, 0, 0);
    S().draw(ill, "char.miner", dug ? "idle" : "dig", tick, 20, 16);
    r.blit(ill, x + 8, y + 22);
    r.rect(x + 7, y + 21, 58, 1, "z"); r.rect(x + 7, y + 54, 58, 1, "z");
    if (dug) S().draw(r, "item.sandbag", 0, 0, x + 70, y + 30);
    const lines = wrap(p.text, w - 84);
    lines.slice(0, 4).forEach((line, i) => TX().draw(r, line, x + 74 + (dug ? 16 : 0) * 0, y + 22 + i * 13, "u"));
    const bx = x + w - 70, by = y + h - 20;
    panel(r, bx, by, 62, 15, 1); TX().centered(r, p.close, bx + 31, by, "l");
    wideKey(r, "Esc", x + 8, by + 1);
  }

  const SCREENS = { lobby, chapters, levels, pause, hint, complete, settings, rulecard };
  function render(r, asset, tick, st) { SCREENS[asset.params.screen](r, tick, asset.params, st || {}); }
  PB.ui = { render, SCREENS, wrap, text2x };
})(typeof window !== "undefined" ? window : globalThis);
