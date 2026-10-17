// Node re-implementation of game/tools/check_ids.gd (checks a/b/c) for machines without Godot.
// Usage: node tools/dev/check-ids-node.mjs <repo-root>   (run node game/tools/import_resources.mjs import first)
import fs from 'fs'; import path from 'path'; import crypto from 'crypto';
const G=path.join(process.argv[2],'game'); const rd=p=>{try{return JSON.parse(fs.readFileSync(path.join(G,p.replace('res://','')),'utf8'))}catch{return {}}};
const sha=f=>crypto.createHash('sha256').update(fs.readFileSync(f)).digest('hex');
const ex=p=>fs.existsSync(path.join(G,p.replace('res://','')));
const idm=rd('res://generated/id-map.json'), arts=rd('res://generated/art-index.json'), inv=rd('res://generated/import-inventory.json');
const tr=[rd('res://generated/content/i18n/zh-Hans.json'),rd('res://generated/content/i18n/en.json')];
const known=new Set(idm.entries.map(e=>e.uid)); const fails=[];
for(const it of idm.entries){const loc=String(it.game);
 if(it.domain==='text'){for(const t of tr) if(typeof t[it.id]!=='string') fails.push(['a',it.uid,'missing translation']);continue}
 const [p0,frag]=loc.split('#'); if(!ex(p0)){fails.push(['a',it.uid,loc,'missing dest']);continue}
 if(frag!==undefined){ if(!(rd(p0).entries||[]).some(r=>String(r.id)===String(it.id))) fails.push(['a',it.uid,'fragment missing'])}
 if(it.domain==='level'&&sha(path.join(G,p0.replace('res://','')))!==it.sha256) fails.push(['a',it.uid,'level sha']);
 if(it.domain==='art'){const m=arts[it.uid]||{}; if(m.hash!==it.hash||m.version!==it.version||m.approved!==it.approved) fails.push(['a',it.uid,'art mismatch',m.version,it.version,m.approved,it.approved]);
  if(m.texture_path&&sha(path.join(G,m.texture_path.replace('res://','')))!==m.png_sha256) fails.push(['a',it.uid,'png sha'])}}
const walk=d=>fs.readdirSync(d,{withFileTypes:true}).flatMap(e=>e.name==='.godot'?[]:e.isDirectory()?walk(path.join(d,e.name)):[path.join(d,e.name)]);
const re=/["']([a-z][a-z0-9_]*:[A-Za-z0-9_][A-Za-z0-9_.-]*)["']/g;
for(const f of walk(G)){const r=path.relative(G,f); if(r.startsWith('generated/')||r.startsWith('tests/'))continue; if(!/\.(gd|tscn)$/.test(f))continue;
 for(const m of fs.readFileSync(f,'utf8').matchAll(re)){const u=m[1]; if(u.endsWith('.'))continue; if(!known.has(u)) fails.push(['b',u,r])}}
const owned=new Map((inv.files||[]).map(x=>['generated/'===''?x.path:x.path,x]));
for(const f of walk(path.join(G,'generated'))){const r=path.relative(G,f); if((r.endsWith('.import')&&owned.has(r.slice(0,-7)))||(r.endsWith('.uid')&&owned.has(r.slice(0,-4))))continue;
 const it=owned.get(r); if(!it||!(it.owners||[]).length){fails.push(['c',r,'no owner']);continue} for(const u of it.owners) if(!known.has(u)) fails.push(['c',u,r,'owner unknown']);
 if(it.sha256!=null&&it.sha256!==sha(f)) fails.push(['c',r,'changed after import'])}
for(const [p] of owned) if(!fs.existsSync(path.join(G,p))) fails.push(['c',p,'inventory missing']);
console.log(known.size,'uids',fails.length,'failures'); for(const f of fails) console.log(JSON.stringify(f));
