class_name CrateWaterRules
extends RefCounted
## Preserves individual SDK water cells when static crate footprints move.
## Water itself is advanced only by EleWorld, never by the design model.

const SIZE: int = 16
const WORLD_WIDTH: int = 320

static func positions(ids: PackedInt32Array, material: int, tile: Vector2i) -> Array[int]:
	var result: Array[int] = []
	for y: int in range(tile.y * SIZE, (tile.y + 1) * SIZE):
		for x: int in range(tile.x * SIZE, (tile.x + 1) * SIZE):
			var index: int = y * WORLD_WIDTH + x
			if index >= 0 and index < ids.size() and ids[index] == material:
				result.append(index)
	return result

static func component(ids: PackedInt32Array, water: int, seeds: Array[int], width: int, height: int) -> Array[int]:
	var result: Array[int] = []
	var seen: Dictionary = {}
	for seed: int in seeds:
		if seed >= 0 and seed < ids.size() and ids[seed] == water and not seen.has(seed):
			seen[seed] = true
			result.append(seed)
	var cursor: int = 0
	while cursor < result.size():
		var index: int = result[cursor]
		cursor += 1
		var x: int = index % WORLD_WIDTH
		var y: int = int(index / WORLD_WIDTH)
		for delta: Vector2i in [Vector2i.LEFT, Vector2i.RIGHT, Vector2i.UP, Vector2i.DOWN]:
			var nx: int = x + delta.x
			var ny: int = y + delta.y
			var other: int = ny * WORLD_WIDTH + nx
			if nx >= 0 and nx < width * SIZE and ny >= 0 and ny < height * SIZE and not seen.has(other) and ids[other] == water:
				seen[other] = true
				result.append(other)
	return result

static func displacement(context, crate_index: int, destination: Vector2i, mode: String, reserved: Array = []) -> Dictionary:
	var crate: Dictionary = context.grid.crates[crate_index]
	return _displacement(context, destination, mode, Vector2i(int(crate.x), int(crate.y)), reserved)

static func pour_displacement(context, destination: Vector2i) -> Dictionary:
	return _displacement(context, destination, "surface", Vector2i(-1, -1))

static func _displacement(context, destination: Vector2i, mode: String, source: Vector2i, reserved: Array = []) -> Dictionary:
	var world = context.world
	if not world.material_ids.has("water"):
		return {"ok": true, "from": [], "to": []}
	var ids: PackedInt32Array = context.material_ids_view()
	if ids.size() != 320 * 192:
		return {"ok": false}
	var water: int = int(world.material_ids.water)
	var from: Array[int] = positions(ids, water, destination)
	if from.is_empty():
		return {"ok": true, "from": [], "to": []}
	if mode == "exchange":
		var targets: Array[int] = []
		for index: int in from:
			var local_x: int = index % WORLD_WIDTH - destination.x * SIZE
			var local_y: int = int(index / WORLD_WIDTH) - destination.y * SIZE
			targets.append((source.y * SIZE + local_y) * WORLD_WIDTH + source.x * SIZE + local_x)
		return {"ok": true, "from": from, "to": targets}
	var body: Array[int] = component(ids, water, from, context.width, context.height)
	var candidates: Array[int] = []
	var tile_candidates: Dictionary = {}
	for pixel: int in body:
		var tile: Vector2i = Vector2i(int((pixel % WORLD_WIDTH) / SIZE), int(int(pixel / WORLD_WIDTH) / SIZE))
		for delta: Vector2i in [Vector2i.ZERO, Vector2i.UP, Vector2i.LEFT, Vector2i.RIGHT, Vector2i.DOWN]:
			var neighbor: Vector2i = tile + delta
			if context.grid.inside(neighbor.x, neighbor.y) and neighbor != destination and (mode != "float" or neighbor != source):
				tile_candidates[context.grid.tile_index(neighbor.x, neighbor.y)] = neighbor
	# Restrict the search to the pool and its immediately adjacent tile
	# footprints. Within them, actual cell connectivity still prevents moving
	# water through a partly eroded solid wall into disconnected air pockets.
	var queue: Array[int] = body.duplicate()
	var seen: Dictionary = {}
	for pixel: int in reserved:
		seen[pixel] = true
	for pixel: int in queue:
		seen[pixel] = true
	var cursor: int = 0
	while cursor < queue.size():
		var pixel: int = queue[cursor]
		cursor += 1
		var point: Vector2i = Vector2i(pixel % WORLD_WIDTH, int(pixel / WORLD_WIDTH))
		for delta: Vector2i in [Vector2i.UP, Vector2i.LEFT, Vector2i.RIGHT, Vector2i.DOWN]:
			var next: Vector2i = point + delta
			if next.x < 0 or next.y < 0 or next.x >= context.width * SIZE or next.y >= context.height * SIZE:
				continue
			var tile: Vector2i = Vector2i(int(next.x / SIZE), int(next.y / SIZE))
			var other: int = next.y * WORLD_WIDTH + next.x
			if tile == destination or not tile_candidates.has(context.grid.tile_index(tile.x, tile.y)) or seen.has(other):
				continue
			if ids[other] != int(world.material_ids.empty) and tile != source:
				continue
			seen[other] = true
			queue.append(other)
			candidates.append(other)
	candidates.sort_custom(func(a: int, b: int) -> bool: return int(a / WORLD_WIDTH) > int(b / WORLD_WIDTH) if int(a / WORLD_WIDTH) != int(b / WORLD_WIDTH) else a < b)
	if candidates.size() < from.size():
		return {"ok": false}
	return {"ok": true, "from": from, "to": candidates.slice(0, from.size())}

static func surface_lift(context, crate_index: int) -> Dictionary:
	var crate: Dictionary = context.grid.crates[crate_index]
	var x: int = int(crate.x)
	var y: int = int(crate.y)
	if not context.grid.is_free(x, y - 1) or not context.world.material_ids.has("water"):
		return {}
	var ids: PackedInt32Array = context.material_ids_view()
	if ids.size() != 320 * 192:
		return {}
	var water: int = int(context.world.material_ids.water)
	var above: Array[int] = positions(ids, water, Vector2i(x, y - 1))
	if above.size() >= 128:
		return {"mode": "exchange", "destination": Vector2i(x, y - 1)}
	var seeds: Array[int] = []
	for px: int in range(x * SIZE, (x + 1) * SIZE):
		seeds.append((y + 1) * SIZE * WORLD_WIDTH + px)
	var body: Array[int] = component(ids, water, seeds, context.width, context.height)
	if body.size() < SIZE * SIZE:
		return {}
	body.sort_custom(func(a: int, b: int) -> bool: return int(a / WORLD_WIDTH) < int(b / WORLD_WIDTH) if int(a / WORLD_WIDTH) != int(b / WORLD_WIDTH) else a < b)
	if (y + 1) * SIZE - int(body[0] / WORLD_WIDTH) < 24:
		return {}
	return {"mode": "surface_lift", "destination": Vector2i(x, y - 1), "from": body.slice(0, SIZE * SIZE)}
