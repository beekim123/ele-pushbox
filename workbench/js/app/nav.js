/* Workbench menu: left category menu, folding, left-column collapse and the
 * narrow-screen drawer. MENU is the only list of pages: the menu is drawn from
 * it and main.js builds its router from it. To add a page, add one entry to a
 * category here (plus the page's own <section id="view-…"> and view script).
 * Loaded in <head> so a collapsed left column never flashes open. */
(function (root) {
  "use strict";

  // { view, label, module } is a page; { group, label, items } is a category.
  // badge: id of a count shown after the label (filled by main.js).
  const MENU = [
    { view: "overview", label: "总览", module: "PBOverview" },
    { group: "play", label: "关卡与玩法", items: [
      { view: "modes", label: "模式与关卡", module: "PBModes" },
      { view: "mechanisms", label: "机制", module: "PBMechanisms" },
      { view: "catalog", label: "设计数据", module: "PBCatalog" },
    ] },
    { group: "delivery", label: "配送", items: [
      { view: "maps", label: "地图预览", module: "PBMaps" },
      { view: "rooms2", label: "配送 v2", module: "PBRooms2" },
    ] },
    { group: "art", label: "美术", items: [
      { view: "scenes", label: "场景", module: "PBScenes" },
      { view: "assets", label: "资产与动画", module: "PBAssets" },
      { view: "edit", label: "编辑与对比", module: "PBEditor" },
      { view: "review", label: "确认", module: "PBReview", badge: "review-count" },
      { view: "export", label: "导出", module: "PBExport", badge: "drafts-count", tone: "warn" },
    ] },
    { group: "tools", label: "工具", items: [
      { view: "ids", label: "编号映射", module: "PBIds" },
    ] },
    { group: "audio", label: "声音", items: [
      { view: "audio", route: "audio/sfx", label: "音效", module: "PBWBAudio" },
      { view: "audio", route: "audio/music", label: "音乐", module: "PBWBAudio" },
      { view: "audio", route: "audio/maps", label: "按地图", module: "PBWBAudio" },
    ] },
  ];

  const KEY = "pb.wb.nav.v1";
  const NARROW = "(max-width: 720px)";
  const doc = document.documentElement;

  // Remembered state; any storage failure falls back to defaults for this page.
  const state = { collapsed: false, groups: {} };
  try {
    const v = JSON.parse(localStorage.getItem(KEY) || "null");
    if (v && typeof v === "object") {
      state.collapsed = v.collapsed === true;
      if (v.groups && typeof v.groups === "object") for (const k of Object.keys(v.groups)) state.groups[k] = v.groups[k] !== false;
    }
  } catch (e) { /* storage unavailable or unreadable */ }
  function save() { try { localStorage.setItem(KEY, JSON.stringify(state)); } catch (e) { /* storage unavailable */ } }
  if (state.collapsed) doc.setAttribute("data-nav", "collapsed");

  const PAGES = [];
  for (const m of MENU) {
    if (m.items) for (const it of m.items) PAGES.push(Object.assign({ group: m.group, groupLabel: m.label }, it));
    else PAGES.push(Object.assign({ group: null, groupLabel: null }, m));
  }

  let nav = null, toggle = null, scrim = null, crumb = null, media = null, current = null;
  const links = new Map(), heads = new Map();

  function h(tag, attrs, kids) {
    const e = document.createElement(tag);
    for (const k of Object.keys(attrs || {})) {
      const v = attrs[k];
      if (v == null || v === false) continue;
      if (k === "text") e.textContent = v;
      else if (k.startsWith("on")) e.addEventListener(k.slice(2), v);
      else e.setAttribute(k, v === true ? "" : v);
    }
    for (const c of kids || []) if (c) e.append(c);
    return e;
  }

  const isOpen = (g) => state.groups[g] !== false;
  const narrow = () => !!(media && media.matches);
  const drawerOpen = () => doc.getAttribute("data-drawer") === "open";

  function link(p) {
    const a = h("a", { href: "#" + (p.route || p.view), "data-view": p.route || p.view, class: p.group ? null : "nav-link" }, [h("span", { text: p.label })]);
    if (p.badge) a.append(h("span", { class: "count" + (p.tone ? " " + p.tone : ""), id: p.badge, hidden: true }));
    links.set(p.route || p.view, a);
    return a;
  }

  function render() {
    nav.textContent = "";
    nav.append(h("div", { class: "nav-drawer-head" }, [
      h("strong", { text: "渡界人" }),
      h("button", { class: "btn small nav-close", type: "button", text: "关闭", onclick: () => setDrawer(false, true) }),
    ]));
    for (const m of MENU) {
      if (!m.items) { nav.append(link(PAGES.find((p) => p.view === m.view))); continue; }
      const listId = "nav-list-" + m.group;
      const dot = h("span", { class: "nav-dot", hidden: true });
      const head = h("button", { class: "nav-head", type: "button", "data-group": m.group, "aria-controls": listId, onclick: () => setGroup(m.group, !isOpen(m.group)) },
        [h("span", { class: "nav-head-label", text: m.label }), dot, h("span", { class: "chev", "aria-hidden": "true" })]);
      const list = h("ul", { class: "nav-list", id: listId, role: "list" }, PAGES.filter((p) => p.group === m.group).map((p) => h("li", {}, [link(p)])));
      nav.append(h("div", { class: "nav-group", "data-group": m.group }, [head, list]));
      heads.set(m.group, { head, list, dot, pages: PAGES.filter((p) => p.group === m.group) });
      applyGroup(m.group);
    }
  }

  function applyGroup(g) {
    const x = heads.get(g), open = isOpen(g);
    x.head.setAttribute("aria-expanded", String(open));
    x.list.hidden = !open;
    updateDots();
  }
  function setGroup(g, open) { state.groups[g] = !!open; save(); applyGroup(g); }

  // A folded category still shows that one of its pages has a count.
  function updateDots() {
    for (const [g, x] of heads) {
      const shown = x.pages.filter((p) => p.badge && document.getElementById(p.badge) && !document.getElementById(p.badge).hidden);
      x.dot.hidden = isOpen(g) || !shown.length;
      x.dot.title = shown.map((p) => `${p.label} ${document.getElementById(p.badge).textContent}`).join(" · ");
    }
  }
  function setBadge(id, n, title) {
    const b = document.getElementById(id);
    if (!b) return;
    b.hidden = !n; b.textContent = String(n || 0);
    if (title) b.title = title; else b.removeAttribute("title");
    updateDots();
  }

  function syncToggle() {
    if (!toggle) return;
    const shown = narrow() ? drawerOpen() : !state.collapsed;
    toggle.setAttribute("aria-expanded", String(shown));
    toggle.title = narrow() ? (shown ? "关闭菜单" : "打开菜单") : (shown ? "收起左栏" : "展开左栏");
  }
  function setCollapsed(c) {
    state.collapsed = !!c; save();
    if (state.collapsed) doc.setAttribute("data-nav", "collapsed"); else doc.removeAttribute("data-nav");
    syncToggle();
    window.dispatchEvent(new Event("resize")); // stages re-fit to the new width
  }
  function setDrawer(open, focusBack) {
    const was = drawerOpen();
    open = !!open && narrow();
    if (open) doc.setAttribute("data-drawer", "open"); else doc.removeAttribute("data-drawer");
    scrim.hidden = !open;
    for (const el of document.querySelectorAll("body > .topbar, body > main")) el.inert = open;
    syncToggle();
    if (open && !was) {
      const a = links.get(current);
      (a && a.offsetParent ? a : nav.querySelector(".nav-close")).focus();
    } else if (!open && was && focusBack) toggle.focus();
  }

  function setCurrent(view) {
    const changed = view !== current;
    current = view;
    const p = PAGES.find((x) => (x.route || x.view) === view) || null;
    for (const [v, a] of links) { if (v === view) a.setAttribute("aria-current", "page"); else a.removeAttribute("aria-current"); }
    for (const [g, x] of heads) x.head.classList.toggle("has-current", !!p && p.group === g);
    // Entering a page opens its category; moving inside the same page keeps the user's folding.
    if (changed && p && p.group && !isOpen(p.group)) setGroup(p.group, true);
    if (crumb) crumb.replaceChildren(...(p ? (p.groupLabel ? [h("span", { text: p.groupLabel + " › " }), h("b", { text: p.label })] : [h("b", { text: p.label })]) : []));
    if (changed && drawerOpen()) setDrawer(false, false);
  }

  function init() {
    nav = document.getElementById("nav");
    toggle = document.getElementById("nav-toggle");
    scrim = document.getElementById("nav-scrim");
    crumb = document.getElementById("nav-crumb");
    media = root.matchMedia ? root.matchMedia(NARROW) : null;
    render();
    toggle.addEventListener("click", () => { if (narrow()) setDrawer(!drawerOpen(), true); else setCollapsed(!state.collapsed); });
    scrim.addEventListener("click", () => setDrawer(false, true));
    nav.addEventListener("click", (e) => { if (e.target.closest("a[href]") && drawerOpen()) setDrawer(false, true); });
    document.addEventListener("keydown", (e) => { if (e.key === "Escape" && drawerOpen()) { e.preventDefault(); setDrawer(false, true); } });
    if (media) {
      const onChange = () => { setDrawer(false, false); syncToggle(); };
      if (media.addEventListener) media.addEventListener("change", onChange); else if (media.addListener) media.addListener(onChange);
    }
    syncToggle();
  }

  root.PBNav = {
    MENU, init, setCurrent, setBadge,
    pages: () => PAGES.slice(),
    drawerOpen,
    collapsed: () => state.collapsed,
  };
})(window);
