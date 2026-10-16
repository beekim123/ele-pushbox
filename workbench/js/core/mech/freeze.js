/* Device pulse only: tile-level terminal approximation of the frost SDK coupler.
 * Marker/background layers are retained; no thermal phase_up or natural melt. */
(function (root) {
  'use strict';
  const TM = root.PB.tilemodel;
  TM.register({
    id: 'freeze', device: 'frost_vent', init: () => 0,
    settle(L, s, events) {
      let changed = false;
      L.devices.forEach((d, k) => {
        if (d.type !== 'frost_vent' || !s.dev[k]) return;
        s.dev[k] = 0; changed = true;
        const [ax, ay, w, h] = d.area;
        for (let y = ay; y < ay + h; y++) for (let x = ax; x < ax + w; x++) if (TM.inside(L, x, y) && s.terrain[y * L.w + x] === TM.T.WATER) s.terrain[y * L.w + x] = TM.T.ICE;
        events.push('freeze-approximation');
      });
      return changed;
    },
  });
})(typeof window !== 'undefined' ? window : globalThis);
