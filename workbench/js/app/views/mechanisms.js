/* View · Mechanisms: the mechanism catalog with derived status, the levels
 * that demonstrate each mechanism and the art it needs. Route: #mechanisms/<id>. */
(function (root) {
  "use strict";
  const store = root.PBStore, el = root.PBStage.el, UI = root.PBContentUI;
  const STEPS = ["proposed", "designed", "specified", "verified", "playable"];
  const OWNER = { sdk: "SDK 物理", game: "游戏层规则", both: "SDK + 游戏层" };
  let selected = null;

  function renderSide() {
    const box = document.getElementById("mech-side");
    box.textContent = "";
    for (const g of store.catalog("groups").filter((x) => x.mode === "lab").sort((a, b) => a.order - b.order)) {
      const ms = store.content().mechanisms.filter((m) => m.group === g.id);
      if (!ms.length) continue;
      box.append(el("div", { class: "group-title", text: `${g.order} ${g.name}` }));
      for (const m of ms) box.append(el("button", { class: "list-btn", type: "button", "aria-current": String(m.id === selected), onclick: () => { location.hash = "#mechanisms/" + m.id; } }, [el("span", { text: m.name }), UI.mechBadge(m.status)]));
    }
  }

  function renderWork() {
    const box = document.getElementById("mech-work");
    box.textContent = "";
    const m = store.mechanism(selected);
    if (!m) { box.append(el("p", { class: "muted", text: "选择左侧的一个机制。" })); return; }
    box.append(el("h2", { text: m.name }), el("div", { class: "btn-row" }, [el("span", { class: "mono", text: "mechanic:" + m.id }), UI.mechBadge(m.status), el("span", { class: "small muted", text: OWNER[m.owner] || m.owner })]));
    const at = STEPS.indexOf(m.status);
    box.append(el("ol", { class: "pipeline", "aria-label": "进度" }, STEPS.map((s, i) => el("li", { class: i < at ? "done" : i === at ? "now" : "", text: store.mechStatusLabel(s) }))));
    box.append(el("p", { text: m.summary }));
    box.append(el("dl", { class: "meta" }, [
      el("dt", { text: "SDK 能力" }), el("dd", { text: (m.sdk || []).join("、") || "—（纯游戏层）" }),
      el("dt", { text: "地图字符" }), el("dd", { class: "mono", text: (m.chars || []).join(" ") || "—" }),
      el("dt", { text: "风险" }), el("dd", { text: m.risk || "—" }),
      el("dt", { text: "设计文档" }), el("dd", { class: "mono", text: m.doc || "—" }),
      el("dt", { text: "内容层" }), el("dd", { text: m.layer === undefined ? "—" : "第 " + m.layer + " 层" }),
      el("dt", { text: "来自" }), el("dd", { text: !m.origin ? "关卡模式" : m.origin === "delivery" ? "配送模式" : m.origin === "sdk" ? "SDK 扩展" : ((store.catalog("worlds").find((w) => w.id === m.origin) || {}).name || m.origin) }),
    ]));
    if (m.origin === "delivery") {
      // Monster mechanics have no turn-based lab level: room demos in the real-time model stand in for them.
      const demos = m.demos || [];
      box.append(el("h3", { text: "配送房间里的演示（实时模型）" }), demos.length ? el("ul", {}, demos.map((d) => { const [tid, did] = d.split("/"), t = (store.content().rooms || []).find((r) => r.id === tid), dm = t && (t.demos || []).find((x) => x.id === did), c = t && t.check && (t.check.demos || []).filter((x) => x.id === did);
        return el("li", {}, [el("a", { href: "#maps/t/" + tid, text: (t ? t.name : tid) + " · " + (dm ? dm.name : did) }), " ", UI.mark(c && c.length ? c.every((x) => x.ok) : null, "设计模型回放（含翻转）")]); })) : el("p", { class: "muted", text: "还没有演示：在房间模板里加一段 demos（docs/design/delivery-realtime.md）。" }));
      box.append(el("p", { class: "small muted", text: "这些机制只属于配送模式（关卡模式没有怪物），所以不进关卡模式的实验组，而是用房间模板里的演示输入在实时模型中回放；开发方在 Godot 里回放同样的演示并写进验证报告后才算已验证。" }));
    } else {
      const levels = store.content().levels.filter((l) => m.levels.includes(l.id));
      box.append(el("h3", { text: "关卡模式中的关卡" }), levels.length ? UI.levelTable(levels) : el("p", { class: "muted", text: "还没有关卡：按 game-design.md 6.7 在实验组加一关。" }));
    }
    const hell = store.content().levels.filter((l) => l.mode === "hell" && l.mechanisms.includes(m.id));
    if (hell.length) box.append(el("p", { class: "small muted", text: "地狱模式候选中也用到：" + hell.map((l) => `${l.id} ${l.title}`).join("、") }));
    box.append(el("h3", { text: "用到的美术" }));
    const cards = el("div", { class: "cards" });
    for (const id of m.assets || []) {
      const a = store.asset(id);
      if (!a) { cards.append(el("div", { class: "card", text: id + "（不存在）" })); continue; }
      const st = store.status(id);
      cards.append(el("a", { class: "card", href: "#assets/" + id }, [
        el("div", { class: "thumb" }, [root.PBAssets.thumb(store.effective(id), 128, 80)]),
        el("div", { class: "name", text: a.name }),
        el("div", { class: "row" }, [el("span", { class: "id", text: `${id} v${a.version}` }), el("span", { class: "badge " + st, text: store.statusLabel(st) })]),
      ]));
    }
    box.append((m.assets || []).length ? cards : el("p", { class: "muted", text: "还没有指定美术。" }));
  }

  function renderInfo() {
    const box = document.getElementById("mech-info");
    box.textContent = "";
    box.append(el("h2", { text: "状态怎么算" }), el("ol", { class: "small" }, [
      el("li", { text: "提议：还没有计划关卡。" }),
      el("li", { text: "已设计：关卡计划里有它的关卡（概念卡）。" }),
      el("li", { text: "有规格：这些关卡都有带地图的规格文件。" }),
      el("li", { text: "已验证：这些关卡都在 Godot 中用真实 SDK 验证通过（验证报告）。" }),
      el("li", { text: "可玩：再加上用到的美术全部已确认。" }),
    ]));
    box.append(el("h3", { text: "加入新机制" }), el("ol", { class: "small" }, [
      el("li", { text: "在 content/catalog/mechanisms.json 登记（组写 experimental）。" }),
      el("li", { text: "如需修改 SDK，按 SDK 仓库的流程发布。" }),
      el("li", { text: "在 groups.json 的实验组计划一关，写规格到 content/levels/lab/experimental/。" }),
      el("li", { text: "Godot headless 验证，结果写进验证报告。" }),
      el("li", { text: "缺的美术先用占位，再制作、确认。" }),
    ]), el("p", { class: "small muted", text: "详见 docs/design/game-design.md 6.7。机制只有到「可玩」才可以用于配送模式和地狱模式。" }));
  }

  function show(id) {
    const list = store.content().mechanisms;
    selected = id && store.mechanism(id) ? id : selected || (list[0] && list[0].id);
    renderSide(); renderWork(); renderInfo();
  }
  root.PBMechanisms = { show };
})(window);
