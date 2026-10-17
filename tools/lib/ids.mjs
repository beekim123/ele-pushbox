// Global resource IDs (docs/design/ids.md). Every resource the workbench knows
// gets one uid "<domain>:<id>"; the workbench (this repository's data) is the
// authority and the game maps each uid to a fixed path. Pure function: the
// caller passes what it already loaded and writes the result.

// domain -> where it comes from in this repository and where it lives in the game.
export const DOMAINS = {
  art:       { name: "美术资产", source: "art/source/<分类>/<id>.json", game: (e) => e.kind === "procedural" ? proceduralPath(e) : `res://generated/art/${e.id}.tres` },
  level:     { name: "关卡", source: "content/levels/<模式>/<组>/<id>.json", game: (e) => `res://generated/content/${e.source.replace(/^content\//, "")}` },
  room:      { name: "配送房间模板", source: "content/rooms/<地区>/<id>.json", game: (e) => `res://generated/content/${e.source.replace(/^content\//, "")}` },
  mode:      { name: "模式", catalog: "modes", game: (e) => `res://generated/content/catalog/modes.json#${e.id}` },
  group:     { name: "机制组（章）", catalog: "groups", game: (e) => `res://generated/content/catalog/groups.json#${e.id}` },
  mechanic:  { name: "机制", catalog: "mechanisms", game: (e) => `res://gameplay/mechanics/${e.id}.gd` },
  world:     { name: "地区", catalog: "worlds" },
  recipient: { name: "收件人", catalog: "recipients" },
  cargo:     { name: "货物", catalog: "cargo" },
  combo:     { name: "缘分组合", catalog: "combos" },
  monster:   { name: "怪物", catalog: "monsters" },
  item:      { name: "道具", catalog: "items" },
  buff:      { name: "增益", catalog: "buffs" },
  upgrade:   { name: "属性升级", catalog: "upgrades" },
  badge:     { name: "徽章", catalog: "badges" },
  event:     { name: "随机事件", catalog: "events" },
  slice:     { name: "可玩切片（配送局配置）", catalog: "slices" },
  sfx:       { name: "音效", source: "content/catalog/audio.json；audio/source/sfx/<id>.json", game: (e) => `res://generated/audio/sfx/${e.id}.wav` },
  music:     { name: "音乐候选与曲组", source: "content/catalog/audio.json；audio/source/music/<id>.json", game: (e) => `res://generated/audio/music/${e.id}.wav` },
  text:      { name: "界面与台词文字", source: "content/i18n/zh-Hans.json 与 content/i18n-<名>/zh-Hans.json", game: (e) => `tr:${e.id}` },
};
function proceduralPath(e) {
  const [cat, ...rest] = e.id.split(".");
  if (cat === "ui" && rest[0] === "screen") return `res://ui/screens/${rest.slice(1).join("_")}.tscn`;
  if (cat === "theme") return `res://generated/themes/${e.id}.tres`;
  return `res://generated/materials/${e.id}.tres`;
}
const ID_RULE = { art: /^[a-z]+(\.[a-z0-9_]+)+$/, level: /^[A-Z][0-9]{2}$/, text: /^[a-z][a-z0-9_]*(\.[A-Za-z0-9_]+)*$/ };
const DEFAULT_RULE = /^[a-z0-9_-]+$/;
const uidOf = (domain, id) => `${domain}:${id}`;

// Audio ID entries describe fixed import destinations separately from currently
// usable approved media. A preview path can never become game_audio.
function audioIds(audio, issue) {
  if (!audio || !audio.catalog) return [];
  const catalog = audio.catalog, manifest = audio.manifest;
  const sources = audio.sources || {}, media = audio.media || {};
  const declared = new Map((Array.isArray(catalog.entries) ? catalog.entries : []).filter(e => e && ["sfx", "music"].includes(e.kind)).map(e => [e.uid, e]));
  const currentByUid = new Map(), duplicate = new Set(), mapped = [];
  const quality = new Map(), adopted = new Map();
  for (const e of manifest && Array.isArray(manifest.entries) ? manifest.entries : []) {
    if (!e || !declared.has(e.uid) || e.kind !== declared.get(e.uid).kind || e.id !== declared.get(e.uid).id) { issue("audio/export/manifest.json", `未知或身份不一致的音频条目 ${e && e.uid}`); continue; }
    if (currentByUid.has(e.uid)) { duplicate.add(e.uid); issue(`ids/${e.uid}`, "音频 manifest 编号重复"); }
    currentByUid.set(e.uid, e);
  }
  const sha = /^[a-f0-9]{64}$/;
  const version = (v) => v && Number.isInteger(v.version) && v.version >= 1 && sha.test(v.hash) && sha.test(v.sha256);
  const valid = (e, v, approved) => !!version(v) && v.wav === (approved ? `audio/export/approved/${e.kind}/${e.id}@v${v.version}.wav` : `audio/export/preview/${e.kind}/${e.id}.wav`) && media[v.wav] === v.sha256;
  const matching = (a, b) => a && b && a.version === b.version && a.hash === b.hash && a.sha256 === b.sha256 && a.wav === b.wav;
  for (const rec of audio.approvals && Array.isArray(audio.approvals.records) ? audio.approvals.records : []) {
    if (!rec || !Array.isArray(rec.items)) continue;
    for (const item of rec.items) {
      const e = item && declared.get(item.uid);
      if (!e || item.history !== `audio/history/${e.kind}/${e.id}@v${item.version}.json` || !(audio.histories || {})[item.history]) continue;
      const v = { ...item, sha256: item.wav_sha256 };
      if (!valid(e, v, true)) continue;
      if (!quality.has(item.uid)) quality.set(item.uid, []);
      quality.get(item.uid).push(v);
    }
    for (const selection of Array.isArray(rec.selections) ? rec.selections : []) {
      if (!selection) continue;
      const e = declared.get(selection.uid), set = (Array.isArray(catalog.music_sets) ? catalog.music_sets : []).find(s => s && s.uid === selection.set_uid);
      const v = (quality.get(selection.uid) || []).findLast(v => v.version === selection.version && v.hash === selection.hash);
      if (e && set && e.kind === "music" && e.set === set.id && Array.isArray(set.candidates) && set.candidates.includes(e.uid) && v) adopted.set(selection.set_uid, { uid: e.uid, ...v });
    }
  }
  const approvedByUid = new Map();
  for (const e of declared.values()) {
    const m = duplicate.has(e.uid) ? null : currentByUid.get(e.uid), current = m && m.current || null;
    const declaredApprovals = m && Array.isArray(m.approved) ? m.approved : [];
    const approvals = (quality.get(e.uid) || []).filter(v => declaredApprovals.some(q => matching(v, q)));
    approvedByUid.set(e.uid, approvals);
    const selected = approvals.at(-1) || null;
    const previewOk = sources[e.uid] === true && valid(e, current, false);
    const availability = selected ? "approved" : current || sources[e.uid] ? previewOk ? "review" : "missing" : "planned";
    const currentApproved = !!current && approvals.some(v => v.version === current.version && v.hash === current.hash && v.sha256 === current.sha256);
    mapped.push({ domain: e.kind, id: e.id, name: e.name, source: e.source,
      extra: { audio_kind: e.kind, availability, approved: !!selected, importable: !!selected, current_is_approved: currentApproved,
        version: current && current.version || null, hash: current && current.hash || null, current,
        game_audio: selected ? { uid: e.uid, ...selected } : null } });
  }
  for (const s of Array.isArray(catalog.music_sets) ? catalog.music_sets : []) {
    if (!s || typeof s !== "object") continue;
    const binding = manifest && manifest.bindings && manifest.bindings[s.uid] || null;
    const e = binding && declared.get(binding.uid);
    const selected = binding && matching(binding, adopted.get(s.uid)) && binding.uid === adopted.get(s.uid).uid && e && e.kind === "music" && e.set === s.id && Array.isArray(s.candidates) && s.candidates.includes(e.uid) && (approvedByUid.get(e.uid) || []).some(v => matching(v, binding)) ? binding : null;
    const availability = selected ? "approved" : binding ? "missing" : "planned";
    mapped.push({ domain: "music", id: s.id, name: s.name, source: `content/catalog/audio.json#music_sets/${s.id}`,
      extra: { audio_kind: "music_set", availability, approved: !!selected, importable: !!selected, current_is_approved: !!selected,
        version: selected && selected.version || null, hash: selected && selected.hash || null, current: null,
        game_audio: selected ? { ...selected } : null } });
  }
  return mapped;
}

// art: [{id, name, kind, category, version, content_hash, approved, file}]
// levels: [{id, spec(file), sha256, title}] ; catalogs: {kind: [entries]} ; texts: {key: zh string}
export function buildIdMap({ art, levels, rooms, catalogs, texts, textSource, audio }) {
  const issues = [], entries = [], seen = new Map(), paths = new Map();
  const push = (domain, e) => {
    const rule = ID_RULE[domain] || DEFAULT_RULE;
    if (!rule.test(e.id)) issues.push({ level: "error", where: `ids/${domain}`, msg: `编号格式不对：${e.id}` });
    const uid = uidOf(domain, e.id);
    if (seen.has(uid)) { issues.push({ level: "error", where: `ids/${uid}`, msg: `编号重复（${seen.get(uid)} 与 ${e.source}）` }); return; }
    seen.set(uid, e.source);
    const D = DOMAINS[domain];
    const game = D.game ? D.game(e) : `res://generated/content/catalog/${D.catalog}.json#${e.id}`;
    if (paths.has(game)) issues.push({ level: "error", where: `ids/${uid}`, msg: `游戏路径与 ${paths.get(game)} 相同：${game}` });
    paths.set(game, uid);
    entries.push(Object.assign({ uid, domain, id: e.id, name: e.name || "", source: e.source, game }, e.extra || {}));
  };
  for (const a of art) push("art", { id: a.id, name: a.name, kind: a.kind, source: a.file,
    extra: { category: a.category, version: a.version, hash: a.content_hash, approved: !!a.approved } });
  for (const l of levels) if (l.spec) push("level", { id: l.id, name: l.title, source: l.spec, extra: { sha256: l.sha256 } });
  for (const r of rooms || []) push("room", { id: r.id, name: r.name, source: r.source, extra: { sha256: r.sha256 } });
  for (const [domain, D] of Object.entries(DOMAINS)) {
    if (!D.catalog) continue;
    for (const e of catalogs[D.catalog] || []) push(domain, { id: e.id, name: e.name || e.title || (e.cargo ? `${e.cargo} × ${e.recipient}` : ""), source: `content/catalog/${D.catalog}.json` });
  }
  for (const e of audioIds(audio, (where, msg) => issues.push({ level: "error", where, msg }))) push(e.domain, e);
  for (const [k, v] of Object.entries(texts)) if (k !== "_meta") push("text", { id: k, name: typeof v === "string" ? v.slice(0, 40) : "", source: (textSource && textSource[k]) || "content/i18n/zh-Hans.json" });
  const counts = {}; for (const e of entries) counts[e.domain] = (counts[e.domain] || 0) + 1;
  return {
    map: {
      format: "pushbox.idmap/1",
      note: "Generated by `node tools/content.mjs build` (docs/design/ids.md). The workbench data is the authority: the game refers to resources only by uid and must find each uid at `game`. Never add an id on the game side first.",
      domains: Object.fromEntries(Object.entries(DOMAINS).map(([k, D]) => [k, { name: D.name, source: D.source || `content/catalog/${D.catalog}.json`, count: counts[k] || 0 }])),
      entries,
    },
    issues,
  };
}
