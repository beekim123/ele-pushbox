// These primitives only emit integer, palette-bound rectangles.
const CAMP_MISSING_GLYPHS = new Set();
function campRect(ctx,x,y,w,h,color) {
  ctx.fillStyle=PALETTE[color] || color;
  ctx.fillRect(Math.round(x),Math.round(y),Math.round(w),Math.round(h));
}
function campPoly(ctx,points,color) {
  const min=Math.min(...points.map(p=>p[1])),max=Math.max(...points.map(p=>p[1]));
  for(let y=min;y<max;y++) {
    const cuts=[];
    for(let i=0;i<points.length;i++) {
      const a=points[i],b=points[(i+1)%points.length];
      if((a[1]<=y && b[1]>y)||(b[1]<=y && a[1]>y)) cuts.push(a[0]+(y-a[1])*(b[0]-a[0])/(b[1]-a[1]));
    }
    cuts.sort((a,b)=>a-b);
    for(let i=0;i+1<cuts.length;i+=2) campRect(ctx,Math.ceil(cuts[i]),y,Math.floor(cuts[i+1])-Math.ceil(cuts[i]),1,color);
  }
}
function campLine(ctx,a,b,color,width=1) {
  let x=a[0],y=a[1],dx=Math.abs(b[0]-x),dy=-Math.abs(b[1]-y),sx=x<b[0]?1:-1,sy=y<b[1]?1:-1,error=dx+dy;
  while(true) {
    campRect(ctx,x,y,width,width,color);
    if(x===b[0] && y===b[1]) break;
    const twice=2*error;
    if(twice>=dy) {error+=dy;x+=sx;}
    if(twice<=dx) {error+=dx;y+=sy;}
  }
}
function campEllipse(ctx,x,y,rx,ry,color) {
  for(let dy=-ry;dy<=ry;dy++) {
    const half=Math.floor(rx*Math.sqrt(Math.max(0,1-dy*dy/(ry*ry))));
    campRect(ctx,x-half,y+dy,half*2+1,1,color);
  }
}
function campGlyph(char) {
  if(!CAMP_FONT.glyphs[char]) CAMP_MISSING_GLYPHS.add(char);
  return CAMP_FONT.glyphs[char] || CAMP_FONT.glyphs["?"];
}
function campTextWidth(text,scale=1) {
  return Array.from(text).reduce((sum,char)=>sum+campGlyph(char).advance*scale,0);
}
function campText(ctx,text,x,y,color="u",scale=1,align="left",outline=false) {
  const width=campTextWidth(text,scale);
  const origin=Math.round(x-(align==="center"?width/2:align==="right"?width:0));
  function paint(dx,dy,code) {
    let cursor=origin;
    for(const char of text) {
      const glyph=campGlyph(char);
      glyph.rows.forEach((bits,row) => {
        let run=-1;
        for(let col=0;col<=glyph.advance;col++) {
          const on=col<glyph.advance && (bits & (1<<col));
          if(on && run<0) run=col;
          if(!on && run>=0) {
            campRect(ctx,cursor+run*scale+dx,y+row*scale+dy,(col-run)*scale,scale,code);run=-1;
          }
        }
      });
      cursor+=glyph.advance*scale;
    }
  }
  if(outline) for(const [dx,dy] of [[-1,0],[1,0],[0,-1],[0,1]]) paint(dx,dy,"z");
  paint(0,0,color);
}
function campSprite(ctx,id,frame,x,y,flip=false) {
  const asset=ASSET_CATALOG.find(a=>a.id===id);
  if(!asset || !asset.frames) return;
  const rows=asset.frames[frame%asset.frames.length],width=rows[0].length;
  rows.forEach((row,yy)=>Array.from(row).forEach((char,xx)=>{
    if(PALETTE[char]) campRect(ctx,x+(flip?width-1-xx:xx),y+yy,1,1,char);
  }));
}
function campChevron(ctx,x,y,direction,color) {
  const dx=direction<0?-1:1;
  for(let i=0;i<4;i++) {campRect(ctx,x+dx*i,y+i,2,1,color);campRect(ctx,x+dx*i,y+6-i,2,1,color);}
}
function campMarker(ctx,x,y,color="l") {
  for(let row=0;row<4;row++) campRect(ctx,x-3+row,y+row,7-row*2,1,color);
}
function campSign(ctx,x,y,w,label,selected=false,disabled=false) {
  campRect(ctx,x+2,y+2,w,17,"z");
  campPoly(ctx,[[x+2,y],[x+w-2,y],[x+w,y+2],[x+w,y+14],[x+w-2,y+16],[x+2,y+16],[x,y+14],[x,y+2]],disabled?"g":"f");
  campRect(ctx,x+2,y,w-4,1,selected?"k":"e");
  campRect(ctx,x+2,y+15,w-4,1,"g");
  campRect(ctx,x+3,y+5,1,1,"F");campRect(ctx,x+w-4,y+10,1,1,"g");
  campText(ctx,label,x+w/2,y+1,disabled?"v":selected?"l":"c",1,"center");
}
