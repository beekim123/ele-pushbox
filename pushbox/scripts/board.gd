extends RefCounted
## Pure discrete rules. All commands use names; no SDK calls or randomness.

const WIDTH := 320
const HEIGHT := 192
const TILE := 16
const COLS := 20
const ROWS := 12
const SOLID_BIT := 1
const LOOSE_BIT := 2
const FLUID_BIT := 4
const BREAKABLE_BIT := 8

var rules: Dictionary
var player := Vector2i.ZERO
var boxes: Array = []
var targets: Array = []
var ladders: Array = []
var levers: Array = []
var gates: Array = []
var bag: Dictionary = {}
var bombs: int = 0
var moves: int = 0
var trapped: bool = false
var gate_crushed: Dictionary = {}
var origin := Vector2i.ZERO
var ids := PackedInt32Array()
var names: Array[String] = []
var flags := PackedInt32Array()
var name_ids: Dictionary = {}
var tag_material_ids: Dictionary = {}
var material_definitions: Dictionary = {}
var _counts: Dictionary = {}
var _categories: Dictionary = {}
var read_revision: int = 0
var _classification_threshold: int = 128
var _uniform_rows: Dictionary = {}
var _uniform_counts: Dictionary = {}
var _commands: Array = []

func configure(config: Dictionary, materials: Array, mapping: Dictionary = {}) -> void:
	rules = config.duplicate(true)
	name_ids.clear()
	tag_material_ids.clear()
	material_definitions.clear()
	names.resize(materials.size())
	flags.resize(materials.size())
	for i in materials.size():
		var material: Dictionary = materials[i]
		var index: int = int(mapping.get(material.name, i))
		names[index] = material.name
		name_ids[material.name] = index
		material_definitions[material.name] = material
		var bits: int = 0
		for tag in material.get("tags", []):
			bits |= {"solid": SOLID_BIT, "loose": LOOSE_BIT, "fluid": FLUID_BIT, "breakable": BREAKABLE_BIT}.get(tag, 0)
			if not tag_material_ids.has(tag):
				tag_material_ids[tag] = []
			tag_material_ids[tag].append(index)
		flags[index] = bits
	_counts.clear()
	_categories.clear()
	_uniform_counts.clear()
	_classification_threshold = int(rules.classify.threshold)
	read_revision += 1

func read(data: PackedInt32Array, changed_tiles: Array[int] = []) -> void:
	# SDK color/tick changes do not require recounting unchanged material IDs.
	if ids == data:
		return
	ids = data.duplicate()
	_uniform_rows.clear()
	for row in ROWS:
		var start: int = row * TILE * WIDTH
		var material: int = ids[start]
		if ids.slice(start, start + TILE * WIDTH).count(material) == TILE * WIDTH:
			_uniform_rows[row] = material
	read_revision += 1
	if changed_tiles.is_empty():
		_counts.clear()
		_categories.clear()
	else:
		for key in changed_tiles:
			_counts.erase(key)
			_categories.erase(key)

func inside(tile: Vector2i) -> bool:
	return tile.x >= 0 and tile.x < COLS and tile.y >= 0 and tile.y < ROWS

func seed_counts(key: int, material_counts: PackedInt32Array) -> void:
	# Optional input data from the controller's existing SDK count query.
	# The board remains pure; ID-only callers use counts() below unchanged.
	var result := {"solid": 0, "loose": 0, "fluid": 0, "breakable": 0, "empty": material_counts[0]}
	for tag in tag_material_ids:
		var total: int = 0
		for material in tag_material_ids[tag]:
			total += material_counts[material]
		result[tag] = total
	_counts[key] = result
	_categories.erase(key)

func counts(tile: Vector2i) -> Dictionary:
	if not inside(tile):
		return {"solid": 256, "loose": 0, "fluid": 0, "breakable": 0, "empty": 0}
	var key: int = tile.y * COLS + tile.x
	if _counts.has(key):
		return _counts[key]
	if _uniform_rows.has(tile.y):
		var material: int = _uniform_rows[tile.y]
		if not _uniform_counts.has(material):
			var bits: int = flags[material]
			var result := {"solid": 256 if (bits & SOLID_BIT) != 0 else 0, "loose": 256 if (bits & LOOSE_BIT) != 0 else 0, "fluid": 256 if (bits & FLUID_BIT) != 0 else 0, "breakable": 256 if (bits & BREAKABLE_BIT) != 0 else 0, "empty": 256 if material == 0 else 0}
			for tag in tag_material_ids:
				result[tag] = 256 if material in tag_material_ids[tag] else 0
			_uniform_counts[material] = result
		_counts[key] = _uniform_counts[material]
		return _counts[key]
	# Most tiles are uniformly empty or bedrock. Packed-array count runs in C++;
	# sixteen short row checks avoid 256 interpreted per-cell/tag operations.
	var first: int = ids[tile.y * TILE * WIDTH + tile.x * TILE]
	var uniform: bool = true
	for y in range(tile.y * TILE, (tile.y + 1) * TILE):
		var start: int = y * WIDTH + tile.x * TILE
		if ids.slice(start, start + TILE).count(first) != TILE:
			uniform = false
			break
	if uniform:
		var bits: int = flags[first]
		var result := {"solid": 256 if (bits & SOLID_BIT) != 0 else 0, "loose": 256 if (bits & LOOSE_BIT) != 0 else 0, "fluid": 256 if (bits & FLUID_BIT) != 0 else 0, "breakable": 256 if (bits & BREAKABLE_BIT) != 0 else 0, "empty": 256 if first == 0 else 0}
		_counts[key] = result
		return result
	var solid: int = 0
	var loose: int = 0
	var fluid: int = 0
	var breakable: int = 0
	var empty: int = 0
	for y in range(tile.y * TILE, (tile.y + 1) * TILE):
		var start: int = y * WIDTH + tile.x * TILE
		for x in TILE:
			var material: int = ids[start + x]
			if material == 0:
				empty += 1
				continue
			var bits: int = flags[material]
			solid += int((bits & SOLID_BIT) != 0)
			loose += int((bits & LOOSE_BIT) != 0)
			fluid += int((bits & FLUID_BIT) != 0)
			breakable += int((bits & BREAKABLE_BIT) != 0)
	var result := {"solid": solid, "loose": loose, "fluid": fluid, "breakable": breakable, "empty": empty}
	_counts[key] = result
	return result

func box_at(tile: Vector2i) -> int:
	for i in boxes.size():
		if boxes[i].at == tile:
			return i
	return -1

func tag_count(tile: Vector2i, tag: String) -> int:
	var values: Dictionary = counts(tile)
	if values.has(tag):
		return int(values[tag])
	var total: int = 0
	if inside(tile) and tag_material_ids.has(tag):
		for y in range(tile.y * TILE, (tile.y + 1) * TILE):
			for x in range(tile.x * TILE, (tile.x + 1) * TILE):
				if ids[y * WIDTH + x] in tag_material_ids[tag]:
					total += 1
	values[tag] = total
	return total

func category(tile: Vector2i) -> String:
	if not inside(tile):
		return "SOLID"
	if box_at(tile) >= 0:
		return "BOX"
	if _classification_threshold != int(rules.classify.threshold):
		_categories.clear()
		_classification_threshold = int(rules.classify.threshold)
	var key: int = tile.y * COLS + tile.x
	if _categories.has(key):
		return _categories[key]
	for entry in rules.classify.order:
		if tag_count(tile, entry.tag) >= int(rules.classify.threshold):
			_categories[key] = entry["class"]
			return entry["class"]
	_categories[key] = "OPEN"
	return "OPEN"

func enterable(tile: Vector2i, for_box: bool = false) -> bool:
	return category(tile) in ["OPEN", "WATER"] and (not for_box or tile != player)

func total_bag() -> int:
	var total: int = 0
	for value in bag.values():
		total += int(value)
	return total

func _direction(action: String) -> Vector2i:
	return {"L": Vector2i.LEFT, "R": Vector2i.RIGHT, "U": Vector2i.UP, "D": Vector2i.DOWN}.get(action.get_slice("_", action.get_slice_count("_") - 1), Vector2i.ZERO)

func action_reason(action: String) -> String:
	var direction: Vector2i = _direction(action)
	var tile: Vector2i = player + direction
	if action in ["L", "R"]:
		if enterable(tile):
			return ""
		var b: int = box_at(tile)
		if b >= 0 and box_at(tile + Vector2i.UP) < 0 and enterable(tile + direction, true):
			return ""
		if enterable(player + Vector2i.UP) and enterable(tile + Vector2i.UP):
			return ""
		return "前方挡住了，台阶上也没有空位。"
	if action == "U":
		return "" if player in ladders and enterable(tile) else "只能沿梯子向上爬。"
	if action == "D":
		return "" if tile in ladders and enterable(tile) else "下一格没有可爬的梯子。"
	if action.begins_with("DIG_"):
		if not action.trim_prefix("DIG_") in rules.player.dig_dirs:
			return "不能向这个方向挖。"
		return "" if category(tile) == "SAND" else "这格没有足够的沙可挖。"
	if action.begins_with("POUR_"):
		if not action.trim_prefix("POUR_") in rules.player.pour_dirs:
			return "只能向左右倒沙。"
		if total_bag() == 0:
			return "沙袋是空的。"
		return "" if enterable(tile) and counts(tile).empty > 0 else "这格没有空位可以倒沙。"
	if action.begins_with("BOMB_"):
		if not action.trim_prefix("BOMB_") in rules.player.bomb_dirs:
			return "不能向这个方向爆破。"
		return "" if bombs > 0 and inside(tile) else "没有可用的炸药。"
	if action == "USE":
		for lever in levers:
			if lever.at == player:
				return ""
		return "这里没有拉杆。"
	return "未知动作。"

func apply_action(action: String) -> Dictionary:
	var reason: String = action_reason(action)
	if not reason.is_empty():
		return {"legal": false, "reason": reason, "commands": []}
	_commands = []
	var direction: Vector2i = _direction(action)
	var tile: Vector2i = player + direction
	var amount: int = 0
	if action in ["L", "R"]:
		if enterable(tile):
			player = tile
		elif box_at(tile) >= 0 and box_at(tile + Vector2i.UP) < 0 and enterable(tile + direction, true):
			var index: int = box_at(tile)
			_swap_box(index, tile + direction)
			player = tile
		else:
			player = tile + Vector2i.UP
	elif action in ["U", "D"]:
		player = tile
	elif action.begins_with("DIG_"):
		for y in range(tile.y * TILE, (tile.y + 1) * TILE):
			for x in range(tile.x * TILE, (tile.x + 1) * TILE):
				var material: int = ids[y * WIDTH + x]
				if material in tag_material_ids.get(rules.dig.tag, []):
					bag[names[material]] = int(bag.get(names[material], 0)) + 1
					_set_cell(x, y, "empty")
					amount += 1
	elif action.begins_with("POUR_"):
		var order: Array = rules.pour.order.duplicate()
		var extra: Array = bag.keys().filter(func(name: String) -> bool: return not name in order)
		extra.sort()
		order.append_array(extra)
		var left: int = mini(total_bag(), int(rules.pour.max_cells))
		for y in range(tile.y * TILE, (tile.y + 1) * TILE):
			for x in range(tile.x * TILE, (tile.x + 1) * TILE):
				if left == 0 or ids[y * WIDTH + x] != 0:
					continue
				for name in order:
					if int(bag.get(name, 0)) > 0:
						_set_cell(x, y, name)
						bag[name] -= 1
						left -= 1
						amount += 1
						break
	elif action.begins_with("BOMB_"):
		_commands.append({"op": "explode", "args": [tile.x * TILE + 8, tile.y * TILE + 8, int(rules.bomb.radius_cells), int(rules.bomb.power)]})
		bombs -= 1
	elif action == "USE":
		for lever in levers:
			if lever.at == player:
				lever.on = not lever.on
				break
	moves += 1
	return {"legal": true, "reason": "", "commands": _commands, "amount": amount}

func _set_cell(x: int, y: int, name: String) -> void:
	_commands.append({"op": "set_cell", "args": [x, y, name]})
	ids[y * WIDTH + x] = name_ids[name]
	if _uniform_rows.get(y / TILE, -1) != int(name_ids[name]):
		_uniform_rows.erase(y / TILE)
	_counts.erase((y / TILE) * COLS + x / TILE)
	_categories.erase((y / TILE) * COLS + x / TILE)
	read_revision += 1

func _paint(tile: Vector2i, name: String) -> void:
	_commands.append({"op": "clear_rect", "args": [tile.x * TILE, tile.y * TILE, TILE, TILE]} if name == "empty" else {"op": "paint_rect", "args": [tile.x * TILE, tile.y * TILE, TILE, TILE, name]})
	for y in range(tile.y * TILE, (tile.y + 1) * TILE):
		_fill_row(y * WIDTH + tile.x * TILE, name_ids[name])
	if _uniform_rows.get(tile.y, -1) != int(name_ids[name]):
		_uniform_rows.erase(tile.y)
	_counts.erase(tile.y * COLS + tile.x)
	_categories.erase(tile.y * COLS + tile.x)
	read_revision += 1

func _fill_row(start: int, material: int) -> void:
	for x in TILE:
		ids[start + x] = material

func _swap_box(index: int, destination: Vector2i) -> void:
	var old: Vector2i = boxes[index].at
	var contents := PackedInt32Array()
	for y in range(destination.y * TILE, (destination.y + 1) * TILE):
		contents.append_array(ids.slice(y * WIDTH + destination.x * TILE, y * WIDTH + (destination.x + 1) * TILE))
	_paint(destination, rules.box_kinds[boxes[index].kind].material)
	_paint(old, "empty")
	for i in contents.size():
		if contents[i] != 0:
			_set_cell(old.x * TILE + i % TILE, old.y * TILE + i / TILE, names[contents[i]])
	boxes[index].at = destination
	if rules.settle.wake_water:
		for neighbour in [old + Vector2i.DOWN, old + Vector2i.LEFT, old + Vector2i.RIGHT]:
			if not inside(neighbour):
				continue
			var found: bool = false
			for y in range(neighbour.y * TILE, (neighbour.y + 1) * TILE):
				for x in range(neighbour.x * TILE, (neighbour.x + 1) * TILE):
					var material: int = ids[y * WIDTH + x]
					if (flags[material] & FLUID_BIT) != 0:
						_commands.append({"op": "set_cell", "args": [x, y, "empty"]})
						_commands.append({"op": "set_cell", "args": [x, y, names[material]]})
						found = true
						break
				if found:
					break

func _supported(box: Dictionary) -> bool:
	var below: Vector2i = box.at + Vector2i.DOWN
	if category(below) in ["SOLID", "SAND", "BOX"] or below == player:
		return true
	var kind: Dictionary = rules.box_kinds[box.kind]
	return kind.floats and counts(below).fluid >= int(kind.float_support)

func _water_top(seeds: Array) -> int:
	var seen: Dictionary = {}
	var stack: Array[Vector2i] = []
	for tile in seeds:
		if category(tile) == "WATER" and not seen.has(tile):
			seen[tile] = true
			stack.append(tile)
	var top: int = ROWS + 1
	while not stack.is_empty():
		var tile: Vector2i = stack.pop_back()
		top = mini(top, tile.y)
		for direction in [Vector2i.RIGHT, Vector2i.LEFT, Vector2i.DOWN, Vector2i.UP]:
			var neighbour: Vector2i = tile + direction
			if not seen.has(neighbour) and category(neighbour) == "WATER":
				seen[neighbour] = true
				stack.append(neighbour)
	return top

func _breakable_tiles() -> Array:
	var tiles: Dictionary = {}
	for material in tag_material_ids.get(rules.bomb.crumble_tag, []):
		var index: int = ids.find(material)
		while index >= 0:
			tiles[Vector2i((index % WIDTH) / TILE, (index / WIDTH) / TILE)] = true
			index = ids.find(material, index + 1)
	var result: Array = tiles.keys()
	result.sort_custom(func(a: Vector2i, b: Vector2i) -> bool: return a.y < b.y or (a.y == b.y and a.x < b.x))
	return result

func resolve_round() -> Dictionary:
	_commands = []
	var changed: bool = false
	var before: String = actors_key()
	for tile in _breakable_tiles():
		var remaining: int = tag_count(tile, rules.bomb.crumble_tag)
		if remaining > 0 and remaining < int(rules.bomb.crumble_below):
			for y in range(tile.y * TILE, (tile.y + 1) * TILE):
				for x in range(tile.x * TILE, (tile.x + 1) * TILE):
					if ids[y * WIDTH + x] in tag_material_ids.get(rules.bomb.crumble_tag, []):
						_set_cell(x, y, "empty")
			changed = true
	var order: Array = range(boxes.size())
	order.sort_custom(func(a: int, b: int) -> bool: return boxes[a].at.y > boxes[b].at.y or (boxes[a].at.y == boxes[b].at.y and boxes[a].at.x < boxes[b].at.x))
	for index in order:
		if not _supported(boxes[index]):
			while not _supported(boxes[index]):
				_swap_box(index, boxes[index].at + Vector2i.DOWN)
			changed = true
			continue
		var tile: Vector2i = boxes[index].at
		if not rules.box_kinds[boxes[index].kind].floats or not enterable(tile + Vector2i.UP, true):
			continue
		var rise: bool = category(tile + Vector2i.DOWN) == "WATER" and _water_top([tile + Vector2i.DOWN]) <= tile.y
		if not rise:
			rise = _water_top([tile + Vector2i.LEFT, tile + Vector2i.RIGHT]) <= tile.y - 1
		if rise:
			_swap_box(index, tile + Vector2i.UP)
			changed = true
	trapped = false
	if category(player) in ["SOLID", "SAND"]:
		var escape: Vector2i = player + Vector2i.UP
		while escape.y >= 0 and not enterable(escape):
			escape.y -= 1
		if escape.y < 0:
			trapped = true
		else:
			player = escape
			changed = true
	while not player in ladders and not (player + Vector2i.DOWN) in ladders and enterable(player + Vector2i.DOWN):
		player.y += 1
		changed = true
	for gate in gates:
		var want: bool = condition(gate.open_when)
		if want and not gate.open:
			for tile in gate.tiles:
				_paint(tile, "empty")
			gate.open = true
			changed = true
		elif not want and gate.open:
			var occupied: bool = false
			var stuff: int = 0
			for tile in gate.tiles:
				stuff += 256 - int(counts(tile).empty)
				occupied = occupied or tile == player or box_at(tile) >= 0
			if not occupied and stuff <= int(rules.gate.crush_max):
				for tile in gate.tiles:
					for y in range(tile.y * TILE, (tile.y + 1) * TILE):
						for x in range(tile.x * TILE, (tile.x + 1) * TILE):
							var name: String = names[ids[y * WIDTH + x]]
							if name != "empty":
								gate_crushed[name] = int(gate_crushed.get(name, 0)) + 1
					_paint(tile, "gate")
				gate.open = false
				changed = true
	return {"changed": changed, "moved": before != actors_key(), "commands": _commands}

func condition(expression: Variant) -> bool:
	if expression is String:
		return expression == "start" and moves == 0
	if not expression is Dictionary:
		return false
	if expression.has("all"):
		for item in expression.all:
			if not condition(item):
				return false
		return true
	if expression.has("any"):
		for item in expression.any:
			if condition(item):
				return true
		return false
	if expression.has("not"):
		return not condition(expression["not"])
	if expression.has("lever"):
		for lever in levers:
			if lever.id == expression.lever:
				return lever.on
	if expression.has("plate"):
		var tile: Vector2i = origin + Vector2i(expression.plate[0], expression.plate[1])
		var by: String = expression.get("by", "any")
		return (by in ["box", "any"] and box_at(tile) >= 0) or (by in ["player", "any"] and tile == player)
	if expression.has("water"):
		return category(origin + Vector2i(expression.water[0], expression.water[1])) == "WATER"
	if expression.has("count"):
		var rect: Array = expression.count.rect
		var total: int = 0
		for y in range(rect[1], rect[1] + rect[3]):
			for x in range(rect[0], rect[0] + rect[2]):
				total += tag_count(origin + Vector2i(x, y), expression.count.tag)
		return total >= int(expression.count.gte)
	if expression.has("box_at"):
		for box in boxes:
			if box.id == expression.box_at[0]:
				return box.at == origin + Vector2i(expression.box_at[1][0], expression.box_at[1][1])
	if expression.has("moves_gt"):
		return moves > int(expression.moves_gt)
	return false

func won() -> bool:
	if boxes.size() != targets.size():
		return false
	for target in targets:
		if box_at(target) < 0:
			return false
	return true

func actors_key() -> String:
	var values: Array = [player.x, player.y]
	var ordered: Array = boxes.duplicate()
	ordered.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return a.id < b.id)
	for box in ordered:
		values.append_array([box.id, box.at.x, box.at.y])
	return JSON.stringify(values)

func movement_key() -> String:
	var values: Array = [actors_key()]
	for gate in gates:
		values.append([gate.id, gate.open])
	for lever in levers:
		values.append([lever.id, lever.on])
	return JSON.stringify(values)

func categories() -> PackedStringArray:
	var result := PackedStringArray()
	for y in ROWS:
		for x in COLS:
			result.append(category(Vector2i(x, y)))
	return result

func position_key() -> String:
	return JSON.stringify([movement_key(), bombs, Array(categories())])

func state() -> Dictionary:
	var result := {"player": [player.x, player.y], "boxes": [], "levers": [], "gates": [], "bag": bag.duplicate(), "bombs": bombs, "moves": moves, "trapped": trapped, "gate_crushed": gate_crushed.duplicate()}
	for box in boxes:
		result.boxes.append({"id": box.id, "at": [box.at.x, box.at.y], "kind": box.kind})
	for lever in levers:
		result.levers.append({"id": lever.id, "at": [lever.at.x, lever.at.y], "on": lever.on})
	for gate in gates:
		result.gates.append({"id": gate.id, "open": gate.open})
	return result

func restore(data: Dictionary) -> void:
	player = Vector2i(data.player[0], data.player[1])
	boxes = data.boxes.duplicate(true)
	for box in boxes:
		box.at = Vector2i(box.at[0], box.at[1])
	for i in levers.size():
		levers[i].on = data.levers[i].on
	for i in gates.size():
		gates[i].open = data.gates[i].open
	bag = data.bag.duplicate()
	for material in bag:
		bag[material] = int(bag[material])
	bombs = int(data.bombs)
	moves = int(data.moves)
	trapped = data.trapped
	gate_crushed = data.gate_crushed.duplicate()
	for material in gate_crushed:
		gate_crushed[material] = int(gate_crushed[material])
