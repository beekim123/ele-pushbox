/* Real-time rules of the delivery mode (docs/design/delivery-realtime.md).
 *
 * Design model, not the SDK: the world advances in fixed logic ticks (60 per
 * second). The player moves tile by tile and waits out a move interval after
 * every action; gravity moves loose things one tile every few ticks; monsters
 * patrol, chase, steal, get pushed, crushed, buried and trapped. Everything is
 * integer and processed in a fixed order, so the same inputs always give the
 * same run: the game's port is checked against recorded replays
 * (content/export/delivery-golden.json).
 *
 * Tile rules follow the lab rules (game-design.md §4, tilemodel.js) for push,
 * step-up, ladders, digging, pouring, plates and doors; sand is a whole tile
 * that falls straight down, as in the lab model. Water, fire and gases are not
 * part of this model (the first slice has none).
 * Shared by the workbench (browser, classic script) and the Node tools.
 */
(function (root) {
  "use strict";
  const PB = (root.PB = root.PB || {});
  const TM = () => PB.tilemodel, R = () => PB.rooms;

  // ---------- parameters (seconds in the catalogs, ticks here) ----------
  function ticks(sec, hz) { return Math.round(sec * hz); }
  function params(slice) {
    const hz = slice.time.tick_hz, iv = slice.intervals, P = slice.player, t = (s) => ticks(s, hz);
    return {
      hz,
      act: { walk: t(iv.walk), step: t(iv.walk), climb: t(iv.climb || iv.walk), push: t(iv.push), dig: t(iv.dig), pour: t(iv.pour), interact: t(iv.interact), use: t(iv.interact) },
      moveAnim: t(iv.move_anim),
      fall: Math.max(1, Math.round(hz / slice.gravity.tiles_per_sec)),
      hearts: P.hearts, iframes: t(P.iframe_secs), fallHurt: P.fall_hurt_rows, sandMax: P.sand_max, slots: P.item_slots,
      monsterKo: slice.monster_fall_ko_rows, integrity: slice.cargo_integrity, coin: slice.coins.pickup,
      transition: t(slice.time.transition_secs),
    };
  }
  function monsterParams(entry, hz) {
    const p = entry.params || {}, t = (s) => ticks(s, hz);
    return { id: entry.id, pushable: !!entry.pushable, move: p.move || "patrol", step: t(p.step_secs || 0.5), chaseStep: t(p.chase_step_secs || p.step_secs || 0.5),
      sight: p.sight_tiles || 0, cliff: p.cliff_rows || 2, contact: p.contact || "hurt", stealSand: p.steal_sand || 0, stealCoins: p.steal_coins || 0,
      flee: t(p.flee_secs || 0), fleeStep: t(p.flee_step_secs || p.step_secs || 0.5), stun: t(p.push_stun_secs || 0), trap: t(p.trap_secs || 3), coins: p.coins || 0 };
  }

  // ---------- one room ----------
  // ctx: {slice, P, monsters: Map(id -> entry), recipient (entry or null)}
  function makeRoom(ctx, t, mirror, open, opts) {
    const o = opts || {}, Rr = R(), v = Rr.variant(t, mirror, open), W = Rr.W, H = Rr.H;
    const exits = new Set(), exitAt = new Map();
    for (const e of Rr.EDGES) if (v.exits[e]) for (const [x, y] of Rr.exitCells(e, v.exits[e])) { exits.add(y * W + x); exitAt.set(y * W + x, { edge: e, slot: v.exits[e] }); }
    // The tile model wants exactly one player: park one on a free cell, then drop it.
    const spot = v.spawns.find((s) => s.feature === "gate") || (() => { for (const e of Rr.EDGES) if (v.exits[e]) { const [x, y] = Rr.entryCell(e, v.exits[e]); return { x, y }; } return { x: 1, y: 7 }; })();
    const rows = v.rows.map((r) => [...r]);
    rows[spot.y][spot.x] = rows[spot.y][spot.x] === "H" ? "h" : "P";
    const parsed = TM().parse({ id: v.id, map: rows.map((r) => r.join("")), bag: { sand: 0, bomb: 0 }, links: v.links });
    const L = parsed.level, s = parsed.state;
    const room = {
      id: t.id, type: t.type, mirror: !!mirror, open: Object.assign({}, open), v, W, H, L, t: 0,
      terrain: s.terrain.slice(), doors: s.open.slice(), crates: s.crates.map((c, i) => ({ n: i, x: c.x, y: c.y, kind: c.kind, fallT: 0, rows: 0 })),
      sandFall: new Map(), climb: new Set(), exits, exitAt,
      monsters: [], pickups: v.coins.map(([x, y]) => ({ x, y, kind: "coin", value: ctx.P.coin })),
      gate: null, keeper: null, recipient: null, hot: false,
    };
    v.spawns.forEach((sp) => {
      if (sp.monster) {
        const mp = monsterParams(ctx.monsters.get(sp.monster), ctx.P.hz);
        room.monsters.push({ n: room.monsters.length, id: sp.monster, M: mp, x: sp.x, y: sp.y, dir: sp.dir === "left" ? -1 : 1, state: "walk", cd: mp.step, until: 0, fallT: 0, rows: 0, carry: { sand: 0, coins: 0 }, ko: false });
      } else if (sp.feature === "gate") room.gate = { x: sp.x, y: sp.y };
      else if (sp.feature === "keeper") room.keeper = { x: sp.x, y: sp.y, talked: false, healed: false, stock: Object.assign({}, (ctx.slice.station || {}).stock || {}) };
      else if (sp.feature === "recipient" && ctx.recipient) {
        const p = ctx.recipient.params || {};
        // A wandering recipient starts walking towards the middle of the room (mirror-safe).
        room.recipient = { id: ctx.recipient.id, x: sp.x, y: sp.y, dir: sp.x < W / 2 ? 1 : -1, move: p.move || "stay", step: ticks(p.step_secs || 0.8, ctx.P.hz), cd: ticks(p.step_secs || 0.8, ctx.P.hz), fallT: 0, rows: 0 };
        room.hot = !!p.home_melt_mult;
      }
    });
    return room;
  }

  // A lab level spec as a room without exits (for comparing the real-time rules
  // with the lab tile model: given time to settle, both must agree).
  function roomFromSpec(ctx, spec) {
    const parsed = TM().parse(spec), L = parsed.level, s = parsed.state;
    const room = { id: spec.id, type: "lab", mirror: false, open: {}, v: { id: spec.id, rows: spec.map, spawns: [], coins: [], exits: {}, world: spec.chapter }, W: L.w, H: L.h, L, t: 0,
      terrain: s.terrain.slice(), doors: s.open.slice(), crates: s.crates.map((c, i) => ({ n: i, x: c.x, y: c.y, kind: c.kind, fallT: 0, rows: 0 })),
      sandFall: new Map(), climb: new Set(), exits: new Set(), exitAt: new Map(), monsters: [], pickups: [], gate: null, keeper: null, recipient: null, hot: false };
    const run = newRun(ctx, { sand: (spec.bag && spec.bag.sand) || 0 });
    enter(run, room, s.player.x, s.player.y, 1);
    return run;
  }

  // ---------- predicates ----------
  const idx = (rm, x, y) => y * rm.W + x;
  const inside = (rm, x, y) => x >= 0 && y >= 0 && x < rm.W && y < rm.H;
  function doorClosed(rm, x, y) { const g = rm.L.doorAt.get(idx(rm, x, y)); return g !== undefined && !rm.doors[g]; }
  function terr(rm, x, y) { return inside(rm, x, y) ? rm.terrain[idx(rm, x, y)] : TM().T.ROCK; }
  // Solid ground: anything but open air (and water, acid, gas in later regions), or a closed door.
  function solid(rm, x, y) { if (!inside(rm, x, y)) return true; const t = terr(rm, x, y), T = TM().T; return doorClosed(rm, x, y) || !(t === T.EMPTY || t === T.WATER || t === T.ACID || t === T.SMOKE || t === T.FOG); }
  const isSand = (rm, x, y) => terr(rm, x, y) === TM().T.SAND;
  const ladder = (rm, x, y) => inside(rm, x, y) && (rm.L.marker[idx(rm, x, y)] === TM().M.LADDER || rm.climb.has(idx(rm, x, y)));
  const isExit = (rm, x, y) => rm.exits.has(idx(rm, x, y));
  const crateAt = (rm, x, y) => rm.crates.find((c) => c.x === x && c.y === y) || null;
  const monsterAt = (rm, x, y) => rm.monsters.find((m) => !m.ko && m.x === x && m.y === y) || null;
  // The recipient is a body (touching him delivers); the station keeper stands in the background like the gate.
  function npcAt(rm, x, y) { const r = rm.recipient; return r && r.x === x && r.y === y ? r : null; }
  const playerAt = (rm, x, y) => !!rm.player && rm.player.x === x && rm.player.y === y;

  // Who may enter a cell. Exit cells take only the player; monsters also keep out of ladders.
  function freeForPlayer(rm, x, y) { return inside(rm, x, y) && !solid(rm, x, y) && !crateAt(rm, x, y) && !monsterAt(rm, x, y) && !npcAt(rm, x, y); }
  function freeForCrate(rm, x, y) { return inside(rm, x, y) && !isExit(rm, x, y) && !solid(rm, x, y) && !crateAt(rm, x, y) && !monsterAt(rm, x, y) && !npcAt(rm, x, y) && !playerAt(rm, x, y); }
  function freeForMonster(rm, x, y) { return freeForCrate(rm, x, y) && !ladder(rm, x, y); }
  // A monster's wall: what it can never walk through (other bodies are only in the way for now).
  function wallForMonster(rm, x, y) { return !inside(rm, x, y) || isExit(rm, x, y) || solid(rm, x, y) || !!crateAt(rm, x, y) || ladder(rm, x, y) || !!npcAt(rm, x, y); }

  // What holds each kind of body up (the cell below it).
  function holdsPlayer(rm, x, y) { return !inside(rm, x, y) || solid(rm, x, y) || !!crateAt(rm, x, y) || !!monsterAt(rm, x, y) || !!npcAt(rm, x, y); }
  function holdsCrate(rm, x, y) { return !inside(rm, x, y) || isExit(rm, x, y) || solid(rm, x, y) || !!crateAt(rm, x, y) || playerAt(rm, x, y) || !!npcAt(rm, x, y); }
  function holdsMonster(rm, x, y) { return holdsCrate(rm, x, y) || !!monsterAt(rm, x, y) || ladder(rm, x, y); }
  function holdsSand(rm, x, y) { return !inside(rm, x, y) || isExit(rm, x, y) || solid(rm, x, y) || !!crateAt(rm, x, y) || playerAt(rm, x, y) || !!npcAt(rm, x, y); }

  // ---------- run ----------
  // ctx: {slice, P, monsters, cargo (entry), recipient (entry), items (Map id -> entry), map?, templates?}
  function newRun(ctx, opts) {
    const P = ctx.P, o = opts || {};
    return {
      ctx, P, tick: 0, clock: 0, hearts: o.hearts != null ? o.hearts : P.hearts, maxHearts: P.hearts, iframes: 0, coins: o.coins || 0, sand: o.sand || 0,
      items: (o.items || []).slice(), cargo: { id: ctx.cargo ? ctx.cargo.id : null, damage: 0, meltT: 0 }, room: null, roomIndex: null, rooms: new Map(),
      buffer: null, pause: 0, done: null, events: [], kos: 0,
    };
  }
  // Cargo integrity left (0 = lost).
  function integrity(run) {
    const c = run.ctx.cargo, p = (c && c.params) || {}, max = run.P.integrity;
    const melt = p.melt_secs_per_point ? Math.floor(run.cargo.meltT / ticks(p.melt_secs_per_point, run.P.hz)) : 0;
    return Math.max(0, max - run.cargo.damage - melt);
  }
  function emit(run, type, extra) { const e = Object.assign({ t: run.tick, type }, extra || {}); run.events.push(e); return e; }
  function hurt(run, why) {
    if (run.iframes > 0 || run.done) return false;
    run.hearts -= 1; run.iframes = run.P.iframes;
    emit(run, "hurt", { why, hearts: run.hearts });
    const p = (run.ctx.cargo && run.ctx.cargo.params) || {};
    if (p.hurt_damage) damageCargo(run, p.hurt_damage, "hurt");
    return true;
  }
  function damageCargo(run, n, why) { run.cargo.damage += n; emit(run, "cargo", { why, left: integrity(run) }); }

  // Puts the player into a room at a cell (entering through an exit, or at the gate).
  function enter(run, room, x, y, face) {
    run.room = room;
    room.player = { x, y, face: face || 1, cd: 0, fallT: 0, rows: 0, anim: null, pose: "idle" };
    // "Restart this room" returns here: the room as it was and the run state at the door (time keeps running).
    room.entry = { snapshot: snapshotRoom(room), run: { hearts: run.hearts, coins: run.coins, sand: run.sand, items: run.items.slice(), damage: run.cargo.damage } };
  }
  function snapshotRoom(rm) { return JSON.stringify({ t: rm.t, terrain: Array.from(rm.terrain), doors: rm.doors, crates: rm.crates, sandFall: [...rm.sandFall], climb: [...rm.climb], monsters: rm.monsters, pickups: rm.pickups, keeper: rm.keeper, recipient: rm.recipient, player: rm.player }); }
  function restoreRoom(rm, json) {
    const s = JSON.parse(json);
    rm.t = s.t; rm.terrain = Uint8Array.from(s.terrain); rm.doors = s.doors; rm.crates = s.crates; rm.sandFall = new Map(s.sandFall); rm.climb = new Set(s.climb);
    rm.monsters = s.monsters; rm.pickups = s.pickups; rm.keeper = s.keeper; rm.recipient = s.recipient; rm.player = s.player;
  }
  // Pause menu: put the room and the run back to how they were at the door.
  function resetRoom(run) {
    const rm = run.room; if (!rm || !rm.entry) return;
    restoreRoom(rm, rm.entry.snapshot);
    const e = rm.entry.run;
    run.hearts = e.hearts; run.coins = e.coins; run.sand = e.sand; run.items = e.items.slice(); run.cargo.damage = e.damage; run.buffer = null;
    emit(run, "reset");
  }

  // ---------- player actions ----------
  const DIR = { L: -1, R: 1 };
  // Returns {ok, kind} and mutates the room; kind picks the move interval.
  function act(run, a) {
    const rm = run.room, p = rm.player, P = run.P;
    if (a === "L" || a === "R") {
      const dx = DIR[a], nx = p.x + dx;
      p.face = dx;
      if (!inside(rm, nx, p.y)) {
        const ex = rm.exitAt.get(idx(rm, p.x, p.y));
        if (ex && ((dx < 0 && ex.edge === "left") || (dx > 0 && ex.edge === "right"))) return { ok: true, kind: "exit", exit: ex };
        return { ok: false };
      }
      const c = crateAt(rm, nx, p.y);
      if (c && freeForCrate(rm, nx + dx, p.y)) { c.x += dx; c.fallT = 0; p.x = nx; return { ok: true, kind: "push" }; }
      const m = monsterAt(rm, nx, p.y);
      if (m) {
        if (m.M.pushable && m.state !== "trapped" && freeForMonster(rm, nx + dx, p.y)) {
          m.anim = { from: { x: m.x, y: m.y }, t: run.tick }; m.x += dx; m.state = "stunned"; m.until = rm.t + m.M.stun; m.fallT = 0; p.x = nx;
          emit(run, "push-monster", { monster: m.n }); return { ok: true, kind: "push" };
        }
        // Walking into a monster that hurts: the player is hurt and stays (a trapped one does not hurt).
        if (m.M.contact === "hurt" && m.state !== "trapped") { hurt(run, m.id); m.dir = dx; return { ok: true, kind: "walk", bump: true }; }
        return { ok: false };
      }
      if (rm.recipient && rm.recipient.x === nx && rm.recipient.y === p.y) return { ok: true, kind: "interact", deliver: true };
      if (freeForPlayer(rm, nx, p.y)) { p.x = nx; return { ok: true, kind: "walk" }; }
      // Step up one tile onto solid ground or a crate (never onto a monster's or a person's head).
      const below = solid(rm, nx, p.y) || !!crateAt(rm, nx, p.y);
      if (below && freeForPlayer(rm, p.x, p.y - 1) && freeForPlayer(rm, nx, p.y - 1)) { p.x = nx; p.y -= 1; return { ok: true, kind: "step" }; }
      return { ok: false };
    }
    if (a === "U") {
      const k = rm.keeper;
      if (k && k.y === p.y && Math.abs(k.x - p.x) <= 1) return { ok: true, kind: "interact", talk: true };
      if (ladder(rm, p.x, p.y) && p.y === 0) { const ex = rm.exitAt.get(idx(rm, p.x, p.y)); if (ex && ex.edge === "top") return { ok: true, kind: "exit", exit: ex }; }
      if (ladder(rm, p.x, p.y) && ladder(rm, p.x, p.y - 1) && freeForPlayer(rm, p.x, p.y - 1)) { p.y -= 1; return { ok: true, kind: "climb" }; }
      return { ok: false };
    }
    if (a === "D") {
      if (p.y === rm.H - 1 && ladder(rm, p.x, p.y)) { const ex = rm.exitAt.get(idx(rm, p.x, p.y)); if (ex && ex.edge === "bottom") return { ok: true, kind: "exit", exit: ex }; }
      if ((ladder(rm, p.x, p.y) || ladder(rm, p.x, p.y + 1)) && freeForPlayer(rm, p.x, p.y + 1)) { p.y += 1; return { ok: true, kind: "climb" }; }
      return { ok: false };
    }
    let m;
    if ((m = /^(DIG|POUR)_([LRD])$/.exec(a))) {
      const [dx, dy] = { L: [-1, 0], R: [1, 0], D: [0, 1] }[m[2]], tx = p.x + dx, ty = p.y + dy;
      if (dx) p.face = dx;
      if (!inside(rm, tx, ty) || isExit(rm, tx, ty)) return { ok: false };
      const T = TM().T, i = idx(rm, tx, ty);
      if (m[1] === "DIG") {
        const t = rm.terrain[i];
        if ((t !== T.SAND && t !== T.EARTH) || run.sand >= P.sandMax || doorClosed(rm, tx, ty)) return { ok: false };
        rm.terrain[i] = T.EMPTY; rm.sandFall.delete(i); run.sand += 1;
        return { ok: true, kind: "dig" };
      }
      if (m[2] === "D" || run.sand < 1 || !freeForCrate(rm, tx, ty)) return { ok: false };
      rm.terrain[i] = T.SAND; run.sand -= 1;
      return { ok: true, kind: "pour" };
    }
    if ((m = /^USE_([1-9])$/.exec(a))) {
      const slot = Number(m[1]) - 1, item = run.items[slot];
      if (!item) return { ok: false };
      if (item === "first_aid") { if (run.hearts >= run.maxHearts) return { ok: false }; run.hearts += 1; }
      else if (item === "rope_ladder") {
        const lx = p.x + p.face, max = ((run.ctx.items && run.ctx.items.get("rope_ladder")) || { params: {} }).params.max_tiles || 6;
        if (!freeForCrate(rm, lx, p.y)) return { ok: false };
        for (let y = p.y, n = 0; n < max && freeForCrate(rm, lx, y); y++, n++) rm.climb.add(idx(rm, lx, y));
      } else return { ok: false };
      run.items.splice(slot, 1);
      emit(run, "use", { item });
      return { ok: true, kind: "use" };
    }
    return { ok: false };
  }

  // ---------- gravity ----------
  // One fall step per body every P.fall ticks; processed bottom-up, left to right.
  function gravity(run) {
    const rm = run.room, P = run.P, T = TM().T;
    for (let y = rm.H - 1; y >= 0; y--) for (let x = 0; x < rm.W; x++) {
      const i = idx(rm, x, y);
      if (rm.terrain[i] === T.SAND) {
        const f = rm.sandFall.get(i) || { t: 0, rows: 0 };
        if (holdsSand(rm, x, y + 1)) { if (f.rows) emit(run, "sand-land", { x, y }); rm.sandFall.delete(i); continue; }
        f.t += 1;
        if (f.t < P.fall) { rm.sandFall.set(i, f); continue; }
        const mo = monsterAt(rm, x, y + 1);
        rm.terrain[i] = T.EMPTY; rm.terrain[i + rm.W] = T.SAND; rm.sandFall.delete(i);
        rm.sandFall.set(i + rm.W, { t: 0, rows: f.rows + 1 });
        if (mo) knockOut(run, mo, "buried");
        continue;
      }
      const c = crateAt(rm, x, y);
      if (c) { fallBody(run, c, holdsCrate(rm, x, y + 1), () => { const mo = monsterAt(rm, x, y + 1); c.y += 1; if (mo) knockOut(run, mo, "crushed"); }, (rows) => { if (playerAt(rm, x, y + 1) && rows > 0) hurt(run, "crate"); }); continue; }
      const mo = monsterAt(rm, x, y);
      if (mo) {
        fallBody(run, mo, holdsMonster(rm, x, y + 1), () => { mo.y += 1; }, (rows) => {
          if (playerAt(rm, x, y + 1) && rows > 0) hurt(run, mo.id);
          if (rows >= P.monsterKo && !isSand(rm, x, y + 1)) knockOut(run, mo, "fall");
          else if (rows > 0 && isPit(rm, mo)) { mo.state = "trapped"; mo.until = rm.t + mo.M.trap; emit(run, "trap", { monster: mo.n }); }
        });
        continue;
      }
      const r = rm.recipient;
      if (r && r.x === x && r.y === y) { fallBody(run, r, holdsMonster(rm, x, y + 1), () => { r.y += 1; }, () => {}); continue; }
      const p = rm.player;
      if (p && p.x === x && p.y === y) {
        fallBody(run, p, ladder(rm, x, y) || holdsPlayer(rm, x, y + 1), () => { p.y += 1; }, (rows) => {
          const soft = isSand(rm, x, y + 1);
          if (rows >= P.fallHurt && !soft) hurt(run, "fall");
          const cp = (run.ctx.cargo && run.ctx.cargo.params) || {};
          if (cp.fragile_fall_rows && rows >= cp.fragile_fall_rows && !(soft && cp.sand_cushion)) damageCargo(run, 1, "fall");
          if (rows > 0) emit(run, "land", { rows });
        });
      }
    }
  }
  // held: whether something holds the body; move(): one row down; land(rows): called once when it stops.
  function fallBody(run, b, held, move, land) {
    if (held) { if (b.rows) land(b.rows); b.rows = 0; b.fallT = 0; return; }
    b.fallT += 1;
    if (b.fallT >= run.P.fall) { move(); b.fallT = 0; b.rows += 1; }
  }
  function isPit(rm, m) { return wallForMonster(rm, m.x - 1, m.y) && wallForMonster(rm, m.x + 1, m.y); }
  function falling(rm, b, holds) { return !holds(rm, b.x, b.y + 1); }

  function knockOut(run, m, how) {
    const rm = run.room;
    m.ko = true; m.state = "ko"; m.koT = run.tick; run.kos += 1;
    // Drops land where it fell; if that cell is now filled, on top of it.
    let dy = m.y; while (dy > 0 && (solid(run.room, m.x, dy) || crateAt(rm, m.x, dy))) dy -= 1;
    if (m.M.coins + m.carry.coins > 0) rm.pickups.push({ x: m.x, y: dy, kind: "coin", value: m.M.coins + m.carry.coins });
    if (m.carry.sand > 0) rm.pickups.push({ x: m.x, y: dy, kind: "sand", value: m.carry.sand });
    emit(run, "ko", { monster: m.n, id: m.id, how });
  }

  // ---------- monsters ----------
  function sees(rm, m, p) {
    if (!m.M.sight || p.y !== m.y || Math.abs(p.x - m.x) > m.M.sight) return false;
    const d = Math.sign(p.x - m.x);
    for (let x = m.x + d; x !== p.x; x += d) if (solid(rm, x, m.y) || crateAt(rm, x, m.y)) return false;
    return true;
  }
  // Rows a monster would fall from (x, y) before something holds it.
  function drop(rm, x, y) { let k = 0; while (k < rm.H && !holdsMonster(rm, x, y + k + 1)) k++; return k; }

  function monsterStep(run, m) {
    const rm = run.room, p = rm.player;
    if (m.ko || falling(rm, m, holdsMonster)) return;
    // Timed states end at a tick of the room's own clock: stunned (pushed), trapped (in a pit), fleeing (after a theft).
    if (m.state === "stunned") { if (rm.t < m.until) return; m.state = "walk"; m.cd = 0; }
    if (m.state === "trapped") {
      if (rm.t < m.until) return;
      // Climb out of the pit, forwards if it can, else backwards.
      for (const d of [m.dir, -m.dir]) {
        const tx = m.x + d, ty = m.y - 1;
        if (freeForMonster(rm, m.x, ty) && freeForMonster(rm, tx, ty) && holdsMonster(rm, tx, ty + 1)) {
          m.x = tx; m.y = ty; m.dir = d; m.state = "walk"; m.cd = m.M.step; emit(run, "escape", { monster: m.n }); return;
        }
      }
      m.until = rm.t + m.M.trap; return;
    }
    if (m.state === "flee" && rm.t >= m.until) m.state = "walk";
    if (m.state !== "flee" && m.M.move === "chase") {
      const see = p && sees(rm, m, p);
      if (see) { if (m.state !== "chase") emit(run, "spot", { monster: m.n }); m.state = "chase"; m.dir = Math.sign(p.x - m.x); }
      else if (m.state === "chase") m.state = "walk";
    }
    if (m.cd > 0) { m.cd -= 1; return; }
    const interval = m.state === "chase" ? m.M.chaseStep : m.state === "flee" ? m.M.fleeStep : m.M.step;
    m.cd = interval - 1;
    const nx = m.x + m.dir;
    if (p && p.x === nx && p.y === m.y) { contact(run, m); return; }
    // Turn at walls, at drops of cliff_rows or more, and never step onto the player's head.
    if (!freeForMonster(rm, nx, m.y) || drop(rm, nx, m.y) >= m.M.cliff || playerAt(rm, nx, m.y + 1)) { m.dir = -m.dir; return; }
    m.anim = { from: { x: m.x, y: m.y }, t: run.tick };
    m.x = nx;
  }
  function contact(run, m) {
    const rm = run.room, p = rm.player;
    if (m.M.contact === "steal") {
      if (m.state === "flee") { m.dir = -m.dir; return; }
      let what = null;
      if (run.sand >= m.M.stealSand && m.M.stealSand > 0) { run.sand -= m.M.stealSand; m.carry.sand += m.M.stealSand; what = "sand"; }
      else if (run.coins >= m.M.stealCoins && m.M.stealCoins > 0) { run.coins -= m.M.stealCoins; m.carry.coins += m.M.stealCoins; what = "coins"; }
      emit(run, "steal", { monster: m.n, what });
      m.state = "flee"; m.until = rm.t + m.M.flee; m.dir = Math.sign(m.x - p.x) || -m.dir; m.cd = m.M.fleeStep - 1;
      return;
    }
    hurt(run, m.id);
    m.dir = -m.dir;
  }

  // The recipient: stays, or wanders like a patrol (never hurts; touching him delivers).
  function recipientStep(run) {
    const rm = run.room, r = rm.recipient, p = rm.player;
    if (!r || r.move !== "wander" || !holdsMonster(rm, r.x, r.y + 1)) return;
    if (r.cd > 0) { r.cd -= 1; return; }
    r.cd = r.step - 1;
    const nx = r.x + r.dir;
    if (p && p.x === nx && p.y === r.y) { run.deliverNow = true; return; }
    if (!freeForMonster(rm, nx, r.y) || drop(rm, nx, r.y) >= 2 || playerAt(rm, nx, r.y + 1)) { r.dir = -r.dir; return; }
    r.x = nx;
  }

  // Plates and doors (game-design.md 4.7): a group is open while all its plates
  // are pressed by the player, a crate or anything solid; doors do not close on occupants.
  function doors(run) {
    const rm = run.room, L = rm.L;
    L.groups.forEach((g, k) => {
      const pressed = (i) => { const x = i % rm.W, y = (i / rm.W) | 0; return playerAt(rm, x, y) || !!crateAt(rm, x, y) || solid(rm, x, y) && !L.doorAt.has(i); };
      const on = g.plates.length > 0 && g.plates.every(pressed);
      const want = on ? 1 : 0;
      if (want === rm.doors[k]) return;
      const busy = g.doors.some((i) => { const x = i % rm.W, y = (i / rm.W) | 0; return playerAt(rm, x, y) || crateAt(rm, x, y) || monsterAt(rm, x, y) || rm.terrain[i] !== TM().T.EMPTY; });
      if (want || !busy) { rm.doors[k] = want; emit(run, want ? "door-open" : "door-close"); }
    });
  }

  function pickups(run) {
    const rm = run.room, p = rm.player;
    for (let i = rm.pickups.length - 1; i >= 0; i--) {
      const q = rm.pickups[i];
      if (q.x !== p.x || q.y !== p.y) continue;
      if (q.kind === "coin") run.coins += q.value;
      else if (q.kind === "sand") run.sand = Math.min(run.P.sandMax, run.sand + q.value);
      rm.pickups.splice(i, 1);
      emit(run, "pickup", { kind: q.kind, value: q.value });
    }
  }

  // ---------- one tick ----------
  // input: {held: "L" | "R" | "U" | "D" | null, press: action | null}. Returns the events of this tick.
  function step(run, input) {
    const from = run.events.length;
    if (run.done) return [];
    const inp = input || {};
    if (inp.press) run.buffer = inp.press;
    if (run.pause > 0) { run.pause -= 1; run.tick += 1; return run.events.slice(from); }
    const rm = run.room, p = rm.player, P = run.P;
    // run.tick counts every tick (events, replays); run.clock is the delivery time (no transitions);
    // rm.t is the room's own clock (monster timers): a room the player is not in stands still.
    run.tick += 1; run.clock += 1; rm.t += 1;
    if (run.iframes > 0) run.iframes -= 1;
    if (p.cd > 0) p.cd -= 1;
    // 1. The player acts when the move interval is over and nothing is carrying them down.
    const air = !ladder(rm, p.x, p.y) && !holdsPlayer(rm, p.x, p.y + 1);
    if (p.cd === 0 && !air) {
      const a = run.buffer || inp.held || null;
      if (a) {
        const before = { x: p.x, y: p.y };
        const r = act(run, a);
        // A buffered press is tried once, at the first tick the player can act, and then forgotten.
        run.buffer = null;
        if (r.ok) {
          p.cd = r.kind === "exit" ? 0 : P.act[r.kind] || P.act.walk;
          p.pose = r.kind; p.anim = { from: before, t: run.tick, len: P.moveAnim };
          if (r.exit) { emit(run, "exit", { edge: r.exit.edge, slot: r.exit.slot, x: p.x, y: p.y }); run.leaving = r.exit; return run.events.slice(from); }
          if (r.deliver) run.deliverNow = true;
          else if (r.talk) talk(run);
          else if (!r.bump) emit(run, r.kind, { x: p.x, y: p.y });
        }
      }
    }
    // 2. Gravity, 3. monsters, 4. recipient, 5. doors, 6. pickups.
    gravity(run);
    for (const m of rm.monsters) monsterStep(run, m);
    recipientStep(run);
    doors(run);
    pickups(run);
    // 7. Cargo that melts; hot rooms melt it faster.
    const cp = (run.ctx.cargo && run.ctx.cargo.params) || {};
    if (cp.melt_secs_per_point) {
      const before = integrity(run);
      run.cargo.meltT += rm.hot && run.ctx.recipient && run.ctx.recipient.params ? run.ctx.recipient.params.home_melt_mult || 1 : 1;
      if (integrity(run) < before) emit(run, "cargo", { why: "melt", left: integrity(run) });
    }
    // 8. Outcome.
    if (run.deliverNow) { run.deliverNow = false; run.done = { ok: true, reason: "delivered", tick: run.tick }; emit(run, "deliver"); }
    else if (run.hearts <= 0) { run.done = { ok: false, reason: "hearts", tick: run.tick }; emit(run, "fail", { reason: "hearts" }); }
    else if (run.ctx.cargo && integrity(run) <= 0) { run.done = { ok: false, reason: "cargo", tick: run.tick }; emit(run, "fail", { reason: "cargo" }); }
    return run.events.slice(from);
  }
  // Talking opens the shelf; the keeper heals once per station, the first time the player is hurt when talking.
  function talk(run) {
    const k = run.room.keeper;
    const heal = !k.healed && run.hearts < run.maxHearts ? Math.min(run.maxHearts - run.hearts, (run.ctx.slice.station && run.ctx.slice.station.heal) || 0) : 0;
    if (heal) { run.hearts += heal; k.healed = true; }
    k.talked = true;
    emit(run, "talk", { heal });
  }

  // ---------- inputs written as scripts (demos and recorded replays) ----------
  // Tokens: an action ("R", "DIG_D", "USE_1"...), "R*4" (four times), "wait 30"
  // (ticks), "hold R 40" (keep R held for 40 ticks). An action is issued as
  // soon as the player can act; script ends when the run is done or leaves.
  function parseScript(tokens) {
    const out = [];
    for (const tok of tokens || []) {
      let m;
      if ((m = /^wait (\d+)$/.exec(tok))) out.push({ wait: Number(m[1]) });
      else if ((m = /^hold ([LRUD]) (\d+)$/.exec(tok))) out.push({ hold: m[1], ticks: Number(m[2]) });
      else if ((m = /^([A-Z_0-9]+)\*(\d+)$/.exec(tok))) for (let i = 0; i < Number(m[2]); i++) out.push({ act: m[1] });
      else if (/^[A-Z_0-9]+$/.test(tok)) out.push({ act: tok });
      else throw new Error("bad script token " + tok);
    }
    return out;
  }
  function ready(run) { const rm = run.room, p = rm.player; return p.cd === 0 && run.pause === 0 && (ladder(rm, p.x, p.y) || holdsPlayer(rm, p.x, p.y + 1)) && !run.buffer; }

  // A script player that advances one tick at a time (the workbench animates it;
  // playRoom runs it to the end). Like a player with the input buffer: the next
  // action is pressed as soon as the previous one has been taken, and runs the
  // moment the player can act.
  function scriptPlayer(run, tokens) {
    const steps = parseScript(tokens);
    let k = 0, waitUntil = 0, holdUntil = 0, held = null, settle = -1;
    return {
      run,
      finished: () => !!run.done || !!run.leaving || settle === 0,
      tick() {
        if (run.done || run.leaving || settle === 0) return [];
        if (settle > 0) { settle -= 1; return step(run, {}); }
        let press = null;
        if (!run.buffer && run.tick >= waitUntil && run.tick >= holdUntil) {
          held = null;
          const s = steps[k];
          if (s && s.wait !== undefined) { waitUntil = run.tick + s.wait; k++; }
          else if (s && s.hold) { held = s.hold; holdUntil = run.tick + s.ticks; k++; }
          else if (s) { press = s.act; k++; }
        }
        const ev = step(run, { held, press });
        // Script finished: give the world half a second to settle, then stop.
        if (k >= steps.length && !run.buffer && !held && run.tick >= waitUntil && !run.leaving && !run.done && settle < 0) settle = 30;
        return ev;
      },
    };
  }
  // Puts a fresh run into one room at an entry ("gate" or "edge.slot").
  function roomRun(ctx, t, placement, from, runOpts) {
    const run = newRun(ctx, runOpts);
    const room = makeRoom(ctx, t, placement.mirror, placement.open);
    let start;
    if (from === "gate") start = [room.gate.x, room.gate.y];
    else { const [e, sl] = from.split("."); start = R().entryCell(e, sl); }
    for (const it of (runOpts && runOpts.items) || []) if (!run.items.includes(it)) run.items.push(it);
    enter(run, room, start[0], start[1], from.startsWith("right") ? -1 : 1);
    return { run, room };
  }
  // Runs one room from an entry with a script. Returns the run, its trace and how it ended.
  function playRoom(ctx, t, placement, demo, opts) {
    const o = opts || {}, { run, room } = roomRun(ctx, t, placement, demo.from, o.run);
    const sp = scriptPlayer(run, o.mirrorScript ? mirrorTokens(demo.script) : demo.script), limit = o.limit || 60 * 120, trace = [];
    while (!sp.finished() && run.tick < limit) { sp.tick(); if (o.trace) trace.push(frame(run)); }
    return { run, room, trace, left: run.leaving || null, done: run.done, ticks: run.tick };
  }

  // ---------- a whole delivery on a generated map ----------
  // templates: Map(id -> room template). The player starts at the gate.
  function startRun(ctx, map, templates, opts) {
    const run = newRun(ctx, opts);
    run.map = map; run.templates = templates; run.visited = new Set([0]);
    const room = roomFor(run, 0);
    enter(run, room, room.gate.x, room.gate.y, 1);
    run.roomIndex = 0;
    return run;
  }
  function roomFor(run, i) {
    if (!run.rooms.has(i)) { const r = run.map.rooms[i]; run.rooms.set(i, makeRoom(run.ctx, run.templates.get(r.template), r.mirror, r.open)); }
    return run.rooms.get(i);
  }
  // Leaving through an exit: the room stays as it is; the next one is entered at the matching cell.
  function travel(run) {
    const ex = run.leaving, cur = run.map.rooms[run.roomIndex], st = R().STEP[ex.edge];
    const next = run.map.rooms.find((r) => r.x === cur.x + st[0] && r.y === cur.y + st[1]);
    run.leaving = null;
    if (!next) return;
    const old = run.room, p = old.player, room = roomFor(run, next.index);
    let x = p.x, y = p.y;
    if (ex.edge === "left") x = room.W - 1; else if (ex.edge === "right") x = 0;
    else if (ex.edge === "top") y = room.H - 1; else y = 0;
    old.player = null;
    enter(run, room, x, y, p.face);
    run.roomIndex = next.index; run.visited.add(next.index); run.pause = run.P.transition;
    emit(run, "room", { index: next.index, edge: ex.edge });
  }
  function stepRun(run, input) { if (run.leaving && run.map) travel(run); return step(run, input); }

  // Station shelf (slice.station): buy one item after talking to the keeper.
  function buy(run, id) {
    const k = run.room && run.room.keeper, sl = run.ctx.slice, item = run.ctx.items.get(id);
    if (!k || !k.talked) return { ok: false, why: "closed" };
    if (!item || !(sl.station.items || []).includes(id)) return { ok: false, why: "unknown" };
    const stock = k.stock;
    if ((stock[id] || 0) <= 0) return { ok: false, why: "stock" };
    if (run.coins < item.price) return { ok: false, why: "coins" };
    if (id === "sandbag") { if (run.sand >= run.P.sandMax) return { ok: false, why: "full" }; run.sand += 1; }
    else { if (run.items.length >= run.P.slots) return { ok: false, why: "slots" }; run.items.push(id); }
    run.coins -= item.price; stock[id] -= 1;
    emit(run, "buy", { item: id, price: item.price });
    return { ok: true };
  }

  // Settlement (delivery-slice.md §10) in integer arithmetic so every port agrees.
  // parTicks: the map's reference time in ticks (sum of the route references).
  function settlement(run, parTicks) {
    const sl = run.ctx.slice, cargo = run.ctx.cargo, rec = run.ctx.recipient, max = run.P.integrity;
    const ok = !!(run.done && run.done.ok), left = integrity(run), t = run.clock, par = Math.max(1, parTicks | 0);
    const fast = Math.round(sl.tip.time_fast * 100), floor = Math.round(sl.tip.time_floor * 100);
    const timePct = t <= par ? fast : Math.max(floor, fast - Math.floor((100 * (t - par)) / par));
    const likePct = rec && (rec.likes || []).includes(cargo.id) ? Math.round(sl.tip.like * 100) : 100;
    const pay = (cargo.params && cargo.params.pay) || 0, den = max * 10000;
    const tip = ok ? Math.floor((pay * left * timePct * likePct + den / 2) / den) : 0;
    const score = Math.floor((left * timePct) / max);
    const rating = !ok ? null : score >= Math.round(sl.rating.S * 100) ? "S" : score >= Math.round(sl.rating.A * 100) ? "A" : score >= Math.round(sl.rating.B * 100) ? "B" : "C";
    const total = ok ? run.coins + tip : Math.floor(run.coins * Math.round(sl.fail_keep * 100) / 100);
    return { ok, reason: run.done ? run.done.reason : null, ticks: t, par, integrity: left, max, timePct, likePct, pay, tip, picked: run.coins, total, rating, score };
  }

  function mirrorTokens(tokens) {
    const sw = { L: "R", R: "L" };
    return tokens.map((t) => t.replace(/\b(DIG|POUR)_([LR])\b/g, (m, a, d) => a + "_" + sw[d]).replace(/^([LR])(\*\d+)?$/, (m, d, n) => sw[d] + (n || "")).replace(/^hold ([LR])/, (m, d) => "hold " + sw[d]));
  }
  // A compact picture of the room at this tick (for traces and golden checkpoints).
  function frame(run) {
    const rm = run.room, p = rm.player;
    return { t: run.tick, p: [p.x, p.y], hearts: run.hearts, coins: run.coins, sand: run.sand, cargo: integrity(run),
      m: rm.monsters.map((m) => (m.ko ? null : [m.x, m.y, m.state[0]])), c: rm.crates.map((c) => [c.x, c.y]) };
  }

  // ---------- demos (each room template carries a few; tools/check-rooms.mjs runs them) ----------
  // cat: {monsters, cargo, recipients, items} catalog entry lists.
  function context(cat, slice, cargoId, recipientId) {
    const byId = (l) => new Map((l || []).map((e) => [e.id, e]));
    return { slice, P: params(slice), monsters: byId(cat.monsters), cargo: byId(cat.cargo).get(cargoId || slice.cargo[0]) || null,
      recipient: recipientId ? byId(cat.recipients).get(recipientId) || null : null, items: byId(cat.items) };
  }
  const MIRROR_EDGE = { left: "right", right: "left", top: "top", bottom: "bottom" };
  // Plays one demo (mirrored if asked) and checks what it promises. Frames every 30 ticks are kept as the replay record.
  function runDemo(cat, slice, t, demo, mirror) {
    const recipient = demo.recipient || (t.type === "home" ? slice.recipients[0] : null);
    const ctx = context(cat, slice, demo.cargo || slice.cargo[0], recipient);
    const open = {}; for (const [e, sl] of Object.entries(demo.open || {})) open[mirror ? MIRROR_EDGE[e] : e] = sl;
    const from = demo.from === "gate" ? "gate" : (mirror ? MIRROR_EDGE[demo.from.split(".")[0]] : demo.from.split(".")[0]) + "." + demo.from.split(".")[1];
    const res = playRoom(ctx, t, { mirror: !!mirror, open }, { from, script: demo.script }, { mirrorScript: !!mirror, run: demo.run, trace: true, limit: demo.limit || 60 * 90 });
    const run = res.run, ex = demo.expect || {}, fail = [];
    const end = res.done ? (res.done.ok ? "deliver" : "fail:" + res.done.reason) : res.left ? "exit:" + res.left.edge : "stopped";
    let want = ex.end;
    if (want && mirror) want = want.replace(/exit:(left|right)/, (m, e) => "exit:" + MIRROR_EDGE[e]);
    if (want && end !== want) fail.push(`结局应为 ${want}，实际 ${end}`);
    const got = { hearts: run.hearts, coins: run.coins, sand: run.sand, kos: run.kos, cargo: integrity(run) };
    for (const k of ["hearts", "coins", "sand", "kos", "cargo"]) if (ex[k] !== undefined && ex[k] !== got[k]) fail.push(`${k} 应为 ${ex[k]}，实际 ${got[k]}`);
    const kos = run.events.filter((e) => e.type === "ko").map((e) => e.how);
    for (const how of ex.ko || []) if (!kos.includes(how)) fail.push(`没有出现"${how}"放倒怪物`);
    for (const ev of ex.events || []) if (!run.events.some((e) => e.type === ev)) fail.push(`没有出现事件 ${ev}`);
    const frames = res.trace.filter((f, i) => f.t % 30 === 0 || i === res.trace.length - 1);
    return { id: demo.id, mirror: !!mirror, ok: fail.length === 0, failures: fail, ticks: res.ticks, end, got, ko: kos,
      placement: R().placementKey(t.id, !!mirror, open), from, cargo: ctx.cargo ? ctx.cargo.id : null, recipient, run: demo.run || null,
      script: mirror ? mirrorTokens(demo.script) : demo.script.slice(), frames,
      events: run.events.filter((e) => !["walk", "climb", "step", "land", "sand-land"].includes(e.type)).map((e) => [e.t, e.type]) };
  }

  PB.rt = { ticks, params, context, runDemo, scriptPlayer, roomRun, roomFromSpec, startRun, stepRun, travel, buy, settlement, monsterParams, makeRoom, newRun, enter, step, act, integrity, resetRoom, snapshotRoom, restoreRoom, parseScript, playRoom, mirrorTokens, frame, ready,
    pred: { solid, ladder, isExit, crateAt, monsterAt, npcAt, freeForPlayer, freeForCrate, freeForMonster, holdsPlayer, holdsCrate, holdsMonster, drop, sees, isPit } };
})(typeof window !== "undefined" ? window : globalThis);
