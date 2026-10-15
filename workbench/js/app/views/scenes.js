/* View 1 · Scenes: whole-screen compositions (representative scene, chapter-1
 * levels, UI screens). Level playback uses the design model, not the SDK. */
(function (root) {
  "use strict";
  const PB = root.PB, store = root.PBStore, el = root.PBStage.el;
  let stage = null, current = null, step = 0, grid = false, observe = false;

  function sceneList() {
    const list = [];
    for (const t of PB.scene.THEMES) {
      const a = store.asset(t);
      if (a) list.push({ group: "代表场景（全要素 × 六主题）", id: "showcase." + t.slice(6), name: a.params.title, kind: "showcase", theme: t, asset: a });
    }
    const lobby = store.assets().find((x) => x.id === "ui.screen.lobby");
    if (lobby) for (const t of PB.scene.THEMES) {
      const a = store.asset(t);
      if (a) list.push({ group: "大厅（随主题切换）", id: "lobby." + t.slice(6), name: "大厅 · " + a.params.title, kind: "screen", asset: lobby, theme: t });
    }
    for (const lv of store.levels()) list.push({ group: "第 1 章关卡（设计模型）", id: "level." + lv.id, name: lv.id + " " + lv.title, kind: "level", level: lv });
    for (const a of store.assets().filter((x) => x.category === "screen" && x.id !== "ui.screen.lobby")) list.push({ group: "游戏界面", id: a.id, name: a.name, kind: "screen", asset: a });
    return list;
  }

  function renderList(listEl) {
    listEl.textContent = "";
    let group = null;
    for (const s of sceneList()) {
      if (s.group !== group) { group = s.group; listEl.append(el("div", { class: "group-title", text: group })); }
      const badge = s.asset ? statusBadge(s.asset.id) : null;
      listEl.append(el("button", { class: "list-btn", type: "button", "aria-current": String(current && current.id === s.id), onclick: () => { location.hash = "#scenes/" + s.id; } }, [el("span", { text: s.name }), badge]));
    }
  }
  function statusBadge(id) { const st = store.status(id); return el("span", { class: "badge " + st, text: store.statusLabel(st) }); }

  function replayState(lv, n) {
    const res = PB.tilemodel.replay(lv, lv.solution.slice(0, n));
    const last = res.steps[res.steps.length - 1];
    return { parsed: { level: res.level, state: last.state }, action: last.action, result: last.result };
  }

  function poseFor(action, result) {
    if (!action) return { pose: "idle" };
    const facing = /L$/.test(action) ? "left" : /R$/.test(action) ? "right" : undefined;
    const kind = result && result.kind;
    const pose = kind === "push" ? "push" : kind === "dig" ? "dig" : kind === "pour" ? "pour" : kind === "climb" ? "climb" : kind === "walk" || kind === "step" ? "walk" : "idle";
    return { pose, facing };
  }

  // Target highlight for the next author action (dig / pour / bomb).
  function nextTarget(lv, parsed) {
    const a = lv.solution[step];
    const m = a && /^(DIG|POUR|BOMB)_([LRD])$/.exec(a);
    if (!m) return null;
    const d = { L: [-1, 0], R: [1, 0], D: [0, 1] }[m[2]], p = parsed.state.player;
    return { kind: m[1].toLowerCase(), x: p.x + d[0], y: p.y + d[1] };
  }

  let showIssues = false;
  const LOCALES = [["zh-Hans", "简体中文"], ["en", "English"], ["qps", "伪本地化（长度测试）"]];
  function screenState(s) {
    return { focus: s.asset.params.screen === "hint" ? 2 : s.asset.params.screen === "levels" ? 4 : 0, specs: Object.fromEntries(store.levels().map((l) => [l.id, l])), levelSpec: store.level("M05"), ruleSpec: store.level("M03"), theme: s.theme, showIssues, animate: true };
  }
  function outline(r, issues) {
    if (!showIssues) return;
    for (const it of issues) { const q = it.rect; r.hline(q.x, q.y, q.w, "A"); r.hline(q.x, q.y + q.h, q.w, "A"); r.vline(q.x, q.y, q.h, "A"); r.vline(q.x + q.w, q.y, q.h + 1, "A"); }
  }

  function draw(r, tick) {
    const s = current;
    PB.i18n.takeIssues();
    if (s.kind === "showcase") { PB.scene.renderLevel(r, PB.scene.SHOWCASE, null, { tick, theme: s.theme, grid, observe, pose: "idle" }); outline(r, PB.i18n.takeIssues()); }
    else if (s.kind === "level") {
      const st = replayState(s.level, step), p = poseFor(st.action, st.result);
      const won = step === s.level.solution.length && PB.tilemodel.won(st.parsed.level, st.parsed.state);
      PB.scene.renderLevel(r, s.level, st.parsed, { tick, grid, observe, pose: won ? "win" : p.pose, facing: p.facing, target: nextTarget(s.level, st.parsed) });
      outline(r, PB.i18n.takeIssues());
    } else {
      PB.ui.render(r, s.asset, tick, screenState(s));
    }
  }

  function info(s) {
    const box = document.getElementById("scene-info");
    box.textContent = "";
    if (s.kind === "level") {
      const lv = s.level, mc = store.modelCheck(lv.id);
      box.append(el("h2", { text: `${lv.id} ${lv.title}` }), el("p", { class: "muted small", text: `${lv.role} · 教：${lv.teaches.join("、")}` }), el("p", { text: lv.discovery }));
      if (mc) box.append(el("dl", { class: "meta" }, [
        el("dt", { text: "作者解" }), el("dd", { text: `${mc.author_steps} 步 ${mc.author_ok ? "（模型中通关）" : "（模型中失败）"}` }),
        el("dt", { text: "模型最短解" }), el("dd", { text: mc.shortest + " 步" }),
        el("dt", { text: "死局状态" }), el("dd", { text: `${mc.dead_end_states} / ${mc.reachable_states}` }),
      ]));
      box.append(el("h3", { text: "三级提示" }));
      const ol = el("ol"); lv.hints.forEach((h) => ol.append(el("li", { text: h }))); box.append(ol);
      if (lv.misreads.length) { box.append(el("h3", { text: "常见误解" })); const ul = el("ul"); lv.misreads.forEach((m) => ul.append(el("li", { text: m }))); box.append(ul); }
      box.append(el("h3", { text: "SDK / 游戏层" }));
      const ul2 = el("ul"); [...(lv.sdk.sdk || []).map((x) => "【SDK】" + x), ...(lv.sdk.game_layer || []).map((x) => "【游戏层】" + x)].forEach((x) => ul2.append(el("li", { class: "small", text: x }))); box.append(ul2);
      box.append(el("h3", { text: "验收条目" })); const ul3 = el("ul"); lv.checks.forEach((c) => ul3.append(el("li", { class: "small", text: c }))); box.append(ul3);
      box.append(el("p", { class: "note small", text: "规格文件：content/levels/ch1-mine/" + lv.id + ".json" }));
    } else if (s.kind === "screen") {
      const a = s.asset;
      box.append(el("h2", { text: a.name }), el("p", { class: "small mono", text: `${a.id} @v${a.version}` }), statusBadge(a.id), el("p", { text: a.usage }), el("p", { class: "small muted", text: a.notes }));
      box.append(el("h3", { text: "用到的资产" }));
      const ul = el("ul"); for (const d of a.depends || []) ul.append(el("li", {}, [el("a", { href: "#assets/" + d, text: d }), " ", statusBadge(d)])); box.append(ul);
      box.append(el("h3", { text: "文字排版检查" }));
      const ul2 = el("ul", { class: "small" });
      for (const [loc, name] of LOCALES) {
        const st = Object.assign(screenState(s), { locale: loc, showIssues: false });
        const issues = PB.ui.render(new PB.Raster(320, 180), a, 0, st);
        ul2.append(el("li", { text: `${name}：` + (issues.length ? `${issues.length} 处放不下（${[...new Set(issues.map((i) => i.key))].slice(0, 4).join("、")}）` : "全部放得下") }));
      }
      box.append(ul2, el("p", { class: "small muted", text: "放不下的文字会被省略或截断，打开「标出溢出」可在画面上看到红框。伪本地化把英文拉长约 40%，用来提前发现以后其他语言的排版问题，只作参考。" }));
      box.append(el("p", { class: "note small", text: "界面中的数字和进度为样例数据。确认的是布局方式、配色和元素样式；文字来自 content/i18n，各语言共用同一套布局规则。" }));
    } else {
      box.append(el("h2", { text: s.name }), el("p", { text: "把第 1 章的人物、箱子、机关、材料和 HUD 放在同一画面中检查整体协调、层级和可读性。" }));
      box.append(el("p", { class: "small muted", text: "画面中的布局只作示意，不是可玩关卡。水与沙的颗粒在游戏中会随 SDK 的格子移动，这里按格子静态绘制。" }));
      box.append(el("h3", { text: "地形主题" }), el("p", {}, [el("a", { href: "#assets/" + s.theme, text: s.theme }), " ", statusBadge(s.theme)]));
    }
  }

  function steps(s) {
    const box = document.getElementById("scene-steps");
    box.textContent = "";
    if (s.kind !== "level") return;
    const n = s.level.solution.length;
    const label = el("span", { class: "mono" });
    const range = el("input", { type: "range", min: "0", max: String(n), value: String(step), "aria-label": "作者解步骤", oninput: () => { step = Number(range.value); update(); } });
    const prev = el("button", { class: "btn", type: "button", text: "上一步", onclick: () => { step = Math.max(0, step - 1); range.value = step; update(); } });
    const next = el("button", { class: "btn", type: "button", text: "下一步", onclick: () => { step = Math.min(n, step + 1); range.value = step; update(); } });
    function update() {
      const a = step ? s.level.solution[step - 1] : "开局";
      label.textContent = `第 ${step}/${n} 步 · ${a}`;
      stage.refresh();
    }
    box.append(el("div", { class: "steps" }, [prev, range, next, label]));
    box.append(el("p", { class: "disclaimer", text: "这是格子规则模型对作者解的推演，用来看布局与流程；沙、水等材料的真实表现以 SDK 运行结果为准。" }));
    update();
  }

  function show(id) {
    const list = sceneList();
    current = list.find((s) => s.id === id) || list[0];
    step = 0;
    renderList(document.getElementById("scene-list"));
    const host = document.getElementById("scene-stage");
    if (stage) stage.destroy();
    const gridBtn = el("button", { class: "btn", type: "button", "aria-pressed": String(grid), text: "网格", onclick: () => { grid = !grid; gridBtn.setAttribute("aria-pressed", String(grid)); stage.refresh(); } });
    const obsBtn = el("button", { class: "btn", type: "button", "aria-pressed": String(observe), text: "观察模式", title: "游戏中按住 Tab 时的画面", onclick: () => { observe = !observe; obsBtn.setAttribute("aria-pressed", String(observe)); stage.refresh(); } });
    const locSel = el("select", { "aria-label": "界面语言", onchange: () => { PB.i18n.setLocale(locSel.value); store.setPref("locale", locSel.value); stage.refresh(); } });
    for (const [v, n] of LOCALES) locSel.append(el("option", { value: v, text: n }));
    locSel.value = PB.i18n.getLocale();
    const issueBtn = el("button", { class: "btn", type: "button", "aria-pressed": String(showIssues), text: "标出溢出", title: "用红框标出放不下而被省略的文字", onclick: () => { showIssues = !showIssues; issueBtn.setAttribute("aria-pressed", String(showIssues)); stage.refresh(); } });
    stage = root.PBStage.create(host, {
      width: 320, height: 180, animated: true, autoplay: true, draw, label: current.name,
      extras: (current.kind === "screen" ? [] : [gridBtn, obsBtn]).concat([el("label", { class: "small muted" }, ["语言 ", locSel]), issueBtn]),
      disclaimer: current.kind === "screen" ? "界面为布局与外观参考；交互在游戏中实现。" : "视觉示意，不代表 SDK 物理结果。",
    });
    info(current); steps(current);
  }

  root.PBScenes = { show, hide: () => stage && stage.setVisible(false), wake: () => stage && stage.setVisible(true) };
})(window);
