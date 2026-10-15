class_name LevelGridState
extends RefCounted
## Gameplay terrain excludes crate entities and the door overlay.

enum Terrain { EMPTY, ROCK, CRACKED, EARTH, SAND, WATER, DOOR }
enum Marker { NONE, LADDER, SOCKET, EXIT, PLATE }

var width: int = 0
var height: int = 0
var terrain: Array[int] = []
var markers: Array[int] = []
var player: Dictionary = {}
var crates: Array[Dictionary] = []
var bag: Dictionary = {"sand": 0, "bomb": 0}
var groups: Array[Dictionary] = []
var open: Array[int] = []
var door_at: Dictionary = {}
var moves: int = 0
var last_error: String = ""

func parse(spec: Dictionary) -> bool:
	var rows: Array = spec.get("map", [])
	if rows.is_empty() or not rows[0] is String:
		last_error = "Level map is missing"
		return false
	height = rows.size()
	width = str(rows[0]).length()
	if width < 3 or width > 20 or height < 3 or height > 10:
		last_error = "Level dimensions must be within 20 by 10 tiles"
		return false
	terrain.resize(width * height)
	terrain.fill(Terrain.EMPTY)
	markers.resize(width * height)
	markers.fill(Marker.NONE)
	player.clear()
	crates.clear()
	var door_cells: Array[int] = []
	var plates: Array[int] = []
	for y: int in range(height):
		if str(rows[y]).length() != width:
			last_error = "Map rows have different widths"
			return false
		for x: int in range(width):
			var character: String = str(rows[y]).substr(x, 1)
			var index: int = y * width + x
			if (x == 0 or y == 0 or x == width - 1 or y == height - 1) and character != "#":
				last_error = "Room boundary must be bedrock"
				return false
			match character:
				"#": terrain[index] = Terrain.ROCK
				"e": terrain[index] = Terrain.EARTH
				"s": terrain[index] = Terrain.SAND
				".": pass
				"|": door_cells.append(index)
				"H": markers[index] = Marker.LADDER
				"o": markers[index] = Marker.SOCKET
				"X": markers[index] = Marker.EXIT
				"_":
					markers[index] = Marker.PLATE
					plates.append(index)
				"P", "h":
					if not player.is_empty():
						last_error = "Level has multiple players"
						return false
					player = {"x": x, "y": y}
					if character == "h":
						markers[index] = Marker.LADDER
				"B", "I", "b":
					crates.append({"x": x, "y": y, "kind": "iron" if character == "I" else "wood"})
					if character == "b":
						markers[index] = Marker.SOCKET
				_:
					last_error = "Unsupported basics map character: " + character
					return false
	if player.is_empty():
		last_error = "Level has no player"
		return false
	bag = {"sand": int(spec.get("bag", {}).get("sand", 0)), "bomb": int(spec.get("bag", {}).get("bomb", 0))}
	if bag.sand < 0 or bag.sand > 9 or bag.bomb < 0:
		last_error = "Invalid starting inventory"
		return false
	groups.clear()
	door_at.clear()
	open.clear()
	if spec.has("links"):
		for link: Dictionary in spec.links:
			var group: Dictionary = {"plates": [], "doors": [], "latch": bool(link.get("latch", false))}
			for point: Array in link.get("plates", []):
				if not inside(int(point[0]), int(point[1])):
					last_error = "Plate outside map"
					return false
				var index: int = int(point[1]) * width + int(point[0])
				group.plates.append(index)
				markers[index] = Marker.PLATE
			for point: Array in link.get("doors", []):
				group.doors.append(int(point[1]) * width + int(point[0]))
			groups.append(group)
	else:
		groups.append({"plates": plates, "doors": door_cells, "latch": false})
	for group_index: int in range(groups.size()):
		open.append(0)
		for index: int in groups[group_index].doors:
			if index not in door_cells or door_at.has(index):
				last_error = "Door group contains unknown or duplicate door"
				return false
			door_at[index] = group_index
	for index: int in door_cells:
		if not door_at.has(index):
			last_error = "Door is not assigned to a group"
			return false
	if not spec.get("devices", []).is_empty() or not spec.get("water", []).is_empty():
		last_error = "Stage two devices and water require their SDK samples"
		return false
	moves = 0
	return true

func inside(x: int, y: int) -> bool:
	return x >= 0 and y >= 0 and x < width and y < height

func tile_index(x: int, y: int) -> int:
	return y * width + x

func terrain_at(x: int, y: int) -> int:
	if not inside(x, y):
		return Terrain.ROCK
	var index: int = tile_index(x, y)
	if door_at.has(index) and open[int(door_at[index])] == 0:
		return Terrain.DOOR
	return terrain[index]

func crate_index(x: int, y: int) -> int:
	for index: int in range(crates.size()):
		if int(crates[index].x) == x and int(crates[index].y) == y:
			return index
	return -1

func is_player(x: int, y: int) -> bool:
	return int(player.x) == x and int(player.y) == y

func is_ladder(x: int, y: int) -> bool:
	return inside(x, y) and markers[tile_index(x, y)] == Marker.LADDER

func supports(x: int, y: int) -> bool:
	var tile: int = terrain_at(x, y)
	return tile not in [Terrain.EMPTY, Terrain.WATER] or crate_index(x, y) >= 0

func is_free(x: int, y: int) -> bool:
	return inside(x, y) and terrain_at(x, y) in [Terrain.EMPTY, Terrain.WATER] and crate_index(x, y) < 0 and not is_player(x, y)

func blocked_for_door(index: int) -> bool:
	var x: int = index % width
	var y: int = int(index / width)
	return is_player(x, y) or crate_index(x, y) >= 0 or terrain[index] != Terrain.EMPTY

func export_state() -> Dictionary:
	return {"w": width, "h": height, "player": player.duplicate(true), "crates": crates.duplicate(true), "terrain": terrain.duplicate(), "bag": bag.duplicate(), "open": open.duplicate(), "moves": moves}

func import_state(saved: Dictionary) -> void:
	player = {"x": int(saved.player.x), "y": int(saved.player.y)}
	crates.clear()
	for crate: Dictionary in saved.crates:
		crates.append({"x": int(crate.x), "y": int(crate.y), "kind": str(crate.kind)})
	terrain.clear()
	for tile: Variant in saved.terrain:
		terrain.append(int(tile))
	bag = {"sand": int(saved.bag.sand), "bomb": int(saved.bag.bomb)}
	open.clear()
	for door: Variant in saved.open:
		open.append(int(door))
	moves = int(saved.moves)
