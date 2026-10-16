extends SceneTree
var failures: Array[String] = []

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var controller: RefCounted = load("res://modes/lab/controller.gd").new()
	controller.configure(JSON.parse_string(FileAccess.get_file_as_string("res://generated/content-manifest.json")))
	var session: RefCounted = load("res://gameplay/session/level_session.gd").new()
	session.render_enabled = false
	session.setup(root.get_node("Registry").level_spec("level:M01"))
	controller.begin_route(session.state(), root.get_node("Registry").author_route("level:M01"), root.get_node("Registry").level_spec("level:M01").solution)
	if controller.route_index(session.state()) != 0: failures.append("initial integer SDK state matches JSON author route step zero")
	session.perform("R")
	if controller.route_index(session.state()) != 1: failures.append("moved integer SDK state matches JSON author route step one")
	var changed: Dictionary = session.state()
	changed.player.x += 1
	if controller.comparable(changed) == controller.comparable(session.state()): failures.append("different coordinates remain distinguishable")
	session.dispose()
	print(JSON.stringify({"suite":"lab","ok":failures.is_empty(),"failures":failures}))
	quit(0 if failures.is_empty() else 1)
