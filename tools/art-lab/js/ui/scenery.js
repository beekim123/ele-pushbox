function campCloud(ctx,x,y,w,shade="v") {
  campRect(ctx,x+3,y+5,w-6,8,shade);
  campRect(ctx,x+9,y+1,w-18,10,shade);
  campRect(ctx,x+16,y-2,w-33,8,shade);
  campRect(ctx,x+5,y+4,w-10,5,"u");
}
function campTree(ctx,x,y,height,near=false) {
  const wood=near?"g":"p",leaf=near?"p":"o";
  campPoly(ctx,[[x,y],[x+8,y-2],[x+11,y+height],[x-4,y+height],[x+1,y+height-12]],wood);
  if(near) {
    campRect(ctx,x+3,y+7,2,height-12,"f");
    campLine(ctx,[x+4,y+26],[x+16,y+14],"g",3);
  }
  campPoly(ctx,[[x-23,y+5],[x-16,y-8],[x-5,y-11],[x+5,y-21],[x+23,y-14],[x+31,y+2],[x+21,y+14],[x+5,y+17],[x-11,y+11]],leaf);
  if(near) {
    campRect(ctx,x-13,y-6,12,3,"o");campRect(ctx,x+9,y-11,13,3,"o");
    campRect(ctx,x+18,y+7,8,2,"o");
  } else {
    campLine(ctx,[x+5,y+30],[x-8,y+13],"p",2);
    campLine(ctx,[x+6,y+21],[x+16,y+10],"p",2);
  }
}
function campCrystal(ctx,x,y,height,t) {
  const lit=Math.floor(t*2)%4<2;
  campPoly(ctx,[[x,y],[x+3,y-height],[x+8,y-height-5],[x+12,y-2],[x+7,y+2]],"q");
  campPoly(ctx,[[x+3,y-1],[x+4,y-height],[x+7,y-height-3],[x+7,y]],lit?"r":"q");
  campLine(ctx,[x+7,y-height-3],[x+10,y-3],lit?"s":"r");
  campPoly(ctx,[[x-5,y],[x-9,y-12],[x-5,y-15],[x+2,y]],"B");
  campLine(ctx,[x-6,y-12],[x-2,y-2],"C");
}
function campGround(ctx,theme,type) {
  const colors=CAMP_THEMES[theme];
  if(theme===4) {
    if(type==="ui_lobby") for(const [x,w,y] of [[12,83,142],[113,94,141],[226,85,146]]) {
      campPoly(ctx,[[x,y],[x+w,y],[x+w-6,y+11],[x+w/2,y+29],[x+8,y+12]],"v");
      campRect(ctx,x,y,w,3,"u");campRect(ctx,x+3,y, w-6,1,"t");
      campCloud(ctx,x+8,y+13,w-15,"v");
    }
    return;
  }
  campPoly(ctx,[[0,147],[28,147],[28,143],[94,143],[94,146],[124,146],[124,142],[205,142],[205,147],[254,147],[254,144],[320,144],[320,180],[0,180]],colors.ground);
  for(const [x,w,y] of [[0,28,147],[28,66,143],[94,30,146],[124,81,142],[205,49,147],[254,66,144]]) {
    campRect(ctx,x,y,w,2,colors.trim);
  }
  if(theme===5) {
    for(let x=2;x<320;x+=16) {
      campRect(ctx,x,149,11,1,"x");campRect(ctx,x+2,151,2,2,"w");
    }
  } else {
    for(let i=0;i<20;i++) {
      const x=h32(i,7,4)%320,y=153+h32(i,8,3)%22;
      campRect(ctx,x,y,2+h32(i,9)%4,1,theme===2?"e":"f");
    }
  }
}
function campBackdrop(ctx,theme,t,type) {
  const c=CAMP_THEMES[theme],tick=Math.floor(t*8);
  campRect(ctx,0,0,320,180,c.sky);
  if(theme===1) {
    campPoly(ctx,[[0,66],[38,43],[81,55],[114,34],[163,61],[207,36],[256,54],[296,33],[320,59],[320,145],[0,145]],"o");
    for(const [x,y,h] of [[33,47,99],[96,63,88],[181,43,107],[255,58,94]])campTree(ctx,x,y,h);
    campRect(ctx,19,94,93,7,"p");campRect(ctx,206,104,88,6,"p");
    campPoly(ctx,[[142,146],[150,105],[149,78],[136,57],[119,48],[120,44],[143,49],[155,63],[158,33],[168,27],[174,60],[191,43],[215,37],[215,41],[194,51],[177,79],[182,114],[192,145]],"g");
    campPoly(ctx,[[155,133],[159,103],[157,78],[162,45],[166,39],[168,77],[166,105],[172,144]],"f");
    campPoly(ctx,[[88,24],[106,10],[135,12],[154,3],[181,12],[207,9],[234,26],[227,42],[205,47],[181,38],[162,47],[144,37],[119,42],[100,34]],"p");
    campRect(ctx,116,19,17,3,"o");campRect(ctx,182,17,22,3,"o");campRect(ctx,206,35,12,2,"o");
    campTree(ctx,4,9,143,true);campTree(ctx,306,2,151,true);
    campPoly(ctx,[[224,128],[256,124],[283,133],[320,132],[320,180],[245,180],[252,154]],"q");
    for(let i=0;i<5;i++) {
      const x=254+(i*13+Math.floor(t*6))%65;
      campRect(ctx,x,146+i*5,9,1,i%2?"r":"s");
    }
    for(let i=0;i<4;i++)campRect(ctx,35+(i*71+Math.floor(t*5))%255,51+(i*29+tick)%85,2,1,"n");
  } else if(theme===0) {
    campPoly(ctx,[[0,16],[31,23],[49,8],[91,12],[112,31],[145,15],[189,9],[225,27],[261,12],[297,25],[320,13],[320,151],[0,151]],"y");
    for(const [x,y,w] of [[13,56,63],[100,39,60],[223,49,72]]) {
      campPoly(ctx,[[x,y+19],[x+10,y+4],[x+w-13,y],[x+w,y+17],[x+w,y+90],[x,y+90]],"x");
      campPoly(ctx,[[x+6,y+21],[x+16,y+10],[x+w-17,y+9],[x+w-7,y+22],[x+w-7,y+90],[x+6,y+90]],"y");
    }
    campRect(ctx,22,44,4,99,"g");campRect(ctx,289,37,5,111,"g");
    for(let i=0;i<5;i++)campRect(ctx,22,49+i*18,4,2,"f");
    campSprite(ctx,"dungeon_bat",Math.floor(t*2),270,32);
    campPoly(ctx,[[0,132],[37,128],[65,141],[101,130],[135,138],[192,125],[235,139],[288,126],[320,132],[320,155],[0,155]],"x");
  } else if(theme===2) {
    campEllipse(ctx,242,38,20,20,"f");
    campEllipse(ctx,242,38,13,13,"e");
    campPoly(ctx,[[81,129],[104,102],[120,102],[120,88],[143,88],[143,72],[162,72],[162,56],[181,56],[181,72],[199,72],[199,88],[221,88],[221,104],[241,104],[268,130]],"f");
    for(const x of [16,75,264,304]) {
      campRect(ctx,x,50,9,92,"f");campRect(ctx,x-3,48,15,5,"e");
      campRect(ctx,x+2,55,2,80,"e");campRect(ctx,x-2,137,14,5,"e");
    }
    for(let i=0;i<9;i++)campRect(ctx,38+i*31,129+(i%3)*4,18,1,"e");
    for(let i=0;i<4;i++)campRect(ctx,91+i*42,39+((tick+i*17)%84),1,2,"e");
  } else if(theme===3) {
    campPoly(ctx,[[0,0],[320,0],[320,64],[303,43],[294,74],[280,31],[269,52],[251,16],[234,40],[214,14],[201,50],[185,16],[169,35],[153,11],[136,43],[119,15],[103,54],[91,17],[69,43],[50,14],[35,63],[19,29],[0,55]],"y");
    campPoly(ctx,[[0,32],[14,39],[24,77],[33,47],[43,85],[43,140],[0,151]],"p");
    campPoly(ctx,[[270,123],[288,58],[302,69],[311,34],[320,53],[320,152]],"p");
    campCrystal(ctx,39,135,23,t);campCrystal(ctx,282,126,28,t+1);
    campEllipse(ctx,246,149,49,13,"q");
    campRect(ctx,218,146,45,1,"r");campRect(ctx,252,152,18,1,"r");
    if(tick%9===0)campRect(ctx,83,83+(tick%5)*5,1,2,"s");
    campSprite(ctx,"cave_moth",Math.floor(t*5),264+Math.round(Math.sin(t)*4),81);
  } else if(theme===4) {
    campRect(ctx,0,50,320,52,"B");campRect(ctx,0,102,320,78,"C");
    for(let x=0;x<320;x+=4) {
      campRect(ctx,x,48,2,2,"B");campRect(ctx,x+2,100,2,2,"C");
    }
    for(let i=0;i<4;i++)campCloud(ctx,((i*99+Math.floor(t*2))%410)-45,63+(i%2)*22,71,"w");
    for(let i=0;i<3;i++)campCloud(ctx,((i*137+Math.floor(t*5))%440)-59,132+(i%2)*14,91,"v");
    campEllipse(ctx,241,57,11,11,"E");
  } else {
    for(let i=0;i<32;i++) {
      const x=h32(i,3,7)%320,y=h32(i,9,11)%140;
      campRect(ctx,x,y,1,1,(tick+i)%13===0?"s":"w");
    }
    campPoly(ctx,[[0,0],[320,0],[320,22],[301,22],[301,9],[19,9],[19,27],[0,27]],"y");
    campRect(ctx,9,28,3,108,"x");campRect(ctx,308,29,3,110,"x");
    for(const x of [53,143,233]) {
      campRect(ctx,x,34,42,2,"y");campRect(ctx,x+17,34,2,82,"y");
      campLine(ctx,[x+1,37],[x+17,53],"y");
    }
    campEllipse(ctx,245,89,31,31,"y");campEllipse(ctx,245,89,28,28,"z");
    campSprite(ctx,"cosmos_drone",Math.floor(t*3),271,58+Math.round(Math.sin(t)*2));
  }
  campGround(ctx,theme,type);
}
function campLamp(ctx,x,y,t,bright=false) {
  campRect(ctx,x+2,y-5,1,5,"f");
  campRect(ctx,x,y,5,8,"z");campRect(ctx,x+1,y+1,3,5,"k");
  campRect(ctx,x+2,y+2,1,3,"l");
  if(bright && Math.floor(t*3)%3!==0) {
    campRect(ctx,x-2,y+3,1,1,"e");campRect(ctx,x+6,y+3,1,1,"e");
  }
}
function campMine(ctx,x,y,theme,t,selected) {
  const c=CAMP_THEMES[theme];
  campPoly(ctx,[[x,y+23],[x+5,y+12],[x+17,y+3],[x+29,y],[x+43,y+1],[x+56,y+11],[x+64,y+25],[x+64,y+65],[x,y+65]],"z");
  campPoly(ctx,[[x+2,y+24],[x+7,y+13],[x+18,y+5],[x+29,y+2],[x+42,y+3],[x+54,y+13],[x+62,y+25],[x+62,y+64],[x+2,y+64]],c.rock);
  campEllipse(ctx,x+32,y+26,22,19,"z");campRect(ctx,x+10,y+26,44,38,"z");
  campRect(ctx,x+21,y+33,22,28,"y");campRect(ctx,x+27,y+39,10,24,"g");
  campRect(ctx,x+7,y+27,4,37,c.rim);campRect(ctx,x+53,y+27,5,37,c.rock);
  for(const [px,py,w] of [[8,14,8],[18,7,10],[29,3,10],[42,7,10]]) {
    campRect(ctx,x+px,y+py,w,2,c.rim);
    campRect(ctx,x+px+w,y+py+2,1,5,c.sky);
  }
  for(let row=0;row<3;row++) {
    campRect(ctx,x+2,y+31+row*11,8,1,c.sky);
    campRect(ctx,x+55,y+29+row*11,7,1,c.sky);
  }
  campRect(ctx,x+11,y+25,4,38,"f");campRect(ctx,x+49,y+25,4,38,"f");
  campRect(ctx,x+11,y+23,42,4,"f");campRect(ctx,x+12,y+23,40,1,"e");
  campLine(ctx,[x+27,y+51],[x+18,y+72],"w");
  campLine(ctx,[x+38,y+51],[x+49,y+72],"w");
  for(let i=0;i<4;i++)campRect(ctx,x+24-i*2,y+53+i*5,19+i*4,2,"f");
  campLamp(ctx,x+30,y+11,t,selected);
  if(selected)campMarker(ctx,x+32,y-9+Math.floor(t*2)%2);
}
function campPractice(ctx,x,y,selected,t) {
  campRect(ctx,x+3,y+14,3,36,"g");campRect(ctx,x+48,y+14,3,36,"g");
  campRect(ctx,x+4,y+15,1,34,"e");campRect(ctx,x+49,y+15,1,34,"e");
  campPoly(ctx,[[x-3,y+13],[x+5,y+1],[x+46,y],[x+56,y+12],[x+54,y+17],[x-1,y+17]],"g");
  campPoly(ctx,[[x-1,y+12],[x+6,y+3],[x+45,y+2],[x+53,y+12],[x+49,y+14],[x+3,y+14]],"c");
  campRect(ctx,x+7,y+12,37,3,"F");
  campRect(ctx,x+7,y+26,37,3,"f");campRect(ctx,x+8,y+25,35,1,"e");
  campRect(ctx,x+9,y+30,32,3,"f");
  campRect(ctx,x+12,y+28,2,20,"g");campRect(ctx,x+38,y+28,2,20,"g");
  campRect(ctx,x+10,y+20,15,5,"c");campRect(ctx,x+17,y+20,1,5,"F");
  campRect(ctx,x+12,y+22,4,1,"e");campRect(ctx,x+19,y+22,4,1,"e");
  campPoly(ctx,[[x+27,y+24],[x+31,y+18],[x+35,y+18],[x+41,y+24]],"d");
  campRect(ctx,x+8,y+40,15,8,"q");campRect(ctx,x+10,y+40,11,2,"s");
  campSprite(ctx,"crate_wood_dungeon",0,x+33,y+34);
  if(selected)campMarker(ctx,x+26,y-10+Math.floor(t*2)%2);
}
function campClosedMine(ctx,x,y,theme) {
  const c=CAMP_THEMES[theme];
  campPoly(ctx,[[x,y+16],[x+9,y+4],[x+22,y],[x+42,y+4],[x+51,y+16],[x+51,y+43],[x,y+43]],"z");
  campPoly(ctx,[[x+2,y+17],[x+11,y+6],[x+22,y+3],[x+40,y+6],[x+49,y+17],[x+49,y+42],[x+2,y+42]],c.rock);
  campRect(ctx,x+9,y+17,33,25,"z");
  campRect(ctx,x+8,y+21,34,5,"f");campRect(ctx,x+9,y+33,33,5,"f");
  campRect(ctx,x+9,y+21,32,1,"e");campRect(ctx,x+10,y+33,30,1,"e");
  campLine(ctx,[x+10,y+20],[x+38,y+38],"g",3);
  campRect(ctx,x+24,y+26,5,6,"w");campRect(ctx,x+25,y+23,3,4,"v");
  campRect(ctx,x+26,y+24,1,2,"z");campRect(ctx,x+26,y+28,1,2,"z");
}
