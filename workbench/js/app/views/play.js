/* Live playback of the delivery real-time model (realtime.js) inside the map
 * preview: a room demo played from its script, one room played with the
 * keyboard, or a whole generated map from the gate to the recipient. Design
 * model only: no SDK, placeholder art where the slice art is not approved. */
(function (root) {
  "use strict";
  const PB = root.PB, store = root.PBStore, el = root.PBStage.el;
  const KEY = { ArrowLeft: "L", ArrowRight: "R", ArrowUp: "U", ArrowDown: "D", a: "L", d: "R", w: "U", s: "D", A: "L", D: "R", W: "U", S: "D" };
  const LABEL = { dig: "挖", pour: "倒沙", "push-monster": "推怪", spot: "被怪物发现", steal: "被偷了", hurt: "受伤", trap: "怪物掉进坑里，被困住", escape: "怪物爬出了坑",
    ko: "放倒怪物", pickup: "拾取", cargo: "货物受损", talk: "和龟掌柜说话", buy: "买", "door-open": "门开了", "door-close": "门关了", room: "进入下一间", exit: "离开房间",
    deliver: "送到了！", fail: "失败", reset: "重来这个房间", use: "用了道具" };
  const KO = { crushed: "压倒", buried: "埋住", fall: "摔晕" };
  const WHY = { fall: "摔", hurt: "受伤", melt: "化了" };
  let cur = null;

  function catalogs() { return { monsters: store.catalog("monsters"), cargo: store.catalog("cargo"), recipients: store.catalog("recipients"), items: store.catalog("items") }; }
  const nameOf = (kind, id) => { const e = store.catalog(kind).find((x) => x.id === id); return e ? e.name : id; };
  function describe(e) {
    let s = LABEL[e.type] || e.type;
    if (e.type === "ko") s += "（" + (KO[e.how] || e.how) + "）";
    if (e.type === "pickup") s = e.kind === "coin" ? `金币 +${e.value}` : `沙袋 +${e.value}`;
    if (e.type === "cargo") s += `（${WHY[e.why] || e.why}，剩 ${e.left}）`;
    if (e.type === "steal") s += e.what === "sand" ? "一袋沙" : e.what === "coins" ? "金币" : "（没东西可偷）";
    if (e.type === "talk" && e.heal) s += `，回 ${e.heal} 颗心`;
    if (e.type === "buy") s += " " + nameOf("items", e.item) + `（${e.price}）`;
    if (e.type === "use") s += " " + nameOf("items", e.item);
    if (e.type === "hurt") s += `（还剩 ${e.hearts} 颗心）`;
    return (e.t / 60).toFixed(1) + " 秒  " + s;
  }
  const NOISE = new Set(["walk", "step", "climb", "push", "land", "sand-land", "interact"]);

  // opts: {kind: "demo" | "room" | "map", slice, world, template, demo, mirror, placement, from, map, templates, cargo, recipient, parSecs, info (element)}
  function start(host, opts) {
    stop();
    const o = opts, sl = o.slice;
    const session = { o, speed: 1, paused: false, lastTick: 0, log: [], keys: { held: [], press: null }, shop: false, result: null };
    if (o.kind === "demo") {
      const recipient = o.demo.recipient || (o.template.type === "home" ? sl.recipients[0] : null);
      const ctx = PB.rt.context(catalogs(), sl, o.demo.cargo || sl.cargo[0], recipient);
      const open = {}; for (const [e, s] of Object.entries(o.demo.open || {})) open[o.mirror ? PB.rooms.MIRROR_EDGE[e] : e] = s;
      const from = o.demo.from === "gate" ? "gate" : (o.mirror ? PB.rooms.MIRROR_EDGE[o.demo.from.split(".")[0]] : o.demo.from.split(".")[0]) + "." + o.demo.from.split(".")[1];
      const rr = PB.rt.roomRun(ctx, o.template, { mirror: !!o.mirror, open }, from, o.demo.run || undefined);
      session.run = rr.run;
      session.player = PB.rt.scriptPlayer(rr.run, o.mirror ? PB.rt.mirrorTokens(o.demo.script) : o.demo.script);
    } else if (o.kind === "room") {
      const ctx = PB.rt.context(catalogs(), sl, o.cargo, o.template.type === "home" ? o.recipient : null);
      session.run = PB.rt.roomRun(ctx, o.template, o.placement, o.from).run;
    } else {
      const ctx = PB.rt.context(catalogs(), sl, o.cargo, o.recipient);
      session.run = PB.rt.startRun(ctx, o.map, new Map(o.templates.map((t) => [t.id, t])));
    }
    session.parTicks = Math.round((o.parSecs || 0) * session.run.P.hz);
    cur = session;
    if (o.kind !== "demo") { window.addEventListener("keydown", onKey, true); window.addEventListener("keyup", onKeyUp, true); }
    const speedSel = el("select", { "aria-label": "播放速度", onchange: () => { session.speed = Number(speedSel.value); } }, [1, 2, 4].map((v) => el("option", { value: String(v), text: "×" + v })));
    const restart = el("button", { class: "btn", type: "button", text: "从头再来", onclick: () => start(host, o) });
    const reset = o.kind !== "demo" ? el("button", { class: "btn", type: "button", text: "重来这个房间（R）", onclick: () => { PB.rt.resetRoom(session.run); session.shop = false; } }) : null;
    session.stage = root.PBStage.create(host, {
      width: 320, height: 180, animated: true, autoplay: true, label: "实时模型", maxHeight: 460,
      extras: [el("label", { class: "small muted" }, ["速度 ", speedSel]), restart, reset].filter(Boolean),
      draw: (r, tick) => draw(session, r, tick),
      disclaimer: (o.kind === "demo" ? "实时设计模型回放演示输入（不是 SDK）。占位：R 鼠群、S 骷髅守卫（底下的色条：红 = 巡逻、亮红 = 追、紫 = 逃、灰 = 被推晕、黄 = 被困）、G 渡门、K 龟掌柜、D 收件人、$ 金币。" :
        "键盘：方向键或 WASD 走 / 爬，Shift + 方向挖，Ctrl + 方向倒沙，↑ 和龟掌柜说话，1–3 用道具，R 重来这个房间。实时设计模型，不是 SDK；占位同上。") + (o.note || ""),
    });
    session.stage.frame.focus();
    renderInfo(session, true);
    return session;
  }
  function stop() {
    if (!cur) return;
    window.removeEventListener("keydown", onKey, true); window.removeEventListener("keyup", onKeyUp, true);
    if (cur.stage) cur.stage.destroy();
    cur = null;
  }

  function onKey(e) {
    const s = cur; if (!s || s.o.kind === "demo") return;
    const t = e.target; if (t && (t.tagName === "INPUT" || t.tagName === "SELECT" || t.tagName === "TEXTAREA")) return;
    const dir = KEY[e.key];
    let act = null;
    if (dir) {
      if (e.shiftKey && dir !== "U") act = "DIG_" + dir;
      else if ((e.ctrlKey || e.altKey) && (dir === "L" || dir === "R")) act = "POUR_" + dir;
      else { act = dir; s.keys.held = s.keys.held.filter((x) => x !== dir).concat([dir]); }
    } else if (/^[1-3]$/.test(e.key)) act = "USE_" + e.key;
    else if (e.key === "r" || e.key === "R") { PB.rt.resetRoom(s.run); s.shop = false; }
    else if (e.key === "Escape" && s.shop) s.shop = false;
    else return;
    e.preventDefault(); e.stopPropagation();
    if (act && !e.repeat) s.keys.press = act;
  }
  function onKeyUp(e) { const s = cur; if (!s) return; const dir = KEY[e.key]; if (dir) s.keys.held = s.keys.held.filter((x) => x !== dir); }

  function draw(s, r, tick) {
    let n = Math.min(6, tick - s.lastTick) * s.speed;
    s.lastTick = tick;
    const run = s.run;
    while (n-- > 0 && !run.done && !s.shop) {
      if (s.player) { if (s.player.finished()) break; s.log.push(...s.player.tick()); }
      else {
        if (run.leaving && !run.map) break;
        const press = s.keys.press; s.keys.press = null;
        const ev = PB.rt.stepRun(run, { held: s.keys.held[s.keys.held.length - 1] || null, press });
        s.log.push(...ev);
        if (ev.some((e) => e.type === "talk")) s.shop = true;
      }
    }
    if (run.done && !s.result) s.result = PB.rt.settlement(run, s.parTicks);
    PB.droom.renderLive(r, run, { world: s.o.world, tick });
    if (s.shop) banner(r, "龟掌柜的货架（右栏）", "l");
    else if (run.done) banner(r, run.done.ok ? "送到了！" : "这一单没送成", run.done.ok ? "l" : "D");
    else if (run.leaving && !run.map) banner(r, "离开了这个房间", "u");
    else if (s.player && s.player.finished()) banner(r, "演示结束", "u");
    if (tick % 6 === 0 || run.done) renderInfo(s, false);
  }
  function banner(r, text, color) {
    const w = PB.text.measure(text) + 16, x = (320 - w) >> 1;
    PB.sprites.ninepatch(r, "ui.panel", 2, x, 26, w, 16);
    PB.text.draw(r, text, x + 8, 27, color, "z");
  }

  // Right column: live numbers, the shop shelf, recent events and the settlement.
  function renderInfo(s, full) {
    const box = s.o.info; if (!box) return;
    if (full || !s.liveBox) {
      box.textContent = "";
      const o = s.o, ctx = s.run.ctx;
      box.append(el("h2", { text: o.kind === "demo" ? "演示：" + o.demo.name + (o.mirror ? "（翻转）" : "") : o.kind === "room" ? "试玩这一间" : "试玩整张图" }));
      box.append(el("p", { class: "small", text: `货物：${ctx.cargo ? ctx.cargo.name : "—"}${ctx.recipient ? " · 收件人：" + ctx.recipient.name : ""}` }));
      if (o.kind === "demo") box.append(el("p", { class: "small mono", text: (o.mirror ? PB.rt.mirrorTokens(o.demo.script) : o.demo.script).join("  ") }));
      s.liveBox = el("div", { class: "live" }); s.shopBox = el("div"); s.logBox = el("ol", { class: "small live-log" }); s.resultBox = el("div");
      box.append(s.liveBox, s.shopBox, el("h3", { text: "发生了什么" }), s.logBox, s.resultBox);
    }
    const run = s.run, secs = (run.clock / run.P.hz).toFixed(1);
    s.liveBox.textContent = `时间 ${secs} 秒 · 心 ${run.hearts}/${run.maxHearts} · 金币 ${run.coins} · 沙袋 ${run.sand} · 完好度 ${PB.rt.integrity(run)}/${run.P.integrity} · 道具 ${run.items.map((i) => nameOf("items", i)).join("、") || "无"}`;
    s.shopBox.textContent = "";
    if (s.shop) {
      const k = run.room.keeper, sl = s.o.slice;
      s.shopBox.append(el("h3", { text: "龟掌柜的货架" }));
      for (const id of sl.station.items) {
        const it = store.catalog("items").find((x) => x.id === id), left = k.stock[id] || 0;
        s.shopBox.append(el("p", {}, [el("button", { class: "btn", type: "button", text: `买 ${it.name}（${it.price} 金币，剩 ${left}）`, onclick: () => { const res = PB.rt.buy(run, id); if (!res.ok) root.PBMain.toast({ coins: "金币不够", stock: "卖完了", slots: "背包满了", full: "沙袋满了", closed: "先和龟掌柜说话" }[res.why] || res.why); renderInfo(s, false); } })]));
      }
      s.shopBox.append(el("button", { class: "btn", type: "button", text: "离开货架（Esc）", onclick: () => { s.shop = false; } }));
    }
    const shown = s.log.filter((e) => !NOISE.has(e.type)).slice(-10);
    if (s.logBox.childElementCount !== shown.length || full || run.done) { s.logBox.textContent = ""; for (const e of shown) s.logBox.append(el("li", { text: describe(e) })); }
    if (s.result && !s.resultBox.childElementCount) {
      const q = s.result;
      s.resultBox.append(el("h3", { text: q.ok ? `送到了 · 评级 ${q.rating}` : "没送成" }));
      if (q.ok) s.resultBox.append(el("p", { class: "small", text: `小费 = 基础 ${q.pay} × 完好度 ${q.integrity}/${q.max} × 用时 ${q.timePct}% × 喜欢 ${q.likePct}% = ${q.tip}（参考时间 ${(q.par / 60).toFixed(1)} 秒，用了 ${(q.ticks / 60).toFixed(1)} 秒）` }));
      s.resultBox.append(el("p", { class: "small", text: q.ok ? `路上拾到 ${q.picked} + 小费 ${q.tip} = ${q.total} 金币` : `原因：${q.reason === "hearts" ? "心掉光了" : "货物没了"}；拾到的 ${q.picked} 金币带回一半 = ${q.total}` }));
    }
  }

  root.PBPlay = { start, stop, active: () => cur };
})(window);
