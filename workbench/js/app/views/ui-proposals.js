/* View · 界面风格提案 (UI-09, #ui-proposals): the generic interface style the
 * user chose, G2 深蓝圆角 — its six sample screens (click one for the original
 * size, 1× / 2× / 3×; #ui-proposals/<screen> opens it directly), the component
 * sheet on a dark and a light map, the palette, the text check, and a download
 * of the overview image that docs/packages/UI-09/G2_深蓝圆角.png was made from.
 * Everything is drawn by PB.uiGeneric (js/core/ui-generic.js). */
(function (root) {
  "use strict";
  const el = root.PBStage.el, store = root.PBStore;
  const G = () => root.PB.uiGeneric;
  const opt = { level: (id) => store.level(id) };
  const ZOOMS = [1, 2, 3];
  const FILE = "G2_深蓝圆角.png";
  const QUOTE = "我看了你思考过程中图了，G2.png 就是我想要的风格，直接按照这个生成吧";
  let page = null, dlg = null, dlgCanvas = null, dlgTitle = null, dlgSeg = null, dlgZoom = 2, zoom = 1, current = null;
  const shots = {};   // screen id -> { r, issues, canvas }

  function canvasOf(r, z, label) {
    const cv = el("canvas", { width: r.w, height: r.h, "aria-label": label });
    cv.getContext("2d").putImageData(new ImageData(r.data, r.w, r.h), 0, 0);
    size(cv, z);
    return cv;
  }
  function size(cv, z) { cv.style.width = cv.width * z + "px"; cv.style.height = cv.height * z + "px"; cv.style.imageRendering = "pixelated"; cv.style.display = "block"; }
  function seg(label, values, cur, text, pick) {
    const s = el("div", { class: "seg", role: "group", "aria-label": label });
    for (const v of values) {
      const b = el("button", { type: "button", "aria-pressed": String(v === cur), text: text(v), onclick: () => { for (const x of s.children) x.setAttribute("aria-pressed", String(x === b)); pick(v); } });
      s.append(b);
    }
    return s;
  }

  function download() {
    const big = G().scale(G().overview(opt).r, 2), cv = el("canvas", { width: big.w, height: big.h });
    cv.getContext("2d").putImageData(new ImageData(big.data, big.w, big.h), 0, 0);
    cv.toBlob((blob) => {
      const a = el("a", { href: URL.createObjectURL(blob), download: FILE });
      document.body.append(a); a.click();
      setTimeout(() => { URL.revokeObjectURL(a.href); a.remove(); }, 1000);
      if (root.PBMain) root.PBMain.toast("已下载 " + FILE);
    }, "image/png");
  }

  // The original-size viewer: one sample screen at 1× / 2× / 3×.
  function dialog() {
    dlgTitle = el("strong");
    dlgSeg = seg("放大倍数", ZOOMS, dlgZoom, (z) => (z === 1 ? "1×（原尺寸）" : z + "×"), (z) => { dlgZoom = z; if (dlgCanvas) size(dlgCanvas, z); });
    const body = el("div", { style: "overflow:auto;max-width:calc(100vw - 64px);max-height:calc(100vh - 140px);margin-top:10px" });
    dlg = el("dialog", { "aria-label": "样板图原尺寸", style: "max-width:calc(100vw - 24px);padding:14px;border:1px solid var(--line);border-radius:var(--radius);background:var(--panel);color:var(--text)" }, [
      el("div", { class: "btn-row" }, [dlgTitle, dlgSeg, el("button", { class: "btn", type: "button", text: "关闭", onclick: () => dlg.close() })]),
      body,
    ]);
    dlg.body = body;
    // Closing the viewer goes back to the page address (not when another page is opening).
    dlg.addEventListener("close", () => { current = null; if (location.hash.startsWith("#ui-proposals/")) history.replaceState(null, "", "#ui-proposals"); });
    return dlg;
  }
  function open(id) {
    const sc = G().SCREENS.find((s) => s.id === id);
    if (!sc) return close();
    current = id;
    dlgTitle.textContent = `${sc.name} · ${sc.note} · 320 × 180`;
    dlgCanvas = canvasOf(shots[id].r, dlgZoom, sc.name + "（原尺寸）");
    dlg.body.textContent = ""; dlg.body.append(dlgCanvas);
    if (!dlg.open) dlg.showModal();
  }
  function close() { if (dlg && dlg.open) dlg.close(); }

  function build() {
    page = document.getElementById("ui-proposals-root");
    page.textContent = "";
    const P = G().STYLE;
    page.append(
      el("h2", { text: `界面风格提案 · ${P.id} ${P.name}（已选定）` }),
      el("p", { class: "note info-note", text: `用户看过提案预览后选定 ${P.id} ${P.name}（原话：“${QUOTE}”）。这一页只放 ${P.id}：组件、调色和六张样板界面；下一步 UI-10 按这个风格做整套游戏界面和通用大厅。` }),
      el("p", { text: P.line }),
      el("p", { class: "small", text: P.fits }),
      el("p", { class: "small", text: P.notFits }));

    const bar = el("div", { class: "btn-row", style: "margin:12px 0" }, [
      el("span", { class: "small muted", text: "样板图放大" }),
      seg("样板图放大倍数", ZOOMS, zoom, (z) => z + "×", (z) => { zoom = z; for (const id in shots) size(shots[id].canvas, z); }),
      el("button", { class: "btn", type: "button", text: "下载总览图（PNG · 2 倍）", onclick: download }),
      el("span", { class: "small muted", text: `和 docs/packages/UI-09/${FILE} 是同一个函数画的` }),
    ]);
    page.append(bar);

    // Sample screens.
    page.append(el("h3", { text: "样板界面（320 × 180，点一张看原尺寸）" }));
    const grid = el("div", { id: "ui-proposals-shots", style: "display:flex;flex-wrap:wrap;gap:14px 12px" });
    let all = [];
    for (const sc of G().SCREENS) {
      const r = new root.PB.Raster(320, 180), iss = G().render(r, sc.id, opt), cv = canvasOf(r, zoom, sc.name);
      shots[sc.id] = { r, issues: iss, canvas: cv };
      all = all.concat(iss.map((i) => `${sc.name}：${i.kind} ${i.key} ${i.detail}`));
      grid.append(el("figure", { style: "margin:0;max-width:100%", "data-screen": sc.id }, [
        el("a", { href: "#ui-proposals/" + sc.id, title: "看原尺寸", style: "display:block;overflow:auto;max-width:100%" }, [cv]),
        el("figcaption", { class: "small" }, [el("strong", { text: sc.name }), el("span", { class: "muted", text: " · " + sc.note })]),
      ]));
    }
    page.append(grid);

    // Components on a dark and a light map.
    const S = G().STRIPS;
    page.append(el("h3", { text: "组件" }), el("p", { class: "small muted", text: `每个组件画两次：左边放在暗图上（${S.dark.note}），右边放在亮图上（${S.light.note}）。像素按 2 倍显示。` }));
    const tb = el("tbody");
    for (const cp of G().COMPONENTS) {
      const cells = ["dark", "light"].map((tone) => {
        const r = new root.PB.Raster(G().CW, cp.h), iss = G().component(r, cp.id, tone, opt);
        all = all.concat(iss.map((i) => `${cp.name}（${tone === "dark" ? "暗图" : "亮图"}）：${i.kind} ${i.key} ${i.detail}`));
        return el("td", {}, [canvasOf(r, 2, `${cp.name} · ${tone === "dark" ? "暗图上" : "亮图上"}`)]);
      });
      tb.append(el("tr", { "data-component": cp.id }, [el("td", { style: "white-space:nowrap" }, [el("strong", { text: cp.name })]), ...cells, el("td", { class: "small", text: cp.note })]));
    }
    page.append(el("div", { style: "overflow-x:auto" }, [el("table", { class: "grid", id: "ui-proposals-components" }, [
      el("thead", {}, [el("tr", {}, ["组件", "暗图上", "亮图上", "说明"].map((x) => el("th", { text: x })))]), tb])]));

    // Palette.
    page.append(el("h3", { text: "调色（ENDESGA32 代码）" }));
    const pb = el("tbody");
    for (const [code, use] of P.colors) {
      const hex = root.PB.PALETTE[code];
      pb.append(el("tr", {}, [
        el("td", {}, [el("span", { style: `display:inline-block;width:22px;height:22px;border-radius:3px;border:1px solid var(--line);background:${hex}`, title: hex })]),
        el("td", { class: "mono", text: code }), el("td", { class: "mono small", text: hex }), el("td", { text: use })]));
    }
    page.append(el("div", { style: "overflow-x:auto" }, [el("table", { class: "grid", id: "ui-proposals-colors" }, [
      el("thead", {}, [el("tr", {}, ["色块", "代码", "颜色", "用途"].map((x) => el("th", { text: x })))]), pb])]));

    // Text check: every string is measured against its room, the screen edge and the fonts.
    page.append(el("h3", { text: "文字检查" }));
    page.append(all.length
      ? el("div", { class: "note", id: "ui-proposals-check" }, [el("strong", { text: `${all.length} 个问题` }), el("ul", {}, all.slice(0, 30).map((x) => el("li", { class: "small", text: x })))])
      : el("p", { class: "small", id: "ui-proposals-check", text: `六张样板图和 ${G().COMPONENTS.length} 个组件（暗图、亮图各一次）：0 个问题。每一行字都查了是否超出位置、是否出屏、字体里有没有这个字。` }));

    page.append(
      el("p", { class: "note", style: "margin-top:20px", text: `已经选好 ${P.id} ${P.name}。还有要改的地方（颜色、圆角、某个组件），直接告诉 Claude，会写进 UI-10 的「用户选定的风格」。` }),
      el("p", { class: "small muted", text: "另外三个提案（G1 白卡片、G3 糖果按钮、G4 纸箱）只在预览图里给用户看过；用户选定 G2 以后没有做进这一页。" }));
    page.append(dialog());
  }

  function show(id) {
    if (!page) build();
    if (id) open(id); else close();
  }
  root.PBUiProposals = { show, hide: close, current: () => current };
})(window);
