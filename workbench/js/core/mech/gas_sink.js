/* Connected-volume whole-tile gas projection. Quantity is conserved; only
 * strictly higher/lower destinations are filled. SDK diffusion, per-tick bin
 * peaks and settling time are deliberately left to physical acceptance. */
(function (root) {
  "use strict";
  const TM = root.PB.tilemodel, T = TM.T, want = T.FOG, direction = 1;
  TM.register({ id: "gas_sink", settle(L,s) {
    if (L.illustration) return false;
    for (let i=0; i<s.terrain.length; i++) {
      if (s.terrain[i]!==want) continue;
      const queue=[i], seen=new Set(queue), row=i/L.w|0;
      let target=-1;
      for (let p=0; p<queue.length; p++) {
        const cell=queue[p], x=cell%L.w, y=cell/L.w|0;
        for (const [nx,ny] of [[x,y+direction],[x-1,y],[x+1,y],[x,y-direction]]) {
          if (!TM.inside(L,nx,ny)) continue;
          const n=ny*L.w+nx, t=TM.terrainAt(L,s,nx,ny);
          if (seen.has(n) || (t!==T.EMPTY && t!==want) || TM.crateAt(s,nx,ny)) continue;
          const shadow=s.player.x===nx && s.player.y===ny ? {...s,player:{x:-1,y:-1}} : s;
          if (t===T.EMPTY && !TM.free(L,shadow,nx,ny)) continue;
          seen.add(n); queue.push(n);
          if (t===T.EMPTY && direction*(ny-row)>0 && (target<0 || direction*(ny-(target/L.w|0))>0 || ny===(target/L.w|0) && n<target)) target=n;
        }
      }
      if (target>=0) { s.terrain[i]=T.EMPTY; s.terrain[target]=want; return true; }
    }
    return false;
  }});
})(typeof window !== "undefined" ? window : globalThis);
