/* Shared pieces for the content views (overview, modes & levels, mechanisms,
 * design data): status badges, check marks and the level table. All statuses
 * come from data/content.js; nothing here decides a status by itself. */
(function (root) {
  "use strict";
  const store = root.PBStore, el = root.PBStage.el;

  function mechBadge(status) { return el("span", { class: "badge st-" + status, text: store.mechStatusLabel(status) }); }
  function modeBadge(m) { return el("span", { class: "badge " + (m.status === "active" ? "st-active" : "st-design"), text: m.status === "active" ? "现在做" : "设计稿" }); }
  // Three-state mark: true = passed, false = failed, null = not available yet.
  function mark(state, title) {
    const t = state === true ? "✓" : state === false ? "✗" : "—";
    return el("span", { class: "mark " + (state === true ? "yes" : state === false ? "no" : "na"), title, text: t });
  }
  function mechChip(id) {
    const m = store.mechanism(id);
    return el("a", { class: "chip-link" + (m ? " st-" + m.status : ""), href: "#mechanisms/" + id, title: m ? `${m.name}：${store.mechStatusLabel(m.status)}` : "未知机制", text: m ? m.name : id });
  }
  function assetLink(id) {
    const a = store.asset(id);
    return el("span", { class: "asset-link" }, [el("a", { href: "#assets/" + id, text: a ? a.name : id }), " ", a ? el("span", { class: "badge " + store.status(id), text: store.statusLabel(store.status(id)) }) : el("span", { class: "badge no", text: "不存在" })]);
  }

  function levelMarks(l) {
    const spec = l.has_spec ? true : null;
    const model = l.model ? l.model.ok : null;
    const sdk = l.verified ? l.verified.ok : null;
    const art = l.art.missing.length === 0;
    return [
      mark(spec, l.has_spec ? "规格：" + l.spec : "还没有关卡规格（概念卡）"),
      mark(model, l.model ? `设计模型：作者解 ${l.model.author_steps} 步，最短 ${l.model.shortest} 步` : "设计模型只覆盖第 1 组的材料"),
      mark(sdk, l.verified ? (l.verified.ok ? `Godot 验证通过（${l.verified.replays} 次回放，最多 ${l.verified.max_ticks} tick）` : "Godot 验证未通过：" + l.verified.failed.join("；")) : "尚无 Godot 验证结果"),
      mark(art, art ? "用到的美术全部已确认" : "未确认：" + l.art.missing.join("、")),
    ];
  }

  // Table of planned levels with their four status marks.
  function levelTable(levels, opts) {
    const o = opts || {};
    const table = el("table", { class: "grid levels" });
    table.append(el("thead", {}, [el("tr", {}, ["编号", "名称", "机制", "规格", "设计模型", "SDK 验证", "美术", ""].map((t) => el("th", { text: t })))]));
    const tb = el("tbody");
    for (const l of levels) {
      const [a, b, c, d] = levelMarks(l);
      const open = l.has_spec ? el("a", { class: "btn small", href: "#scenes/level." + l.id, text: "预览" }) : null;
      tb.append(el("tr", { "aria-current": String(o.current === l.id) }, [
        el("td", { class: "mono" }, [el("a", { href: `#modes/${l.group}/${l.id}`, text: l.id })]),
        el("td", { text: l.title }),
        el("td", {}, l.mechanisms.map(mechChip)),
        el("td", {}, [a]), el("td", {}, [b]), el("td", {}, [c]), el("td", {}, [d]),
        el("td", {}, [open]),
      ]));
    }
    table.append(tb);
    return table;
  }

  function counts(levels) {
    return {
      total: levels.length,
      spec: levels.filter((l) => l.has_spec).length,
      model: levels.filter((l) => l.model && l.model.ok).length,
      sdk: levels.filter((l) => l.verified && l.verified.ok).length,
      art: levels.filter((l) => !l.art.missing.length).length,
    };
  }

  root.PBContentUI = { mechBadge, modeBadge, mark, mechChip, assetLink, levelTable, levelMarks, counts };
})(window);
