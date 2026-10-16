/* Fixed-height game-layer launch after a genuine downward contact. The WeakMap
 * only guards transient repeated impacts inside one settle; settled state is in dev. */
(function (root) {
  "use strict";
  const TM = root.PB.tilemodel, rounds = new WeakMap();
  const pos = (L,p) => p.y * L.w + p.x + 1;
  const remember = s => { for (const c of s.crates) { c.bounceX = c.x; c.bounceY = c.y; } };
  TM.register({ id: "bounce", device: "bounce",
    setup(L,s,d,k) { s.dev[k] = pos(L,s.player); remember(s); },
    solid(L,s,x,y) { return L.devices.some(d => d.type === "bounce" && d.at[0] === x && d.at[1] === y); },
    settle(L,s,events) {
      let run = rounds.get(s);
      if (!run || run.move !== s.moves) { run = {move:s.moves, fired:new Set()}; rounds.set(s,run); }
      let changed = false;
      L.devices.forEach((d,k) => {
        if (d.type !== "bounce") return;
        const [x,y] = d.at, who = s.player.x === x && s.player.y === y-1 ? s.player : TM.crateAt(s,x,y-1);
        const previous = (s.dev[k] || 1) - 1;
        const fell = who === s.player ? previous % L.w === x && (previous / L.w | 0) < y-1 : who && who.bounceX === x && who.bounceY < y-1;
        if (who && fell && !run.fired.has(who)) {
          run.fired.add(who);
          let clear = true;
          for (let yy = who.y-1; yy >= who.y-d.height; yy--) if (!TM.free(L,s,x,yy)) clear = false;
          if (clear) { who.y -= d.height; changed = true; events.push("bounce"); }
          else events.push("bounce-blocked");
        }
        const value = pos(L,s.player);
        if (s.dev[k] !== value) { s.dev[k] = value; changed = true; }
      });
      remember(s);
      return changed;
    },
  });
})(typeof window !== "undefined" ? window : globalThis);
