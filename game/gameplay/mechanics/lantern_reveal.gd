class_name LanternRevealMechanic
extends "res://gameplay/mechanics/mechanic.gd"
## The player's lamp makes crystal bridge cells solid within two tiles.

const LIGHT_RADIUS_SQUARED: int = 4
var _visible: Dictionary = {}

func setup(spec: Dictionary, context) -> void:
	super.setup(spec, context)
	_visible.clear()

func on_settle_step() -> bool:
	var context = session()
	var grid = context.grid
	var player: Vector2i = Vector2i(int(grid.player.x), int(grid.player.y))
	var changed: bool = false
	for index: int in range(grid.devices.size()):
		var device: Dictionary = grid.devices[index]
		if str(device.get("type", "")) != "lantern_reveal":
			continue
		var lit: Array = []
		for point: Array in device.get("cells", []):
			var tile: Vector2i = Vector2i(int(point[0]), int(point[1]))
			if not grid.inside(tile.x, tile.y):
				continue
			var key: String = "%d:%d:%d" % [index, tile.x, tile.y]
			var illuminated: bool = (tile - player).length_squared() <= LIGHT_RADIUS_SQUARED
			# Materialization cannot overwrite the player or a crate.
			var solid: bool = illuminated and not grid.is_player(tile.x, tile.y) and grid.crate_index(tile.x, tile.y) < 0
			if solid:
				lit.append([tile.x, tile.y])
			if not _visible.has(key) or bool(_visible[key]) != solid:
				var was_solid: bool = bool(_visible.get(key, false))
				var occupied: bool = grid.is_player(tile.x, tile.y) or grid.crate_index(tile.x, tile.y) >= 0
				# An unlit, never materialized cell can contain water or an entity.
				# Only erase SDK material that was owned by this bridge.
				if solid or (was_solid and not occupied):
					if not context.set_tile_material(tile.x, tile.y, str(device.get("material", "bridge")) if solid else "empty"):
						return changed
					changed = true
				_visible[key] = solid
		device.lit_cells = lit
		device.radius = 2
	return changed

func get_state() -> Dictionary:
	return {"visible": _visible.duplicate(true)}

func set_state(state: Dictionary) -> void:
	_visible = state.get("visible", {}).duplicate(true)

func observe() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for index: int in range(session().grid.devices.size()):
		var device: Dictionary = session().grid.devices[index]
		if str(device.get("type", "")) == "lantern_reveal":
			result.append({"type": "lantern_reveal", "device": index, "cells": device.get("cells", []), "lit_cells": device.get("lit_cells", []), "radius": 2})
	return result
