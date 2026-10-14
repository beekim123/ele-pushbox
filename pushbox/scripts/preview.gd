extends RefCounted
## A non-rendered second world, using exactly Session's real settlement code.

const Session := preload("res://pushbox/scripts/session.gd")
var session: RefCounted
var last_us: int = 0

func configure(source: RefCounted, parent: Node) -> String:
	session = Session.new()
	var reason: String = session.load_level(source.level_path, parent, false)
	if reason.is_empty():
		# Initialize the hidden world and warm shared classification/key routines
		# during level creation, before interactive frame budgets start.
		session.settle_sync()
	return reason

var pending: bool = false
var calculations: int = 0
var _source: RefCounted
var _saved: Dictionary = {}
var _stamp: String = ""
var _cache: Dictionary = {}
var _action: String = ""
var _pixels: bool = false
var _result: Dictionary = {}
var _begin_us: int = 0
var work_us: int = 0
var phase_us: Dictionary = {}
var frame_slices_us: Array[int] = []

func invalidate() -> void:
	pending = false
	_cache.clear()
	_stamp = ""
	if not _saved.is_empty() and _source != null:
		_source._remove_snapshot(_saved)
	_saved = {}

func begin(source: RefCounted, action: String, pixels: bool = true) -> Dictionary:
	var stamp: String = "%d:%d:%d:%d" % [source.get_instance_id(), source.world.get_tick(), source.board.read_revision, source.board.moves]
	if stamp != _stamp:
		invalidate()
		_stamp = stamp
		_source = source
	var key: String = action + (":pixels" if pixels else "")
	if _cache.has(key):
		return _cache[key]
	var reason: String = source.board.action_reason(action)
	if not reason.is_empty():
		return {"legal": false, "reason": reason}
	_begin_us = Time.get_ticks_usec()
	work_us = 0
	phase_us.clear()
	frame_slices_us.clear()
	if _saved.is_empty():
		_saved = source.snapshot("preview")
	if _saved.is_empty() or not session.restore(_saved):
		return {"legal": false, "reason": "预演快照载入失败。"}
	_action = action
	_pixels = pixels
	_result = session.perform(action)
	calculations += 1
	pending = session.running
	work_us += Time.get_ticks_usec() - _begin_us
	phase_us["begin"] = work_us
	if not pending:
		return _finish()
	return {}

func advance(tick_budget: int = 4) -> Dictionary:
	if not pending:
		return {}
	var started: int = Time.get_ticks_usec()
	session.advance_frame(tick_budget)
	var elapsed: int = Time.get_ticks_usec() - started
	work_us += elapsed
	phase_us[session.last_work_phase] = int(phase_us.get(session.last_work_phase, 0)) + elapsed
	if session.running:
		return {}
	return _finish()

func advance_budget(microseconds: int = 3500) -> Dictionary:
	var started: int = Time.get_ticks_usec()
	var result: Dictionary = {}
	while pending and Time.get_ticks_usec() - started < microseconds:
		result = advance(1)
	frame_slices_us.append(Time.get_ticks_usec() - started)
	return result

func _finish() -> Dictionary:
	var started: int = Time.get_ticks_usec()
	var categories: PackedStringArray = session.board.categories()
	var changed: Array[Vector2i] = []
	var previous: PackedStringArray = _source.board.categories()
	for i in categories.size():
		if categories[i] != previous[i]:
			changed.append(Vector2i(i % 20, i / 20))
	var removed: Array[Vector2i] = []
	if _pixels:
		removed = _removed_cells(_source.board, _action)
	_result.merge({"action": _action, "tick": session.world.get_tick(), "hash": session.world.get_state_hash(), "actors": session.board.actors_key(), "game_state": session.board.state(), "player": session.board.player, "boxes": session.board.boxes.duplicate(true), "categories": categories, "changed": changed, "removed": removed, "errors": session.errors.duplicate()})
	phase_us["finish"] = Time.get_ticks_usec() - started
	work_us += int(phase_us.finish)
	last_us = work_us
	_result["time_us"] = last_us
	_cache[_action + (":pixels" if _pixels else "")] = _result
	pending = false
	return _result

func predict(source: RefCounted, action: String, pixels: bool = false) -> Dictionary:
	var result: Dictionary = begin(source, action, pixels)
	while pending:
		result = advance(4)
	return result

func _removed_cells(board: RefCounted, action: String) -> Array[Vector2i]:
	var result: Array[Vector2i] = []
	var target: Vector2i = board.player + board._direction(action)
	if action.begins_with("DIG_"):
		for y in range(target.y * 16, (target.y + 1) * 16):
			for x in range(target.x * 16, (target.x + 1) * 16):
				if board.ids[y * 320 + x] in board.tag_material_ids.get(board.rules.dig.tag, []):
					result.append(Vector2i(x, y))
	elif action.begins_with("BOMB_"):
		var center: Vector2i = target * 16 + Vector2i(8, 8)
		var radius: int = int(board.rules.bomb.radius_cells)
		var radius_squared: int = radius * radius
		var cells: Dictionary = {}
		for y in range(maxi(0, center.y - radius), mini(192, center.y + radius + 1)):
			for x in range(maxi(0, center.x - radius), mini(320, center.x + radius + 1)):
				var distance: int = (x - center.x) * (x - center.x) + (y - center.y) * (y - center.y)
				if distance > radius_squared:
					continue
				var material: int = board.ids[y * 320 + x]
				if material == 0:
					continue
				var definition: Dictionary = board.material_definitions[board.names[material]]
				var resistance: int = int(definition.get("blast_resistance", {"empty": 0, "static": 2000, "powder": 200, "liquid": 50, "gas": 0}.get(definition["class"], 0)))
				var power: int = int(board.rules.bomb.power) * (radius_squared - distance) / radius_squared
				if power > resistance:
					cells[Vector2i(x, y)] = true
		# Crumble is additional destruction of static remnants; preserve source
		# coordinates and avoid mistaking redistributed sand/water for destruction.
		for material in board.tag_material_ids.get(board.rules.bomb.crumble_tag, []):
			var index: int = board.ids.find(material)
			while index >= 0:
				if session.board.ids[index] == 0:
					cells[Vector2i(index % 320, index / 320)] = true
				index = board.ids.find(material, index + 1)
		result.assign(cells.keys())
		result.sort_custom(func(a: Vector2i, b: Vector2i) -> bool: return a.y < b.y or (a.y == b.y and a.x < b.x))
	return result

func dispose() -> void:
	invalidate()
	if session != null:
		session.dispose()
