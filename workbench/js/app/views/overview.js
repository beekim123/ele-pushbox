/* View · Overview: where every mode, mechanism group, art asset and check
 * stands, computed from data/content.js and data/bundle.js. */
(function (root) {
  "use strict";
  const store = root.PBStore, el = root.PBStage.el, UI = root.PBContentUI;

  function section(title, children) { return el("section", { class: "ov-section" }, [el("h3", { text: title })].concat(children)); }

  function show() {
    const box = document.getElementById("overview-root");
    box.textContent = "";
    const C = store.content();
    box.append(el("h2", { text: "总览" }),
      el("p", { class: "muted", text: "游戏分三个模式；任何机制先在关卡模式中做成关卡并验证，才能用于另外两个模式。本页的状态全部由仓库数据算出：目录 content/catalog、关卡规格 content/levels、美术 art/、游戏验证报告 game/reports/verification.json。" }));
    if (!store.hasContent()) { box.append(el("p", { class: "note", text: "没有找到 data/content.js。请在仓库根目录运行 node tools/art.mjs build。" })); return; }

    // Modes.
    const cards = el("div", { class: "mode-cards" });
    for (const m of store.catalog("modes").slice().sort((a, b) => a.order - b.order)) {
      const levels = C.levels.filter((l) => l.mode === m.id);
      let stat = "";
      if (m.id === "lab") {
        const n = UI.counts(levels), st = {};
        for (const x of C.mechanisms) st[x.status] = (st[x.status] || 0) + 1;
        stat = `${store.catalog("groups").filter((g) => g.mode === "lab").length} 组，计划 ${n.total} 关（有规格 ${n.spec}、SDK 验证 ${n.sdk}）；机制 ${C.mechanisms.length} 个：` + ["playable", "verified", "specified", "designed", "proposed"].filter((k) => st[k]).map((k) => `${store.mechStatusLabel(k)} ${st[k]}`).join("、");
      } else if (m.id === "hell") stat = `候选关卡 ${levels.length} 个（来自原组合关）`;
      else stat = `可玩切片 ${store.catalog("slices").length} 个（${store.catalog("slices").map((x) => x.name).join("、")}）；设计数据：地区 ${store.catalog("worlds").length}、收件人 ${store.catalog("recipients").length}、货物 ${store.catalog("cargo").length}、缘分组合 ${store.catalog("combos").length}、怪物 ${store.catalog("monsters").length}、道具 ${store.catalog("items").filter((i) => i.mode === "delivery").length}、增益 ${store.catalog("buffs").length}、徽章 ${store.catalog("badges").length}、事件 ${store.catalog("events").length}`;
      cards.append(el("a", { class: "mode-card", href: m.id === "delivery" ? "#catalog/slices" : "#modes/" + (m.id === "lab" ? "basics" : "hell-pool") }, [
        el("div", { class: "row" }, [el("strong", { text: m.name }), UI.modeBadge(m)]),
        el("p", { class: "small", text: m.summary }),
        el("p", { class: "small muted", text: stat }),
        el("p", { class: "mono small muted", text: m.doc }),
      ]));
    }
    box.append(section("模式", [cards]));

    // Level-mode groups.
    const t = el("table", { class: "grid" });
    t.append(el("thead", {}, [el("tr", {}, ["组", "主题", "计划关卡", "有规格", "设计模型通过", "SDK 验证", "美术已确认"].map((x) => el("th", { text: x })))]));
    const tb = el("tbody");
    for (const g of store.catalog("groups").filter((x) => x.mode === "lab").sort((a, b) => a.order - b.order)) {
      const n = UI.counts(C.levels.filter((l) => l.group === g.id));
      const theme = store.asset(g.theme);
      tb.append(el("tr", {}, [
        el("td", {}, [el("a", { href: "#modes/" + g.id, text: `${g.order} ${g.name}` }), g.hidden ? el("span", { class: "small muted", text: "（默认隐藏）" }) : null]),
        el("td", {}, [el("a", { href: "#assets/" + g.theme, text: theme ? theme.params.title : g.theme })]),
        el("td", { text: String(n.total) }), el("td", { text: `${n.spec}/${n.total}` }), el("td", { text: g.id === "basics" ? `${n.model}/${n.total}` : "—" }),
        el("td", { text: `${n.sdk}/${n.total}` }), el("td", { text: `${n.art}/${n.total}` }),
      ]));
    }
    t.append(tb);
    box.append(section("关卡模式进度", [t, el("p", { class: "small muted", text: "设计模型只覆盖第 1 组的材料；第 2 组起的流体、爆炸、反应和冷热只能在真实 SDK 中验证。" })]));

    // Art.
    const ac = { approved: 0, review: 0, draft: 0, local: 0 };
    for (const a of store.assets()) ac[store.status(a.id)]++;
    box.append(section("美术", [el("p", {}, [`共 ${store.assets().length} 项：已确认 ${ac.approved}、待确认 ${ac.review}、草稿 ${ac.draft}、本地修改 ${ac.local}。 `, el("a", { href: "#review", text: "去确认页" })])]));

    // Godot verification report.
    const R = C.summary.report;
    box.append(section("游戏验证报告", [R
      ? el("dl", { class: "meta" }, [el("dt", { text: "生成时间" }), el("dd", { text: R.generated || "—" }), el("dt", { text: "游戏提交" }), el("dd", { class: "mono", text: R.commit || "—" }), el("dt", { text: "SDK" }), el("dd", { text: R.sdk || "—" }), el("dt", { text: "关卡结果" }), el("dd", { text: R.levels + " 关" }), el("dt", { text: "SDK 样板" }), el("dd", { text: R.samples.map((x) => `${x.id} ${x.ok ? "✓" : "✗"}`).join("、") || "—" })])
      : el("p", { class: "muted", text: "尚无报告。开发方开工后，Godot headless 测试每次运行都写 game/reports/verification.json，工作台据此显示每关、每个机制是否在真实 SDK 中验证通过（格式见 docs/design/workbench.md 第 4 节）。" })]));

    // Checks.
    const list = el("ul", { class: "issues" });
    for (const i of C.issues) list.append(el("li", { class: "issue " + i.level }, [el("span", { class: "badge " + (i.level === "error" ? "no" : "review"), text: i.level === "error" ? "错误" : "警告" }), " ", el("span", { class: "mono", text: i.where }), "：", i.msg]));
    box.append(section("内容检查", [C.issues.length ? list : el("p", { class: "muted", text: "没有错误或警告（node tools/content.mjs check）。" })]));

    box.append(section("现在", [el("ul", {}, [
      el("li", { text: "全部美术已确认（APR-0001–APR-0005）。Godot 重构已交给 GPT：阶段一 = 工程骨架 + 第 1 组 + 全套菜单，阶段二 = 第 2 组「水与机关」。" }),
      el("li", { text: "GPT 每次运行测试都会写 game/reports/verification.json，这里和「模式与关卡」页会显示每关的 SDK 验证状态。" }),
      el("li", { text: "配送模式：第一个可玩切片（幽暗石牢）正在设计，按 ① 定范围 → ② 房间模板与地图生成 → ③ 实时规则模型 → ④ 美术候选 推进（docs/design/delivery-slice.md）。" }),
    ])]));
  }

  root.PBOverview = { show };
})(window);
