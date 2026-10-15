/* View · Design data: generic tables for the catalogs that are not shown
 * elsewhere (items, cargo, monsters, buffs, modes). Route: #catalog/<kind>. */
(function (root) {
  "use strict";
  const store = root.PBStore, el = root.PBStage.el, UI = root.PBContentUI;
  const KINDS = [["cargo", "货物"], ["monsters", "怪物"], ["buffs", "增益"], ["items", "物品"], ["modes", "模式"]];
  const LABEL = { name: "名称", summary: "说明", rule: "规则", counter: "怎么应对", behavior: "行为", effect: "效果", mechanisms: "机制", assets: "美术", difficulty: "难度", mode: "模式", status: "状态", doc: "文档", order: "顺序" };
  const STATUS = { concept: "设计稿", active: "在用", design: "设计稿" };
  let kind = "cargo";

  function cell(key, v) {
    if (key === "mechanisms") return el("td", {}, (v || []).map(UI.mechChip));
    if (key === "assets") return el("td", {}, (v || []).map(UI.assetLink));
    if (key === "status") return el("td", {}, [el("span", { class: "badge " + (v === "active" ? "st-active" : "st-design"), text: STATUS[v] || v })]);
    if (key === "mode") { const m = store.mode(v); return el("td", { text: m ? m.name : v }); }
    return el("td", { class: key === "doc" ? "mono small" : "", text: Array.isArray(v) ? v.join("、") : v == null ? "" : String(v) });
  }

  function show(id) {
    if (id && KINDS.some(([k]) => k === id)) kind = id;
    const side = document.getElementById("catalog-side"), work = document.getElementById("catalog-work");
    side.textContent = ""; work.textContent = "";
    side.append(el("div", { class: "group-title", text: "目录" }));
    for (const [k, name] of KINDS) side.append(el("button", { class: "list-btn", type: "button", "aria-current": String(k === kind), onclick: () => { location.hash = "#catalog/" + k; } }, [el("span", { text: name }), el("span", { class: "small muted", text: String(store.catalog(k).length) })]));
    side.append(el("p", { class: "small muted", text: "机制和关卡计划见「机制」「模式与关卡」页。" }));
    const entries = store.catalog(kind), name = KINDS.find(([k]) => k === kind)[1];
    work.append(el("h2", { text: name }), el("p", { class: "small muted", text: store.catalogNote(kind) }), el("p", { class: "mono small muted", text: `content/catalog/${kind}.json` }));
    const keys = [];
    for (const e of entries) for (const k of Object.keys(e)) if (k !== "id" && !keys.includes(k)) keys.push(k);
    const table = el("table", { class: "grid" });
    table.append(el("thead", {}, [el("tr", {}, [el("th", { text: "编号" })].concat(keys.map((k) => el("th", { text: LABEL[k] || k }))))]));
    const tb = el("tbody");
    for (const e of entries) tb.append(el("tr", {}, [el("td", { class: "mono", text: e.id })].concat(keys.map((k) => cell(k, e[k])))));
    table.append(tb);
    work.append(entries.length ? table : el("p", { class: "muted", text: "空。" }));
  }
  root.PBCatalog = { show };
})(window);
