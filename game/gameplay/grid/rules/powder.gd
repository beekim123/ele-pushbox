class_name CratePowderRules
extends RefCounted
## Keep thin sand/gravel cells at their local offsets in the tile above a crate.
const SIZE: int = 16
const WORLD_WIDTH: int = 320
const SOLID_THRESHOLD: int = 128

static func displacement(context, crate_index: int, destination: Vector2i, vacated: Array[Vector2i] = [], occupied: Array[Vector2i] = []) -> Dictionary:
	var ids: PackedInt32Array = context.material_ids_view()
	if ids.size() != 320 * 192 or not context.grid.inside(destination.x, destination.y):
		return {"ok":false}
	var cells: Array[Dictionary] = []
	for material: String in ["sand", "gravel"]:
		var id: int = int(context.world.material_ids.get(material, -1))
		for y: int in range(destination.y * SIZE, (destination.y + 1) * SIZE):
			for x: int in range(destination.x * SIZE, (destination.x + 1) * SIZE):
				var pixel: int = y * WORLD_WIDTH + x
				if ids[pixel] == id:
					cells.append({"from":pixel, "to":pixel - SIZE * WORLD_WIDTH, "material":material})
	if cells.is_empty():
		return {"ok":true, "cells":cells, "reserved":[]}
	if cells.size() >= SOLID_THRESHOLD:
		return {"ok":false}
	var above: Vector2i = destination + Vector2i.UP
	var crate: Dictionary = context.grid.crates[crate_index]
	var vacated_source: bool = above == Vector2i(int(crate.x), int(crate.y)) or above in vacated
	if not context.grid.inside(above.x, above.y) or above in occupied or (context.grid.is_player(above.x, above.y) and not vacated_source):
		return {"ok":false}
	# A falling crate clears its old footprint before placing powder there.
	if not vacated_source:
		if not context.grid.is_free(above.x, above.y):
			return {"ok":false}
		for y: int in range(above.y * SIZE, (above.y + 1) * SIZE):
			for x: int in range(above.x * SIZE, (above.x + 1) * SIZE):
				if ids[y * WORLD_WIDTH + x] != int(context.world.material_ids.empty):
					return {"ok":false}
	var reserved: Array[int] = []
	for cell: Dictionary in cells:
		reserved.append(int(cell.to))
	return {"ok":true, "cells":cells, "reserved":reserved}
