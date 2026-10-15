class_name FallMechanic
extends "res://gameplay/mechanics/mechanic.gd"

func on_settle_step() -> bool:
	var context = session()
	var grid = context.grid
	var order: Array[int] = []
	for index: int in range(grid.crates.size()):
		order.append(index)
	order.sort_custom(func(a: int, b: int) -> bool: return int(grid.crates[a].y) > int(grid.crates[b].y))
	var changed: bool = false
	for index: int in order:
		var crate: Dictionary = grid.crates[index]
		var below: int = grid.terrain_at(int(crate.x), int(crate.y) + 1)
		if str(crate.kind) == "wood" and below == grid.Terrain.WATER:
			continue
		if grid.is_free(int(crate.x), int(crate.y) + 1):
			if context.move_crate(index, Vector2i(int(crate.x), int(crate.y) + 1), "exchange"):
				changed = true
	var x: int = int(grid.player.x)
	var y: int = int(grid.player.y)
	if not grid.is_ladder(x, y) and not grid.supports(x, y + 1) and grid.is_free(x, y + 1):
		grid.player.y = y + 1
		changed = true
	return changed
