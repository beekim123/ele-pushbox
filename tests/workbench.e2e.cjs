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
  for (const h of ["#scenes", "#scenes/level.M04", "#scenes/ui.screen.chapters", "#scenes/lobby.forest", "#scenes/showcase.cosmos", "#assets", "#assets/mech.door", "#edit/obj.crate_wood", "#review", "#export"]) {
    await page.goto(URL + h); await page.waitForTimeout(250);
  }
  check(errors.length === 0, "all views load without console errors" + (errors.length ? ": " + errors[0] : ""));

  // 2. Browser rendering equals the exported PNGs (same core code, integer pixels).
  await page.goto(URL + "#scenes");
  for (const [name, file, expr] of [
    ["showcase", "art/export/reference/showcase.dungeon.png", "(() => { const r = new PB.Raster(320,180); PB.scene.renderLevel(r, PB.scene.SHOWCASE, null, {tick:0}); return Array.from(r.data); })()"],
    ["level M06", "art/export/reference/level.M06.png", "(() => { const r = new PB.Raster(320,180); PB.scene.renderLevel(r, PBStore.level('M06'), null, {tick:0}); return Array.from(r.data); })()"],
    ["miner sheet", "art/export/preview/char.miner.png", "(() => { const a = PBStore.asset('char.miner'); const r = new PB.Raster(a.size[0]*a.frames.length, a.size[1]); a.frames.forEach((f,i)=>r.blitRows(f,i*a.size[0],0,false)); return Array.from(r.data); })()"],
  ]) {
    const got = await page.evaluate(expr);
    const want = await decode(file);
    let diff = 0; for (let i = 0; i < want.data.length; i++) if (want.data[i] !== got[i]) diff++;
    check(got.length === want.data.length && diff === 0, `${name}: browser render matches ${file} (${diff} differing bytes)`);
  }

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

  // 5. Review selection produces exact asset@version#hash text.
  await page.goto(URL + "#review"); await page.waitForTimeout(200);
  await page.check('input[aria-label="通过 木箱"]');
  const text = await page.locator('textarea[aria-label="确认文字"]').inputValue();
  const v = await page.evaluate(() => { const a = PBStore.asset("obj.crate_wood"); return `obj.crate_wood@v${a.version} #${a.content_hash.slice(0, 12)}`; });
  check(text.includes(v), "review text lists the exact version and hash");

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
  for (const h of ["#scenes", "#assets/char.miner", "#review"]) {
    await page.goto(URL + h); await page.waitForTimeout(250);
    const overflow = await page.evaluate(() => document.documentElement.scrollWidth - window.innerWidth);
    check(overflow <= 0, `${h} at 390px has no horizontal page scroll (${overflow}px)`);
  }
  await browser.close();
  console.log(failures.length ? `\n${failures.length} check(s) failed` : "\nall workbench checks passed");
  process.exit(failures.length ? 1 : 0);
})().catch((e) => { console.error(e); process.exit(1); });
