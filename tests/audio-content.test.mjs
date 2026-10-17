// WB-02: audio catalog validation and the workbench/game ID contract.
// Every mutation and generated media file lives in an isolated temporary root.
import { test } from "node:test";
import assert from "node:assert/strict";
import crypto from "node:crypto";
import fs from "node:fs";
import os from "node:os";
import path from "node:path";
import { fileURLToPath } from "node:url";
import { buildContent } from "../tools/content.mjs";
import { sourceHash } from "../tools/lib/audio.mjs";

const REPO = path.resolve(path.dirname(fileURLToPath(import.meta.url)), "..");
const json = (f) => JSON.parse(fs.readFileSync(f, "utf8"));
const audioCatalog = () => json(path.join(REPO, "content/catalog/audio.json"));
const write = (root, file, value) => {
  const p = path.join(root, file); fs.mkdirSync(path.dirname(p), { recursive: true });
  fs.writeFileSync(p, typeof value === "string" || Buffer.isBuffer(value) ? value : JSON.stringify(value));
};
function sandbox(t) {
  const root = fs.mkdtempSync(path.join(os.tmpdir(), "pb-audio-content-"));
  t.after(() => fs.rmSync(root, { recursive: true, force: true }));
  const entries = {
    modes: ["lab", "delivery", "hell"].map(id => ({ id })),
    groups: json(path.join(REPO, "content/catalog/groups.json")).entries.map(g => ({ ...g, levels: [] })),
    worlds: ["dungeon", "diyu", "jeju"].map(id => ({ id })),
    cargo: [{ id: "box", params: { pay: 1 } }],
    recipients: [{ id: "receiver", worlds: ["dungeon", "diyu", "jeju"], params: { move: {} } }],
    slices: [["dungeon_1", "dungeon"], ["dungeon_2", "dungeon"], ["diyu_1", "diyu"]].map(([id, world]) => ({ id, world, mode: "delivery", cargo: ["box"], recipients: ["receiver"], time: { tick_hz: 1 } })),
  };
  for (const name of ["modes", "groups", "mechanisms", "worlds", "recipients", "cargo", "combos", "monsters", "items", "buffs", "upgrades", "badges", "events", "slices"]) write(root, `content/catalog/${name}.json`, { format: "pushbox.catalog/1", kind: name, entries: entries[name] || [] });
  for (const g of entries.groups) write(root, `art/source/themes/${g.theme}.json`, { id: g.theme, kind: "procedural", version: 1 });
  write(root, "content/catalog/audio.json", audioCatalog());
  return root;
}
function edit(root, file, fn) { const d = json(path.join(root, file)); fn(d); write(root, file, d); }
const editAudio = (root, fn) => edit(root, "content/catalog/audio.json", fn);
const audioIssues = (res) => res.issues.filter(i => /^(audio(?:[/.]|$)|content\/catalog\/audio\.json|ids\/(?:sfx|music))/.test(i.where));
const errors = (res) => audioIssues(res).filter(i => i.level === "error").map(i => `${i.where}: ${i.msg}`);
const id = (res, uid) => res.ids.entries.find(e => e.uid === uid);
const sha = (b) => crypto.createHash("sha256").update(b).digest("hex");
function manifest(root) {
  return { format: "pushbox.audio-manifest/1", entries: audioCatalog().entries.map(e => ({ ...e, current: null, approved: [] })), bindings: {}, catalog: audioCatalog() };
}
function medium(root, e, version, approved = false) {
  const wav = approved ? `audio/export/approved/${e.kind}/${e.id}@v${version}.wav` : `audio/export/preview/${e.kind}/${e.id}.wav`;
  const bytes = Buffer.alloc(46); bytes.write("RIFF", 0); bytes.writeUInt32LE(38, 4); bytes.write("WAVEfmt ", 8); bytes.writeUInt32LE(16, 16); bytes.writeUInt16LE(1, 20); bytes.writeUInt16LE(1, 22); bytes.writeUInt32LE(44100, 24); bytes.writeUInt32LE(88200, 28); bytes.writeUInt16LE(2, 32); bytes.writeUInt16LE(16, 34); bytes.write("data", 36); bytes.writeUInt32LE(2, 40); bytes.writeInt16LE(version, 44);
  write(root, wav, bytes);
  const source = { format: "pushbox.audio/1", kind: e.kind, id: e.id, uid: e.uid, name: e.name, seed: version, version, engine: "portitor-chip/1", sample_rate: 44100, channels: 1, gain_db: -24, instruments: [{ id: "soft", wave: "sine", gain_db: -6, lowpass_hz: 2000, attack_ms: 10, decay_ms: 0, sustain: 1, release_ms: 25 }] };
  if (e.kind === "sfx") Object.assign(source, { duration_ms: e.duration_ms, events: [{ instrument: "soft", start_ms: 0, duration_ms: e.duration_ms - 25, note: 48, gain_db: 0 }] });
  else Object.assign(source, { set: e.set, bpm: e.bpm, meter: e.meter, bars: e.bars, mode: e.mode, tracks: [{ instrument: "soft", notes: [{ beat: 0, length: 128, note: 48, gain_db: 0 }] }] });
  const fingerprint = sha("isolated fixture renderer"), hash = sourceHash(source, fingerprint); source.content_hash = hash;
  const result = { version, hash, wav, sha256: sha(bytes), metrics: { ok: true } };
  if (approved) {
    result.history = `audio/history/${e.kind}/${e.id}@v${version}.json`;
    write(root, result.history, { format: "pushbox.audio-history/1", uid: e.uid, version, hash, renderer_fingerprint: fingerprint, source });
  }
  return result;
}

function recordApproval(root, entry, version, setUid) {
  const item = { uid: entry.uid, version: version.version, hash: version.hash, wav_sha256: version.sha256, wav: version.wav, history: version.history };
  write(root, "audio/approvals.json", { format: "pushbox.audio-approvals/1", records: [{ id: "AAP-0001", date: "2026-10-17T08:00:00.000Z", by: "隔离测试", via: "test", note: "仅测试临时数据", items: [item], selections: setUid ? [{ set_uid: setUid, uid: entry.uid, version: version.version, hash: version.hash }] : [] }] });
}

test("audio is parsed/exported as a catalog; no sources means planned, never importable", t => {
  const root = sandbox(t), res = buildContent(root, { write: true });
  assert.equal(res.summary.errors, 0);
  assert.equal(res.catalogs.audio.length, 41);
  assert.equal(res.audio.catalog.music_sets.length, 3);
  assert.equal(res.ids.domains.sfx.count, 32);
  assert.equal(res.ids.domains.music.count, 12);
  for (const uid of ["sfx:push", "music:dungeon_a", "music:dungeon"]) {
    assert.equal(id(res, uid).availability, "planned");
    assert.equal(id(res, uid).importable, false);
    assert.equal(id(res, uid).game_audio, null);
  }
  assert.equal(id(res, "sfx:push").source, "audio/source/sfx/push.json");
  assert.equal(id(res, "music:dungeon_a").game, "res://generated/audio/music/dungeon_a.wav");
  assert.equal(id(res, "music:dungeon").game, "res://generated/audio/music/dungeon.wav");
  assert.equal(json(path.join(root, "content/export/content-manifest.json")).audio.catalog.kind, "audio");
});

test("registered pending slice warns while absent, resolves normally when it appears", t => {
  const root = sandbox(t);
  let res = buildContent(root);
  assert.deepEqual(errors(res), []);
  assert.ok(audioIssues(res).some(i => i.level === "warn" && i.msg.includes("slice:jeju_1")));
  edit(root, "content/catalog/slices.json", d => { d.entries.push({ ...d.entries[0], id: "jeju_1", world: "jeju" }); });
  res = buildContent(root);
  assert.deepEqual(errors(res), []);
  assert.ok(!audioIssues(res).some(i => i.level === "warn" && i.msg.includes("jeju_1")));
  edit(root, "content/catalog/slices.json", d => { d.entries.find(e => e.id === "jeju_1").world = "dungeon"; });
  assert.ok(errors(buildContent(root)).some(e => e.includes("jeju_1") && e.includes("world")), "resolved pending refs must undergo the normal world/set check");
});

test("unregistered missing references are errors, including future slices", t => {
  const root = sandbox(t);
  editAudio(root, d => { d.routes.delivery.slice_to_music.unknown_1 = "music:dungeon"; d.music_sets[0].slices.push("unknown_1"); });
  assert.ok(errors(buildContent(root)).some(e => e.includes("slice:unknown_1")));
  editAudio(root, d => { d.pending_references = []; });
  assert.ok(errors(buildContent(root)).some(e => e.includes("slice:jeju_1")));
});

test("audio entry UIDs, IDs, namespaces, source paths and duplicate aliases are checked", t => {
  const root = sandbox(t);
  editAudio(root, d => {
    d.entries[0].id = "Push Bad"; d.entries[0].uid = "sfx.push";
    d.entries[1].source = "../outside.wav";
    d.entries.push({ ...d.entries[2] });
    d.music_sets.push({ ...d.music_sets[0] });
  });
  const e = errors(buildContent(root));
  assert.ok(e.some(s => s.includes("编号")));
  assert.ok(e.some(s => s.includes("uid")));
  assert.ok(e.some(s => s.includes("source")));
  assert.ok(e.some(s => s.includes("重复")));
});

test("music sets require three distinct own candidates and every candidate is assigned once", t => {
  const root = sandbox(t);
  editAudio(root, d => { d.music_sets[0].candidates = ["music:dungeon_a", "music:dungeon_a"]; d.music_sets[1].candidates.push("music:dungeon_b"); });
  const e = errors(buildContent(root));
  assert.ok(e.some(s => s.includes("至少") && s.includes("3")));
  assert.ok(e.some(s => s.includes("重复")));
  assert.ok(e.some(s => s.includes("归属") || s.includes("set")));
  assert.ok(e.some(s => s.includes("dungeon_c")));
});

test("routes validate slices/worlds/groups and derive chapters from group themes and level.chapter", t => {
  const root = sandbox(t);
  editAudio(root, d => {
    d.routes.world_to_music.mars = "music:dungeon";
    d.routes.group_to_chapter.phantom = "dungeon";
    d.routes.group_to_chapter.basics = "ruins";
    d.routes.chapter_to_music.unwritten = "music:dungeon";
    d.routes.chapter_to_music.forest = "music:missing_set";
  });
  const e = errors(buildContent(root));
  for (const s of ["world:mars", "group:phantom", "basics", "chapter:unwritten", "music:missing_set"]) assert.ok(e.some(x => x.includes(s)), s);
  // A chapter actually present in level data is allowed without inventing a chapter catalog.
  editAudio(root, d => { delete d.routes.world_to_music.mars; delete d.routes.group_to_chapter.phantom; d.routes.group_to_chapter.basics = "dungeon"; d.routes.chapter_to_music.forest = "music:dungeon"; });
  write(root, "content/levels/lab/custom/Z01.json", { format: "pushbox.levelspec/1", id: "Z01", chapter: "unwritten" });
  assert.deepEqual(errors(buildContent(root)), []);
});

test("default/fallback endpoint, policy safety, export format and audio ranges are real assertions", t => {
  const root = sandbox(t);
  editAudio(root, d => {
    d.policy.default_music_uid = "music:missing";
    d.policy.fallback_order = ["requested_set_approved_selection", "music:dungeon_approved_selection"];
    d.policy.unapproved_in_game = true;
    d.policy.export.sample_rate = 48000;
    d.policy.metrics.fundamental_hz = [1760, 65];
    d.entries[0].duration_ms = 1700;
    d.entries[1].priority = 4;
    d.entries.find(e => e.kind === "music").bpm = 120;
  });
  const e = errors(buildContent(root));
  for (const field of ["default_music_uid", "fallback_order", "unapproved_in_game", "sample_rate", "fundamental_hz", "duration_ms", "priority", "bpm"]) assert.ok(e.some(s => s.includes(field)), field);
});

test("malformed audio objects report field errors without throwing", t => {
  const root = sandbox(t);
  for (const field of ["entries", "music_sets", "policy", "routes", "pending_references"]) {
    write(root, "content/catalog/audio.json", { ...audioCatalog(), [field]: null });
    assert.ok(errors(buildContent(root)).some(e => e.includes(field)), field);
  }
});

test("a valid preview is review, missing/corrupt preview is missing, neither can import", t => {
  const root = sandbox(t), man = manifest(root), e = man.entries.find(e => e.uid === "sfx:push");
  write(root, e.source, { uid: e.uid });
  e.current = medium(root, e, 1);
  write(root, "audio/export/manifest.json", man);
  let res = buildContent(root);
  assert.equal(id(res, e.uid).availability, "review");
  assert.equal(id(res, e.uid).importable, false);
  assert.equal(id(res, e.uid).game_audio, null);
  write(root, e.current.wav, "corrupt");
  assert.equal(id(buildContent(root), e.uid).availability, "missing");
  fs.rmSync(path.join(root, e.current.wav));
  assert.equal(id(buildContent(root), e.uid).availability, "missing");
});

test("approved historical media remains importable while a new current version awaits approval", t => {
  const root = sandbox(t), man = manifest(root), e = man.entries.find(e => e.uid === "sfx:push");
  write(root, e.source, { uid: e.uid });
  e.current = medium(root, e, 2); e.approved = [medium(root, e, 1, true)]; recordApproval(root, e, e.approved[0]);
  write(root, "audio/export/manifest.json", man);
  let mapped = id(buildContent(root), e.uid);
  assert.equal(mapped.availability, "approved");
  assert.equal(mapped.importable, true);
  assert.equal(mapped.current_is_approved, false);
  assert.equal(mapped.game_audio.version, 1);
  assert.equal(mapped.game_audio.wav, "audio/export/approved/sfx/push@v1.wav");
  write(root, e.approved[0].wav, "corrupt");
  mapped = id(buildContent(root), e.uid);
  assert.equal(mapped.importable, false);
  assert.equal(mapped.game_audio, null);
});

test("music aliases require explicit matching approved bindings; wrong set and corrupt media cannot import", t => {
  const root = sandbox(t), man = manifest(root), e = man.entries.find(e => e.uid === "music:dungeon_a");
  write(root, e.source, { uid: e.uid });
  e.current = medium(root, e, 1); e.approved = [medium(root, e, 1, true)]; recordApproval(root, e, e.approved[0]);
  write(root, "audio/export/manifest.json", man);
  assert.equal(id(buildContent(root), "music:dungeon").importable, false, "quality approval is not set selection");
  man.bindings["music:dungeon"] = { uid: e.uid, ...e.approved[0] }; recordApproval(root, e, e.approved[0], "music:dungeon");
  write(root, "audio/export/manifest.json", man);
  let res = buildContent(root);
  assert.equal(id(res, "music:dungeon").availability, "approved");
  assert.equal(id(res, "music:dungeon").game_audio.uid, e.uid);
  man.bindings["music:diyu"] = man.bindings["music:dungeon"];
  write(root, "audio/export/manifest.json", man);
  assert.equal(id(buildContent(root), "music:diyu").importable, false);
  write(root, e.approved[0].wav, "corrupt");
  assert.equal(id(buildContent(root), "music:dungeon").importable, false);
});

test("audio approval status cannot be forged in manifest without records and valid history", t => {
  const root = sandbox(t), man = manifest(root), e = man.entries.find(e => e.uid === "sfx:push");
  write(root, e.source, { uid: e.uid }); e.current = medium(root, e, 1); e.approved = [medium(root, e, 1, true)];
  write(root, "audio/export/manifest.json", man);
  fs.rmSync(path.join(root, "audio/approvals.json"), { force: true });
  assert.equal(id(buildContent(root), e.uid).importable, false, "manifest cannot invent user approval");
  recordApproval(root, e, e.approved[0]);
  assert.equal(id(buildContent(root), e.uid).importable, true);
  fs.rmSync(path.join(root, e.approved[0].history));
  assert.equal(id(buildContent(root), e.uid).importable, false, "history is required");
  write(root, e.approved[0].history, { format: "pushbox.audio-history/1", uid: e.uid });
  assert.equal(id(buildContent(root), e.uid).importable, false, "corrupt history is rejected");
});

test("manifest selections must match the actual user adoption records", t => {
  const root = sandbox(t), man = manifest(root), e = man.entries.find(e => e.uid === "music:dungeon_a");
  write(root, e.source, { uid: e.uid }); e.current = medium(root, e, 1); e.approved = [medium(root, e, 1, true)];
  recordApproval(root, e, e.approved[0]);
  man.bindings["music:dungeon"] = { uid: e.uid, ...e.approved[0] };
  write(root, "audio/export/manifest.json", man);
  assert.equal(id(buildContent(root), "music:dungeon").importable, false, "quality record cannot stand in for adoption");
  recordApproval(root, e, e.approved[0], "music:dungeon");
  assert.equal(id(buildContent(root), "music:dungeon").importable, true);
});

test("audio JSON null and nested malformed manifest report errors without throwing", t => {
  const root = sandbox(t);
  write(root, "content/catalog/audio.json", "null");
  assert.ok(errors(buildContent(root)).length);
  write(root, "content/catalog/audio.json", audioCatalog());
  write(root, "audio/export/manifest.json", "null");
  assert.ok(errors(buildContent(root)).length);
  write(root, "audio/export/manifest.json", { ...manifest(root), entries: [null] });
  assert.ok(errors(buildContent(root)).length);
});

test("catalog object field order has no effect on validated policy meaning", t => {
  const root = sandbox(t);
  editAudio(root, d => { d.policy.preview_defaults = { sfx: 0.8, music: 0.8, master: 0.8 }; d.policy.metrics.sfx_rms_dbfs = { tolerance: 2, target: -24 }; });
  assert.deepEqual(errors(buildContent(root)), []);
});

test("latest valid quality confirmation follows records, never manifest array order", t => {
  const root = sandbox(t), man = manifest(root), e = man.entries.find(e => e.uid === "sfx:push");
  write(root, e.source, { uid: e.uid }); e.current = medium(root, e, 2);
  const first = medium(root, e, 1, true), last = medium(root, e, 2, true);
  e.approved = [last, first]; // A stale/reordered manifest cannot reverse the recorded facts.
  recordApproval(root, e, first);
  const table = json(path.join(root, "audio/approvals.json"));
  recordApproval(root, e, last);
  table.records.push({ ...json(path.join(root, "audio/approvals.json")).records[0], id: "AAP-0002" });
  write(root, "audio/approvals.json", table); write(root, "audio/export/manifest.json", man);
  assert.equal(id(buildContent(root), e.uid).game_audio.version, 2);
});

test("quality approval requires record ID, valid date, actor, channel and nonempty user statement", t => {
  const root = sandbox(t), man = manifest(root), e = man.entries.find(e => e.uid === "sfx:push");
  write(root, e.source, { uid: e.uid }); e.current = medium(root, e, 1); e.approved = [medium(root, e, 1, true)];
  write(root, "audio/export/manifest.json", man);
  recordApproval(root, e, e.approved[0]);
  assert.equal(id(buildContent(root), e.uid).importable, true, "complete fixture must represent a usable confirmation");
  for (const field of ["id", "date", "by", "via", "note"]) {
    recordApproval(root, e, e.approved[0]);
    edit(root, "audio/approvals.json", a => { delete a.records[0][field]; });
    let res = buildContent(root);
    assert.equal(id(res, e.uid).importable, false, `missing ${field} cannot approve audio`);
    assert.ok(errors(res).some(x => x.includes(`records[0].${field}`)), `missing ${field} identifies its record field`);
    recordApproval(root, e, e.approved[0]);
    edit(root, "audio/approvals.json", a => { a.records[0][field] = "   "; });
    res = buildContent(root);
    assert.equal(id(res, e.uid).importable, false, `blank ${field} cannot approve audio`);
    assert.ok(errors(res).some(x => x.includes(`records[0].${field}`)), `blank ${field} identifies its record field`);
  }
  for (const date of ["not-a-date", "2026-02-30T00:00:00.000Z", "2026-13-17T00:00:00.000Z"]) {
    recordApproval(root, e, e.approved[0]);
    edit(root, "audio/approvals.json", a => { a.records[0].date = date; });
    const res = buildContent(root);
    assert.equal(id(res, e.uid).importable, false, `invalid date ${date} cannot approve audio`);
    assert.ok(errors(res).some(x => x.includes("records[0].date")));
  }
});

test("adoption records missing user statement cannot select a music alias", t => {
  const root = sandbox(t), man = manifest(root), e = man.entries.find(e => e.uid === "music:dungeon_a");
  write(root, e.source, { uid: e.uid }); e.current = medium(root, e, 1); e.approved = [medium(root, e, 1, true)];
  recordApproval(root, e, e.approved[0]);
  const table = json(path.join(root, "audio/approvals.json"));
  table.records.push({ id: "AAP-0002", date: "2026-10-17T09:00:00.000Z", by: "隔离测试", via: "test", items: [], selections: [{ set_uid: "music:dungeon", uid: e.uid, version: 1, hash: e.approved[0].hash }] });
  man.bindings["music:dungeon"] = { uid: e.uid, ...e.approved[0] };
  write(root, "audio/approvals.json", table); write(root, "audio/export/manifest.json", man);
  const res = buildContent(root);
  assert.equal(id(res, e.uid).importable, true, "valid earlier quality confirmation remains usable");
  assert.equal(id(res, "music:dungeon").importable, false, "adoption also requires a recorded explicit user statement");
  assert.ok(errors(res).some(x => x.includes("records[1].note")));
});
