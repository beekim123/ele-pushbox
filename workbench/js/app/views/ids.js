/* View · Resource IDs: every resource's global uid "<domain>:<id>", where it is
 * defined in this repository and where it must live in the game
 * (content/export/id-map.json, docs/design/ids.md). Route: #ids/<domain>. */
(function (root) {
  "use strict";
  const store = root.PBStore, el = root.PBStage.el;
  const KIND = { mode: "modes", group: "groups", world: "worlds", recipient: "recipients", cargo: "cargo", combo: "combos", monster: "monsters", item: "items", buff: "buffs", upgrade: "upgrades", badge: "badges", event: "events" };
  let domain = "", query = "";

  function linkFor(e) {
    if (e.domain === "sfx") return "#audio/sfx/" + e.uid;
    if (e.domain === "music") return "#audio/" + (e.audio_kind === "music_set" || e.kind === "music_set" || e.resource_kind === "music_set" ? "maps" : "music") + "/" + e.uid;
    if (e.domain === "art") return "#assets/" + e.id;
    if (e.domain === "mechanic") return "#mechanisms/" + e.id;
    if (e.domain === "level") { const p = store.planned(e.id); return p ? `#modes/${p.group}/${e.id}` : null; }
    if (KIND[e.domain]) return "#catalog/" + KIND[e.domain];
    return null;
  }
  function copy(text) { try { navigator.clipboard.writeText(text); } catch (err) { /* clipboard may be unavailable on file:// */ } }

  function show(id) {
    const map = store.ids();
    if (id !== undefined) domain = map.domains[id] ? id : "";
    const side = document.getElementById("ids-side"), work = document.getElementById("ids-work");
    side.textContent = ""; work.textContent = "";
    side.append(el("div", { class: "group-title", text: "编号空间" }));
    const btn = (k, name, n) => el("button", { class: "list-btn", type: "button", "aria-current": String(k === domain), onclick: () => { location.hash = "#ids/" + k; } }, [el("span", { text: name }), el("span", { class: "small muted", text: String(n) })]);
    side.append(btn("", "全部", map.entries.length));
    for (const [k, d] of Object.entries(map.domains)) side.append(btn(k, `${d.name} · ${k}`, d.count));
    work.append(el("h2", { text: "资源编号与游戏映射" }),
      el("p", { class: "small muted", text: "每个资源都有全局唯一编号「空间:编号」。以工作台（本仓库的数据）为准：游戏只用编号找资源，每个编号在游戏里的位置固定为「游戏路径」一列。新资源先在这里加，游戏不能自己发明编号。数据：content/export/id-map.json；规则：docs/design/ids.md。" }));
    const input = el("input", { id: "ids-search", type: "search", placeholder: "搜索编号、名称或路径", value: query, "aria-label": "搜索",
      oninput: (ev) => { query = ev.target.value; render(); } });
    work.append(el("p", {}, [input]));
    const holder = el("div", { id: "ids-table" }); work.append(holder);
    function render() {
      holder.textContent = "";
      const q = query.trim().toLowerCase();
      const rows = map.entries.filter((e) => (!domain || e.domain === domain) && (!q || (e.uid + " " + e.name + " " + e.game + " " + e.source).toLowerCase().includes(q)));
      const table = el("table", { class: "grid ids" });
      table.append(el("thead", {}, [el("tr", {}, ["全局编号", "名称", "来源（以此为准）", "游戏路径", "状态"].map((t) => el("th", { text: t })))]));
      const tb = el("tbody");
      for (const e of rows.slice(0, 400)) {
        const href = linkFor(e);
        const status = ["sfx", "music"].includes(e.domain) ? root.PBWBAudio.text(({ planned: "planned", missing: "missing", review: "review", approved: "approved" })[e.availability] || "missing") : e.domain === "art" ? `v${e.version} · ${e.approved ? "已确认" : "待确认"}` : e.sha256 ? "规格 " + e.sha256.slice(0, 8) : "";
        tb.append(el("tr", {}, [
          el("td", { class: "mono" }, [href ? el("a", { href, text: e.uid }) : e.uid, " ", el("button", { class: "mini", type: "button", title: "复制编号", onclick: () => copy(e.uid), text: "⧉" })]),
          el("td", { text: e.name }), el("td", { class: "mono small", text: e.source }), el("td", { class: "mono small", text: e.game }), el("td", { class: "small", text: status })]));
      }
      table.append(tb);
      holder.append(el("p", { class: "small muted", text: `${rows.length} 项${rows.length > 400 ? "（只显示前 400 项，请搜索）" : ""}` }), table);
    }
    render();
  }
  root.PBIds = { show };
})(window);
