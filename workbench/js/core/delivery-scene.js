/* Delivery-mode room pictures (docs/design/delivery-maps.md §5): a room
 * placement drawn in its region's theme, plus its entities (coins, monsters,
 * gate, recipient, station keeper), and a small tile overview for the map
 * preview. Terrain, life and light reuse the approved level renderer
 * (scene.js) unchanged. Entities that have no art yet are drawn as clearly
 * marked placeholders: a letter in a box, never mistaken for final art.
 * Shared by the workbench (browser, classic script) and the Node tools. */
(function (root) {
  "use strict";
  const PB = (root.PB = root.PB || {});
  const S = () => PB.sprites;
  const W = 320, H = 180, HUD_H = 20;

  // Region theme for delivery rooms: the approved theme with the ambient life
  // that looks like a local monster switched off (worlds.json ambient_exclude).
  // Registered at runtime under "<theme>~delivery"; nothing is written to art/.
  function themeId(world) {
    const base = (world && world.theme) || "theme.dungeon", id = base + "~delivery";
    if (!S().has(id) && S().has(base)) {
      const a = S().get(base), drop = new Set((world && world.ambient_exclude) || []);
      S().register(Object.assign({}, a, { id, params: Object.assign({}, a.params, { ambient: (a.params.ambient || []).filter((x) => !drop.has(x.id)) }) }));
    }
    return S().has(id) ? id : base;
  }

  // Lab level spec of a placement for the level renderer, with the player at [x, y].
  function roomSpec(v, player) {
    const rows = v.rows.map((r) => [...r]);
    const [px, py] = player;
    rows[py][px] = rows[py][px] === "H" ? "h" : "P";
    return { format: "pushbox.levelspec/1", id: v.id + (v.mirror ? "~m" : ""), chapter: v.world || "dungeon", map: rows.map((r) => r.join("")), bag: { sand: 0, bomb: 0 }, links: v.links };
  }
  // Where to show the player when nothing else says so: the gate, or the first open exit.
  function defaultPlayer(v) {
    const gate = v.spawns.find((s) => s.feature === "gate");
    if (gate) return [gate.x, gate.y];
    for (const e of PB.rooms.EDGES) if (v.exits[e]) return PB.rooms.innerEntry(e, v.exits[e]);
    return [1, 7];
  }

  // Sprite id each entity uses once its art exists; until then a placeholder.
  const ART = { coin: "item.coin", gate: "mech.ferry_gate", keeper: "npc.turtle_keeper" };
  const MONSTER_ART = (id) => "monster." + id;
  const RECIPIENT_ART = { old_miner: "char.miner" };
  const PLACEHOLDER = { monster: ["A", "t"], gate: ["C", "t"], recipient: ["m", "z"], keeper: ["j", "z"], coin: ["l", "z"] };
  const LETTER = { rat_swarm: "R", skeleton_guard: "S", gate: "G", recipient: "D", keeper: "K", coin: "$" };

  function placeholder(r, kind, id, cx, by) {
    const [fill, ink] = PLACEHOLDER[kind] || ["v", "z"];
    if (kind === "coin") { r.rect(cx - 3, by - 9, 6, 6, "z"); r.rect(cx - 2, by - 8, 4, 4, fill); return; }
    const x = cx - 7, y = by - 14;
    r.rect(x, y, 14, 14, "z"); r.rect(x + 1, y + 1, 12, 12, fill);
    // Diagonal hatch on the corner marks it as a placeholder.
    r.set(x + 1, y + 1, "z"); r.set(x + 2, y + 1, "z"); r.set(x + 1, y + 2, "z");
    const ch = LETTER[id] || LETTER[kind] || "?";
    PB.text.draw(r, ch, cx - (PB.text.measure(ch) >> 1), y, ink);
  }
  function artFor(kind, id, recipient) {
    if (kind === "coin") return ART.coin;
    if (kind === "monster") return MONSTER_ART(id);
    if (kind === "recipient") return RECIPIENT_ART[recipient] || "char." + recipient;
    return ART[kind];
  }
  // Draws one entity standing on tile (tx, ty); returns true if final art was used.
  function drawEntity(r, ox, oy, kind, id, tx, ty, o) {
    const cx = ox + tx * 16 + 8, by = oy + ty * 16 + 16;
    const sid = artFor(kind, id, o && o.recipient);
    if (sid && S().has(sid)) {
      const a = S().get(sid), anim = (o && o.anim) || (a.animations && (a.animations.idle ? "idle" : Object.keys(a.animations)[0]));
      S().draw(r, sid, anim, (o && o.tick) || 0, cx, by, !!(o && o.flip));
      return true;
    }
    placeholder(r, kind, id, cx, by);
    return false;
  }

  // v: a placement (PB.rooms.variant). opts: {world, tick, player, facing,
  // recipient, route: [[x, y], ...], hud: false, env}.
  function render(r, v, opts) {
    const o = opts || {};
    const spec = roomSpec(v, o.player || defaultPlayer(v));
    const at = PB.scene.renderLevel(r, spec, null, { theme: themeId(o.world), tick: o.tick || 0, hud: false, facing: o.facing, env: o.env, pose: "idle" });
    const ox = at.ox, oy = at.oy;
    const used = { placeholders: [] };
    for (const [x, y] of v.coins) if (!drawEntity(r, ox, oy, "coin", "coin", x, y, o)) used.placeholders.push("coin");
    for (const s of v.spawns) {
      const kind = s.monster ? "monster" : s.feature, id = s.monster || s.feature;
      if (!drawEntity(r, ox, oy, kind, id, s.x, s.y, Object.assign({}, o, { flip: s.dir === "left" }))) used.placeholders.push(kind === "recipient" ? "recipient:" + (o.recipient || "?") : id);
    }
    if (o.route) drawRoute(r, ox, oy, o.route);
    if (o.hud !== false) { r.rect(0, 0, W, HUD_H, "z"); r.hline(0, HUD_H - 1, W, "y"); }
    used.placeholders = [...new Set(used.placeholders)];
    return Object.assign({ ox, oy }, used);
  }

  // Dotted line through tile centres (a route from the check report).
  function drawRoute(r, ox, oy, cells) {
    for (let i = 1; i < cells.length; i++) {
      const [x0, y0] = cells[i - 1], [x1, y1] = cells[i];
      const ax = ox + x0 * 16 + 8, ay = oy + y0 * 16 + 9, bx = ox + x1 * 16 + 8, by = oy + y1 * 16 + 9;
      const n = Math.max(Math.abs(bx - ax), Math.abs(by - ay)) || 1;
      for (let k = 0; k <= n; k += 3) r.set(Math.round(ax + ((bx - ax) * k) / n), Math.round(ay + ((by - ay) * k) / n), "l");
    }
    const [lx, ly] = cells[cells.length - 1];
    r.rect(ox + lx * 16 + 6, oy + ly * 16 + 7, 4, 4, "l");
  }
  // Player positions along an action list, replayed in the tile model.
  function routeCells(spec, actions) {
    const res = PB.tilemodel.replay(spec, actions || []);
    return res.steps.map((s) => [s.state.player.x, s.state.player.y]);
  }

  // Tile overview of a placement: s pixels per tile.
  const MINI = { "#": "x", e: "e", s: "c", ".": "y", H: "f", B: "b", I: "v", _: "s", "|": "u" };
  function mini(r, v, x0, y0, s) {
    v.rows.forEach((row, ty) => [...row].forEach((ch, tx) => r.rect(x0 + tx * s, y0 + ty * s, s, s, MINI[ch] || "y")));
    const dot = (tx, ty, c) => r.rect(x0 + tx * s + (s >> 2), y0 + ty * s + (s >> 2), Math.max(1, s >> 1), Math.max(1, s >> 1), c);
    for (const [x, y] of v.coins) dot(x, y, "l");
    for (const sp of v.spawns) r.rect(x0 + sp.x * s, y0 + sp.y * s, s, s, sp.monster ? "A" : sp.feature === "gate" ? "C" : sp.feature === "recipient" ? "m" : "j");
  }

  PB.droom = { themeId, roomSpec, defaultPlayer, render, drawEntity, drawRoute, routeCells, mini, placeholder, W, H, HUD_H };
})(typeof window !== "undefined" ? window : globalThis);
