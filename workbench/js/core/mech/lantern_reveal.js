/* Mechanism plugin: lantern_reveal (content/catalog/mechanisms.json spec_contract).
 * Ghost planks (`cells`) are solid only while the player is within 2 tiles
 * (Euclidean, tile centres, dx^2 + dy^2 <= 4). Order per action: update the planks, then
 * gravity; the player's gravity runs inside the same settle loop, which re-runs this hook.
 * state.dev[k] holds a bitmask of the lit planks. */
(function (root) {
  "use strict";
  const PB = (root.PB = root.PB || {});
  const RADIUS2 = 4;
  const lit = (L, s, d, i) => {
    const [x, y] = d.cells[i], dx = s.player.x - x, dy = s.player.y - y;
    return dx * dx + dy * dy <= RADIUS2;
  };
  PB.tilemodel.register({
    id: "lantern_reveal",
    device: "lantern_reveal",
    init: () => 0,
    settle(L, s) {
      let moved = false;
      L.devices.forEach((d, k) => {
        if (d.type !== "lantern_reveal") return;
        let mask = 0;
        d.cells.forEach((_, i) => { if (lit(L, s, d, i)) mask |= 1 << i; });
        if (mask !== s.dev[k]) { s.dev[k] = mask; moved = true; }
      });
      return moved;
    },
    solid(L, s, x, y) {
      for (let k = 0; k < L.devices.length; k++) {
        const d = L.devices[k];
        if (d.type !== "lantern_reveal") continue;
        for (let i = 0; i < d.cells.length; i++) if (d.cells[i][0] === x && d.cells[i][1] === y && (s.dev[k] >> i) & 1) return true;
      }
      return false;
    },
  });
})(typeof window !== "undefined" ? window : globalThis);
