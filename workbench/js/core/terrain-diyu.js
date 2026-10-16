/* Background for the 地府·酆都 region (theme.diyu, delivery mode; docs/design/delivery-diyu.md).
 * A night sky that brightens to a sickly teal glow at the horizon, with the
 * ghost city in silhouette in front of it: a crenellated wall, a gate tower
 * with upturned eaves and a pagoda, plus a few dim lantern windows. Like every
 * backdrop it stays darker than the terrain and holds nothing shaped like an
 * interactive object (art-direction.md §5).
 * Wraps PB.terrain.drawBackground for background.style "diyu" only, so the
 * approved themes' renderer (terrain.js) stays unchanged. "time" is in 1/60 s ticks. */
(function (root) {
  "use strict";
  const PB = (root.PB = root.PB || {});
  const T = PB.terrain;
  if (!T || T.diyu) return;   // loaded twice: keep the first wrapper
  const h32 = PB.h32, base = T.drawBackground;
  const BAYER = [0, 8, 2, 10, 12, 4, 14, 6, 3, 11, 1, 9, 15, 7, 13, 5];

  function drawBackground(r, theme, x0, y0, w, h, time) {
    if (!theme.background || theme.background.style !== "diyu") return base(r, theme, x0, y0, w, h, time);
    const B = theme.background, x1 = x0 + w, y1 = y0 + h, t = time | 0;
    const px = (x, y, c) => { if (x >= x0 && y >= y0 && x < x1 && y < y1) r.set(x, y, c); };
    const horizon = y0 + Math.round(h * 0.5);
    // Sky: base[0] at the top, base[1] lower down, the accent glow just above the horizon.
    for (let y = y0; y < y1; y++) {
      const level = Math.floor(((y - y0) * 16) / Math.max(1, horizon - y0));
      for (let x = x0; x < x1; x++) {
        const b = BAYER[(y & 3) * 4 + (x & 3)];
        let c = level < 4 ? B.base[0] : level < 9 ? (b < (level - 4) * 3 ? B.base[1] : B.base[0]) : level < 11 ? B.base[1] : b < (level - 10) * 3 ? B.accent : B.base[1];
        if (y >= horizon) c = B.accent;
        if (y < horizon - 20 && h32(x >> 1, y >> 1, 411) % 97 === 0) c = B.base[1];
        px(x, y, c);
      }
    }
    // Far ridge (Mount Mingshan) between sky and glow.
    for (let x = x0; x < x1; x++) {
      const ridge = horizon - 9 - Math.round(5 * Math.sin((x - x0) / 23) + 3 * Math.sin((x - x0) / 9 + 1.3)) - (h32(x >> 2, 0, 413) % 2);
      for (let y = ridge; y < horizon + 2; y++) px(x, y, B.base[1]);
    }
    // City wall with merlons across the whole width.
    const wallTop = horizon + 4;
    for (let x = x0; x < x1; x++) {
      const merlon = ((x - x0) % 8) < 5;
      for (let y = wallTop - (merlon ? 3 : 0); y < y1; y++) px(x, y, B.detail);
    }
    // Gate towers and pagodas every 160 px, offset so a 320 px screen shows one of each.
    for (let gx = x0 + 70; gx < x1 + 60; gx += 160) tower(px, B, gx, wallTop, t);
    for (let gx = x0 + 230; gx < x1 + 40; gx += 160) pagoda(px, B, gx, wallTop, t);
    // Distant lanterns along the wall top: dim, slowly flickering.
    for (let i = 0, n = Math.max(1, (w / 26) | 0); i < n; i++) {
      const lx = x0 + 9 + i * 26 + (h32(i, 1, 417) % 9), on = ((t >> 5) + i * 3) % 11 !== 0;
      if (on) { px(lx, wallTop + 3, B.speck); px(lx, wallTop + 4, B.speck); }
    }
  }
  // Two-storey gate tower with upturned eaves, centred on cx, standing on the wall top.
  function tower(px, B, cx, wallTop, t) {
    const D = B.detail;
    const body = (y0, y1, half) => { for (let y = y0; y < y1; y++) for (let k = -half; k <= half; k++) px(cx + k, y, D); };
    const roof = (y, half) => {   // eave line with upturned tips, then a short slope
      for (let k = -half; k <= half; k++) px(cx + k, y, D);
      px(cx - half - 1, y - 1, D); px(cx + half + 1, y - 1, D); px(cx - half - 2, y - 2, D); px(cx + half + 2, y - 2, D);
      for (let d = 1; d <= 3; d++) for (let k = -half + d * 2; k <= half - d * 2; k++) px(cx + k, y - d, D);
    };
    body(wallTop - 12, wallTop, 17);
    roof(wallTop - 13, 21);
    body(wallTop - 24, wallTop - 16, 12);
    roof(wallTop - 25, 16);
    px(cx, wallTop - 29, D); px(cx, wallTop - 30, D);
    // Windows: dim lantern light, one of them flickers.
    for (const [wx, wy, fl] of [[-9, -8, 0], [-3, -8, 1], [3, -8, 0], [9, -8, 0], [-5, -21, 0], [5, -21, 1]]) {
      if (fl && ((t >> 4) % 7) === 0) continue;
      px(cx + wx, wallTop + wy, B.speck); px(cx + wx + 1, wallTop + wy, B.speck); px(cx + wx, wallTop + wy + 1, B.speck); px(cx + wx + 1, wallTop + wy + 1, B.speck);
    }
  }
  // Five-tier pagoda, centred on cx.
  function pagoda(px, B, cx, wallTop, t) {
    const D = B.detail;
    let y = wallTop, half = 6;
    for (let tier = 0; tier < 5; tier++) {
      for (let d = 0; d < 6; d++) for (let k = -half + 2; k <= half - 2; k++) px(cx + k, y - d, D);
      y -= 6;
      for (let k = -half - 1; k <= half + 1; k++) px(cx + k, y, D);
      px(cx - half - 2, y - 1, D); px(cx + half + 2, y - 1, D);
      if (tier < 4 && ((t >> 5) + tier) % 9 !== 0) px(cx, y + 3, B.speck);
      half -= 1;
    }
    for (let d = 1; d <= 5; d++) px(cx, y - d, D);
  }

  T.drawBackground = drawBackground;
  T.diyu = { tower, pagoda };
})(typeof window !== "undefined" ? window : globalThis);
