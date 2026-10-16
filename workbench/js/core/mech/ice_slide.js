/* Game-layer rule: a horizontally pushed crate slides while its foot is ice.
 * It may leave the ice onto the first dry tile, then stops; people do not slide.
 * Uses the shared action/done hooks so one push is one move/undo/gust phase. */
(function (root) {
  'use strict';
  const TM = root.PB.tilemodel;
  TM.register({
    id: 'ice_slide',
    act(L, s, action) {
      if (action !== 'L' && action !== 'R') return null;
      const dx = action === 'R' ? 1 : -1, p = s.player, c = TM.crateAt(s, p.x + dx, p.y);
      if (!c || !TM.free(L, s, c.x + dx, c.y) || TM.terrainAt(L, s, c.x + dx, c.y + 1) !== TM.T.ICE) return null;
      const enter = () => {
        const into = c.y * L.w + c.x + dx;
        if (s.terrain[into] === TM.T.WATER && !TM.displace(L, s, into)) return false;
        c.x += dx; return true;
      };
      const oldX = c.x;
      if (!enter()) return { ok: false, reason: 'blocked' };
      p.x = oldX;
      while (TM.terrainAt(L, s, c.x, c.y + 1) === TM.T.ICE && TM.free(L, s, c.x + dx, c.y)) if (!enter()) break;
      return TM.done(L, s, 'push');
    },
  });
})(typeof window !== 'undefined' ? window : globalThis);
