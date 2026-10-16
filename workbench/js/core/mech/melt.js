/* Tile-level terminal approximation of heat -> ice/water SDK coupling. The normal
 * water model subsequently handles gravity, flow and collection-bin latching. */
(function (root) {
  'use strict';
  const TM = root.PB.tilemodel;
  TM.register({
    id: 'melt', device: 'heat_vent', init: () => 0,
    settle(L, s, events) {
      let changed = false;
      L.devices.forEach((d, k) => {
        if (d.type !== 'heat_vent' || !s.dev[k]) return;
        s.dev[k] = 0; changed = true;
        const [ax, ay, w, h] = d.area;
        for (let y = ay; y < ay + h; y++) for (let x = ax; x < ax + w; x++) if (TM.inside(L, x, y) && s.terrain[y * L.w + x] === TM.T.ICE) s.terrain[y * L.w + x] = TM.T.WATER;
        events.push('melt-approximation');
      });
      return changed;
    },
  });
})(typeof window !== 'undefined' ? window : globalThis);
