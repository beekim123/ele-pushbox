// Preview state is isolated from real game saves and progression.
const CAMP_ROUTES = [
  [[22,100],[71,76],[121,105],[171,65],[222,92],[272,48]],
  [[22,104],[72,74],[122,102],[172,59],[222,88],[272,48]],
  [[22,111],[72,82],[122,52],[172,82],[222,110],[272,53]],
  [[22,65],[72,105],[122,65],[172,105],[222,65],[272,105]],
  [[22,100],[72,56],[122,92],[172,49],[222,92],[272,57]],
  [[22,88],[72,88],[122,52],[172,103],[222,52],[272,88]]
];
const CAMP_THEMES = [
  { sky:"z", far:"y", mid:"x", rock:"w", rim:"v", ground:"g", trim:"w", road:"e", water:"q", accent:"l", wood:"f" },
  { sky:"p", far:"o", mid:"n", rock:"f", rim:"e", ground:"g", trim:"n", road:"e", water:"r", accent:"l", wood:"f" },
  { sky:"g", far:"f", mid:"e", rock:"e", rim:"d", ground:"f", trim:"k", road:"d", water:"q", accent:"k", wood:"f" },
  { sky:"z", far:"y", mid:"p", rock:"x", rim:"w", ground:"y", trim:"p", road:"w", water:"q", accent:"s", wood:"f" },
  { sky:"x", far:"B", mid:"C", rock:"u", rim:"t", ground:"v", trim:"t", road:"c", water:"r", accent:"l", wood:"f" },
  { sky:"z", far:"y", mid:"x", rock:"w", rim:"u", ground:"y", trim:"w", road:"v", water:"q", accent:"s", wood:"f" }
];

function createCampState() {
  return {
    screen:"lobby", chapter:1, level:3, mode:"campaign",
    progress:[[0,1,2,3,4,5],[0,1,2],[],[],[],[]],
    openAll:true, preset:"open", hoverId:null, revision:0
  };
}
const campPreviewState = createCampState();

function campOpenChapters(state) {
  return UI_CHAPTERS.map((_,i) => i).filter(i =>
    state.openAll || i === 0 || state.progress[i-1].length >= 3);
}
function campLevelStatus(state, index) {
  if (state.progress[state.chapter].includes(index)) return "done";
  if (!campOpenChapters(state).includes(state.chapter)) return "locked";
  return state.openAll || index < Math.min(6, 2 + state.progress[state.chapter].length * 2) ? "open" : "locked";
}
function campPreset(state, preset) {
  state.preset=preset;
  state.progress = UI_CHAPTERS.map(() => []);
  state.openAll = preset === "open";
  if (preset === "mid" || preset === "open") {
    state.progress[0] = [0,1,2,3,4,5];
    state.progress[1] = [0,1,2];
    state.chapter = 1; state.level = 3;
  } else if (preset === "complete") {
    state.progress = UI_CHAPTERS.map(() => [0,1,2,3,4,5]);
  } else {
    state.chapter = 0; state.level = 0;
  }
  state.hoverId = null;
  state.revision++;
}
function campRegions(type, state) {
  if (type === "ui_lobby") return [
    {id:"teaching",x:14,y:79,w:87,h:84,action:{type:"mode",mode:"teaching"}},
    {id:"campaign",x:113,y:61,w:94,h:102,action:{type:"mode",mode:"campaign"}},
    {id:"challenge",x:224,y:83,w:83,h:80,disabled:true,action:{type:"mode",mode:"challenge"}}
  ];
  const hasOtherChapter = campOpenChapters(state).length > 1;
  return [
    {id:"back",x:5,y:5,w:26,h:25,action:{type:"back"}},
    {id:"previous",x:38,y:5,w:26,h:25,disabled:!hasOtherChapter,action:{type:"chapter",step:-1}},
    {id:"next",x:246,y:5,w:26,h:25,disabled:!hasOtherChapter,action:{type:"chapter",step:1}},
    {id:"enter",x:258,y:148,w:54,h:25,disabled:campLevelStatus(state,state.level)==="locked",action:{type:"launch"}},
    ...CAMP_ROUTES[state.chapter].map(([x,y],i) => ({
      id:"level-"+i,x,y,w:24,h:24,disabled:campLevelStatus(state,i)==="locked",action:{type:"level",index:i}
    }))
  ];
}
function campHit(type, state, x, y) {
  return campRegions(type,state).find(r => x>=r.x && y>=r.y && x<r.x+r.w && y<r.y+r.h) || null;
}
function campPoint(clientX, clientY, rect) {
  if (rect.width<=0 || rect.height<=0) return null;
  const x=Math.floor((clientX-rect.left)*320/rect.width);
  const y=Math.floor((clientY-rect.top)*180/rect.height);
  return x>=0 && y>=0 && x<320 && y<180 ? {x,y} : null;
}
function campAction(state, action) {
  if (action.type === "mode") {
    if (!["teaching","campaign"].includes(action.mode)) return {notice:"挑战模式正在筹备"};
    state.mode=action.mode;
    state.revision++;
    if (action.mode === "campaign") { state.screen="campaign"; return {}; }
    return {launch:{kind:"teaching",title:"教学"}};
  }
  if (action.type === "back") { state.screen="lobby"; state.hoverId=null; state.revision++; return {}; }
  if (action.type === "chapter") {
    const open=campOpenChapters(state), current=open.indexOf(state.chapter);
    state.chapter=open[(current + action.step + open.length)%open.length];
    if (campLevelStatus(state,state.level)==="locked") state.level=0;
    state.hoverId=null; state.revision++; return {};
  }
  if (action.type === "chooseChapter") {
    if(!Number.isInteger(action.index) || !campOpenChapters(state).includes(action.index)) return {notice:"这个主题尚未开放"};
    state.chapter=action.index;
    if(campLevelStatus(state,state.level)==="locked")state.level=0;
    state.hoverId=null; state.revision++; return {};
  }
  if (action.type === "level") {
    if (!Number.isInteger(action.index) || action.index<0 || action.index>5 || campLevelStatus(state,action.index)==="locked") return {notice:"这条路线尚未开放"};
    state.level=action.index; state.hoverId=null; state.revision++; return {};
  }
  if (action.type === "launch") {
    if (campLevelStatus(state,state.level)==="locked") return {notice:"这条路线尚未开放"};
    const level=UI_CHAPTERS[state.chapter].levels[state.level];
    return {launch:{kind:"campaign",chapter:UI_CHAPTERS[state.chapter].id,id:level.id,title:level.title}};
  }
  return {};
}
function campKey(state, key) {
  if (key === "Escape" && state.screen === "campaign") return campAction(state,{type:"back"});
  if (key === "Enter" || key === " ") {
    const mode=state.screen==="lobby" && ["teaching","campaign"].includes(state.hoverId)?state.hoverId:state.mode;
    if(state.hoverId){state.hoverId=null;state.revision++;}
    return campAction(state,state.screen==="campaign"?{type:"launch"}:{type:"mode",mode});
  }
  if (["PageUp","PageDown"].includes(key) && state.screen === "campaign") return campAction(state,{type:"chapter",step:key==="PageUp"?-1:1});
  if (!["ArrowLeft","ArrowRight","ArrowUp","ArrowDown","Home","End"].includes(key)) return null;
  const step=["ArrowLeft","ArrowUp"].includes(key)?-1:1;
  if (state.screen === "lobby") {
    state.hoverId=null;
    state.mode=key==="Home"?"teaching":key==="End"?"campaign":state.mode==="campaign"?"teaching":"campaign";
    state.revision++; return {};
  }
  const open=[0,1,2,3,4,5].filter(i => campLevelStatus(state,i)!=="locked");
  const at=open.indexOf(state.level);
  const index=key==="Home"?open[0]:key==="End"?open[open.length-1]:open[(at+step+open.length)%open.length];
  return campAction(state,{type:"level",index});
}
