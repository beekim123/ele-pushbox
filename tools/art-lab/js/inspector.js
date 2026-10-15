const inspCanvas = document.getElementById("inspCanvas");
const inspCtx = inspCanvas.getContext("2d");

function initInspectorPalette() {
  const bar = document.getElementById("inspPaletteBar");
  const codes = [".", ...Object.keys(PALETTE)];
  codes.forEach(code => {
    const btn = document.createElement("button");
    btn.type = "button";
    btn.className = "swatch-btn" + (code === activePaintCode ? " active" : "");
    btn.style.background = code === "."
      ? "repeating-conic-gradient(#333 0% 25%, #111 0% 50%) 50% / 6px 6px"
      : PALETTE[code];
    btn.title = code === "." ? "透明橡皮擦 (.)" : `色码 '${code}' (${PALETTE[code]})`;
    btn.setAttribute("aria-label", btn.title);
    btn.setAttribute("aria-pressed", String(code === activePaintCode));
    btn.onclick = () => {
      activePaintCode = code;
      document.querySelectorAll(".swatch-btn").forEach(b => {
        b.classList.remove("active");
        b.setAttribute("aria-pressed", "false");
      });
      btn.classList.add("active");
      btn.setAttribute("aria-pressed", "true");
    };
    bar.appendChild(btn);
  });

  inspCanvas.addEventListener("mousedown", (e) => paintOnInspectorCanvas(e));
  inspCanvas.addEventListener("mousemove", (e) => { if (e.buttons === 1) paintOnInspectorCanvas(e); });
}

function paintOnInspectorCanvas(e) {
  if (!selectedAsset || selectedAsset.wide) return;
  const rows = selectedAsset.frames[selectedFrameIdx % selectedAsset.frames.length];
  const h = rows.length, w = rows[0].length;
  const rect = inspCanvas.getBoundingClientRect();
  const gx = Math.floor(((e.clientX - rect.left) / rect.width) * w);
  const gy = Math.floor(((e.clientY - rect.top) / rect.height) * h);
  if (gx >= 0 && gx < w && gy >= 0 && gy < h) {
    const arr = rows[gy].split("");
    if(arr[gx]===activePaintCode)return;
    arr[gx] = activePaintCode;
    rows[gy] = arr.join("");
    campPreviewState.revision++;
    updateInspectorCode();
  }
}

function selectAssetForInspector(item, reveal = true) {
  selectedAsset = item;
  delete inspCanvas.dataset.uiFrameKey;
  selectedFrameIdx = 0;
  document.querySelectorAll(".asset-card").forEach(el => {
    const c = el.querySelector("canvas");
    const selected = !!c && c.dataset.assetId === item.id;
    el.classList.toggle("selected", selected);
    el.setAttribute("aria-pressed", String(selected));
  });

  document.getElementById("inspTitle").textContent = item.name;
  document.getElementById("inspId").textContent = item.id;
  document.getElementById("specCat").textContent = CATEGORY_TITLES[item.category][0];
  document.getElementById("specBiome").textContent = BIOME_NAMES[item.biome];
  document.getElementById("specSize").textContent = item.wide ? "320 × 180 px" : `${item.frames[0][0].length} × ${item.frames[0].length} px`;
  const isUI=!!item.renderType && item.renderType.startsWith("ui_");
  document.getElementById("specFps").textContent = isUI ? "8 FPS 生态动画" : item.wide ? "60 Hz 实时推演" : `${item.frames.length} 帧 / ${item.fps} FPS`;
  document.getElementById("specDesc").textContent = item.desc;
  document.getElementById("paletteSection").style.display = item.wide ? "none" : "block";
  document.getElementById("frameSection").hidden = !!item.wide;
  document.getElementById("inspHintText").textContent = isUI
    ? "放大预演可试选入口、主题和关卡；进度为独立样例。"
    : item.wide
    ? "320 × 180 原生场景 · 随全局动画播放。"
    : "暂停动画后，可选择色板并点击像素修改。";
  document.getElementById("copyStatus").textContent = "";
  syncCampInspector(item);

  // 渲染动作帧缩略条
  const strip = document.getElementById("inspFrameStrip");
  strip.innerHTML = "";
  if (!item.wide && item.frames) {
    item.frames.forEach((rows, idx) => {
      const fDiv = document.createElement("button");
      fDiv.type = "button";
      fDiv.className = "frame-thumb" + (idx === selectedFrameIdx ? " active" : "");
      fDiv.setAttribute("aria-label", `选择第 ${idx + 1} 帧`);
      fDiv.setAttribute("aria-pressed", String(idx === selectedFrameIdx));
      const fc = document.createElement("canvas");
      fc.className = "pixel-canvas";
      fc.width = rows[0].length * 3;
      fc.height = rows.length * 3;
      drawMatrixOnCtx(fc.getContext("2d"), rows, 0, 0, 3);
      fDiv.appendChild(fc);
      const lbl = document.createElement("span");
      lbl.textContent = String(idx + 1).padStart(2, "0");
      fDiv.appendChild(lbl);
      fDiv.onclick = () => {
        selectedFrameIdx = idx;
        document.querySelectorAll(".frame-thumb").forEach((el, i) => {
          el.classList.toggle("active", i === idx);
          el.setAttribute("aria-pressed", String(i === idx));
        });
      };
      strip.appendChild(fDiv);
    });
  }
  updateInspectorCode();
  if (reveal) setInspectorOpen(true);
}

function updateInspectorCode() {
  const box = document.getElementById("inspCodeBox");
  if (!selectedAsset) return;
  if (selectedAsset.wide) {
    if (selectedAsset.renderType === "map") {
      box.value = JSON.stringify({
        id: selectedAsset.id,
        biome: selectedAsset.biome,
        map: BIOME_MAPS[selectedAsset.biomeIdx]
      }, null, 2);
    } else {
      box.value = JSON.stringify(campExport(selectedAsset.renderType), null, 2);
    }
    return;
  }
  let code = `# GDScript Pixel Matrix (${selectedAsset.id})\n`;
  selectedAsset.frames.forEach((rows, idx) => {
    code += `"${selectedAsset.id}_${idx}": [\n`;
    rows.forEach(r => { code += `\t"${r}",\n`; });
    code += `],\n`;
  });
  box.value = code;
}

function resetSelectedAsset() {
  if (!selectedAsset || selectedAsset.wide) return;
  const orig = BACKUP_CATALOG.find(a => a.id === selectedAsset.id);
  if (orig) {
    selectedAsset.frames = JSON.parse(JSON.stringify(orig.frames));
    campPreviewState.revision++;
    selectAssetForInspector(selectedAsset);
  }
}

async function copyInspectorCode() {
  const box = document.getElementById("inspCodeBox");
  const status = document.getElementById("copyStatus");
  try {
    await navigator.clipboard.writeText(box.value);
    status.textContent = "已复制资产数据";
  } catch (_) {
    document.querySelector(".code-disclosure").open = true;
    box.focus();
    box.select();
    status.textContent = "无法自动复制，已选中数据，请按 ⌘C / Ctrl+C。";
  }
}
