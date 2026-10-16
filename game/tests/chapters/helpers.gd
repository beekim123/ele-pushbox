extends RefCounted
## Shared read-only SDK measurements for chapter acceptance assertions.
const SESSION = preload("res://gameplay/session/level_session.gd")

static func row(text: String, passed: bool, detail: Variant, available: bool = true) -> Dictionary:
	return {"text":text,"ok":available and passed,"status":("pass" if passed else "fail") if available else "not_run","detail":compact(detail)}

static func compact(value: Variant) -> Variant:
	if value is Dictionary:
		var result: Dictionary = {}
		for key: Variant in value:
			result[key] = {"sample_count":value[key].size(),"evidence":"level.physics"} if str(key) == "physics" and value[key] is Array else compact(value[key])
		return result
	if value is Array:
		return value.map(compact)
	return value

static func sample(trace: Array, index: int = -1) -> Dictionary:
	if trace.is_empty() or index >= trace.size() or index < -trace.size():
		return {}
	return trace[index].get("actual", {})

static func action(trace: Array, name: String, ordinal: int = 1) -> Dictionary:
	var count: int = 0
	for item: Dictionary in trace:
		if str(item.action) == name:
			count += 1
			if count == ordinal:
				return item.actual
	return {}

static func material(value: Dictionary, name: String) -> int:
	return int(value.get("materials", {}).get(name, 0))

static func tile(value: Dictionary, x: int, y: int, name: String) -> int:
	return int(value.get("tiles", {}).get("%d,%d" % [x,y], {}).get(name, 0))

static func point(value: Variant, x: int, y: int) -> bool:
	return value is Array and value.size() == 2 and typeof(value[0]) in [TYPE_INT,TYPE_FLOAT] and typeof(value[1]) in [TYPE_INT,TYPE_FLOAT] and float(value[0]) == float(x) and float(value[1]) == float(y)

static func box(value: Dictionary, x: int, y: int, layers: int = -1) -> bool:
	for crate: Dictionary in value.get("state", {}).get("crates", []):
		if int(crate.x) == x and int(crate.y) == y and (layers < 0 or int(crate.get("nested_layers", 1)) == layers):
			return true
	return false

static func player(value: Dictionary, x: int, y: int) -> bool:
	var p: Dictionary = value.get("state", {}).get("player", {})
	return p.get("x", -1) == x and p.get("y", -1) == y

static func device(value: Dictionary, kind: String) -> Dictionary:
	for d: Dictionary in value.get("state", {}).get("devices", []):
		if str(d.get("type", "")) == kind:
			return d
	return {}

static func common(summary: Dictionary) -> bool:
	return bool(summary.won) and bool(summary.consistent) and bool(summary.undo_ok) and bool(summary.restart_ok) and bool(summary.limits_ok)

static func capture(session) -> Dictionary:
	var counts: PackedInt32Array = session.world.count_materials(Rect2i(0,0,session.width*16,session.height*16))
	var materials: Dictionary = {}
	var tiles: Dictionary = {}
	for name: String in session.world.material_ids:
		var id: int = int(session.world.material_ids[name])
		if id >= 0 and id < counts.size(): materials[name] = int(counts[id])
	for y: int in range(session.height):
		for x: int in range(session.width):
			var local: PackedInt32Array = session.world.count_materials(session.cell_rect(x,y))
			var values: Dictionary = {}
			for name: String in session.world.material_ids:
				var id: int = int(session.world.material_ids[name])
				if id >= 0 and id < local.size() and local[id] > 0: values[name] = int(local[id])
			tiles["%d,%d" % [x,y]] = values
	return {"state":session.state(),"goals":session.goal_lights(),"observe":session.observe(),"materials":materials,"tiles":tiles,"hash":session.world.get_state_hash()}

static func branch(spec: Dictionary, actions: Array) -> Dictionary:
	var session = SESSION.new()
	session.render_enabled = false
	if not session.setup(spec):
		var error: String = session.last_error
		session.dispose()
		return {"setup_ok":false,"error":error}
	var opening: Dictionary = capture(session)
	var results: Array[Dictionary] = []
	var accepted: int = 0
	for name: String in actions:
		var result: Dictionary = session.perform(name)
		result.erase("hashes")
		results.append(result)
		if not bool(result.get("accepted",false)) or not str(result.get("error","")).is_empty(): break
		accepted += 1
	var final: Dictionary = capture(session)
	var won: bool = session.is_won()
	session.dispose()
	return {"setup_ok":true,"accepted_steps":accepted,"requested_steps":actions.size(),"won":won,"opening":opening,"final":final,"results":results}
