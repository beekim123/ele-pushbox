import { test } from 'node:test';
import assert from 'node:assert/strict';
import fs from 'node:fs';
import vm from 'node:vm';
import { loadCore, loadMechanisms, listJson, readJson } from '../tools/lib/load-core.mjs';
const PB = loadCore(['raster','sprites','tilemodel']);
loadMechanisms();
vm.runInThisContext(fs.readFileSync('workbench/js/app/ladder-tops.js','utf8'));
const LT = PB.ladderTops;
const spec = map => ({id:'test',map});
function caps(s, extra = []) { return LT.cells(s, new Set(extra)).filter(i => LT.isTop(s, new Set(LT.cells(s,new Set(extra))), i % s.map[0].length, Math.floor(i/s.map[0].length))); }
test('platform head keeps four pixels; logical H and movement remain intact', () => {
 const s = spec(['######','#.H..#','##H###','#.h.X#','######']);
 const before = JSON.stringify(s), p = PB.tilemodel.parse(s);
 assert.deepEqual(caps(s),[8]);
 assert.equal(LT.KEEP_ROWS,4);
 assert.ok(PB.tilemodel.act(p.level,p.state,'U').ok);
 assert.ok(PB.tilemodel.act(p.level,p.state,'U').ok);
 assert.equal(JSON.stringify(s),before);
});
test('no landing, cross-room opening and single rung keep their whole sprite', () => {
 for (const s of [spec(['#.H..#','#.H..#','######']), spec(['######','#.H..#','#.H..#','#....#','######']),spec(['######','#.H..#','######'])]) assert.deepEqual(caps(s),[]);
});
test('opening crate landing is stable after it moves; new rope extends rather than cuts an interior rung', () => {
 const s=spec(['######','#.H..#','#BH###','#.H..#','######']);
 assert.deepEqual(caps(s),[8]);
 assert.equal(LT.isTop(s,new Set([2,8,14,20]),2,1),false);
 assert.deepEqual(caps(spec(['######','#....#','##.###','#....#','######']),[8,14,20]),[8]);
});
// Counts follow the 2026-10-16 design review maps (G01, G02, E01 lost their ladders; Q04, E04 redrawn).
test('all 46 lab maps are audited; 29 static platform heads in 22 maps', () => {
 const found=listJson('content/levels/lab').map(readJson).map(s=>({id:s.id,cells:caps(s)}));
 assert.equal(found.length,46);
 assert.equal(found.filter(x=>x.cells.length).length,22);
 assert.equal(found.reduce((n,x)=>n+x.cells.length,0),29);
 assert.equal(found.find(x=>x.id==='F07').cells.length,2);
});
test('crop reuses approved pixels and restores context after an exception; independent sprite previews stay whole', () => {
 PB.sprites.register({id:'mech.ladder',size:[16,16],anchor:[8,16],frames:[Array(16).fill('aaaaaaaaaaaaaaaa')],animations:{default:{frames:[0]}}});
 const s=spec(['######','#.H..#','##H###','#.h.X#','######']);
 PB.scene={renderLevel(r) { PB.sprites.draw(r,'mech.ladder','default',0,152,92); if(r.fail) throw Error('test'); return {ox:112,oy:60}; }};
 LT.install();
 const r=new PB.Raster(320,180); PB.scene.renderLevel(r,s);
 assert.equal(r.get(144,76),'.'); assert.equal(r.get(144,88),'a');
 const bad=new PB.Raster(320,180); bad.fail=true; assert.throws(()=>PB.scene.renderLevel(bad,s),/test/);
 const a=new PB.Raster(16,16); PB.sprites.draw(a,'mech.ladder','default',0,8,16);
 assert.equal(a.get(0,0),'a');
});
