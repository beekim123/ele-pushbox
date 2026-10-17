/* UI-09 · the generic interface style (docs/packages/UI-09.md).
 * The user looked at the proposals and chose G2 深蓝圆角: dark blue rounded
 * panels with a dark outer line and a light inner line, selection drawn
 * reversed (white face, dark text) and a small mint accent. This file draws its
 * components and the sample screens (generic lobby, pause on a dark map, level
 * clear on a light map, level HUD, delivery reels, English pause) for the
 * workbench page #ui-proposals and the overview image
 * docs/packages/UI-09/G2_深蓝圆角.png; UI-10 builds the full set of game
 * screens from it.
 * Not a game asset: nothing here is registered in PB.ui.SCREENS and nothing has
 * an art/source entry. Text, masks, dim and the coin come from the ui-kit.js
 * tools (called, never changed); backdrops are real levels and lobby scenes
 * drawn by PB.scene / PB.uiStyle, like ui-style.js levelScene. Words only this
 * file needs are in TEXT (drawn with glyphs the frozen fonts already have);
 * UI-10 moves them into a text table. */
(function (root) {
  "use strict";
  const PB = (root.PB = root.PB || {});
  const U = () => PB.uk, S = () => PB.sprites, I = () => PB.i18n;
  const W = 320, H = 180, fd = (a, b) => Math.floor(a / b);
  const ARROWS = ["up", "down", "left", "right"];

  // ================================================================ words
  const TEXT = {
    "zh-Hans": {
      "g.lobby.level": "关卡模式", "g.lobby.delivery": "配送",
      "g.reels.map": "地图", "g.reels.tip": "小费 ×1.5",
      "g.keys.move": "移动", "g.keys.undo": "撤销", "g.keys.pause": "暂停",
      "g.say": "木箱会浮起来！", "g.think": "这条路对不对……", "g.hello": "你好！",
    },
    en: {
      "g.lobby.level": "Level mode", "g.lobby.delivery": "Delivery",
      "g.reels.map": "Map", "g.reels.tip": "Tip ×1.5",
      "g.keys.move": "Move", "g.keys.undo": "Undo", "g.keys.pause": "Pause",
      "g.say": "Wood floats!", "g.think": "Is this the way...", "g.hello": "Hello!",
    },
  };
  function t(key, vars) {
    const zh = TEXT["zh-Hans"];
    if (!(key in zh)) return I().t(key, vars);
    const loc = I().getLocale(), tab = loc === "zh-Hans" ? zh : TEXT.en;
    let s = key in tab ? tab[key] : zh[key];
    if (vars) s = s.replace(/\{(\w+)\}/g, (m, n) => (n in vars ? String(vars[n]) : m));
    return loc === "qps" ? I().pseudo(s) : s;
  }
  const levelTitle = (spec) => (I().has(`level.${spec.id}.title`) ? t(`level.${spec.id}.title`) : spec.title || spec.id);
  const coinsText = (n) => String(n).replace(/\B(?=(\d{3})+(?!\d))/g, ",");

  // ================================================================ text checks
  // Every string goes through line(): it reports text wider than its room, text
  // past the screen edge and characters the fonts do not have.
  let issues = [];
  function report(kind, key, detail) { if (issues.length < 200) issues.push({ kind, key, detail }); }
  function fontOf(sz) { return sz === 10 ? PB.FONT_SMALL : PB.FONT; }
  function line(c, x, y, s, col, o, room, key) {
    o = Object.assign({ sz: 12 }, o || {});
    const w = c.tw(s, o.sz, o.scale), F = fontOf(o.sz);
    if (room != null && w > room) report("overflow", key || s, w + " > " + room);
    const x0 = o.align === "c" ? x - fd(w, 2) : o.align === "r" ? x - w : x;
    if (c.w === W && (x0 < 0 || x0 + w > W)) report("offscreen", key || s, x0 + ".." + (x0 + w));
    if (F && F.glyphs) for (const ch of s) if (!/\s/.test(ch) && !F.glyphs[ch]) report("glyph", key || s, ch);
    c.text(x, y, s, col, o);
    return w;
  }

  // ================================================================ shapes
  const MONO = {};
  function mono(col) {
    if (!MONO[col]) { const m = {}; for (const k of PB.CODES) m[k] = col; MONO[col] = m; }
    return MONO[col];
  }
  function icon(sid, name) { return U().frame(sid, S().get(sid).animations[name].frames[0]); }
  function maskOf(x, y, w, h, r) { const u = U(); return r > 0 ? u.roundM(x, y, w, h, r) : u.rectM(x, y, w, h); }
  function ring(c, M, col) {
    const u = U(), In = u.shrink(M, 1);
    for (const k of M) if (!In.has(k)) c.px(u.KX(k), u.KY(k), col);
    return In;
  }
  // The n rows of M nearest its top (dir -1) or bottom (dir 1) edge, per column.
  function band(c, M, col, n, dir) {
    const u = U();
    for (const k of M) { const a = u.KX(k), b = u.KY(k); for (let i = 1; i <= n; i++) if (!M.has(u.K(a, b + dir * i))) { c.px(a, b, col); break; } }
  }
  // A box: rings from the outside in, fill, top / bottom bands. Returns the fill mask.
  // s = { r, rings: [colour], fill, top: [colour, n], bottom: [colour, n] }
  function box(c, x, y, w, h, s) {
    let In = maskOf(x, y, w, h, s.r || 0);
    for (const col of s.rings || []) In = ring(c, In, col);
    if (s.fill) U().paint(c, In, s.fill);
    if (s.top) band(c, In, s.top[0], s.top[1], -1);
    if (s.bottom) band(c, In, s.bottom[0], s.bottom[1], 1);
    return In;
  }
  const ringsOf = (s) => (s.rings || []).length;
  const faceOf = (s, y, h) => { const rc = ringsOf(s); return { top: y + rc, h: h - 2 * rc - ((s.bottom && s.bottom[1]) || 0) }; };
  // Rings grown around a fill mask (bubbles, dots, triangles).
  function layered(c, F, rings, fill) {
    const u = U(), n = rings.length;
    for (let i = 0; i < n; i++) for (const k of u.grow(F, n - i, false)) c.px(u.KX(k), u.KY(k), rings[i]);
    u.paint(c, F, fill);
  }
  function triMask(x, y, n, dir) {
    const u = U(), M = new Set();
    // Tip at (x, y); i = distance from the tip, the base (i = n) is 2n + 1 long.
    for (let i = 0; i <= n; i++) for (let j = -i; j <= i; j++) {
      if (dir === "left") M.add(u.K(x + i, y + j)); else if (dir === "up") M.add(u.K(x + j, y + i));
      else if (dir === "down") M.add(u.K(x + j, y - i)); else M.add(u.K(x - i, y + j));
    }
    return M;
  }
  function discMask(cx, cy, r) {
    const u = U(), M = new Set();
    for (let j = -r; j <= r; j++) for (let i = -r; i <= r; i++) if (i * i + j * j <= r * r + r * 0.8) M.add(u.K(cx + i, cy + j));
    return M;
  }
  // Speech bubble fill: rounded box plus a tail under it, its straight edge at tx.
  function sayMask(x, y, w, h, r, tx, len, flip) {
    const u = U(), F = maskOf(x, y, w, h, r);
    for (let i = 0; i < len; i++) for (let a = 0; a < len - i; a++) F.add(u.K(tx + (flip ? -a : a), y + h + i));
    return F;
  }
  // Title with a scale-2 headline, a drop under it and an outline (lobby logo).
  function bigText(c, x, y, s, fill, line1, drop) {
    line(c, x, y + 2, s, drop, { sz: 12, scale: 2, outline: drop });
    line(c, x, y, s, fill, { sz: 12, scale: 2, outline: line1 });
  }

  // ================================================================ the style: G2 深蓝圆角
  // P is the token table (which colour, radius and line goes where); K draws the
  // components from it. ENDESGA32 codes, see raster.js.
  const P = {
    id: "G2", name: "深蓝圆角",
    line: "深蓝圆角面板，外圈一道深色边、里面一道浅色细边，选中时反成白底深字，薄荷绿只做小点缀：安静、不抢画面。",
    fits: "适合：亮图（深色面板最显眼）和暗图（浅色细边把面板和背景分开）；夜里玩眼睛舒服，和现在的界面最接近，改起来最省事。",
    notFits: "不适合：想要明快、热闹的感觉；在石牢、地府这类深蓝深紫的地图上，面板主要靠浅色细边分开。",
    short: "深蓝面板 · 浅色细边 · 反白选中 · 亮色点缀",
    colors: [["y", "面板底色"], ["z", "外描边"], ["u", "浅色细边、次要字"], ["x", "按钮、按键、分隔线"], ["w", "按钮高光、不能按"], ["t", "正文字、选中底"], ["m", "点缀：光标、开关开、标记"]],
    ink: "t", sub: "u", dis: "w",
    panel: { r: 4, rings: ["z", "u"], fill: "y" },
    small: { r: 3, rings: ["z", "u"], fill: "y" },
    plate: { r: 3, rings: ["z", "u"], fill: "y" }, plateText: "t", plateSub: "u",
    btn: { n: { r: 3, rings: ["z"], fill: "x", top: ["w", 1] }, sel: { r: 3, rings: ["z"], fill: "t", bottom: ["u", 1] }, dis: { r: 3, rings: ["z", "x"], fill: "y" } },
    btnText: { n: "t", sel: "y", dis: "w" },
    icons: { n: null, sel: mono("y"), dis: mono("w") },
    rowSel: { r: 3, fill: "t" },
    key: { r: 1, rings: ["z"], fill: "x", top: ["w", 1] }, keyText: "t",
    cursor: { fill: "m", line: "z" },
    say: { r: 3, rings: ["z", "u"], fill: "y", text: "t" }, think: { r: 4, rings: ["z", "u"], fill: "y", text: "u" },
    slider: { line: "z", track: "x", fill: "m", knob: "t" },
    toggle: { line: "z", on: "m", off: "x", knob: "t" },
    tag: { r: 2, fill: "m", text: "y" }, tagAlt: { r: 2, rings: ["u"], fill: "y", text: "t" },
    well: { r: 2, rings: ["z"], fill: "z" }, wellSel: { r: 2, rings: ["m"], fill: "z" },
    rowH: 15, rowGap: 0, padX: 8, padB: 6, titleOver: 0, titleH: 24,
  };

  const K = {
    keyW: (c, label) => (ARROWS.includes(label) ? 11 : c.tw(label, 10) + 7),
    keycap(c, x, y, label) {
      const w = K.keyW(c, label), u = U(), col = P.keyText;
      box(c, x, y, w, 11, P.key);
      if (label === "up" || label === "down") u.glyph(c, u.ARROW[label + "5"], x + 3, y + 3, col);
      else if (label === "left" || label === "right") u.glyph(c, u.ARROW[label + "5"], x + 4, y + 2, col);
      else line(c, x + fd(w, 2), y + 1, label, col, { sz: 10, align: "c" });
      return w;
    },
    panel: (c, x, y, w, h, small) => box(c, x, y, w, h, small ? P.small : P.panel),
    plate: (c, x, y, w, h) => box(c, x, y, w, h, P.plate),
    // "— 暂停 —": centred title with two mint dashes, a dark rule under it.
    title(c, x, y, w, text) {
      const tw = line(c, x + fd(w, 2), y + 6, text, "t", { sz: 12, align: "c" }, w - 40, "title");
      const l = x + fd(w, 2) - fd(tw, 2) - 6, r = x + fd(w, 2) + tw - fd(tw, 2) + 5;
      c.hline(l - 7, y + 11, 7, "m"); c.hline(r + 1, y + 11, 7, "m");
      c.hline(x + 6, y + 20, w - 12, "x");
    },
    logo(c, x, y) {
      bigText(c, x, y, t("game.title"), "t", "z", "y");
      line(c, x + 2, y + 28, "PORTITOR", "m", { sz: 10, spacing: 2, outline: "z" });
      line(c, x, y + 43, t("game.tagline"), "t", { sz: 10, outline: "z" });
    },
    // Icon + label (+ keycap at the right end) inside a box face.
    content(c, x, y, w, face, label, st, o) {
      o = o || {};
      const ic = o.icon ? icon(o.icon[0], o.icon[1]) : null, iw = ic ? ic[0].length + 4 : 0;
      const kw = o.key ? K.keyW(c, o.key) + 4 : 0, pad = o.pad == null ? 6 : o.pad, lw = c.tw(label, 12);
      const room = w - 2 * pad - iw - kw;
      let xx = o.align === "l" ? x + pad : x + pad + Math.max(0, fd(room - lw, 2));
      if (ic) { c.blit(ic, xx, face.top + fd(face.h - ic.length, 2), false, P.icons[st]); xx += iw; }
      line(c, xx, face.top + fd(face.h - 11, 2), label, P.btnText[st], { sz: 12 }, room, o.id || label);
      if (o.key) K.keycap(c, x + w - pad - kw + 4, face.top + fd(face.h - 11, 2), o.key);
    },
    // st: "n" normal, "sel" selected, "dis" can't press.
    button(c, x, y, w, h, label, st, o) {
      const s = P.btn[st];
      box(c, x, y, w, h, s);
      K.content(c, x, y, w, faceOf(s, y, h), label, st, o);
    },
    iconButton(c, x, y, w, h, ic, st) {
      const s = P.btn[st], f = faceOf(s, y, h);
      box(c, x, y, w, h, s);
      c.blit(ic, x + fd(w - ic[0].length, 2), f.top + fd(f.h - ic.length, 2), false, P.icons[st]);
    },
    // Menu row: plain text on the panel; the selected row is a white bar.
    row(c, x, y, w, h, label, st, o) {
      o = Object.assign({ align: "l" }, o || {});
      const s = st === "sel" ? P.rowSel : { r: 0 };
      if (st === "sel") box(c, x, y, w, h, s);
      K.content(c, x, y, w, faceOf(s, y, h), label, st, o);
    },
    cursor: (c, x, y, dir) => layered(c, triMask(x, y, 3, dir || "right"), [P.cursor.line], P.cursor.fill),
    slider(c, x, y, w, v) {
      const s = P.slider, fx = x + 3 + Math.round((w - 7) * v);
      box(c, x, y + 2, w, 5, { r: 2, rings: [s.line], fill: s.track });
      c.rect(x + 1, y + 3, fx - x - 1, 3, s.fill);
      box(c, fx - 3, y, 7, 9, { r: 2, rings: [s.line], fill: s.knob });
    },
    toggle(c, x, y, on) {
      const s = P.toggle;
      box(c, x, y, 19, 11, { r: 5, rings: [s.line], fill: on ? s.on : s.off });
      box(c, on ? x + 9 : x + 1, y + 1, 9, 9, { r: 4, fill: s.knob });
    },
    // o.alt: the quiet tag (当前); o.icon: rows drawn before the text.
    tag(c, x, y, text, o) {
      o = o || {};
      const s = o.alt ? P.tagAlt : P.tag, ic = o.icon || null, iw = ic ? ic[0].length + 1 : 0, w = c.tw(text, 10) + 8 + iw;
      box(c, x, y, w, 12, s);
      let xx = x + 4;
      if (ic) { c.blit(ic, xx - 1, y + fd(12 - ic.length, 2)); xx += iw; }
      line(c, xx, y + 1, text, s.text, { sz: 10 });
      return w;
    },
    say(c, x, y, w, h, tx, text) {
      const s = P.say, rc = s.rings.length;
      layered(c, sayMask(x + rc, y + rc, w - 2 * rc, h - 2 * rc, s.r, tx, 4, tx > x + w / 2), s.rings, s.fill);
      line(c, x + fd(w, 2), y + fd(h - 11, 2), text, s.text, { sz: 12, align: "c" }, w - 2 * rc - 6, "say");
    },
    think(c, x, y, w, h, tx, text) {
      const s = P.think, rc = s.rings.length;
      layered(c, maskOf(x + rc, y + rc, w - 2 * rc, h - 2 * rc, s.r), s.rings, s.fill);
      layered(c, discMask(tx + 2, y + h + 2, 2), s.rings, s.fill);
      layered(c, discMask(tx - 2, y + h + 7, 1), s.rings, s.fill);
      line(c, x + fd(w, 2), y + fd(h - 11, 2), text, s.text, { sz: 12, align: "c" }, w - 2 * rc - 6, "think");
    },
    coins(c, xr, y, n) {
      const s = coinsText(n), w = 6 + 9 + 4 + c.tw(s, 12) + 6, x = xr - w, f = faceOf(P.plate, y, 17);
      K.plate(c, x, y, w, 17);
      U().coinIcon(c, x + 6, f.top + fd(f.h - 9, 2), true);
      line(c, x + 19, f.top + fd(f.h - 11, 2), s, P.plateText, { sz: 12 });
      return w;
    },
    heading(c, x, y, text) {
      const w = c.tw(text, 12) + 14, f = faceOf(P.plate, y, 17);
      K.plate(c, x, y, w, 17);
      line(c, x + 7, f.top + fd(f.h - 11, 2), text, P.plateText, { sz: 12 });
      return w;
    },
    // Reel window: the scrolling strip of a reel (inside a small panel).
    well: (c, x, y, w, h, sel) => box(c, x, y, w, h, sel ? P.wellSel : P.well),
  };

  // ================================================================ sample screens
  // Bottom key hints: keycaps + labels on a plate.
  function keybar(c, items, x, y, align) {
    let w = 0;
    items.forEach(([ks, lab], n) => {
      ks.forEach((key, i) => { w += K.keyW(c, key) + (i < ks.length - 1 ? 1 : 0); });
      w += 3 + c.tw(lab, 10) + (n < items.length - 1 ? 9 : 0);
    });
    const pw = w + 12;
    if (align === "c") x -= fd(pw, 2); else if (align === "r") x -= pw;
    K.plate(c, x, y - 2, pw, 15);
    let xx = x + 6;
    for (const [ks, lab] of items) {
      ks.forEach((key, i) => { xx += K.keycap(c, xx, y, key) + (i < ks.length - 1 ? 1 : 0); });
      xx += 3; xx += line(c, xx, y + 1, lab, P.plateText, { sz: 10 }) + 9;
    }
    return pw;
  }
  const HUD_BUTTONS = ["undo", "restart", "hint", "pause"];
  function hudBar(c, spec, lamps) {
    const id = spec.id, name = levelTitle(spec), f = faceOf(P.plate, 2, 17);
    const lw = 8 + c.tw(id, 10) + 5 + c.tw(name, 12) + 8;
    K.plate(c, 3, 2, lw, 17);
    line(c, 11, f.top + fd(f.h - 9, 2), id, P.plateSub, { sz: 10 });
    line(c, 11 + c.tw(id, 10) + 5, f.top + fd(f.h - 11, 2), name, P.plateText, { sz: 12 }, 150, "level.title");
    const x = 317 - HUD_BUTTONS.length * 19 + 2;
    HUD_BUTTONS.forEach((nm, i) => K.iconButton(c, x + i * 19, 2, 17, 17, icon("ui.icons", nm), "n"));
    const gw = 8 + lamps.length * 11 - 2 + 8, gx = x - 4 - gw;
    K.plate(c, gx, 2, gw, 17);
    lamps.forEach((on, i) => c.blit(icon("ui.goal_lamp", on ? "on" : "off"), gx + 8 + i * 11, f.top + fd(f.h - 9, 2)));
  }
  function rowNeed(c, it) { return 6 + (it.icon ? 16 : 0) + c.tw(it.label, 12) + (it.key ? 4 + K.keyW(c, it.key) : 0) + 6; }
  function menu(c, cx, top, title, items, minW) {
    const rh = P.rowH, gap = P.rowGap, padX = P.padX;
    const w = Math.max(minW, ...items.map((it) => rowNeed(c, it) + 2 * padX));
    const x = cx - fd(w, 2), y = top + P.titleOver, h = P.titleH + items.length * (rh + gap) - gap + P.padB;
    K.panel(c, x, y, w, h);
    K.title(c, x, y, w, title);
    items.forEach((it, i) => {
      const ry = y + P.titleH + i * (rh + gap);
      K.row(c, x + padX, ry, w - 2 * padX, rh, it.label, it.st, { icon: it.icon, key: it.key, id: it.id });
      if (it.st === "sel") K.cursor(c, x + padX - 2, ry + fd(rh - 1, 2));
    });
    return { x, y, w, h };
  }

  const PAUSE = [
    ["pause.resume", ["ui.menu_icons", "continue"], "Esc"], ["pause.hint", ["ui.icons", "hint"], "H"],
    ["pause.restart", ["ui.icons", "restart"], "R"], ["pause.skip", ["ui.icons", "skip"], null],
    ["pause.levels", ["ui.menu_icons", "chapters"], null], ["pause.settings", ["ui.menu_icons", "settings"], null],
    ["pause.menu", ["ui.menu_icons", "quit"], null],
  ];
  function pause(c, bg) {
    hudBar(c, bg.spec, bg.lamps.map(() => false));
    U().dim(c, 1);
    // 跳过此关 is drawn as "can't press" to show the third button state on a real screen.
    const items = PAUSE.map(([key, ic, cap], i) => ({ id: key, label: t(key), icon: ic, key: cap, st: i === 0 ? "sel" : key === "pause.skip" ? "dis" : "n" }));
    menu(c, 160, 22, t("pause.title"), items, 132);
    keybar(c, [[["up", "down"], t("keys.select")], [["Enter"], t("keys.confirm")], [["Esc"], t("keys.back")]], 160, 163, "c");
  }
  function lobby(c) {
    K.logo(c, 16, 10);
    K.coins(c, 313, 6, 1280);
    const items = ["g.lobby.level", "g.lobby.delivery", "menu.settings", "menu.quit"];
    const x = 22, y0 = 72, bw = 104, bh = 18;
    items.forEach((key, i) => K.button(c, x, y0 + i * 22, bw, bh, t(key), i === 0 ? "sel" : "n", { id: key }));
    K.cursor(c, x - 3, y0 + 8);
    keybar(c, [[["up", "down"], t("keys.select")], [["Enter"], t("keys.confirm")]], 10, 163);
  }
  function complete(c, bg) {
    hudBar(c, bg.spec, bg.lamps);
    const w = 160, x = 160 - fd(w, 2), y = 26 + P.titleOver, bh = 17, h = P.titleH + 16 + bh + 9;
    K.panel(c, x, y, w, h);
    K.title(c, x, y, w, t("complete.title"));
    line(c, 160, y + P.titleH + 1, t("complete.moves", { n: bg.spec.solution.length }), P.ink, { sz: 12, align: "c" }, w - 16, "complete.moves");
    const by = y + P.titleH + 16, bw = fd(w - 12 * 2 - 8, 2);
    K.button(c, x + 12, by, bw, bh, t("complete.next"), "sel", { id: "complete.next" });
    K.button(c, x + w - 12 - bw, by, bw, bh, t("complete.levels"), "n", { id: "complete.levels" });
    K.cursor(c, x + 9, by + 8);
    keybar(c, [[["left", "right"], t("keys.select")], [["Enter"], t("keys.confirm")]], 160, 163, "c");
  }
  function hud(c, bg) {
    hudBar(c, bg.spec, bg.lamps);
    const hx = bg.o.ox + bg.player.x * 16, hy = bg.o.oy + bg.player.y * 16;
    const s = t("g.say"), w = c.tw(s, 12) + 16, h = 19;
    K.say(c, hx + 6 - 8, hy - h - 6, w, h, hx + 6, s);
    keybar(c, [[["left", "right"], t("g.keys.move")], [["Z"], t("g.keys.undo")], [["R"], t("pause.restart")], [["H"], t("pause.hint")], [["Esc"], t("g.keys.pause")]], 160, 163, "c");
  }
  // Reels: map -> recipient -> cargo; the recipient reel is the one being turned.
  function reelStrip(c, x, y, w, h, list, gapY, sel) {
    const u = U(), In = K.well(c, x, y, w, h, sel), sub = u.C.make(w, h, ".");
    list.forEach((f, i) => {
      const fw = f[0].length, fh = f.length, oy = fd(h - fh, 2) + (i - 1) * gapY;
      sub.blit(f, fd(w - fw, 2), oy);
      if (i !== 1) u.dim(sub, 2, [0, Math.max(0, oy), w, Math.min(h, oy + fh)]);
    });
    for (const kk of In) { const a = u.KX(kk), b = u.KY(kk), v = sub.get(a - x, b - y); if (v && v !== ".") c.px(a, b, v); }
  }
  const heart = () => U().frame("ui.delivery_icons", 0).slice(3, 13).map((r) => r.slice(2, 14));
  function reels(c, bg) {
    K.heading(c, 6, 5, t("dlv.reels.title"));
    K.coins(c, 313, 5, 1280);
    const av = (id) => U().frame("avatar." + id, 0), cg = (id) => U().frame("cargo." + id, 0);
    const cols = [
      { label: t("g.reels.map"), name: t("theme.dungeon"), list: [bg.thumbs.diyu, bg.thumbs.dungeon, bg.thumbs.diyu], gap: 34 },
      { label: t("dlv.reels.recipient"), name: t("recipient.old_miner.name"), list: [av("goblin_smith"), av("old_miner"), av("zombie")], gap: 30, sel: true },
      { label: t("dlv.reels.cargo"), name: t("cargo.letter.name"), list: [cg("ice_cream"), cg("letter"), cg("vase")], gap: 22 },
    ];
    const rw = 86, rh = 90, ry = 27, xs = [14, 117, 220], rc = ringsOf(P.small);
    cols.forEach((col, i) => {
      const x = xs[i];
      K.panel(c, x, ry, rw, rh, true);
      line(c, x + fd(rw, 2), ry + rc + 3, col.label, P.sub, { sz: 10, align: "c" }, rw - 8, "reel.label");
      reelStrip(c, x + rc + 4, ry + rc + 15, rw - 2 * rc - 8, 50, col.list, col.gap, col.sel);
      line(c, x + fd(rw, 2), ry + rc + 69, col.name, P.ink, { sz: 12, align: "c" }, rw - 2 * rc - 6, "reel.name");
      if (col.sel) { K.cursor(c, x - 3, ry + fd(rh, 2)); K.cursor(c, x + rw + 2, ry + fd(rh, 2), "left"); }
      if (i < 2) { const ax = x + rw + 9; layered(c, triMask(ax, ry + fd(rh, 2), 2, "right"), [P.cursor.line], P.sub); }
    });
    const ix = 10, iy = 122, iw = 300;
    K.panel(c, ix, iy, iw, 36, true);
    const l1 = line(c, ix + rc + 6, iy + rc + 2, t("cargo.letter.name") + " · ", P.ink, { sz: 12 });
    line(c, ix + rc + 6 + l1, iy + rc + 2, t("cargo.letter.rule"), P.sub, { sz: 12 }, iw - 2 * rc - 12 - l1, "cargo.rule");
    const l2 = line(c, ix + rc + 6, iy + rc + 16, t("recipient.old_miner.name") + " · ", P.ink, { sz: 12 });
    const tip = t("g.reels.tip"), hi = heart(), tw = c.tw(tip, 10) + 8 + hi[0].length + 1;
    line(c, ix + rc + 6 + l2, iy + rc + 16, t("recipient.old_miner.rule"), P.sub, { sz: 12 }, iw - 2 * rc - 12 - l2 - tw - 6, "recipient.rule");
    K.tag(c, ix + iw - rc - 6 - tw, iy + rc + 16, tip, { icon: hi });
    keybar(c, [[["left", "right"], t("dlv.keys.reel")], [["R"], t("dlv.reels.reroll", { n: 1 })], [["Enter"], t("dlv.keys.go")]], 160, 163, "c");
  }

  // ================================================================ backdrops (cached)
  const cache = new Map();
  function levelOf(o, id) {
    if (o && typeof o.level === "function") return o.level(id);
    if (o && o.levels && o.levels[id]) return o.levels[id];
    if (root.PBStore && root.PBStore.level) return root.PBStore.level(id);
    throw new Error("ui-generic: no level " + id);
  }
  function levelBg(o, id, win) {
    const spec = levelOf(o, id), TM = PB.tilemodel, parsed = TM.parse(spec);
    if (win) for (const a of spec.solution) TM.act(parsed.level, parsed.state, a);
    const r = new PB.Raster(W, H);
    const at = PB.scene.renderLevel(r, spec, parsed, Object.assign({ tick: 0, hud: false, env: "full" }, win ? { pose: "win" } : {}));
    return { r, spec, o: at, player: parsed.state.player, lamps: TM.goals(parsed.level, parsed.state).map((g) => !!g.lit) };
  }
  function thumb(theme) {
    const r = new PB.Raster(W, H); PB.uiStyle.backdrop(r, theme, 0, "full", true);
    const c = new (U().C)(r), out = [];
    for (let y = 0; y < 30; y++) { let s = ""; for (let x = 0; x < 50; x++) s += c.get(196 + x, 128 + y); out.push(s); }
    return out;
  }
  const BACKDROPS = {
    lobby: () => { const r = new PB.Raster(W, H); PB.uiStyle.backdrop(r, "theme.sky", 0, "full", true); return { r }; },
    pause: (o) => levelBg(o, "M05", false),
    complete: (o) => levelBg(o, "F07", true),
    hud: (o) => levelBg(o, "W02", false),
    reels: () => {
      const r = new PB.Raster(W, H); PB.uiStyle.backdrop(r, "theme.dungeon", 0, "full", false); U().dim(new (U().C)(r), 2);
      return { r, thumbs: { dungeon: thumb("theme.dungeon"), diyu: thumb("theme.diyu") } };
    },
  };
  function backdrop(name, o) { if (!cache.has(name)) cache.set(name, BACKDROPS[name](o)); return cache.get(name); }

  const SCREENS = [
    { id: "lobby", name: "通用大厅", note: "背景：云端圣域大厅", bg: "lobby", draw: lobby },
    { id: "pause", name: "暂停 · 暗图", note: "背景：幽暗石牢 M05", bg: "pause", draw: pause },
    { id: "complete", name: "过关 · 亮图", note: "背景：云端圣域 F07", bg: "complete", draw: complete },
    { id: "hud", name: "关卡 HUD", note: "背景：黄金神庙 W02", bg: "hud", draw: hud },
    { id: "reels", name: "配送开局三滚轮台", note: "背景：幽暗石牢大厅压暗", bg: "reels", draw: reels },
    { id: "pause_en", name: "暂停 · English", note: "背景：幽暗石牢 M05", bg: "pause", draw: pause, locale: "en" },
  ];
  const SCREEN_BY_ID = Object.fromEntries(SCREENS.map((s) => [s.id, s]));

  // ================================================================ components
  // The component sheet: every part on its own over a strip of a dark map (M05
  // 石牢) and of a light one (F07 云端 after the clear), CW pixels wide.
  const CW = 112;
  const hero = () => U().frame("char.portitor", 0);
  function cSettings(c) {
    const x = 4, w = CW - 8, y = 3 + P.titleOver, rh = 15, h = P.titleH + 2 * rh + P.padB + 1;
    K.panel(c, x, y, w, h);
    K.title(c, x, y, w, t("settings.title"));
    const ry = y + P.titleH, lx = x + P.padX + 2;
    line(c, lx, ry + 2, t("settings.music"), P.ink, { sz: 12 }, 28, "settings.music");
    K.slider(c, lx + 30, ry + 3, w - 2 * P.padX - 34, 0.7);
    line(c, lx, ry + rh + 2, t("settings.sfx"), P.ink, { sz: 12 }, 28, "settings.sfx");
    K.toggle(c, x + w - P.padX - 2 - 19, ry + rh + 2, true);
  }
  function cPanelSmall(c) {
    const x = 4, y = 4, w = CW - 8, h = 26, rc = ringsOf(P.small);
    K.panel(c, x, y, w, h, true);
    c.blit(U().frame("cargo.letter", 0), x + rc + 5, y + fd(h - 16, 2));
    line(c, x + rc + 25, y + fd(h - 11, 2), t("cargo.letter.name"), P.ink, { sz: 12 }, 40, "cargo.letter.name");
    line(c, x + w - rc - 6, y + fd(h - 9, 2), t("dlv.reels.cargo"), P.sub, { sz: 10, align: "r" }, 30, "dlv.reels.cargo");
  }
  function cTitle(c) {
    const x = 4, w = CW - 8, y = 4 + P.titleOver;
    K.panel(c, x, y, w, P.titleH + 8);
    K.title(c, x, y, w, t("pause.title"));
  }
  const cButton = (key, st, ic) => (c) => {
    const x = 14, y = 5, w = CW - 28;
    K.button(c, x, y, w, 18, t(key), st, { icon: ic, id: key });
    if (st === "sel") K.cursor(c, x - 3, y + 8);
  };
  function cCursor(c) {
    const x = 6, w = CW - 12, y = 3, top = y + ringsOf(P.panel) + 3, rh = P.rowH;
    K.panel(c, x, y, w, top - y + 2 * rh + P.rowGap + P.padB);
    [["pause.resume", ["ui.menu_icons", "continue"], "Esc", "sel"], ["pause.restart", ["ui.icons", "restart"], "R", "n"]].forEach(([key, ic, cap, st], i) => {
      const ry = top + i * (rh + P.rowGap);
      K.row(c, x + P.padX, ry, w - 2 * P.padX, rh, t(key), st, { icon: ic, key: cap, id: key });
      if (st === "sel") K.cursor(c, x + P.padX - 2, ry + fd(rh - 1, 2));
    });
  }
  function cKeycap(c) {
    const keys = ["up", "down", "Enter", "Esc", "Z"];
    let x = fd(CW - (keys.reduce((s, k) => s + K.keyW(c, k), 0) + 2 * (keys.length - 1)), 2);
    for (const k of keys) x += K.keycap(c, x, 4, k) + 2;
    keybar(c, [[["up", "down"], t("keys.select")], [["Z"], t("g.keys.undo")]], fd(CW, 2), 22, "c");
  }
  function cTag(c) {
    const a = t("lobby.current_tag"), b = t("g.reels.tip"), hi = heart();
    const wa = c.tw(a, 10) + 8, wb = c.tw(b, 10) + 8 + hi[0].length + 1, x = fd(CW - wa - 4 - wb, 2);
    K.tag(c, x, 5, a, { alt: true });
    K.tag(c, x + wa + 4, 5, b, { icon: hi });
  }
  function cSay(c) {
    const s = t("g.hello"), w = c.tw(s, 12) + 16, h = 19, bx = fd(CW - w, 2), by = 4, hx = bx + 2;
    K.say(c, bx, by, w, h, hx + 6, s);
    c.blit(hero(), hx, by + h + 6);
  }
  function cThink(c) {
    const s = t("g.think"), w = Math.min(CW - 4, c.tw(s, 12) + 16), h = 19, bx = fd(CW - w, 2), by = 3, hx = bx + w - 34;
    K.think(c, bx, by, w, h, hx + 6, s);
    c.blit(hero(), hx, by + h + 12);
  }
  function cHud(c, env) {
    const spec = env.spec, id = spec.id, name = levelTitle(spec), f = faceOf(P.plate, 3, 17), g = faceOf(P.plate, 23, 17);
    K.plate(c, 3, 3, 8 + c.tw(id, 10) + 5 + c.tw(name, 12) + 8, 17);
    line(c, 11, f.top + fd(f.h - 9, 2), id, P.plateSub, { sz: 10 });
    line(c, 11 + c.tw(id, 10) + 5, f.top + fd(f.h - 11, 2), name, P.plateText, { sz: 12 }, CW - 30, "level.title");
    const gw = 8 + 2 * 11 - 2 + 8;
    K.plate(c, 3, 23, gw, 17);
    [true, false].forEach((on, i) => c.blit(icon("ui.goal_lamp", on ? "on" : "off"), 11 + i * 11, g.top + fd(g.h - 9, 2)));
    ["undo", "hint", "pause"].forEach((nm, i) => K.iconButton(c, 3 + gw + 4 + i * 19, 23, 17, 17, icon("ui.icons", nm), "n"));
  }
  // name: the word on the page; px: the word drawn in the overview image when the
  // fonts lack a glyph of name (键帽 / 标签).
  const COMPONENTS = [
    { id: "panel", name: "面板（大）", h: 67, draw: cSettings, note: "深蓝底，外圈深色边、里面一道浅色细边，圆角 4。例子：设置面板（标题、音乐滑块、音效开关）。" },
    { id: "panel_small", name: "面板（小）", h: 34, draw: cPanelSmall, note: "同样的两道边，圆角 3：滚轮台的三个小格、信息条、列表项。" },
    { id: "title", name: "标题条", h: 39, draw: cTitle, note: "标题居中，两侧薄荷短线，下面一道深灰蓝分隔线；不另画底条。" },
    { id: "btn_n", name: "按钮 · 普通", h: 28, draw: cButton("complete.levels", "n", ["ui.menu_icons", "chapters"]), note: "深灰蓝底，上沿一道高光，白字。" },
    { id: "btn_sel", name: "按钮 · 选中", h: 28, draw: cButton("complete.next", "sel", ["ui.menu_icons", "continue"]), note: "反白：白底深字，下沿浅灰，左边薄荷光标。" },
    { id: "btn_dis", name: "按钮 · 不能按", h: 28, draw: cButton("pause.skip", "dis", ["ui.icons", "skip"]), note: "和面板同色，只剩边，字和图标变暗。" },
    { id: "cursor", name: "光标", h: 47, draw: cCursor, note: "薄荷三角指着选中的那一行，选中行是白条；其余行直接写在面板上。" },
    { id: "keycap", name: "键帽提示", px: "按键提示", h: 38, draw: cKeycap, note: "深灰蓝小键帽、白字；底部提示条把键帽和说明放在一块小底板上。" },
    { id: "slider", name: "滑块", h: 21, draw: (c) => K.slider(c, 10, 6, CW - 20, 0.6), note: "深灰蓝槽，薄荷进度，白色滑钮。" },
    { id: "toggle", name: "开关", h: 21, draw: (c) => { K.toggle(c, 30, 5, true); K.toggle(c, 63, 5, false); }, note: "开：薄荷底、白钮在右；关：深灰蓝底、白钮在左。" },
    { id: "tag", name: "标签", px: "标记", h: 22, draw: cTag, note: "主标签薄荷底深字（小费 ×1.5）；次要标签深蓝底浅色边（当前）。" },
    { id: "say", name: "说话泡", h: 48, draw: cSay, note: "和面板一样的深蓝底两道边，尾巴指着说话的人。" },
    { id: "think", name: "心里话泡", h: 53, draw: cThink, note: "同样的泡，字用浅灰，下面两个小圆点代替尾巴。" },
    { id: "hud", name: "HUD 底板", h: 43, draw: cHud, note: "关卡号和关名、目标灯放在小底板上，图标按钮（撤销、提示、暂停）用普通按钮。" },
  ];
  const COMP_BY_ID = Object.fromEntries(COMPONENTS.map((x) => [x.id, x]));
  const STRIPS = { dark: { bg: "pause", note: "石牢 M05" }, light: { bg: "complete", note: "云端 F07 过关后" } };

  // ================================================================ drawing entry points
  function withLocale(loc, fn) {
    const prev = I().getLocale();
    try { I().setLocale(loc); return fn(); } finally { I().setLocale(prev); }
  }
  function drawScreen(r, sc, o) {
    withLocale(sc.locale || "zh-Hans", () => {
      const bg = backdrop(sc.bg, o);
      r.data.set(bg.r.data);
      sc.draw(new (U().C)(r), bg);
    });
  }
  function drawComponent(r, cp, tone, o) {
    withLocale("zh-Hans", () => {
      const src = backdrop(STRIPS[tone === "light" ? "light" : "dark"].bg, o).r;
      for (let y = 0; y < r.h; y++) for (let x = 0; x < r.w; x++) {
        const si = ((24 + y) * W + 4 + x) * 4, di = (y * r.w + x) * 4;
        for (let i = 0; i < 4; i++) r.data[di + i] = src.data[si + i];
      }
      cp.draw(new (U().C)(r), { spec: levelOf(o, "M05") });
    });
  }
  // One sample screen into r (320 x 180). Returns the text issues.
  function render(r, screenId, o) {
    const sc = SCREEN_BY_ID[screenId];
    if (!sc) throw new Error("ui-generic: unknown screen " + screenId);
    issues = [];
    drawScreen(r, sc, o);
    return issues.slice();
  }
  // One component into r (CW x its h) over the dark or the light strip. Returns the text issues.
  function component(r, compId, tone, o) {
    const cp = COMP_BY_ID[compId];
    if (!cp) throw new Error("ui-generic: unknown component " + compId);
    issues = [];
    drawComponent(r, cp, tone, o);
    return issues.slice();
  }

  // The overview image (1x): the six sample screens, the component sheet (dark |
  // light) and the palette. docs/packages/UI-09/G2_深蓝圆角.png is this at 2x,
  // the same function the page's download button calls.
  function overview(o) {
    issues = [];
    const M = 8, GAP = 8, OW = 2 * M + 3 * W + 2 * GAP, PAIR = 2 * CW + 2, COLS = 4, CGAP = fd(OW - 2 * M - COLS * PAIR, COLS - 1);
    const rows = [];
    for (let i = 0; i < COMPONENTS.length; i += COLS) rows.push(COMPONENTS.slice(i, i + COLS));
    const PCOLS = 4, PW = fd(OW - 2 * M, PCOLS), SHOT = 14 + H + 8;
    const yName = M, yShort = yName + 28, ySamples = yShort + 18, yShots = ySamples + 16;
    const yComp = yShots + 2 * SHOT, yCells = yComp + 16;
    const yPal = yCells + rows.reduce((s, row) => s + 12 + Math.max(...row.map((cp) => cp.h)) + 8, 0);
    const yColors = yPal + 16, yFoot = yColors + Math.ceil(P.colors.length / PCOLS) * 18 + 4, OH = yFoot + 9 + M;
    const r = new PB.Raster(OW, OH), c = new (U().C)(r);
    c.rect(0, 0, OW, OH, "z");
    const nw = line(c, M, yName, P.id + " " + P.name, "t", { sz: 12, scale: 2 });
    K.tag(c, M + nw + 8, yName + 7, "已选定");
    line(c, M, yShort, P.short, "u", { sz: 10 });
    line(c, M, ySamples, "样板界面 · 320×180", "t", { sz: 12 });
    SCREENS.forEach((sc, i) => {
      const x = M + (i % 3) * (W + GAP), y = yShots + fd(i, 3) * SHOT, sr = new PB.Raster(W, H);
      const w1 = line(c, x, y, sc.name, "t", { sz: 12 });
      line(c, x + w1 + 6, y + 2, sc.note, "v", { sz: 10 });
      drawScreen(sr, sc, o);
      c.frame(x - 1, y + 13, W + 2, H + 2, "x");
      r.blit(sr, x, y + 14);
    });
    line(c, M, yComp, "组件 · 左：暗图上 · 右：亮图上", "t", { sz: 12 });
    let y = yCells;
    for (const row of rows) {
      row.forEach((cp, i) => {
        const x = M + i * (PAIR + CGAP);
        line(c, x, y, cp.px || cp.name, "u", { sz: 10 }, PAIR, "comp." + cp.id);
        ["dark", "light"].forEach((tone, j) => { const cr = new PB.Raster(CW, cp.h); drawComponent(cr, cp, tone, o); r.blit(cr, x + j * (CW + 2), y + 12); });
      });
      y += 12 + Math.max(...row.map((cp) => cp.h)) + 8;
    }
    line(c, M, yPal, "调色 · ENDESGA32 代码", "t", { sz: 12 });
    P.colors.forEach(([code, use], i) => {
      const x = M + (i % PCOLS) * PW, yy = yColors + fd(i, PCOLS) * 18;
      c.frame(x, yy, 14, 14, "v"); c.rect(x + 1, yy + 1, 12, 12, code);
      line(c, x + 19, yy + 1, code, "t", { sz: 12 });
      line(c, x + 30, yy + 3, PB.PALETTE[code], "v", { sz: 10 });
      line(c, x + 76, yy + 3, use, "t", { sz: 10 }, PW - 84, "color." + code);
    });
    line(c, M, yFoot, "已选定 G2 · 下一步 UI-10 按这个风格做整套界面", "u", { sz: 10 });
    return { r, issues: issues.slice() };
  }
  // Integer upscale (the overview is shared at 2x).
  function scale(r, n) {
    if (n === 1) return r;
    const out = new PB.Raster(r.w * n, r.h * n);
    for (let y = 0; y < out.h; y++) for (let x = 0; x < out.w; x++) {
      const si = (fd(y, n) * r.w + fd(x, n)) * 4, di = (y * out.w + x) * 4;
      for (let i = 0; i < 4; i++) out.data[di + i] = r.data[si + i];
    }
    return out;
  }

  PB.uiGeneric = { STYLE: P, kit: K, SCREENS, COMPONENTS, STRIPS, CW, TEXT, t, render, component, overview, scale, clearCache: () => cache.clear() };
})(typeof window !== "undefined" ? window : globalThis);
