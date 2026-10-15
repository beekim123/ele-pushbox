/* Entry: hash routing (#view/id), navigation state, badges, toast and downloads. */
(function (root) {
  "use strict";
  const store = root.PBStore;
  const VIEWS = { overview: root.PBOverview, modes: root.PBModes, mechanisms: root.PBMechanisms, catalog: root.PBCatalog, scenes: root.PBScenes, assets: root.PBAssets, edit: root.PBEditor, review: root.PBReview, export: root.PBExport };
  let active = null;

  function toast(msg) {
    const t = document.getElementById("toast");
    t.textContent = msg; t.hidden = false;
    clearTimeout(toast.timer); toast.timer = setTimeout(() => { t.hidden = true; }, 2600);
  }
  function download(name, text) {
    const a = document.createElement("a");
    a.href = URL.createObjectURL(new Blob([text], { type: "application/json" }));
    a.download = name; document.body.append(a); a.click();
    setTimeout(() => { URL.revokeObjectURL(a.href); a.remove(); }, 1000);
    toast("已下载 " + name);
  }
  function updateBadges() {
    const n = store.draftCount(), flag = document.getElementById("drafts-flag");
    flag.hidden = !n; flag.textContent = `本地未导出修改 ${n} 项`;
    const r = Object.keys(store.review().selected).length, rc = document.getElementById("review-count");
    rc.hidden = !r; rc.textContent = String(r);
  }

  function route() {
    const [view, ...rest] = (location.hash.slice(1) || "overview").split("/");
    const name = VIEWS[view] ? view : "overview";
    const id = rest.join("/") || null;
    for (const v of Object.keys(VIEWS)) {
      const sec = document.getElementById("view-" + v);
      const on = v === name;
      if (!on && !sec.hidden && VIEWS[v].hide) VIEWS[v].hide();
      sec.hidden = !on;
    }
    for (const a of document.querySelectorAll(".tabs a")) {
      if (a.dataset.view === name) a.setAttribute("aria-current", "page"); else a.removeAttribute("aria-current");
    }
    active = name;
    VIEWS[name].show(id);
    updateBadges();
  }

  function init() {
    if (!root.PB_BUNDLE) {
      document.querySelector("main").innerHTML = '<div class="page"><h2>缺少数据</h2><p>没有找到 data/bundle.js。请在仓库根目录运行 <code>node tools/art.mjs build</code>。</p></div>';
      return;
    }
    store.registerAll();
    const sel = document.getElementById("appearance");
    sel.value = root.PBAppearance.get();
    sel.addEventListener("change", () => root.PBAppearance.set(sel.value));
    store.on(updateBadges);
    window.addEventListener("hashchange", route);
    document.addEventListener("keydown", (e) => { if (active === "edit") root.PBEditor.onKey(e); });
    window.addEventListener("beforeunload", (e) => {
      if (!store.storageOk() && store.draftCount()) { e.preventDefault(); e.returnValue = ""; }
    });
    route();
  }
  root.PBMain = { toast, download, updateBadges };
  init();
})(window);
