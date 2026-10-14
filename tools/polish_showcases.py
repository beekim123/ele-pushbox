#!/usr/bin/env python3
"""Author six terrain silhouettes for the visual observation galleries."""
import json, math
from pathlib import Path
ROOT=Path(__file__).resolve().parents[1]
for p in sorted((ROOT/'pushbox/levels/showcase').glob('*.json')):
 d=json.loads(p.read_text());w,h=map(int,d['size']);g=[list('.'*w) for _ in range(h)];props=[]
 def put(x,y,c='#'):
  if 0<=x<w and 0<=y<h:g[y][x]=c
 def rect(x,y,ww,hh,c='#'):
  for yy in range(y,y+hh):
   for xx in range(x,x+ww):put(xx,yy,c)
 def prop(name,x,y,flip=False):props.append({'sprite':name,'at':[x,y],**({'flip':True} if flip else {})})
 theme=p.stem
 if theme=='forest':
  for x in range(1,w-1):
   top=int(3*(abs(x-(w-1)/2)/(w/2))**2)
   put(x,top);put(x,top+1)
  for y in range(3,h-2):put(1+(y>h-4),y);put(w-2-(y>h-4),y)
  for x,top,width in [(2,8,4),(4,7,4),(7,6,4),(17,5,4),(21,4,5),(19,10,7)]:
   rect(x,top,width,1);rect(x+1,top+1,max(1,width-2),1)
  rect(12,3,2,6);rect(13,9,2,2);rect(10,11,2,2);rect(16,10,2,3)
  rect(11,13,7,1);rect(12,11,4,2,'w');rect(20,12,5,2,'w');rect(19,14,7,1)
  prop('miner_idle_0',3,7);prop('crate_static_0',23,3);prop('target_idle_0',25,3)
  for y in range(7,12):prop('vine_ladder_0',11,y)
  prop('crate_iron_0',8,5);prop('lever_left_0',5,6);prop('lantern_idle_0',16,2)
  rect(3,9,2,2,'s');rect(3,11,3,1)
 elif theme=='sky_island':
  def island(left,top,width,depth):
   for yy in range(depth):rect(left+yy//2,top+yy,width-2*(yy//2),1)
  island(2,4,8,3);island(20,4,8,3);island(7,10,7,3);island(18,10,6,3);island(12,14,6,1)
  rect(21,4,3,1,'i');rect(20,5,3,1,'w');rect(14,9,4,1,'i')
  for x in range(10,20):prop('cloud_pad_0',x,5)
  for x in range(14,18):prop('cloud_pad_0',x,11)
  prop('wind_emitter_0',5,3);prop('lever_left_0',3,3);prop('crate_static_0',23,3);prop('crate_iron_0',9,9)
  prop('target_idle_0',16,13);prop('miner_idle_0',3,3);prop('lantern_idle_0',25,1)
 elif theme=='ruins':
  mid=(w-1)/2
  for y in range(h):
   left=max(1,int(mid)-y);right=min(w-2,int(mid)+1+y)
   for x in [left,left+1,right-1,right]:put(x,y)
  rect(3,h-1,w-6,1)
  rect(12,1,4,2,'s');rect(11,3,1,2);rect(16,3,1,2)
  rect(5,7,6,1);rect(18,7,5,1);rect(10,11,8,1)
  rect(4,11,4,2,'w');rect(3,13,6,1);rect(20,11,4,2,'w');rect(19,13,6,1)
  prop('sand_funnel_0',13,3);prop('golden_scale_0',12,7);prop('scale_pan_0',7,6);prop('scale_pan_0',20,6)
  prop('lantern_idle_0',5,5);prop('lantern_idle_0',22,5);prop('crate_iron_0',7,6);prop('crate_static_0',20,6);prop('miner_idle_0',6,6)
 elif theme=='cave':
  for x in range(w):
   thick=1+(x*7%4)
   for y in range(thick):put(x,y)
   bottom=h-1-(x*11%3)
   for y in range(bottom,h):put(x,y)
  for y in range(3,h-3):put(y%2,y);put(w-1-y%2,y)
  for x,y,width in [(3,5,7),(10,7,5),(16,9,5),(23,11,5)]:rect(x,y,width,1);rect(x+1,y+1,width-2,1)
  rect(3,10,5,3,'a');rect(2,13,7,1);rect(17,11,5,2,'m');rect(16,13,7,1)
  rect(22,3,4,2,'w');rect(21,5,6,1)
  rect(6,7,2,2,'c');rect(8,10,2,1)
  prop('miner_idle_0',4,4);prop('crate_static_0',12,6);prop('crate_iron_0',25,10)
  prop('stalactite_0',9,2);prop('geyser_0',5,9);prop('lantern_idle_0',15,3);prop('lantern_idle_0',24,7)
 elif theme=='cosmos':
  corner=4
  for y in range(h):
   inset=max(0,corner-min(y,h-1-y))
   for x in [inset,w-1-inset]:put(x,y)
   if y in [0,h-1]:rect(inset,y,w-inset*2,1)
  rect(4,4,9,1);rect(18,4,9,1);rect(4,13,9,1);rect(18,13,9,1)
  rect(25,7,1,6);rect(30,7,1,6);rect(26,12,4,1);rect(26,8,4,4,'w')
  rect(5,10,3,2,'s');rect(4,12,5,1);rect(14,15,4,1,'p');rect(13,16,6,1)
  for x in range(5,13):prop('magnetic_rail_0',x,3)
  for x in range(19,27):prop('magnetic_rail_0',x,12)
  prop('quantum_pad_0',6,3);prop('quantum_pad_0',22,12);prop('gravity_console_0',12,12)
  prop('miner_idle_0',7,3);prop('crate_iron_0',21,3);prop('crate_static_0',23,3);prop('lantern_idle_0',17,2)
 else:
  for x in range(w):
   top=0 if x%8 in [3,4] else 1 if x%8 in [2,5] else 2
   put(x,top)
  for y in range(2,h-1):put(0,y);put(w-1,y)
  rect(2,h-1,w-4,1);rect(3,5,5,1);rect(3,6,2,3);rect(15,4,6,1);rect(20,5,2,5)
  rect(7,9,3,1);rect(15,9,6,1);rect(10,10,5,2,'w');rect(9,12,7,1)
  rect(3,8,1,3,'s');rect(11,2,2,2,'c')
  for y in range(3,10):prop('ladder_static_0',7,y)
  for y in range(5,9):prop('gate',17,y)
  prop('miner_idle_0',4,4);prop('crate_static_0',6,4);prop('crate_iron_0',12,9);prop('target_idle_0',18,8)
  prop('lantern_idle_0',5,1);prop('lantern_idle_0',18,1)
 d['map']=[''.join(r) for r in g];d['props']=props
 p.write_text(json.dumps(d,ensure_ascii=False,indent=2)+'\n')
print('Authored six distinct showcase silhouettes')
