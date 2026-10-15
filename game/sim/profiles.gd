class_name SimulationProfiles
extends RefCounted

const Materials = preload("res://sim/materials.gd")

static func basics() -> Dictionary:
	return {"format": "ele.profile/1", "name": "portitor_basics", "gravity": "down", "solvers": [{"name": "cells"}]}

static func for_level(spec: Dictionary = {}) -> Dictionary:
	if not Materials.uses_extended_materials(spec):
		return basics()
	var selected: Dictionary = {} if spec.has("profile") else {"cells": {"name": "cells"}}
	for solver: Variant in spec.get("profile", []):
		var entry: Dictionary = solver.duplicate(true) if solver is Dictionary else {"name": str(solver)}
		var name: String = str(entry.get("name", ""))
		if not name.is_empty():
			selected[name] = entry
	# An authored profile is the exact solver contract. Group inference only
	# supplies defaults for the existing water/react specs that omit it.
	if not spec.has("profile"):
		var group: String = str(spec.get("group", ""))
		var map_text: String = "\n".join(spec.get("map", []))
		var mechanisms: Array = spec.get("mechanisms", [])
		if group in ["water", "thermal"] or map_text.contains("~") or map_text.contains("i") or not spec.get("water", []).is_empty() or _has_any(mechanisms, ["water_flow", "float_sink", "displace", "communicating", "freeze", "melt", "vine"]):
			_add(selected, "liquid_pressure")
		if group in ["blast", "thermal"] or map_text.contains("f") or _has_any(mechanisms, ["bomb", "blast_through", "fuse", "blast_ignite"]):
			_add(selected, "explosions")
		if group == "thermal" or map_text.contains("w") or _has_any(mechanisms, ["burn", "freeze", "melt", "blast_ignite"]):
			_add(selected, "thermal")
		if group == "thermal" or _has_any(mechanisms, ["freeze", "melt"]):
			_add(selected, "couplers")
		for device: Dictionary in spec.get("devices", []):
			match str(device.get("type", "")):
				"torch":
					_add(selected, "thermal")
				"frost_vent", "heat_vent":
					_add(selected, "couplers")
					_add(selected, "liquid_pressure")
	var profile: Dictionary = {"format": "ele.profile/1", "name": "portitor_chapters", "gravity": "down", "solvers": []}
	# Dictionary insertion order is the authored profile order.
	if spec.has("profile"):
		for name: String in selected:
			profile.solvers.append(selected[name])
	else:
		for name: String in ["cells", "thermal", "explosions", "liquid_pressure", "couplers"]:
			if selected.has(name):
				profile.solvers.append(selected[name])
		for name: String in selected:
			if not _has_solver(profile, name):
				profile.solvers.append(selected[name])
	var layers: Array[Dictionary] = []
	if _has_solver(profile, "thermal"):
		layers.append({"name": "temperature", "type": "u16", "default": 2344, "scale": 1, "moves_with_cell": true})
		profile.ambient = {"temperature": 2344, "air_conductivity": 4, "relax_shift": 6}
	if _has_solver(profile, "explosions"):
		profile.explosions = {"max_per_tick": 64, "heat": 3200, "max_debris": 0}
	if _has_solver(profile, "couplers"):
		layers.append({"name": "frost", "type": "u8", "default": 0, "scale": 1})
		layers.append({"name": "heat", "type": "u8", "default": 0, "scale": 1})
		profile.couplers = [
			{"type": "layer_to_material", "layer": "frost", "min": 1, "from": "water", "to": "ice", "chance": 256},
			{"type": "layer_to_material", "layer": "heat", "min": 1, "from": "ice", "to": "water", "chance": 256}
		]
		for solver: Dictionary in profile.solvers:
			if str(solver.name) == "couplers":
				solver.params = {"stride": 1}
				solver.rate_divider = 1
	if not layers.is_empty():
		profile.layers = layers
	return profile

static func _add(selected: Dictionary, name: String) -> void:
	if not selected.has(name):
		selected[name] = {"name": name}

static func _has_any(items: Array, names: Array) -> bool:
	for name: String in names:
		if items.has(name):
			return true
	return false

static func _has_solver(profile: Dictionary, name: String) -> bool:
	for solver: Dictionary in profile.solvers:
		if str(solver.name) == name:
			return true
	return false
