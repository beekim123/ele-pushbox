extends SceneTree
## Isolated bridge-weight contract, separate from the current E04 replay.
const SESSION = preload("res://gameplay/session/level_session.gd")
var failures: Array[String] = []
func _initialize() -> void: call_deferred("_run")
func _run() -> void:
	var spec: Dictionary = {"id":"bridge-powder-contract","group":"experimental","profile":["cells"],"mechanisms":["gravel","load_bridge"],"map":["########","####g###","####g###","####B###","####=###","####.###","#P##o###","########"],"devices":[{"type":"bridge","cells":[[4,4]],"capacity":2}],"goals":[{"type":"socket","at":[4,6]}]}
	var session = SESSION.new()
	session.render_enabled = false
	if not session.setup(spec): failures.append(session.last_error)
	else:
		if not bool(session.grid.devices[0].get("broken",false)): failures.append("two classified gravel tiles plus a wood crate did not overload capacity2")
		if int(session.state().crates[0].y) != 6: failures.append("crate did not fall into socket")
		if session.material_count(Rect2i(0,0,128,128),"gravel") != 512: failures.append("powder was deleted")
	session.dispose()
	var exact_spec: Dictionary = spec.duplicate(true)
	exact_spec.map[1] = "########"
	var exact = SESSION.new()
	exact.render_enabled = false
	if not exact.setup(exact_spec): failures.append(exact.last_error)
	else:
		if bool(exact.grid.devices[0].get("broken",false)) or int(exact.grid.devices[0].get("load",0)) != 2: failures.append("capacity2 failed to retain exactly two units of load")
		var cracked: bool = false
		for observed: Dictionary in exact.observe():
			if str(observed.get("kind","")) == "bridge": cracked = bool(observed.get("cracked",false))
		if not cracked: failures.append("exact capacity did not expose cracked state")
	exact.dispose()
	print(JSON.stringify({"suite":"bridge-gravel-contract","ok":failures.is_empty(),"failures":failures}))
	quit(0 if failures.is_empty() else 1)
