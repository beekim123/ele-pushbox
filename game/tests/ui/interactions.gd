extends SceneTree
## Player-facing GUI dispatch with isolated progress and a real SDK world.
var checks: Array[Dictionary] = []
var app: Node
var suite: String = "ui-interactions"

func _initialize() -> void:
	create_timer(300.0 if OS.get_cmdline_user_args().has("--manual") else 90.0).timeout.connect(func() -> void: printerr("FAIL: interactions timeout"); quit(1))
	call_deferred("_run")

func check(id: String, ok: bool, actual: Variant = null) -> void:
	checks.append({"id": id, "ok": ok, "actual": actual})
	if not ok: printerr("FAIL: " + id + " " + str(actual))

func key(code: int, shift: bool = false, ctrl: bool = false, echo: bool = false) -> void:
	var event := InputEventKey.new()
	event.physical_keycode = code
	event.keycode = code
	event.pressed = true
	event.echo = echo
	event.shift_pressed = shift
	event.ctrl_pressed = ctrl
	Input.parse_input_event(event)
	await process_frame
	event = event.duplicate()
	event.pressed = false
	event.echo = false
	Input.parse_input_event(event)
	await process_frame

func mouse(point: Vector2, pressed: bool) -> void:
	var event := InputEventMouseButton.new()
	event.position = point
	event.global_position = point
	event.button_index = MOUSE_BUTTON_LEFT
	event.button_mask = MOUSE_BUTTON_MASK_LEFT if pressed else 0
	event.pressed = pressed
	root.push_input(event, true)
	await process_frame

func click(point: Vector2) -> void:
	await mouse(point, true)
	await mouse(point, false)
	await process_frame

func drag(from: Vector2, to: Vector2) -> void:
	await mouse(from, true)
	for step: int in range(1, 5):
		var event := InputEventMouseMotion.new()
		event.position = from.lerp(to, step / 4.0)
		event.global_position = event.position
		event.button_mask = MOUSE_BUTTON_MASK_LEFT
		root.push_input(event, true)
		await process_frame
	await mouse(to, false)
	await process_frame

func idle() -> void:
	for frame: int in 400:
		if not app.get("_busy"): return
		await process_frame
	check("action.finishes", false)

func _run() -> void:
	suite = "ui-interactions" if DisplayServer.get_name() == "headless" else "ui-interactions-gpu"
	var settings: Node = root.get_node("Settings")
	var save: Node = root.get_node("Save")
	settings.values.language = "zh-Hans"
	root.get_node("Locale").set_language("zh-Hans")
	settings.values.window_scale = "auto"
	settings.values.music = 0.2
	settings.values.sfx = 0.8
	save.data = load("res://core/save/schema.gd").defaults()
	app = load("res://app/boot.tscn").instantiate()
	root.add_child(app)
	await process_frame
	if OS.get_cmdline_user_args().has("--manual"):
		root.title = "PORTITOR Settings QA"
		root.size = Vector2i(960, 540)
		print("MANUAL_QA_READY: isolated save; no automated input")
		return
	await click(app.screen.buttons[2].get_global_rect().get_center())
	check("mouse.opens_settings", app.current_screen == "settings", app.current_screen)
	root.size = Vector2i(960, 540) # A player resized the window while auto is saved.
	await process_frame
	var sliders: Array[Node] = app.screen.get_children().filter(func(node: Node) -> bool: return node is HSlider)
	var music_rect: Rect2 = sliders[0].get_global_rect()
	var sfx_rect: Rect2 = sliders[1].get_global_rect()
	await click(music_rect.get_center())
	check("music.pointer_sets_half", is_equal_approx(float(settings.values.music), 0.5), settings.values.music)
	check("music.does_not_resize", root.size == Vector2i(960, 540), root.size)
	check("music.keeps_focus", app.screen.focus_index == 1, app.screen.focus_index)
	check("music.does_not_change_sfx_or_scale", settings.values.sfx == 0.8 and str(settings.values.window_scale) == "auto")
	await key(KEY_RIGHT)
	check("music.next_key_stays_on_music", is_equal_approx(float(settings.values.music), 0.6) and app.screen.focus_index == 1 and root.get_node("Locale").language == "zh-Hans", settings.values)
	await drag(music_rect.get_center(), Vector2(music_rect.position.x - 10, music_rect.get_center().y))
	check("music.drag_can_reach_zero", settings.values.music == 0.0, settings.values.music)
	await drag(Vector2(music_rect.position.x, music_rect.get_center().y), Vector2(music_rect.end.x + 10, music_rect.get_center().y))
	check("music.drag_can_reach_one", settings.values.music == 1.0, settings.values.music)
	await click(app.screen.buttons[1].get_global_rect().position + Vector2(20, 7))
	check("music.label_only_selects", settings.values.music == 1.0 and app.screen.focus_index == 1)
	await click(sfx_rect.get_center())
	check("sfx.pointer_sets_half", is_equal_approx(float(settings.values.sfx), 0.5), settings.values.sfx)
	check("sfx.does_not_resize_or_change_music", root.size == Vector2i(960, 540) and settings.values.music == 1.0)
	await key(KEY_LEFT)
	check("sfx.keyboard_decrements_correct_row", is_equal_approx(float(settings.values.sfx), 0.4) and app.screen.focus_index == 2, settings.values)
	settings.set_value("window_scale", 6)
	await process_frame
	app.screen.set_focus(3)
	await key(KEY_RIGHT)
	check("scale.can_return_to_auto", str(settings.values.window_scale) == "auto", settings.values.window_scale)
	await key(KEY_ESCAPE)
	await click(app.screen.buttons[1].get_global_rect().get_center())
	check("mouse.opens_chapters", app.current_screen == "chapters", app.current_screen)
	await key(KEY_ENTER, false, false, true)
	check("held_enter_does_not_cross_screens", app.current_screen == "chapters", app.current_screen)
	app.show_screen("chapters")
	app.lab.group_index = 0
	await key(KEY_ENTER)
	await click(app.screen.buttons[0].get_global_rect().get_center())
	for index: int in 7:
		if index > 1:
			await key(KEY_ESCAPE)
			await click(app.screen.buttons[index].get_global_rect().get_center())
		for card: int in 8:
			if app.current_screen != "rulecard": break
			await key(KEY_ENTER)
		check("level.opens.M%02d" % (index + 1), app.current_screen == "play" and str(app.session.spec.id) == "M%02d" % (index + 1))
		for action: String in app.session.spec.solution:
			var direction: String = action.get_slice("_", action.get_slice_count("_") - 1)
			var code: int = {"L": KEY_LEFT, "R": KEY_RIGHT, "U": KEY_UP, "D": KEY_DOWN}[direction]
			await key(code, action.begins_with("DIG_"), action.begins_with("POUR_"))
			await idle()
		check("physical_keys.complete.M%02d" % (index + 1), app.current_screen == "complete" and bool(save.level_data("level:M%02d" % (index + 1)).cleared))
		if index == 0:
			await click(app.screen.buttons[0].get_global_rect().get_center())
			check("mouse.next_level_opens_M02", app.current_screen in ["play", "rulecard"] and str(app.session.spec.id) == "M02")
	await key(KEY_ESCAPE)
	await key(KEY_ESCAPE)
	app.lab.group_index = 1
	app.show_screen("chapters")
	await process_frame
	var labels: Array[Node] = app.screen.find_children("*", "Label", true, false)
	var text: String = ""
	for label: Label in labels: text += label.text + "\n"
	check("water.no_false_clear_to_unlock_promise", not text.contains("通关"), text)
	check("water.available_after_basics", app.lab.available(1), text)
	await key(KEY_ENTER)
	check("water.enters_implemented_levels", app.current_screen == "levels", app.current_screen)
	var store = load("res://core/save/save_store.gd").new(save.get("_store").location)
	check("completed_progress.reads_from_disk", store.load_progress() == OK)
	for index: int in 7:
		check("progress.persisted.M%02d" % (index + 1), bool(store.level_data("level:M%02d" % (index + 1)).cleared))
	app.dispose()
	app.queue_free()
	await process_frame
	var result: Dictionary = {"suite": suite, "ok": checks.all(func(c: Dictionary) -> bool: return c.ok), "checks": checks, "scope": "Actual viewport mouse press/release/drag and physical keyboard events; real SDK author play; isolated progress"}
	var file := FileAccess.open("res://tests/results/" + suite + ".json", FileAccess.WRITE)
	file.store_string(JSON.stringify(result, "\t") + "\n")
	file.close()
	print(JSON.stringify({"suite":suite, "ok":result.ok, "checks":checks.size(), "failed":checks.filter(func(c: Dictionary) -> bool: return not c.ok)}))
	quit(0 if result.ok else 1)
