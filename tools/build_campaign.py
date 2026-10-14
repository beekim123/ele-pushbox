#!/usr/bin/env python3
"""Author editable candidate geometries; only verified recordings enter campaign/."""
import json
import copy
from pathlib import Path
ROOT = Path(__file__).resolve().parents[1]
DRAFTS = ROOT/'artifacts/stage2a/drafts'
DRAFTS.mkdir(parents=True,exist_ok=True)
THEMES=['dungeon','forest','ruins','cave','sky_island','cosmos']
PREFIX=['D','F','R','C','S','X']
TITLES=[['沉铁开道','一沙卡千斤','一沙二用','爆柱填渊','铁木双井','深层矿井枢纽'],['甘霖育藤','浮木渡津','筑坝引泉','斩藤落箱','双藤交错','巨木盘根水殿'],['黄金天平','流沙漏斗','掬沙称重','沙漏与水钟','双盘博弈','日轮金字塔内殿'],['滴酸穿石','水火化沙','引酸入渠','钟乳石坠','双色沙漏','幽光晶簇与熔脉'],['履冰过渊','轻重云垫','冰封水位线','顺风扬沙','破冰坠锚','破晓云海风之圣域'],['量子跃迁','隔空传沙','失重回廊','等离子冷却','星门双生','深空星站：曲率反应舱']]
LEGEND={'#':'bedrock','.':'empty','c':'cracked_rock','s':'sand','w':'water','G':'gate','a':'acid','m':'lava','u':'pumice','i':'ice','q':{'material':'sand','fill':0.75},'h':{'material':'sand','fill':0.5}}
class Level:
 def __init__(self,m,n,w,h):
  self.m,self.n,self.w,self.h=m,n,w,h
  self.grid=[list('#'*w if y in (0,h-1) else '#'+'.'*(w-2)+'#') for y in range(h)]
  self.d={'format':'pushbox.level/1','content':'default','id':f'{PREFIX[m]}_{n:02}','title':TITLES[m][n-1],'theme_id':THEMES[m],'campaign':{'map':m,'index':n-1,'stars':(n+1)//2},'legend':LEGEND,'map':[],'entities':{'player':[1,h-2],'boxes':[],'targets':[],'ladders':[],'levers':[]},'budget':{'sand_cells':0,'bombs':0},'seed':1,'mechanisms':[],'biome_mechanisms':{},'hints':[],'solution':[],'solution_hashes':[],'solution_keys':[]}
 def put(self,x,y,c):self.grid[y][x]=c;return self
 def rect(self,x,y,w,h,c):
  for yy in range(y,y+h):
   for xx in range(x,x+w):self.put(xx,yy,c)
  return self
 def player(self,x,y):self.d['entities']['player']=[x,y];return self
 def box(self,id,x,y,tx,ty,kind='wood'):
  self.d['entities']['boxes'].append({'id':id,'at':[x,y],'kind':kind});self.d['entities']['targets'].append([tx,ty]);return self
 def ladder(self,x,top,bottom):self.d['entities']['ladders'] += [[x,y] for y in range(top,bottom+1) if [x,y] not in self.d['entities']['ladders']];return self
 def lever(self,id,x,y):self.d['entities']['levers'].append({'id':id,'at':[x,y]});return self
 def gate(self,id,tiles,cond):
  for x,y in tiles:self.put(x,y,'G')
  self.d['mechanisms'].append({'kind':'gate','id':id,'tiles':tiles,'open_when':cond});return self
 def mech(self,kind,item):self.d['biome_mechanisms'].setdefault(kind,[]).append(item);return self
 def budget(self,sand=0,bombs=0):self.d['budget']={'sand_cells':sand*256,'bombs':bombs};return self
 def solution(self,s):self.d['solution']=s.split();return self
 def save(self):
  self.d['map']=[''.join(r) for r in self.grid]
  (DRAFTS/(self.d['id']+'.json')).write_text(json.dumps(self.d,ensure_ascii=False,indent=2)+'\n')
  return self

def dungeon():
 l=Level(0,1,12,7).rect(1,4,10,2,'#').rect(5,4,1,2,'w').player(3,3).box('I',4,3,5,5,'iron').box('A',2,3,9,3).ladder(3,2,3).ladder(5,3,4)
 l.gate('G1',[[8,2],[8,3]],{'plate':[5,5],'by':'box'}).solution('R L U L L '+'R '*7).save()
 l=Level(0,2,12,7).rect(1,5,10,1,'#').put(7,5,'.').player(6,4).box('A',3,4,9,4).budget(1)
 l.ladder(6,3,4).ladder(2,3,4)
 for x in range(3,6):l.ladder(x,3,3)
 l.gate('G1',[[7,3],[7,4],[7,5]],{'plate':[6,4],'by':'player'}).solution('POUR_R U L L L L D '+'R '*6).save()
 l=Level(0,3,14,8).rect(1,6,12,1,'#').put(2,6,'s').put(4,6,'.').rect(10,4,3,2,'#').player(2,5).box('A',5,5,8,5).box('B',11,3,12,3).ladder(7,4,5)
 l.gate('G1',[[7,3],[7,4],[7,5]],{'count':{'rect':[4,6,1,1],'tag':'loose','gte':128}}).solution('DIG_D R POUR_R R R R L L DIG_D R R R U R POUR_R R R R').save()
 l=Level(0,4,16,9).rect(1,6,14,2,'#').rect(8,6,1,2,'.').rect(7,1,3,3,'#').put(8,1,'h').put(8,2,'s').put(8,3,'s').put(8,4,'c').player(2,5).box('A',3,5,12,5).budget(0,1).ladder(6,3,5).ladder(7,4,5)
 l.ladder(2,4,5)
 for x in range(3,8):l.ladder(x,4,4)
 l.solution('U R R R R R BOMB_R L L L L L D '+'R '*9).save()
 l=Level(0,5,18,10).rect(1,1,16,8,'#')
 old=['###########','#s#.......#','#sc.......#','#s###.#.###','#####w#w###','#####www###','#####.#####','###########']
 for y,row in enumerate(old):
  for x,c in enumerate(row):l.put(x,y,c)
 l.rect(11,1,6,2,'.').put(10,2,'.').player(9,2).box('I',8,2,7,5,'iron').box('A',6,2,9,2).ladder(5,2,4).ladder(7,2,4).budget(0,1)
 l.d['legend']=copy.deepcopy(LEGEND)
 l.d['legend']['v']={'material':'water','fill':0.25}
 l.put(6,4,'v')
 l.gate('G1',[[3,1],[3,2]],{'plate':[7,5],'by':'box'}).solution('L L U L L D R L L L BOMB_L L DIG_L L DIG_D R R R POUR_R POUR_R R R R R').save()

 l=Level(0,6,20,11).rect(1,1,18,9,'#')
 for y,row in enumerate(old):
  for x,c in enumerate(row):l.put(x,y,c)
 l.rect(10,1,9,2,'.').player(4,2).box('I',8,2,7,5,'iron').box('A',6,2,9,2).box('B',13,8,16,7).budget(1,1)
 l.put(3,3,'.').ladder(3,2,3).ladder(4,1,2).ladder(5,2,4).ladder(7,2,4).ladder(9,1,2).ladder(8,1,2)
 for x in range(5,9):l.ladder(x,1,1)
 # The shared anti-crush assembly also spans the iron crate's middle route.
 # Upper float A must be delivered before its sand can be recovered for B.
 l.gate('G1',[[3,1],[3,2],[3,3],[7,1],[7,2],[7,3]],{'plate':[4,2],'by':'player'})
 l.rect(11,2,1,6,'.').rect(11,6,8,2,'.').rect(12,8,3,1,'.').rect(12,9,3,1,'w')
 l.d['legend']=copy.deepcopy(LEGEND)
 l.d['legend']['v']={'material':'water','fill':0.25}
 l.d['legend']['j']={'material':'water','fill':0.5}
 l.put(6,4,'v').put(12,8,'j').ladder(5,2,6).ladder(11,2,7).ladder(12,6,8).ladder(13,7,8).ladder(14,6,7)
 l.solution('POUR_L U R R R R R D L L U L L D R L L L BOMB_L L DIG_L L DIG_D R R R POUR_R POUR_R R R R R '
            'L L L D D DIG_D D DIG_D U U U U R R R R R R D D D D D R D R U L L POUR_R R R R R').save()

def forest():
 l=Level(1,1,12,7).rect(1,6,10,1,'#').rect(7,3,4,3,'#').rect(3,3,3,2,'#').rect(4,3,1,2,'w').put(4,5,'#').player(1,5).box('A',8,2,10,2).lever('L1',1,5).ladder(2,2,5)
 l.gate('SPRING',[[5,3],[5,4]],{'lever':'L1'}).mech('vine_seeds',{'at':[6,5],'height':4}).solution('USE R U U U R R R R U U U R R R').save()
 l=Level(1,2,14,8).rect(1,5,12,2,'#').rect(6,5,2,2,'.').rect(6,6,2,1,'w').player(4,4).box('A',5,4,11,4).box('B',3,4,10,4).budget(1)
 for x in range(4,11):l.ladder(x,3,3)
 l.ladder(4,4,4).ladder(10,4,4).ladder(6,4,4).ladder(7,4,4)
 l.solution('U R POUR_R L D '+'R '*6+'U '+'L '*8+'R '*7).save()
 l=Level(1,3,16,9).rect(1,7,14,1,'#').put(5,7,'.').put(6,6,'#').put(4,5,'#').rect(7,3,8,4,'#').rect(3,3,3,2,'#').rect(4,3,1,2,'w').player(3,6).box('A',8,2,13,2).lever('L1',4,4).budget(1).ladder(2,2,6)
 l.gate('DRAIN',[[4,6]],{'not':{'lever':'L1'}}).gate('SPRING',[[5,3],[5,4]],{'lever':'L1'}).mech('vine_seeds',{'at':[6,5],'height':4}).solution('R POUR_R L L U U U U R R USE R R U U U '+'R '*6).save()
 l=Level(1,4,16,9).rect(1,7,14,1,'#').rect(7,3,8,1,'#').put(9,3,'c').put(7,6,'#').rect(3,4,3,2,'#').rect(4,4,1,2,'w').put(4,6,'#').player(1,6).box('A',8,2,13,6).lever('L1',1,6).budget(0,1).ladder(2,3,6).ladder(7,4,5).ladder(8,4,6)
 l.gate('SPRING',[[5,4],[5,5]],{'lever':'L1'}).mech('vine_seeds',{'at':[6,6],'height':5,'support':[9,3]}).solution('USE R U U U R R R R U U U U R R L L D D R R BOMB_R D D R R R R').save()

 for n,w,h in [(5,18,10),(6,20,11)]:
  l=Level(1,n,w,h).rect(1,8,w-2,h-9,'#').rect(1,7,4,1,'#').put(5,8,'w').rect(7,5,4,3,'#').rect(13,2,w-14,7,'#').put(12,7,'#').put(11,8,'w').rect(4,3,3,1,'#').put(5,2,'s').player(3,6).box('I',4,6,5,8,'iron').box('A',8,4,10,4).box('B',14,1,16,1).budget(1,1 if n==6 else 0).ladder(5,6,7).ladder(7,3,4).ladder(9,3,4).ladder(11,3,7)
  l.mech('vine_seeds',{'at':[6,7],'height':4}).mech('vine_seeds',{'at':[12,6],'height':6})
  prefix='R R R U U R U L DIG_L R D D R R U R POUR_R POUR_R R R U U R R R'
  if n==6:
   l.put(5,6,'c').ladder(3,5,6).ladder(4,5,5)
   prefix='U R BOMB_R L D '+prefix
  l.solution(prefix).save()

def ruins():
 l=Level(2,1,12,7).rect(1,4,2,2,'#').rect(8,2,3,4,'#').player(1,3).box('I',2,3,3,5,'iron').box('A',7,3,9,1).ladder(2,1,3)
 for x in range(3,7):l.ladder(x,1,1)
 l.mech('scales',{'left':[3,3],'right':[7,3],'lift':2}).solution('R U U '+'R '*6).save()
 l=Level(2,2,14,8).rect(1,5,12,2,'#').rect(7,5,1,2,'.').rect(6,0,3,3,'#').put(7,0,'h').put(7,1,'s').put(7,2,'s').put(7,3,'c').player(2,4).box('A',3,4,11,4).budget(0,1).ladder(2,3,4)
 for x in range(3,7):l.ladder(x,3,3)
 l.gate('G1',[[9,3],[9,4]],{'count':{'rect':[7,5,1,2],'tag':'loose','gte':384}}).mech('hourglasses',{'tiles':[[7,3]],'open_when':{'not':{'count':{'rect':[7,3,1,1],'tag':'breakable','gte':1}}}}).solution('U R R R R BOMB_R L L L L D '+'R '*8).save()
 l=Level(2,3,16,9).rect(1,5,3,3,'#').rect(3,4,1,4,'#').rect(5,4,1,4,'#').rect(10,4,2,4,'#').rect(12,2,3,6,'#').player(3,3).box('A',9,5,10,3).box('B',13,1,14,1).budget(2).ladder(4,3,6).ladder(9,2,3)
 for x in range(4,9):l.ladder(x,3,3)
 l.mech('scales',{'left':[4,5],'right':[9,5],'lift':2,'weight_height':2}).solution('POUR_R POUR_R '+'R '*6+'L '*5+'D D DIG_D DIG_D U '+'R '*5+'U R POUR_R R R R').save()
 l=Level(2,4,16,9).rect(1,1,14,7,'#')
 old=['###########','#####q#...#','#####s#...#','####.c#...#','#####w#w###','#####www###','#####w#####','###########']
 for y,row in enumerate(old):
  for x,c in enumerate(row):l.put(x,y,c)
 l.rect(6,2,4,1,'.').put(7,3,'.').put(4,3,'#').put(3,3,'.').put(4,1,'.').rect(3,1,1,3,'.').put(2,3,'.').player(2,3).box('A',7,3,9,2).lever('L1',2,3).ladder(3,1,3).ladder(5,3,4).ladder(7,2,4)
 l.gate('G1',[[6,2]],{'count':{'rect':[7,3,1,1],'tag':'fluid','gte':64}}).mech('hourglasses',{'tiles':[[5,3]],'open_when':{'lever':'L1'},'delayed_tiles':[[5,1]]}).solution('USE R U U R R R R R').save()

 l=Level(2,5,18,10).rect(1,5,2,4,'#').rect(5,5,1,3,'#').put(2,4,'s').rect(8,5,7,1,'#').put(10,5,'.').put(11,5,'.').player(3,4).box('A',4,6,2,4).box('I',10,6,7,8,'iron').budget(1,1).ladder(3,3,4).ladder(4,3,7).ladder(8,3,4).ladder(11,3,8)
 for x in range(5,11):l.ladder(x,3,3)
 l.mech('scales',{'left':[4,6],'right':[10,6],'lift':2,'weight_height':3,'threshold':0}).mech('scales',{'left':[7,4],'right':[3,8],'lift':4})
 l.gate('SHAFT',[[3,5],[3,6],[3,7]],{'box_at':['I',[7,4]]}).put(8,4,'c')
 l.solution('DIG_L POUR_R POUR_R U '+'R '*8+'D L BOMB_L R D D D D '+'L '*7+'U U U U '+'R '*7+'D L L L U L L L L D L').save()

 k=Level(2,6,20,11)
 for y,row in enumerate(l.grid):
  for x,c in enumerate(row):k.put(x,y,c)
 for key in ['entities','budget','mechanisms','biome_mechanisms','solution']:
  k.d[key]=copy.deepcopy(l.d[key])
 k.rect(17,1,2,8,'.').rect(18,6,1,4,'#').rect(14,6,1,4,'#').rect(16,6,1,2,'#').rect(14,3,3,1,'#').put(16,4,'#').put(15,3,'q').put(15,4,'s').put(15,5,'c').rect(15,7,1,3,'w').rect(16,8,2,1,'w').put(17,7,'w').box('B',17,6,18,5).lever('H',14,4).ladder(13,3,4).ladder(15,4,7)
 k.gate('H_WALK',[[16,5]],{'lever':'H'}).mech('hourglasses',{'tiles':[[15,5]],'open_when':{'lever':'H'},'delayed_tiles':[[15,3]]})
 k.d['solution'] += ('U '+'R '*10+'R USE R D R R').split()
 k.save()

def cave():
 l=Level(3,1,12,7).rect(1,5,10,1,'#').rect(5,2,3,1,'#').put(6,2,'a').put(6,4,'c').player(2,4).box('A',3,4,9,4).lever('L1',2,4)
 l.gate('ACID',[[6,3]],{'lever':'L1'}).solution('USE '+'R '*6).save()
 l=Level(3,2,14,8).rect(1,5,12,2,'#').rect(5,4,2,2,'.').rect(5,5,2,1,'m').rect(4,2,3,2,'#').rect(5,2,1,2,'w').rect(10,3,3,3,'#').player(4,4).box('A',11,2,12,2).lever('L1',4,4).ladder(5,3,4)
 l.gate('WATER',[[5,4]],{'lever':'L1'}).solution('USE DIG_R R DIG_D U U R R R POUR_R R R R').save()
 l=Level(3,3,16,9).rect(1,7,4,1,'#').rect(6,6,9,2,'#').put(5,7,'.').put(4,5,'#').put(7,5,'c').rect(4,1,3,3,'#').rect(5,1,1,3,'a').player(3,6).box('A',8,5,12,5).lever('L1',3,3).budget(1).ladder(3,3,6).ladder(5,4,6)
 l.gate('DRAIN',[[4,6]],{'not':{'lever':'L1'}}).gate('ACID',[[5,4]],{'lever':'L1'}).gate('WALK',[[4,4]],{'not':{'count':{'rect':[7,5,1,1],'tag':'breakable','gte':1}}})
 l.solution('R POUR_R L U U U USE D D R R R R '+'R '*4).save()
 l=Level(3,4,16,9).rect(1,1,14,7,'#')
 old=['###########','####.c#...#','#####.#...#','#####c#.###','#####w#w###','#####www###','#####w#####','###########']
 for y,row in enumerate(old):
  for x,c in enumerate(row):l.put(x,y,c)
 l.rect(6,2,4,1,'.').put(7,3,'.').player(4,1).box('A',7,3,9,2).budget(0,1).ladder(5,2,4).ladder(7,2,4)
 l.gate('WALK',[[6,2]],{'count':{'rect':[7,3,1,1],'tag':'fluid','gte':64}}).mech('stalactites',{'at':[5,2],'support':[5,1]}).solution('BOMB_R R D R R R').save()
 l=Level(3,5,18,10).rect(1,5,16,2,'#').put(1,5,'s').put(2,5,'.').rect(5,4,2,2,'.').rect(5,5,2,1,'m').rect(4,2,3,2,'#').rect(5,2,1,2,'w').put(9,5,'.').put(11,5,'.').player(4,4).box('A',13,4,16,4).lever('L1',4,4).ladder(5,3,4).ladder(2,1,5).ladder(3,1,4).ladder(4,3,4).ladder(9,4,4).ladder(11,4,4)
 l.gate('WATER',[[5,4]],{'lever':'L1'}).gate('PUMICE',[[12,3],[12,4]],{'count':{'rect':[9,5,1,1],'tag':'pumice','gte':128}}).gate('SAND',[[14,3],[14,4]],{'count':{'rect':[11,5,1,1],'tag':'sand','gte':128}})
 l.solution('USE DIG_R POUR_L R DIG_D U U L L L D D D D DIG_L U U U U '+'R '*6+'POUR_R R R POUR_R '+'R '*5).save()

 base=json.loads((DRAFTS/'C_03.json').read_text())
 k=Level(3,6,20,11)
 for y,row in enumerate(base['map']):
  for x,c in enumerate(row):k.put(x,y,c)
 for key in ['entities','budget','mechanisms','biome_mechanisms','solution']:k.d[key]=copy.deepcopy(base[key])
 k.d['budget']['bombs']=1
 k.put(4,1,'a').put(3,1,'#').put(6,5,'c').mech('stalactites',{'at':[6,3],'support':[7,5]}).mech('geysers',{'at':[6,5],'every':3,'material':'acid','active_when':{'lever':'L1'}})
 k.rect(14,8,5,1,'#').rect(15,6,4,2,'#').rect(16,6,1,2,'m').rect(15,3,3,2,'#').rect(16,3,1,2,'w').put(15,5,'.').box('I',17,5,18,5,'iron').lever('H',15,5).ladder(11,4,5).ladder(16,5,5)
 k.gate('WATER',[[16,5]],{'lever':'H'}).mech('geysers',{'at':[18,5],'every':3,'material':'water','active_when':{'lever':'H'}})
 k.d['solution'] += 'U R R R R USE DIG_R R R'.split()
 k.save()

def sky():
 l=Level(4,1,12,7).rect(1,4,10,2,'#').rect(4,4,4,2,'w').player(4,3).box('A',5,3,9,3).box('I',2,3,8,3,'iron').lever('L1',1,3).ladder(8,2,3)
 for x in range(3,8):l.ladder(x,2,2)
 for x in range(4,8):l.ladder(x,3,3)
 l.mech('freezers',{'tiles':[[x,4] for x in range(4,8)],'active_when':{'lever':'L1'}}).solution('R R R R U '+'L '*7+'USE '+'R '*6).save()
 l=Level(4,2,14,8).rect(1,4,3,3,'#').rect(8,4,5,3,'#').player(4,3).box('A',5,3,12,3).box('I',2,3,4,6,'iron').ladder(8,2,3)
 for x in range(3,8):l.ladder(x,2,2)
 for x in range(4,8):l.mech('cloud_pads',[x,4])
 l.gate('G1',[[10,2],[10,3]],{'plate':[4,6],'by':'box'}).solution('R R R R U '+'L '*7+'R R '+'R '*8).save()
 l=Level(4,3,16,9).rect(1,1,14,7,'#').rect(1,1,11,3,'.').rect(8,4,4,1,'#').rect(12,2,3,6,'#').rect(12,1,3,1,'.').rect(5,5,1,3,'w').rect(7,5,1,2,'w').put(6,6,'w').put(5,4,'v').put(7,4,'.').player(4,3).box('A',7,4,10,3).box('B',13,1,14,1).budget(1).lever('L1',4,3).ladder(5,3,6).ladder(7,3,4).ladder(9,2,3)
 l.d['legend']=copy.deepcopy(LEGEND);l.d['legend']['v']={'material':'water','fill':0.4375}
 l.mech('freezers',{'tiles':[[7,4]],'active_when':{'lever':'L1'}}).solution('POUR_R USE R D D D DIG_D U U U R R R R U R POUR_R R R R').save()
 l=Level(4,4,16,9).rect(1,6,14,2,'#').rect(4,6,7,1,'i').put(11,6,'.').put(12,6,'i').player(8,5).box('A',4,5,13,5).budget(1).lever('W',8,5).ladder(9,4,5)
 for x in range(4,9):l.ladder(x,4,4)
 l.mech('wind_zones',{'rect':[3,4,11,3],'direction':'R','active_when':{'lever':'W'}}).solution('USE R POUR_R U '+'L '*6+'R '*8).save()
 l=Level(4,5,18,10).rect(1,4,3,5,'#').rect(1,7,16,2,'#').rect(7,3,10,4,'#').rect(4,5,3,2,'w').rect(5,4,2,1,'w').rect(7,5,8,1,'.').rect(9,1,7,4,'#').rect(10,1,5,4,'w').player(4,3).box('A',5,3,8,2).box('I',2,3,4,6,'iron').budget(0,1).lever('L1',4,3).ladder(5,2,3).ladder(6,2,2)
 for x in range(3,5):l.ladder(x,2,2)
 l.mech('cloud_pads',[4,4]).mech('freezers',{'tiles':[[4,5],[5,4],[6,4]],'active_when':{'all':[{'lever':'L1'},{'not':{'plate':[4,6],'by':'box'}}]}})
 l.gate('RESERVE',[[7,5],[10,5],[11,5],[12,5],[13,5],[14,5]],{'plate':[4,6],'by':'box'}).solution('USE R U L L L L R R R BOMB_D R U R R').save()
 l=Level(4,6,20,11).rect(1,4,3,6,'#').rect(8,4,11,6,'#').rect(9,4,3,1,'w').put(12,4,'.').player(4,3).box('A',5,3,16,3).box('I',2,3,4,9,'iron').budget(1,1).lever('W',10,3).ladder(7,2,3).ladder(9,2,3).ladder(10,2,3)
 for x in range(3,11):l.ladder(x,2,2)
 for x in range(4,8):l.mech('cloud_pads',[x,4])
 l.gate('G1',[[14,2],[14,3]],{'plate':[4,9],'by':'box'}).mech('freezers',{'tiles':[[9,4],[10,4],[11,4]],'active_when':{'lever':'W'}}).mech('wind_zones',{'rect':[8,2,10,4],'direction':'R','active_when':{'lever':'W'}}).solution('R R R U R R R D USE POUR_R L U '+'L '*8+'R R '+'R '*12).save()

def cosmos():
 l=Level(5,1,12,7).rect(1,5,10,1,'#').rect(6,2,1,3,'#').rect(7,3,4,2,'#').player(1,4).box('A',2,4,10,2).ladder(5,1,4)
 l.mech('teleporters',{'from':[4,4],'to':[8,2]}).solution('R R R R U U U R R R R').save()
 l=Level(5,2,14,8).rect(1,1,12,6,'#').rect(1,1,9,1,'.').rect(4,2,6,1,'.').put(2,2,'.').put(5,3,'v').put(7,3,'.').rect(5,4,1,3,'w').rect(7,4,1,2,'w').put(6,5,'w').player(1,1).box('A',7,3,9,2).budget(1).ladder(5,2,4).ladder(7,2,3)
 l.d['legend']=copy.deepcopy(LEGEND);l.d['legend']['v']={'material':'water','fill':0.4375}
 l.mech('teleporters',{'from':[2,2],'to':[5,2]}).solution('POUR_R R R R R R R R').save()
 l=Level(5,3,16,9).rect(1,7,14,1,'#').rect(1,1,14,1,'#').rect(7,7,2,1,'.').player(2,6).box('A',6,6,14,6).box('I',3,6,7,7,'iron').lever('G',2,6).lever('H',9,2).ladder(5,2,6).ladder(9,2,6)
 for x in range(6,10):l.ladder(x,2,2)
 cond={'all':[{'lever':'G'},{'not':{'lever':'H'}}]}
 l.mech('gravity_zones',{'rect':[5,2,6,5],'active_when':cond}).gate('G1',[[12,5],[12,6]],{'plate':[7,7],'by':'box'}).solution('USE R R R R L U U U U R R R R USE D D D D R R R R').save()
 l=Level(5,4,16,9).rect(1,5,14,2,'#').rect(5,4,2,2,'.').rect(5,5,2,1,'m').put(6,4,'m').rect(4,1,3,3,'#').rect(5,1,1,3,'w').put(5,4,'c').put(9,5,'.').player(4,4).box('A',12,4,14,4).budget(0,1).ladder(5,4,4).ladder(6,4,4).ladder(9,4,4)
 l.gate('G1',[[11,3],[11,4]],{'count':{'rect':[9,5,1,1],'tag':'pumice','gte':128}}).solution('BOMB_R R DIG_D R R R POUR_R R R R R R').save()
 l=Level(5,5,18,10).rect(1,8,16,1,'#').rect(1,1,16,1,'#').rect(9,1,1,6,'#').rect(11,4,6,1,'#').rect(4,3,3,1,'#').player(1,7).box('A',3,7,5,2).box('B',4,7,13,3).box('I',12,3,14,3,'iron').budget(1).lever('G',1,7).ladder(3,2,2).ladder(2,2,7).ladder(5,6,7).ladder(10,3,7).ladder(13,2,3)
 l.mech('gravity_zones',{'rect':[2,2,2,6],'active_when':{'lever':'G'}}).mech('teleporters',{'from':[6,7],'to':[12,3]}).gate('Q_LOCK',[[4,1],[4,2]],{'count':{'rect':[12,3,1,1],'tag':'loose','gte':128}})
 l.solution('USE R R R R U R R R R R U U U U R R R U L L R L L D D D D L L L L L POUR_R L L L U U U U U R R').save()
 base=json.loads((DRAFTS/'X_03.json').read_text())
 k=Level(5,6,20,11)
 for y,row in enumerate(base['map']):
  for x,c in enumerate(row):k.put(x,y,c)
 for key in ['entities','mechanisms','biome_mechanisms']:k.d[key]=copy.deepcopy(base[key])
 k.budget(1,1).rect(15,7,4,2,'#').rect(15,6,4,1,'#').rect(16,2,3,3,'#').rect(17,2,1,3,'w').rect(17,6,1,2,'m').put(17,5,'c').put(4,3,'#').put(15,5,'.').put(16,5,'.').ladder(11,4,6).ladder(17,5,6)
 k.d['mechanisms'][0]['open_when']={'all':[{'plate':[7,7],'by':'box'},{'count':{'rect':[4,2,1,1],'tag':'pumice','gte':128}}]}
 k.lever('Q',15,5).mech('teleporters',{'from':[16,5],'to':[4,2],'active_when':{'lever':'Q'}}).solution('USE R R R R L U U U U R R R R USE R R U U R R R R R BOMB_R R DIG_D L L POUR_R USE L L L L U U L L D R R R R').save()

if __name__=='__main__':
 dungeon()
 forest()
 ruins()
 cave()
 sky()
 cosmos()
