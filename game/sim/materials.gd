class_name SimulationMaterials
extends RefCounted
## SDK content for the basics profile. Physics values follow GD-4.1.

static func definitions() -> Dictionary:
	return {
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
