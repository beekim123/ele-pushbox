/* Game-layer gust, after ordinary gravity/flow. dev[k] is the turn phase modulo
 * period, so state keys and clone-based undo preserve future gust timing.
 * No parse/settle hook: repeated static rounds cannot create extra gusts. */
(function (root) {
  'use strict';
  const TM = root.PB.tilemodel;
  const DIR = { L: [-1, 0], R: [1, 0], U: [0, -1], D: [0, 1] };
  TM.register({
    id: 'gust', device: 'gust', init: () => 0,
    afterAction(L, s, kind, events) {
      let moved = false;
      L.devices.forEach((d, k) => {
        if (d.type !== 'gust') return;
        const period = Math.max(1, d.period | 0), phase = d.phase | 0;
        s.dev[k] = (s.dev[k] + 1) % period;
        if ((s.dev[k] + phase) % period !== 0) return;
        const [ax, ay, w, h] = d.area, [dx, dy] = DIR[d.direction] || [0, 0];
        const kinds = d.light_kinds || ['wood'];
        // Eligibility reads the pre-gust occupancy; this does not push crate chains.
        const plans = s.crates.filter(c => c.x >= ax && c.x < ax + w && c.y >= ay && c.y < ay + h && kinds.includes(c.kind) && TM.free(L, s, c.x + dx, c.y + dy));
        for (const c of plans) {
          const x = c.x + dx, y = c.y + dy, into = y * L.w + x;
          if (s.terrain[into] === TM.T.WATER && !TM.displace(L, s, into)) continue;
          c.x = x; c.y = y; moved = true; events.push('gust');
        }
      });
      return moved;
    },
  });
})(typeof window !== 'undefined' ? window : globalThis);
