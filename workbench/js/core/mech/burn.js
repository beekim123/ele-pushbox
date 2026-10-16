/* LV-04 design approximation: the torch's SDK temperature circle seeds a connected
 * wood component, whose eventual burned-out state is predicted. This does not
 * simulate burning ticks, cell survival, heat diffusion or phase duration. */
(function (root) {
  'use strict';
  const TM = root.PB.tilemodel;
  function heatedCells(x, y, area) {
    const [ax, ay, w, h] = area, cx = 16 * ax + 8 * w, cy = 16 * ay + 8 * h, r = 8 * Math.min(w, h);
    let count = 0;
    for (let py = 16 * y; py < 16 * (y + 1); py++) for (let px = 16 * x; px < 16 * (x + 1); px++) if ((px - cx) ** 2 + (py - cy) ** 2 <= r * r) count++;
    return count;
  }
  TM.register({
    id: 'burn', device: 'torch', init: () => 0,
    settle(L, s, events) {
      let changed = false;
      L.devices.forEach((d, k) => {
        if (d.type !== 'torch' || !s.dev[k]) return;
        s.dev[k] = 0; changed = true;
        // wood.ignite_temp=4584 SDK encoded units (8/K); 600 is too cold.
        if (!(d.temperature >= 4584) || !d.area) return;
        const pending = [];
        for (let y = 0; y < L.h; y++) for (let x = 0; x < L.w; x++) {
          const i = y * L.w + x;
          if (s.terrain[i] === TM.T.WOOD && heatedCells(x, y, d.area) >= 128) pending.push(i);
        }
        const seen = new Set();
        while (pending.length) {
          const i = pending.pop();
          if (seen.has(i) || s.terrain[i] !== TM.T.WOOD) continue;
          seen.add(i); s.terrain[i] = TM.T.EMPTY;
          const x = i % L.w, y = (i / L.w) | 0;
          for (const [dx, dy] of [[1, 0], [-1, 0], [0, 1], [0, -1]]) if (TM.inside(L, x + dx, y + dy)) pending.push((y + dy) * L.w + x + dx);
        }
        if (seen.size) events.push('burn-approximation');
      });
      return changed;
    },
  });
})(typeof window !== 'undefined' ? window : globalThis);
