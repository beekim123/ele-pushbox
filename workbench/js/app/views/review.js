/* View 4 · Review & approve. The page cannot write to the repository: it builds
 * an exact list of asset@version#hash that the user sends in chat (or as a file),
 * and only `node tools/art.mjs approve` turns that into an approval record. */
(function (root) {
  "use strict";
  const PB = root.PB, store = root.PBStore, el = root.PBStage.el;
  const ORDER = ["character", "monster", "avatar", "object", "mechanism", "item", "cargo", "fx", "ui", "terrain", "material", "screen"];

  function approvalText() {
    const sel = store.review().selected, fb = store.review().feedback;
    const lines = [];
    const ids = Object.keys(sel).sort();
    if (ids.length) {
      lines.push("美术确认：通过以下 " + ids.length + " 项（版本与哈希必须一致）");
      for (const id of ids) lines.push(`- ${id}@v${sel[id].version} #${sel[id].hash.slice(0, 12)}`);
    }
    const fids = Object.keys(fb).sort();
    if (fids.length) {
      if (lines.length) lines.push("");
      lines.push("美术需修改：");
      for (const id of fids) lines.push(`- ${id}@v${fb[id].version}：${fb[id].text}`);
    }
    return lines.join("\n");
  }
  function requestFile() {
    const sel = store.review().selected, fb = store.review().feedback;
    return { format: "pushbox.approval-request/1", created: new Date().toISOString(), note: "由工作台生成；由 `node tools/art.mjs approve --via workbench` 记录后才算确认。",
      approve: Object.keys(sel).sort().map((id) => ({ asset: id, version: sel[id].version, hash: sel[id].hash })),
      changes: Object.keys(fb).sort().map((id) => ({ asset: id, version: fb[id].version, request: fb[id].text })) };
  }

  function show() {
    store.pruneReview();
    const box = document.getElementById("review-root");
    box.textContent = "";
    const assets = store.assets().slice().sort((a, b) => ORDER.indexOf(a.category) - ORDER.indexOf(b.category) || a.id.localeCompare(b.id));
    const counts = { approved: 0, review: 0, draft: 0, local: 0 };
    for (const a of assets) counts[store.status(a.id)]++;
    box.append(el("h2", { text: "确认美术" }),
      el("p", { class: "muted", text: `共 ${assets.length} 项：待确认 ${counts.review}、已确认 ${counts.approved}、草稿 ${counts.draft}、本地修改 ${counts.local}。` }),
      el("p", { class: "note small", text: "勾选你实际看过并认可的具体版本，然后点「复制确认文字」发到聊天里（或下载确认文件交给 Claude）。网页本身不会写入仓库，勾选也不等于确认；只有记录进 art/approvals.json 的版本才能进入游戏。对需要修改的项，直接在「修改意见」里写下来，会一起复制。" }));

    const table = el("table", { class: "grid" });
    table.append(el("thead", {}, [el("tr", {}, ["通过", "预览", "资产", "版本", "状态", "修改意见"].map((t) => el("th", { text: t })))]));
    const tbody = el("tbody");
    for (const a of assets) {
      const st = store.status(a.id), sel = !!store.review().selected[a.id];
      const can = st === "review";
      const cb = el("input", { type: "checkbox", "aria-label": "通过 " + a.name, disabled: !can, onchange: () => { store.toggleSelected(a.id, cb.checked); summary(); } });
      cb.checked = sel;
      const fbv = (store.review().feedback[a.id] || {}).text || "";
      const fb = el("input", { class: "feedback-input", type: "text", placeholder: st === "approved" ? "" : "需要修改时填写", value: fbv, "aria-label": "修改意见 " + a.name, onchange: () => { store.setFeedback(a.id, fb.value.trim()); summary(); } });
      const why = st === "local" ? "有本地未导出的修改，先导出并重新构建" : st === "approved" ? "已确认" : st === "draft" ? "草稿，尚未提交确认" : "";
      tbody.append(el("tr", {}, [
        el("td", { title: why }, [cb]),
        el("td", {}, [root.PBAssets.thumb(store.effective(a.id), 48, 32)]),
        el("td", {}, [el("a", { href: "#assets/" + a.id, text: a.name }), el("div", { class: "mono", text: a.id })]),
        el("td", { class: "mono", text: `v${a.version} #${(a.content_hash || "").slice(0, 8)}` }),
        el("td", {}, [el("span", { class: "badge " + st, text: store.statusLabel(st) })]),
        el("td", {}, [fb]),
      ]));
    }
    table.append(tbody);
    const selectAll = el("button", { class: "btn", type: "button", text: "全选待确认项", onclick: () => { for (const a of assets) if (store.status(a.id) === "review") store.toggleSelected(a.id, true); show(); } });
    const clear = el("button", { class: "btn", type: "button", text: "清空勾选与意见", onclick: () => { store.clearReview(); show(); } });
    box.append(el("div", { class: "btn-row" }, [selectAll, clear]), table);

    const out = el("textarea", { readonly: true, "aria-label": "确认文字" });
    const copy = el("button", { class: "btn primary", type: "button", text: "复制确认文字", onclick: async () => {
      try { await navigator.clipboard.writeText(out.value); root.PBMain.toast("已复制，请粘贴到聊天里。"); }
      catch (e) { out.select(); root.PBMain.toast("浏览器不允许自动复制，已选中文字，请按 Ctrl/⌘+C。"); }
    } });
    const dl = el("button", { class: "btn", type: "button", text: "下载确认文件", onclick: () => root.PBMain.download(`pushbox-approval-request-${Date.now()}.json`, JSON.stringify(requestFile(), null, 2)) });
    const sum = el("p", { class: "small muted" });
    function summary() {
      const n = Object.keys(store.review().selected).length, m = Object.keys(store.review().feedback).length;
      out.value = approvalText() || "（尚未勾选或填写意见）";
      sum.textContent = `已勾选 ${n} 项，修改意见 ${m} 条。`;
      copy.disabled = dl.disabled = !(n || m);
      root.PBMain.updateBadges();
    }
    box.append(el("h3", { text: "发送给 Claude" }), sum, out, el("div", { class: "btn-row" }, [copy, dl]));
    summary();

    box.append(el("h3", { text: "已记录的确认" }));
    const recs = store.approvals();
    if (!recs.length) box.append(el("p", { class: "muted", text: "还没有任何确认记录。" }));
    for (const r of recs) box.append(el("details", {}, [el("summary", { text: `${r.id} · ${r.date.slice(0, 10)} · ${r.by}（${r.via === "chat" ? "聊天" : "工作台文件"}）· ${r.items.length} 项${r.scope ? " · " + r.scope : ""}` }),
      el("ul", {}, r.items.map((i) => el("li", { class: "mono", text: `${i.asset}@v${i.version} #${i.hash.slice(0, 12)} → ${i.png}` }))), r.note ? el("p", { class: "small", text: r.note }) : null]));
  }
  root.PBReview = { show };
})(window);
