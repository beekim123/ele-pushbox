/* Mechanism plugin: nested_box (content/catalog/mechanisms.json spec_contract).
 * The crate at device.at carries `layers` (outer to inner). Every explosion that reaches
 * it peels one layer (crate.nest counts the layers left, crate.kind follows the outer layer);
 * one layer left is an ordinary crate. A goal with accept.nested_layers:N only lights for a
 * crate with at most N layers left. The binding follows the crate (it is a crate field). */
(function (root) {
  "use strict";
  const PB = (root.PB = root.PB || {});
  PB.tilemodel.register({
    id: "nested_box",
    device: "nested_box",
    setup(L, s, d) {
      const c = PB.tilemodel.crateAt(s, d.at[0], d.at[1]);
      if (!c) throw new Error(L.id + ": nested_box.at " + d.at + " is not a crate");
      c.nest = d.layers.length; c.kind = d.layers[0]; c.nestDev = L.devices.indexOf(d);
    },
    explode(L, s, cells) {
      for (const c of s.crates) {
        if (!(c.nest > 1) || !cells.some(([x, y]) => x === c.x && y === c.y)) continue;
        c.nest -= 1; // one peel per explosion, however many blast cells touch the crate
        c.kind = L.devices[c.nestDev].layers[L.devices[c.nestDev].layers.length - c.nest];
      }
    },
    accepts(L, s, c, x, y) {
      const g = L.goalSpecs.find((g) => g.at && g.at[0] === x && g.at[1] === y && g.accept && g.accept.nested_layers);
      return !g || (c.nest || 1) <= g.accept.nested_layers;
    },
    key: (L, s) => s.crates.filter((c) => c.nest).map((c) => c.x + "," + c.y + ":" + c.nest).sort().join(";"),
  });
})(typeof window !== "undefined" ? window : globalThis);
