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
			if index == 3:
				var before_blast: Dictionary = session.state().devices[0]
				if bool(before_blast.get("broken",true)) or int(before_blast.get("load",0)) != 1: failures.append("crate alone did not retain the capacity1 bridge")
			if index == 4 and int(result.get("ticks",1200)) >= 1200: failures.append("blast reached the 1200 tick budget")
		var state: Dictionary = session.state()
		if not bool(state.devices[0].get("broken",false)): failures.append("gravel was omitted from bridge load: " + str(state.devices[0]))
		if int(state.devices[0].get("load",0)) != 2: failures.append("crate plus classified gravel did not record load2")
		if int(state.crates[0].x) != 6 or int(state.crates[0].y) != 7: failures.append("crate did not fall to the lower socket")
		if session.material_count(session.cell_rect(6,6),"bridge") != 0: failures.append("broken bridge cells remain")
		if session.material_count(session.cell_rect(6,6),"gravel") < 128: failures.append("gravel did not classify above the lower crate")
		if session.material_count(session.cell_rect(5,4),"bedrock") != 256: failures.append("blast destroyed the sealed bedrock wall")
		if session.material_count(Rect2i(0,0,session.width*16,session.height*16),"gravel") != 256: failures.append("gravel mass changed")
	session.dispose()
	print(JSON.stringify({"suite":"bridge-gravel","ok":failures.is_empty(),"failures":failures}))
	quit(0 if failures.is_empty() else 1)
