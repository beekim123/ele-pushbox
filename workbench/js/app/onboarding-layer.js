/* UX-03 · Onboarding layer of the workbench level page (views/scenes.js).
 * docs/design/onboarding.md §2–4, §7, §8. With 引导 on, a level that has
 * onboarding data is played live (keyboard and mouse, on the grid rule model)
 * and the layer draws over PB.scene.renderLevel: key hints, empty sockets
 * breathing, light dots flying to the goal lamps, things flashing together,
 * plate-to-door light, thoughts, dead-end and stuck reminders.
 * Data: PB_BUNDLE.onboarding (content/onboarding/*.json, added to the bundle by
 * tools/art.mjs build); text: content/i18n-onboarding through PB.i18n; drawing:
 * PB.onbFx (workbench/js/core/onboarding-fx.js).
 * The game keeps learned / said / seen in the save; the workbench keeps them for
 * the session (重看引导 clears them). Not here: rule cards, the 7-day review strip. */
(function (root) {
  "use strict";
  const PB = root.PB, el = root.PBStage.el;
  const TM = () => PB.tilemodel, FX = () => PB.onbFx;

  // Times and counts (seconds), onboarding.md §2–4.
  const N = {
    hintAt: 1, fadeIn: 0.15, fadeOut: 0.3, stand: 2, idle: 45,
    thinkAt: 0.5, thinkFor: 10, trapFor: 8, typing: 30,
    flashAt: 0.5, dot: 0.5, lamp: 0.15, link: 0.6, grain: 0.4,
    stuckBlocked: 3, stuckMax: 2, pulses: 1.2, trapSays: 2,
    altFor: 5, shake: 0.4, pose: 0.3, undoRepeat: 0.12,
  };
  const DEVICES = [["mac", "Mac"], ["pc", "PC"], ["mouse", "鼠标"], ["alt", "备选按法"]];
  const isMac = () => /mac|iphone|ipad/i.test((root.navigator && (root.navigator.platform || root.navigator.userAgent)) || "");
  const pref = { on: true, device: isMac() ? "mac" : "pc" };
  const freshMemory = () => ({ learned: {}, said: {}, seen: {}, undoTold: false, stuckTold: false, dug: false });
  let mem = freshMemory(), stage = null, spec = null, V = null, blurred = false, ui = null;

  const dataOf = (id) => ((root.PB_BUNDLE && root.PB_BUNDLE.onboarding) || {})[id] || null;
  const hasData = (lv) => !!(lv && dataOf(lv.id));
  function devMethod() {
    if (pref.device === "alt") return { dev: isMac() ? "mac" : "pc", method: "alt" };
    return { dev: pref.device, method: "hold" };
  }
  // "新局面": player, crates, terrain and bag (onboarding.md §4).
  function posKey(s) {
    return s.player.x + "," + s.player.y + "|" + s.crates.map((c) => c.x + "," + c.y).sort().join(";") + "|" + s.terrain.join("") + "|" + s.bag.sand + "," + s.bag.bomb;
  }
  const actOfKind = (k) => (k === "walk" || k === "push" || k === "step" ? "move" : k);
  const actOfAction = (a) => (a === "L" || a === "R" ? "move" : a === "U" || a === "D" ? "climb" : a.split("_")[0].toLowerCase());
  const dirOfAction = (a) => { const m = /_([LRD])$/.exec(a); return m ? m[1].toLowerCase() : a === "U" ? "u" : a === "D" ? "d" : "lr"; };
  const TERRAIN_OF = { dirt: "EARTH", earth: "EARTH", sand: "SAND" };

  // ---------------------------------------------------------------- one visit of a level
  function startVisit(lv) {
    const { level, state } = TM().parse(lv);
    V = {
      L: level, s: state, start: TM().clone(state), history: [], data: dataOf(lv.id),
      ox: (320 - level.w * 16) >> 1, oy: 20 + ((160 - level.h * 16) >> 1),
      clock: 0, lastTick: null, lastUndoAt: -1,
      pose: "idle", poseAt: -9, facing: "right", won: TM().won(level, state),
      seen: new Set([posKey(state)]), lastNew: 0, posSince: 0, idleFired: false,
      blocked: 0, blockedBy: null, stuck: 0, stuckArmed: true, pulseAt: -9,
      hints: [], khState: new Map(), reshown: {}, done: new Set(),
      think: null, startSaid: false, trapAt: {}, trapSaid: {}, trapGlow: null,
      fx: [], flashes: [], alt: null, hover: null,
    };
    // First appearance (once a session): socket + goal lamp, plate + door symbols.
    const sockets = TM().goals(level, state).some((g) => g.kind === "socket");
    if (sockets && !mem.seen.socket) { mem.seen.socket = true; V.flashes.push("socket"); }
    if (level.plates.length && level.doors.length && !mem.seen.plate) { mem.seen.plate = true; V.flashes.push("plate"); }
  }
  const now = () => V.clock;

  function say(key, o) {
    if (!PB.i18n.has(key)) return;
    V.think = { key, t0: now(), until: now() + (o.for || N.thinkFor), kind: o.kind, all: false };
    V.blocked = 0;
  }
  function showHint(h, cell) {
    const one = { act: h.act, dir: h.dir || "lr", at: h.at || "player", done: h.done, cell: cell || null, t0: now(), t1: null, src: h.src || "data" };
    V.hints.push(one);
    V.blocked = 0;
    return one;
  }
  function hintDone(h, kind) {
    if (h.done) return h.done === kind;
    return actOfKind(kind) === h.act;
  }

  // ---------------------------------------------------------------- timers (run on every frame)
  function cellIs(x, y, name) {
    const t = TM().T[TERRAIN_OF[name] || ""];
    return t !== undefined && x >= 0 && y >= 0 && x < V.L.w && y < V.L.h && V.s.terrain[y * V.L.w + x] === t;
  }
  function markerNear(kind) {
    const M = TM().M[kind.toUpperCase()], p = V.s.player;
    let best = null;
    for (let i = 0; i < V.L.w * V.L.h; i++) {
      if (V.L.marker[i] !== M) continue;
      const x = i % V.L.w, y = (i / V.L.w) | 0, d = Math.abs(x - p.x) * 2 + Math.abs(y - p.y);
      if (!best || d < best.d) best = { x, y, d };
    }
    return best;
  }
  function wants(kh) {
    const show = kh.show || "start", p = V.s.player;
    if (now() < N.hintAt) return null;   // nothing before 1 s after the fade-in
    if (show === "start") return {};
    let m = /^near:(\w+)$/.exec(show);
    if (m) { const c = markerNear(m[1]); return c && Math.abs(c.x - p.x) <= 1 && c.y === p.y ? {} : null; }
    m = /^blocked:(\w+)$/.exec(show);
    if (m) {
      if (V.blockedBy && V.blockedBy.what === m[1]) return { cell: V.blockedBy.cell };
      for (const dx of [-1, 1]) if (cellIs(p.x + dx, p.y, m[1]) && now() - V.posSince >= N.stand) return { cell: { x: p.x + dx, y: p.y } };
    }
    return null;
  }
  function update() {
    const t = now(), D = V.data || {};
    // Thought at the start (M01, M04): 0.5 s after the level fades in.
    if (!V.startSaid && D.say_start && t >= N.thinkAt) {
      V.startSaid = true;
      if (!mem.said[D.say_start]) { mem.said[D.say_start] = true; say(D.say_start, { kind: "start" }); }
    }
    if (V.think && t >= V.think.until) V.think = null;
    // Key hints from the level data.
    for (const kh of D.keyhints || []) {
      const on = V.khState.get(kh);
      if (on && /^near:/.test(kh.show || "") && on.t1 == null && !wants(kh)) { on.t1 = t; V.khState.delete(kh); continue; }   // walked away: fade, may come back
      if (on || mem.learned[kh.act]) continue;
      const w = wants(kh);
      if (w) V.khState.set(kh, showHint(kh, w.cell));
    }
    V.hints = V.hints.filter((h) => h.t1 == null || t - h.t1 < N.fadeOut);
    // 45 s without a new position: show again the key of an action the solution
    // needs and this visit has not done (once per action), else the stuck reminder.
    if (!V.idleFired && t - V.lastNew >= N.idle && !V.won) {
      V.idleFired = true;
      const need = (V.data && specActs()) || [];
      const next = need.find((a) => !V.done.has(a.act) && !V.reshown[a.act] && !V.hints.some((h) => h.act === a.act && h.t1 == null));
      if (next) {
        V.reshown[next.act] = true;
        const kh = (D.keyhints || []).find((k) => k.act === next.act);
        showHint({ act: next.act, dir: kh ? kh.dir : next.dir, at: kh ? kh.at : "player", src: "idle" });
      } else stuck();
    }
    if (V.alt && t - V.alt.t0 >= N.altFor) V.alt = null;
    if (V.trapGlow && V.trapGlow !== posKey(V.s)) V.trapGlow = null;
    V.fx = V.fx.filter((f) => t - f.t0 < f.life);
  }
  function specActs() {
    const out = [], seen = new Set();
    for (const a of spec.solution || []) { const act = actOfAction(a); if (!seen.has(act)) { seen.add(act); out.push({ act, dir: dirOfAction(a) }); } }
    return out;
  }
  // Generic "stuck" (3 blocked moves in a row, or 45 s without a new position):
  // undo and hint glow, two pulses; at most twice a level; a new position re-arms it.
  function stuck() {
    if (!V.stuckArmed || V.stuck >= N.stuckMax) return;
    V.stuck++; V.stuckArmed = false; V.pulseAt = now();
    if (!mem.stuckTold) { mem.stuckTold = true; say("onb.say.stuck_hint", { kind: "stuck" }); }
  }

  // ---------------------------------------------------------------- playing
  const POSE = { push: "push", dig: "dig", pour: "pour", climb: "climb", walk: "walk", step: "walk" };
  function play(a) {
    if (V.won) return null;
    if (/[LR]$/.test(a)) V.facing = /L$/.test(a) ? "left" : "right";
    const before = V.s, next = TM().clone(before), res = TM().act(V.L, next, a);
    if (!res.ok) { blockedBy(a, res); return res; }
    V.history.push(before); V.s = next;
    V.pose = POSE[res.kind] || "idle"; V.poseAt = now();
    V.done.add(actOfKind(res.kind));
    for (const h of V.hints) if (h.t1 == null && hintDone(h, res.kind)) { h.t1 = now(); mem.learned[h.act] = true; }
    if (V.think && V.think.kind === "start" && (res.kind === "push" || res.kind === "step")) V.think = null;
    V.blocked = 0;
    effects(a, res, before, next);
    moved(before);
    return res;
  }
  function blockedBy(a, res) {
    if (a !== "L" && a !== "R") return;
    const p = V.s.player, x = p.x + (a === "L" ? -1 : 1);
    for (const what of Object.keys(TERRAIN_OF)) if (cellIs(x, p.y, what)) { V.blockedBy = { what, cell: { x, y: p.y } }; break; }
    if (++V.blocked >= N.stuckBlocked) { V.blocked = 0; stuck(); }
  }
  // After the state changed (move, undo, restart): new position, traps, win.
  function moved(before) {
    const k = posKey(V.s);
    if (!before || before.player.x !== V.s.player.x || before.player.y !== V.s.player.y) V.posSince = now();
    if (!V.seen.has(k)) { V.seen.add(k); V.lastNew = now(); V.stuckArmed = true; V.idleFired = false; }
    V.won = TM().won(V.L, V.s);
    traps();
  }
  // Dead ends and wrong moves from the level data: think at once and light the
  // undo icon until the position changes; at most twice per trap per visit.
  function traps() {
    const s = V.s, at = (list, test) => (list || []).some(([x, y]) => test(x, y));
    for (const tr of (V.data && V.data.traps) || []) {
      const w = tr.when || {};
      let hold = true;
      if (w.crate_at) hold = hold && at(w.crate_at, (x, y) => !!TM().crateAt(s, x, y));
      if (w.sand_at) hold = hold && at(w.sand_at, (x, y) => s.terrain[y * V.L.w + x] === TM().T.SAND);
      if (w.no_sand_at) hold = hold && !at(w.no_sand_at, (x, y) => s.terrain[y * V.L.w + x] === TM().T.SAND);
      if (w.bag !== undefined) hold = hold && s.bag.sand === w.bag;
      if (!hold) { V.trapAt[tr.id] = null; continue; }
      if (V.trapAt[tr.id]) continue;
      V.trapAt[tr.id] = true; V.trapGlow = posKey(s);
      V.trapSaid[tr.id] = (V.trapSaid[tr.id] || 0) + 1;
      if (V.trapSaid[tr.id] <= N.trapSays && tr.say) say(tr.say, { kind: "trap", for: N.trapFor });
    }
  }
  function effects(a, res, before, after) {
    const t = now(), L = V.L;
    // A crate into a socket: the light dot flies to its lamp, the lamp flashes.
    const g0 = TM().goals(L, before), g1 = TM().goals(L, after);
    g1.forEach((g, i) => { if (g.kind === "socket" && g.lit && g0[i] && !g0[i].lit) V.fx.push({ kind: "dot", i, n: g1.length, x: g.x, y: g.y, t0: t, life: N.dot + N.lamp }); });
    // A door opened by its plate: plate-to-door light (group 1: every time).
    for (const i of L.doors) {
      if (!TM().doorClosed(L, before, i) || TM().doorClosed(L, after, i)) continue;
      const grp = L.groups[L.doorAt.get(i)];
      for (const p of (grp && grp.plates) || []) {
        const px = p % L.w, py = (p / L.w) | 0, crate = TM().crateAt(after, px, py);
        if (!crate && !(after.player.x === px && after.player.y === py)) continue;
        V.fx.push({ kind: "link", from: p, to: i, t0: t, life: N.link });
        if (crate && !mem.said["onb.say.m05_cause"]) { mem.said["onb.say.m05_cause"] = true; say("onb.say.m05_cause", { kind: "cause" }); }
      }
    }
    // The first dig ever: a grain flies into the sandbag.
    if (res.kind === "dig" && !mem.dug) {
      mem.dug = true;
      const d = { DIG_L: [-1, 0], DIG_R: [1, 0], DIG_D: [0, 1] }[a];
      V.fx.push({ kind: "grain", x: before.player.x + d[0], y: before.player.y + d[1], bag: after.bag.sand - 1, t0: t, life: N.grain });
    }
  }
  function undo(repeat) {
    const t = performance.now() / 1000;
    if (repeat && t - V.lastUndoAt < N.undoRepeat) return;
    if (!V.history.length) return;
    V.lastUndoAt = t;
    const before = V.s;
    V.s = V.history.pop(); V.pose = "idle";
    if (V.think && V.think.kind === "trap") V.think = null;
    moved(before);
    if (!mem.undoTold) { mem.undoTold = true; say("onb.say.undo_hold", { kind: "undo" }); }
  }
  function restart() {
    const before = V.s;
    V.history.push(before); V.s = TM().clone(V.start); V.pose = "idle"; V.alt = null;
    if (V.think && V.think.kind === "trap") V.think = null;
    moved(before);
  }
  // Alternative keys (§7): X / C / B, then a direction. The same letter, Esc or
  // 5 s cancel; C with an empty bag does not start.
  const ALT_OF = { x: "dig", c: "pour", b: "bomb" };
  function altKey(k) {
    const kind = ALT_OF[k];
    if (V.alt && V.alt.kind === kind) { V.alt = null; return; }
    if ((kind === "pour" && V.s.bag.sand < 1) || (kind === "bomb" && V.s.bag.bomb < 1)) return;
    V.alt = { kind, t0: now(), shake: -9 };
  }
  function arrow(d, e) {
    const D = { left: "L", right: "R", up: "U", down: "D" }[d];
    if (V.alt) {
      const kind = V.alt.kind;
      if (!FX().WAIT_DIRS[kind].includes(D.toLowerCase())) { V.alt.shake = now(); return; }
      const res = play(kind.toUpperCase() + "_" + D);
      if (res && res.ok) V.alt = null; else V.alt.shake = now();
      return;
    }
    if (e.shiftKey) { if (D !== "U") play("DIG_" + D); return; }
    if (e.ctrlKey || e.metaKey) { if (D === "L" || D === "R") play("POUR_" + D); return; }
    play(D);
  }

  // ---------------------------------------------------------------- keyboard and mouse
  function active() {
    if (!pref.on || !V || !stage || !stage.canvas.isConnected || document.hidden) return false;
    const sec = document.getElementById("view-scenes");
    return !sec || !sec.hidden;
  }
  function onKey(e) {
    if (!active()) return;
    const tg = e.target, tag = (tg && tg.tagName) || "";
    if (tag === "INPUT" || tag === "SELECT" || tag === "TEXTAREA" || (tg && tg.isContentEditable)) return;
    const k = e.key, before = V.think;
    if ((k === "Enter" || k === " ") && tag === "BUTTON") return;
    if ((e.ctrlKey || e.metaKey) && !/^Arrow/.test(k)) return;   // browser shortcuts stay
    if (k === "Escape" && (V.alt || V.think)) { if (V.alt) V.alt = null; else V.think = null; }
    else if (k === "Enter" && V.think) V.think = null;
    else if (/^Arrow(Left|Right|Up|Down)$/.test(k)) arrow(k.slice(5).toLowerCase(), e);
    else if (k === "z" || k === "Z") undo(e.repeat);
    else if ((k === "r" || k === "R") && !e.repeat) restart();
    else if (/^[xcbXCB]$/.test(k) && !e.repeat) altKey(k.toLowerCase());
    else return;
    e.preventDefault(); e.stopPropagation();
    if (before && V.think === before) before.all = true;   // any key shows the whole thought
    if (!stage.playing()) stage.setPlaying(true);
    stage.refresh();
  }
  // Mouse (§7): left click digs a neighbouring dirt or sand cell, right click pours
  // into a neighbouring empty cell; hovering shows what the click would do.
  function cellOfEvent(e) {
    const b = stage.canvas.getBoundingClientRect();
    const x = ((e.clientX - b.left) * 320) / b.width, y = ((e.clientY - b.top) * 180) / b.height;
    return { x: Math.floor((x - V.ox) / 16), y: Math.floor((y - V.oy) / 16) };
  }
  function hoverAt(c) {
    const p = V.s.player, dx = c.x - p.x, dy = c.y - p.y, T = TM().T;
    const dir = dy === 0 && dx === -1 ? "L" : dy === 0 && dx === 1 ? "R" : dx === 0 && dy === 1 ? "D" : null;
    if (!dir || c.x < 0 || c.y < 0 || c.x >= V.L.w || c.y >= V.L.h) return null;
    const t = V.s.terrain[c.y * V.L.w + c.x];
    if (t === T.EARTH || t === T.SAND) return { kind: "dig", button: "mouse_l", action: "DIG_" + dir, x: c.x, y: c.y };
    if (dir !== "D" && V.s.bag.sand > 0) {
      const probe = TM().clone(V.s);
      if (TM().act(V.L, probe, "POUR_" + dir).ok) return { kind: "pour", button: "mouse_r", action: "POUR_" + dir, x: c.x, y: c.y };
    }
    return null;
  }
  function mouse(canvas) {
    const refresh = () => stage && stage.refresh();
    canvas.addEventListener("mousemove", (e) => { if (!active()) return; V.hover = hoverAt(cellOfEvent(e)); refresh(); });
    canvas.addEventListener("mouseleave", () => { if (V) { V.hover = null; refresh(); } });
    canvas.addEventListener("mousedown", (e) => {
      if (!active() || e.button !== 0) return;
      const h = hoverAt(cellOfEvent(e));
      if (h && h.kind === "dig") { play(h.action); V.hover = hoverAt(cellOfEvent(e)); refresh(); }
    });
    canvas.addEventListener("contextmenu", (e) => {
      if (!active()) return;
      e.preventDefault();
      const h = hoverAt(cellOfEvent(e));
      if (h && h.kind === "pour") { play(h.action); V.hover = hoverAt(cellOfEvent(e)); refresh(); }
    });
  }
  if (root.addEventListener) {
    root.addEventListener("keydown", onKey, true);
    root.addEventListener("blur", () => { blurred = true; });
    root.addEventListener("focus", () => { blurred = false; });
  }

  // ---------------------------------------------------------------- drawing
  // HUD sandbag i (scene.js drawHud: lamps, then bombs, then up to 3 bags right to left).
  function bagX(i) {
    const s = V.s, n = TM().goals(V.L, s).length;
    let rx = 256 - 10 * n - 6;
    if (s.bag.bomb > 0) { rx -= 16; if (s.bag.bomb > 1) rx -= 12; rx -= 2; }
    const canDig = spec.map.some((row) => /[es]/.test(row));
    const shown = Math.min(3, Math.max(s.bag.sand, (spec.bag && spec.bag.sand) || 0, canDig ? 1 : 0));
    if (s.bag.sand > 3) rx -= 14;
    return rx - 15 * (shown - Math.max(0, Math.min(shown - 1, i)));
  }
  const cellX = (x) => V.ox + x * 16, cellY = (y) => V.oy + y * 16;
  // Where a hint goes: above its cell (on the wall for blocked:dirt), under the
  // HUD for the sandbag; under the cell when the HUD is in the way.
  function hintRect(h, sz) {
    let cx, top;
    if (h.at === "bag") { cx = bagX(0) + 8; return { x: clampX(cx - (sz.w >> 1), sz.w), y: 22 }; }
    let c = h.at === "player" ? V.s.player : h.cell;
    if (!c && h.at !== "player") c = markerNear(h.at) || V.s.player;
    cx = cellX(c.x) + 8; top = cellY(c.y);
    let y = top - 2 - sz.h;
    if (y < 21) y = top + 18;
    return { x: clampX(cx - (sz.w >> 1), sz.w), y };
  }
  const clampX = (x, w) => Math.max(2, Math.min(318 - w, x));
  function drawHint(r, h, t) {
    const F = FX(), { dev, method } = devMethod(), items = F.hintItems(h.act, h.dir, dev, method);
    const sz = F.hintSize(r, items), at = hintRect(h, sz);
    let alpha = Math.min(1, (t - h.t0) / N.fadeIn);
    if (h.t1 != null) alpha = Math.min(alpha, 1 - (t - h.t1) / N.fadeOut);
    h.rect = { x: at.x, y: at.y, w: sz.w, h: sz.h };
    F.faded(r, alpha, h.rect, (q) => F.keyhint(q, at.x, at.y, items, { t: t - h.t0 }));
  }
  function waitDirs(kind) {
    return FX().WAIT_DIRS[kind].filter((d) => { const n = TM().clone(V.s); return TM().act(V.L, n, kind.toUpperCase() + "_" + d.toUpperCase()).ok; });
  }
  function glowLevels(t) {
    const F = FX(), pulse = F.twoPulses(t - V.pulseAt);
    return { undo: Math.max(V.trapGlow ? 0.6 + 0.4 * F.breath(t, 1.2) : 0, pulse), hint: pulse };
  }
  function draw(r, tick, o) {
    if (V.lastTick == null || tick < V.lastTick) V.lastTick = tick;
    const dt = Math.min(0.25, (tick - V.lastTick) / 60);
    V.lastTick = tick;
    if (!blurred) V.clock += dt;
    update();
    const F = FX(), t = now(), L = V.L, s = V.s, S = PB.sprites, sym = (i) => (L.symbol && L.symbol[i]) || 0;
    const pose = V.won ? "win" : t - V.poseAt < N.pose ? V.pose : "idle";
    PB.scene.renderLevel(r, spec, { level: L, state: s }, Object.assign({ tick, pose, facing: V.facing }, o || {}));
    const goals = TM().goals(L, s), steady = !!(o && o.env === "off");
    // Empty sockets breathe (steady with environment effects off).
    for (const g of goals) if (g.kind === "socket" && !g.lit && !(s.player.x === g.x && s.player.y === g.y)) F.socketGlow(r, cellX(g.x) + 8, cellY(g.y) + 16, steady ? 0.7 : F.breath(t), tick);
    // First appearance: flash twice together.
    if (F.flashOn(t - N.flashAt)) for (const what of V.flashes) {
      if (what === "socket") goals.forEach((g, i) => {
        if (g.kind !== "socket") return;
        if (!g.lit) F.flashSprite(r, "mech.socket", "idle", tick, cellX(g.x) + 8, cellY(g.y) + 16);
        F.outline(r, F.spriteAt("ui.goal_lamp", g.lit ? 1 : 0, 0, F.lampX(i, goals.length), 5), "t");
      });
      if (what === "plate") {
        for (const i of L.plates) {
          const x = cellX(i % L.w) + 8, y = cellY((i / L.w) | 0) + 16, px = i % L.w, py = (i / L.w) | 0;
          const pressed = (s.player.x === px && s.player.y === py) || !!TM().crateAt(s, px, py);
          F.flashSprite(r, "mech.plate", pressed ? "down" : "up", 0, x, y);
          if (!pressed) F.flashSprite(r, "mech.link_symbol", sym(i), 0, x, y - 7);
        }
        for (const i of L.doors) F.flashSprite(r, "mech.link_symbol", sym(i), 0, cellX(i % L.w) + 8, cellY((i / L.w) | 0) + 4);
      }
    }
    // Light dots, lamp flashes, plate-to-door light, the first grain of sand.
    for (const f of V.fx) {
      const e = t - f.t0;
      if (f.kind === "dot") {
        if (e < N.dot) {
          S.draw(r, "ui.goal_lamp", 0, 0, F.lampX(f.i, f.n), 5);   // the lamp lights when the dot lands
          F.lightDot(r, cellX(f.x) + 8, cellY(f.y) + 10, F.lampX(f.i, f.n) + 4, 9, e / N.dot);
        } else F.lampFlash(r, f.i, f.n);
      } else if (f.kind === "link") {
        F.causeLine(r, cellX(f.from % L.w) + 8, cellY((f.from / L.w) | 0) + 12, cellX(f.to % L.w) + 8, cellY((f.to / L.w) | 0) + 8, e / N.link);
      } else if (f.kind === "grain") {
        const bx = bagX(f.bag), u = 1 - Math.pow(1 - Math.min(1, e / N.grain), 2);
        S.draw(r, "item.sandbag", 1, 0, bx, 2);
        const x0 = cellX(f.x) + 8, y0 = cellY(f.y) + 8, x1 = bx + 8, y1 = 10;
        const gx = Math.round(x0 + (x1 - x0) * u), gy = Math.round(y0 + (y1 - y0) * u - Math.sin(Math.PI * u) * 10);
        r.rect(gx - 1, gy - 1, 3, 3, "z"); r.set(gx, gy, "c"); r.set(gx - 1, gy, "d"); r.set(gx, gy - 1, "c");
      }
    }
    const glow = glowLevels(t);
    F.hudGlow(r, "undo", glow.undo); F.hudGlow(r, "hint", glow.hint);
    if (V.hover) F.hover(r, V.hover.kind, cellX(V.hover.x), cellY(V.hover.y), V.hover.button);
    const hx = cellX(s.player.x) + 8, top = cellY(s.player.y);
    if (V.alt) F.waiting(r, V.alt.kind, hx, top - 2, t - V.alt.t0, { dirs: waitDirs(V.alt.kind), shake: t - V.alt.shake < N.shake, no: t - V.alt.shake < N.shake });
    for (const h of V.hints) drawHint(r, h, t);
    if (V.think) {
      const { dev, method } = devMethod(), c = new PB.uk.C(r);
      const lay = F.layoutThought(c, PB.i18n.t(V.think.key), { device: dev, method });
      let over = top - (V.alt ? 12 : 0);   // above the waiting icon and above key hints over the hero
      for (const h of V.hints) if (h.rect && h.rect.y < top && h.rect.x < hx + 24 && h.rect.x + h.rect.w > hx - 24) over = Math.min(over, h.rect.y - 1);
      const at = F.thoughtPlace(lay, hx, over, top + 16);
      F.thought(r, lay, at.x, at.y, at.tx, { below: at.below, reveal: V.think.all ? null : Math.floor((t - V.think.t0) * N.typing) });
    }
  }

  // ---------------------------------------------------------------- the page
  function syncSteps() {
    const box = document.getElementById("scene-steps");
    if (box) box.hidden = !!(pref.on && spec);
  }
  function controls(lv) {
    if (!hasData(lv)) return [];
    const refresh = () => stage && stage.refresh();
    const toggle = el("button", { class: "btn", type: "button", id: "onb-toggle", "aria-pressed": String(pref.on), text: "引导",
      title: "新手引导：方向键走 / 推，Shift / Ctrl / ⌘ + 方向挖和倒沙，Z 撤销，R 重开（onboarding.md）",
      onclick: () => { pref.on = !pref.on; toggle.setAttribute("aria-pressed", String(pref.on)); if (pref.on && spec) startVisit(spec); syncSteps(); refresh(); } });
    const dev = el("select", { id: "onb-device", "aria-label": "引导的按键提示", onchange: () => { pref.device = dev.value; refresh(); } });
    for (const [v, n] of DEVICES) dev.append(el("option", { value: v, text: n }));
    dev.value = pref.device;
    const ff = el("button", { class: "btn", type: "button", id: "onb-ff", text: "快进 45 秒", title: "把「没有新局面」的计时往前拨 45 秒",
      onclick: () => { if (V) { V.lastNew -= N.idle; V.posSince -= N.idle; } refresh(); } });
    const again = el("button", { class: "btn", type: "button", id: "onb-reset", text: "重看引导", title: "忘掉这次会话里学会的、说过的、见过的，从头玩这一关",
      onclick: () => { mem = freshMemory(); if (spec) startVisit(spec); refresh(); } });
    return [toggle, el("label", { class: "small muted" }, ["设备 ", dev]), ff, again];
  }
  function attach(lv, st) {
    stage = st; spec = hasData(lv) ? lv : null; V = null;
    if (spec) { startVisit(spec); if (st) mouse(st.canvas); }
    syncSteps();
  }
  const keysText = (items) => items.map((it) => it.key || (it.sep === "plus" ? "+" : it.sep === "slash" ? "/" : it.sep === "then" ? ">" : it.icon)).join(" ");
  function snapshot() {
    if (!V || !spec) return { on: pref.on, level: null };
    const { dev, method } = devMethod();
    return {
      on: pref.on, device: pref.device, level: spec.id, clock: V.clock, player: [V.s.player.x, V.s.player.y], won: V.won,
      hints: V.hints.map((h) => ({ act: h.act, dir: h.dir, at: h.at, fading: h.t1 != null, keys: keysText(FX().hintItems(h.act, h.dir, dev, method)), rect: h.rect || null })),
      think: V.think && { key: V.think.key, kind: V.think.kind }, glow: glowLevels(V.clock), fx: V.fx.map((f) => f.kind), alt: V.alt && V.alt.kind,
    };
  }

  root.PBOnboarding = { controls, attach, on: () => !!(pref.on && spec && V), draw: (r, tick, o) => { if (V) draw(r, tick, o); }, snapshot, N };
})(window);
