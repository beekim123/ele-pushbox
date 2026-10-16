// Live adapter oracle, separate from approved art exports.
import fs from 'node:fs';
import vm from 'node:vm';
import {loadCore,loadMechanisms,listJson,readJson} from '../../../tools/lib/load-core.mjs';
import {encodePng} from '../../../tools/lib/png.mjs';
const PB=loadCore(['raster','font-data','font-small','font-extra','sprites','i18n','tilemodel','terrain','ambient','env','matter','scene','rooms','delivery-scene']);
loadMechanisms();
for(const f of listJson('art/source')) PB.sprites.register(readJson(f));
PB.i18n.setTables({'zh-Hans':{},en:{}}); PB.i18n.setLocale('zh-Hans');
const output='game/tests/results'; fs.mkdirSync(output,{recursive:true});
const f07=readJson('content/levels/lab/thermal/F07.json');
const before=new PB.Raster(320,180); PB.scene.renderLevel(before,f07,null,{tick:0,hud:false,env:'off',ambient:false});
vm.runInThisContext(fs.readFileSync('workbench/js/app/ladder-tops.js','utf8'));
const cases=[];
function add(spec,extra=[],kind='lab') {
 const markers=Array(spec.map.length*spec.map[0].length).fill(0);
 for(const i of PB.ladderTops.cells(spec,new Set(extra))) markers[i]=1;
 const caps=markers.flatMap((m,i)=>m&&PB.ladderTops.isTop(spec,new Set(markers.flatMap((m,j)=>m?[j]:[])),i%spec.map[0].length,Math.floor(i/spec.map[0].length))?[i]:[]);
 cases.push({id:spec.id,kind,spec,markers,caps});
}
for(const f of listJson('content/levels/lab')) {
 const s=readJson(f); add(s);
 for(const d of s.devices||[]) if(d.type==='vine') add(s,Array.from({length:d.height},(_,i)=>(d.root[1]-i)*s.map[0].length+d.root[0]),'grown-vine');
}
for(const f of listJson('content/rooms')) {
 const t=readJson(f);
 for(const p of PB.rooms.placements(t)) {
  const v=PB.rooms.variant(t,p.mirror,p.open); add(PB.droom.roomSpec(v,PB.droom.defaultPlayer(v)),[],'delivery');
 }
}
fs.writeFileSync(output+'/ladder-tops.reference.json',JSON.stringify({cases},null,1));
const after=new PB.Raster(320,180); PB.scene.renderLevel(after,f07,null,{tick:0,hud:false,env:'off',ambient:false});
fs.mkdirSync('game/reports/ladder-tops',{recursive:true});
for(const [name,r] of [['F07-before',before],['F07-after',after]]) fs.writeFileSync('game/reports/ladder-tops/'+name+'.png',encodePng(r.w,r.h,r.data));
fs.writeFileSync('game/reports/ladder-tops/audit.json',JSON.stringify({format:'portitor.ladder-display/1',keep_rows:4,cases:cases.map(({id,kind,caps,spec})=>({id,kind,tops:caps.map(i=>[i%spec.map[0].length,Math.floor(i/spec.map[0].length)])}))},null,1)+'\n');
console.log('ladder reference cases:',cases.length);
