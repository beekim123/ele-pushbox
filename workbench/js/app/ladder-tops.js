/* Live presentation override. Frozen sprite sources and art-export renderers stay
 * unchanged. H/h remains a complete logical cell; only a platform head's upper
 * twelve pixels are omitted. Opening geometry keeps the cap stable while boxes
 * move and terrain is dug. A room-edge connection has no cap. Level mode and v1
 * delivery rooms are wrapped here; delivery v2 rooms call scope(). */
(function (root) {
 'use strict';
 const PB = root.PB = root.PB || {}, KEEP_ROWS = 4;
 const passable = c => '.HhoXP_BIb~a^v'.includes(c || '?');
 const support = c => !!c && !'.HhoXP_~a^v|'.includes(c);
 function cells(spec, extra = new Set()) {
  const w = spec.map[0].length, out = new Set(extra);
  spec.map.forEach((row,y) => [...row].forEach((c,x) => { if(c==='H'||c==='h') out.add(y*w+x); }));
  return [...out].sort((a,b)=>a-b);
 }
 function isTop(spec, climb, x, y) {
  const rows=spec.map, w=rows[0].length;
  if(y<=0 || y+1>=rows.length || x<0 || x>=w || !climb.has(y*w+x) || climb.has((y-1)*w+x) || !climb.has((y+1)*w+x)) return false;
  return [-1,1].some(dx => x+dx>=0 && x+dx<w && passable(rows[y][x+dx]) && support(rows[y+1][x+dx]));
 }
 let active=null;
 function context(spec,L,s,extra=new Set()) {
  const climb=new Set(cells(spec,extra)), vine=new Set();
  for(const i of L.climb || []) climb.add(i);
  (L.devices||[]).forEach((d,k)=>{
   if(d.type==='vine' && (s.dev?.[k] || d.preview?.grown)) for(let n=0;n<d.height;n++) { const i=(d.root[1]-n)*L.w+d.root[0]; climb.add(i); vine.add(i); }
  });
  return {spec,climb,vine,ox:(320-L.w*16)>>1,oy:20+((160-L.h*16)>>1)};
 }
 function scoped(ctx,fn) { const previous=active; active=ctx; try { return fn(); } finally { active=previous; } }
 // For renderers that place a room themselves, such as delivery v2 (PB.droom2,
 // delivery-puzzle-rules.md 8.2): fn's ladder sprites get the same caps. spec is
 // the room's opening map in level letters (rooms2.start: M.spec, float blocks
 // there are ground), L and s its parsed level and live state, and the room's
 // top-left cell is drawn at (ox, oy).
 function scope(spec,L,s,ox,oy,fn) { const ctx=context(spec,L,s); ctx.ox=ox; ctx.oy=oy; return scoped(ctx,fn); }
 function install() {
  if(PB.scene && !PB.scene.renderLevel.ladderTops) {
   const render=PB.scene.renderLevel;
   const wrapped=function(r,spec,state,opts) {
    if(spec.showcase || spec.id==='delivery.hud') return scoped(null,()=>render(r,spec,state,opts));
    const parsed=state || PB.tilemodel.parse(spec);
    const ctx=context(spec,parsed.level,parsed.state,active?.extra);
    // The frozen illustration compositor reads preview.grown. Supply the live
    // plugin state at its boundary without changing the source spec or renderer.
    const visual={...spec,devices:(spec.devices||[]).map((d,k)=>d.type==='vine'?{...d,preview:{...d.preview,grown:!!parsed.state.dev?.[k] || !!d.preview?.grown}}:d)};
    return scoped(ctx,()=>render(r,visual,parsed,opts));
   };
   wrapped.ladderTops=true; PB.scene.renderLevel=wrapped;
  }
  if(PB.droom && !PB.droom.renderLive.ladderTops) {
   const render=PB.droom.renderLive;
   const wrapped=function(r,run,opts) {
    const rm=run.room, spec=PB.droom.roomSpec(rm.v,PB.droom.defaultPlayer(rm.v));
    const ctx=context(spec,rm.L,{dev:[]},new Set(rm.climb)); ctx.extra=new Set(rm.climb);
    return scoped(ctx,()=>render(r,run,opts));
   };
   wrapped.ladderTops=true; PB.droom.renderLive=wrapped;
  }
  if(!PB.sprites.draw.ladderTops) {
   const draw=PB.sprites.draw;
   const wrapped=function(r,id,anim,tick,x,y,flip) {
    const c=active;
    if(c && ['mech.ladder','mech.rope_ladder','mech.vine'].includes(id) && anim!=='root') {
     const tx=(x-c.ox-8)/16,ty=(y-c.oy-16)/16,i=ty*c.spec.map[0].length+tx;
     if(Number.isInteger(tx)&&Number.isInteger(ty)) {
      if(id==='mech.ladder'&&c.vine.has(i)) return;
      if(isTop(c.spec,c.climb,tx,ty)) {
       const a=PB.sprites.get(id),f=typeof anim==='number'?anim:PB.sprites.frameAt(a,anim,tick||0),skip=Math.max(0,a.size[1]-KEEP_ROWS);
       r.blitRows(a.frames[f].slice(skip),x-(flip?a.size[0]-a.anchor[0]:a.anchor[0]),y-a.anchor[1]+skip,!!flip); return;
      }
     }
    }
    return draw(r,id,anim,tick,x,y,flip);
   };
   wrapped.ladderTops=true; PB.sprites.draw=wrapped;
  }
 }
 PB.ladderTops={KEEP_ROWS,cells,isTop,scope,install}; install();
})(typeof window!=='undefined'?window:globalThis);
