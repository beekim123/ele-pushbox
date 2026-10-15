// Render the same integer rectangles as Canvas; no browser or game process.
const fs=require('node:fs'),path=require('node:path'),vm=require('node:vm');
const zlib=require('node:zlib'),crypto=require('node:crypto');
const root=path.resolve(__dirname,'..');
const output=path.resolve(process.argv[2] || path.join(root,'../../artifacts/art-lab-ui-camp'));
const scripts=['js/data/palette.js','js/data/assets.js','js/data/campaign.js','js/ui/font.js','js/ui/state.js','js/ui/draw.js','js/ui/scenery.js','js/ui/screens.js'];
const context=vm.createContext({});
scripts.forEach(file=>vm.runInContext(fs.readFileSync(path.join(root,file),'utf8'),context,{filename:file}));
const crcTable=Array.from({length:256},(_,n)=>{for(let k=0;k<8;k++)n=n&1?0xedb88320^(n>>>1):n>>>1;return n>>>0;});
function chunk(type,body) {
  const kind=Buffer.from(type),combined=Buffer.concat([kind,body]);
  let crc=0xffffffff;
  for(const value of combined)crc=crcTable[(crc^value)&255]^(crc>>>8);
  const length=Buffer.alloc(4),sum=Buffer.alloc(4);length.writeUInt32BE(body.length);sum.writeUInt32BE((crc^0xffffffff)>>>0);
  return Buffer.concat([length,combined,sum]);
}
function png(pixels,width=320,height=180) {
  const header=Buffer.alloc(13);header.writeUInt32BE(width,0);header.writeUInt32BE(height,4);header[8]=8;header[9]=2;
  const rows=[];
  for(let y=0;y<height;y++)rows.push(Buffer.from([0]),pixels.subarray(y*width*3,(y+1)*width*3));
  return Buffer.concat([Buffer.from('89504e470d0a1a0a','hex'),chunk('IHDR',header),chunk('IDAT',zlib.deflateSync(Buffer.concat(rows))),chunk('IEND',Buffer.alloc(0))]);
}
function render(type,chapter,time,preset="open") {
  const pixels=Buffer.alloc(320*180*3);
  const colors=new Map();
  const ctx={fillStyle:"#181425",fillRect(x,y,w,h){
    if(![x,y,w,h].every(Number.isInteger))throw Error('Fractional rectangle');
    if(!colors.has(this.fillStyle))colors.set(this.fillStyle,Buffer.from(this.fillStyle.slice(1),'hex'));
    const color=colors.get(this.fillStyle);
    for(let yy=Math.max(0,y);yy<Math.min(180,y+h);yy++)
      for(let xx=Math.max(0,x);xx<Math.min(320,x+w);xx++)color.copy(pixels,(yy*320+xx)*3);
  }};
  context.ctx=ctx;context.type=type;context.chapter=chapter;context.time=time;context.preset=preset;
  vm.runInContext('var state=createCampState();campPreset(state,preset);state.chapter=chapter;renderUIPreviewToCtx(ctx,type,time,state)',context);
  return pixels;
}
fs.mkdirSync(output,{recursive:true});
const chapters=vm.runInContext('UI_CHAPTERS',context),screens=[];
for(let chapter=0;chapter<6;chapter++)for(const type of ['ui_lobby','ui_campaign']) {
  const pixels=render(type,chapter,0);
  const name=chapters[chapter].id+'-'+type.replace('ui_','')+'-native.png';
  fs.writeFileSync(path.join(output,name),png(pixels));
  screens.push({theme:chapters[chapter].id,type,file:name,sha256:crypto.createHash('sha256').update(pixels).digest('hex')});
}
const states=[];
for(const preset of ['new','mid','complete']) {
  const chapter=preset==='new'?0:1,name=chapters[chapter].id+'-campaign-'+preset+'-native.png';
  fs.writeFileSync(path.join(output,name),png(render('ui_campaign',chapter,0,preset)));
  states.push({preset,theme:chapters[chapter].id,file:name});
}
for(const type of ['ui_lobby','ui_campaign'])for(let frame=0;frame<8;frame++) {
  fs.writeFileSync(path.join(output,'forest-'+type.replace('ui_','')+'-frame-'+frame+'.png'),png(render(type,1,frame/8)));
}
const sourceHashes=Object.fromEntries(scripts.map(file=>[file,crypto.createHash('sha256').update(fs.readFileSync(path.join(root,file))).digest('hex')]));
const manifest={viewport:[320,180],font:"Fusion Pixel 12px bitmap subset",source:"Art Lab integer Canvas primitives; not a browser or Godot screenshot",sourceHashes,screens,states};
fs.writeFileSync(path.join(output,'manifest.json'),JSON.stringify(manifest,null,2)+'\n');
console.log('Rendered 12 themed screens, 3 progress states and 16 animation source frames to '+output);
