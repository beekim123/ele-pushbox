class_name VineMechanic
extends "res://gameplay/mechanics/mechanic.gd"
## Root water permanently grows a ladder of the authored height.

const Grid = preload("res://gameplay/grid/grid_state.gd")
var _grown: Dictionary = {}

func setup(spec: Dictionary, context) -> void:
	super.setup(spec, context)
	_grown.clear()

func on_settle_step() -> bool:
	var context = session()
	var grid = context.grid
	var changed: bool = false
	for index: int in range(grid.devices.size()):
		var device: Dictionary = grid.devices[index]
		if str(device.get("type", "")) != "vine" or not device.has("root"):
			continue
		var root: Vector2i = Vector2i(int(device.root[0]), int(device.root[1]))
		if not grid.inside(root.x, root.y):
			continue
		var key: String = str(index)
		var water: int = context.material_count(context.cell_rect(root.x, root.y), "water")
		device.water_count = water
		if not bool(_grown.get(key, false)) and water < maxi(1, int(device.get("need", 1))):
			continue
		var cells: Array = []
		for offset: int in range(maxi(0, int(device.get("height", 1)))):
			var y: int = root.y - offset
			if not grid.inside(root.x, y):
				break
			if grid.terrain_at(root.x, y) not in [Grid.Terrain.EMPTY, Grid.Terrain.WATER]:
				break
			var tile: int = grid.tile_index(root.x, y)
			if int(grid.markers[tile]) != Grid.Marker.LADDER:
				grid.markers[tile] = Grid.Marker.LADDER
				changed = true
			cells.append([root.x, y])
		_grown[key] = true
		device.grown = true
		device.ladder_cells = cells
	return changed

func get_state() -> Dictionary:
	return {"grown": _grown.duplicate(true)}

func set_state(state: Dictionary) -> void:
	_grown = state.get("grown", {}).duplicate(true)

func observe() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for index: int in range(session().grid.devices.size()):
		var device: Dictionary = session().grid.devices[index]
		if str(device.get("type", "")) == "vine":
			result.append({"type": "vine", "device": index, "root": device.get("root", []), "height": device.get("height", 1), "grown": bool(_grown.get(str(index), false)), "water_count": device.get("water_count", 0), "need": device.get("need", 1), "cells": device.get("ladder_cells", [])})
	return result
