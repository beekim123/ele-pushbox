class_name LabController
extends RefCounted
## Chapter access follows saved clears; author routes grow from real SDK states.
const IMPLEMENTED_GROUPS: Array[String] = ["basics", "water", "blast", "react", "thermal", "experimental"]
var groups: Array = []
var group_index: int = 0
var level_index: int = 0
var route: Array = []
var _all_groups: Array = []
var open_all_levels: bool = false:
	set(value):
		open_all_levels = value
		_refresh_groups()
var _solution: Array = []
var _legacy_route: bool = false

func configure(manifest: Dictionary) -> void:
	_all_groups = manifest.get("groups", []).filter(func(group: Dictionary) -> bool: return group.get("mode") == "lab")
	_refresh_groups()

func _refresh_groups() -> void:
	var selected: String = str(current_group().get("id", ""))
	groups = _all_groups.filter(func(group: Dictionary) -> bool: return str(group.get("id", "")) != "experimental" or open_all_levels or OS.is_debug_build())
	group_index = clampi(group_index, 0, maxi(0, groups.size() - 1))
	for index: int in range(groups.size()):
		if str(groups[index].get("id", "")) == selected:
			group_index = index
			return
	level_index = 0

func current_group() -> Dictionary:
	return groups[group_index] if group_index >= 0 and group_index < groups.size() else {}

func levels() -> Array:
	return current_group().get("levels", [])

func stage_available(index: int) -> bool:
	return index >= 0 and index < groups.size() and str(groups[index].get("id", "")) in IMPLEMENTED_GROUPS

func available(index: int) -> bool:
	if index < 0 or index >= groups.size():
		return false
	if str(groups[index].get("id", "")) == "experimental":
		return open_all_levels or OS.is_debug_build()
	if open_all_levels or index == 0:
		return true
	var cleared: int = 0
	for level: Dictionary in groups[index - 1].get("levels", []):
		if bool(Save.level_data("level:" + str(level.id)).get("cleared", false)):
			cleared += 1
	return cleared >= unlock_need(index)

func unlock_need(index: int) -> int:
	return maxi(2, groups[index - 1].get("levels", []).size() - 2) if index > 0 and index < groups.size() else 0

func has_spec(index: int = -1) -> bool:
	var list: Array = levels()
	var selected: int = level_index if index < 0 else index
	return selected >= 0 and selected < list.size() and list[selected].get("spec") is String and not str(list[selected].spec).is_empty()

func level_uid(index: int = -1) -> String:
	var list: Array = levels()
	var selected: int = level_index if index < 0 else index
	return "level:" + str(list[selected].id) if selected >= 0 and selected < list.size() else ""

func route_index(state: Dictionary) -> int:
	var key: String = comparable(state, _legacy_route)
	for index: int in range(route.size() - 1, -1, -1):
		if comparable(route[index], _legacy_route) == key:
			return index
	return -1

func begin_route(opening: Dictionary, imported: Array, solution: Array) -> void:
	_solution = solution.duplicate()
	_legacy_route = str(current_group().get("id", "")) == "basics" and not imported.is_empty() and imported[0] is Dictionary and not imported[0].has("devices") and not imported[0].has("markers")
	route = imported.duplicate(true)
	if route.is_empty() or not route.all(func(state: Variant) -> bool: return state is Dictionary) or comparable(route[0], _legacy_route) != comparable(opening, _legacy_route):
		_legacy_route = false
		route = [opening.duplicate(true)]

func record_action(before: Dictionary, action: String, after: Dictionary) -> void:
	var index: int = route_index(before)
	if index < 0 or index >= _solution.size() or action != str(_solution[index]):
		return
	# A new route state needs a real accepted author action from its known prefix.
	if index + 1 == route.size():
		route.append(after.duplicate(true))

static func comparable(state: Dictionary, legacy_basics: bool = false) -> String:
	var crates: Array = []
	for crate: Dictionary in state.get("crates", []):
		# Stable ids and presentation bindings do not describe the puzzle position.
		crates.append({"x": int(crate.x), "y": int(crate.y), "kind": str(crate.kind), "nested_layers": int(crate.get("nested_layers", 1))})
	crates.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return a.y * 100 + a.x < b.y * 100 + b.x)
	# JSON comparison intentionally excludes SDK tick/hash, moves and victory UI.
	var parts: Array = [state.get("player"), crates, state.get("terrain"), state.get("bag"), state.get("doors")]
	if not legacy_basics:
		parts.append(state.get("devices", []))
		parts.append(state.get("markers", []))
	return JSON.stringify(_normalize(parts))

static func _normalize(value: Variant) -> Variant:
	if value is int or value is float:
		return float(value)
	if value is Array:
		return value.map(_normalize)
	if value is Dictionary:
		var result: Dictionary = {}
		var keys: Array = value.keys()
		keys.sort_custom(func(a: Variant, b: Variant) -> bool: return str(a) < str(b))
		for key: Variant in keys:
			result[key] = _normalize(value[key])
		return result
	return value
