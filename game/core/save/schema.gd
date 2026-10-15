class_name SaveSchema
extends RefCounted

const VERSION: int = 1
const SECTIONS: Array[String] = ["progress", "wallet", "shop", "workshop", "badges", "license", "quests", "dialogue_seen", "affinity", "stamps", "hub", "settings"]

static func defaults() -> Dictionary:
	var result: Dictionary = {"version": VERSION}
	for section in SECTIONS:
		result[section] = {}
	return result

static func normalize(source: Dictionary) -> Dictionary:
	# Unknown sections intentionally survive future-system roundtrips.
	var result := source.duplicate(true)
	for section in SECTIONS:
		if not result.get(section) is Dictionary:
			result[section] = {}
	result["version"] = VERSION
	return result
