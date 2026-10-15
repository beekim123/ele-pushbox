class_name GridClassifier
extends RefCounted

const Grid = preload("res://gameplay/grid/grid_state.gd")
const CELL_SIZE: int = 16
const MAJORITY: int = 128

func update(world, grid) -> bool:
	var ids: PackedInt32Array = world.get_material_ids(0, 0, 320, 192)
	if ids.size() != 320 * 192:
		return false
	var classes: Dictionary = {}
	for terrain: int in Grid.TILE_MATERIALS:
		var material: String = Grid.TILE_MATERIALS[terrain]
		if world.material_ids.has(material):
			classes[int(world.material_ids[material])] = terrain
	# Lifetime/phase variants retain their gameplay class until they disappear.
	for pair: Array in [["plug_decay", Grid.Terrain.PLUG]]:
		if world.material_ids.has(pair[0]):
			classes[int(world.material_ids[pair[0]])] = int(pair[1])
	for tile_y: int in range(grid.height):
		for tile_x: int in range(grid.width):
			var counts: Dictionary = {}
			for y: int in range(tile_y * CELL_SIZE, (tile_y + 1) * CELL_SIZE):
				for x: int in range(tile_x * CELL_SIZE, (tile_x + 1) * CELL_SIZE):
					var material: int = ids[y * 320 + x]
					if classes.has(material):
						var category: int = classes[material]
						counts[category] = int(counts.get(category, 0)) + 1
			var classified: int = Grid.Terrain.EMPTY
			for category: int in counts:
				if int(counts[category]) >= MAJORITY:
					classified = category
					break
			grid.terrain[grid.tile_index(tile_x, tile_y)] = classified
	return true
