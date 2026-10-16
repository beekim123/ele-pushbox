extends SceneTree
## E04 regression: classified gravel has the powder weight defined by the model.
const SESSION = preload("res://gameplay/session/level_session.gd")
var failures: Array[String] = []
func _initialize() -> void: call_deferred("_run")
func _run() -> void:
	var spec: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://generated/content/levels/lab/experimental/E04.json"))
	var session = SESSION.new()
	session.render_enabled = false
	if not session.setup(spec): failures.append(session.last_error)
	else:
		for index: int in range(5):
			var result: Dictionary = session.perform(str(spec.solution[index]))
			if not bool(result.get("accepted",false)) or not str(result.get("error","")).is_empty(): failures.append("step%d: %s" % [index + 1,str(result.get("error",result.get("reason","")))])
		var state: Dictionary = session.state()
		if not bool(state.devices[0].get("broken",false)): failures.append("gravel was omitted from bridge load: " + str(state.devices[0]))
		if int(state.crates[0].x) != 6 or int(state.crates[0].y) != 7: failures.append("crate did not fall to the lower socket")
		if session.material_count(Rect2i(0,0,session.width*16,session.height*16),"gravel") != 256: failures.append("gravel mass changed")
	session.dispose()
	print(JSON.stringify({"suite":"bridge-gravel","ok":failures.is_empty(),"failures":failures}))
	quit(0 if failures.is_empty() else 1)
