shader_type canvas_item;
render_mode unshaded;

// A whole-world sampler crosses SDK tile x=256 before finding neighbours.
// map_texture is the explicit grid oracle; sdk textures are actual cell IDs.
uniform sampler2D map_texture : filter_nearest, repeat_disable;
uniform sampler2D sdk_left : filter_nearest, repeat_disable;
uniform sampler2D sdk_right : filter_nearest, repeat_disable;
uniform bool sdk_mode = false;
uniform bool cell_image_mode = false;
uniform ivec2 grid_size = ivec2(20, 10);
uniform ivec2 sdk_size = ivec2(320, 192);
uniform ivec2 left_origin = ivec2(0);
uniform ivec2 right_origin = ivec2(256, 0);
uniform int rock_id = 1;
uniform int cracked_id = -1;
uniform int earth_id = 2;
uniform int sand_id = 3;
uniform int water_id = -1;
uniform int rock_pattern = 0; // brick/block/rough/grass/marble/cloud/panel
uniform bool hazard_trim = false;
uniform int colors[37];
uniform int visual_tick = 0;
uniform int vignette_width = 0;
uniform ivec2 screen_origin = ivec2(0);
uniform bool observe = false;
uniform int background_dim_steps = 0;

const vec4 PAL[33] = vec4[33](
 vec4(0.0), vec4(190,74,47,255)/255.0, vec4(215,118,67,255)/255.0,
 vec4(234,212,170,255)/255.0, vec4(228,166,114,255)/255.0,
 vec4(184,111,80,255)/255.0, vec4(115,62,57,255)/255.0, vec4(62,39,49,255)/255.0,
 vec4(162,38,51,255)/255.0, vec4(228,59,68,255)/255.0, vec4(247,118,34,255)/255.0,
 vec4(254,174,52,255)/255.0, vec4(254,231,97,255)/255.0, vec4(99,199,77,255)/255.0,
 vec4(62,137,72,255)/255.0, vec4(38,92,66,255)/255.0, vec4(25,60,62,255)/255.0,
 vec4(18,78,137,255)/255.0, vec4(0,153,219,255)/255.0, vec4(44,232,245,255)/255.0,
 vec4(255,255,255,255)/255.0, vec4(192,203,220,255)/255.0,
 vec4(139,155,180,255)/255.0, vec4(90,105,136,255)/255.0,
 vec4(58,68,102,255)/255.0, vec4(38,43,68,255)/255.0, vec4(24,20,37,255)/255.0,
 vec4(255,0,68,255)/255.0, vec4(104,56,108,255)/255.0,
 vec4(181,80,136,255)/255.0, vec4(246,117,122,255)/255.0,
 vec4(232,183,150,255)/255.0, vec4(194,133,105,255)/255.0);
const int DIM[33] = int[33](0,6,5,22,32,6,7,26,7,8,1,2,11,14,15,16,26,25,17,18,21,22,23,24,25,26,26,8,7,28,29,32,5);
const int BAYER[16] = int[16](0,8,2,10,12,4,14,6,3,11,1,9,15,7,13,5);

uint h32(int x, int y, int seed) {
 uint n = uint(x)*374761393u + uint(y)*668265263u + uint(seed)*2147483647u;
 n = (n ^ (n >> 13u))*1274126177u;
 return n ^ (n >> 16u);
}

ivec2 raw_cell(ivec2 p) {
 if (p.x < 0 || p.y < 0 || p.x >= sdk_size.x || p.y >= sdk_size.y) return ivec2(0);
 vec4 raw;
 if (cell_image_mode) raw = texelFetch(map_texture,p,0);
 else if (p.x >= right_origin.x) raw = texelFetch(sdk_right,p-right_origin,0);
 else raw = texelFetch(sdk_left,p-left_origin,0);
 ivec2 rg = ivec2(round(raw.rg*255.0));
 return ivec2(rg.x + ((rg.y & 15)<<8), (rg.y >> 4)&3);
}

int mat_at(ivec2 p) {
 if (!sdk_mode) {
  ivec2 t=ivec2(floor(vec2(p)/16.0));
  if (t.x<0 || t.y<0 || t.x>=grid_size.x || t.y>=grid_size.y) return 0;
  return int(round(texelFetch(map_texture,t,0).r*255.0));
 }
 int id=raw_cell(p).x;
 if (id==rock_id) return 1;
 if (id==cracked_id) return 2;
 if (id==earth_id) return 3;
 if (id==sand_id) return 4;
 if (id==water_id) return 5;
 return 0; // Entities and gates are rendered from approved sprites.
}

bool crack(ivec2 tile, int px, int py) {
 if (px<0 || px>15) return false;
 uint a=h32(tile.x,tile.y,91);
 int x0=3+int(a%6u), x1=6+int((a>>4u)%6u), x2=4+int((a>>8u)%8u);
 if (py>=0 && py<=8 && px==int(floor(float(x0)+float((x1-x0)*py)/8.0+0.5))) return true;
 if (py>=8 && py<=15 && px==int(floor(float(x1)+float((x2-x1)*(py-8))/7.0+0.5))) return true;
 return py>=8 && py<=11 && px==x1+(((a>>12u)%2u)!=0u?1:-1)*(py-8);
}

int block_frame(int c, ivec2 p, ivec4 n, int self, int frame, int bevel) {
 if (frame==0) return c;
 if ((p.x==0 && n.z!=self)||(p.x==15 && n.w!=self)||(p.y==0 && n.x!=self)||(p.y==15 && n.y!=self)) return frame;
 if (bevel!=0 && ((p.x==1 && n.z!=self)||(p.y==1 && n.x!=self))) return bevel;
 return c;
}

bool empty_cloud(int m) { return m==0 || m==5; }
int cloud(ivec2 w, ivec2 p, ivec4 n) {
 bool u=n.x==0, d=n.y==0, l=n.z==0, r=n.w==0;
 if ((u&&l&&p.x+p.y<4)||(u&&r&&15-p.x+p.y<4)||(d&&l&&p.x+15-p.y<4)||(d&&r&&30-p.x-p.y<4)) return 0;
 int top=int(h32(w.x>>2,0,33)%2u), bottom=1+int(h32(w.x>>2,1,33)%3u);
 if (empty_cloud(n.x)&&p.y<top) return 0;
 if (empty_cloud(n.y)&&p.y>15-bottom) return 0;
 if (empty_cloud(n.z)&&p.x<int(h32(0,w.y>>2,35)%2u)) return 0;
 if (empty_cloud(n.w)&&p.x>15-int(h32(1,w.y>>2,35)%2u)) return 0;
 int c=colors[0], layer=w.y>>3, scallop=6-int(h32(w.x>>2,layer,39)%3u);
 if ((w.y&7)>=scallop && (w.y&7)<=scallop+1 && h32(w.x>>3,layer,41)%4u!=0u) c=colors[1];
 if (empty_cloud(n.y)) { int from_bottom=15-bottom-p.y; if (from_bottom<=0) c=colors[6]; else if (from_bottom<=3) c=colors[1]; }
 if (empty_cloud(n.w)&&p.x>=14) c=c==colors[6]?colors[6]:colors[1];
 if (empty_cloud(n.x)&&p.y==top) c=colors[4];
 return c;
}

int rock(ivec2 w, ivec2 p, ivec4 n, uint hash) {
 bool open_up=n.x==0 || n.x==5 || n.x==4;
 bool seam=false;
 int c=colors[0];
 if (rock_pattern==1) {
  int row=w.y/8, off=(row&1)*8, col=(w.x+off)/16;
  seam=w.y%8==7 || (w.x+off)%16==15;
  c=seam?colors[2]:colors[h32(col,row,7)%3u==0u?1:0];
  int gx=(w.x+off)%16, gy=w.y%8;
  if (!seam && h32(col,row,9)%5u==0u && gy>=2&&gy<=4 && (gx==5||gx==9||(gy==3&&gx>5&&gx<9))) c=colors[2];
  if (!seam && hash%37u==0u) c=colors[3];
 } else if (rock_pattern==2) {
  int band=(w.y+int(h32(w.x>>3,0,11)%4u))>>2;
  c=colors[h32(w.x>>4,band,13)%3u==0u?1:0];
  if (h32(w.x>>2,band,17)%11u==0u && (w.y&3)==0) c=colors[2];
  if (hash%97u==0u) c=colors[3];
 } else if (rock_pattern==3) {
  c=colors[h32(w.x>>1,w.y>>2,13)%4u==0u?1:0];
  if (h32(w.x,w.y>>1,19)%23u==0u) c=colors[2];
  if (hash%41u==0u) c=colors[3];
 } else if (rock_pattern==4) {
  int row=w.y>>3, col=(w.x+(row&1)*8)>>4;
  c=colors[0];
  if ((w.y&7)==7 || ((w.x+(row&1)*8)&15)==15) c=colors[1];
  else if (h32(col,row,15)%3u==0u && (w.x+w.y*2+int(h32(col,row,16)%9u))%17==0) c=colors[2];
 } else if (rock_pattern==5) {
  return cloud(w,p,n);
 } else if (rock_pattern==6) {
  seam=p.x==0||p.x==15||p.y==0||p.y==15;
  c=seam?colors[2]:colors[p.y<8?0:1];
  if ((p.x==2||p.x==13)&&(p.y==2||p.y==13)) c=colors[3];
  if (!seam&&p.x>3&&p.x<12&&p.y==7) c=colors[2];
 } else {
  int row=w.y/6, off=(row&1)*5, col=(w.x+off)/10;
  seam=w.y%6==5||(w.x+off)%10==9;
  c=seam?colors[2]:colors[h32(col,row,7)%4u==0u?1:0];
  if (!seam&&hash%29u==0u) c=colors[3];
 }
 if (open_up) {
  if (rock_pattern==3) {
   int blade=int(h32(w.x,0,21)%4u);
   if (p.y==0) c=blade==0?colors[5]:colors[8];
   else if (p.y==1) c=colors[8];
   else if (p.y==2 && blade<2) c=colors[5];
   else if (p.y==3 && blade==0) c=colors[5];
  } else if (rock_pattern==6) {
   if (hazard_trim) { if (p.y<=2) c=(((w.x+p.y)>>2)&1)!=0?colors[8]:26; }
   else if (p.y==0) c=colors[4]; else if (p.y==1) c=(w.x&7)==3?colors[8]:colors[5];
  } else if (rock_pattern==4||rock_pattern==1) {
   if (p.y==0) c=colors[8]; else if (p.y==1) c=colors[4];
  } else if (rock_pattern==2) {
   if (p.y==0) c=h32(w.x,1,23)%3u!=0u?colors[8]:colors[4];
   else if (p.y==1 && h32(w.x,1,23)%3u==0u) c=colors[8];
  } else {
   if (p.y==0) c=colors[4]; else if (p.y==1&&!seam) c=colors[5];
  }
 }
 if (n.y==0) {
  if (rock_pattern==4 && colors[9]!=0) { int bump=13-int(h32(w.x>>2,0,29)%3u); if (p.y>=bump) c=p.y==15?colors[6]:colors[9]; }
  else if (rock_pattern==2) { if (p.y==15 || (p.y==14&&h32(w.x,2,31)%4u==0u)) c=colors[6]; }
  else if (p.y==15) c=colors[6];
 }
 if ((p.x==0&&n.z==0&&p.y>0)||(p.x==15&&n.w==0&&p.y>0)) c=colors[7];
 return c;
}

int shade(int m, ivec2 w, ivec2 p, ivec2 tile, ivec4 n) {
 int seed=m==1?11:m==2?23:m==3?37:m==4?41:53;
 uint hash=h32(w.x,w.y,seed);
 if (m==1) return rock(w,p,n,hash);
 if (m==3) {
  int c=colors[10+(((hash>>3u)%5u==0u)?1:0)];
  if (h32(w.x>>2,w.y>>2,5)%9u==0u) c=colors[12];
  if (hash%37u==0u) c=colors[13]; else if (h32(w.x,w.y-1,seed)%37u==0u) c=colors[14];
  if (n.x!=3&&n.x!=1) { if (p.y==0) c=colors[15]; else if(p.y==1&&hash%3u!=0u) c=colors[16]; }
  if (p.y==15&&n.y==0) c=colors[17];
  if ((p.x==0&&n.z==0)||(p.x==15&&n.w==0)) c=colors[17];
  return block_frame(c,p,n,3,colors[18],colors[19]);
 }
 if (m==2) {
  int c=colors[20+(hash%7u==0u?1:0)];
  if(crack(tile,p.x,p.y)) c=colors[22]; else if(crack(tile,p.x-1,p.y)) c=colors[23];
  if(p.y==0&&n.x==0) c=colors[24];
  if(p.y==15&&n.y==0) c=colors[25];
  return block_frame(c,p,n,2,colors[26],colors[27]);
 }
 if (m==4) {
  int variant=sdk_mode?raw_cell(w).y:int(hash%3u);
  int c=colors[28+variant%3];
  if (!sdk_mode&&hash%17u==0u) c=colors[31];
  if (sdk_mode ? mat_at(w+ivec2(0,-1))!=4 : p.y==0&&n.x!=4) c=colors[32];
  return c;
 }
 if (m==5) {
  if (sdk_mode) {
   int above=mat_at(w+ivec2(0,-1));
   if (above!=5&&above!=4) return colors[35];
   return raw_cell(w).y==3?colors[36]:raw_cell(w).y==0?colors[34]:colors[33];
  }
  int c=p.y<4&&n.x==5?colors[33]:p.y<6?colors[34]:colors[33];
  if(n.x!=5&&n.x!=4) {
   if(p.y==0) c=colors[35];
   else if(p.y==1&&((w.x+visual_tick)%7==0||(w.x+visual_tick*2)%11==0)) c=colors[36];
   else if(p.y<4) c=colors[34];
  }
  if(n.x==5&&h32(w.x,w.y,3+(visual_tick>>1))%97u==0u) c=colors[36];
  return c;
 }
 return 0;
}

void fragment() {
 ivec2 w=ivec2(floor(UV*vec2(grid_size*16)));
 ivec2 tile=w/16, p=w%16;
 ivec2 middle=tile*16+ivec2(8);
 ivec4 n=ivec4(mat_at(middle+ivec2(0,-16)),mat_at(middle+ivec2(0,16)),mat_at(middle+ivec2(-16,0)),mat_at(middle+ivec2(16,0)));
 int c=shade(mat_at(w),w,p,tile,n);
 ivec2 screen=w+screen_origin;
 int distance=min(min(screen.x,screen.y-20),min(319-screen.x,179-screen.y));
 if(c!=0 && vignette_width>0 && screen.y>=20 && distance<vignette_width && BAYER[(screen.y&3)*4+(screen.x&3)]*vignette_width>=distance*16) c=DIM[c];
 if(c!=0&&observe) c=DIM[c];
 for (int step=0; step<background_dim_steps; step++) c=DIM[c];
 COLOR=PAL[c];
}
