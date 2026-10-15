function campLobby(ctx,t,state) {
  const theme=state.chapter, hover=state.hoverId;
  const selected=hover && ["teaching","campaign"].includes(hover)?hover:state.mode;
  campBackdrop(ctx,theme,t,"ui_lobby");
  const road=theme===5?"x":"f";
  campPoly(ctx,[[139,137],[178,137],[205,180],[109,180]],"g");
  campPoly(ctx,[[146,140],[171,140],[191,180],[124,180]],road);
  for(let i=0;i<6;i++)campRect(ctx,139-i*2,149+i*5,32+i*4,1,"g");
  campPractice(ctx,30,95,selected==="teaching",t);
  campMine(ctx,128,76,theme,t,selected==="campaign");
  campClosedMine(ctx,239,102,theme);
  if(theme===1) {
    campSprite(ctx,"forest_bird",Math.floor(t*3),92,137);
    campSprite(ctx,"flower_sway",Math.floor(t*2),8,140);
    campSprite(ctx,"forest_butterfly",Math.floor(t*6),76+Math.round(Math.sin(t)*5),74+Math.round(Math.cos(t*2)*2));
  } else if(theme===2)campSprite(ctx,"ruins_scarab",Math.floor(t*3),213,140);
  else if(theme===4)campSprite(ctx,"sky_dove",Math.floor(t*2),213,138);
  campSprite(ctx,"miner_idle",Math.floor(t*2),selected==="teaching"?83:150,selected==="teaching"?128:125);
  campText(ctx,"沙与水",17,13,"l",2,"left",true);
  campText(ctx,"推箱子",20,43,"u",1,"left",true);
  campText(ctx,UI_CHAPTERS[theme].name,306,14,"u",1,"right",true);
  campSign(ctx,27,145,61,"教学",selected==="teaching");
  campSign(ctx,130,145,61,"闯关",selected==="campaign");
  campSign(ctx,237,145,61,"挑战",false,true);
  const hint=hover==="challenge"?"挑战仍在筹备中":selected==="teaching"?"移动、挖沙与推箱":"从这里，探索沙与水";
  campText(ctx,hint,160,165,hover==="challenge"?"v":"c",1,"center");
}

function campDrawTrail(ctx,theme,state) {
  const nodes=CAMP_ROUTES[theme],colors=CAMP_THEMES[theme];
  for(let i=0;i<nodes.length-1;i++) {
    const a=[nodes[i][0]+12,nodes[i][1]+16],b=[nodes[i+1][0]+12,nodes[i+1][1]+16];
    const color=campLevelStatus(state,i)==="done"?colors.road:colors.rock;
    if(theme===5) {
      const bend=[b[0]-13,a[1]];
      campLine(ctx,a,bend,"y",4);campLine(ctx,bend,b,"y",4);
      campLine(ctx,a,bend,color,1);campLine(ctx,bend,b,color,1);
    } else {
      campLine(ctx,a,b,theme===4?"w":"g",4);campLine(ctx,a,b,color,2);
      const dx=b[0]-a[0],dy=b[1]-a[1],length=Math.max(Math.abs(dx),Math.abs(dy));
      for(let step=8;step<length;step+=10) {
        const x=Math.round(a[0]+dx*step/length),y=Math.round(a[1]+dy*step/length);
        campRect(ctx,x-1,y-1,4,1,theme===4?"c":colors.road);
      }
    }
  }
  nodes.forEach(([x,y]) => {
    if(theme===4) {
      campPoly(ctx,[[x-7,y+18],[x+31,y+18],[x+25,y+27],[x+12,y+35],[x-2,y+26]],"v");
      campRect(ctx,x-6,y+17,36,3,"u");campRect(ctx,x-3,y+17,30,1,"t");
    } else {
      campPoly(ctx,[[x-3,y+18],[x+27,y+18],[x+30,y+23],[x+24,y+27],[x,y+26],[x-5,y+23]],colors.ground);
      campRect(ctx,x-2,y+19,29,2,colors.trim);
    }
  });
}
function campDrawNode(ctx,x,y,index,t,state) {
  const status=campLevelStatus(state,index);
  const selected=index===state.level,hover=state.hoverId==="level-"+index;
  campRect(ctx,x+10,y+13,4,12,"g");campRect(ctx,x+11,y+15,1,9,"e");
  campPoly(ctx,[[x+2,y+1],[x+21,y],[x+24,y+3],[x+23,y+17],[x+3,y+19],[x,y+16],[x,y+4]],"z");
  campRect(ctx,x+2,y+3,20,13,status==="locked"?"y":selected?"f":"g");
  campRect(ctx,x+3,y+2,18,1,selected?"k":status==="locked"?"x":"e");
  campRect(ctx,x+3,y+16,17,1,status==="locked"?"x":"f");
  campRect(ctx,x+3,y+5,1,1,"f");campRect(ctx,x+20,y+13,1,1,"f");
  if(hover && status!=="locked")campRect(ctx,x+5,y+1,14,1,"l");
  campText(ctx,String(index+1).padStart(2,"0"),x+12,y+3,selected?"l":status==="locked"?"w":"u",1,"center");
  if(status==="done") {
    campRect(ctx,x+21,y-5,1,11,"f");
    campPoly(ctx,[[x+22,y-5],[x+28,y-5],[x+26,y-2],[x+28,y+1],[x+22,y+1]],"k");
    campRect(ctx,x+23,y-4,3,1,"l");
  } else if(status==="locked") {
    campRect(ctx,x+8,y-4,7,6,"x");campRect(ctx,x+9,y-7,5,4,"w");
    campRect(ctx,x+10,y-6,3,2,"z");
  }
  if(selected) {
    const c=CAMP_THEMES[state.chapter];
    campRect(ctx,x-13,y+22,15,4,c.ground);campRect(ctx,x-12,y+22,13,1,c.trim);
    campSprite(ctx,"miner_idle",Math.floor(t*2),x-15,y+7);
  }
}
function campCampaign(ctx,t,state) {
  const theme=state.chapter,c=CAMP_THEMES[theme];
  campBackdrop(ctx,theme,t,"ui_campaign");
  if(theme===1) {
    campSprite(ctx,"flower_sway",Math.floor(t*2),48,130);
    campSprite(ctx,"forest_bird",Math.floor(t*3),215,126);
  }
  campDrawTrail(ctx,theme,state);
  CAMP_ROUTES[theme].forEach(([x,y],i)=>campDrawNode(ctx,x,y,i,t,state));
  // This foreground ledge belongs to the scene, rather than a floating UI card.
  campPoly(ctx,[[0,148],[31,148],[31,145],[111,145],[111,149],[202,149],[202,146],[320,146],[320,180],[0,180]],theme===4?"x":c.ground);
  campRect(ctx,0,148,30,1,c.trim);campRect(ctx,33,145,76,1,c.trim);campRect(ctx,205,146,115,1,c.trim);
  campText(ctx,"营地",18,11,state.hoverId==="back"?"l":"u",1,"center",true);
  const chapterNavigation=campOpenChapters(state).length>1;
  campChevron(ctx,53,14,-1,chapterNavigation?(state.hoverId==="previous"?"l":"u"):"x");
  campChevron(ctx,255,14,1,chapterNavigation?(state.hoverId==="next"?"l":"u"):"x");
  campText(ctx,UI_CHAPTERS[theme].name,157,11,"l",1,"center",true);
  const cleared=state.progress[theme].length;
  if(cleared>=6) {
    campPoly(ctx,[[277,11],[280,14],[281,10],[283,14],[286,11],[285,18],[278,18]],"k");
    campRect(ctx,279,16,5,1,"l");
  } else if(cleared>=3) {
    campRect(ctx,281,9,1,3,"w");campRect(ctx,278,12,7,7,"w");
    campRect(ctx,279,13,5,4,"u");campRect(ctx,281,13,1,3,"t");
  }
  campText(ctx,state.progress[theme].length+"/6",307,11,"u",1,"right",true);
  const level=UI_CHAPTERS[theme].levels[state.level];
  campText(ctx,String(state.level+1).padStart(2,"0"),12,154,"k");
  campText(ctx,level.title,35,154,"u",1,"left",true);
  const locked=campLevelStatus(state,state.level)==="locked";
  campSign(ctx,260,151,49,locked?"未开放":"进入",state.hoverId==="enter",locked);
}
function renderUIPreviewToCtx(ctx,type,t,state=campPreviewState) {
  if(type==="ui_lobby")campLobby(ctx,t,state);
  else if(type==="ui_campaign")campCampaign(ctx,t,state);
}
