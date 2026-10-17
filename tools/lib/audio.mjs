// Deterministic, dependency-free synthesis for the PORTITOR audio source format.
import { createHash } from 'node:crypto';
import { readFileSync } from 'node:fs';

const RATE = 44100;
const COMMON = ['format', 'kind', 'id', 'uid', 'name', 'description', 'seed', 'engine', 'sample_rate', 'channels', 'version', 'content_hash', 'gain_db', 'instruments'];
const INSTRUMENT = ['id', 'wave', 'pulse_width', 'gain_db', 'lowpass_hz', 'attack_ms', 'decay_ms', 'sustain', 'release_ms'];
const EVENT = ['instrument', 'start_ms', 'duration_ms', 'note', 'slide_to_note', 'gain_db'];
const NOTE = ['beat', 'length', 'note', 'gain_db'];
const sha = value => createHash('sha256').update(value).digest('hex');
const own = (obj, key) => Object.prototype.hasOwnProperty.call(obj, key);
const hz = note => 440 * 2 ** ((note - 69) / 12);
const gain = db => 10 ** (db / 20);
const db = amplitude => amplitude > 0 ? 20 * Math.log10(amplitude) : -Infinity;
const canonical = value => Array.isArray(value) ? value.map(canonical) : value && typeof value === 'object' ? Object.fromEntries(Object.keys(value).sort().map(key => [key, canonical(value[key])])) : value;

export function rendererFingerprint() { return sha(readFileSync(new URL(import.meta.url))); }
export function sourceHash(source, fingerprint = rendererFingerprint()) {
  const sound = Object.fromEntries(Object.entries(source).filter(([key]) => !['name', 'description', 'version', 'content_hash'].includes(key)));
  return sha(JSON.stringify(canonical({ source: sound, renderer_fingerprint: fingerprint, encoding: 'pcm_s16le', sample_rate: RATE, channels: 1 })));
}

function failure(uid, field, message) { throw new Error(`${uid} ${field}: ${message}`); }
function record(value, fields, uid, path) {
  if (!value || typeof value !== 'object' || Array.isArray(value)) failure(uid, path, 'must be an object');
  for (const key of Object.keys(value)) if (!fields.includes(key)) failure(uid, path ? `${path}.${key}` : key, 'unknown field');
}
function numeric(value, min, max, uid, path, integer = false) {
  if (typeof value !== 'number' || !Number.isFinite(value) || value < min || value > max || (integer && !Number.isInteger(value))) failure(uid, path, `must be ${integer ? 'an integer' : 'finite'} in [${min}, ${max}]`);
}
function text(value, uid, path) { if (typeof value !== 'string' || !value.trim()) failure(uid, path, 'must be a nonempty string'); }
function equal(value, expected, uid, path) { if (JSON.stringify(value) !== JSON.stringify(expected)) failure(uid, path, `must equal ${JSON.stringify(expected)}`); }
function list(value, uid, path, min = 1) { if (!Array.isArray(value) || value.length < min) failure(uid, path, `must be an array with at least ${min} item(s)`); }
function pitch(value, instrument, uid, path, policy) {
  if (instrument.wave === 'noise') { if (value !== undefined) failure(uid, path, 'noise must omit pitched notes'); return; }
  numeric(value, ...policy.note_midi_range, uid, path, true);
  numeric(hz(value), ...policy.metrics.fundamental_hz, uid, `${path}.fundamental_hz`);
}
function sourceEvents(source) {
  const instruments = new Map(source.instruments.map(i => [i.id, i]));
  if (source.kind === 'sfx') return source.events.map((e, index) => {
    const start = Math.round(e.start_ms * RATE / 1000);
    const gateEnd = Math.round((e.start_ms + e.duration_ms) * RATE / 1000);
    return { ...e, index, instrument: instruments.get(e.instrument), start, gate: gateEnd - start };
  });
  const beatSamples = RATE * 60 / source.bpm;
  return source.tracks.flatMap((track, ti) => track.notes.map((n, ni) => {
    const start = Math.round(n.beat * beatSamples);
    return { ...n, index: `${ti}:${ni}`, instrument: instruments.get(track.instrument), start, gate: Math.round((n.beat + n.length) * beatSamples) - start };
  }));
}
function sampleCount(source) { return source.kind === 'music' ? Math.round(RATE * source.bars * source.meter[0] * 60 / source.bpm) : Math.round(RATE * source.duration_ms / 1000); }
function voiceCounts(events, period, circular) {
  const points = []; let active = 0, pitched = 0;
  const add = (start, end, isPitched) => { points.push([start, 1, isPitched ? 1 : 0], [end, -1, isPitched ? -1 : 0]); };
  for (const e of events) {
    let duration = e.gate + Math.ceil(e.instrument.release_ms * RATE / 1000);
    const isPitched = e.instrument.wave !== 'noise';
    if (!circular) { add(e.start, e.start + duration, isPitched); continue; }
    const full = Math.floor(duration / period);
    active += full; if (isPitched) pitched += full;
    duration -= full * period;
    if (duration === 0) continue;
    const start = e.start % period, end = start + duration;
    if (end <= period) add(start, end, isPitched);
    else { add(start, period, isPitched); add(0, end - period, isPitched); }
  }
  let totalMax = active, pitchedMax = pitched;
  points.sort((a, b) => a[0] - b[0] || a[1] - b[1]);
  for (const [, delta, pitchDelta] of points) { active += delta; pitched += pitchDelta; totalMax = Math.max(totalMax, active); pitchedMax = Math.max(pitchedMax, pitched); }
  return { voice_max: totalMax, pitched_voice_max: pitchedMax };
}

export function validateSource(source, entry, policy) {
  const uid = entry?.uid || source?.uid || '(unknown audio uid)';
  const kind = entry?.kind || source?.kind;
  record(source, [...COMMON, ...(kind === 'music' ? ['set', 'bpm', 'meter', 'bars', 'mode', 'tracks'] : ['duration_ms', 'events', 'loop'])], uid, '');
  equal(source.format, 'pushbox.audio/1', uid, 'format');
  equal(source.engine, 'portitor-chip/1', uid, 'engine');
  if (!['sfx', 'music'].includes(kind)) failure(uid, 'kind', 'must be sfx or music');
  equal(source.kind, kind, uid, 'kind');
  equal(source.uid, entry.uid, uid, 'uid'); equal(source.id, entry.id, uid, 'id');
  if (!/^[a-z0-9][a-z0-9_-]*$/.test(source.id)) failure(uid, 'id', 'invalid local identifier');
  text(source.name, uid, 'name');
  if (own(source, 'description') && typeof source.description !== 'string') failure(uid, 'description', 'must be a string');
  equal(source.sample_rate, RATE, uid, 'sample_rate'); equal(source.channels, 1, uid, 'channels');
  numeric(source.seed, 0, 0xffffffff, uid, 'seed', true);
  numeric(source.version, 0, Number.MAX_SAFE_INTEGER, uid, 'version', true);
  if (source.content_hash !== null && !/^[a-f0-9]{64}$/.test(source.content_hash || '')) failure(uid, 'content_hash', 'must be null or a SHA-256 digest');
  numeric(source.gain_db, -60, 0, uid, 'gain_db');
  list(source.instruments, uid, 'instruments');
  const instruments = new Map();
  source.instruments.forEach((i, index) => {
    const path = `instruments[${index}]`;
    record(i, INSTRUMENT, uid, path); text(i.id, uid, `${path}.id`);
    if (!/^[a-z0-9][a-z0-9_-]*$/.test(i.id) || instruments.has(i.id)) failure(uid, `${path}.id`, 'invalid or duplicate instrument id');
    if (!['sine', 'triangle', 'pulse', 'noise'].includes(i.wave)) failure(uid, `${path}.wave`, 'unsupported waveform');
    if (i.wave === 'pulse') { if (![0.25, 0.5].includes(i.pulse_width)) failure(uid, `${path}.pulse_width`, 'must be 0.25 or 0.5'); }
    else if (own(i, 'pulse_width')) failure(uid, `${path}.pulse_width`, 'only allowed for pulse');
    numeric(i.gain_db, -60, 0, uid, `${path}.gain_db`);
    numeric(i.lowpass_hz, 200, Math.min(4000, policy.metrics.lowpass_hz_max), uid, `${path}.lowpass_hz`);
    numeric(i.attack_ms, 8, 200, uid, `${path}.attack_ms`);
    numeric(i.decay_ms, 0, 500, uid, `${path}.decay_ms`);
    numeric(i.sustain, 0, 1, uid, `${path}.sustain`);
    numeric(i.release_ms, 25, 1500, uid, `${path}.release_ms`);
    instruments.set(i.id, i);
  });
  const instrumentAt = (id, path) => { if (!instruments.has(id)) failure(uid, path, 'unknown instrument'); return instruments.get(id); };
  if (kind === 'sfx') {
    numeric(source.duration_ms, 0.01, Math.min(policy.sfx_duration_max_ms, entry.duration_ms), uid, 'duration_ms');
    if (own(source, 'loop')) { if (source.loop !== true || source.id !== 'reel_spin') failure(uid, 'loop', 'only reel_spin supports loop:true'); }
    if (source.id === 'reel_spin') equal(source.loop, true, uid, 'loop');
    list(source.events, uid, 'events');
    source.events.forEach((e, index) => {
      const path = `events[${index}]`;
      record(e, EVENT, uid, path);
      const i = instrumentAt(e.instrument, `${path}.instrument`);
      numeric(e.start_ms, 0, source.duration_ms, uid, `${path}.start_ms`);
      numeric(e.duration_ms, 0.001, source.duration_ms, uid, `${path}.duration_ms`);
      if (e.start_ms + e.duration_ms + i.release_ms > source.duration_ms + 1e-9) failure(uid, `${path}.duration_ms`, 'gate plus release exceeds file duration');
      pitch(e.note, i, uid, `${path}.note`, policy);
      if (own(e, 'slide_to_note')) { if (i.wave === 'noise') failure(uid, `${path}.slide_to_note`, 'noise cannot slide'); pitch(e.slide_to_note, i, uid, `${path}.slide_to_note`, policy); }
      numeric(e.gain_db, -60, 0, uid, `${path}.gain_db`);
    });
  } else {
    equal(source.set, entry.set, uid, 'set'); text(source.mode, uid, 'mode');
    numeric(source.bpm, ...policy.music_bpm_range, uid, 'bpm'); equal(source.bpm, entry.bpm, uid, 'bpm');
    equal(source.meter, policy.music_meter, uid, 'meter'); equal(source.meter, entry.meter, uid, 'meter');
    equal(source.bars, policy.music_bars, uid, 'bars'); equal(source.bars, entry.bars, uid, 'bars');
    list(source.tracks, uid, 'tracks');
    if (source.tracks.length > policy.music_track_limit) failure(uid, 'tracks', `exceeds ${policy.music_track_limit} tracks`);
    source.tracks.forEach((track, ti) => {
      const path = `tracks[${ti}]`; record(track, ['instrument', 'notes'], uid, path);
      const i = instrumentAt(track.instrument, `${path}.instrument`);
      list(track.notes, uid, `${path}.notes`, 0);
      track.notes.forEach((n, ni) => {
        const np = `${path}.notes[${ni}]`; record(n, NOTE, uid, np);
        numeric(n.beat, 0, 128 - 1 / 16, uid, `${np}.beat`);
        numeric(n.length, 1 / 16, Number.MAX_SAFE_INTEGER, uid, `${np}.length`);
        for (const field of ['beat', 'length']) if (!Number.isSafeInteger(n[field] * 16)) failure(uid, `${np}.${field}`, 'must use 1/16 beat precision');
        pitch(n.note, i, uid, `${np}.note`, policy); numeric(n.gain_db, -60, 0, uid, `${np}.gain_db`);
      });
    });
    const voices = voiceCounts(sourceEvents(source), sampleCount(source), true);
    if (voices.pitched_voice_max > policy.music_pitched_voice_limit) failure(uid, 'tracks.pitched_voice_max', `exceeds ${policy.music_pitched_voice_limit} simultaneous pitched voices including releases`);
    if (voices.voice_max > policy.music_track_limit) failure(uid, 'tracks.voice_max', `exceeds ${policy.music_track_limit} simultaneous voices including releases`);
  }
}

function envelopeBeforeGate(age, instrument) {
  const a = instrument.attack_ms * RATE / 1000, d = instrument.decay_ms * RATE / 1000;
  if (age < a) return age / a;
  if (d > 0 && age < a + d) return 1 - (1 - instrument.sustain) * (age - a) / d;
  return instrument.sustain;
}
function renderVoice(mix, event, start, seed, energy) {
  const instrument = event.instrument, count = mix.length;
  const release = instrument.release_ms * RATE / 1000;
  const duration = event.gate + Math.ceil(release);
  const stop = Math.min(duration, count - start);
  const alpha = 1 - Math.exp(-2 * Math.PI * instrument.lowpass_hz / RATE);
  const volume = gain(instrument.gain_db + event.gain_db);
  const noteHz = instrument.wave === 'noise' ? 0 : hz(event.note);
  const slideHz = event.slide_to_note === undefined ? noteHz : hz(event.slide_to_note);
  const releaseLevel = envelopeBeforeGate(event.gate, instrument);
  let phase = 0, filtered = 0, random = seed || 1;
  for (let age = 0; age < stop; age++) {
    let raw;
    if (instrument.wave === 'noise') { random ^= random << 13; random ^= random >>> 17; random ^= random << 5; raw = (random >>> 0) / 2147483648 - 1; }
    else if (instrument.wave === 'sine') raw = Math.sin(2 * Math.PI * phase);
    else if (instrument.wave === 'triangle') raw = 1 - 4 * Math.abs(phase - 0.5);
    else raw = phase < instrument.pulse_width ? 1 : -instrument.pulse_width / (1 - instrument.pulse_width);
    filtered += alpha * (raw - filtered);
    const env = age < event.gate ? envelopeBeforeGate(age, instrument) : releaseLevel * Math.max(0, 1 - (age - event.gate) / release);
    const value = filtered * env * volume, position = start + age;
    if (position >= 0) { mix[position] += value; energy.total += value * value; if (instrument.wave === 'noise') energy.noise += value * value; }
    const frequency = noteHz + (slideHz - noteHz) * Math.min(1, age / Math.max(1, event.gate));
    phase += frequency / RATE; phase -= Math.floor(phase);
  }
}
function wavBuffer(pcm) {
  const wav = Buffer.alloc(44 + pcm.length * 2);
  wav.write('RIFF', 0); wav.writeUInt32LE(wav.length - 8, 4); wav.write('WAVEfmt ', 8); wav.writeUInt32LE(16, 16);
  wav.writeUInt16LE(1, 20); wav.writeUInt16LE(1, 22); wav.writeUInt32LE(RATE, 24); wav.writeUInt32LE(RATE * 2, 28);
  wav.writeUInt16LE(2, 32); wav.writeUInt16LE(16, 34); wav.write('data', 36); wav.writeUInt32LE(pcm.length * 2, 40);
  for (let n = 0; n < pcm.length; n++) wav.writeInt16LE(pcm[n], 44 + n * 2);
  return wav;
}
function measure(pcm, source, voices, energy, policy) {
  const count = pcm.length, threshold = 0.001;
  let peak = 0, sum = 0, square = 0, first = -1, last = -1, run = 0, longest = 0, leading = 0, stillLeading = true;
  for (let n = 0; n < count; n++) {
    const x = pcm[n] / 32768, abs = Math.abs(x);
    peak = Math.max(peak, abs); sum += x; square += x * x;
    if (abs >= threshold) { if (first < 0) first = n; last = n; }
    if (pcm[n] === 0) { run++; longest = Math.max(longest, run); if (stillLeading) leading++; }
    else { run = 0; stillLeading = false; }
  }
  const circular = source.kind === 'music' || source.loop === true;
  if (circular) longest = Math.min(count, Math.max(longest, leading + run));
  let activeSquare = 0;
  if (first >= 0) for (let n = first; n <= last; n++) activeSquare += (pcm[n] / 32768) ** 2;
  const activeCount = first >= 0 ? last - first + 1 : 0;
  const m = { verified: true, sample_rate: RATE, channels: 1, bit_depth: 16, sample_count: count, duration_ms: count * 1000 / RATE,
    active_sample_count: activeCount, rms_dbfs: db(Math.sqrt(source.kind === 'sfx' ? activeSquare / Math.max(1, activeCount) : square / count)),
    full_rms_dbfs: db(Math.sqrt(square / count)), peak_dbfs: db(peak), dc_abs: Math.abs(sum / count), noise_energy_ratio: energy.total > 0 ? energy.noise / energy.total : 0,
    endpoint_start_abs: Math.abs(pcm[0] / 32768), endpoint_end_abs: Math.abs(pcm[count - 1] / 32768), longest_silence_ms: longest * 1000 / RATE,
    track_count: source.kind === 'music' ? source.tracks.length : source.events.length, ...voices };
  if (circular) {
    m.seam_value_delta = Math.abs((pcm[0] - pcm[count - 1]) / 32768);
    m.seam_slope_delta = Math.abs(((pcm[1] - pcm[0]) - (pcm[count - 1] - pcm[count - 2])) / 32768);
  }
  if (source.kind === 'music') {
    const window = Math.round(policy.metrics.music_window_seconds * RATE), step = Math.round(policy.metrics.music_window_step_seconds * RATE);
    const windows = [];
    let windowSquare = 0;
    for (let n = 0; n < Math.min(window, count); n++) windowSquare += (pcm[n] / 32768) ** 2;
    const lastStart = count - window;
    for (let start = 0; start <= lastStart; start += step) {
      if (start > 0) {
        for (let n = start - step; n < start; n++) windowSquare -= (pcm[n] / 32768) ** 2;
        for (let n = start + window - step; n < start + window; n++) windowSquare += (pcm[n] / 32768) ** 2;
      }
      const rms = db(Math.sqrt(Math.max(0, windowSquare) / window));
      if (rms >= policy.metrics.music_window_ignore_below_dbfs) windows.push(rms);
    }
    m.window_count = Math.floor(lastStart / step) + 1; m.window_non_silent_count = windows.length;
    m.window_rms_min_dbfs = windows.length ? Math.min(...windows) : null;
    m.window_rms_max_dbfs = windows.length ? Math.max(...windows) : null;
    m.window_rms_range_db = windows.length ? Math.max(...windows) - Math.min(...windows) : 0;
  }
  return m;
}
function assertMetrics(metrics, source, policy) {
  const uid = source.uid, p = policy.metrics;
  const max = (field, limit) => { if (!Number.isFinite(metrics[field]) || metrics[field] > limit + 1e-12) failure(uid, `metrics.${field}`, `${metrics[field]} exceeds ${limit}`); };
  max('peak_dbfs', p.sample_peak_max_dbfs); max('noise_energy_ratio', p.noise_energy_ratio_max);
  const rms = source.kind === 'music' ? p.music_rms_dbfs : p.sfx_rms_dbfs;
  if (!Number.isFinite(metrics.rms_dbfs) || Math.abs(metrics.rms_dbfs - rms.target) > rms.tolerance + 1e-12) failure(uid, 'metrics.rms_dbfs', `${metrics.rms_dbfs} outside ${rms.target} ± ${rms.tolerance}`);
  max('dc_abs', p.dc_abs_max);
  if (source.kind === 'music' || source.loop) { max('seam_value_delta', p.music_seam_value_delta_max); max('seam_slope_delta', p.music_seam_slope_delta_max); }
  else { max('endpoint_start_abs', p.sfx_endpoint_abs_max); max('endpoint_end_abs', p.sfx_endpoint_abs_max); }
  if (source.kind === 'music') {
    max('window_rms_range_db', p.music_window_rms_range_max_db);
    if (metrics.longest_silence_ms >= p.music_full_silence_max_ms) failure(uid, 'metrics.longest_silence_ms', `must be less than ${p.music_full_silence_max_ms} ms`);
  }
}

export function renderAudio(source, entry, policy) {
  validateSource(source, entry, policy);
  const count = sampleCount(source), mix = new Float64Array(count), energy = { total: 0, noise: 0 };
  const events = sourceEvents(source), circular = source.kind === 'music' || source.loop === true;
  const voices = voiceCounts(events, count, circular);
  for (let ei = 0; ei < events.length; ei++) {
    const event = events[ei], duration = event.gate + Math.ceil(event.instrument.release_ms * RATE / 1000);
    const seed = ((source.seed || 1) ^ Math.imul(ei, 0x9e3779b9)) >>> 0;
    if (!circular) renderVoice(mix, event, event.start, seed, energy);
    else {
      // One complete pre-roll, plus every older note that still sustains into it.
      // Each absolute beat endpoint is rounded independently before scheduling.
      const firstCycle = Math.floor((-count - event.start - duration) / count) + 1;
      const lastCycle = Math.floor((count - 1 - event.start) / count);
      for (let cycle = firstCycle; cycle <= lastCycle; cycle++) renderVoice(mix, event, event.start + cycle * count, seed, energy);
    }
  }
  const pcm = new Int16Array(count), volume = gain(source.gain_db);
  for (let n = 0; n < count; n++) {
    const x = mix[n] * volume;
    if (!Number.isFinite(x)) failure(source.uid, `metrics.samples[${n}]`, 'non-finite sample');
    if (x > 32767 / 32768 || x < -1) failure(source.uid, 'metrics.clipping', `sample ${n} exceeds PCM range`);
    pcm[n] = Math.round(x * 32768);
  }
  const metrics = measure(pcm, source, voices, energy, policy);
  assertMetrics(metrics, source, policy);
  return { wav: wavBuffer(pcm), metrics };
}
