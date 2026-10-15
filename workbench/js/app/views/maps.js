/* View · Map preview (delivery mode): maps generated from a seed with the same
 * code as tools/check-rooms.mjs and the game (mapgen.js), the room templates
 * and their traversability results. Routes: #maps/<seed>[/<room index>] and
 * #maps/t/<template id>[/<placement key>]. Monsters, the recipient, the keeper
 * and coins are placeholders until their art is approved. */
(function (root) {
  "use strict";
  const PB = root.PB, store = root.PBStore, el = root.PBStage.el;
  const S = 4, GAP = 8, PAD = 8;           // overview: pixels per tile, gap between rooms
  const RW = 20 * S, RH = 10 * S;
  let seed = 1, sel = 0, template = null, placementKey = null, showRoute = true, stage = null;

  const slices = () => store.catalog("slices");
  const slice = () => slices()[0];
  const rooms = () => (store.content().rooms || []);
  const roomById = (id) => rooms().find((r) => r.id === id);
  const world = (id) => store.catalog("worlds").find((w) => w.id === id);
  const sliceTemplates = (sl) => (sl.rooms || []).map(roomById).filter(Boolean).sort((a, b) => a.id.localeCompare(b.id));
  const ROLE = { gate: "渡门", home: "收件人之家", station: "驿站", room: "房间" };
  const EDGE = { left: "左", right: "右", top: "上", bottom: "下" };
  const exitsText = (open) => PB.rooms.EDGES.filter((e) => open[e]).map((e) => EDGE[e] + (open[e] === "low" || open[e] === "mid" ? "" : "·" + open[e])).join(" ") || "—";

  function generate() {
    const sl = slice();
    try { return PB.mapgen.generate(seed, sl, sliceTemplates(sl)); } catch (e) { return { error: e.message }; }
  }
  function placementCheck(t, key) { return t && t.check ? t.check.placements.find((p) => p.key === key) : null; }
  function routeFor(map, r) {
    const prev = map.rooms[r.index - 1], next = map.rooms[r.index + 1];
    const name = (other) => { const e = PB.rooms.edgeToward([r.x, r.y], [other.x, other.y]); return e + "." + r.open[e]; };
    return { from: prev ? name(prev) : "gate", to: next ? name(next) : "recipient" };
  }
  // Player cells of a checked route, replayed in the tile model with the checker's own spec.
  function routeCells(t, v, rt) {
    if (!rt || !rt.ok || !rt.actions) return null;
    let start;
    if (rt.from === "gate") { const g = v.spawns.find((s) => s.feature === "gate"); start = [g.x, g.y]; }
    else { const [e, s] = rt.from.split("."); start = PB.rooms.innerEntry(e, s); }
    return PB.droom.routeCells(PB.rooms.specOf(v, start[0], start[1]), rt.actions);
  }

  // ---------- overview canvas ----------
  function overview(map) {
    const w = PAD * 2 + map.cols * RW + (map.cols - 1) * GAP, h = PAD * 2 + map.rows * RH + (map.rows - 1) * GAP;
    const r = new PB.Raster(w, h);
    r.rect(0, 0, w, h, "z");
    const at = (x, y) => [PAD + x * (RW + GAP), PAD + y * (RH + GAP)];
    for (let y = 0; y < map.rows; y++) for (let x = 0; x < map.cols; x++) {
      const [px, py] = at(x, y), room = PB.mapgen.roomAt(map, x, y);
      if (!room) { r.rect(px, py, RW, RH, "y"); for (let k = 0; k < RW + RH; k += 6) for (let d = 0; d < RH; d++) { const xx = k - d; if (xx >= 0 && xx < RW) r.set(px + xx, py + d, "x"); } continue; }
      const t = roomById(room.template);
      PB.droom.mini(r, PB.rooms.variant(t, room.mirror, room.open), px, py, S);
    }
    // Path links between consecutive rooms, then role tags and the selection frame.
    map.rooms.forEach((room, i) => {
      const next = map.rooms[i + 1]; if (!next) return;
      const [ax, ay] = at(room.x, room.y), [bx, by] = at(next.x, next.y);
      if (room.y === next.y) { const x = Math.max(ax, bx) - GAP, yy = ay + 26; r.rect(x, yy, GAP, 3, "l"); }
      else { const yy = Math.max(ay, by) - GAP; r.rect(ax + 36, yy, 8, GAP, "l"); }
    });
    map.rooms.forEach((room, i) => {
      const [px, py] = at(room.x, room.y), tag = String(i + 1), c = { gate: "C", station: "j", home: "m", room: "w" }[room.role];
      const tw = PB.text.measure(tag) + 4;
      r.rect(px, py, tw, 13, c);
      PB.text.draw(r, tag, px + 2, py - 1, "t");
      if (i === sel) { r.rect(px - 2, py - 2, RW + 4, 2, "s"); r.rect(px - 2, py + RH, RW + 4, 2, "s"); r.rect(px - 2, py, 2, RH, "s"); r.rect(px + RW, py, 2, RH, "s"); }
    });
    return r;
  }

  function show(id) {
    const parts = (id || "").split("/");
    if (parts[0] === "t") { template = parts[1] || null; placementKey = parts[2] ? decodeURIComponent(parts[2]) : null; }
    else { template = null; if (parts[0] && /^\d+$/.test(parts[0])) seed = Number(parts[0]); sel = parts[1] ? Number(parts[1]) : 0; }
    renderSide(); renderWork(); renderInfo();
  }

  function renderSide() {
    const box = document.getElementById("maps-side");
    box.textContent = "";
    const sl = slice();
    if (!sl) { box.append(el("p", { class: "muted", text: "没有可玩切片（content/catalog/slices.json）。" })); return; }
    box.append(el("div", { class: "group-title", text: "切片" }), el("p", { class: "small" }, [el("a", { href: "#catalog/slices", text: sl.name })]));
    box.append(el("div", { class: "group-title", text: "种子" }));
    const input = el("input", { id: "map-seed", type: "number", min: "1", value: String(seed), "aria-label": "地图种子", onchange: () => { location.hash = "#maps/" + Math.max(1, Number(input.value) | 0); } });
    box.append(el("div", { class: "btn-row seed-row" }, [
      el("button", { class: "btn", type: "button", text: "◀", title: "上一个种子", onclick: () => { location.hash = "#maps/" + Math.max(1, seed - 1); } }),
      input,
      el("button", { class: "btn", type: "button", text: "▶", title: "下一个种子", onclick: () => { location.hash = "#maps/" + (seed + 1); } }),
      el("button", { class: "btn", type: "button", text: "随机", onclick: () => { location.hash = "#maps/" + (1 + Math.floor(Math.random() * 99999)); } }),
    ]));
    const routeBtn = el("button", { class: "btn", type: "button", "aria-pressed": String(showRoute), text: "显示路线", title: "检查工具在格子模型里找到的路线（不含怪物）", onclick: () => { showRoute = !showRoute; routeBtn.setAttribute("aria-pressed", String(showRoute)); if (stage) stage.refresh(); } });
    box.append(el("p", {}, [routeBtn]));
    box.append(el("div", { class: "group-title", text: "房间模板" }));
    for (const t of sliceTemplates(sl)) {
      const ok = t.check && !t.check.errors.length && t.check.placements.every((p) => p.ok);
      box.append(el("button", { class: "list-btn", type: "button", "aria-current": String(template === t.id), onclick: () => { location.hash = "#maps/t/" + t.id; } }, [
        el("span", { text: t.name }), el("span", { class: "badge " + (ok ? "approved" : "no"), text: ok ? "通过" : "未通过" })]));
    }
    box.append(el("p", { class: "small muted", text: "模板在 content/rooms/<地区>/，检查结果在 content/rooms-check.generated.json（node tools/check-rooms.mjs --write）。" }));
  }

  function renderWork() {
    const box = document.getElementById("maps-work");
    box.textContent = "";
    if (stage) { stage.destroy(); stage = null; }
    const sl = slice();
    if (!sl) return;
    const w = world(sl.world);
    if (template) return renderTemplate(box, sl, w);
    const map = generate();
    if (map.error) { box.append(el("p", { class: "note", text: "这个种子生成失败：" + map.error })); return; }
    sel = Math.min(Math.max(0, sel), map.rooms.length - 1);
    box.append(el("h2", { text: `种子 ${seed} · ${map.dir === "down" ? "由上往下" : "由下往上"} · 主路径 ${map.rooms.length} 间` }));
    const ov = overview(map), cv = el("canvas", { class: "map-overview", width: ov.w, height: ov.h, "aria-label": "地图总览：点房间查看" });
    cv.getContext("2d").putImageData(new ImageData(ov.data, ov.w, ov.h), 0, 0);
    cv.style.width = ov.w * 2 + "px";
    cv.addEventListener("click", (ev) => {
      const b = cv.getBoundingClientRect(), x = ((ev.clientX - b.left) / b.width) * ov.w, y = ((ev.clientY - b.top) / b.height) * ov.h;
      const cx = Math.floor((x - PAD) / (RW + GAP)), cy = Math.floor((y - PAD) / (RH + GAP));
      const room = PB.mapgen.roomAt(map, cx, cy);
      if (room) location.hash = `#maps/${seed}/${room.index}`;
    });
    box.append(el("div", { class: "map-frame" }, [cv]));
    const room = map.rooms[sel], t = roomById(room.template), v = PB.rooms.variant(t, room.mirror, room.open);
    const pc = placementCheck(t, PB.rooms.placementKey(room.template, room.mirror, room.open));
    const want = routeFor(map, room), rt = pc && pc.routes.find((x) => x.from === want.from && x.to === want.to);
    const cells = routeCells(t, v, rt);
    box.append(el("h3", { text: `第 ${sel + 1} 间 · ${ROLE[room.role]} · ${t.name}${room.mirror ? "（翻转）" : ""}` }));
    const host = el("div", { class: "stage-host" });
    box.append(host);
    stage = root.PBStage.create(host, {
      width: 320, height: 180, animated: true, autoplay: true, label: t.name, maxHeight: 420,
      draw: (r, tick) => { const res = PB.droom.render(r, v, { world: w, tick, player: cells ? cells[0] : undefined, route: showRoute ? cells : null, recipient: room.role === "home" ? "old_miner" : undefined }); lastPlaceholders = res.placeholders; },
      disclaimer: "地形、生态与光照用已确认的主题；怪物（R 鼠群、S 骷髅守卫）、渡门 G、收件人 D、龟掌柜 K、金币 $ 是占位，美术在第 4 步。黄色虚线是检查工具在格子模型里找到的路线：不含怪物与时间。",
    });
  }
  let lastPlaceholders = [];

  function renderTemplate(box, sl, w) {
    const t = roomById(template);
    if (!t) { box.append(el("p", { class: "muted", text: "没有这个房间模板。" })); return; }
    const pls = (t.check && t.check.placements) || [];
    const p = pls.find((x) => x.key === placementKey) || pls[0];
    box.append(el("h2", { text: `${t.name} · ${t.id}` }), el("p", { text: t.idea || "" }));
    const v = p ? PB.rooms.variant(t, p.mirror, p.open) : PB.rooms.variant(t, false, null);
    const rt = p && p.routes[0], cells = rt ? routeCells(t, v, rt) : null;
    const host = el("div", { class: "stage-host" });
    box.append(host);
    stage = root.PBStage.create(host, { width: 320, height: 180, animated: true, autoplay: true, label: t.name, maxHeight: 420,
      draw: (r, tick) => PB.droom.render(r, v, { world: w, tick, player: cells ? cells[0] : undefined, route: showRoute ? cells : null, recipient: "old_miner" }),
      disclaimer: "占位：R 鼠群、S 骷髅守卫、G 渡门、D 收件人、K 龟掌柜、$ 金币。黄色虚线 = 下表第一条路线。" });
    const table = el("table", { class: "grid" });
    table.append(el("thead", {}, [el("tr", {}, ["摆法", "翻转", "出入口", "路线", "步数", "要挖", "参考用时", ""].map((x) => el("th", { text: x })))]));
    const tb = el("tbody");
    for (const q of pls) for (const [i, r] of q.routes.entries()) tb.append(el("tr", { "aria-current": String(p && q.key === p.key && i === 0) }, [
      el("td", { class: "mono small", text: i === 0 ? q.key : "" }), el("td", { text: i === 0 ? (q.mirror ? "是" : "否") : "" }), el("td", { text: i === 0 ? exitsText(q.open) : "" }),
      el("td", { text: `${r.from} → ${r.to}` }), el("td", { text: r.ok ? String(r.steps) : "走不通" }), el("td", { text: r.needs_dig ? "是" : "" }), el("td", { text: r.par_secs != null ? r.par_secs + " 秒" : "—" }),
      el("td", {}, i === 0 ? [el("a", { class: "btn small", href: "#maps/t/" + t.id + "/" + encodeURIComponent(q.key), text: "看" })] : []),
    ]));
    table.append(tb);
    box.append(table);
  }

  function renderInfo() {
    const box = document.getElementById("maps-info");
    box.textContent = "";
    const sl = slice();
    if (!sl) return;
    if (template) {
      const t = roomById(template);
      if (!t) return;
      box.append(el("h2", { text: t.name }), el("p", { class: "small mono", text: `room:${t.id} · ${t.file}` }));
      box.append(el("dl", { class: "meta" }, [
        el("dt", { text: "类型" }), el("dd", { text: ROLE[t.type] }),
        el("dt", { text: "出入口" }), el("dd", { text: Object.entries(t.exits).map(([e, s]) => EDGE[e] + "（" + s.join("、") + "）").join(" ") }),
        el("dt", { text: "单向" }), el("dd", { text: t.routes ? t.routes.join("、") : "否" }),
        el("dt", { text: "可以翻转" }), el("dd", { text: t.mirror ? "是" : "否" }),
        el("dt", { text: "权重" }), el("dd", { text: String(t.weight || 10) }),
        el("dt", { text: "机制" }), el("dd", {}, (t.mechanisms || []).map(root.PBContentUI.mechChip)),
      ]));
      if (t.notes) box.append(el("p", { class: "small", text: t.notes }));
      const c = t.check;
      box.append(el("h3", { text: "检查" }), el("p", { class: "small", text: c ? (c.errors.length ? "静态检查有错：" + c.errors.join("；") : `${c.placements.length} 种摆法、${c.placements.reduce((n, p) => n + p.routes.length, 0)} 条路线，全部${c.placements.every((p) => p.ok) ? "走得通" : "检查过（有走不通的）"}。`) : "还没有检查结果。" }));
      for (const w of (c && c.warnings) || []) box.append(el("p", { class: "small muted", text: "提醒：" + w }));
      return;
    }
    const map = generate();
    if (map.error) return;
    const par = map.rooms.reduce((n, r) => { const t = roomById(r.template), pc = placementCheck(t, PB.rooms.placementKey(r.template, r.mirror, r.open)), want = routeFor(map, r), rt = pc && pc.routes.find((x) => x.from === want.from && x.to === want.to); return n + (rt && rt.par_secs ? rt.par_secs : 0); }, 0);
    box.append(el("h2", { text: "这张地图" }), el("dl", { class: "meta" }, [
      el("dt", { text: "种子" }), el("dd", { class: "mono", text: String(seed) }),
      el("dt", { text: "大小" }), el("dd", { text: `${map.cols} × ${map.rows} 个房间` }),
      el("dt", { text: "方向" }), el("dd", { text: map.dir === "down" ? "由上往下" : "由下往上" }),
      el("dt", { text: "主路径" }), el("dd", { text: `${map.rooms.length} 间（第 ${map.attempt + 1} 次尝试）` }),
      el("dt", { text: "参考用时" }), el("dd", { text: `${par} 秒（只算走路，不含怪物、驿站、绕路）` }),
    ]));
    const table = el("table", { class: "grid" });
    table.append(el("thead", {}, [el("tr", {}, ["#", "作用", "模板", "出入口"].map((x) => el("th", { text: x })))]));
    const tb = el("tbody");
    for (const r of map.rooms) {
      const t = roomById(r.template);
      tb.append(el("tr", { "aria-current": String(r.index === sel) }, [el("td", {}, [el("a", { href: `#maps/${seed}/${r.index}`, text: String(r.index + 1) })]), el("td", { text: ROLE[r.role] }),
        el("td", {}, [el("a", { href: "#maps/t/" + t.id, text: t.name + (r.mirror ? "（翻）" : "") })]), el("td", { text: exitsText(r.open) })]));
    }
    table.append(tb);
    box.append(table);
    const room = map.rooms[sel], t = roomById(room.template);
    box.append(el("h3", { text: t.name }), el("p", { class: "small", text: t.idea || "" }));
    box.append(el("p", { class: "note small", text: "同一个种子在工作台、tools/check-rooms.mjs 和游戏里必须生成同一张图；前 30 个种子的结果写在 content/export/delivery-golden.json，供游戏对照。" }));
  }

  root.PBMaps = { show, hide: () => stage && stage.setVisible(false), placeholders: () => lastPlaceholders };
})(window);
