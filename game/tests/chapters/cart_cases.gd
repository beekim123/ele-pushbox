extends SceneTree
## Regression: tracks decoded from JSON contain numeric floats.
const SESSION = preload("res://gameplay/session/level_session.gd")
var failures: Array[String] = []
func _initialize() -> void: call_deferred("_run")
func _run() -> void:
	var source: Dictionary = {"id":"cart-json","group":"blast","profile":["cells"],"mechanisms":["mine_cart"],"map":["########","########","###B..o#","##P....#","########"],"devices":[{"type":"mine_cart","at":[3,3],"width":1,"track":[[3,3],[4,3],[5,3],[6,3]]}]}
	var spec: Dictionary = JSON.parse_string(JSON.stringify(source))
	var session = SESSION.new()
	session.render_enabled = false
	if not session.setup(spec):
		failures.append(session.last_error)
	else:
		var first_hash: String = session.world.get_state_hash()
		var had_last_roll: bool = session.grid.devices[0].has("last_roll")
		var result: Dictionary = session.perform("R")
		if not result.get("accepted",false): failures.append("JSON track rejected legal side push: " + str(result))
		if session.grid.devices[0].at != [6.0,3.0] and not (int(session.grid.devices[0].at[0]) == 6 and int(session.grid.devices[0].at[1]) == 3): failures.append("cart did not roll to end")
		if int(session.state().crates[0].x) != 6 or int(session.state().crates[0].y) != 2: failures.append("cargo not carried")
		if session.material_count(Rect2i(0,0,128,80),"crate") != 256: failures.append("SDK cargo occupancy not conserved")
		if not session.undo() or session.world.get_state_hash() != first_hash: failures.append("undo did not restore full SDK snapshot")
		if session.grid.devices[0].has("last_roll") != had_last_roll: failures.append("undo added an absent last_roll device field")
	session.dispose()
	var malformed: Dictionary = spec.duplicate(true)
	malformed.devices[0].track[1] = [4.5,3.0]
	var blocked = SESSION.new()
	blocked.render_enabled = false
	if not blocked.setup(malformed): failures.append(blocked.last_error)
	elif blocked.perform("R").get("accepted",false): failures.append("fractional track coordinate was silently rounded into a legal tile")
	blocked.dispose()
	print(JSON.stringify({"suite":"cart-json","ok":failures.is_empty(),"failures":failures}))
	quit(0 if failures.is_empty() else 1)
