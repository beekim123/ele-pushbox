// Workbench interaction only; launch intents never execute or save a game.
let campViewerLastFrame = "";
let campViewerReturnFocus = null;

function campFrameKey(type,time,state=campPreviewState) {
  return type+":"+state.revision+":"+Math.floor(time*8);
}
function campExport(type,state=campPreviewState) {
  return {
    design:"mine-camp-v1", screen:type, viewport:[320,180],
    chapter:UI_CHAPTERS[state.chapter].id,
    level:UI_CHAPTERS[state.chapter].levels[state.level],
    mode:state.mode, preset:state.preset, open_all:state.openAll,
    completed:state.progress[state.chapter].slice(),
    font:{source:"Fusion Pixel 12px",height:CAMP_FONT.height,baseline:CAMP_FONT.baseline},
    regions:campRegions(type,state)
  };
}
function campViewerType() {
  return campPreviewState.screen==="lobby"?"ui_lobby":"ui_campaign";
}
function campViewerControls() {
  document.getElementById("uiScreenSelect").value=campPreviewState.screen;
  document.getElementById("uiProgressSelect").value=campPreviewState.preset;
  const select=document.getElementById("uiChapterSelect"),open=campOpenChapters(campPreviewState);
  select.innerHTML="";
  UI_CHAPTERS.forEach((chapter,i)=>{
    const option=document.createElement("option");
    option.value=String(i);option.textContent=chapter.name;option.disabled=!open.includes(i);
    select.appendChild(option);
  });
  select.value=String(campPreviewState.chapter);
  const level=UI_CHAPTERS[campPreviewState.chapter].levels[campPreviewState.level];
  document.getElementById("uiFocusCanvas").setAttribute("aria-label",campPreviewState.screen==="lobby"?"矿井营地，当前选择"+(campPreviewState.mode==="teaching"?"教学":"闯关"):UI_CHAPTERS[campPreviewState.chapter].name+"，"+level.title);
  if(selectedAsset && selectedAsset.renderType && selectedAsset.renderType.startsWith("ui_"))updateInspectorCode();
  if(typeof syncCampShowcase==="function")syncCampShowcase();
}
function campViewerDispatch(action) {
  const result=campAction(campPreviewState,action);
  const status=document.getElementById("uiFocusStatus");
  if(result.launch)status.textContent="已选择："+result.launch.title+"。此处仅预演界面，不会启动游戏。";
  else if(result.notice)status.textContent=result.notice;
  else status.textContent="通关状态为示例，不会写入游戏存档。";
  campViewerControls();
}
function campFitViewer() {
  const canvas=document.getElementById("uiFocusCanvas");
  const scale=Math.max(1,Math.min(3,Math.floor((window.innerWidth-72)/320),Math.floor((window.innerHeight-245)/180)));
  canvas.style.width=(320*scale)+"px";canvas.style.height=(180*scale)+"px";
}
function openCampViewer(type) {
  const dialog=document.getElementById("uiFocusDialog");
  campViewerReturnFocus=document.activeElement;
  campPreviewState.screen=type==="ui_campaign"?"campaign":"lobby";
  campPreviewState.hoverId=null;campPreviewState.revision++;
  campViewerControls();campFitViewer();dialog.showModal();
  document.getElementById("uiFocusStatus").textContent="通关状态为示例，不会写入游戏存档。";
  document.getElementById("uiFocusCanvas").focus();
}
function renderCampViewer(time) {
  const dialog=document.getElementById("uiFocusDialog");
  if(!dialog.open)return;
  const type=campViewerType(),key=campFrameKey(type,time);
  if(key===campViewerLastFrame)return;
  campViewerLastFrame=key;
  renderUIPreviewToCtx(document.getElementById("uiFocusCanvas").getContext("2d"),type,time);
}
function syncCampInspector(item) {
  const isUI=!!item.renderType && item.renderType.startsWith("ui_");
  document.getElementById("uiOpenPreview").hidden=!isUI;
}
function initCampViewer() {
  const dialog=document.getElementById("uiFocusDialog"),canvas=document.getElementById("uiFocusCanvas");
  document.getElementById("uiOpenPreview").addEventListener("click",()=>openCampViewer(selectedAsset.renderType));
  document.getElementById("uiClosePreview").addEventListener("click",()=>dialog.close());
  document.getElementById("uiScreenSelect").addEventListener("change",event=>{
    campPreviewState.screen=event.target.value==="campaign"?"campaign":"lobby";
    campPreviewState.hoverId=null;campPreviewState.revision++;campViewerControls();canvas.focus();
  });
  document.getElementById("uiChapterSelect").addEventListener("change",event=>campViewerDispatch({type:"chooseChapter",index:Number(event.target.value)}));
  document.getElementById("uiProgressSelect").addEventListener("change",event=>{
    campPreset(campPreviewState,event.target.value);campViewerControls();
  });
  for(const [id,key] of [["uiPreviousItem","ArrowLeft"],["uiNextItem","ArrowRight"],["uiActivateItem","Enter"]]) {
    document.getElementById(id).addEventListener("click",()=>{
      const result=campKey(campPreviewState,key);
      campViewerControls();
      document.getElementById("uiFocusStatus").textContent=result && result.launch?"已选择："+result.launch.title+"。此处仅预演界面。":"通关状态为示例，不会写入游戏存档。";
    });
  }
  document.getElementById("uiBackToCamp").addEventListener("click",()=>campViewerDispatch({type:"back"}));
  canvas.addEventListener("pointermove",event=>{
    const point=campPoint(event.clientX,event.clientY,canvas.getBoundingClientRect());
    const hit=point && campHit(campViewerType(),campPreviewState,point.x,point.y);
    const id=hit?hit.id:null;
    if(id!==campPreviewState.hoverId){campPreviewState.hoverId=id;campPreviewState.revision++;}
    canvas.style.cursor=hit?(hit.disabled?"not-allowed":"pointer"):"default";
  });
  canvas.addEventListener("pointerleave",()=>{
    if(campPreviewState.hoverId){campPreviewState.hoverId=null;campPreviewState.revision++;}
  });
  canvas.addEventListener("click",event=>{
    const point=campPoint(event.clientX,event.clientY,canvas.getBoundingClientRect());
    const hit=point && campHit(campViewerType(),campPreviewState,point.x,point.y);
    if(hit)campViewerDispatch(hit.action);
    canvas.focus();
  });
  dialog.addEventListener("keydown",event=>{
    if(event.key==="Tab"){event.stopPropagation();return;}
    if(event.target!==canvas && event.key!=="Escape")return;
    if(event.key==="Escape" && campPreviewState.screen==="lobby"){
      event.preventDefault();event.stopPropagation();dialog.close();return;
    }
    const result=campKey(campPreviewState,event.key);
    if(result!==null){
      event.preventDefault();event.stopPropagation();campViewerControls();
      if(result.launch)document.getElementById("uiFocusStatus").textContent="已选择："+result.launch.title+"。此处仅预演界面。";
    }
  });
  dialog.addEventListener("close",()=>{
    campPreviewState.hoverId=null;campPreviewState.revision++;
    if(campViewerReturnFocus && campViewerReturnFocus.isConnected)campViewerReturnFocus.focus();
  });
  if(window.addEventListener)window.addEventListener("resize",campFitViewer);
  campViewerControls();
}
