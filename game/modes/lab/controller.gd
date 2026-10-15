class_name LabController
extends RefCounted
## The first implementation exposes basics only; later groups await review.
var groups: Array = []
var group_index: int = 0
var level_index: int = 0
var route: Array = []

func configure(manifest: Dictionary) -> void:
	groups = manifest.get("groups", []).filter(func(group: Dictionary) -> bool: return group.get("mode") == "lab")

func current_group() -> Dictionary:
	return groups[group_index] if not groups.is_empty() else {}

func levels() -> Array:
	return current_group().get("levels", [])

func available(index: int) -> bool:
	return index >= 0 and index < groups.size() and groups[index].get("id") == "basics"

func level_uid(index: int = -1) -> String:
	var list: Array = levels()
	var selected: int = level_index if index < 0 else index
	return "level:" + str(list[selected].id) if selected >= 0 and selected < list.size() else ""

func route_index(state: Dictionary) -> int:
	var key: String = comparable(state)
	for index: int in range(route.size() - 1, -1, -1):
		if comparable(route[index]) == key:
			return index
	return -1

static func comparable(state: Dictionary) -> String:
	var crates: Array = state.get("crates", []).duplicate(true)
	crates.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return a.y * 100 + a.x < b.y * 100 + b.x)
	# JSON comparison intentionally excludes SDK tick/hash, moves and victory UI.
	return JSON.stringify(_normalize([state.get("player"), crates, state.get("terrain"), state.get("bag"), state.get("doors")]))

static func _normalize(value: Variant) -> Variant:
	if value is int or value is float:
		return float(value)
	if value is Array:
		return value.map(_normalize)
	if value is Dictionary:
		var result: Dictionary = {}
		for key: Variant in value:
			result[key] = _normalize(value[key])
		return result
	return value
