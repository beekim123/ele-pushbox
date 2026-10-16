/* SDK radius=20, ignition radius=10: the centre tile and orthogonal adjacent
 * tiles intersect the ignition inner circle; diagonal tiles do not (sqrt(128)>10).
 * Predicts eventual connected-wood burnout, not actual SDK ignition/survival. */
(function (root) {
  'use strict';
  const TM = root.PB.tilemodel;
  TM.register({
    id: 'blast_ignite',
    explode(L, s, cells, events) {
      const pending = cells.map(([x, y]) => y * L.w + x), seen = new Set();
      while (pending.length) {
        const i = pending.pop();
        if (seen.has(i) || s.terrain[i] !== TM.T.WOOD) continue;
        seen.add(i); s.terrain[i] = TM.T.EMPTY;
        const x = i % L.w, y = (i / L.w) | 0;
        for (const [dx, dy] of [[1, 0], [-1, 0], [0, 1], [0, -1]]) if (TM.inside(L, x + dx, y + dy)) pending.push((y + dy) * L.w + x + dx);
      }
      if (seen.size) events.push('blast-ignite-approximation');
    },
  });
})(typeof window !== 'undefined' ? window : globalThis);
