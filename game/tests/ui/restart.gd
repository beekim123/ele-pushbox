extends SceneTree
## A second Godot process reads the real save left by the interaction replay.
var failures: Array[String] = []

func _initialize() -> void:
	create_timer(20.0).timeout.connect(func() -> void: quit(1))
	call_deferred("_run")

func _run() -> void:
	var save: Node = root.get_node("Save")
	var settings: Node = root.get_node("Settings")
	for index: int in 7:
		if not bool(save.level_data("level:M%02d" % (index + 1)).cleared): failures.append("missing completed M%02d after process restart" % (index + 1))
	if not is_equal_approx(float(settings.values.music), 1.0) or not is_equal_approx(float(settings.values.sfx), 0.4): failures.append("audio values did not survive process restart")
	if str(settings.values.window_scale) != "auto": failures.append("auto scale did not survive process restart")
	var app: Node = load("res://app/boot.tscn").instantiate()
	root.add_child(app)
	await process_frame
	var event := InputEventKey.new()
	event.physical_keycode = KEY_ENTER
	event.keycode = KEY_ENTER
	event.pressed = true
	Input.parse_input_event(event)
	await process_frame
	event = event.duplicate()
	event.pressed = false
	Input.parse_input_event(event)
	await process_frame
	if app.session == null or str(app.session.spec.id) != "M07": failures.append("Continue did not restore the last played level after process restart")
	app.dispose()
	app.queue_free()
	await process_frame
	var result: Dictionary = {"suite":"ui-restart", "ok":failures.is_empty(), "failures":failures, "scope":"Second OS process; real prior GUI play save, no seeded completion records"}
	var file := FileAccess.open("res://tests/results/ui-restart.json", FileAccess.WRITE)
	file.store_string(JSON.stringify(result, "\t") + "\n")
	file.close()
	print(JSON.stringify(result))
	quit(0 if failures.is_empty() else 1)
