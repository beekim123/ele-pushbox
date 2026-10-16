/* A latched background ladder; its cells are derived from each branch's dev state.
 * Never mutate shared L.climb: BFS and undo branches may have different growth. */
(function (root) {
  "use strict";
  const TM = root.PB.tilemodel;
  TM.register({ id: "vine", device: "vine", init: () => 0,
    settle(L,s) {
      let changed = false;
      L.devices.forEach((d,k) => {
        if (d.type !== "vine" || s.dev[k]) return;
        const [x,y] = d.root;
        if (TM.terrainAt(L,s,x,y) === TM.T.WATER && Math.max(1,d.need || 256) <= 256) { s.dev[k] = 1; changed = true; }
      });
      return changed;
    },
    ladder(L,s,x,y) { return L.devices.some((d,k) => d.type === "vine" && s.dev[k] && x === d.root[0] && y <= d.root[1] && y > d.root[1] - d.height); },
  });
})(typeof window !== "undefined" ? window : globalThis);
