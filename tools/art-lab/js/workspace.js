const inspectorMedia = window.matchMedia("(max-width: 1100px)");
const inspectorPanel = document.getElementById("inspectorPanel");
let inspectorReturnFocus = null;
function syncInspectorLayout() {
  const open = inspectorMedia.matches && document.documentElement.dataset.inspectorOpen === "true";
  const hidden = inspectorMedia.matches && !open;
  inspectorPanel.inert = hidden;
  inspectorPanel.setAttribute("role", open ? "dialog" : "complementary");
  if (open) inspectorPanel.setAttribute("aria-modal", "true");
  else inspectorPanel.removeAttribute("aria-modal");
  if (hidden) inspectorPanel.setAttribute("aria-hidden", "true");
  else inspectorPanel.removeAttribute("aria-hidden");
  document.getElementById("inspectorScrim").hidden = !open;
  document.getElementById("inspectorToggle").setAttribute("aria-expanded", String(open));
  ["appHeader", "categoryNav", "galleryMain"].forEach(id => { document.getElementById(id).inert = open; });
}
function setInspectorOpen(open) {
  if (open && !inspectorMedia.matches) return;
  if (open && document.documentElement.dataset.inspectorOpen === "true") return;
  if (open) inspectorReturnFocus = document.activeElement;
  document.documentElement.dataset.inspectorOpen = String(open);
  syncInspectorLayout();
  if (open) document.getElementById("closeInspectorBtn").focus();
  else if (inspectorReturnFocus && inspectorReturnFocus.isConnected) inspectorReturnFocus.focus();
}
inspectorMedia.addEventListener("change", () => {
  document.documentElement.dataset.inspectorOpen = "false";
  syncInspectorLayout();
});
document.addEventListener("keydown", event => {
  if (!inspectorMedia.matches || document.documentElement.dataset.inspectorOpen !== "true") return;
  if(event.target && !inspectorPanel.contains(event.target))return;
  if (event.key === "Escape") { event.preventDefault(); setInspectorOpen(false); }
  if (event.key === "Tab") {
    const controls = [...inspectorPanel.querySelectorAll('button:not([disabled]), textarea, [tabindex="0"], summary')].filter(el => el.getClientRects().length);
    const first = controls[0], last = controls[controls.length - 1];
    if (event.shiftKey && document.activeElement === first) { event.preventDefault(); last.focus(); }
    else if (!event.shiftKey && document.activeElement === last) { event.preventDefault(); first.focus(); }
  }
});
syncInspectorLayout();
