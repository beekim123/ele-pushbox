// First-screen presentation of the current edits. Uses the same live renderers
// and preview state as the asset library and enlarged viewer.
function setWorkbenchView(view) {
  const showcase=view!=="library";
  if(document.documentElement.dataset.inspectorOpen==="true")setInspectorOpen(false);
  document.documentElement.dataset.workbenchView=showcase?"showcase":"library";
  document.getElementById("campShowcase").hidden=!showcase;
  document.getElementById("assetLibrary").hidden=showcase;
  for(const [id,active] of [["showcaseViewButton",showcase],["libraryViewButton",!showcase]]) {
    const button=document.getElementById(id);
    button.classList.toggle("active",active);
    button.setAttribute("aria-pressed",String(active));
  }
}

function syncCampShowcase() {
  const select=document.getElementById("showcaseChapterSelect"),open=campOpenChapters(campPreviewState);
  select.innerHTML="";
  UI_CHAPTERS.forEach((chapter,i)=>{
    const option=document.createElement("option");
    option.value=String(i);option.textContent=chapter.name;option.disabled=!open.includes(i);
    select.appendChild(option);
  });
  select.value=String(campPreviewState.chapter);
  document.getElementById("showcaseProgressSelect").value=campPreviewState.preset;
  const play=document.getElementById("showcasePlayPause");
  play.textContent=isPlaying?"暂停动画":"播放动画";
  play.setAttribute("aria-pressed",String(isPlaying));
}

function renderCampShowcase(time) {
  if(document.getElementById("campShowcase").hidden)return;
  for(const [id,type] of [["showcaseLobbyCanvas","ui_lobby"],["showcaseCampaignCanvas","ui_campaign"]]) {
    const canvas=document.getElementById(id),key=campFrameKey(type,time);
    if(canvas.dataset.uiFrameKey===key)continue;
    renderUIPreviewToCtx(canvas.getContext("2d"),type,time);
    canvas.dataset.uiFrameKey=key;
  }
  const miner=ASSET_CATALOG.find(item=>item.id==="miner_dig");
  const frame=Math.floor(time*miner.fps)%miner.frames.length;
  for(const [id,index,scale] of [["showcaseMinerCanvas",frame,6],
    ["showcaseMinerFrame0",0,4],["showcaseMinerFrame1",1,4],["showcaseMinerFrame2",2,4]]) {
    const canvas=document.getElementById(id),key=index+":"+campPreviewState.revision;
    if(canvas.dataset.spriteFrameKey===key)continue;
    const ctx=canvas.getContext("2d");
    ctx.clearRect(0,0,canvas.width,canvas.height);
    drawMatrixOnCtx(ctx,miner.frames[index],0,0,scale);
    canvas.dataset.spriteFrameKey=key;
  }
}

function initCampShowcase() {
  document.getElementById("showcaseViewButton").addEventListener("click",()=>setWorkbenchView("showcase"));
  document.getElementById("libraryViewButton").addEventListener("click",()=>setWorkbenchView("library"));
  document.getElementById("showcaseChapterSelect").addEventListener("change",event=>
    campViewerDispatch({type:"chooseChapter",index:Number(event.target.value)}));
  document.getElementById("showcaseProgressSelect").addEventListener("change",event=>{
    campPreset(campPreviewState,event.target.value);campViewerControls();
  });
  document.getElementById("showcasePlayPause").addEventListener("click",togglePlay);
  document.getElementById("showcaseLobbyOpen").addEventListener("click",()=>openCampViewer("ui_lobby"));
  document.getElementById("showcaseCampaignOpen").addEventListener("click",()=>openCampViewer("ui_campaign"));
  document.getElementById("showcaseMinerInspect").addEventListener("click",()=>{
    // Keep the return target visible when the narrow inspector opens next.
    document.getElementById("libraryViewButton").focus();
    setWorkbenchView("library");
    selectAssetForInspector(ASSET_CATALOG.find(item=>item.id==="miner_dig"));
  });
  setWorkbenchView("showcase");syncCampShowcase();
}
