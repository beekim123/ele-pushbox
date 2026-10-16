#!/usr/bin/env node
// Content pipeline: check | build. Node 18+, no dependencies.
// Catalogs (content/catalog), level specs (content/levels), art sources and the
// Godot verification report are cross-checked; statuses are derived from data,
// never written by hand. See docs/design/workbench.md.
// Pass --root <dir> to run against a copy (tests must not touch the repository).
import crypto from "node:crypto";
import fs from "node:fs";
import path from "node:path";
import { fileURLToPath, pathToFileURL } from "node:url";
import { buildIdMap } from "./lib/ids.mjs";
import { loadRooms } from "./check-rooms.mjs";
import { loadTextTables } from "./lib/i18n.mjs";

const REPO = path.resolve(path.dirname(fileURLToPath(import.meta.url)), "..");
export const CATALOGS = ["modes", "groups", "mechanisms", "worlds", "recipients", "cargo", "combos", "monsters", "items", "buffs", "upgrades", "badges", "events", "slices"];
const sha = (buf) => crypto.createHash("sha256").update(buf).digest("hex");
const readJson = (p) => JSON.parse(fs.readFileSync(p, "utf8"));
function walk(dir) {
  if (!fs.existsSync(dir)) return [];
  return fs.readdirSync(dir, { withFileTypes: true }).sort((a, b) => a.name.localeCompare(b.name))
    .flatMap((e) => (e.isDirectory() ? walk(path.join(dir, e.name)) : e.name.endsWith(".json") ? [path.join(dir, e.name)] : []));
}

// A level counts as verified only when every condition in workbench.md §4 holds.
function verdict(r, specSha) {
  if (!r) return null;
  const checks = r.checks || [];
  const stale = r.spec_sha256 !== undefined && r.spec_sha256 !== specSha;
  const ok = !stale && r.won === true && r.consistent === true && r.undo_ok === true && (r.replays | 0) >= 3 &&
    typeof r.max_ticks === "number" && typeof r.tick_limit === "number" && r.max_ticks < r.tick_limit && checks.every((c) => c.ok === true);
  return { ok, replays: r.replays | 0, max_ticks: r.max_ticks, tick_limit: r.tick_limit, failed: [...checks.filter((c) => c.ok !== true).map((c) => c.text), ...(stale ? ["SDK 报告与当前规格 SHA 不一致，需要重测"] : [])] };
}

export function buildContent(root, opts = {}) {
  const rel = (...p) => path.join(root, ...p);
  const issues = [];
  const add = (level, where, msg) => issues.push({ level, where, msg });

  // ---- catalogs ----
  const cat = {}, notes = {};
  for (const name of CATALOGS) {
    const p = rel("content/catalog", name + ".json");
    cat[name] = [];
    if (!fs.existsSync(p)) { add("error", `content/catalog/${name}.json`, "目录文件缺失"); continue; }
    let doc;
    try { doc = readJson(p); } catch (e) { add("error", `content/catalog/${name}.json`, "不是合法 JSON：" + e.message); continue; }
    if (doc.format !== "pushbox.catalog/1" || doc.kind !== name) add("error", `content/catalog/${name}.json`, "format 应为 pushbox.catalog/1，kind 应为 " + name);
    const seen = new Set();
    for (const e of doc.entries || []) {
      if (!e.id || !/^[a-z0-9_-]+$/.test(e.id)) add("error", `${name}`, `编号不合法：${JSON.stringify(e.id)}`);
      else if (seen.has(e.id)) add("error", `${name}/${e.id}`, "编号重复");
      seen.add(e.id);
    }
    cat[name] = doc.entries || [];
    notes[name] = doc.note || "";
  }
  const byId = (list) => new Map(list.map((e) => [e.id, e]));
  const modes = byId(cat.modes), groups = byId(cat.groups), mechs = byId(cat.mechanisms);

  // ---- art: which assets exist and which current versions are approved ----
  const art = new Map();
  const artFile = new Map();
  for (const f of walk(rel("art/source"))) { try { const a = readJson(f); art.set(a.id, a); artFile.set(a.id, path.relative(root, f).split(path.sep).join("/")); } catch (e) { /* art.mjs reports broken sources */ } }
  const approvals = fs.existsSync(rel("art/approvals.json")) ? readJson(rel("art/approvals.json")).records : [];
  const approved = (id) => { const a = art.get(id); return !!a && approvals.some((r) => r.items.some((it) => it.asset === id && it.version === a.version && it.hash === a.content_hash)); };

  // ---- level specs, design-model results, Godot verification report ----
  const specs = new Map();
  for (const f of walk(rel("content/levels"))) {
    let s; try { s = readJson(f); } catch (e) { add("error", path.relative(root, f), "不是合法 JSON"); continue; }
    if (s.format !== "pushbox.levelspec/1") continue;
    const file = path.relative(root, f).split(path.sep).join("/");
    if (specs.has(s.id)) add("error", file, `关卡编号 ${s.id} 重复（另见 ${specs.get(s.id).file}）`);
    specs.set(s.id, { spec: s, file, sha256: sha(fs.readFileSync(f)) });
  }
  const model = new Map();
  if (fs.existsSync(rel("content/model-check.generated.json"))) for (const l of readJson(rel("content/model-check.generated.json")).levels || []) model.set(l.id, l);
  let report = null;
  const rp = rel("game/reports/verification.json");
  if (fs.existsSync(rp)) {
    try { report = readJson(rp); } catch (e) { add("error", "game/reports/verification.json", "不是合法 JSON"); }
    if (report && report.format !== "pushbox.verification/1") { add("error", "game/reports/verification.json", "format 应为 pushbox.verification/1"); report = null; }
  }
  const results = new Map((report && report.levels || []).map((r) => [r.id, r]));

  // ---- groups and the level plan ----
  const planned = new Map();
  for (const g of cat.groups) {
    if (!modes.has(g.mode)) add("error", `groups/${g.id}`, `模式 ${g.mode} 不在 modes.json 中`);
    if (!art.has(g.theme)) add("error", `groups/${g.id}`, `主题 ${g.theme} 不是已有的美术资产`);
    for (const l of g.levels || []) {
      if (planned.has(l.id)) add("error", `groups/${g.id}/${l.id}`, `关卡编号重复（另见 ${planned.get(l.id).group.id}）`);
      planned.set(l.id, { plan: l, group: g });
      for (const m of l.mechanisms || []) if (!mechs.has(m)) add("error", `groups/${g.id}/${l.id}`, `机制 ${m} 不在机制目录中`);
      if (!(l.mechanisms || []).length) add("error", `groups/${g.id}/${l.id}`, "没有写演示的机制");
    }
  }
  for (const [id, { spec: s, file }] of specs) {
    const p = planned.get(id);
    if (!p) { add("warn", file, "关卡规格不在 groups.json 的关卡计划中"); continue; }
    const want = `content/levels/${p.group.mode}/${p.group.id}/${id}.json`;
    if (file !== want) add("error", file, `规格应放在 ${want}`);
    if (s.mode !== p.group.mode || s.group !== p.group.id) add("error", file, `mode / group 应为 ${p.group.mode} / ${p.group.id}`);
    const a = (s.mechanisms || []).slice().sort().join(","), b = (p.plan.mechanisms || []).slice().sort().join(",");
    if (a !== b) add("error", file, `mechanisms（${a || "空"}）与关卡计划（${b}）不一致`);
    if (s.title !== p.plan.title) add("warn", file, `标题「${s.title}」与关卡计划「${p.plan.title}」不同`);
  }

  // ---- mechanisms ----
  for (const m of cat.mechanisms) {
    if (!groups.has(m.group)) add("error", `mechanisms/${m.id}`, `组 ${m.group} 不在 groups.json 中`);
    if (!["sdk", "game", "both"].includes(m.owner)) add("error", `mechanisms/${m.id}`, "owner 只能是 sdk、game、both");
    for (const a of m.assets || []) if (!art.has(a)) add("error", `mechanisms/${m.id}`, `美术资产 ${a} 不存在`);
  }
  // ---- design data (delivery mode and beyond) ----
  const worlds = byId(cat.worlds), recipients = byId(cat.recipients), cargo = byId(cat.cargo);
  for (const w of cat.worlds) {
    if (w.theme && !art.has(w.theme)) add("error", `worlds/${w.id}`, `主题 ${w.theme} 不是已有的美术资产`);
    const life = w.theme && art.has(w.theme) ? ((art.get(w.theme).params || {}).ambient || []).map((a) => a.id) : [];
    for (const id of w.ambient_exclude || []) if (!life.includes(id)) add("error", `worlds/${w.id}`, `ambient_exclude 的 ${id} 不在主题 ${w.theme} 的生态里`);
    for (const m of w.mechanisms || []) if (!mechs.has(m)) add("error", `worlds/${w.id}`, `机制 ${m} 不在机制目录中`);
  }
  for (const r of cat.recipients) {
    if (!(r.worlds || []).length) add("error", `recipients/${r.id}`, "没有写去哪个地区");
    for (const w of r.worlds || []) if (!worlds.has(w)) add("error", `recipients/${r.id}`, `地区 ${w} 不在 worlds.json 中`);
    for (const c of r.likes || []) if (!cargo.has(c)) add("error", `recipients/${r.id}`, `喜欢的货物 ${c} 不在 cargo.json 中`);
  }
  for (const x of cat.combos) {
    if (!cargo.has(x.cargo)) add("error", `combos/${x.id}`, `货物 ${x.cargo} 不在 cargo.json 中`);
    if (!recipients.has(x.recipient)) add("error", `combos/${x.id}`, `收件人 ${x.recipient} 不在 recipients.json 中`);
  }
  for (const mo of cat.monsters) if (mo.world && !worlds.has(mo.world)) add("error", `monsters/${mo.id}`, `地区 ${mo.world} 不在 worlds.json 中`);
  for (const m of cat.mechanisms) if (m.origin && !["delivery", "sdk"].includes(m.origin) && !worlds.has(m.origin)) add("error", `mechanisms/${m.id}`, `来源 ${m.origin} 不是地区，也不是 delivery / sdk`);
  for (const kind of ["items", "cargo"]) for (const e of cat[kind]) {
    for (const a of e.assets || []) if (!art.has(a)) add("error", `${kind}/${e.id}`, `美术资产 ${a} 不存在`);
    for (const m of e.mechanisms || []) if (!mechs.has(m)) add("error", `${kind}/${e.id}`, `机制 ${m} 不在机制目录中`);
    if (e.mode && !modes.has(e.mode)) add("error", `${kind}/${e.id}`, `模式 ${e.mode} 不存在`);
  }
  // Playable slices (docs/design/delivery-slice.md): one run configuration each.
  const monsters = byId(cat.monsters), items = byId(cat.items);
  for (const sl of cat.slices) {
    const at = `slices/${sl.id}`;
    if (!modes.has(sl.mode)) add("error", at, `模式 ${sl.mode} 不存在`);
    if (!worlds.has(sl.world)) add("error", at, `地区 ${sl.world} 不在 worlds.json 中`);
    for (const c of sl.cargo || []) {
      const e = cargo.get(c);
      if (!e) add("error", at, `货物 ${c} 不在 cargo.json 中`);
      else if (!e.params || typeof e.params.pay !== "number") add("error", at, `货物 ${c} 缺少 params.pay（基础报酬）`);
    }
    for (const r of sl.recipients || []) {
      const e = recipients.get(r);
      if (!e) add("error", at, `收件人 ${r} 不在 recipients.json 中`);
      else if (!(e.worlds || []).includes(sl.world)) add("error", at, `收件人 ${r} 不住在 ${sl.world}`);
      else if (!e.params || !e.params.move) add("error", at, `收件人 ${r} 缺少 params.move`);
    }
    for (const m of sl.monsters || []) {
      const e = monsters.get(m);
      if (!e) add("error", at, `怪物 ${m} 不在 monsters.json 中`);
      else if (e.world !== sl.world) add("error", at, `怪物 ${m} 属于 ${e.world}，不是 ${sl.world}`);
      else if (!e.params || !e.params.move || !(e.params.step_secs > 0)) add("error", at, `怪物 ${m} 缺少 params.move / step_secs`);
    }
    for (const m of sl.mechanisms || []) if (!mechs.has(m)) add("error", at, `机制 ${m} 不在机制目录中`);
    const st = sl.station || {};
    for (const it of st.items || []) if (!items.has(it)) add("error", at, `驿站商品 ${it} 不在 items.json 中`);
    for (const it of Object.keys(st.stock || {})) if (!(st.items || []).includes(it)) add("error", at, `库存 ${it} 不是驿站商品`);
    if (!sl.cargo || !sl.cargo.length || !sl.recipients || !sl.recipients.length) add("error", at, "两个滚轮都至少要有一个符号");
    if (!sl.time || !(sl.time.tick_hz > 0)) add("error", at, "time.tick_hz 必须大于 0");
  }

  // ---- delivery room templates (docs/design/delivery-maps.md) ----
  const rooms = loadRooms(root), roomById = new Map();
  for (const { file, room: t } of rooms) {
    const at = file;
    if (roomById.has(t.id)) add("error", at, `房间编号 ${t.id} 重复（另见 ${roomById.get(t.id).file}）`);
    roomById.set(t.id, { file, room: t });
    if (!worlds.has(t.world)) add("error", at, `地区 ${t.world} 不在 worlds.json 中`);
    else if (file !== `content/rooms/${t.world}/${t.id}.json`) add("error", at, `房间模板应放在 content/rooms/${t.world}/${t.id}.json`);
    for (const m of t.mechanisms || []) if (!mechs.has(m)) add("error", at, `机制 ${m} 不在机制目录中`);
    for (const [k, e] of Object.entries(t.legend || {})) if (e.monster && !monsters.has(e.monster)) add("error", at, `legend ${k} 的怪物 ${e.monster} 不在 monsters.json 中`);
  }
  let roomCheck = null;
  const rcp = rel("content/rooms-check.generated.json");
  if (fs.existsSync(rcp)) { try { roomCheck = readJson(rcp); } catch (e) { add("error", "content/rooms-check.generated.json", "不是合法 JSON"); } }
  const checked = new Map(((roomCheck && roomCheck.templates) || []).map((t) => [t.id, t]));
  for (const { file, sha256, room: t } of rooms) {
    const c = checked.get(t.id);
    if (!c || c.sha256 !== sha256) { add("error", file, "可通性检查结果缺失或已过期：运行 node tools/check-rooms.mjs --write"); continue; }
    for (const e of c.errors) add("error", file, e);
    for (const p of c.placements) for (const r of p.routes) if (!r.ok) add("error", file, `${p.key}：${r.from} → ${r.to} 走不通`);
    for (const d of c.demos || []) if (!d.ok) add("error", file, `演示 ${d.id}${d.mirror ? "（翻转）" : ""} 没有达到预期：${d.failures.join("；")}`);
  }
  for (const sl of cat.slices) {
    const at = `slices/${sl.id}`;
    for (const id of sl.rooms || []) {
      const r = roomById.get(id);
      if (!r) add("error", at, `房间模板 ${id} 不存在（content/rooms/）`);
      else if (r.room.world !== sl.world) add("error", at, `房间模板 ${id} 属于 ${r.room.world}，不是 ${sl.world}`);
    }
    if (sl.rooms) for (const ty of ["gate", "home", "station", "room"]) if (!sl.rooms.some((id) => roomById.has(id) && roomById.get(id).room.type === ty)) add("error", at, `没有 ${ty} 类型的房间模板`);
    const cs = ((roomCheck && roomCheck.slices) || []).find((x) => x.id === sl.id);
    if (sl.rooms && sl.rooms.length && (!cs || !cs.ok)) add("error", at, cs ? "按种子生成的地图没有全部通过检查：" + (cs.failures[0] || "") : "还没有地图检查结果：运行 node tools/check-rooms.mjs --write");
  }

  // ---- derived statuses ----
  const levelAssets = (l, g) => [...new Set([g.theme, ...(l.mechanisms || []).flatMap((m) => (mechs.get(m) || {}).assets || [])])];
  const levels = [];
  for (const g of cat.groups.slice().sort((a, b) => (modes.get(a.mode) || {}).order - (modes.get(b.mode) || {}).order || a.order - b.order)) {
    for (const [i, l] of (g.levels || []).entries()) {
      const sp = specs.get(l.id), hasSpec = !!sp && Array.isArray(sp.spec.map) && sp.spec.map.length > 0;
      const mc = model.get(l.id), assets = levelAssets(l, g);
      levels.push({
        id: l.id, mode: g.mode, group: g.id, order: i + 1, title: l.title, role: l.role, discovery: l.discovery, mechanisms: l.mechanisms,
        spec: sp ? sp.file : null, sha256: sp ? sp.sha256 : null, has_spec: hasSpec,
        model: mc ? { ok: !!mc.author_ok && mc.author_steps === mc.shortest, author_steps: mc.author_steps, shortest: mc.shortest } : null,
        verified: verdict(results.get(l.id), sp ? sp.sha256 : null),
        art: { assets, missing: assets.filter((a) => !approved(a)) },
      });
    }
  }
  // Delivery-only mechanisms (monsters) have no turn-based lab level: the room demos
  // play that part (docs/design/delivery-realtime.md): a demo in the design model
  // = specified; the Godot report's `demos` entry passing = verified.
  const roomDemos = [];
  for (const { room: t } of rooms) for (const d of t.demos || []) {
    const c = checked.get(t.id), res = c ? (c.demos || []).filter((x) => x.id === d.id) : [];
    const godot = report ? (report.demos || []).filter((x) => x.template === t.id && x.demo === d.id) : [];
    roomDemos.push({ template: t.id, id: d.id, mechanisms: d.mechanisms || [], model_ok: res.length > 0 && res.every((x) => x.ok), verified: godot.length > 0 && godot.every((x) => x.ok === true) });
  }
  const mechanisms = cat.mechanisms.map((m) => {
    if (m.origin === "delivery") {
      const ds = roomDemos.filter((d) => d.mechanisms.includes(m.id)), missingArt = (m.assets || []).filter((a) => !approved(a));
      let status = "proposed";
      if (ds.length) status = "designed";
      if (ds.length && ds.every((d) => d.model_ok)) status = "specified";
      if (status === "specified" && ds.every((d) => d.verified)) status = "verified";
      if (status === "verified" && !missingArt.length) status = "playable";
      return Object.assign({}, m, { status, levels: [], demos: ds.map((d) => d.template + "/" + d.id), missing_art: missingArt });
    }
    const ls = levels.filter((l) => l.mode === "lab" && l.mechanisms.includes(m.id));
    const missingArt = (m.assets || []).filter((a) => !approved(a));
    let status = "proposed";
    if (ls.length) status = "designed";
    if (ls.length && ls.every((l) => l.has_spec)) status = "specified";
    if (status === "specified" && ls.every((l) => l.verified && l.verified.ok)) status = "verified";
    if (status === "verified" && !missingArt.length) status = "playable";
    return Object.assign({}, m, { status, levels: ls.map((l) => l.id), missing_art: missingArt });
  });
  for (const m of mechanisms) if (m.status !== "proposed" && !m.levels.length && m.origin !== "delivery") add("warn", `mechanisms/${m.id}`, "没有关卡模式的关卡");
  for (const id of results.keys()) if (!planned.has(id)) add("warn", "game/reports/verification.json", `报告里的关卡 ${id} 不在关卡计划中`);

  // ---- global ids and the workbench -> game map (docs/design/ids.md) ----
  // Text keys from content/i18n and the content/i18n-<name> tables (tools/lib/i18n.mjs).
  let texts = {}, textSource = {};
  if (fs.existsSync(rel("content/i18n/zh-Hans.json"))) {
    try { const t = loadTextTables(root); texts = t.tables["zh-Hans"]; textSource = t.source; for (const q of t.problems) add("error", q.where, q.msg); }
    catch (e) { add("error", "content/i18n", e.message); }
  }
  const ids = buildIdMap({
    art: [...art.values()].map((a) => Object.assign({}, a, { file: artFile.get(a.id), approved: approved(a.id) })).sort((a, b) => a.id.localeCompare(b.id)),
    levels: levels.map((l) => ({ id: l.id, title: l.title, spec: l.has_spec ? l.spec : null, sha256: l.sha256 })),
    rooms: rooms.map(({ file, sha256, room }) => ({ id: room.id, name: room.name, source: file, sha256 })),
    catalogs: cat, texts, textSource,
  });
  issues.push(...ids.issues);

  const summary = {
    errors: issues.filter((i) => i.level === "error").length, warnings: issues.filter((i) => i.level === "warn").length,
    report: report ? { generated: report.generated || null, commit: report.commit || null, sdk: report.sdk || null, levels: (report.levels || []).length, samples: report.samples || [], references: report.references || [] } : null,
  };
  const roomData = rooms.map(({ file, sha256, room }) => Object.assign({}, room, { file, sha256, check: checked.get(room.id) || null }));
  const result = { catalogs: cat, notes, levels, mechanisms, issues, summary, ids: ids.map, rooms: roomData, roomSlices: (roomCheck && roomCheck.slices) || [] };

  if (opts.write) {
    // Godot reads only this manifest for modes, groups, level order and spec hashes.
    if (!summary.errors) {
      const manifest = {
        format: "pushbox.content-manifest/1",
        note: "Generated by `node tools/content.mjs build`. Godot loads modes, groups and levels from here and must check each spec file against sha256.",
        modes: cat.modes,
        groups: cat.groups.map((g) => ({ id: g.id, mode: g.mode, order: g.order, name: g.name, theme: g.theme, sdk_profile: g.sdk_profile, hidden: !!g.hidden,
          levels: levels.filter((l) => l.group === g.id).map((l) => ({ id: l.id, title: l.title, mechanisms: l.mechanisms, spec: l.has_spec ? l.spec : null, sha256: l.has_spec ? l.sha256 : null })) })),
        mechanisms: mechanisms.map((m) => ({ id: m.id, name: m.name, group: m.group, owner: m.owner, sdk: m.sdk, levels: m.levels, status: m.status })),
        worlds: cat.worlds, recipients: cat.recipients, cargo: cat.cargo, combos: cat.combos, monsters: cat.monsters,
        items: cat.items, buffs: cat.buffs, upgrades: cat.upgrades, badges: cat.badges, events: cat.events, slices: cat.slices,
        rooms: rooms.map(({ file, sha256, room }) => ({ id: room.id, world: room.world, type: room.type, spec: file, sha256 })),
        delivery_golden: fs.existsSync(rel("content/export/delivery-golden.json")) ? "content/export/delivery-golden.json" : null,
      };
      fs.mkdirSync(rel("content/export"), { recursive: true });
      fs.writeFileSync(rel("content/export/content-manifest.json"), JSON.stringify(manifest, null, 1) + "\n");
      fs.writeFileSync(rel("content/export/id-map.json"), JSON.stringify(ids.map, null, 1) + "\n");
    }
    fs.mkdirSync(rel("workbench/data"), { recursive: true });
    fs.writeFileSync(rel("workbench/data/content.js"), "/* Generated by `node tools/content.mjs build`. Do not edit. */\nwindow.PB_CONTENT = " + JSON.stringify(result) + ";\n");
  }
  return result;
}

export function printIssues(res) {
  for (const i of res.issues) console.log(`${i.level === "error" ? "ERROR" : i.level === "warn" ? "warn " : "info "} ${i.where}: ${i.msg}`);
  const st = {}; for (const m of res.mechanisms) st[m.status] = (st[m.status] || 0) + 1;
  console.log(`content: ${res.summary.errors} error(s), ${res.summary.warnings} warning(s); ${res.levels.length} planned levels, ${res.levels.filter((l) => l.has_spec).length} with specs; mechanisms ${Object.entries(st).map(([k, v]) => k + " " + v).join(", ")}; verification report ${res.summary.report ? "present" : "absent"}`);
}

if (process.argv[1] && import.meta.url === pathToFileURL(process.argv[1]).href) {
  const argv = process.argv.slice(2), cmd = argv[0];
  const i = argv.indexOf("--root"), root = path.resolve(i >= 0 ? argv[i + 1] : REPO);
  if (cmd !== "check" && cmd !== "build") { console.log("usage: node tools/content.mjs check|build [--root dir]"); process.exit(2); }
  const res = buildContent(root, { write: cmd === "build" });
  printIssues(res);
  process.exit(res.summary.errors ? 1 : 0);
}
