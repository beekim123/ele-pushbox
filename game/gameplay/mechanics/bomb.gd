class_name BombMechanic
extends "res://gameplay/mechanics/mechanic.gd"
## Placement commits one real SDK explosion; partial cracked tiles collapse.

const Grid = preload("res://gameplay/grid/grid_state.gd")

func actions() -> Array[String]:
	return ["BOMB_L", "BOMB_R", "BOMB_D"]

func try_action(action: String) -> Dictionary:
	if action not in actions():
		return {"handled": false}
	var context = session()
	var grid = context.grid
	var direction: Vector2i = {"BOMB_L": Vector2i.LEFT, "BOMB_R": Vector2i.RIGHT, "BOMB_D": Vector2i.DOWN}[action]
	var tile: Vector2i = Vector2i(int(grid.player.x), int(grid.player.y)) + direction
	if int(grid.bag.bomb) <= 0 or not grid.inside(tile.x, tile.y):
		return {"handled": true, "accepted": false, "reason": "no-bomb"}
	return {"handled": true, "accepted": true, "kind": "bomb", "bomb": tile}

func on_physics_tick() -> bool:
	var context = session()
	var changed: bool = false
	if not context.world.material_ids.has("cracked_rock"):
		return false
	for y: int in range(context.height):
		for x: int in range(context.width):
			# The immutable opening marks only potential cracked rock footprints;
			# a partial footprint is removed after the real SDK blast has cut it.
			if str(context.spec.map[y]).substr(x, 1) != "%":
				continue
			var count: int = context.sdk_material_count(context.cell_rect(x, y), "cracked_rock")
			if count > 0 and count < 128:
				if not context.set_tile_material(x, y, "empty"):
					return changed
				changed = true
	return changed

func observe() -> Array[Dictionary]:
	return [{"kind": "bomb", "radius": 20, "power": 8000, "count": int(session().grid.bag.bomb)}]
