const APPEARANCE_KEY = "pushbox-art-lab-theme";
const appearanceOptions = ["light", "dark", "system"];
const systemAppearance = window.matchMedia("(prefers-color-scheme: dark)");
let appearancePreference = "system";
try {
  const saved = localStorage.getItem(APPEARANCE_KEY);
  if (appearanceOptions.includes(saved)) appearancePreference = saved;
} catch (_) { /* Local file storage may be unavailable. Keep the page usable. */ }
function applyAppearance() {
  const resolved = appearancePreference === "system"
    ? (systemAppearance.matches ? "dark" : "light") : appearancePreference;
  document.documentElement.dataset.theme = resolved;
  document.documentElement.style.colorScheme = resolved;
  const control = document.getElementById("themeSelect");
  if (control) control.value = appearancePreference;
}
function setTheme(value) {
  appearancePreference = appearanceOptions.includes(value) ? value : "system";
  try { localStorage.setItem(APPEARANCE_KEY, appearancePreference); } catch (_) {}
  applyAppearance();
}
applyAppearance();
systemAppearance.addEventListener("change", applyAppearance);
document.addEventListener("DOMContentLoaded", applyAppearance);
