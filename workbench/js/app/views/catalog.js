/* View · Design data: generic tables for the design catalogs (worlds,
 * recipients, cargo, combos, monsters, items, buffs, upgrades, badges, events,
 * modes). Route: #catalog/<kind>. */
(function (root) {
  "use strict";
  const store = root.PBStore, el = root.PBStage.el, UI = root.PBContentUI;
  const KINDS = [["worlds", "地区"], ["recipients", "收件人"], ["cargo", "货物"], ["combos", "缘分组合"], ["monsters", "怪物"], ["items", "道具"], ["buffs", "增益"], ["upgrades", "属性升级"], ["badges", "徽章"], ["events", "随机事件"], ["modes", "模式"]];
  const LABEL = { name: "名称", summary: "说明", rule: "规则", counter: "怎么应对", behavior: "行为", effect: "效果", mechanisms: "机制", assets: "美术", difficulty: "难度", mode: "模式", status: "状态", doc: "文档", order: "顺序",
    style: "风格", theme: "主题资产", layer: "层", worlds: "地区", world: "地区", rarity: "稀有度", temper: "脾气", likes: "喜欢", carry: "拿法", cargo: "货物", recipient: "收件人", reward: "奖励",
    pushable: "能推", price: "价格", base: "初始", step: "每级", max_level: "级数", max: "最高", price_growth: "涨价", gate: "前置", cost: "点数", source: "来源", setup: "场景", choices: "选择" };
  const STATUS = { concept: "设计稿", active: "在用", design: "设计稿" };
  const RARITY = { common: "常见", rare: "稀有", legendary: "传说" };
  const CARRY = { small: "小件", medium: "手拿", bulky: "大件", living: "活物" };
  const nameOf = (kind, id) => { const e = store.catalog(kind).find((x) => x.id === id); return e ? e.name : id; };
  let kind = "worlds";

  function cell(key, v) {
    if (key === "mechanisms") return el("td", {}, (v || []).map(UI.mechChip));
    if (key === "assets") return el("td", {}, (v || []).map(UI.assetLink));
    if (key === "status") return el("td", {}, [el("span", { class: "badge " + (v === "active" ? "st-active" : "st-design"), text: STATUS[v] || v })]);
    if (key === "mode") { const m = store.mode(v); return el("td", { text: m ? m.name : v }); }
    if (key === "worlds" || key === "world") return el("td", { text: [].concat(v || []).map((w) => nameOf("worlds", w)).join("、") });
    if (key === "likes" || key === "cargo") return el("td", { text: [].concat(v || []).map((c) => nameOf("cargo", c)).join("、") });
    if (key === "recipient") return el("td", { text: nameOf("recipients", v) });
    if (key === "theme") return el("td", {}, v ? [UI.assetLink(v)] : ["—"]);
    if (key === "rarity") return el("td", { text: RARITY[v] || v });
    if (key === "carry") return el("td", { text: CARRY[v] || v });
    if (key === "pushable") return el("td", { text: v ? "能" : "不能" });
    if (key === "layer") return el("td", { class: "mono", text: v === 0 ? "0" : v ? "第 " + v + " 层" : "" });
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
