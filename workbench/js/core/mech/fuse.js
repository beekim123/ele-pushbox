/* LV-02: connectivity-only fuse model. A blast ignites every fuse tile in its
 * cross; each ignited tile burns once and creates a separate cross-shaped blast.
 * This predicts the final logical reach, NOT heat propagation, cell destruction,
 * burn duration or the 480-tick phase. Those remain explicit SDK checks. */
(function (root) {
  'use strict';
  const TM = root.PB.tilemodel;
  const OFFSETS = [[0, 0], [1, 0], [-1, 0], [0, 1], [0, -1]];
  TM.register({
    id: 'fuse',
    explode(L, s, cells, events) {
      const queue = [], reached = new Set();
      function ignite(affected) {
        for (const [x, y] of affected) {
          const i = y * L.w + x;
          if (s.terrain[i] !== TM.T.FUSE || reached.has(i)) continue;
          reached.add(i); queue.push([x, y]);
        }
      }
      ignite(cells);
      for (let head = 0; head < queue.length; head++) {
        const [x, y] = queue[head];
        s.terrain[y * L.w + x] = TM.T.EMPTY;
        const affected = OFFSETS.map(([dx, dy]) => [x + dx, y + dy]).filter(([tx, ty]) => TM.inside(L, tx, ty));
        ignite(affected);
        for (const [tx, ty] of affected) {
          const i = ty * L.w + tx, t = s.terrain[i];
          if (t === TM.T.CRACKED || t === TM.T.EARTH || t === TM.T.SAND) s.terrain[i] = TM.T.EMPTY;
        }
        // A burned fuse creates an independent explosion, so a nested crate may
        // lose one layer per fuse blast. Never recurse into this fuse hook.
        for (const p of TM.plugins) if (p.id !== 'fuse' && typeof p.explode === 'function') p.explode(L, s, affected, events);
        events.push('fuse-burst');
      }
    },
  });
})(typeof window !== 'undefined' ? window : globalThis);
