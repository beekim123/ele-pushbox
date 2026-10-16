/* Whole-tile acid projection, not SDK chemistry: each reaction consumes exactly one
 * acid tile and one tagged rock tile. Flow chooses a lower reachable air cell.
 * Cell-scale contact/residue and reaction timing remain SDK acceptance checks. */
(function (root) {
  "use strict";
  const TM = root.PB.tilemodel, T = TM.T;
  const neighbours = (L, i) => [[i % L.w, (i / L.w | 0) + 1], [i % L.w - 1, i / L.w | 0], [i % L.w + 1, i / L.w | 0], [i % L.w, (i / L.w | 0) - 1]].filter(([x,y]) => TM.inside(L,x,y));
  TM.register({ id: "acid", settle(L, s, events) {
    if (L.illustration) return false;
    for (let i = 0; i < s.terrain.length; i++) {
      if (s.terrain[i] !== T.ACID) continue;
      for (const [x,y] of neighbours(L,i)) {
        const n = y * L.w + x, t = TM.terrainAt(L,s,x,y);
        if (t !== T.LIME_A && t !== T.LIME_B) continue;
        s.terrain[i] = T.EMPTY; s.terrain[n] = T.EMPTY; events.push("acid-reaction"); return true;
      }
      const queue = [i], seen = new Set(queue), parents = new Map(), top = i / L.w | 0;
      let target = -1;
      for (let p = 0; p < queue.length; p++) for (const [x,y] of neighbours(L,queue[p])) {
        const n = y * L.w + x, t = TM.terrainAt(L,s,x,y);
        if (seen.has(n) || y < top || (t !== T.EMPTY && t !== T.ACID) || TM.crateAt(s,x,y)) continue;
        // free() also honours device platforms; the player does not block SDK fluid.
        const shadow = s.player.x === x && s.player.y === y ? { ...s, player: {x:-1,y:-1} } : s;
        if (t === T.EMPTY && !TM.free(L,shadow,x,y)) continue;
        seen.add(n); parents.set(n, queue[p]); queue.push(n);
        const reactionEdge = neighbours(L,n).some(([rx,ry]) => [T.LIME_A,T.LIME_B].includes(TM.terrainAt(L,s,rx,ry)));
        if (t === T.EMPTY && (y > top || y === top && reactionEdge) && (target < 0 || y > (target / L.w | 0) || y === (target / L.w | 0) && n < target)) target = n;
      }
      if (target >= 0) {
        // Move only to the first open cell along the route, so contact reactions
        // happen before a fluid unit can pass an etchable side wall. Existing
        // contiguous acid may transmit that one unit, but quantity stays exact.
        const path = [];
        for (let n = target; n !== i; n = parents.get(n)) path.push(n);
        const next = path.reverse().find(n => s.terrain[n] === T.EMPTY);
        s.terrain[i] = T.EMPTY; s.terrain[next] = T.ACID; return true;
      }
    }
    return false;
  } });
})(typeof window !== "undefined" ? window : globalThis);
