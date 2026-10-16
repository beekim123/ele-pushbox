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
  const browser = await chromium.launch();
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
  for (const h of ["#overview", "#modes", "#modes/water", "#modes/basics/M03", "#modes/hell-pool", "#modes/water/W08", "#mechanisms", "#mechanisms/float_sink", "#mechanisms/portal", "#scenes/level.W09", "#assets/mech.bridge", "#catalog/cargo", "#catalog/items", "#catalog/slices", "#maps", "#maps/7/2", "#maps/t/dungeon_guard", "#maps/t/dungeon_plate", "#rooms2", "#rooms2/pool/5", "#rooms2/diyu_lantern", "#rooms2/dungeon2_yard", "#scenes", "#scenes/level.M04", "#scenes/ui.screen.chapters", "#scenes/lobby.forest", "#scenes/showcase.cosmos", "#scenes/chapter.ruins", "#scenes/chapter.sky", "#assets", "#assets/material.chapter2_5", "#assets/char.portitor", "#catalog/worlds", "#catalog/recipients", "#catalog/combos", "#catalog/upgrades", "#ids", "#ids/level", "#scenes/ui.screen.dialogue", "#scenes/ui.screen.hint", "#assets/mech.door", "#edit/obj.crate_wood", "#review", "#export"]) {
    await page.goto(URL + h); await page.waitForTimeout(250);
  }
  check(errors.length === 0, "all views load without console errors" + (errors.length ? ": " + errors[0] : ""));

  // 2. Browser rendering equals the exported PNGs (same core code, integer pixels).
  await page.goto(URL + "#scenes");
  for (const [name, file, expr] of [
    ["showcase", "art/export/reference/showcase.dungeon.png", "(() => { const r = new PB.Raster(320,180); PB.scene.renderLevel(r, PB.scene.SHOWCASE, null, {tick:0}); return Array.from(r.data); })()"],
    ["level M06", "art/export/reference/level.M06.png", "(() => { const r = new PB.Raster(320,180); PB.scene.renderLevel(r, PBStore.level('M06'), null, {tick:0, env:'off'}); return Array.from(r.data); })()"],
    ["level W08 (bridge)", "art/export/reference/level.W08.png", "(() => { const r = new PB.Raster(320,180); PB.scene.renderLevel(r, PBStore.level('W08'), null, {tick:0, env:'off'}); return Array.from(r.data); })()"],
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

  // 2e. Step-4 art is approved (APR-0006): the map preview draws it with "美术候选" on or off and lists no
  // candidates. The switch itself is checked on the v2 rooms (2f), which still have candidates.
  await page.goto(URL + "#maps/7/4"); await page.waitForTimeout(300);
  await page.click('.play-bar button:has-text("静态")'); await page.waitForTimeout(400);
  const withArt = await page.evaluate(() => PBMaps.placeholders());
  await page.click('#maps-side button:has-text("美术候选")'); await page.waitForTimeout(400);
  const without = await page.evaluate(() => PBMaps.placeholders());
  const mapNote = await page.locator("#maps-work").textContent();
  await page.click('#maps-side button:has-text("美术候选")'); await page.waitForTimeout(200);
  check(withArt.length === 0 && without.length === 0,
    `map preview draws the approved step-4 art whether candidates are on or off (on: ${JSON.stringify(withArt)}, off: ${JSON.stringify(without)})`);
  check(!mapNote.includes("美术候选（未确认"), "the map preview lists no unconfirmed art");

  // 2f. v2 rooms: the browser draws the same run pool as tools/check-rooms2.mjs; a run lists and links its
  // rooms; a room replays its solution step by step and plays with the keyboard; candidates switch off.
  await page.goto(URL + "#rooms2/pool/5"); await page.waitForTimeout(300);
  const poolDiff = await page.evaluate(() => {
    const want = PBStore.content().pools2[0], keys = ["maps", "recipients", "cargo", "template_use", "rooms_per_run", "screens_per_run"], got = {};
    for (const k of keys) got[k] = {};
    const add = (k, v) => { got[k][v] = (got[k][v] || 0) + 1; };
    for (let s = 1; s <= want.seeds; s++) {
      const m = PBRooms2.generate(s);
      if (m.error) return ["seed " + s + ": " + m.error];
      add("maps", m.slice); add("recipients", m.recipient); add("cargo", m.cargo); add("rooms_per_run", m.rooms.length);
      add("screens_per_run", m.rooms.reduce((n, r) => n + r.cols * r.rows, 0));
      for (const r of m.rooms) add("template_use", r.template);
    }
    const norm = (o) => JSON.stringify(Object.keys(o || {}).sort().map((k) => [k, o[k]]));
    return keys.filter((k) => norm(got[k]) !== norm(want[k]));
  });
  check(poolDiff.length === 0, "browser run generator matches the exported run-pool statistics" + (poolDiff.length ? ": " + poolDiff.join(", ") : ""));
  const run5 = await page.evaluate(() => PBRooms2.state().run);
  check(!!run5 && (await page.locator("#rooms2-work table.r2 tbody tr").count()) === run5.length, `the run of seed 5 lists its ${run5 && run5.length} rooms`);
  const homeAt = await page.evaluate(() => {
    const m = PBRooms2.generate(5), r = m.rooms[m.rooms.length - 1], cv = document.querySelector("#rooms2-work canvas.map-overview");
    return { x: 6 + r.gx * 64 + 30, y: 6 + r.gy * 34 + 15, w: cv.width, h: cv.height, href: document.querySelector("#rooms2-work table.r2 tbody tr:last-child a").getAttribute("href") };
  });
  const ov2 = await page.locator("#rooms2-work canvas.map-overview").boundingBox();
  await page.mouse.click(ov2.x + (homeAt.x / homeAt.w) * ov2.width, ov2.y + (homeAt.y / homeAt.h) * ov2.height);
  await page.waitForTimeout(300);
  check((await page.evaluate(() => location.hash)) === homeAt.href && (await page.evaluate(() => PBRooms2.state().page)) === "room", "clicking a room on the run overview opens that room on its route");
  await page.goto(URL + "#rooms2/dungeon2_bridge"); await page.waitForTimeout(300);
  await page.click('#rooms2-work button:has-text("解法回放")'); await page.waitForTimeout(200);
  await page.keyboard.press("End"); await page.waitForTimeout(150);
  const atEnd = await page.evaluate(() => PBRooms2.state());
  await page.keyboard.press("ArrowLeft"); await page.waitForTimeout(150);
  const oneBack = await page.evaluate(() => PBRooms2.state());
  check(atEnd.mode === "replay" && atEnd.author === true && atEnd.steps > 0 && atEnd.step === atEnd.steps && atEnd.done === true && oneBack.step === atEnd.steps - 1 && oneBack.done === false,
    `the bridge replays its author solution to the end and steps back (${atEnd.step}/${atEnd.steps} done ${atEnd.done}, then ${oneBack.step} done ${oneBack.done})`);
  await page.click('#rooms2-work button:has-text("试玩")'); await page.waitForTimeout(200);
  await page.keyboard.press("ArrowRight"); await page.waitForTimeout(300);
  const walked = await page.evaluate(() => PBRooms2.state().moves);
  await page.keyboard.press("z"); await page.waitForTimeout(150);
  const undone = await page.evaluate(() => PBRooms2.state().moves);
  check(walked === 1 && undone === 0, `keyboard play: → walks one step and Z takes it back (${walked} → ${undone})`);
  await page.goto(URL + "#rooms2/dungeon2_yard"); await page.waitForTimeout(300);
  const stageSize = () => page.evaluate(() => { const c = document.querySelector("#rooms2-work .stage-frame canvas"); return c.width + "×" + c.height; });
  const fullSize = await stageSize();
  await page.keyboard.press("v"); await page.waitForTimeout(150);
  const camSize = await stageSize();
  await page.keyboard.press("v"); await page.waitForTimeout(150);
  check(fullSize === "640×340" && camSize === "320×180", `a 2×2 room is drawn whole (${fullSize}) or through the game camera (${camSize})`);
  await page.goto(URL + "#rooms2/diyu_ghostfire"); await page.waitForTimeout(400);
  const r2With = await page.evaluate(() => PBRooms2.state().placeholders);
  await page.click('#rooms2-side button:has-text("美术候选")');
  await page.waitForFunction(() => PBRooms2.state().placeholders.length > 0, null, { timeout: 5000 }).catch(() => {});
  const r2Without = await page.evaluate(() => PBRooms2.state().placeholders);
  await page.click('#rooms2-side button:has-text("美术候选")'); await page.waitForTimeout(200);
  check(r2With.length === 0 && r2Without.includes("wandering_soul") && !r2Without.includes("coin"),
    `v2 rooms draw the candidates only while the switch is on, approved coins always (on: ${JSON.stringify(r2With)}, off: ${JSON.stringify(r2Without)})`);
  check((await page.locator("#rooms2-work").textContent()).includes("美术候选（未确认"), "the v2 room page says which drawn art is unconfirmed");

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
  await page.reload(); await page.waitForTimeout(300);
  check((await page.locator("#drafts-flag").textContent()).includes("1"), "draft survives a page reload");
  await page.goto(URL + "#export"); await page.waitForTimeout(200);
  const [dl] = await Promise.all([page.waitForEvent("download"), page.click("text=下载修改文件")]);
  const edits = JSON.parse(fs.readFileSync(await dl.path(), "utf8"));
  check(edits.format === "pushbox.art-edits/1" && edits.edits[0].id === "obj.crate_wood" && edits.edits[0].frames[0][8].includes("A"), "export produces a pushbox.art-edits/1 file containing the edit");
  page.once("dialog", (d) => d.accept());
  await page.click("#export-root button.danger"); await page.waitForTimeout(200);
  check(!(await page.locator("#drafts-flag").isVisible()), "discarding the draft clears the flag");

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

  // 7. Narrow window: no horizontal page scroll, navigation still reachable.
  await page.setViewportSize({ width: 390, height: 800 });
  for (const h of ["#overview", "#modes/water", "#mechanisms/acid", "#catalog/cargo", "#catalog/slices", "#maps/5/1", "#maps/t/dungeon_well", "#rooms2/pool/3", "#rooms2/diyu_fengdu", "#scenes", "#assets/char.miner", "#review"]) {
    await page.goto(URL + h); await page.waitForTimeout(250);
    const overflow = await page.evaluate(() => document.documentElement.scrollWidth - window.innerWidth);
    check(overflow <= 0, `${h} at 390px has no horizontal page scroll (${overflow}px)`);
  }
  await browser.close();
  console.log(failures.length ? `\n${failures.length} check(s) failed` : "\nall workbench checks passed");
  process.exit(failures.length ? 1 : 0);
})().catch((e) => { console.error(e); process.exit(1); });
