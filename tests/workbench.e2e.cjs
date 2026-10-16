// Browser checks for workbench/index.html (Playwright + Chromium).
// Run: node tests/workbench.e2e.cjs   (set PLAYWRIGHT_MODULE if playwright is not resolvable)
// Uses a fresh browser profile, so localStorage never touches a real user's drafts.
const path = require("path");
const fs = require("fs");
const { chromium } = require(process.env.PLAYWRIGHT_MODULE || "playwright");

const REPO = path.resolve(__dirname, "..");
const URL = "file://" + path.join(REPO, "workbench/index.html");
const failures = [];
const check = (ok, msg) => { console.log((ok ? "ok   " : "FAIL ") + msg); if (!ok) failures.push(msg); };

async function decode(file) {
  const { decodePng } = await import(path.join(REPO, "tools/lib/png.mjs"));
  return decodePng(fs.readFileSync(path.join(REPO, file)));
}

(async () => {
  const browser = await chromium.launch({ executablePath: process.env.PLAYWRIGHT_CHROMIUM_EXECUTABLE || undefined, args: ["--num-raster-threads=1"] });
  const ctx = await browser.newContext({ viewport: { width: 1440, height: 900 }, acceptDownloads: true });
  await ctx.addInitScript(() => {
    window.__raf = 0; const raf = window.requestAnimationFrame.bind(window);
    window.requestAnimationFrame = (cb) => { window.__raf++; return raf(cb); };
  });
  const page = await ctx.newPage();
  const errors = [];
  page.on("pageerror", (e) => errors.push(e.message));
  page.on("console", (m) => { if (m.type() === "error") errors.push(m.text()); });

  // 1. Every view opens without errors.
  for (const h of ["#overview", "#modes", "#modes/water", "#modes/basics/M03", "#modes/hell-pool", "#modes/water/W08", "#mechanisms", "#mechanisms/float_sink", "#mechanisms/portal", "#scenes/level.W09", "#assets/mech.bridge", "#catalog/cargo", "#catalog/items", "#catalog/slices", "#maps", "#maps/7/2", "#maps/t/dungeon_guard", "#maps/t/dungeon_plate", "#scenes", "#scenes/level.M04", "#scenes/ui.screen.chapters", "#scenes/lobby.forest", "#scenes/showcase.cosmos", "#scenes/chapter.ruins", "#scenes/chapter.sky", "#assets", "#assets/material.chapter2_5", "#assets/char.portitor", "#catalog/worlds", "#catalog/recipients", "#catalog/combos", "#catalog/upgrades", "#ids", "#ids/level", "#scenes/ui.screen.dialogue", "#scenes/ui.screen.hint", "#assets/mech.door", "#edit/obj.crate_wood", "#review", "#export"]) {
    await page.goto(URL + h); await page.waitForTimeout(250);
  }
  check(errors.length === 0, "all views load without console errors" + (errors.length ? ": " + errors[0] : ""));

  // 2. Browser rendering equals the exported PNGs (same core code, integer pixels).
  await page.goto(URL + "#scenes");
  for (const [name, file, expr] of [
    ["showcase", "art/export/reference/showcase.dungeon.png", "(() => { const r = new PB.Raster(320,180); PB.scene.renderLevel(r, PB.scene.SHOWCASE, null, {tick:0}); return Array.from(r.data); })()"],
    ["level M06", "art/export/reference/level.M06.png", "(() => { const r = new PB.Raster(320,180); PB.scene.renderLevel(r, PBStore.level('M06'), null, {tick:0, env:'off'}); return Array.from(r.data); })()"],
    ["level W08 (bridge)", "art/export/reference/level.W08.png", "(() => { const r = new PB.Raster(320,180); PB.scene.renderLevel(r, PBStore.level('W08'), null, {tick:0, env:'off'}); return Array.from(r.data); })()"],
    ["F07 ladder caps", "game/reports/ladder-tops/F07-after.png", "(() => { const r = new PB.Raster(320,180); PB.scene.renderLevel(r, PBStore.level('F07'), null, {tick:0, hud:false, env:'off', ambient:false}); return Array.from(r.data); })()"],
    ["level W09 (portals)", "art/export/reference/level.W09.png", "(() => { const r = new PB.Raster(320,180); PB.scene.renderLevel(r, PBStore.level('W09'), null, {tick:0, env:'off'}); return Array.from(r.data); })()"],
    ["chapter 4 showcase", "art/export/reference/chapter.forest.png", "(() => { const r = new PB.Raster(320,180); PB.scene.renderLevel(r, PB.matter.SHOWCASES.forest, null, {tick:0}); return Array.from(r.data); })()"],
    ["chapter 2-5 materials", "art/export/preview/material.chapter2_5.png", "(() => { const r = new PB.Raster(320,180); PB.matter.swatches(r); return Array.from(r.data); })()"],
    ["hero sheet", "art/export/preview/char.portitor.png", "(() => { const a = PBStore.asset('char.portitor'); const r = new PB.Raster(a.size[0]*a.frames.length, a.size[1]); a.frames.forEach((f,i)=>r.blitRows(f,i*a.size[0],0,false)); return Array.from(r.data); })()"],
  ]) {
    const got = await page.evaluate(expr);
    const want = await decode(file);
    let diff = 0; for (let i = 0; i < want.data.length; i++) if (want.data[i] !== got[i]) diff++;
    check(got.length === want.data.length && diff === 0, `${name}: browser render matches ${file} (${diff} differing bytes)`);
  }

  // The real live compositor reflects a grown vine and a restored pre-growth
  // state without painting a full rung over the platform head.
  const vines = await page.evaluate(() => ['G06','E03'].map(id => {
    const spec = PBStore.level(id), R = PB.tilemodel.replay(spec,spec.solution);
    const state = R.steps[R.steps.length-1].state, k = R.level.devices.findIndex(d=>d.type==='vine');
    const d = R.level.devices[k], x=d.root[0], y=d.root[1]-d.height+1;
    const off = PB.tilemodel.clone(state); off.dev[k]=0;
    const paint = st => { const r = new PB.Raster(320,180); PB.scene.renderLevel(r,spec,{level:R.level,state:st},{tick:0,hud:false,env:'off',ambient:false}); return r; };
    const a=paint(state), b=paint(off), c=paint(state);
    const ox=(320-R.level.w*16)>>1, oy=20+((160-R.level.h*16)>>1);
    let upper=0,lower=0;
    for(let yy=0;yy<16;yy++) for(let xx=0;xx<16;xx++) if(a.get(ox+x*16+xx,oy+y*16+yy)!==b.get(ox+x*16+xx,oy+y*16+yy)) { if(yy<12) upper++; else lower++; }
    return {id,grown:!!state.dev[k],upper,lower,restored:Array.from(a.data).every((v,i)=>v===c.data[i])};
  }));
  check(vines.every(v=>v.grown&&v.upper===0&&v.lower>0&&v.restored),'G06/E03 grown vine has a short cap and restores identical pixels ('+JSON.stringify(vines)+')');

  const ropes = await page.evaluate(() => {
    const sl=PBStore.catalog('slices')[0], cat={monsters:PBStore.catalog('monsters'),cargo:PBStore.catalog('cargo'),recipients:PBStore.catalog('recipients'),items:PBStore.catalog('items')};
    const rows=Array.from({length:10},(_,y)=>Array.from({length:20},(_,x)=>y===0||y===9||x===0||x===19?'#':'.'));
    for(let x=1;x<19;x++) rows[4][x]='#';
    for(let y=0;y<9;y++) rows[y][3]=y>=5?'H':'.';
    rows[7][1]='P';
    const spec={id:'rope-render-test',chapter:'dungeon',map:rows.map(r=>r.join(''))};
    const run=PB.rt.roomFromSpec(PB.rt.context(cat,sl),spec); run.room.player=null;
    const paint=()=>{const r=new PB.Raster(320,180);PB.droom.renderLive(r,run,{tick:0,hud:false,env:'off'});return r;};
    const off=paint(); run.room.climb=new Set([3*20+3,4*20+3]); const cap=paint();
    const diff=(a,b,ty,start,end)=>{let n=0;for(let yy=start;yy<end;yy++)for(let xx=0;xx<16;xx++)if(a.get(3*16+xx,20+ty*16+yy)!==b.get(3*16+xx,20+ty*16+yy))n++;return n;};
    for(let y=0;y<=4;y++)run.room.climb.add(y*20+3); const extended=paint();
    return {upper:diff(cap,off,3,0,12),lower:diff(cap,off,3,12,16),interior:diff(extended,cap,3,0,12),seam:diff(extended,off,0,0,12)};
  });
  check(ropes.upper===0&&ropes.lower>0&&ropes.interior>0&&ropes.seam>0,'delivery rope caps merge with static ladders and keep room seams ('+JSON.stringify(ropes)+')');

  // 2b. Content views show derived statuses from data/content.js.
  await page.goto(URL + "#modes/basics"); await page.waitForTimeout(200);
  check((await page.locator("#modes-work table.levels tbody tr").count()) === 7, "modes view lists the 7 basics levels");
  check(await page.locator('#modes-work a[href="#scenes/level.M01"]').isVisible(), "a level with a spec links to its scene preview");
  await page.goto(URL + "#modes/water"); await page.waitForTimeout(200);
  check((await page.locator("#modes-work table.levels tbody tr").count()) === 9, "modes view lists the 9 water-and-machinery levels");
  // The design model runs in the browser too: chapter 2 author solutions win there.
  const wins = await page.evaluate(() => ["W01", "W02", "W03", "W04", "W05", "W07", "W08", "W09", "W10"].map((id) => { const l = PBStore.level(id); return id + ":" + PB.tilemodel.replay(l, l.solution).won; }));
  check(wins.every((w) => w.endsWith(":true")), "chapter 2 author solutions win in the browser model (" + wins.filter((w) => !w.endsWith(":true")).join(", ") + ")");
  await page.goto(URL + "#mechanisms/plate_door"); await page.waitForTimeout(200);
  const mechText = await page.locator("#mech-work").textContent();
  check(mechText.includes("M05") && mechText.includes("M06") && mechText.includes("有规格"), "mechanism page shows its levels and derived status");
  await page.goto(URL + "#overview"); await page.waitForTimeout(200);
  check((await page.locator("#overview-root").textContent()).includes("没有错误或警告"), "overview shows a clean content check");
  await page.goto(URL + "#ids"); await page.waitForTimeout(200);
  await page.fill("#ids-search", "W08"); await page.waitForTimeout(150);
  const idText = await page.locator("#ids-work").textContent();
  check(idText.includes("level:W08") && idText.includes("res://generated/content/levels/lab/water/W08.json"), "id map page finds level:W08 and its game path");
  await page.goto(URL + "#catalog/worlds"); await page.waitForTimeout(200);
  const eastAsia = JSON.parse(fs.readFileSync(path.join(REPO, "content/catalog/worlds.json"), "utf8")).entries.filter((w) => w.culture === "东亚").length;
  await page.selectOption("#catalog-culture", "东亚"); await page.waitForTimeout(150);
  const rows = await page.locator("#catalog-work table.grid tbody tr").count();
  check(rows === eastAsia && (await page.locator("#catalog-work").textContent()).includes("地府·酆都"), `region catalog filters by culture sphere (${rows}/${eastAsia} 东亚 rows, 地府 listed)`);

  // 2c. Map preview: the browser generator reproduces the golden maps; rooms are clickable.
  const golden = JSON.parse(fs.readFileSync(path.join(REPO, "content/export/delivery-golden.json"), "utf8")).maps.slice(0, 8);
  await page.goto(URL + "#maps/3"); await page.waitForTimeout(300);
  const same = await page.evaluate((g) => {
    const sl = PBStore.catalog("slices")[0], list = sl.rooms.map((id) => PBStore.content().rooms.find((r) => r.id === id)).sort((a, b) => a.id.localeCompare(b.id));
    return g.map((m) => JSON.stringify(PB.mapgen.generate(m.seed, sl, list).rooms) === JSON.stringify(m.rooms));
  }, golden);
  check(same.every(Boolean), `browser map generator matches the golden table (${same.filter(Boolean).length}/${same.length} seeds)`);
  const box3 = await page.locator("canvas.map-overview").boundingBox();
  const target = await page.evaluate(() => { const sl = PBStore.catalog("slices")[0], list = sl.rooms.map((id) => PBStore.content().rooms.find((r) => r.id === id)).sort((a, b) => a.id.localeCompare(b.id)); const m = PB.mapgen.generate(3, sl, list), r = m.rooms[m.rooms.length - 1]; return { x: r.x, y: r.y, i: r.index, cols: m.cols, rows: m.rows }; });
  const cw = await page.evaluate(() => document.querySelector("canvas.map-overview").width), ch = await page.evaluate(() => document.querySelector("canvas.map-overview").height);
  await page.mouse.click(box3.x + ((8 + target.x * 88 + 40) / cw) * box3.width, box3.y + ((8 + target.y * 48 + 20) / ch) * box3.height);
  await page.waitForTimeout(250);
  check((await page.evaluate(() => location.hash)) === `#maps/3/${target.i}`, "clicking a room on the overview selects it");
  check((await page.locator("#maps-work h3").textContent()).includes("收件人之家"), "the last room of the path is the recipient's home");
  await page.goto(URL + "#maps/t/dungeon_station"); await page.waitForTimeout(250);
  check((await page.locator("#maps-work table.routes tbody tr").count()) === 48, "station template lists its 48 checked routes");
  check((await page.locator("#maps-work table.demos tbody tr").count()) === 2, "station template lists its demo and the demo's mirror image");

  // 2d. Real-time model: the browser replays the golden demos frame for frame; a demo plays in the
  // map preview; a whole map can be played with the keyboard.
  const replays = JSON.parse(fs.readFileSync(path.join(REPO, "content/export/delivery-golden.json"), "utf8")).replays;
  const replayed = await page.evaluate((list) => {
    const sl = PBStore.catalog("slices")[0], cat = { monsters: PBStore.catalog("monsters"), cargo: PBStore.catalog("cargo"), recipients: PBStore.catalog("recipients"), items: PBStore.catalog("items") };
    return list.map((g) => { const t = PBStore.content().rooms.find((r) => r.id === g.template), r = PB.rt.runDemo(cat, sl, t, t.demos.find((d) => d.id === g.demo), g.mirror); return r.ok && r.end === g.end && JSON.stringify(r.frames) === JSON.stringify(g.frames); });
  }, replays.map((g) => ({ template: g.template, demo: g.demo, mirror: g.mirror, end: g.end, frames: g.frames })));
  check(replayed.length >= 20 && replayed.every(Boolean), `browser real-time model reproduces the golden replays (${replayed.filter(Boolean).length}/${replayed.length})`);
  await page.goto(URL + "#maps/t/dungeon_guard"); await page.waitForTimeout(250);
  await page.selectOption('select[aria-label="演示"]', "crush"); await page.waitForTimeout(150);
  await page.selectOption('select[aria-label="播放速度"]', "4");
  const demoDone = await page.waitForFunction(() => { const s = PBPlay.active(); return s && s.run.leaving ? { edge: s.run.leaving.edge, kos: s.run.kos, hearts: s.run.hearts } : null; }, null, { timeout: 30000 }).then((h) => h.jsonValue()).catch(() => null);
  await page.waitForTimeout(200);
  check(!!demoDone && demoDone.edge === "right" && demoDone.kos === 1 && demoDone.hearts === 3 && (await page.locator("#maps-info").textContent()).includes("放倒怪物（压倒）"),
    "the crush demo plays in the map preview: the skeleton is crushed, the player leaves right unhurt");
  await page.goto(URL + "#maps/11"); await page.waitForTimeout(300);
  await page.click('.play-bar button:has-text("试玩整张图")'); await page.waitForTimeout(200);
  const gateExit = await page.evaluate(() => { const r = PBPlay.active().run; return r.map.rooms[0].open.bottom || null; });
  await page.keyboard.down("ArrowRight");
  await page.waitForFunction(() => PBPlay.active().run.room.player.x >= 9, null, { timeout: 10000 }).catch(() => {});
  await page.keyboard.up("ArrowRight");
  await page.keyboard.down("ArrowDown");
  await page.waitForFunction(() => PBPlay.active().run.roomIndex === 1, null, { timeout: 10000 }).catch(() => {});
  await page.keyboard.up("ArrowDown");
  const moved = await page.evaluate(() => { const r = PBPlay.active().run; return { room: r.roomIndex, entered: r.events.filter((e) => e.type === "room").length, y: r.room.player.y }; });
  check(gateExit === "mid" && moved.room === 1 && moved.entered === 1, `keyboard play: from the gate down the shaft into the second room of seed 11 (${JSON.stringify(moved)})`);
  await page.keyboard.press("r"); await page.waitForTimeout(150);
  check(await page.evaluate(() => { const r = PBPlay.active().run; return r.events.some((e) => e.type === "reset") && r.room.player.y === 0; }), "R restarts the room at the door it was entered by");

  // 2e. Step-4 art candidates: drawn in the map preview while "美术候选" is on, placeholders when off.
  await page.goto(URL + "#maps/7/4"); await page.waitForTimeout(300);
  await page.click('.play-bar button:has-text("静态")'); await page.waitForTimeout(400);
  const withArt = await page.evaluate(() => PBMaps.placeholders());
  await page.click('#maps-side button:has-text("美术候选")');
  await page.waitForFunction(() => PBMaps.placeholders().length > 0, null, { timeout: 5000 }).catch(() => {});
  const without = await page.evaluate(() => PBMaps.placeholders());
  await page.click('#maps-side button:has-text("美术候选")'); await page.waitForTimeout(200);
  check(!withArt.includes("rat_swarm") && !withArt.includes("coin") && !without.includes("rat_swarm") && !without.includes("coin"),
    `APR-0006 art stays visible with candidates off (on: ${JSON.stringify(withArt)}, off: ${JSON.stringify(without)})`);
  check(!(await page.locator("#maps-work").textContent()).includes("美术候选（未确认"), "approved delivery art is not described as unconfirmed");

  // 3. Hidden stages stop animating; the visible one animates.
  await page.goto(URL + "#scenes/showcase.forest"); await page.waitForTimeout(300);
  let before = await page.evaluate(() => window.__raf); await page.waitForTimeout(1000);
  const busy = (await page.evaluate(() => window.__raf)) - before;
  await page.goto(URL + "#review"); await page.waitForTimeout(300);
  before = await page.evaluate(() => window.__raf); await page.waitForTimeout(1000);
  const idle = (await page.evaluate(() => window.__raf)) - before;
  check(busy > 20 && idle < 3, `animation loop runs only when visible (visible ${busy}/s, hidden ${idle}/s)`);

  // 4. Edits autosave, survive reload and export to an importable file.
  await page.goto(URL + "#edit/obj.crate_wood"); await page.waitForTimeout(300);
  await page.click('[data-code="A"]');
  const box = await page.locator(".editor-canvas").boundingBox();
  await page.mouse.click(box.x + box.width * 0.5, box.y + box.height * 0.5);
  await page.waitForTimeout(200);
  check(await page.locator("#drafts-flag").isVisible(), "drawing creates a local draft and shows the unsaved flag");
  const exportBadge = page.locator('#nav a[data-view="export"] #drafts-count');
  check((await exportBadge.isVisible()) && (await exportBadge.textContent()) === "1", "the 导出 menu item keeps the draft hint (1)");
  await page.reload(); await page.waitForTimeout(300);
  check((await page.locator("#drafts-flag").textContent()).includes("1"), "draft survives a page reload");
  await page.goto(URL + "#export"); await page.waitForTimeout(200);
  const [dl] = await Promise.all([page.waitForEvent("download"), page.click("text=下载修改文件")]);
  const edits = JSON.parse(fs.readFileSync(await dl.path(), "utf8"));
  check(edits.format === "pushbox.art-edits/1" && edits.edits[0].id === "obj.crate_wood" && edits.edits[0].frames[0][8].includes("A"), "export produces a pushbox.art-edits/1 file containing the edit");
  page.once("dialog", (d) => d.accept());
  await page.click("#export-root button.danger"); await page.waitForTimeout(200);
  check(!(await page.locator("#drafts-flag").isVisible()), "discarding the draft clears the flag");
  check(!(await page.locator("#drafts-count").isVisible()), "discarding the draft clears the 导出 menu hint");

  // 5. Review page: approved assets cannot be re-selected; requests carry exact versions.
  await page.goto(URL + "#review"); await page.waitForTimeout(200);
  const states = await page.evaluate(() => PBStore.assets().map((a) => [a.id, a.status, a.version, a.content_hash]));
  const reviewable = states.find((x) => x[1] === "review");
  if (reviewable) {
    const name = await page.evaluate((id) => PBStore.asset(id).name, reviewable[0]);
    await page.check(`input[aria-label="通过 ${name}"]`);
    const text = await page.locator('textarea[aria-label="确认文字"]').inputValue();
    check(text.includes(`${reviewable[0]}@v${reviewable[2]} #${reviewable[3].slice(0, 12)}`), "review text lists the exact version and hash");
  } else {
    const crate = states.find((x) => x[0] === "obj.crate_wood");
    check(await page.locator('input[aria-label="通过 木箱"]').isDisabled(), "approved assets cannot be selected again");
    await page.fill('input[aria-label="修改意见 木箱"]', "test change request");
    await page.locator('input[aria-label="修改意见 木箱"]').dispatchEvent("change");
    const text = await page.locator('textarea[aria-label="确认文字"]').inputValue();
    check(text.includes(`obj.crate_wood@v${crate[2]}：test change request`), "change requests name the exact asset version");
    await page.click("text=清空勾选与意见");
  }

  // 6. Every UI screen lays out in Chinese and English without cut text.
  const textIssues = await page.evaluate(() => {
    const out = [];
    for (const a of PBStore.assets().filter((x) => x.category === "screen")) for (const locale of ["zh-Hans", "en"]) {
      const st = { locale, focus: 0, specs: Object.fromEntries(PBStore.levels().map((l) => [l.id, l])), levelSpec: PBStore.level("M05"), ruleSpec: PBStore.level("M03") };
      for (const i of PB.ui.render(new PB.Raster(320, 180), a, 0, st)) out.push(`${a.id}/${locale}/${i.key}`);
    }
    return out;
  });
  check(textIssues.length === 0, "all screens fit in zh-Hans and en" + (textIssues.length ? ": " + textIssues.slice(0, 3).join(", ") : ""));

  // 6b. Left category menu (WB-01): drawn from the one PBNav.MENU array, folds by category and
  // remembers it, keeps hash links and browser history; the whole left column can collapse.
  const menuErrors = errors.length;
  await page.goto(URL + "#overview"); await page.waitForTimeout(200);
  const menu = await page.evaluate(() => Array.from(document.querySelectorAll("#nav > a, #nav > .nav-group")).map((n) => n.matches("a")
    ? [n.firstChild.textContent] : [n.querySelector(".nav-head-label").textContent, ...Array.from(n.querySelectorAll(".nav-list a")).map((a) => a.firstChild.textContent)]));
  const wantMenu = [["总览"], ["关卡与玩法", "模式与关卡", "机制", "设计数据"], ["配送", "地图预览"], ["美术", "场景", "资产与动画", "编辑与对比", "确认", "导出"], ["工具", "编号映射"]];
  check(JSON.stringify(menu) === JSON.stringify(wantMenu), "left menu shows the categories and pages of WB-01 in order (" + JSON.stringify(menu) + ")");
  const reg = await page.evaluate(() => ({
    menu: PBNav.MENU.flatMap((m) => (m.items ? m.items.map((i) => i.view) : [m.view])),
    links: Array.from(document.querySelectorAll("#nav a[data-view]")).map((a) => a.dataset.view),
    sections: Array.from(document.querySelectorAll("main > section.view")).map((x) => x.id.replace(/^view-/, "")),
    modules: PBNav.pages().every((x) => window[x.module] && typeof window[x.module].show === "function"),
  }));
  check(JSON.stringify(reg.links) === JSON.stringify(reg.menu) && reg.modules && reg.sections.length === reg.menu.length && reg.sections.every((x) => reg.menu.includes(x)),
    `menu links and the router both come from the one PBNav.MENU array and cover every page (${reg.links.length} links, ${reg.sections.length} pages)`);
  const wrongClicks = [];
  for (const v of reg.menu) {
    await page.click(`#nav a[data-view="${v}"]`); await page.waitForTimeout(200);
    const st = await page.evaluate((v) => ({ hash: location.hash, shown: !document.getElementById("view-" + v).hidden, current: Array.from(document.querySelectorAll('#nav a[aria-current="page"]')).map((a) => a.dataset.view).join() }), v);
    if (st.hash !== "#" + v || !st.shown || st.current !== v) wrongClicks.push(v + " " + JSON.stringify(st));
  }
  check(wrongClicks.length === 0, "clicking each menu item opens its page and highlights only that item" + (wrongClicks.length ? ": " + wrongClicks[0] : ""));
  const where = () => page.evaluate(() => ({
    hash: location.hash,
    view: Array.from(document.querySelectorAll("main > section.view")).filter((x) => !x.hidden).map((x) => x.id).join(),
    current: Array.from(document.querySelectorAll('#nav a[aria-current="page"]')).map((a) => a.dataset.view).join(),
    heads: Array.from(document.querySelectorAll("#nav .nav-head.has-current")).map((x) => x.dataset.group + ":" + x.getAttribute("aria-expanded")).join(),
    crumb: document.getElementById("nav-crumb").textContent,
  }));
  await page.goto(URL + "#maps/5/1"); await page.waitForTimeout(300);
  const deepMap = await where(), mapText = await page.locator("#maps-work").textContent();
  check(deepMap.view === "view-maps" && deepMap.current === "maps" && deepMap.heads === "delivery:true" && deepMap.crumb === "配送 › 地图预览" && mapText.includes("种子 5") && mapText.includes("第 2 间"),
    "#maps/5/1 still opens seed 5, room 2, with 地图预览 highlighted under an open 配送 (" + JSON.stringify(deepMap) + ")");
  await page.goto(URL + "#assets/char.miner"); await page.waitForTimeout(300);
  const deepAsset = await where();
  check(deepAsset.view === "view-assets" && deepAsset.current === "assets" && deepAsset.heads === "art:true" && (await page.locator("#asset-inspector").textContent()).includes("char.miner"),
    "#assets/char.miner still opens that asset, with 资产与动画 highlighted under an open 美术");
  await page.goto(URL + "#maps/5/1"); await page.waitForTimeout(250);
  await page.click('#nav a[data-view="assets"]'); await page.waitForTimeout(250);
  const picked = await where();
  await page.goBack(); await page.waitForTimeout(300);
  const back = await where();
  await page.goForward(); await page.waitForTimeout(300);
  const fwd = await where();
  check(picked.hash === "#assets" && back.hash === "#maps/5/1" && back.view === "view-maps" && back.current === "maps" && fwd.hash === "#assets" && fwd.view === "view-assets" && fwd.current === "assets",
    "browser back / forward move between pages opened from the menu and keep the highlight in step");

  const fold = (g) => page.evaluate((g) => ({ expanded: document.querySelector(`#nav .nav-head[data-group="${g}"]`).getAttribute("aria-expanded"), hidden: document.getElementById("nav-list-" + g).hidden }), g);
  await page.goto(URL + "#overview"); await page.waitForTimeout(200);
  await page.click('#nav .nav-head[data-group="play"]'); await page.waitForTimeout(100);
  const folded = await fold("play");
  await page.reload(); await page.waitForTimeout(400);
  const foldKept = await fold("play");
  check(folded.expanded === "false" && folded.hidden && foldKept.expanded === "false" && foldKept.hidden, "clicking a category title folds it, and the folding survives a reload");
  await page.goto(URL + "#mechanisms/acid"); await page.waitForTimeout(250);
  const unfolded = await where();
  check(unfolded.current === "mechanisms" && unfolded.heads === "play:true" && !(await fold("play")).hidden, "opening a page inside a folded category unfolds it and highlights the page");
  await page.click('#nav .nav-head[data-group="play"]'); await page.waitForTimeout(100);
  await page.goto(URL + "#mechanisms/plate_door"); await page.waitForTimeout(250);
  const stillFolded = await where();
  await page.click('#nav .nav-head[data-group="play"]'); await page.waitForTimeout(100);
  check(stillFolded.heads === "play:false" && (await fold("play")).expanded === "true", "the current category can be folded (its title stays highlighted) and moving inside the page keeps it folded");
  const pick = await page.evaluate(() => PBStore.assets().find((a) => a.status === "review" && !PBStore.review().selected[a.id]).id);
  await page.evaluate((id) => PBStore.toggleSelected(id, true), pick); await page.waitForTimeout(100);
  const reviewBadge = page.locator('#nav a[data-view="review"] #review-count');
  const badgeShown = (await reviewBadge.isVisible()) && Number(await reviewBadge.textContent()) === (await page.evaluate(() => Object.keys(PBStore.review().selected).length));
  await page.click('#nav .nav-head[data-group="art"]'); await page.waitForTimeout(100);
  const dotShown = await page.locator('#nav .nav-head[data-group="art"] .nav-dot').isVisible();
  await page.click('#nav .nav-head[data-group="art"]');
  await page.evaluate((id) => PBStore.toggleSelected(id, false), pick); await page.waitForTimeout(100);
  check(badgeShown && dotShown, "the 确认 menu item keeps its count, and a folded 美术 still shows a mark for it");

  await page.goto(URL + "#scenes/showcase.forest"); await page.waitForTimeout(300);
  const layoutBox = () => page.evaluate(() => ({
    nav: getComputedStyle(document.getElementById("nav")).display === "none" ? 0 : document.getElementById("nav").getBoundingClientRect().width,
    main: document.querySelector("main").getBoundingClientRect().width,
    work: document.querySelector("#view-scenes .work").getBoundingClientRect().width,
    expanded: document.getElementById("nav-toggle").getAttribute("aria-expanded"),
  }));
  const wide = await layoutBox();
  await page.click("#nav-toggle"); await page.waitForTimeout(250);
  const roomy = await layoutBox();
  await page.reload(); await page.waitForTimeout(400);
  const roomyKept = await layoutBox();
  await page.click("#nav-toggle"); await page.waitForTimeout(250);
  const restored = await layoutBox();
  check(wide.nav > 150 && wide.expanded === "true" && roomy.nav === 0 && roomy.expanded === "false" && roomy.main >= 1439 && roomy.work >= wide.work + wide.nav - 1 && roomyKept.nav === 0 && restored.nav === wide.nav && restored.expanded === "true",
    `the whole left column collapses for big pictures, stays collapsed after a reload and opens again (work area ${Math.round(wide.work)} → ${Math.round(roomy.work)}px)`);
  check(errors.length === menuErrors, "menu actions cause no console errors" + (errors.length > menuErrors ? ": " + errors[menuErrors] : ""));

  // Storage that throws (blocked or private mode) must not break the menu.
  const blocked = await browser.newContext({ viewport: { width: 1440, height: 900 } });
  await blocked.addInitScript(() => { Object.defineProperty(window, "localStorage", { configurable: true, get() { throw new DOMException("storage is disabled", "SecurityError"); } }); });
  const bp = await blocked.newPage(), blockedErrors = [];
  bp.on("pageerror", (e) => blockedErrors.push(e.message));
  bp.on("console", (m) => { if (m.type() === "error") blockedErrors.push(m.text()); });
  await bp.goto(URL + "#overview"); await bp.waitForTimeout(400);
  const denied = await bp.evaluate(() => { try { localStorage.getItem("pb.wb.nav.v1"); return false; } catch (e) { return true; } });
  await bp.click('#nav .nav-head[data-group="art"]'); await bp.waitForTimeout(100);
  const blockedFold = await bp.getAttribute('#nav .nav-head[data-group="art"]', "aria-expanded");
  await bp.click('#nav .nav-head[data-group="art"]'); await bp.waitForTimeout(100);
  await bp.click('#nav a[data-view="scenes"]'); await bp.waitForTimeout(300);
  const blockedHash = await bp.evaluate(() => location.hash);
  await bp.click("#nav-toggle"); await bp.waitForTimeout(150);
  const blockedCollapse = await bp.evaluate(() => getComputedStyle(document.getElementById("nav")).display === "none");
  await blocked.close();
  check(denied && blockedFold === "false" && blockedHash === "#scenes" && blockedCollapse && blockedErrors.length === 0,
    "with localStorage blocked the menu still folds, navigates and collapses without errors" + (blockedErrors.length ? ": " + blockedErrors[0] : ""));

  // 7. Narrow window: no horizontal page scroll, navigation still reachable.
  await page.setViewportSize({ width: 390, height: 800 });
  for (const h of ["#overview", "#modes/water", "#mechanisms/acid", "#catalog/cargo", "#catalog/slices", "#maps/5/1", "#maps/t/dungeon_well", "#scenes", "#assets/char.miner", "#review"]) {
    await page.goto(URL + h); await page.waitForTimeout(250);
    const overflow = await page.evaluate(() => document.documentElement.scrollWidth - window.innerWidth);
    check(overflow <= 0, `${h} at 390px has no horizontal page scroll (${overflow}px)`);
  }
  // 7b. At phone width the menu is one button in the top-left corner that opens a drawer.
  await page.goto(URL + "#maps/5/1"); await page.waitForTimeout(250);
  const menuBtn = await page.locator("#nav-toggle").boundingBox();
  check(!!menuBtn && menuBtn.x < 40 && menuBtn.y < 40 && (await page.locator("#nav-toggle").isVisible()) && !(await page.locator("#nav").isVisible()),
    "at 390px the menu folds into a button in the top-left corner and the drawer starts closed");
  await page.click("#nav-toggle"); await page.waitForTimeout(350);
  const drawer = await page.evaluate(() => { const r = document.getElementById("nav").getBoundingClientRect(); return { left: r.left, right: r.right, expanded: document.getElementById("nav-toggle").getAttribute("aria-expanded"), scrim: !document.getElementById("nav-scrim").hidden, inert: document.querySelector("main").inert, overflow: document.documentElement.scrollWidth - window.innerWidth }; });
  check(drawer.left === 0 && drawer.right <= 390 && drawer.expanded === "true" && drawer.scrim && drawer.inert && drawer.overflow <= 0 && (await page.locator('#nav a[data-view="maps"][aria-current="page"]').isVisible()),
    `the button opens the menu as a drawer over the page, without horizontal scroll (${drawer.overflow}px)`);
  await page.click('#nav a[data-view="scenes"]'); await page.waitForTimeout(350);
  check((await page.evaluate(() => location.hash)) === "#scenes" && !(await page.locator("#nav").isVisible()) && (await page.getAttribute("#nav-toggle", "aria-expanded")) === "false" && !(await page.evaluate(() => document.querySelector("main").inert)),
    "picking a page in the drawer opens it and closes the drawer");
  await page.click("#nav-toggle"); await page.waitForTimeout(350);
  await page.keyboard.press("Escape"); await page.waitForTimeout(350);
  const escClosed = !(await page.locator("#nav").isVisible());
  await page.click("#nav-toggle"); await page.waitForTimeout(350);
  await page.mouse.click(375, 500); await page.waitForTimeout(350);
  const outsideClosed = !(await page.locator("#nav").isVisible());
  check(escClosed && outsideClosed, "Esc and tapping outside the drawer close it");
  await browser.close();
  console.log(failures.length ? `\n${failures.length} check(s) failed` : "\nall workbench checks passed");
  process.exit(failures.length ? 1 : 0);
})().catch((e) => { console.error(e); process.exit(1); });
