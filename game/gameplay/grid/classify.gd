class_name GridClassifier
extends RefCounted

const Grid = preload("res://gameplay/grid/grid_state.gd")
const CELL_SIZE: int = 16
const MAJORITY: int = 128

func update(world, grid) -> bool:
	var ids: PackedInt32Array = world.get_material_ids(0, 0, 320, 192)
	if ids.size() != 320 * 192:
		return false
	var bedrock_id: int = int(world.material_ids.bedrock)
	var earth_id: int = int(world.material_ids.packed_earth)
	var sand_id: int = int(world.material_ids.sand)
	# Native counts include one trailing border bucket. Crate and gate
	# counts are deliberately ignored: they remain gameplay overlays.
	var expected_counts: int = world.material_ids.size() + 1
	if bedrock_id < 0 or bedrock_id >= expected_counts - 1 or earth_id < 0 or earth_id >= expected_counts - 1 or sand_id < 0 or sand_id >= expected_counts - 1:
		return false
	for tile_y: int in range(grid.height):
		for tile_x: int in range(grid.width):
			var counts: PackedInt32Array = world.count_materials(Rect2i(tile_x * CELL_SIZE, tile_y * CELL_SIZE, CELL_SIZE, CELL_SIZE))
			if counts.size() != expected_counts:
				return false
			var classified: int = Grid.Terrain.EMPTY
			if counts[bedrock_id] >= MAJORITY:
				classified = Grid.Terrain.ROCK
			elif counts[earth_id] >= MAJORITY:
				classified = Grid.Terrain.EARTH
			elif counts[sand_id] >= MAJORITY:
				classified = Grid.Terrain.SAND
			grid.terrain[grid.tile_index(tile_x, tile_y)] = classified
	return true
