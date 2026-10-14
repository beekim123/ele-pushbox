extends RefCounted
## Validate before starting the world; preserve the template's paint order.

const ACTIONS := ["L", "R", "U", "D", "DIG_L", "DIG_R", "DIG_D", "POUR_L", "POUR_R", "BOMB_L", "BOMB_R", "BOMB_D", "USE"]

static func json(path: String) -> Dictionary:
	var parser := JSON.new()
	if parser.parse(FileAccess.get_file_as_string(path)) != OK or not parser.data is Dictionary:
		return {}
	return parser.data

static func merge(base: Dictionary, override: Dictionary) -> Dictionary:
	var result: Dictionary = base.duplicate(true)
	for key in override:
		if override[key] is Dictionary and result.get(key) is Dictionary:
			result[key] = merge(result[key], override[key])
		else:
			result[key] = override[key]
	return result

static func _coord(value: Variant, width: int, height: int) -> bool:
	return value is Array and value.size() == 2 and value[0] is float and value[1] is float and value[0] == int(value[0]) and value[1] == int(value[1]) and value[0] >= 0 and value[0] < width and value[1] >= 0 and value[1] < height

static func _guide_condition(value: Variant, width: int, height: int, entities: Dictionary) -> bool:
	if value is String:
		return value in ["start", "moved", "dug", "poured", "bomb_dragged", "lever_used"]
	if not value is Dictionary or value.is_empty():
		return false
	for group in ["all", "any"]:
		if value.has(group):
			if value.size() != 1 or not value[group] is Array or value[group].is_empty():
				return false
			for child in value[group]:
				if not _guide_condition(child, width, height, entities):
					return false
			return true
	if value.has("not"):
		return value.size() == 1 and _guide_condition(value["not"], width, height, entities)
	if value.has("player_at"):
		return value.size() == 1 and _coord(value.player_at, width, height)
	if value.has("box_at"):
		var box: Variant = value.box_at
		return value.size() == 1 and box is Array and box.size() == 2 and box[0] is String and entities.boxes.any(func(item: Dictionary) -> bool: return item.id == box[0]) and _coord(box[1], width, height)
	if value.has("lever"):
		return value.size() == 1 and value.lever is String and entities.get("levers", []).any(func(item: Dictionary) -> bool: return item.id == value.lever)
	if value.has("plate"):
		return value.size() <= 2 and _coord(value.plate, width, height) and value.get("by", "any") in ["any", "player", "box"]
	if value.has("water"):
		return value.size() == 1 and _coord(value.water, width, height)
	if value.has("moves_gt"):
		return value.size() == 1 and value.moves_gt is float and value.moves_gt >= 0 and value.moves_gt == int(value.moves_gt)
	if value.has("count"):
		var count: Variant = value.count
		if value.size() != 1 or not count is Dictionary or not count.get("rect") is Array or count.rect.size() != 4 or not count.get("tag") is String or not count.get("gte") is float:
			return false
		for number in count.rect:
			if not number is float or number != int(number):
				return false
		return count.rect[0] >= 0 and count.rect[1] >= 0 and count.rect[2] > 0 and count.rect[3] > 0 and count.rect[0] + count.rect[2] <= width and count.rect[1] + count.rect[3] <= height and count.gte >= 0 and count.gte == int(count.gte)
	return false

static func validate(level: Dictionary, materials: Array, rules: Dictionary) -> String:
	if level.get("format") != "pushbox.level/1" or not level.get("map") is Array or level.map.is_empty():
		return "关卡格式或地图无效。"
	var grid: Array = level.map
	if not grid[0] is String or grid[0].is_empty():
		return "地图第一行无效。"
	var width: int = grid[0].length()
	var height: int = grid.size()
	if width > 20 or height > 11:
		return "地图超过 20×11 格。"
	if not level.get("legend") is Dictionary or not level.get("entities") is Dictionary:
		return "缺少图例或物件。"
	var definitions: Dictionary = {}
	for material in materials:
		definitions[material.name] = material
	var gate_tiles: Dictionary = {}
	for y in height:
		if not grid[y] is String or grid[y].length() != width:
			return "地图每行必须等宽。"
		for x in width:
			if not level.legend.has(grid[y][x]):
				return "图例中不存在字符：" + grid[y][x]
			var entry: Variant = level.legend[grid[y][x]]
			var name: String = entry if entry is String else str(entry.get("material", ""))
			if not definitions.has(name):
				return "未知材料：" + name
			if name == "gate":
				gate_tiles[Vector2i(x, y)] = true
			if entry is Dictionary:
				if not definitions[name]["class"] in ["powder", "liquid"]:
					return "只有沙和液体允许部分填充。"
				var fill: float = float(entry.get("fill", 1.0))
				if fill < 0.0 or fill > 1.0:
					return "填充比例必须在 0 到 1 之间。"
	var entities: Dictionary = level.entities
	if not _coord(entities.get("player"), width, height):
		return "人物坐标无效。"
	var occupied: Array = [Vector2i(entities.player[0], entities.player[1])]
	var box_ids: Array = []
	for box in entities.get("boxes", []):
		if not _coord(box.get("at"), width, height) or not rules.box_kinds.has(box.get("kind")) or not box.get("id") is String:
			return "箱子配置无效。"
		var tile := Vector2i(box.at[0], box.at[1])
		if tile in occupied or box.id in box_ids:
			return "箱子坐标或 id 重复。"
		occupied.append(tile)
		box_ids.append(box.id)
	for kind in ["targets", "ladders"]:
		var seen: Array = []
		for at in entities.get(kind, []):
			if not _coord(at, width, height) or at in seen:
				return "目标或梯子坐标无效或重复。"
			seen.append(at)
	if entities.get("boxes", []).size() != entities.get("targets", []).size():
		return "箱子和目标数量不相等。"
	var lever_ids: Array = []
	for lever in entities.get("levers", []):
		if not _coord(lever.get("at"), width, height) or not lever.get("id") is String or lever.id in lever_ids:
			return "拉杆配置无效。"
		lever_ids.append(lever.id)
	var declared: Dictionary = {}
	for mechanism in level.get("mechanisms", []):
		if mechanism.get("kind") != "gate" or not mechanism.get("open_when") is Dictionary:
			return "机关配置无效。"
		for at in mechanism.get("tiles", []):
			if not _coord(at, width, height):
				return "闸门坐标无效。"
			var tile := Vector2i(at[0], at[1])
			if declared.has(tile):
				return "闸门组重叠。"
			declared[tile] = true
	if declared.size() != gate_tiles.size():
		return "地图闸门与机关坐标不一致。"
	for tile in declared:
		if not gate_tiles.has(tile):
			return "地图闸门与机关坐标不一致。"
	for action in level.get("solution", []):
		if not action in ACTIONS:
			return "作者解法有未知动作。"
	if not level.get("guides", []) is Array:
		return "引导必须是数组。"
	var guide_ids: Array[String] = []
	for guide in level.get("guides", []):
		if not guide is Dictionary or not guide.get("id") is String or guide.id in guide_ids:
			return "引导 id 无效或重复。"
		if guide.has("after") and not guide.after in guide_ids:
			return "引导 after 必须指向前一条引导。"
		guide_ids.append(guide.id)
		if not _guide_condition(guide.get("start", "start"), width, height, entities) or not _guide_condition(guide.get("done"), width, height, entities):
			return "引导开始或完成条件无效。"
		if not guide.get("text", "") is String or guide.get("text", "").length() > 8:
			return "引导文字最多 8 个字。"
		var modes: int = int(guide.has("keycap")) + int(guide.has("mouse")) + int(guide.has("hand"))
		if modes != 1:
			return "每条引导必须选择一种图标。"
		if guide.has("keycap") and not guide.keycap in ["UP", "DOWN", "LEFT_RIGHT", "Z_R"]:
			return "引导键帽无效。"
		if guide.has("point") and guide.point is Array and not _coord(guide.point, width, height):
			return "引导坐标无效。"
		if guide.has("mouse"):
			if not guide.mouse is Dictionary or not _coord(guide.mouse.get("at"), width, height) or not guide.mouse.get("button") in ["left", "right"]:
				return "鼠标引导坐标或按钮无效。"
		if guide.has("hand") and (not guide.hand is Dictionary or guide.hand.get("from") != "hud:bombs" or guide.hand.get("to") != "map"):
			return "拖动引导配置无效。"
	if int(rules.settle.quiet_ticks) <= 1 or int(rules.classify.threshold) < 1 or int(rules.classify.threshold) > 256:
		return "规则参数无效。"
	return ""

static func populate(board: RefCounted, level: Dictionary) -> Array:
	var origin := Vector2i((20 - level.map[0].length()) / 2, (12 - level.map.size()) / 2)
	board.origin = origin
	var entities: Dictionary = level.entities
	board.player = origin + Vector2i(entities.player[0], entities.player[1])
	for box in entities.boxes:
		board.boxes.append({"id": box.id, "at": origin + Vector2i(box.at[0], box.at[1]), "kind": box.kind})
	for kind in ["targets", "ladders"]:
		for at in entities.get(kind, []):
			board[kind].append(origin + Vector2i(at[0], at[1]))
	for lever in entities.get("levers", []):
		board.levers.append({"id": lever.id, "at": origin + Vector2i(lever.at[0], lever.at[1]), "on": lever.get("initial", false)})
	for gate in level.get("mechanisms", []):
		var tiles: Array = []
		for at in gate.tiles:
			tiles.append(origin + Vector2i(at[0], at[1]))
		board.gates.append({"id": gate.id, "tiles": tiles, "open_when": gate.open_when.duplicate(true), "open": false})
	board.bombs = int(level.budget.get("bombs", 0))
	board.bag = {"sand": int(level.budget.get("sand_cells", 0))}
	var commands: Array = [{"op": "paint_rect", "args": [0, 0, 320, 192, "bedrock"]}]
	for y in level.map.size():
		for x in level.map[y].length():
			var entry: Variant = level.legend[level.map[y][x]]
			var name: String = entry if entry is String else str(entry.material)
			var cx: int = (origin.x + x) * 16
			var cy: int = (origin.y + y) * 16
			if name == "empty" or entry is Dictionary:
				commands.append({"op": "clear_rect", "args": [cx, cy, 16, 16]})
			else:
				commands.append({"op": "paint_rect", "args": [cx, cy, 16, 16, name]})
			if entry is Dictionary:
				var filled: int = int(floor(float(entry.get("fill", 1.0)) * 16))
				if filled > 0:
					commands.append({"op": "paint_rect", "args": [cx, cy + 16 - filled, 16, filled, name]})
	for box in board.boxes:
		commands.append({"op": "paint_rect", "args": [box.at.x * 16, box.at.y * 16, 16, 16, board.rules.box_kinds[box.kind].material]})
	return commands
