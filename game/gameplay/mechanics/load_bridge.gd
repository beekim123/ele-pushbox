class_name LoadBridgeMechanic
extends "res://gameplay/mechanics/mechanic.gd"
## A bridge carries continuous columns of riders and sand above all its planks.

const Grid = preload("res://gameplay/grid/grid_state.gd")

func setup(level_spec: Dictionary, context) -> void:
	super.setup(level_spec, context)
	for device: Dictionary in context.grid.devices:
		if str(device.get("type", "")) == "bridge":
			device.broken = bool(device.get("broken", false))
			device.load = int(device.get("load", 0))

func on_settle_step() -> bool:
	var context = session()
	var changed: bool = false
	for device: Dictionary in context.grid.devices:
		if str(device.get("type", "")) != "bridge" or bool(device.get("broken", false)):
			continue
		device.load = _bridge_load(device)
		if int(device.load) <= maxi(1, int(device.get("capacity", 1))):
			continue
		for cell: Array in device.get("cells", []):
			if not context.set_tile_material(int(cell[0]), int(cell[1]), "empty"):
				return changed
		device.broken = true
		changed = true
	return changed

func get_state() -> Dictionary:
	var states: Array[Dictionary] = []
	var grid = session().grid
	for index: int in range(grid.devices.size()):
		var device: Dictionary = grid.devices[index]
		if str(device.get("type", "")) == "bridge":
			states.append({"index": index, "broken": bool(device.get("broken", false)), "load": int(device.get("load", 0))})
	return {"devices": states}

func set_state(saved: Dictionary) -> void:
	var grid = session().grid
	for state: Dictionary in saved.get("devices", []):
		var index: int = int(state.get("index", -1))
		if index < 0 or index >= grid.devices.size() or str(grid.devices[index].get("type", "")) != "bridge":
			continue
		grid.devices[index].broken = bool(state.get("broken", false))
		grid.devices[index].load = int(state.get("load", 0))

func observe() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	var grid = session().grid
	for index: int in range(grid.devices.size()):
		var device: Dictionary = grid.devices[index]
		if str(device.get("type", "")) != "bridge":
			continue
		var load: int = int(device.get("load", 0))
		var capacity: int = maxi(1, int(device.get("capacity", 1)))
		var broken: bool = bool(device.get("broken", false))
		result.append({"kind": "bridge", "device": index, "cells": device.get("cells", []).duplicate(true), "load": load, "capacity": capacity, "cracked": not broken and load == capacity, "broken": broken})
	return result

func _bridge_load(device: Dictionary) -> int:
	var grid = session().grid
	var load: int = 0
	var counted: Dictionary = {}
	for cell: Array in device.get("cells", []):
		var x: int = int(cell[0])
		for y: int in range(int(cell[1]) - 1, -1, -1):
			var weight: int = 0
			var crate: int = grid.crate_index(x, y)
			if crate >= 0:
				weight = 2 if str(grid.crates[crate].kind) == "iron" else 1
			elif grid.is_player(x, y):
				weight = 1
			elif int(grid.terrain[grid.tile_index(x, y)]) == Grid.Terrain.SAND:
				weight = 1
			if weight == 0:
				break
			var tile: int = grid.tile_index(x, y)
			if not counted.has(tile):
				counted[tile] = true
				load += weight
	return load
