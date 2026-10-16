/* A new falling load triggers the opposite body once. Initial loads form a
 * baseline. A rejected sweep consumes that arrival; a resting load never retries. */
(function (root) {
  "use strict";
  const TM = root.PB.tilemodel, T = TM.T;
  const occupant = (s,x,y) => s.player.x === x && s.player.y === y ? s.player : TM.crateAt(s,x,y);
  function load(L,s,end) {
    let value = 0;
    for (let y=end[1]-1; y>=0; y--) {
      const who = occupant(s,end[0],y), t = TM.terrainAt(L,s,end[0],y);
      if (who) value += who === s.player ? 1 : TM.WEIGHT[who.kind] || 1;
      else if (t === T.SAND || t === T.GRAVEL) value++;
      else break;
    }
    return Math.min(15,value);
  }
  const encode = (L,s,d) => load(L,s,d.ends[0]) + 16*load(L,s,d.ends[1]) + 256*(s.player.y*L.w+s.player.x+1);
  const remember = s => { for (const c of s.crates) { c.seesawX=c.x; c.seesawY=c.y; } };
  TM.register({ id: "seesaw", device: "seesaw",
    setup(L,s,d,k) { s.dev[k]=encode(L,s,d); remember(s); },
    solid(L,s,x,y) { return L.devices.some(d => d.type === "seesaw" && d.ends.some(e => e[0]===x && e[1]===y)); },
    settle(L,s,events) {
      let changed = false;
      L.devices.forEach((d,k) => {
        if (d.type !== "seesaw") return;
        const old = s.dev[k] || 0, playerAt = (old / 256 | 0)-1;
        for (let side=0; side<2; side++) {
          const end=d.ends[side], current=load(L,s,end), before=(old >> (side*4)) & 15;
          if (current <= before || current < (d.threshold || 1)) continue;
          const source=occupant(s,end[0],end[1]-1), material=TM.terrainAt(L,s,end[0],end[1]-1);
          const fell = source === s.player ? playerAt % L.w === source.x && (playerAt / L.w | 0) < source.y
            : source ? source.seesawX === source.x && source.seesawY < source.y : material===T.SAND || material===T.GRAVEL;
          if (!fell) continue;
          const other=1-side, pad=d.ends[other], who=occupant(s,pad[0],pad[1]-1);
          if (!who) continue;
          const to=d.landings[other], top=who.y-d.height;
          if (!to || to[1]!==top || Math.abs(to[0]-who.x)!==1) throw new Error(L.id+": seesaw landing must rise height then move one cell");
          let clear=true;
          for (let y=who.y-1; y>=top; y--) if (!TM.free(L,s,who.x,y)) clear=false;
          if (!TM.free(L,s,to[0],to[1])) clear=false;
          if (clear) { who.x=to[0]; who.y=to[1]; changed=true; events.push("seesaw"); }
          else events.push("seesaw-blocked");
        }
        const next=encode(L,s,d);
        if (next!==s.dev[k]) { s.dev[k]=next; changed=true; }
      });
      remember(s);
      return changed;
    },
  });
})(typeof window !== "undefined" ? window : globalThis);
