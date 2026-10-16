extends SceneTree
## E06 regression: wind reacts after the lever's door has completed settlement.
const SESSION = preload("res://gameplay/session/level_session.gd")
var failures: Array[String] = []
func _initialize() -> void: call_deferred("_run")
func _run() -> void:
	var spec: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://generated/content/levels/lab/experimental/E06.json"))
	var session = SESSION.new()
	session.render_enabled = false
	if not session.setup(spec): failures.append(session.last_error)
	else:
		for index: int in range(9):
			var result: Dictionary = session.perform(str(spec.solution[index]))
			if not bool(result.get("accepted",false)): failures.append("action rejected: " + str(index + 1))
		var state: Dictionary = session.state()
		if int(state.player.x) != 7 or int(state.player.y) != 4: failures.append("step9 did not launch prepared player in the same action: " + str(state.player))
		if int(state.crates[0].x) != 3 or int(state.crates[0].y) != 6: failures.append("step9 wind did not drop cargo onto seesaw")
	session.dispose()
	print(JSON.stringify({"suite":"gust-order","ok":failures.is_empty(),"failures":failures}))
	quit(0 if failures.is_empty() else 1)
