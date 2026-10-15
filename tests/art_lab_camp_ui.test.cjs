const { test } = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');
const vm = require('node:vm');
const crypto = require('node:crypto');

const root = path.join(__dirname, '../tools/art-lab');
const uiFiles = [
  'js/data/palette.js', 'js/data/assets.js', 'js/data/campaign.js',
  'js/ui/font.js', 'js/ui/state.js', 'js/ui/draw.js',
  'js/ui/scenery.js', 'js/ui/screens.js'
];

function load() {
  for (const file of uiFiles) assert.ok(fs.existsSync(path.join(root, file)), 'Missing camp UI module: ' + file);
  const context = vm.createContext({});
  for (const file of uiFiles) vm.runInContext(fs.readFileSync(path.join(root, file), 'utf8'), context, { filename: file });
  return {
    run(source) { return vm.runInContext(source, context); },
    context,
    state: vm.runInContext('createCampState()', context)
  };
}

test('six chapters contain the real 36 campaign IDs and names', () => {
  const app = load();
  const chapters = app.run('UI_CHAPTERS');
  assert.equal(chapters.length, 6);
  for (const chapter of chapters) {
    const directory = path.join(__dirname, '../pushbox/levels/campaign', chapter.id);
    const actual = fs.readdirSync(directory).filter(f => f.endsWith('.json')).sort()
      .map(f => JSON.parse(fs.readFileSync(path.join(directory, f), 'utf8')));
    assert.equal(chapter.levels.length, 6);
    assert.deepEqual(Array.from(chapter.levels, level => [level.id, level.title]), actual.map(level => [level.id, level.title]));
  }
});

test('normal progress preserves chapter and two-at-a-time level unlock rules', () => {
  const app = load();
  const state = app.state;
  app.context.state = state;
  app.run('campPreset(state, "new")');
  assert.equal(state.chapter, 0);
  assert.deepEqual(Array.from(app.run('campOpenChapters(state)')), [0]);
  assert.deepEqual(Array.from(app.run('[0,1,2,3,4,5].map(i => campLevelStatus(state,i))')),
    ['open','open','locked','locked','locked','locked']);
  state.progress[0] = [0,1,2];
  assert.deepEqual(Array.from(app.run('campOpenChapters(state)')), [0,1]);
  assert.equal(app.run('campLevelStatus(state,5)'), 'open');
});

test('locked levels and the challenge entrance cannot launch or alter progress', () => {
  const app = load();
  app.context.state = app.state;
  app.run('campPreset(state, "new")');
  const before = JSON.stringify(app.state.progress);
  const locked = app.run('campAction(state,{type:"level",index:5})');
  assert.equal(locked.launch, undefined);
  assert.equal(app.state.level, 0);
  app.state.screen = 'lobby';
  const challenge = app.run('campAction(state,{type:"mode",mode:"challenge"})');
  assert.equal(challenge.launch, undefined);
  assert.equal(app.state.screen, 'lobby');
  assert.equal(JSON.stringify(app.state.progress), before);
});

test('the campaign entrance opens the route and launch reports the selected real level', () => {
  const app = load();
  app.context.state = app.state;
  app.run('campAction(state,{type:"mode",mode:"campaign"})');
  assert.equal(app.state.screen, 'campaign');
  app.run('campAction(state,{type:"level",index:5})');
  const before = JSON.stringify(app.state.progress);
  const result = app.run('campAction(state,{type:"launch"})');
  assert.equal(result.launch.id, 'F_06');
  assert.equal(result.launch.title, '巨木盘根水殿');
  assert.equal(JSON.stringify(app.state.progress), before);
});

test('keyboard selection skips unavailable destinations and Escape returns to camp', () => {
  const app = load();
  app.context.state = app.state;
  app.run('campPreset(state,"new"); state.screen="campaign"; campKey(state,"ArrowRight")');
  assert.equal(app.state.level, 1);
  app.run('campKey(state,"ArrowRight")');
  assert.equal(app.state.level, 0);
  app.run('campKey(state,"Escape")');
  assert.equal(app.state.screen, 'lobby');
  app.run('campKey(state,"ArrowRight")');
  assert.ok(['teaching','campaign'].includes(app.state.mode));
});

test('all six route layouts have distinct, non-overlapping hit regions inside the viewport', () => {
  const app = load();
  app.context.state = app.state;
  for (let theme = 0; theme < 6; theme++) {
    app.state.chapter = theme;
    const regions = app.run('campRegions("ui_campaign",state)');
    const nodes = regions.filter(region => region.action.type === 'level');
    assert.equal(nodes.length, 6);
    for (const region of regions) {
      assert.ok(region.x >= 0 && region.y >= 0 && region.x + region.w <= 320 && region.y + region.h <= 180, region.id);
      app.context.region = region;
      const hit = app.run('campHit("ui_campaign",state,region.x+region.w/2,region.y+region.h/2)');
      assert.equal(hit.id, region.id);
    }
    for (let i = 0; i < nodes.length; i++) for (let j = i + 1; j < nodes.length; j++) {
      const a=nodes[i],b=nodes[j];
      assert.ok(a.x+a.w<=b.x || b.x+b.w<=a.x || a.y+a.h<=b.y || b.y+b.h<=a.y, a.id+' overlaps '+b.id);
    }
  }
});

test('pointer coordinates account for integer enlargement and reject points outside the canvas', () => {
  const app = load();
  app.context.rect = { left: 50, top: 100, width: 640, height: 360 };
  const point = app.run('campPoint(370,280,rect)');
  assert.equal(point.x, 160); assert.equal(point.y, 90);
  assert.equal(app.run('campPoint(690,280,rect)'), null);
  assert.equal(app.run('campPoint(49,100,rect)'), null);
});

test('every scene uses integer palette pixels and the bundled bitmap typeface', () => {
  const app = load();
  const palette = new Set(Object.values(app.run('PALETTE')));
  const fingerprints = [];
  for (const type of ['ui_lobby','ui_campaign']) for (let theme=0;theme<6;theme++) {
    const pixels = Buffer.alloc(320*180*3);
    let count=0;
    const ctx = {
      fillStyle: '#181425',
      fillRect(x,y,w,h) {
        assert.ok([x,y,w,h].every(Number.isInteger), 'fractional pixel');
        assert.ok(palette.has(this.fillStyle), 'color outside project palette: '+this.fillStyle);
        const rgb=Buffer.from(this.fillStyle.slice(1),'hex');
        for(let yy=Math.max(0,y);yy<Math.min(180,y+h);yy++)
          for(let xx=Math.max(0,x);xx<Math.min(320,x+w);xx++)rgb.copy(pixels,(yy*320+xx)*3);
        count++;
      },
      fillText() { assert.fail('Use the pixel typeface, not system Canvas text'); }
    };
    app.context.ctx=ctx; app.context.state=app.state; app.state.chapter=theme;
    app.context.type=type;
    app.run('renderUIPreviewToCtx(ctx,type,0,state)');
    assert.ok(count>500, 'empty scene');
    fingerprints.push(crypto.createHash('sha256').update(pixels).digest('hex'));
  }
  assert.equal(new Set(fingerprints).size,12);
  assert.equal(app.run('CAMP_MISSING_GLYPHS.size'),0);
});

function viewer() {
  const app=load(),elements={};
  let focus=null,paintCount=0,exports=0;
  const ctx={fillStyle:"#181425",fillRect(){paintCount++;}};
  const ids=['uiScreenSelect','uiProgressSelect','uiChapterSelect','uiFocusCanvas','uiFocusDialog',
    'uiFocusStatus','uiOpenPreview','uiClosePreview','uiPreviousItem','uiNextItem','uiActivateItem','uiBackToCamp'];
  for(const id of ids) elements[id]={
    value:"",style:{},dataset:{},children:[],listeners:{},isConnected:true,open:false,
    setAttribute(){},addEventListener(name,callback){this.listeners[name]=callback;},
    appendChild(child){this.children.push(child);},
    focus(){focus=this;},getContext(){return ctx;},
    getBoundingClientRect(){return {left:50,top:30,width:640,height:360};},
    showModal(){this.open=true;},close(){this.open=false;if(this.listeners.close)this.listeners.close();}
  };
  const document={
    get activeElement(){return focus;},
    getElementById(id){assert.ok(elements[id],'Unknown viewer ID: '+id);return elements[id];},
    createElement(){return {value:"",textContent:""};}
  };
  Object.assign(app.context,{
    document,window:{innerWidth:1024,innerHeight:768,addEventListener(){}},
    selectedAsset:{renderType:"ui_campaign"},
    updateInspectorCode(){exports++;}
  });
  vm.runInContext(fs.readFileSync(path.join(root,'js/ui/viewer.js'),'utf8'),app.context);
  app.run('initCampViewer()');
  focus=elements.uiOpenPreview;
  return {app,elements,get focus(){return focus;},get paints(){return paintCount;},get exports(){return exports;},
    key(key){const event={key,target:elements.uiFocusCanvas,preventDefault(){},stopPropagation(){}};elements.uiFocusDialog.listeners.keydown(event);}};
}

test('full-size viewer handles scaled clicks, nested Escape and returns focus', () => {
  const v=viewer();
  v.app.run('openCampViewer("ui_lobby")');
  assert.equal(v.elements.uiFocusDialog.open,true);
  assert.equal(v.elements.uiFocusCanvas.style.width,'640px');
  assert.equal(v.focus,v.elements.uiFocusCanvas);
  v.elements.uiFocusCanvas.listeners.click({clientX:370,clientY:270});
  assert.equal(v.app.run('campPreviewState.screen'),'campaign');
  v.key('Escape');
  assert.equal(v.app.run('campPreviewState.screen'),'lobby');
  assert.equal(v.elements.uiFocusDialog.open,true);
  v.key('Escape');
  assert.equal(v.elements.uiFocusDialog.open,false);
  assert.equal(v.focus,v.elements.uiOpenPreview);
});

test('preview rendering is cached until its 8 FPS frame or selection changes', () => {
  const v=viewer();
  v.app.run('openCampViewer("ui_campaign");renderCampViewer(0)');
  const first=v.paints;
  v.app.run('renderCampViewer(0.03)');
  assert.equal(v.paints,first);
  v.app.run('campAction(campPreviewState,{type:"level",index:4});renderCampViewer(0.03)');
  assert.ok(v.paints>first);
});

test('keyboard and native preview controls refresh the exported selection', () => {
  const v=viewer();
  v.app.run('openCampViewer("ui_campaign")');
  const before=v.exports;
  v.key('ArrowRight');
  assert.ok(v.exports>before,'Keyboard change must refresh inspector data');
  const after=v.exports;
  v.elements.uiNextItem.listeners.click();
  assert.ok(v.exports>after,'Native controls must refresh inspector data');
});

test('keyboard lobby selection replaces stale mouse hover and Enter matches the highlight', () => {
  const app=load();
  app.context.state=app.state;
  app.state.mode="teaching";app.state.hoverId="teaching";
  app.run('campKey(state,"ArrowRight")');
  assert.equal(app.state.mode,"campaign");
  assert.equal(app.state.hoverId,null);
  app.state.hoverId="teaching";
  const result=app.run('campKey(state,"Enter")');
  assert.equal(result.launch.kind,"teaching");
  assert.equal(app.state.mode,"teaching");
  assert.equal(app.state.hoverId,null);
});

test('editing and restoring a sprite invalidates paused camp previews', () => {
  const v=viewer(),app=v.app;
  const inspector=fs.readFileSync(path.join(root,'js/inspector.js'),'utf8');
  const paint=inspector.slice(inspector.indexOf('function paintOnInspectorCanvas'),inspector.indexOf('function selectAssetForInspector'));
  const reset=inspector.slice(inspector.indexOf('function resetSelectedAsset'),inspector.indexOf('async function copyInspectorCode'));
  Object.assign(app.context,{
    selectedAsset:app.run('ASSET_CATALOG.find(a=>a.id==="miner_idle")'),
    selectedFrameIdx:0,activePaintCode:"m",
    inspCanvas:{getBoundingClientRect(){return {left:0,top:0,width:128,height:128};}},
    selectAssetForInspector(){}
  });
  vm.runInContext(paint+'\n'+reset,app.context);
  const before=app.run('campFrameKey("ui_lobby",0)');
  app.run('paintOnInspectorCanvas({clientX:1,clientY:1})');
  const edited=app.run('campFrameKey("ui_lobby",0)');
  assert.notEqual(edited,before,'Painting must invalidate the paused UI frame');
  app.run('resetSelectedAsset()');
  assert.notEqual(app.run('campFrameKey("ui_lobby",0)'),edited,'Restoring must invalidate the paused UI frame');
});
