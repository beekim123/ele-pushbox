const { test } = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');
const vm = require('node:vm');

const artLabRoot = path.join(__dirname, '../tools/art-lab');
const html = fs.readFileSync(path.join(artLabRoot, 'index.html'), 'utf8');
const pageScripts = [...html.matchAll(/<script\b([^>]*)>([\s\S]*?)<\/script>/g)].map(match => {
  const src = match[1].match(/\bsrc="([^"]+)"/)?.[1];
  return {
    attributes: match[1],
    id: match[1].match(/\bid="([^"]+)"/)?.[1],
    src,
    source: src ? fs.readFileSync(path.join(artLabRoot, src), 'utf8') : match[2]
  };
});
function readPageScript(id) {
  const script = pageScripts.find(script => script.id === id);
  assert.ok(script, `Missing page script: ${id}`);
  return script.source;
}

test('HTML keeps markup only and loads local CSS and ordered classic scripts', () => {
  assert.equal(/<style\b|\sstyle=|\son(?:click|input|change)=/i.test(html), false,
    'HTML must not contain inline styles or event handlers');
  assert.ok(pageScripts.length > 1);
  for (const script of pageScripts) {
    assert.ok(script.src, 'JavaScript must live outside HTML');
    assert.doesNotMatch(script.attributes, /\b(?:async|defer)\b|type="module"/);
    new vm.Script(script.source, { filename: script.src });
  }
  const css = html.match(/<link\b[^>]*rel="stylesheet"[^>]*href="([^"]+)"/);
  assert.ok(css, 'Stylesheet must live outside HTML');
  assert.ok(fs.statSync(path.join(artLabRoot, css[1])).isFile());
});

// Exercise the actual appearance script without starting a browser or game.
function loadAppearance({ saved = null, dark = false, blockedStorage = false } = {}) {
  const source = readPageScript('appearance-script');
  const root = { dataset: {}, style: {} };
  const select = { value: '' };
  const events = {};
  const mediaEvents = {};
  const media = {
    matches: dark,
    addEventListener(name, callback) { mediaEvents[name] = callback; }
  };
  const storage = new Map(saved === null ? [] : [['pushbox-art-lab-theme', saved]]);
  let ready = false;
  const context = {
    document: {
      documentElement: root,
      getElementById(id) { return ready && id === 'themeSelect' ? select : null; },
      addEventListener(name, callback) { events[name] = callback; }
    },
    localStorage: {
      getItem(key) { if (blockedStorage) throw new Error('Storage disabled'); return storage.get(key) ?? null; },
      setItem(key, value) { if (blockedStorage) throw new Error('Storage disabled'); storage.set(key, value); }
    },
    matchMedia() { return media; }
  };
  context.window = context;
  vm.createContext(context);
  vm.runInContext(source, context);
  return {
    root, select, storage,
    setTheme(value) { context.setTheme(value); },
    ready() { ready = true; events.DOMContentLoaded(); },
    systemDark(value) { media.matches = value; mediaEvents.change({ matches: value }); }
  };
}

test('first visit follows the system before the page body is ready', () => {
  const app = loadAppearance({ dark: true });
  assert.equal(app.root.dataset.theme, 'dark');
  assert.equal(app.root.style.colorScheme, 'dark');
  app.ready();
  assert.equal(app.select.value, 'system');
});

test('a saved appearance wins over the system and restores the control', () => {
  const app = loadAppearance({ saved: 'light', dark: true });
  assert.equal(app.root.dataset.theme, 'light');
  app.ready();
  assert.equal(app.select.value, 'light');
});

test('switching appearance updates the page, control and saved preference', () => {
  const app = loadAppearance();
  app.ready();
  app.setTheme('dark');
  assert.equal(app.root.dataset.theme, 'dark');
  assert.equal(app.select.value, 'dark');
  assert.equal(app.storage.get('pushbox-art-lab-theme'), 'dark');
  const reopened = loadAppearance({ saved: app.storage.get('pushbox-art-lab-theme') });
  assert.equal(reopened.root.dataset.theme, 'dark');
});

test('system changes only affect the page while following the system', () => {
  const app = loadAppearance();
  app.ready();
  app.systemDark(true);
  assert.equal(app.root.dataset.theme, 'dark');
  app.setTheme('light');
  app.systemDark(false);
  app.systemDark(true);
  assert.equal(app.root.dataset.theme, 'light');
  app.setTheme('system');
  assert.equal(app.root.dataset.theme, 'dark');
});

test('an unknown saved value falls back to the system', () => {
  const app = loadAppearance({ saved: 'old-purple-theme', dark: true });
  app.ready();
  assert.equal(app.root.dataset.theme, 'dark');
  assert.equal(app.select.value, 'system');
});

test('disabled local storage does not stop initialization or theme switching', () => {
  const app = loadAppearance({ blockedStorage: true });
  app.ready();
  app.setTheme('dark');
  assert.equal(app.root.dataset.theme, 'dark');
  assert.equal(app.select.value, 'dark');
});

function loadWorkspace(narrow = true) {
  const source = readPageScript('workspace-script');
  const root = { dataset: { theme: 'dark' } };
  const events = {};
  const media = { matches: narrow, addEventListener(name, callback) { this.onchange = callback; } };
  const nodes = {};
  const document = {
    documentElement: root,
    activeElement: null,
    getElementById(id) { assert.ok(nodes[id], `Unknown ID: ${id}`); return nodes[id]; },
    addEventListener(name, callback) { events[name] = callback; }
  };
  for (const id of ['inspectorPanel', 'inspectorScrim', 'inspectorToggle', 'appHeader', 'categoryNav', 'galleryMain', 'closeInspectorBtn', 'lastControl', 'assetCard']) {
    nodes[id] = {
      attributes: {}, isConnected: true,
      setAttribute(name, value) { this.attributes[name] = value; },
      removeAttribute(name) { delete this.attributes[name]; },
      getClientRects() { return [1]; },
      focus() { document.activeElement = this; }
    };
  }
  nodes.inspectorPanel.querySelectorAll = () => [nodes.closeInspectorBtn, nodes.lastControl];
  document.activeElement = nodes.assetCard;
  const context = { document, matchMedia() { return media; } };
  context.window = context;
  vm.createContext(context);
  vm.runInContext(source, context);
  return {
    root, nodes, document,
    open(value) { context.setInspectorOpen(value); },
    resize(value) { media.matches = value; media.onchange(); },
    key(key, shiftKey = false) {
      const event = { key, shiftKey, prevented: false, preventDefault() { this.prevented = true; } };
      events.keydown(event);
      return event;
    }
  };
}

test('narrow layout starts with the inspector hidden and background usable', () => {
  const app = loadWorkspace();
  assert.equal(app.nodes.inspectorPanel.inert, true);
  assert.equal(app.nodes.inspectorPanel.attributes['aria-hidden'], 'true');
  assert.equal(app.nodes.inspectorScrim.hidden, true);
  assert.equal(app.nodes.galleryMain.inert, false);
});

test('opening the inspector focuses it and Escape returns focus to the selected asset', () => {
  const app = loadWorkspace();
  app.open(true);
  assert.equal(app.nodes.inspectorPanel.attributes.role, 'dialog');
  assert.equal(app.nodes.inspectorPanel.attributes['aria-modal'], 'true');
  assert.equal(app.nodes.inspectorPanel.inert, false);
  assert.equal(app.nodes.galleryMain.inert, true);
  assert.equal(app.nodes.appHeader.inert, true);
  assert.equal(app.document.activeElement, app.nodes.closeInspectorBtn);
  assert.equal(app.key('Escape').prevented, true);
  assert.equal(app.nodes.inspectorPanel.inert, true);
  assert.equal(app.nodes.galleryMain.inert, false);
  assert.equal(app.document.activeElement, app.nodes.assetCard);
});

test('keyboard focus wraps within an open narrow inspector', () => {
  const app = loadWorkspace();
  app.open(true);
  assert.equal(app.key('Tab', true).prevented, true);
  assert.equal(app.document.activeElement, app.nodes.lastControl);
  assert.equal(app.key('Tab').prevented, true);
  assert.equal(app.document.activeElement, app.nodes.closeInspectorBtn);
});

test('refreshing an already open inspector preserves its original return focus', () => {
  const app = loadWorkspace();
  app.open(true);
  app.nodes.lastControl.focus();
  app.open(true);
  app.open(false);
  assert.equal(app.document.activeElement, app.nodes.assetCard);
});

test('resizing to desktop closes the modal state and leaves the inspector usable', () => {
  const app = loadWorkspace();
  app.open(true);
  app.resize(false);
  assert.equal(app.nodes.inspectorPanel.inert, false);
  assert.equal(app.nodes.inspectorPanel.attributes.role, 'complementary');
  assert.equal(app.nodes.inspectorPanel.attributes['aria-modal'], undefined);
  assert.equal(app.nodes.appHeader.inert, false);
  assert.equal(app.nodes.inspectorScrim.hidden, true);
  assert.equal(app.root.dataset.theme, 'dark');
  app.resize(true);
  assert.equal(app.nodes.inspectorPanel.inert, true);
});

test('desktop inspector remains a nonmodal pane', () => {
  const app = loadWorkspace(false);
  app.open(true);
  assert.equal(app.nodes.inspectorPanel.inert, false);
  assert.equal(app.nodes.inspectorPanel.attributes.role, 'complementary');
  assert.equal(app.nodes.galleryMain.inert, false);
});

async function runCopy(writeText) {
  const allSource = pageScripts.map(script => script.source).join('\n');
  const source = allSource.slice(allSource.indexOf('async function copyInspectorCode()'), allSource.indexOf('function selectCategory(cat)'));
  assert.ok(source.startsWith('async function'), 'Copy handler must report its real result');
  const box = { value: 'sprite-matrix', focus() { this.focused = true; }, select() { this.selected = true; } };
  const status = {};
  const disclosure = {};
  const context = {
    navigator: { clipboard: { writeText } },
    document: {
      getElementById(id) { return id === 'inspCodeBox' ? box : status; },
      querySelector() { return disclosure; }
    }
  };
  vm.createContext(context);
  vm.runInContext(source, context);
  await context.copyInspectorCode();
  return { box, status, disclosure };
}

test('copy reports success after the clipboard accepts the actual asset data', async () => {
  let copied;
  const app = await runCopy(async text => { copied = text; });
  assert.equal(copied, 'sprite-matrix');
  assert.equal(app.status.textContent, '已复制资产数据');
});

test('clipboard denial opens and selects the data for manual copying', async () => {
  const app = await runCopy(async () => { throw new Error('Clipboard denied'); });
  assert.equal(app.disclosure.open, true);
  assert.equal(app.box.focused, true);
  assert.equal(app.box.selected, true);
  assert.match(app.status.textContent, /Ctrl\+C/);
});

test('scripts boot in HTML order and bind search, filters and animation', () => {
  // Minimal DOM/canvas adapter for integration checks; this is not a browser
  // layout test. Evaluate every real script in one shared classic-script scope.
  const all = [];
  function element(tag, attributes = {}) {
    const node = {
      tag, attributes: { ...attributes }, dataset: {}, style: {}, children: [], listeners: {},
      className: attributes.class ?? '', value: '', isConnected: true,
      setAttribute(name, value) { this.attributes[name] = value; },
      removeAttribute(name) { delete this.attributes[name]; },
      addEventListener(name, callback) { (this.listeners[name] ??= []).push(callback); },
      appendChild(child) { this.children.push(child); child.parentElement = this; },
      getContext() {
        return this.context2d ??= new Proxy({ fillRect() { node.paintCount = (node.paintCount ?? 0) + 1; } },
          { get: (object, key) => object[key] ?? (() => {}) });
      },
      focus() { document.activeElement = this; },
      getClientRects() { return [1]; },
      querySelector(selector) { return this.children.find(child => matches(child, selector)) ?? null; }
    };
    for (const [name, value] of Object.entries(attributes)) {
      if (name.startsWith('data-')) node.dataset[name.slice(5).replace(/-([a-z])/g, (_, c) => c.toUpperCase())] = value;
    }
    node.classList = {
      toggle(name, on) {
        const classes = new Set(node.className.split(/\s+/).filter(Boolean));
        if (on ?? !classes.has(name)) classes.add(name); else classes.delete(name);
        node.className = [...classes].join(' ');
      },
      add(name) { this.toggle(name, true); },
      remove(name) { this.toggle(name, false); }
    };
    Object.defineProperty(node, 'innerHTML', {
      set(value) {
        const disconnect = child => { child.isConnected = false; child.children.forEach(disconnect); };
        this.children.forEach(disconnect);
        this.children = [];
        const canvas = value.match(/<canvas[^>]*data-asset-id="([^"]+)"/);
        if (canvas) this.appendChild(element('canvas', { 'data-asset-id': canvas[1] }));
      }
    });
    all.push(node);
    return node;
  }
  function matches(node, selector) {
    if (selector.startsWith('.')) return node.className.split(/\s+/).includes(selector.slice(1));
    const data = selector.match(/^\[(data-[\w-]+)\]$/);
    if (data) return data[1] in node.attributes;
    if (selector === 'canvas[data-asset-id]') return node.tag === 'canvas' && 'assetId' in node.dataset;
    return node.tag === selector;
  }
  for (const match of html.matchAll(/<([a-z][\w-]*)\b([^>]*)>/gi)) {
    const attributes = Object.fromEntries([...match[2].matchAll(/([\w-]+)="([^"]*)"/g)].map(item => [item[1], item[2]]));
    element(match[1], attributes);
  }
  const document = {
    documentElement: all.find(node => node.tag === 'html'),
    activeElement: null,
    getElementById(id) { return all.find(node => node.attributes.id === id); },
    createElement(tag) { return element(tag); },
    querySelectorAll(selector) { return all.filter(node => node.isConnected && matches(node, selector)); },
    querySelector(selector) { return this.querySelectorAll(selector)[0]; },
    addEventListener() {}
  };
  const frames = [];
  const context = {
    document,
    performance: { now: () => 0 },
    requestAnimationFrame(callback) { frames.push(callback); },
    matchMedia() { return { matches: false, addEventListener() {} }; },
    localStorage: { getItem() { return null; }, setItem() {} },
    navigator: { clipboard: { async writeText() {} } }
  };
  context.window = context;
  vm.createContext(context);
  for (const script of pageScripts) vm.runInContext(script.source, context, { filename: script.src });
  const byId = id => document.getElementById(id);
  const click = node => node.listeners.click[0]({ target: node });
  assert.equal(byId('campShowcase')?.hidden, false, 'Completed artwork must be the default view');
  assert.equal(byId('assetLibrary').hidden, true);
  assert.equal(byId('showcaseChapterSelect').value, '1');
  assert.equal(byId('showcaseChapterSelect').children.length, 6);
  vm.runInContext('renderCampShowcase(0)', context);
  for (const id of ['showcaseLobbyCanvas', 'showcaseCampaignCanvas']) assert.ok(byId(id).paintCount > 500, id + ' must draw a complete scene');
  assert.ok(byId('showcaseMinerCanvas').paintCount > 0);
  const firstPaint = byId('showcaseCampaignCanvas').paintCount;
  vm.runInContext('renderCampShowcase(0.03)', context);
  assert.equal(byId('showcaseCampaignCanvas').paintCount, firstPaint, 'Showcase must use the shared 8 FPS cache');
  byId('showcaseChapterSelect').value = '4';
  byId('showcaseChapterSelect').listeners.change[0]({ target: byId('showcaseChapterSelect') });
  assert.equal(vm.runInContext('campPreviewState.chapter', context), 4);
  assert.equal(byId('uiChapterSelect').value, '4', 'Showcase and enlarged preview must share the selected theme');
  byId('showcaseProgressSelect').value = 'new';
  byId('showcaseProgressSelect').listeners.change[0]({ target: byId('showcaseProgressSelect') });
  assert.equal(byId('showcaseChapterSelect').value, '0');
  assert.equal(byId('showcaseChapterSelect').children[4].disabled, true);
  click(byId('showcasePlayPause'));
  assert.equal(vm.runInContext('isPlaying', context), false);
  click(byId('showcasePlayPause'));
  click(byId('libraryViewButton'));
  assert.equal(byId('campShowcase').hidden, true);
  assert.equal(byId('assetLibrary').hidden, false);
  vm.runInContext('renderCampShowcase(1)', context);
  assert.equal(byId('showcaseCampaignCanvas').paintCount, firstPaint, 'Hidden showcase must not redraw');
  click(byId('showcaseViewButton'));
  assert.equal(byId('campShowcase').hidden, false);
  assert.equal(byId('galleryCount').textContent, '42 项素材');
  assert.equal(byId('inspId').textContent, 'forest_bird');
  assert.equal(byId('inspPaletteBar').children.length, 33);
  assert.equal(frames.length, 1);
  byId('showcaseMinerInspect').focus();
  click(byId('showcaseMinerInspect'));
  assert.equal(byId('inspId').textContent, 'miner_dig');
  assert.equal(document.activeElement, byId('libraryViewButton'), 'Pixel editing link must leave focus on a visible library entry');
  click(byId('showcaseViewButton'));
  byId('searchInput').value = 'forest_bird';
  byId('searchInput').listeners.input[0]();
  assert.equal(byId('assetLibrary').hidden, false, 'Searching must reveal its results');
  assert.equal(byId('galleryCount').textContent, '1 项素材');
  byId('galleryContainer').listeners.click[0]({ target: { closest: () => true } });
  assert.equal(byId('galleryCount').textContent, '42 项素材');
  click(all.find(node => node.dataset.cat === 'map'));
  assert.equal(byId('galleryCount').textContent, '6 项素材');
  click(all.find(node => node.dataset.biome === 'forest'));
  assert.equal(byId('galleryCount').textContent, '1 项素材');
  click(byId('playPauseBtn'));
  assert.equal(byId('playPauseBtn').textContent, '播放动画');
  for (let i = 0; i < 6; i++) vm.runInContext(`renderLiveMapToCtx(inspCtx, ${i}, 0)`, context);
  vm.runInContext('renderUIPreviewToCtx(inspCtx, "ui_lobby", 0); renderUIPreviewToCtx(inspCtx, "ui_campaign", 0);', context);
  frames[0](16);
  assert.equal(frames.length, 2);
});
