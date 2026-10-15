function animateLoop(now) {
  const dt = (now - lastTime) / 1000;
  lastTime = now;
  if (isPlaying) clock += dt;

  // 更新画廊中所有可见卡片的 Canvas
  if(!document.getElementById("assetLibrary").hidden)document.querySelectorAll("canvas[data-asset-id]").forEach(c => {
    const item = ASSET_CATALOG.find(a => a.id === c.dataset.assetId);
    if (!item) return;
    if(item.renderType && item.renderType.startsWith("ui_")) {
      const key=campFrameKey(item.renderType,clock);
      if(c.dataset.uiFrameKey===key)return;
      c.dataset.uiFrameKey=key;
    }
    const cx = c.getContext("2d");
    cx.clearRect(0, 0, c.width, c.height);
    if (item.wide) {
      if (item.renderType === "map") {
        renderLiveMapToCtx(cx, item.biomeIdx, clock);
      } else {
        renderUIPreviewToCtx(cx, item.renderType, clock);
      }
    } else {
      const fIdx = Math.floor(clock * item.fps) % item.frames.length;
      drawMatrixOnCtx(cx, item.frames[fIdx], 0, 0, globalScale);
    }
  });

  // 更新右侧检视器大图
  if (selectedAsset && !document.getElementById("assetLibrary").hidden) {
    if (selectedAsset.wide) {
      if(inspCanvas.width!==320 || inspCanvas.height!==180) {
        inspCanvas.width=320;inspCanvas.height=180;
        delete inspCanvas.dataset.uiFrameKey;
      }
      inspCanvas.style.width = "320px"; inspCanvas.style.height = "180px";
      if (selectedAsset.renderType === "map") {
        renderLiveMapToCtx(inspCtx, selectedAsset.biomeIdx, clock);
      } else {
        const key=campFrameKey(selectedAsset.renderType,clock);
        if(inspCanvas.dataset.uiFrameKey!==key) {
          renderUIPreviewToCtx(inspCtx, selectedAsset.renderType, clock);
          inspCanvas.dataset.uiFrameKey=key;
        }
      }
    } else {
      const fIdx = isPlaying ? (Math.floor(clock * selectedAsset.fps) % selectedAsset.frames.length) : selectedFrameIdx;
      const rows = selectedAsset.frames[fIdx];
      const w = rows[0].length, h = rows.length;
      const scale = Math.max(4, Math.floor(144 / Math.max(w, h)));
      inspCanvas.width = w * scale; inspCanvas.height = h * scale;
      inspCanvas.style.width = (w * scale) + "px"; inspCanvas.style.height = (h * scale) + "px";
      inspCtx.clearRect(0, 0, inspCanvas.width, inspCanvas.height);
      drawMatrixOnCtx(inspCtx, rows, 0, 0, scale);
    }
  }

  renderCampViewer(clock);
  renderCampShowcase(clock);
  requestAnimationFrame(animateLoop);
}

// Bind document controls here; dynamically created sprite controls live in
// gallery.js / inspector.js. Scripts are ordered in index.html for file:// use.
function bindControls() {
  initCampViewer();
  initCampShowcase();
  document.getElementById("searchInput").addEventListener("input", ()=>{
    setWorkbenchView("library");renderGallery();
  });
  document.getElementById("themeSelect").addEventListener("change", event => setTheme(event.target.value));
  document.querySelectorAll("[data-cat]").forEach(button => {
    button.addEventListener("click", () => selectCategory(button.dataset.cat));
  });
  document.querySelectorAll("[data-biome]").forEach(button => {
    button.addEventListener("click", () => selectBiomeFilter(button.dataset.biome, button));
  });
  document.querySelectorAll("[data-stage-bg]").forEach(button => {
    button.addEventListener("click", () => setStageBg(button.dataset.stageBg, button));
  });
  document.querySelectorAll("[data-scale]").forEach(button => {
    button.addEventListener("click", () => setGlobalScale(Number(button.dataset.scale), button));
  });
  document.querySelectorAll("[data-inspector]").forEach(button => {
    button.addEventListener("click", () => setInspectorOpen(button.dataset.inspector === "open"));
  });
  document.getElementById("playPauseBtn").addEventListener("click", togglePlay);
  document.getElementById("resetAssetBtn").addEventListener("click", resetSelectedAsset);
  document.getElementById("copyAssetBtn").addEventListener("click", copyInspectorCode);
  document.getElementById("galleryContainer").addEventListener("click", event => {
    if (event.target.closest('[data-action="clear-filters"]')) clearFilters();
  });
}

bindControls();
initInspectorPalette();
renderGallery();
selectAssetForInspector(ASSET_CATALOG[5], false);
requestAnimationFrame(animateLoop);
