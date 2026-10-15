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
    for (const ch of str) {
      if (TX().measure(line + ch) > width) { lines.push(line); line = ch === " " ? "" : ch; } else line += ch;
    }
    if (line) lines.push(line);
    return lines;
  }
  function dim(r) { r.remap(0, 0, W, H, PB.DIM); r.remap(0, 0, W, H, PB.DIM); }

  function backdrop(r, theme, tick) {
    const T = S().get(theme).params;
    PB.terrain.drawBackground(r, T, 0, 0, W, H, tick);
    const floor = { w: 21, h: 2, at: (x, y) => (y < 0 || x < 0 || x >= 21 || y >= 2 ? 0 : 1) };
    PB.terrain.drawTerrain(r, floor, T, 0, H - 24, tick >> 3);
  }

  // ---------- screens ----------
  function lobby(r, tick, p, st) {
    backdrop(r, p.theme, tick);
    text2x(r, p.title, 20, 18, "l", "g");
    TX().draw(r, p.subtitle, 22, 50, "d", "z");
    S().draw(r, "obj.crate_wood", "default", 0, 236, H - 24);
    S().draw(r, "obj.crate_wood", "default", 0, 252, H - 24);
    S().draw(r, "obj.crate_wood", "default", 0, 244, H - 40);
    S().draw(r, "char.miner", "idle", tick, 220, H - 24);
    S().draw(r, "mech.exit_flag", "idle", tick, 284, H - 24);
    const sel = st.focus | 0, x = 20, y0 = 74;
    p.items.forEach((label, i) => {
      const y = y0 + i * 18;
      panel(r, x, y, 92, 16, i === sel ? 1 : 0);
      if (i === sel) { r.rect(x + 5, y + 6, 2, 4, "k"); r.rect(x + 7, y + 7, 1, 2, "k"); }
      TX().draw(r, label, x + 12, y + 1, i === sel ? "l" : "u");
    });
    let kx = 20; const ky = H - 17;
    key(r, "up", kx, ky); key(r, "down", kx + 14, ky); kx += 30;
    kx += TX().draw(r, p.hint_select, kx, ky - 1, "v") + 8;
    kx += wideKey(r, "Enter", kx, ky) + 3;
    TX().draw(r, p.hint_confirm, kx, ky - 1, "v");
  }

  function chapters(r, tick, p, st) {
    backdrop(r, "terrain.mine", tick);
    dim(r);
    TX().draw(r, p.heading, 12, 6, "l", "z");
    const sel = st.focus | 0, cw = 58, gap = 4, x0 = (W - (cw * 5 + gap * 4)) >> 1, y0 = 26;
    p.chapters.forEach((ch, i) => {
      const x = x0 + i * (cw + gap), y = y0 + (i === sel ? -2 : 0);
      panel(r, x, y, cw, 112, i === sel ? 1 : 0);
      // Thumbnail: a strip of that chapter's terrain, or a locked plate.
      const th = { x: x + 5, y: y + 5, w: cw - 10, h: 44 };
      if (ch.theme && S().has(ch.theme)) {
        const T = S().get(ch.theme).params;
        const tmp = new PB.Raster(th.w, th.h);
        PB.terrain.drawBackground(tmp, T, 0, 0, th.w, th.h, tick);
        PB.terrain.drawTerrain(tmp, { w: 4, h: 1, at: (tx, ty) => (ty === 0 && tx >= 0 && tx < 4 ? ch.floor || 1 : 0) }, T, 0, th.h - 16, tick >> 3);
        r.blit(tmp, th.x, th.y);
        if (ch.sprite) S().draw(r, ch.sprite, "idle", tick, th.x + 16, th.y + th.h - 16);
      } else {
        r.rect(th.x, th.y, th.w, th.h, "y");
      }
      if (ch.locked) {
        r.remap(th.x, th.y, th.w, th.h, PB.DIM);
        icon(r, "lock", x + (cw >> 1) - 6, th.y + 16);
      }
      r.rect(th.x - 1, th.y - 1, th.w + 2, 1, "z"); r.rect(th.x - 1, th.y + th.h, th.w + 2, 1, "z");
      TX().centered(r, ch.num, x + (cw >> 1), y + 52, "v");
      TX().centered(r, ch.name, x + (cw >> 1), y + 66, ch.locked ? "w" : "u");
      TX().centered(r, ch.progress, x + (cw >> 1), y + 84, ch.locked ? "w" : i === sel ? "l" : "k");
    });
    const cur = p.chapters[sel];
    panel(r, 12, 146, W - 24, 24, 0);
    TX().draw(r, cur.locked ? cur.unlock : cur.blurb, 20, 151, cur.locked ? "v" : "u");
  }

  function levels(r, tick, p, st) {
    backdrop(r, "terrain.mine", tick);
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
    PB.scene.renderLevel(r, spec, null, Object.assign({ tick, theme: "terrain.mine" }, extra || {}));
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
    PB.scene.renderLevel(r, spec, parsed, { tick, pose: "win", theme: "terrain.mine" });
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
    backdrop(r, "terrain.mine", tick);
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

  const SCREENS = { lobby, chapters, levels, pause, hint, complete, settings };
  function render(r, asset, tick, st) { SCREENS[asset.params.screen](r, tick, asset.params, st || {}); }
  PB.ui = { render, SCREENS, wrap, text2x };
})(typeof window !== "undefined" ? window : globalThis);
