/* View · Modes & levels: mode → group → planned levels, each with its spec,
 * design-model, SDK-verification and art status. Route: #modes/<group>[/<level>]. */
(function (root) {
  "use strict";
  const store = root.PBStore, el = root.PBStage.el, UI = root.PBContentUI;
  let group = "basics", level = null;

  function renderSide() {
    const box = document.getElementById("modes-side");
    box.textContent = "";
    for (const m of store.catalog("modes").slice().sort((a, b) => a.order - b.order)) {
      box.append(el("div", { class: "group-title" }, [m.name, " ", UI.modeBadge(m)]));
      const gs = store.catalog("groups").filter((g) => g.mode === m.id).sort((a, b) => a.order - b.order);
      for (const g of gs) {
        const n = UI.counts(store.content().levels.filter((l) => l.group === g.id));
        box.append(el("button", { class: "list-btn", type: "button", "aria-current": String(g.id === group), onclick: () => { location.hash = "#modes/" + g.id; } }, [
          el("span", { text: (m.id === "lab" ? g.order + " " : "") + g.name }), el("span", { class: "small muted", text: n.total ? `${n.spec}/${n.total}` : "0" })]));
      }
      if (!gs.length) box.append(el("a", { class: "list-btn", href: "#catalog/worlds" }, [el("span", { text: "设计数据（地区、收件人、货物、怪物……）" })]));
    }
  }

  function renderWork() {
    const box = document.getElementById("modes-work");
    box.textContent = "";
    const g = store.group(group);
    if (!g) { box.append(el("p", { class: "muted", text: "没有这个组。" })); return; }
    const m = store.mode(g.mode), levels = store.content().levels.filter((l) => l.group === g.id);
    box.append(el("h2", { text: `${m.name} · ${g.name}` }));
    if (g.mode === "hell") box.append(el("p", { class: "note info-note small", text: "地狱模式的候选池：原第 2–5 章的组合关。地狱模式开工时重新设计成高难谜题（docs/design/mode-hell.md）。" }));
    if (g.hidden) box.append(el("p", { class: "note info-note small", text: "实验组：以后新增的 SDK 机制先在这里各做一关（docs/design/game-design.md 6.7）。默认只在「开放全部关卡」或开发构建中出现。" }));
    if (levels.length) box.append(UI.levelTable(levels, { current: level }));
    else box.append(el("p", { class: "muted", text: "这个组还没有计划中的关卡。" }));
    box.append(el("p", { class: "small muted", text: "四列状态：规格（content/levels 中有带地图的规格）、设计模型（作者解在格子模型中通关且等于最短解）、SDK 验证（Godot 验证报告）、美术（本关机制与主题用到的资产全部已确认）。悬停可看详情。" }));
  }

  function renderInfo() {
    const box = document.getElementById("modes-info");
    box.textContent = "";
    const g = store.group(group);
    if (!g) return;
    const l = level && store.planned(level);
    if (l) {
      box.append(el("h2", { text: `${l.id} ${l.title}` }), el("p", { class: "small muted", text: `${l.role} · 第 ${l.order} 关` }), el("p", { text: l.discovery }));
      box.append(el("h3", { text: "机制" }), el("div", { class: "chips" }, l.mechanisms.map(UI.mechChip)));
      const [a, b, c, d] = UI.levelMarks(l);
      box.append(el("h3", { text: "状态" }), el("dl", { class: "meta" }, [
        el("dt", { text: "规格" }), el("dd", {}, [a, " ", l.spec ? el("span", { class: "mono", text: l.spec }) : "还没有，待按概念卡细化（game-design.md 6.4–6.6）"]),
        el("dt", { text: "设计模型" }), el("dd", {}, [b, " ", l.model ? `作者解 ${l.model.author_steps} 步 / 最短 ${l.model.shortest} 步` : "不适用或未运行"]),
        el("dt", { text: "SDK 验证" }), el("dd", {}, [c, " ", l.verified ? (l.verified.ok ? `通过（回放 ${l.verified.replays} 次）` : "未通过") : "尚无报告"]),
        el("dt", { text: "美术" }), el("dd", {}, [d, " ", l.art.missing.length ? "未确认：" + l.art.missing.join("、") : "全部已确认"]),
      ]));
      box.append(el("h3", { text: "用到的美术" }), el("ul", { class: "small" }, l.art.assets.map((id) => el("li", {}, [UI.assetLink(id)]))));
      if (l.has_spec) box.append(el("p", {}, [el("a", { class: "btn", href: "#scenes/level." + l.id, text: "打开场景预览" })]));
      return;
    }
    const m = store.mode(g.mode), theme = store.asset(g.theme);
    box.append(el("h2", { text: g.name }), el("dl", { class: "meta" }, [
      el("dt", { text: "模式" }), el("dd", { text: m.name }),
      el("dt", { text: "主题" }), el("dd", {}, [UI.assetLink(g.theme)]),
      el("dt", { text: "SDK profile" }), el("dd", { text: (g.sdk_profile || []).join("、") || "—" }),
      el("dt", { text: "规格目录" }), el("dd", { class: "mono", text: `content/levels/${g.mode}/${g.id}/` }),
    ]));
    if (theme) box.append(el("p", { class: "small muted", text: theme.notes || "" }));
    const ms = store.content().mechanisms.filter((x) => x.group === g.id);
    if (ms.length) { box.append(el("h3", { text: "本组的机制" })); const ul = el("ul", { class: "small" }); for (const x of ms) ul.append(el("li", {}, [UI.mechChip(x.id), " ", UI.mechBadge(x.status)])); box.append(ul); }
    box.append(el("p", { class: "note small", text: "关卡计划以 content/catalog/groups.json 为准；规格写好后，规格里的 mode、group、mechanisms 必须与计划一致，否则 node tools/content.mjs check 报错。" }));
  }

  function show(id) {
    const [g, l] = (id || "").split("/");
    if (g && store.group(g)) group = g;
    level = l || null;
    renderSide(); renderWork(); renderInfo();
  }
  root.PBModes = { show };
})(window);
