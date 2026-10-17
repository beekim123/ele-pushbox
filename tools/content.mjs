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
import { loadRooms2, poolInput } from "./check-rooms2.mjs";
import { loadTextTables } from "./lib/i18n.mjs";
import { sourceHash } from "./lib/audio.mjs";

const REPO = path.resolve(path.dirname(fileURLToPath(import.meta.url)), "..");
export const CATALOGS = ["modes", "groups", "mechanisms", "worlds", "recipients", "cargo", "combos", "monsters", "items", "buffs", "upgrades", "badges", "events", "slices", "audio"];
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

// Audio uses the ordinary catalog envelope but also owns sets, policy and routing.
// Keep all checks here: a successful generic catalog pass must not imply that
// the audio references and safety policy have been checked.
function checkAudioCatalog(doc, catalogs, specs, add) {
  const at = "audio", localId = /^[a-z0-9_-]+$/;
  const object = (v) => v !== null && typeof v === "object" && !Array.isArray(v);
  const fail = (where, msg) => add("error", where, msg);
  const list = (v, p) => { if (!Array.isArray(v)) { fail(p, "必须是数组"); return []; } return v; };
  const record = (v, p) => { if (!object(v)) { fail(p, "必须是对象"); return {}; } return v; };
  const text = (v, p) => { if (typeof v !== "string" || !v.trim()) fail(p, "必须是非空字符串"); };
  const number = (v, p, min, max, integer = false) => { if (!Number.isFinite(v) || v < min || v > max || (integer && !Number.isInteger(v))) fail(p, `必须是 ${min}–${max} 的${integer ? "整数" : "有限数值"}`); };
  const canonical = (v) => Array.isArray(v) ? v.map(canonical) : object(v) ? Object.fromEntries(Object.keys(v).sort().map(k => [k, canonical(v[k])])) : v;
  const exact = (v, expected, p) => { if (JSON.stringify(canonical(v)) !== JSON.stringify(canonical(expected))) fail(p, `必须为 ${JSON.stringify(expected)}`); };
  const known = (v, keys, p) => { for (const k of Object.keys(v)) if (!keys.includes(k)) fail(`${p}.${k}`, "未知字段"); };
  doc = record(doc, at);
  exact(doc.format, "pushbox.catalog/1", `${at}.format`); exact(doc.kind, "audio", `${at}.kind`);
  known(doc, ["format", "kind", "note", "policy", "routes", "pending_references", "music_sets", "entries"], at);
  const entries = list(doc.entries, `${at}.entries`), sets = list(doc.music_sets, `${at}.music_sets`);
  const policy = record(doc.policy, `${at}.policy`), routes = record(doc.routes, `${at}.routes`);
  const pending = list(doc.pending_references, `${at}.pending_references`);
  const byUid = new Map(), setByUid = new Map(), seen = new Set();
  const identity = (e, kind, p) => {
    if (typeof e.id !== "string" || !localId.test(e.id)) fail(`${p}.id`, `编号不合法：${JSON.stringify(e.id)}`);
    if (e.uid !== `${kind}:${e.id}`) fail(`${p}.uid`, `uid 应为 ${kind}:${e.id}`);
    if (seen.has(`${kind}:${e.id}`)) fail(p, `编号重复：${kind}:${e.id}`);
    seen.add(`${kind}:${e.id}`); text(e.name, `${p}.name`);
  };
  const base = ["id", "uid", "kind", "name", "source"];
  for (const [i, value] of entries.entries()) {
    const p = `${at}.entries[${i}]`, e = record(value, p);
    if (!["sfx", "music"].includes(e.kind)) { fail(`${p}.kind`, "只能是 sfx 或 music"); continue; }
    identity(e, e.kind, p); byUid.set(e.uid, e);
    exact(e.source, `audio/source/${e.kind}/${e.id}.json`, `${p}.source`);
    if (e.kind === "sfx") {
      known(e, [...base, "trigger", "sound", "duration_ms", "max_instances", "min_interval_ms", "voice_group", "priority", "loop", "max_play_ms", "stop_fade_ms"], p);
      for (const k of ["trigger", "sound", "voice_group"]) text(e[k], `${p}.${k}`);
      number(e.duration_ms, `${p}.duration_ms`, 1, Math.min(1600, policy.sfx_duration_max_ms || 1600));
      number(e.max_instances, `${p}.max_instances`, 1, e.id === "crate_land" ? 2 : 1, true);
      number(e.min_interval_ms, `${p}.min_interval_ms`, 1, 60000, true);
      number(e.priority, `${p}.priority`, 0, 3, true);
      if (e.loop !== undefined) {
        exact(e.loop, true, `${p}.loop`);
        if (e.id !== "reel_spin") fail(`${p}.loop`, "只有 reel_spin 支持音效循环");
        number(e.max_play_ms, `${p}.max_play_ms`, e.duration_ms, 2000, true);
        exact(e.stop_fade_ms, 80, `${p}.stop_fade_ms`);
      } else if (e.max_play_ms !== undefined || e.stop_fade_ms !== undefined) fail(p, "max_play_ms / stop_fade_ms 只用于 loop 音效");
    } else {
      known(e, [...base, "set", "theme", "instruments", "bpm", "meter", "bars", "mode", "mood", "difference"], p);
      for (const k of ["set", "theme", "mode", "difference"]) text(e[k], `${p}.${k}`);
      for (const k of ["instruments", "mood"]) {
        const values = list(e[k], `${p}.${k}`); if (!values.length) fail(`${p}.${k}`, "不能为空");
        for (const [j, v] of values.entries()) text(v, `${p}.${k}[${j}]`);
      }
      number(e.bpm, `${p}.bpm`, 64, 108); exact(e.meter, [4, 4], `${p}.meter`); exact(e.bars, 32, `${p}.bars`);
    }
  }
  for (const [i, value] of sets.entries()) {
    const p = `${at}.music_sets[${i}]`, s = record(value, p);
    identity(s, "music", p); exact(s.kind, "music_set", `${p}.kind`);
    known(s, ["id", "uid", "kind", "name", "world", "slices", "candidates"], p);
    setByUid.set(s.uid, s);
  }
  const refs = {
    world: new Map((catalogs.worlds || []).map(e => [e.id, e])),
    slice: new Map((catalogs.slices || []).map(e => [e.id, e])),
    group: new Map((catalogs.groups || []).map(e => [e.id, e])), chapter: new Map(),
  };
  for (const g of catalogs.groups || []) if (typeof g.theme === "string" && g.theme.startsWith("theme.")) refs.chapter.set(g.theme.slice(6), g);
  for (const s of specs.values()) if (typeof s.spec.chapter === "string" && s.spec.chapter) refs.chapter.set(s.spec.chapter, s.spec);
  const pendingByUid = new Map(), warned = new Set();
  for (const [i, value] of pending.entries()) {
    const p = `${at}.pending_references[${i}]`, r = record(value, p);
    known(r, ["domain", "id", "owner", "reason"], p);
    if (!["slice", "world", "group", "chapter"].includes(r.domain)) fail(`${p}.domain`, "只能是 slice、world、group、chapter");
    if (typeof r.id !== "string" || !localId.test(r.id)) fail(`${p}.id`, "编号不合法");
    for (const k of ["owner", "reason"]) text(r[k], `${p}.${k}`);
    const uid = `${r.domain}:${r.id}`;
    if (pendingByUid.has(uid)) fail(p, `引用登记重复：${uid}`);
    pendingByUid.set(uid, r);
  }
  const ref = (domain, id, p) => {
    if (typeof id !== "string" || !localId.test(id)) { fail(p, `${domain} 引用编号不合法：${JSON.stringify(id)}`); return null; }
    const target = refs[domain].get(id), uid = `${domain}:${id}`;
    if (target) return target;
    if (pendingByUid.has(uid)) {
      if (!warned.has(uid)) { const r = pendingByUid.get(uid); add("warn", `audio/pending_references/${uid}`, `${uid} 尚未合入（${r.owner}）：${r.reason}`); warned.add(uid); }
    } else fail(p, `引用 ${uid} 不存在，且未在 pending_references 登记`);
    return null;
  };
  const setRef = (uid, p) => { if (!setByUid.has(uid)) { fail(p, `曲组 ${uid} 不存在（music_sets）`); return null; } return setByUid.get(uid); };
  const membership = new Map();
  for (const [i, s] of sets.entries()) {
    if (!object(s)) continue;
    const p = `${at}.music_sets[${i}]`;
    if (s.id === "theme") {
      exact(s.world, null, `${p}.world`);
      exact(s.slices, [], `${p}.slices`);
    } else ref("world", s.world, `${p}.world`);
    const slices = list(s.slices, `${p}.slices`), candidates = list(s.candidates, `${p}.candidates`);
    if (new Set(slices).size !== slices.length) fail(`${p}.slices`, "引用重复");
    for (const id of slices) { const sl = ref("slice", id, `${p}.slices`); if (sl && sl.world !== s.world) fail(`${p}.slices`, `${id}.world 为 ${sl.world}，与曲组 world ${s.world} 不一致`); }
    if (new Set(candidates).size < 3) fail(`${p}.candidates`, "每组至少需要 3 个不同候选");
    if (new Set(candidates).size !== candidates.length) fail(`${p}.candidates`, "候选重复");
    for (const uid of candidates) {
      const e = byUid.get(uid);
      if (!e || e.kind !== "music") fail(`${p}.candidates`, `候选 ${uid} 不是已有 music 条目`);
      else if (e.set !== s.id) fail(`${p}.candidates`, `候选 ${uid} 归属 set ${e.set}，不能归到 ${s.id}`);
      membership.set(uid, (membership.get(uid) || 0) + 1);
    }
  }
  for (const e of entries) if (object(e) && e.kind === "music") {
    if (!setByUid.has(`music:${e.set}`)) fail(`audio/${e.uid}.set`, `曲组 music:${e.set} 不存在`);
    if (membership.get(e.uid) !== 1) fail(`audio/${e.uid}`, `候选必须恰好归属一个曲组，实际 ${membership.get(e.uid) || 0} 个`);
  }

  const p = "audio.policy";
  const constants = {
    unapproved_in_game: false, walking_sfx: "silent", sfx_voice_limit: 3, sfx_bus_gain_db: -6,
    crossfade_ms: 1000, crossfade_curve: "linear_unity_sum", pause_music_gain_db: -9, pause_ramp_ms: 200,
    master_control: "workbench_monitor_only", existing_game_settings: { music: 0.8, sfx: 0.8 },
    preview_defaults: { master: 0.8, music: 0.8, sfx: 0.8 }, sfx_duration_max_ms: 1600,
    music_bpm_range: [64, 108], music_meter: [4, 4], music_bars: 32, music_track_limit: 6, music_pitched_voice_limit: 4, note_midi_range: [36, 81],
  };
  known(policy, ["default_music_uid", "fallback_order", "export", "metrics", ...Object.keys(constants)], p);
  setRef(policy.default_music_uid, `${p}.default_music_uid`);
  exact(policy.fallback_order, ["requested_set_approved_selection", `${policy.default_music_uid}_approved_selection`, "silence"], `${p}.fallback_order`);
  for (const [k, v] of Object.entries(constants)) exact(policy[k], v, `${p}.${k}`);
  const exp = record(policy.export, `${p}.export`), metrics = record(policy.metrics, `${p}.metrics`);
  const exportSpec = { sample_rate: 44100, channels: 1, encoding: "pcm_s16le", container: "wav" };
  known(exp, Object.keys(exportSpec), `${p}.export`); for (const [k, v] of Object.entries(exportSpec)) exact(exp[k], v, `${p}.export.${k}`);
  const metricSpec = { sfx_rms_dbfs: { target: -24, tolerance: 2 }, music_rms_dbfs: { target: -26, tolerance: 2 }, sample_peak_max_dbfs: -9,
    dc_abs_max: 0.001, music_seam_value_delta_max: 0.002, music_seam_slope_delta_max: 0.002, fundamental_hz: [65, 1760], lowpass_hz_max: 4000,
    noise_energy_ratio_max: 0.08, music_window_seconds: 3, music_window_step_seconds: 1, music_window_rms_range_max_db: 6,
    music_window_ignore_below_dbfs: -50, music_full_silence_max_ms: 1000, sfx_endpoint_abs_max: 0.001 };
  known(metrics, Object.keys(metricSpec), `${p}.metrics`); for (const [k, v] of Object.entries(metricSpec)) exact(metrics[k], v, `${p}.metrics.${k}`);

  const r = "audio.routes";
  const rejectThemeRoute = (value, p) => {
    if (value === "music:theme") fail(p, "主题曲组 music:theme 仅用于试听，不能被 routes 引用");
    else if (value !== null && typeof value === "object") for (const [key, child] of Object.entries(value)) rejectThemeRoute(child, `${p}.${key}`);
  };
  rejectThemeRoute(routes, r);
  known(routes, ["delivery", "world_to_music", "chapter_to_music", "group_to_chapter", "lobby", "result", "hell"], r);
  const delivery = record(routes.delivery, `${r}.delivery`);
  known(delivery, ["slice_to_music", "otherwise"], `${r}.delivery`);
  const sliceRoutes = record(delivery.slice_to_music, `${r}.delivery.slice_to_music`);
  const worldRoutes = record(routes.world_to_music, `${r}.world_to_music`);
  const chapterRoutes = record(routes.chapter_to_music, `${r}.chapter_to_music`);
  const groupRoutes = record(routes.group_to_chapter, `${r}.group_to_chapter`);
  for (const [id, uid] of Object.entries(sliceRoutes)) {
    const p = `${r}.delivery.slice_to_music.${id}`, sl = ref("slice", id, p), s = setRef(uid, p);
    if (sl && s && sl.world !== s.world) fail(p, `slice:${id}.world ${sl.world} 与曲组 world ${s.world} 不一致`);
  }
  for (const [id, uid] of Object.entries(worldRoutes)) {
    const p = `${r}.world_to_music.${id}`, w = ref("world", id, p), s = setRef(uid, p);
    if (w && s && s.world !== id) fail(p, `world:${id} 与曲组 world ${s.world} 不一致`);
  }
  for (const [id, uid] of Object.entries(chapterRoutes)) { ref("chapter", id, `${r}.chapter_to_music.${id}`); setRef(uid, `${r}.chapter_to_music.${id}`); }
  for (const [id, chapter] of Object.entries(groupRoutes)) {
    const p = `${r}.group_to_chapter.${id}`, g = ref("group", id, p);
    ref("chapter", chapter, p);
    if (g && g.theme !== `theme.${chapter}`) fail(p, `group:${id} 的 chapter 应为 groups.theme 去掉 theme. 前缀（${g.theme}），实际 ${chapter}`);
    if (!Object.hasOwn(chapterRoutes, chapter)) fail(p, `chapter:${chapter} 没有 chapter_to_music 路由`);
  }
  for (const s of sets) if (object(s)) for (const id of Array.isArray(s.slices) ? s.slices : []) if (sliceRoutes[id] !== s.uid) fail(`${r}.delivery.slice_to_music.${id}`, `曲组 ${s.uid} 声明的 slice:${id} 缺少一致路由`);
  exact(delivery.otherwise, "slice.world_to_music_then_default", `${r}.delivery.otherwise`);
  exact(routes.lobby, "visible_map_context_then_default", `${r}.lobby`);
  exact(routes.result, "continue_current_no_restart", `${r}.result`);
  exact(routes.hell, "chapter_to_music_no_diyu_name_inference", `${r}.hell`);
  return doc;
}

function audioIdInputs(root, catalog, add) {
  const file = path.join(root, "audio/export/manifest.json"), sources = {}, media = {}, histories = {};
  let approvals = { format: "pushbox.audio-approvals/1", records: [] };
  const approvalFile = path.join(root, "audio/approvals.json");
  if (fs.existsSync(approvalFile)) {
    try {
      const value = readJson(approvalFile);
      if (!value || value.format !== "pushbox.audio-approvals/1" || !Array.isArray(value.records)) add("error", "audio/approvals.json", "format / records 不合法");
      else approvals = value;
    } catch (e) { add("error", "audio/approvals.json", "不是合法 JSON：" + e.message); }
  }
  let manifest = null;
  if (fs.existsSync(file)) {
    try { manifest = readJson(file); if (!manifest || manifest.format !== "pushbox.audio-manifest/1" || !Array.isArray(manifest.entries) || !manifest.bindings || typeof manifest.bindings !== "object" || Array.isArray(manifest.bindings)) { add("error", "audio/export/manifest.json", "音频 manifest 的 format / entries / bindings 不合法"); manifest = null; } }
    catch (e) { add("error", "audio/export/manifest.json", "不是合法 JSON：" + e.message); }
  }
  for (const e of Array.isArray(catalog.entries) ? catalog.entries : []) if (e && typeof e.source === "string" && e.source === `audio/source/${e.kind}/${e.id}.json`) sources[e.uid] = fs.existsSync(path.join(root, e.source)) && fs.statSync(path.join(root, e.source)).isFile();
  for (const e of (manifest && manifest.entries) || []) {
    const versions = [e && e.current, ...(Array.isArray(e && e.approved) ? e.approved : [])];
    for (const v of versions) if (v && typeof v.wav === "string" && /^audio\/export\/(preview|approved)\/(sfx|music)\/[a-z0-9_@.-]+\.wav$/.test(v.wav)) {
      const p = path.join(root, v.wav); if (fs.existsSync(p) && fs.statSync(p).isFile()) media[v.wav] = sha(fs.readFileSync(p));
    }
  }
  const declarations = new Map((Array.isArray(catalog.entries) ? catalog.entries : []).filter(e => e && typeof e === "object").map(e => [e.uid, e]));
  const recordIds = new Set(), validRecords = [];
  const recordedDate = (date) => {
    if (typeof date !== "string" || !/^\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}(?:\.\d{1,3})?(?:Z|[+-]\d{2}:\d{2})$/.test(date) || !Number.isFinite(Date.parse(date))) return false;
    const day = date.slice(0, 10), midnight = Date.parse(`${day}T00:00:00.000Z`);
    return Number.isFinite(midnight) && new Date(midnight).toISOString().slice(0, 10) === day;
  };
  for (const [index, r] of approvals.records.entries()) {
    const at = `audio/approvals.records[${index}]`;
    if (!r || typeof r !== "object" || Array.isArray(r)) { add("error", at, "确认记录必须是对象"); continue; }
    let invalid = false;
    const bad = (field, msg) => { add("error", `${at}.${field}`, msg); invalid = true; };
    if (typeof r.id !== "string" || !/^AAP-\d{4,}$/.test(r.id) || recordIds.has(r.id)) bad("id", "确认记录 id 不合法或重复");
    if (!recordedDate(r.date)) bad("date", "必须记录有效的 ISO 日期与时间");
    for (const field of ["by", "via", "note"]) if (typeof r[field] !== "string" || !r[field].trim()) bad(field, field === "note" ? "必须记录非空的用户确认原话" : "必须是非空字符串");
    if (!Array.isArray(r.items)) bad("items", "必须是数组");
    if (!Array.isArray(r.selections || [])) bad("selections", "必须是数组");
    if (invalid) continue;
    recordIds.add(r.id); validRecords.push(r);
    for (const item of r.items) {
      const e = item && declarations.get(item.uid);
      if (!e || !Number.isInteger(item.version) || item.version < 1) { add("error", "audio/approvals.json", "确认记录引用未知 uid 或非法版本"); continue; }
      const expected = `audio/history/${e.kind}/${e.id}@v${item.version}.json`, wav = `audio/export/approved/${e.kind}/${e.id}@v${item.version}.wav`;
      if (item.history !== expected || item.wav !== wav) { add("error", `audio/${item.uid}`, "确认记录 history / wav 路径不规范"); continue; }
      let valid = false;
      try {
        const snap = readJson(path.join(root, expected));
        valid = snap && snap.format === "pushbox.audio-history/1" && snap.uid === item.uid && snap.version === item.version && snap.hash === item.hash &&
          typeof snap.renderer_fingerprint === "string" && snap.source && snap.source.uid === item.uid && snap.source.version === item.version && snap.source.content_hash === item.hash && sourceHash(snap.source, snap.renderer_fingerprint) === item.hash;
        if (!Object.hasOwn(media, wav)) {
          const bytes = fs.readFileSync(path.join(root, wav));
          if (bytes.length >= 44 && bytes.toString("ascii", 0, 4) === "RIFF" && bytes.toString("ascii", 8, 12) === "WAVE" && bytes.readUInt32LE(24) === 44100 && bytes.readUInt16LE(22) === 1 && bytes.readUInt16LE(34) === 16) media[wav] = sha(bytes);
        }
      } catch (e) { /* Missing/damaged historical data must never be importable. */ }
      histories[expected] = !!valid;
      if (!valid || media[wav] !== item.wav_sha256) add("warn", `audio/${item.uid}`, `已确认 v${item.version} 的历史源或媒体缺失/损坏，不可导入游戏`);
    }
  }
  return { catalog, manifest, sources, media, histories, approvals: { ...approvals, records: validRecords } };
}

// Onboarding data (docs/design/onboarding.md 附 3) lives in content/onboarding/*.json,
// keyed by level id, so the level specs (and their SDK records) stay untouched.
// Checked: the level exists, every text key is in content/i18n-onboarding, every
// [x, y] cell lies inside that level's map, and a trap's kind is dead or wrong.
function checkOnboarding(root, specs, textSource, add) {
  const dir = path.join(root, "content/onboarding");
  if (!fs.existsSync(dir)) return;
  const table = "content/i18n-onboarding/zh-Hans.json";
  const list = (v) => (Array.isArray(v) ? v : []);
  for (const name of fs.readdirSync(dir).filter((n) => n.endsWith(".json")).sort()) {
    const file = `content/onboarding/${name}`;
    let doc; try { doc = readJson(path.join(dir, name)); } catch (e) { add("error", file, "不是合法 JSON：" + e.message); continue; }
    if (!doc || doc.format !== "pushbox.onboarding/1" || !doc.levels || typeof doc.levels !== "object") { add("error", file, "format 应为 pushbox.onboarding/1，levels 应为对象"); continue; }
    for (const [id, o] of Object.entries(doc.levels)) {
      const at = `${file} ${id}`, sp = specs.get(id);
      if (!sp) { add("error", at, `关卡 ${id} 不存在`); continue; }
      if (!o || typeof o !== "object") { add("error", at, "必须是对象"); continue; }
      const map = list(sp.spec.map);
      const key = (k, p) => { if (textSource[k] !== table) add("error", `${at}.${p}`, `文字键 ${JSON.stringify(k)} 不在 content/i18n-onboarding 里`); };
      const cell = (c, p) => {
        const ok = Array.isArray(c) && c.length === 2 && Number.isInteger(c[0]) && Number.isInteger(c[1]) && c[1] >= 0 && c[1] < map.length && c[0] >= 0 && c[0] < String(map[c[1]]).length;
        if (!ok) add("error", `${at}.${p}`, `坐标 ${JSON.stringify(c)} 不在 ${id} 的地图内`);
      };
      for (const p of ["goal", "hint3", "say_start"]) if (o[p] !== undefined) key(o[p], p);
      for (const [i, h] of list(o.keyhints).entries()) if (h && Array.isArray(h.at)) cell(h.at, `keyhints[${i}].at`);
      for (const [i, t] of list(o.traps).entries()) {
        const p = `traps[${i}]`;
        if (!t || (t.kind !== "dead" && t.kind !== "wrong")) add("error", `${at}.${p}.kind`, `只能是 dead 或 wrong：${JSON.stringify(t && t.kind)}`);
        if (!t) continue;
        if (t.say !== undefined) key(t.say, `${p}.say`);
        for (const w of ["crate_at", "sand_at", "no_sand_at"]) for (const [j, c] of list((t.when || {})[w]).entries()) cell(c, `${p}.when.${w}[${j}]`);
      }
    }
  }
}

export function buildContent(root, opts = {}) {
  const rel = (...p) => path.join(root, ...p);
  const issues = [];
  const add = (level, where, msg) => issues.push({ level, where, msg });

  // ---- catalogs ----
  const cat = {}, notes = {};
  let audioCatalog = {};
  for (const name of CATALOGS) {
    const p = rel("content/catalog", name + ".json");
    cat[name] = [];
    if (!fs.existsSync(p)) { add("error", `content/catalog/${name}.json`, "目录文件缺失"); continue; }
    let doc;
    try { doc = readJson(p); } catch (e) { add("error", `content/catalog/${name}.json`, "不是合法 JSON：" + e.message); continue; }
    if (!doc || typeof doc !== "object" || Array.isArray(doc)) { add("error", `content/catalog/${name}.json`, "目录必须是对象"); continue; }
    if (doc.format !== "pushbox.catalog/1" || doc.kind !== name) add("error", `content/catalog/${name}.json`, "format 应为 pushbox.catalog/1，kind 应为 " + name);
    if (name === "audio") { audioCatalog = doc; cat[name] = Array.isArray(doc.entries) ? doc.entries.filter(e => e && typeof e === "object") : []; notes[name] = doc.note || ""; continue; }
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
  checkAudioCatalog(audioCatalog, cat, specs, add);
  const audio = audioIdInputs(root, audioCatalog, add);
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
    if (sl.pool) continue; // run pools: checked with the v2 maps below
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
    for (const [c, rs] of Object.entries(sl.cargo_only || {})) {
      if (!(sl.cargo || []).includes(c)) add("error", at, `cargo_only 的 ${c} 不是这张地图的货物`);
      for (const r of rs) if (!(sl.recipients || []).includes(r)) add("error", at, `cargo_only 的 ${c} 写了不在这张地图的收件人 ${r}`);
    }
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

  // ---- delivery rooms v2, maps v2 and run pools (docs/design/delivery-puzzle-rules.md) ----
  const rooms2 = loadRooms2(root), room2ById = new Map();
  const ROLES2 = ["gate", "teach", "develop", "twist", "breather", "station", "home"];
  for (const { file, room: t } of rooms2) {
    const at = file;
    if (roomById.has(t.id) || room2ById.has(t.id)) add("error", at, `房间编号 ${t.id} 重复（另见 ${(roomById.get(t.id) || room2ById.get(t.id)).file}）`);
    room2ById.set(t.id, { file, room: t });
    if (!worlds.has(t.world)) add("error", at, `地区 ${t.world} 不在 worlds.json 中`);
    else if (file !== `content/rooms/${t.world}/${t.id}.json`) add("error", at, `房间模板应放在 content/rooms/${t.world}/${t.id}.json`);
    for (const k of ["mechanisms", "requires", "teaches", "needs"]) for (const m of t[k] || []) if (!mechs.has(m)) add("error", at, `${k} 的机制 ${m} 不在机制目录中`);
    for (const [k, e] of Object.entries(t.legend || {})) if (e.monster && !monsters.has(e.monster)) add("error", at, `legend ${k} 的怪物 ${e.monster} 不在 monsters.json 中`);
    for (const r of (t.only || {}).recipients || []) if (!recipients.has(r)) add("error", at, `only 的收件人 ${r} 不在 recipients.json 中`);
    for (const c of (t.only || {}).cargo || []) if (!cargo.has(c)) add("error", at, `only 的货物 ${c} 不在 cargo.json 中`);
  }
  let room2Check = null;
  const r2p = rel("content/rooms2-check.generated.json");
  if (fs.existsSync(r2p)) { try { room2Check = readJson(r2p); } catch (e) { add("error", "content/rooms2-check.generated.json", "不是合法 JSON"); } }
  const checked2 = new Map(((room2Check && room2Check.templates) || []).map((t) => [t.id, t]));
  const room2Ok = new Map();
  for (const { file, sha256, room: t } of rooms2) {
    const c = checked2.get(t.id);
    if (!c || c.sha256 !== sha256) { add("error", file, "解谜检查结果缺失或已过期：运行 node tools/check-rooms2.mjs --write"); room2Ok.set(t.id, false); continue; }
    for (const e of c.errors) add("error", file, e);
    room2Ok.set(t.id, !c.errors.length);
  }
  const maps2 = new Map(cat.slices.filter((s) => s.format === 2).map((s) => [s.id, s]));
  for (const sl of maps2.values()) {
    const at = `slices/${sl.id}`;
    if (sl.rooms) add("error", at, "format 2 的地图用 rooms2 列房间（rooms 是第一版的房间）");
    const list = [];
    for (const id of sl.rooms2 || []) {
      const r = room2ById.get(id);
      if (!r) add("error", at, `房间 ${id} 不存在（content/rooms/ 下 format pushbox.room/2）`);
      else if (r.room.world !== sl.world) add("error", at, `房间 ${id} 属于 ${r.room.world}，不是 ${sl.world}`);
      else list.push(r.room);
    }
    const L = sl.layout || {};
    if (!(L.cols > 0) || !(L.rows > 0)) add("error", at, "layout.cols / rows 必须大于 0");
    if (!["down", "up", "right", "left"].includes(L.direction || "down")) add("error", at, "layout.direction 只能是 down、up、right、left");
    const seq = L.sequence || [];
    if (!seq.length || seq[0].role !== "gate" || seq[seq.length - 1].role !== "home") add("error", at, "layout.sequence 要以 gate 开始、以 home 结束");
    for (const st of seq) {
      if (!ROLES2.includes(st.role)) add("error", at, `layout.sequence 的 role ${st.role} 不对`);
      else if (!list.some((t) => t.role === st.role)) add("error", at, `没有 role 为 ${st.role} 的房间`);
    }
    for (const r of sl.recipients || []) if (!list.some((t) => t.role === "home" && (!t.only || !t.only.recipients || t.only.recipients.includes(r)))) add("error", at, `收件人 ${r} 没有可用的收件人之家`);
  }
  const pools = cat.slices.filter((s) => s.pool);
  for (const sl of pools) {
    const at = `slices/${sl.id}`;
    if (!modes.has(sl.mode)) add("error", at, `模式 ${sl.mode} 不存在`);
    const P = sl.pool || {};
    if (!(P.maps || []).length) add("error", at, "pool.maps 至少要有一张地图");
    for (const m of P.maps || []) if (!maps2.has(m.slice)) add("error", at, `地图 ${m.slice} 不是 format 2 的地图（slices.json）`);
    const res = ((room2Check && room2Check.pools) || []).find((x) => x.id === sl.id);
    if (!res) add("error", at, "还没有开局池检查结果：运行 node tools/check-rooms2.mjs --write");
    else if (res.input_sha256 !== poolInput(sl, maps2)) add("error", at, "开局池或它的地图改过了，检查结果已过期：运行 node tools/check-rooms2.mjs --write");
    else if (!res.ok) add("error", at, "按种子生成的局没有全部通过检查：" + (res.failures[0] || ""));
  }
  for (const w of cat.worlds) for (const f of w.hint_fauna || []) if (f.asset && !art.has(f.asset)) add("error", `worlds/${w.id}`, `提示动物 ${f.id} 的美术资产 ${f.asset} 不存在`);

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
      // v2 rooms (turn-based puzzle check, no Godot run yet): at most "specified".
      const rs = rooms2.filter(({ room: t }) => (t.mechanisms || []).includes(m.id)).map(({ room: t }) => t.id);
      let status = "proposed";
      if (ds.length || rs.length) status = "designed";
      if ((ds.length || rs.length) && ds.every((d) => d.model_ok) && rs.every((id) => room2Ok.get(id))) status = "specified";
      if (status === "specified" && ds.length && !rs.length && ds.every((d) => d.verified)) status = "verified";
      if (status === "verified" && !missingArt.length) status = "playable";
      return Object.assign({}, m, { status, levels: [], demos: ds.map((d) => d.template + "/" + d.id), rooms2: rs, missing_art: missingArt });
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
  checkOnboarding(root, specs, textSource, add);
  const ids = buildIdMap({
    art: [...art.values()].map((a) => Object.assign({}, a, { file: artFile.get(a.id), approved: approved(a.id) })).sort((a, b) => a.id.localeCompare(b.id)),
    levels: levels.map((l) => ({ id: l.id, title: l.title, spec: l.has_spec ? l.spec : null, sha256: l.sha256 })),
    rooms: rooms.concat(rooms2).map(({ file, sha256, room }) => ({ id: room.id, name: room.name, source: file, sha256 })),
    catalogs: cat, texts, textSource, audio,
  });
  issues.push(...ids.issues);

  const summary = {
    errors: issues.filter((i) => i.level === "error").length, warnings: issues.filter((i) => i.level === "warn").length,
    report: report ? { generated: report.generated || null, commit: report.commit || null, sdk: report.sdk || null, levels: (report.levels || []).length, samples: report.samples || [], references: report.references || [] } : null,
  };
  const roomData = rooms.map(({ file, sha256, room }) => Object.assign({}, room, { file, sha256, check: checked.get(room.id) || null }));
  const room2Data = rooms2.map(({ file, sha256, room }) => Object.assign({}, room, { file, sha256, check: checked2.get(room.id) || null }));
  const result = { catalogs: cat, notes, audio: { catalog: audio.catalog, manifest: audio.manifest }, levels, mechanisms, issues, summary, ids: ids.map, rooms: roomData, roomSlices: (roomCheck && roomCheck.slices) || [],
    rooms2: room2Data, pools2: (room2Check && room2Check.pools) || [] };

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
        audio: { catalog: audio.catalog, manifest: audio.manifest },
        worlds: cat.worlds, recipients: cat.recipients, cargo: cat.cargo, combos: cat.combos, monsters: cat.monsters,
        items: cat.items, buffs: cat.buffs, upgrades: cat.upgrades, badges: cat.badges, events: cat.events, slices: cat.slices,
        rooms: rooms.map(({ file, sha256, room }) => ({ id: room.id, world: room.world, type: room.type, spec: file, sha256 })),
        rooms2: rooms2.map(({ file, sha256, room }) => ({ id: room.id, world: room.world, type: room.type, role: room.role, size: room.size || [1, 1], spec: file, sha256 })),
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
