class_name SimulationMaterials
extends RefCounted
## SDK content for GD-4.1. Added chapter values are source-reviewed candidates.

static func definitions(spec: Dictionary = {}) -> Dictionary:
	var content: Dictionary = {
		"format": "ele.materials/1",
		"materials": [
			{"name": "empty", "class": "empty"},
			{"name": "bedrock", "class": "static", "density": 255, "blast_resistance": 65535, "debris_chance": 0, "colors": ["#3a4466ff"], "tags": ["solid"]},
			{"name": "packed_earth", "class": "static", "density": 200, "blast_resistance": 300, "debris_chance": 0, "colors": ["#b86f50ff"], "tags": ["solid", "diggable"]},
			{"name": "sand", "class": "powder", "density": 60, "fall": 2, "debris_chance": 0, "colors": ["#e4a672ff", "#ead4aaff", "#fee761ff"], "tags": ["sand", "diggable"]},
			{"name": "crate", "class": "static", "density": 255, "blast_resistance": 65535, "debris_chance": 0, "colors": ["#b86f50ff"], "tags": ["box"]},
			{"name": "iron_crate", "class": "static", "density": 255, "blast_resistance": 65535, "debris_chance": 0, "colors": ["#8b9bb4ff"], "tags": ["box"]},
			{"name": "gate", "class": "static", "density": 255, "blast_resistance": 65535, "debris_chance": 0, "colors": ["#5a6988ff"], "tags": ["solid", "gate"]}
		]
	}
	# Keep the first chapter's material table and movement specialization intact.
	if not uses_extended_materials(spec):
		return content
	content.materials.append_array([
		{"name": "water", "class": "liquid", "density": 30, "fall": 2, "disp": 5, "debris_chance": 0, "colors": ["#0099dbff"], "extinguishes": true, "tags": ["water"]},
		{"name": "cracked_rock", "class": "static", "density": 200, "blast_resistance": 300, "debris_chance": 0, "colors": ["#c28569ff"], "tags": ["solid", "cracked"]},
		{"name": "gravel", "class": "powder", "density": 70, "blast_resistance": 65535, "fall": 0, "move_chance": 128, "debris_chance": 0, "colors": ["#8b9bb4ff"], "tags": ["solid", "gravel"]},
		{"name": "fuse", "class": "static", "density": 100, "blast_resistance": 65535, "debris_chance": 0, "colors": ["#d77643ff"], "burnable": _burnable(32), "explosive": {"radius": 20, "power": 8000}, "tags": ["solid"]},
		{"name": "acid", "class": "liquid", "density": 35, "fall": 2, "disp": 5, "debris_chance": 0, "colors": ["#63c74dff"], "tags": ["acid"]},
		{"name": "limestone_a", "class": "static", "density": 200, "blast_resistance": 2000, "debris_chance": 0, "colors": ["#ead4aaff"], "tags": ["solid", "etchable"]},
		{"name": "limestone_b", "class": "static", "density": 200, "blast_resistance": 2000, "debris_chance": 0, "colors": ["#c28569ff"], "tags": ["solid", "etchable"]},
		{"name": "hard_rock", "class": "static", "density": 255, "blast_resistance": 65535, "debris_chance": 0, "colors": ["#5a6988ff"], "tags": ["solid"]},
		{"name": "smoke", "class": "gas", "density": 1, "fall": 1, "disp": 3, "debris_chance": 0, "colors": ["#c0cbdcff"], "tags": ["smoke"]},
		{"name": "fog", "class": "gas", "density": 10, "fall": 1, "disp": 3, "sinks": true, "debris_chance": 0, "colors": ["#8b9bb4ff"], "tags": ["fog"]},
		{"name": "plug", "class": "static", "density": 200, "blast_resistance": 2000, "debris_chance": 0, "colors": ["#3e8948ff"], "tags": ["solid"]},
		{"name": "plug_decay", "class": "static", "density": 200, "blast_resistance": 2000, "debris_chance": 0, "colors": ["#3e8948ff"], "lifetime": {"min": 120, "max": 120, "to": "empty"}, "tags": ["solid"]},
		{"name": "wood", "class": "static", "density": 100, "blast_resistance": 65535, "debris_chance": 0, "colors": ["#b86f50ff"], "burnable": _burnable(120), "tags": ["solid"]},
		# Device ice has no phase_up: only an explicit heat pulse melts it.
		{"name": "ice", "class": "static", "density": 80, "blast_resistance": 2000, "debris_chance": 0, "colors": ["#2ce8f5ff"], "tags": ["solid", "ice"]},
		{"name": "bridge", "class": "static", "density": 255, "blast_resistance": 65535, "debris_chance": 0, "colors": ["#b86f50ff"], "tags": ["solid", "platform"]}
	])
	return content

static func reactions(spec: Dictionary = {}) -> Dictionary:
	if not uses_extended_materials(spec):
		return {}
	return {"format": "ele.reactions/1", "reactions": [{"a": "acid", "b": "#etchable", "to_a": "empty", "to_b": "empty", "chance": 256}]}

static func uses_extended_materials(spec: Dictionary) -> bool:
	var group: String = str(spec.get("group", "basics"))
	if group != "basics" and not group.is_empty():
		return true
	for solver: Variant in spec.get("profile", []):
		var name: String = str(solver.get("name", "")) if solver is Dictionary else str(solver)
		if name != "cells":
			return true
	for mechanism: Variant in spec.get("mechanisms", []):
		if str(mechanism) in ["water_flow", "float_sink", "displace", "communicating", "lever", "lift", "bin", "load_bridge", "portal", "bomb", "blast_through", "fuse", "gravel", "acid", "etch_tag", "gas_rise", "gas_sink", "lifetime", "vine", "burn", "freeze", "melt", "blast_ignite", "mine_cart", "lantern_reveal", "nested_box", "bounce", "seesaw", "ice_slide", "gust"]:
			return true
	if not spec.get("water", []).is_empty() or not spec.get("devices", []).is_empty():
		return true
	for row: Variant in spec.get("map", []):
		for symbol: String in ["~", "%", "g", "f", "a", "L", "M", "R", "^", "v", "w", "i", "p", "="]:
			if str(row).contains(symbol):
				return true
	return false

static func _burnable(duration: int) -> Dictionary:
	# Empty fire/product keep the chapter's burn result free of undeclared ash.
	return {"ignite_temp": 4584, "burn_time": duration, "burn_temp": 7200, "spread": 256, "fire": "empty", "fire_chance": 0, "product": "empty"}
