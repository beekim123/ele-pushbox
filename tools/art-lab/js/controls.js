function selectCategory(cat) {
  currentCategory = cat;
  document.querySelectorAll(".cat-btn").forEach(btn => {
    btn.classList.toggle("active", btn.dataset.cat === cat);
    btn.setAttribute("aria-pressed", String(btn.dataset.cat === cat));
  });
  renderGallery();
}

function selectBiomeFilter(biome, btnEl) {
  currentBiomeFilter = biome;
  document.querySelectorAll(".biome-chip").forEach(b => {
    b.classList.remove("active");
    b.setAttribute("aria-pressed", "false");
  });
  btnEl.classList.add("active");
  btnEl.setAttribute("aria-pressed", "true");
  renderGallery();
}

function setStageBg(bgClass, btnEl) {
  stageBgClass = bgClass;
  btnEl.parentElement.querySelectorAll(".control-pill").forEach(b => {
    b.classList.remove("active");
    b.setAttribute("aria-pressed", "false");
  });
  btnEl.classList.add("active");
  btnEl.setAttribute("aria-pressed", "true");
  document.getElementById("inspStageBox").className = "inspector-preview-box " + bgClass;
  renderGallery();
}

function setGlobalScale(s, btnEl) {
  globalScale = s;
  btnEl.parentElement.querySelectorAll(".control-pill").forEach(b => {
    b.classList.remove("active");
    b.setAttribute("aria-pressed", "false");
  });
  btnEl.classList.add("active");
  btnEl.setAttribute("aria-pressed", "true");
  renderGallery();
}

function togglePlay() {
  isPlaying = !isPlaying;
  document.getElementById("playPauseBtn").textContent = isPlaying ? "暂停动画" : "播放动画";
  document.getElementById("playPauseBtn").setAttribute("aria-pressed", String(isPlaying));
}
