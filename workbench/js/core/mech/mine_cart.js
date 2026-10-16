/* LV-02 mine cart. dev[k] is its index in the ordered horizontal track.
 * A side push sweeps every intervening deck/cargo position and follows the
 * original deck by one tile. The cart never starts because a wall is removed.
 * Track/cargo cell rewrites and real material safety checks belong to the SDK. */
(function (root) {
  'use strict';
  const TM = root.PB.tilemodel;
  TM.register({
    id: 'mine_cart',
    device: 'mine_cart',
    init(L, d) {
      if ((d.width || 1) !== 1 || !Array.isArray(d.track) || !d.track.length) throw new Error(L.id + ': mine_cart requires a width-1 track');
      const index = d.track.findIndex(([x, y]) => x === d.at[0] && y === d.at[1]);
      if (index < 0) throw new Error(L.id + ': mine_cart.at must lie on its track');
      for (let i = 1; i < d.track.length; i++) {
        const [x, y] = d.track[i], [px, py] = d.track[i - 1];
        if (y !== py || Math.abs(x - px) !== 1) throw new Error(L.id + ': mine_cart track must be adjacent and horizontal');
      }
      return index;
    },
    solid(L, s, x, y) {
      return L.devices.some((d, k) => d.type === 'mine_cart' && d.track[s.dev[k]][0] === x && d.track[s.dev[k]][1] === y);
    },
    act(L, s, action) {
      if (action !== 'L' && action !== 'R') return null;
      const dx = action === 'R' ? 1 : -1;
      for (let k = 0; k < L.devices.length; k++) {
        const d = L.devices[k];
        if (d.type !== 'mine_cart') continue;
        const [sx, sy] = d.track[s.dev[k]], p = s.player;
        if (p.y !== sy || p.x + dx !== sx) continue;
        const cargo = TM.crateAt(s, sx, sy - 1);
        let index = s.dev[k], lastX = sx;
        while (true) {
          const next = d.track.findIndex(([x, y]) => x === lastX + dx && y === sy);
          if (next < 0) break;
          const tx = lastX + dx;
          if (!TM.free(L, s, tx, sy)) break;
          if (cargo && !TM.free(L, s, tx, sy - 1)) break;
          // The dry-track model deliberately rejects liquid cargo destinations;
          // a displaced-water policy requires a separate SDK fixture.
          if (cargo && TM.terrainAt(L, s, tx, sy - 1) !== TM.T.EMPTY) break;
          index = next; lastX = tx;
        }
        if (index === s.dev[k]) return { ok: false, reason: 'cart-blocked' };
        s.dev[k] = index;
        if (cargo) cargo.x = lastX;
        p.x = sx;
        const result = TM.done(L, s, 'cart-push');
        result.events.unshift('cart-roll');
        return result;
      }
      return null;
    },
  });
})(typeof window !== 'undefined' ? window : globalThis);
