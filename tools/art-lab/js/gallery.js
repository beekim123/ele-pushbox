function updateCategoryCounts() {
  const counts = { all: 0, character: 0, monster: 0, prop: 0, plant_mech: 0, terrain: 0, ui: 0, map: 0 };
  ASSET_CATALOG.forEach(item => {
    if (currentBiomeFilter === "all" || item.biome === "all" || item.biome === currentBiomeFilter) {
      counts.all++;
      counts[item.category] = (counts[item.category] || 0) + 1;
    }
  });
  for (const [k, v] of Object.entries(counts)) {
    const el = document.getElementById("cnt-" + k);
    if (el) el.textContent = v;
  }
}

function renderGallery() {
  updateCategoryCounts();
  const query = document.getElementById("searchInput").value.trim().toLowerCase();
  const container = document.getElementById("galleryContainer");
  container.innerHTML = "";
  container.classList.toggle("single-category", currentCategory !== "all");
  document.getElementById("galleryTitle").textContent = CATEGORY_TITLES[currentCategory][0];
  let resultCount = 0;

  const categoriesToShow = currentCategory === "all"
    ? ["character", "monster", "prop", "plant_mech", "terrain", "ui", "map"]
    : [currentCategory];

  categoriesToShow.forEach(catKey => {
    const items = ASSET_CATALOG.filter(item => {
      if (item.category !== catKey) return false;
      if (currentBiomeFilter !== "all" && item.biome !== "all" && item.biome !== currentBiomeFilter) return false;
      if (query && !item.name.toLowerCase().includes(query) && !item.id.toLowerCase().includes(query) && !item.desc.toLowerCase().includes(query)) return false;
      return true;
    });
    if (items.length === 0) return;
    resultCount += items.length;

    const section = document.createElement("section");
    const [title, subtitle] = CATEGORY_TITLES[catKey];
    section.innerHTML = `
      <div class="category-banner">
        <div><h2>${title}</h2><p>${subtitle}</p></div>
        <span class="section-count">${items.length} 项</span>
      </div>
    `;
    const grid = document.createElement("div");
    grid.className = "asset-grid" + ((catKey === "map" || catKey === "ui") ? " wide-cards" : "");

    items.forEach(item => {
      const card = document.createElement("div");
      card.className = "asset-card" + (selectedAsset && selectedAsset.id === item.id ? " selected" : "");
      card.onclick = () => selectAssetForInspector(item);
      card.tabIndex = 0;
      card.setAttribute("role", "button");
      card.setAttribute("aria-label", `检视：${item.name}`);
      card.setAttribute("aria-pressed", String(selectedAsset && selectedAsset.id === item.id));
      card.onkeydown = event => {
        if (event.key === "Enter" || event.key === " ") {
          event.preventDefault();
          selectAssetForInspector(item);
        }
      };

      const isWide = !!item.wide;
      const cw = isWide ? 320 : (item.frames[0][0].length * globalScale);
      const ch = isWide ? 180 : (item.frames[0].length * globalScale);
      const sizeStr = isWide ? "320×180 px" : `${item.frames[0][0].length}×${item.frames[0].length} px`;
      const fpsStr = isWide ? "实时预演" : `${item.frames.length}f · ${item.fps} fps`;

      card.innerHTML = `
        <div class="card-stage ${stageBgClass}">
          <span class="card-tag-top">${sizeStr}</span>
          <span class="card-tag-fps">${fpsStr}</span>
          <canvas class="pixel-canvas" data-asset-id="${item.id}" width="${cw}" height="${ch}" style="width:${cw}px;height:${ch}px;"></canvas>
        </div>
        <div class="card-meta">
          <div class="card-title"><span>${item.name.replace(/\s*[（(][^）)]*[）)]/g, "")}</span></div>
          <div class="card-id">${item.id}</div>
        </div>
      `;
      grid.appendChild(card);
    });

    section.appendChild(grid);
    container.appendChild(section);
  });
  document.getElementById("galleryCount").textContent = `${resultCount} 项素材`;
  if (resultCount === 0) {
    container.innerHTML = '<div class="gallery-empty"><h2>没有找到素材</h2><p>试试其他关键词，或清除当前分类与主题筛选。</p><button class="btn-outline" data-action="clear-filters">清除筛选</button></div>';
  }
}

function clearFilters() {
  currentCategory = "all";
  currentBiomeFilter = "all";
  document.getElementById("searchInput").value = "";
  document.querySelectorAll(".cat-btn").forEach(btn => {
    const active = btn.dataset.cat === "all";
    btn.classList.toggle("active", active);
    btn.setAttribute("aria-pressed", String(active));
  });
  document.querySelectorAll(".biome-chip").forEach(btn => {
    const active = btn.dataset.biome === "all";
    btn.classList.toggle("active", active);
    btn.setAttribute("aria-pressed", String(active));
  });
  renderGallery();
}
