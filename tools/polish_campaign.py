#!/usr/bin/env python3
"""Sculpt author-route-safe silhouettes; SDK recording remains the solve gate."""
import json, math
from pathlib import Path
ROOT=Path(__file__).resolve().parents[1]
OUT=ROOT/'artifacts/art-ui-polish'
BASE=OUT/'baseline-levels'
BASE.mkdir(parents=True,exist_ok=True)
(OUT/'drafts').mkdir(exist_ok=True)
for p in (ROOT/'pushbox/levels/campaign').rglob('*.json'):
 d=json.loads(p.read_text());b=BASE/(d['id']+'.json')
 if not b.exists():b.write_bytes(p.read_bytes())
reports=[]
for p in sorted(BASE.glob('*.json')):
 d=json.loads(p.read_text());old=d['map'];h=len(old);w=len(old[0]);g=[list(r) for r in old]
 ox,oy=(20-w)//2,(12-h)//2
 critical=set();occupied=set()
 def point(x,y,r=0):
  x,y=int(x),int(y)
  for yy in range(y-r,y+r+1):
   for xx in range(x-r,x+r+1):
    if 0<=xx<w and 0<=yy<h:critical.add((xx,yy))
 def actor(x,y):
  x,y=int(x),int(y);occupied.add((x,y));point(x,y);point(x,y+1)
 actor(*d['entities']['player'])
 for b in d['entities']['boxes']:actor(*b['at'])
 for x,y in d['entities']['targets']:actor(x,y)
 previous={'player':tuple(map(int,d['entities']['player']))}
 for b in d['entities']['boxes']:previous[b['id']]=tuple(map(int,b['at']))
 for key in d['solution_keys']:
  k=json.loads(key);positions=json.loads(json.loads(k[0])[0]);actor(positions[0]-ox,positions[1]-oy)
  current={'player':(int(positions[0])-ox,int(positions[1])-oy)}
  for i in range(2,len(positions),3):
   current[positions[i]]=(int(positions[i+1])-ox,int(positions[i+2])-oy)
   actor(*current[positions[i]])
  for name,(x,y) in current.items():
   px,py=previous[name]
   if abs(x-px)<=1:
    for yy in range(min(py,y),max(py,y)+1):point(x,yy);point(px,yy)
  previous=current
  for i,c in enumerate(k[2]):
   if c in ['WATER','SAND']:point(i%20-ox,i//20-oy,1)
 for y in range(h):
  for x in range(w):
   if old[y][x] not in '#.':point(x,y,1)
 for key in ['ladders','targets']:
  for x,y in d['entities'][key]:point(x,y)
 for lever in d['entities']['levers']:point(*lever['at'])
 def visit(obj):
  if isinstance(obj,dict):
   for key,v in obj.items():
    if key in ['at','left','right','from','to','support'] and isinstance(v,list) and len(v)==2 and all(isinstance(t,(float,int)) for t in v):point(*v,1)
    elif key=='rect' and isinstance(v,list) and len(v)==4:
     for yy in range(int(v[1]),int(v[1]+v[3])):
      for xx in range(int(v[0]),int(v[0]+v[2])):point(xx,yy)
    else:visit(v)
  elif isinstance(obj,list):
   if len(obj)==2 and all(isinstance(t,(float,int)) for t in obj):point(*obj)
   else:
    for v in obj:visit(v)
 visit(d['biome_mechanisms']);visit(d['mechanisms'])
 theme=d['theme_id']
 roofs=[]
 for y in range(1,h):
  x=1
  while x<w-1:
   if old[y][x]=='#' and old[y-1][x]!='#':
    start=x
    while x<w-1 and old[y][x]=='#' and old[y-1][x]!='#':x+=1
    roofs.append((start,x-1,y))
   else:x+=1
 for y in range(h):
  for x in range(w):
   if old[y][x]!='#' or (x,y) in critical:continue
   keep=True
   if theme=='sky_island':
    keep=any(0<=y-top<=3 and a+(y-top)//2<=x<=b-(y-top)//2 for a,b,top in roofs)
    if x in [0,w-1] or y==0:keep=False
   elif theme=='forest':
    if y==0:keep=2<=x<w-2
    elif y==1 and x in [0,w-1]:keep=False
    elif y>=h-2:keep=2+int(y==h-1)<=x<w-2-int(y==h-1) and (x%5 in [0,1] or (x,y-1) in critical)
    elif x not in [0,w-1] and old[y-1][x]=='#' and old[min(y+1,h-1)][x]=='#':keep=x%5 in [0,1] or (x+y)%7==0
   elif theme=='ruins':
    side=max(0,(w//2-2)-y*2)
    if x<side or x>=w-side:keep=False
    elif y>=h-2 and x%4 in [1,2] and (x,y-1) not in critical:keep=False
   elif theme=='cave':
    if y==0:keep=x%5 not in [0,4]
    elif y>=h-2:keep=y<h-1-(x%3==0)
    elif x in [0,w-1]:keep=y%4!=1
    elif old[y-1][x]=='#' and old[min(y+1,h-1)][x]=='#':keep=(x+y)%4<2
   elif theme=='cosmos':
    corner=3
    if (x+y<corner or (w-1-x)+y<corner or x+(h-1-y)<corner or (w-1-x)+(h-1-y)<corner):keep=False
    elif x not in [0,w-1] and 1<y<h-2 and old[y-1][x]=='#' and old[y+1][x]=='#':keep=x%6 in [0,1]
   else:
    if y==0:keep=x%6 not in [0,5]
    elif y==1 and x%6 in [2,3]:keep=False
    elif y>=h-2 and x%5 in [1,2] and (x,y-1) not in critical:keep=False
   if not keep:g[y][x]='.'
 # Add sculpted canopy / roof tips only in empty, unused air.
 for x in range(1,w-1):
  if theme=='forest':top=1 if x in [1,w-2] else 0
  elif theme=='cave':top=1+(x*7%3)
  elif theme=='ruins':top=max(0,math.ceil(abs(x-(w-1)/2)/2)-1)
  elif theme=='dungeon':top=1 if x%6 in [1,4] else 0
  elif theme=='cosmos':top=max(0,3-min(x,w-1-x))
  else:continue
  if 0<=top<min(4,h-3) and g[top][x]=='.' and (x,top) not in critical:g[top][x]='#'
 if theme=='sky_island':
  for y in range(h):g[y][0]=g[y][-1]='.'
  g[0]=list('.'*w)
 # S_05's flood basin needs its inner retaining wall. Place the assembly
 # one cell inward, leaving both canvas edges as open sky.
 if d['id']=='S_05':
  for y in range(3,8):g[y][0]='#'
  def shift(obj):
   if isinstance(obj,dict):
    for key,v in obj.items():
     if key=='rect' and isinstance(v,list) and len(v)==4:v[0]+=1
     else:shift(v)
   elif isinstance(obj,list):
    if len(obj)==2 and all(isinstance(t,(int,float)) for t in obj):obj[0]+=1
    else:
     for v in obj:shift(v)
  shift(d['entities']);shift(d['mechanisms']);shift(d['biome_mechanisms'])
  g=[list('.')+row+list('.') for row in g]
 d['map']=[''.join(r) for r in g]
 d['solution_hashes']=[];d['solution_keys']=[]
 changed=sum(a!=b for r,s in zip(old,[''.join(r) for r in (g if d['id']!='S_05' else [r[1:-1] for r in g])]) for a,b in zip(r,s))
 assert changed>0,d['id']
 (OUT/'drafts'/p.name).write_text(json.dumps(d,ensure_ascii=False,indent=2)+'\n')
 reports.append({'id':d['id'],'theme':theme,'changed_tiles':changed,'protected_tiles':len(critical),'actions':len(d['solution'])})
(OUT/'geometry-redesign.json').write_text(json.dumps(reports,indent=2)+'\n')
print('Sculpted 36 drafts:',sum(r['changed_tiles'] for r in reports),'changed terrain cells; recordings required')
