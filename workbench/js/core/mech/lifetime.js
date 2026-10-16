/* The model contracts release(plug_decay)'s full fixed SDK phase to its end state.
 * The core release clears it once; this plugin validates and records that projection.
 * It does not simulate ticks or authorise game-layer timed material deletion. */
(function (root) {
  "use strict";
  const TM = root.PB.tilemodel;
  TM.register({ id: "lifetime",
    settle(L,s,events) {
      let changed = false;
      L.devices.forEach((d,k) => {
        if (d.type !== "release" || d.to !== "plug_decay") return;
        if (!(d.phase_ticks >= 120)) throw new Error(L.id + ": plug_decay phase_ticks must contain its 120 tick candidate lifetime");
        if (s.dev[k] === 1) { s.dev[k] = 2; events.push("lifetime-phase-projected"); changed = true; }
      });
      return changed;
    },
  });
})(typeof window !== "undefined" ? window : globalThis);
