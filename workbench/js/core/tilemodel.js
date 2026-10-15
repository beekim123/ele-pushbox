/* Design model of the tile-level rules (docs/design/game-design.md §4).
 *
 * This is NOT the SDK. It predicts what each player action should do at the
 * tile level so that level specs can be checked for solvability, step counts
 * and dead ends before anyone builds them in Godot. Loose sand, water, fire
 * and every other SDK material must still be verified in the real SDK.
 *
 * Chapter 2-5 characters (§6.5) are parsed so their maps can be drawn, with
 * only the simplest tile behaviour (powders fall, wood crates float, lift decks
 * and grown vines can be stood on / climbed). Fluids, gases, explosions,
 * reactions and heat are NOT modelled; those levels are verified in the SDK.
 *
 * Shared by the workbench (browser, classic script) and the Node tools.
 */
(function (root) {
  "use strict";
  const PB = (root.PB = root.PB || {});

  // Terrain codes (static map layer).
  const T = { EMPTY: 0, ROCK: 1, CRACKED: 2, EARTH: 3, SAND: 4, WATER: 5, DOOR: 6,
    GRAVEL: 7, FUSE: 8, ACID: 9, LIME_A: 10, LIME_B: 11, HARD: 12, SMOKE: 13, FOG: 14, PLUG: 15, WOOD: 16, ICE: 17 };
  // Background markers (do not block).
  const M = { NONE: 0, LADDER: 1, SOCKET: 2, EXIT: 3, PLATE: 4 };

  const CHAR = {
    "#": { t: T.ROCK }, "%": { t: T.CRACKED }, "e": { t: T.EARTH }, "s": { t: T.SAND },
    "~": { t: T.WATER }, "|": { t: T.DOOR }, ".": {}, "H": { m: M.LADDER }, "o": { m: M.SOCKET },
    "X": { m: M.EXIT }, "_": { m: M.PLATE }, "P": { player: true }, "B": { crate: "wood" },
    "I": { crate: "iron" }, "b": { crate: "wood", m: M.SOCKET }, "h": { player: true, m: M.LADDER },
    "g": { t: T.GRAVEL }, "f": { t: T.FUSE }, "a": { t: T.ACID }, "L": { t: T.LIME_A }, "M": { t: T.LIME_B },
    "R": { t: T.HARD }, "^": { t: T.SMOKE }, "v": { t: T.FOG }, "p": { t: T.PLUG }, "w": { t: T.WOOD }, "i": { t: T.ICE },
  };
  const POWDER = (t) => t === T.SAND || t === T.GRAVEL;
  const LIQUID = (t) => t === T.WATER || t === T.ACID;
  const OPEN = (t) => t === T.EMPTY || t === T.WATER || t === T.ACID || t === T.SMOKE || t === T.FOG;

  const DIRS = { L: [-1, 0], R: [1, 0], U: [0, -1], D: [0, 1] };

  function parse(spec) {
    const rows = spec.map;
    const h = rows.length, w = rows[0].length;
    const terrain = new Uint8Array(w * h), marker = new Uint8Array(w * h);
    const crates = []; let player = null;
    for (let y = 0; y < h; y++) {
      if (rows[y].length !== w) throw new Error(spec.id + ": row " + y + " width " + rows[y].length + " != " + w);
      for (let x = 0; x < w; x++) {
        const c = CHAR[rows[y][x]];
        if (!c) throw new Error(spec.id + ": unknown char '" + rows[y][x] + "' at " + x + "," + y);
        const i = y * w + x;
        if (c.t) terrain[i] = c.t;
        if (c.m) marker[i] = c.m;
        if (c.crate) crates.push({ x, y, kind: c.crate });
        if (c.player) { if (player) throw new Error(spec.id + ": two players"); player = { x, y }; }
      }
    }
    if (!player) throw new Error(spec.id + ": no player");
    const bag = Object.assign({ sand: 0, bomb: 0 }, spec.bag || {});
    const level = { id: spec.id, w, h, marker, plates: [], doors: [] };
    // Plates under water are listed in links (a cell holds one character).
    for (const g of spec.links || []) for (const [x, y] of g.plates || []) marker[y * w + x] = M.PLATE;
    for (let i = 0; i < w * h; i++) {
      if (marker[i] === M.PLATE) level.plates.push(i);
      if (terrain[i] === T.DOOR) level.doors.push(i);
    }
    if (spec.links) {
      level.symbol = {};
      spec.links.forEach((g, k) => { for (const [x, y] of (g.plates || []).concat(g.doors || [])) level.symbol[y * w + x] = g.symbol || ["circle", "triangle", "square"][k % 3]; });
    }
    // Devices that change what can be stood on or climbed (drawn by matter.js).
    // `preview` holds an illustration state for the workbench, never a rule.
    if (spec.devices) {
      level.deck = new Set(); level.climb = new Set();
      for (const d of spec.devices) {
        const pv = d.preview || {};
        if (d.type === "lift") { const [x, y] = d.stops[pv.stop || 0]; for (let k = 0; k < (d.width || 1); k++) level.deck.add(y * w + x + k); }
        if (d.type === "vine" && pv.grown) for (let k = 0; k < d.height; k++) level.climb.add((d.root[1] - k) * w + d.root[0]);
      }
    }
    const state = { terrain, crates, player, bag, doorsOpen: false, moves: 0 };
    settle(level, state);
    return { level, state };
  }

  function clone(s) {
    return { terrain: s.terrain.slice(), crates: s.crates.map((c) => ({ x: c.x, y: c.y, kind: c.kind })),
      player: { x: s.player.x, y: s.player.y }, bag: { sand: s.bag.sand, bomb: s.bag.bomb },
      doorsOpen: s.doorsOpen, moves: s.moves };
  }

  function inside(L, x, y) { return x >= 0 && y >= 0 && x < L.w && y < L.h; }
  function terrainAt(L, s, x, y) {
    if (!inside(L, x, y)) return T.ROCK;
    const t = s.terrain[y * L.w + x];
    return t === T.DOOR && s.doorsOpen ? T.EMPTY : t;
  }
  function crateAt(s, x, y) { for (const c of s.crates) if (c.x === x && c.y === y) return c; return null; }
  function solidTerrain(t) { return t !== T.EMPTY && !OPEN(t); }
  function deck(L, x, y) { return !!L.deck && L.deck.has(y * L.w + x); }
  function isPlayer(s, x, y) { return s.player.x === x && s.player.y === y; }
  // Tile that holds something resting on it.
  function supports(L, s, x, y) { return solidTerrain(terrainAt(L, s, x, y)) || !!crateAt(s, x, y) || deck(L, x, y); }
  // Tile a body may move into.
  function free(L, s, x, y) {
    const t = terrainAt(L, s, x, y);
    return OPEN(t) && !crateAt(s, x, y) && !isPlayer(s, x, y) && !deck(L, x, y);
  }
  function ladder(L, x, y) { return inside(L, x, y) && (L.marker[y * L.w + x] === M.LADDER || (!!L.climb && L.climb.has(y * L.w + x))); }

  function platesPressed(L, s) {
    if (!L.plates.length) return false;
    return L.plates.every((i) => {
      const x = i % L.w, y = (i / L.w) | 0;
      return isPlayer(s, x, y) || !!crateAt(s, x, y) || solidTerrain(s.terrain[i]);
    });
  }

  // Gravity for crates, loose sand and the player, then doors; repeat to fixpoint.
  function settle(L, s) {
    const events = [];
    for (let guard = 0; guard < 256; guard++) {
      let moved = false;
      for (let y = L.h - 2; y >= 0; y--) {
        for (let x = 0; x < L.w; x++) {
          const i = y * L.w + x;
          const t = s.terrain[i], below = terrainAt(L, s, x, y + 1);
          if (POWDER(t) && free(L, s, x, y + 1) && !LIQUID(below)) {
            s.terrain[i] = below; s.terrain[i + L.w] = t; moved = true;
          } else if (POWDER(t) && LIQUID(below) && !crateAt(s, x, y + 1)) {
            s.terrain[i] = below; s.terrain[i + L.w] = t; moved = true; // sand sinks, water rises
          }
        }
      }
      for (const c of s.crates.slice().sort((a, b) => b.y - a.y)) {
        // Wood floats (chapter 2 on): it rests on a water surface and rises through water.
        if (c.kind === "wood" && terrainAt(L, s, c.x, c.y) === T.WATER && terrainAt(L, s, c.x, c.y - 1) === T.WATER && free(L, s, c.x, c.y - 1)) { c.y -= 1; moved = true; events.push("crate-float"); }
        else if (c.kind === "wood" && terrainAt(L, s, c.x, c.y + 1) === T.WATER) continue;
        else if (free(L, s, c.x, c.y + 1)) { c.y += 1; moved = true; events.push("crate-fall"); }
      }
      const p = s.player;
      if (!ladder(L, p.x, p.y) && !supports(L, s, p.x, p.y + 1) && free(L, s, p.x, p.y + 1)) {
        p.y += 1; moved = true;
      }
      const open = platesPressed(L, s);
      if (open !== s.doorsOpen) {
        if (open || L.doors.every((i) => !crateAt(s, i % L.w, (i / L.w) | 0) && !isPlayer(s, i % L.w, (i / L.w) | 0))) {
          s.doorsOpen = open; moved = true; events.push(open ? "door-open" : "door-close");
        }
      }
      if (!moved) return events;
    }
    throw new Error("settle did not converge");
  }

  // Returns {ok, reason, events}. Mutates state on success.
  function act(L, s, action) {
    const p = s.player;
    if (action === "L" || action === "R") {
      const dx = DIRS[action][0], nx = p.x + dx;
      const c = crateAt(s, nx, p.y);
      if (c && free(L, s, nx + dx, p.y)) {
        c.x += dx; p.x = nx; return done(L, s, "push");
      }
      if (free(L, s, nx, p.y)) { p.x = nx; return done(L, s, "walk"); }
      // Step up one tile.
      if (supports(L, s, nx, p.y) && free(L, s, p.x, p.y - 1) && free(L, s, nx, p.y - 1)) {
        p.x = nx; p.y -= 1; return done(L, s, "step");
      }
      return { ok: false, reason: "blocked" };
    }
    if (action === "U") {
      if (ladder(L, p.x, p.y) && ladder(L, p.x, p.y - 1) && free(L, s, p.x, p.y - 1)) { p.y -= 1; return done(L, s, "climb"); }
      return { ok: false, reason: "no-ladder" };
    }
    if (action === "D") {
      if ((ladder(L, p.x, p.y) || ladder(L, p.x, p.y + 1)) && free(L, s, p.x, p.y + 1)) { p.y += 1; return done(L, s, "climb"); }
      return { ok: false, reason: "no-ladder" };
    }
    const m = /^(DIG|POUR|BOMB)_([LRD])$/.exec(action);
    if (!m) return { ok: false, reason: "unknown" };
    const [dx, dy] = DIRS[m[2]];
    const tx = p.x + dx, ty = p.y + dy;
    if (!inside(L, tx, ty)) return { ok: false, reason: "edge" };
    const ti = ty * L.w + tx;
    if (m[1] === "DIG") {
      const t = s.terrain[ti];
      if ((t !== T.SAND && t !== T.EARTH) || s.bag.sand >= 9) return { ok: false, reason: "not-diggable" };
      s.terrain[ti] = T.EMPTY; s.bag.sand += 1; return done(L, s, "dig");
    }
    if (m[1] === "POUR") {
      if (m[2] === "D" || s.bag.sand < 1 || !free(L, s, tx, ty)) return { ok: false, reason: "cannot-pour" };
      s.terrain[ti] = T.SAND; s.bag.sand -= 1; return done(L, s, "pour");
    }
    // BOMB: clears breakable tiles at the target and its four neighbours.
    if (s.bag.bomb < 1) return { ok: false, reason: "no-bomb" };
    let destroyed = 0;
    for (const [ox, oy] of [[0, 0], [1, 0], [-1, 0], [0, 1], [0, -1]]) {
      const x = tx + ox, y = ty + oy;
      if (!inside(L, x, y)) continue;
      const t = s.terrain[y * L.w + x];
      if (t === T.CRACKED || t === T.SAND || t === T.EARTH) { s.terrain[y * L.w + x] = T.EMPTY; destroyed++; }
    }
    s.bag.bomb -= 1;
    const r = done(L, s, "bomb"); r.destroyed = destroyed; return r;
  }

  function done(L, s, kind) { s.moves += 1; const events = settle(L, s); return { ok: true, kind, events }; }

  function goals(L, s) {
    const list = [];
    for (let i = 0; i < L.w * L.h; i++) {
      const x = i % L.w, y = (i / L.w) | 0;
      if (L.marker[i] === M.SOCKET) list.push({ kind: "socket", x, y, lit: !!crateAt(s, x, y) });
      if (L.marker[i] === M.EXIT) list.push({ kind: "exit", x, y, lit: isPlayer(s, x, y) });
    }
    return list;
  }
  function won(L, s) { const g = goals(L, s); return g.length > 0 && g.every((x) => x.lit); }

  function key(s) {
    let k = s.player.x + "," + s.player.y + "|" + s.bag.sand + "," + s.bag.bomb + "|";
    k += s.crates.map((c) => c.kind[0] + c.x + "," + c.y).sort().join(";") + "|";
    let t = ""; for (let i = 0; i < s.terrain.length; i++) t += s.terrain[i];
    return k + t;
  }

  const ACTIONS = ["L", "R", "U", "D", "DIG_L", "DIG_R", "DIG_D", "POUR_L", "POUR_R", "BOMB_L", "BOMB_R", "BOMB_D"];

  // Breadth-first search for the shortest solution under the model.
  function solve(spec, limit) {
    const { level: L, state } = parse(spec);
    const max = limit || 300000;
    const seen = new Map([[key(state), null]]);
    let frontier = [state], depth = 0;
    const parents = new Map();
    while (frontier.length && seen.size < max) {
      const next = [];
      for (const s of frontier) {
        if (won(L, s)) return { solved: true, solution: rebuild(parents, key(s)), explored: seen.size };
        for (const a of ACTIONS) {
          const n = clone(s);
          if (!act(L, n, a).ok) continue;
          const k = key(n);
          if (seen.has(k)) continue;
          seen.set(k, true); parents.set(k, [key(s), a]); next.push(n);
        }
      }
      frontier = next; depth++;
    }
    return { solved: false, explored: seen.size, exhausted: frontier.length === 0 };
  }
  function rebuild(parents, k) {
    const out = [];
    while (parents.has(k)) { const [pk, a] = parents.get(k); out.push(a); k = pk; }
    return out.reverse();
  }

  // Replays an action list; returns per-step snapshots for previews and checks.
  function replay(spec, actions) {
    const { level: L, state } = parse(spec);
    const steps = [{ action: null, state: clone(state), result: null }];
    let s = state;
    for (const a of actions) {
      const n = clone(s); const r = act(L, n, a);
      if (!r.ok) return { level: L, steps, failedAt: steps.length - 1, reason: r.reason, action: a };
      steps.push({ action: a, state: clone(n), result: r }); s = n;
    }
    return { level: L, steps, won: won(L, s) };
  }

  // Counts reachable states from which the goal is no longer reachable
  // (only meaningful for small rooms; used to flag trap-heavy layouts).
  function deadEnds(spec, limit) {
    const { level: L, state } = parse(spec);
    const max = limit || 60000;
    const keys = new Map(), edges = new Map(), wins = [];
    const queue = [state]; keys.set(key(state), state);
    while (queue.length && keys.size < max) {
      const s = queue.shift(); const k = key(s); const out = [];
      if (won(L, s)) wins.push(k);
      for (const a of ACTIONS) {
        const n = clone(s); if (!act(L, n, a).ok) continue;
        const nk = key(n); out.push(nk);
        if (!keys.has(nk)) { keys.set(nk, n); queue.push(n); }
      }
      edges.set(k, out);
    }
    if (queue.length) return { complete: false, states: keys.size };
    const reverse = new Map();
    for (const [k, out] of edges) for (const n of out) { if (!reverse.has(n)) reverse.set(n, []); reverse.get(n).push(k); }
    const good = new Set(wins); const stack = wins.slice();
    while (stack.length) { const k = stack.pop(); for (const p of reverse.get(k) || []) if (!good.has(p)) { good.add(p); stack.push(p); } }
    return { complete: true, states: keys.size, dead: keys.size - good.size };
  }

  PB.tilemodel = { T, M, CHAR, ACTIONS, parse, clone, act, settle, goals, won, solve, replay, deadEnds, crateAt, ladder };
})(typeof window !== "undefined" ? window : globalThis);
