extends RefCounted
## Stable campaign IDs and ordered six-level pools; save progress stores IDs only.
const THEMES := ["dungeon","forest","ruins","cave","sky_island","cosmos"]
const MAP_NAMES := ["幽暗石牢","迷雾古森","黄金神庙","幽光晶窟","云端圣域","深空星站"]
const SHORT_NAMES := ["石牢","古森","神庙","晶窟","天空","星站"]
const PREFIXES := ["D","F","R","C","S","X"]
const TITLES := [
	["沉铁开道","一沙卡千斤","一沙二用","爆柱填渊","铁木双井","深层矿井枢纽"],
	["甘霖育藤","浮木渡津","筑坝引泉","斩藤落箱","双藤交错","巨木盘根水殿"],
	["黄金天平","流沙漏斗","掬沙称重","沙漏与水钟","双盘博弈","日轮金字塔内殿"],
	["滴酸穿石","水火化沙","引酸入渠","钟乳石坠","双色沙漏","幽光晶簇与熔脉"],
	["履冰过渊","轻重云垫","冰封水位线","顺风扬沙","破冰坠锚","破晓云海风之圣域"],
	["量子跃迁","隔空传沙","失重回廊","等离子冷却","星门双生","深空星站：曲率反应舱"]]
const FEATURES := ["防夹闸 · 矿柱塌方","遇水育藤 · 林泉浮箱","流沙漏斗 · 配重天平","酸蚀 · 重锤 · 间歇泉","冷冻 · 云垫 · 顺风场","量子传送 · 反重力舱"]
static func id(map: int, index: int) -> String:
	return "%s_%02d" % [PREFIXES[map],index+1]
static func path(map: int, index: int) -> String:
	return "res://pushbox/levels/campaign/%s/c_%s_%02d.json" % [THEMES[map],THEMES[map],index+1]
static func locate(value: String) -> Vector2i:
	if value.length() != 4 or value[1] != "_":
		return Vector2i(-1,-1)
	var map: int = PREFIXES.find(value.substr(0,1))
	var index: int = value.substr(2).to_int()-1
	if map < 0 or index < 0 or index >= 6 or value != id(map,index):
		return Vector2i(-1,-1)
	return Vector2i(map,index)
static func count(completed: Dictionary, map: int) -> int:
	var total: int = 0
	for index in 6:
		total += int(completed.get(id(map,index),false) == true)
	return total
static func map_unlocked(completed: Dictionary, map: int) -> bool:
	if map < 0 or map >= 6:
		return false
	for before in map:
		if count(completed,before) < 3:
			return false
	return true
static func level_unlocked(completed: Dictionary, map: int, index: int) -> bool:
	return map_unlocked(completed,map) and index >= 0 and index < mini(6,2+2*count(completed,map))
static func mainline_complete(completed: Dictionary) -> bool:
	for map in 6:
		if count(completed,map) < 3:
			return false
	return true
