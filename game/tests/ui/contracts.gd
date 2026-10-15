extends SceneTree
## Focused UI regressions, independent of reference-pixel acceptance.

var failures: Array[String] = []

func _initialize() -> void:
	create_timer(30.0).timeout.connect(func() -> void: printerr("FAIL: ui-contracts timeout"); quit(1))
	call_deferred("_run")

func _check(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)
		printerr("FAIL: " + message)

func _press(code: int) -> void:
	var event := InputEventKey.new()
	event.physical_keycode = code
	event.keycode = code
	event.pressed = true
	Input.parse_input_event(event)
	await process_frame
	var release := InputEventKey.new()
	release.physical_keycode = code
	release.keycode = code
	release.pressed = false
	Input.parse_input_event(release)
	await process_frame

func _reveal(boot: Node) -> void:
	for child: Node in boot.screen.get_children():
		if child is PortitorBubble:
			(child as PortitorBubble).reveal_all()

func _idle(boot: Node) -> void:
	for frame: int in 240:
		if not boot.get("_busy"):
			return
		await process_frame
	_check(false, "test action reaches a settled UI state within 240 frames")

func _run() -> void:
	var boot: Node = load("res://app/boot.tscn").instantiate()
	root.add_child(boot)
	await process_frame
	# Isolate these interface checks from the separate unseen-rule-card tests.
	root.get_node("Save").data["rule_cards_seen"] = ["mechanic:push", "mechanic:ladder", "mechanic:dig", "mechanic:pour", "mechanic:plate_door", "mechanic:fall"]
	boot.lab.group_index = 0
	boot.lab.level_index = 0
	boot.start_level()
	await process_frame
	_check(boot.session != null, "HUD contract requires a real SDK session")
	if boot.session != null:
		var goals: Array = boot.session.goal_lights()
		var hud: Control = boot.screen
		var lamps := hud.find_child("GoalLamps", true, false)
		_check(lamps != null and lamps.get_child_count() == goals.size(), "HUD shows one lamp for each real goal")
		var count := hud.find_child("GoalCount", true, false) as Label
		_check(count != null and count.text == "0 / 1", "HUD shows current goal completion count")
		var observe := hud.find_child("ObserveButton", true, false) as Button
		_check(observe != null, "HUD exposes the observe control")
		if observe != null:
			observe.button_down.emit()
			_check(bool(boot.world_view.observe), "holding observe HUD control enables observation")
			observe.button_up.emit()
			_check(not bool(boot.world_view.observe), "releasing observe HUD control disables observation")
	var bubble := PortitorBubble.new()
	root.add_child(bubble)
	var speaker := Vector2(8, 100)
	bubble.configure("A long hint stays attached to the speaker near the left screen edge.", speaker, "", "")
	var expected_tail: float = clampf(speaker.x, bubble.box.position.x + 5, bubble.box.end.x - 6)
	_check(is_equal_approx(bubble.tail_x, expected_tail), "bubble tail follows the clamped speaker anchor")
	_check(not is_equal_approx(bubble.tail_x, bubble.box.get_center().x), "edge bubble fixture distinguishes speaker anchor from box center")
	bubble.free()
	var settings: Node = root.get_node("Settings")
	var old_scale: Variant = settings.values.window_scale
	var old_window_size: Vector2i = root.size
	settings.values["window_scale"] = 2
	var fresh_boot: Node = load("res://app/boot.tscn").instantiate()
	fresh_boot.set_process(false)
	fresh_boot.set_process_input(false)
	root.add_child(fresh_boot)
	await process_frame
	_check(root.size == Vector2i(640, 360), "a newly started app applies the saved integer window scale")
	fresh_boot.dispose()
	fresh_boot.queue_free()
	await process_frame
	settings.values["window_scale"] = old_scale
	root.size = old_window_size
	boot.hint_level = 1
	boot.show_screen("hint")
	_reveal(boot)
	await _press(KEY_ENTER)
	_check(boot.hint_level == 2 and boot.current_screen == "hint", "physical Enter advances the revealed first hint")
	boot.hint_level = 3
	boot.show_screen("hint")
	_reveal(boot)
	await _press(KEY_ENTER)
	_check(boot.get("_demo_running") and boot.current_screen == "play", "physical Enter starts the third-hint demonstration")
	# Invalidate the asynchronous continuation before disposing its old world.
	boot.set("_demo_running", false)
	boot.set("_demo_serial", int(boot.get("_demo_serial")) + 1)
	boot.start_level()
	boot.perform("L")
	await _idle(boot)
	_check(boot.lab.route_index(boot.session.state()) < 0, "rewind fixture starts off the M01 author route")
	boot.hint_level = 3
	boot.show_screen("hint")
	_reveal(boot)
	var before_select: Dictionary = boot.session.state().duplicate(true)
	await _press(KEY_S)
	_check(int(boot.screen.focus_index) == 1, "physical S selects the third-hint rewind button")
	_check(boot.session.state().player == before_select.player and boot.session.state().moves == before_select.moves, "third-hint button selection cannot move the player")
	boot.screen.set_focus(0)
	await _press(KEY_DOWN)
	_check(int(boot.screen.focus_index) == 1, "physical Down selects the third-hint rewind button")
	_check(boot.session.state().player == before_select.player and boot.session.state().moves == before_select.moves, "third-hint Down selection cannot move the player")
	_reveal(boot)
	await _press(KEY_ENTER)
	_check(boot.current_screen == "play" and boot.lab.route_index(boot.session.state()) >= 0, "physical Enter rewinds to an author-route state")
	boot.lab.level_index = 3
	boot.start_level()
	for action: String in ["R", "R", "POUR_R"]:
		boot.perform(action)
		await _idle(boot)
	var original_opening: Array = boot.world_view.get("_opening").terrain.duplicate()
	var original_elapsed: float = float(boot.world_view.get("_elapsed"))
	boot.show_screen("pause")
	boot.return_screen = "pause"
	boot.show_screen("settings")
	boot.back()
	boot.back()
	_check(boot.current_screen == "play", "pause settings returns to the same live level")
	_check(boot.world_view.get("_opening").terrain == original_opening, "pause settings cannot replace opening decoration terrain with poured sand")
	_check(float(boot.world_view.get("_elapsed")) >= original_elapsed, "pause settings cannot reset the level animation clock")
	var pour: Dictionary = boot._target_cells(Vector2i(3, 4), "pour")
	_check(pour.get("cells", []).size() == boot.session.height, "pour highlight covers the full level column")
	for cell: Dictionary in pour.get("cells", []):
		_check(int(cell.x) == 3 and int(cell.y) >= 0 and int(cell.y) < boot.session.height, "pour highlight keeps one valid column x coordinate")
	for index: int in 7:
		boot.lab.level_index = index
		boot.start_level()
		boot.hint_level = 1
		boot.show_screen("hint")
		_reveal(boot)
		var moves_before: int = int(boot.session.state().moves)
		var hash_before: String = str(boot.session.world.get_state_hash())
		boot._update_target()
		var cells: Array = boot._hint_target_cells()
		_check(not cells.is_empty(), "first hint selects existing objects in level %d" % (index + 1))
		for cell: Dictionary in cells:
			_check(int(cell.x) >= 0 and int(cell.y) >= 0 and int(cell.x) < boot.session.width and int(cell.y) < boot.session.height, "first hint outlines stay inside level %d" % (index + 1))
		_check(int(boot.session.state().moves) == moves_before and str(boot.session.world.get_state_hash()) == hash_before, "hint highlighting does not advance moves or SDK state in level %d" % (index + 1))
	boot.show_screen("chapters")
	await process_frame
	var chapter_screen: Control = boot.screen
	var thumbnails := chapter_screen.find_children("ThemeThumbnail*", "TextureRect", true, false)
	_check(not thumbnails.is_empty(), "chapter cards contain theme thumbnail controls")
	var progress := chapter_screen.find_child("ChapterProgress0", true, false) as Label
	_check(progress != null and progress.text.ends_with("/ 7"), "chapter card progress uses current manifest level count")
	var pages := chapter_screen.find_child("ChapterPageIndicator", true, false)
	_check(pages != null and pages.get_child_count() == boot.lab.groups.size(), "chapter selector has one page marker per group")
	var clipped := Button.new()
	clipped.text = "THIS BUTTON MUST NOT SILENTLY CLIP"
	clipped.add_theme_font_override("font", PortitorUI.font())
	clipped.add_theme_font_size_override("font_size", 12)
	clipped.clip_text = true
	clipped.position = Vector2(1, 1)
	clipped.size = Vector2(12, 15)
	chapter_screen.add_child(clipped)
	var wrapped: Label = PortitorUI.label("one two three four five six seven eight nine ten", 24, false, true)
	wrapped.max_lines_visible = 1
	wrapped.position = Vector2(290, 168)
	wrapped.size = Vector2(24, 12)
	chapter_screen.add_child(wrapped)
	await process_frame
	var issues: Array = chapter_screen.layout_issues()
	_check(issues.any(func(issue: Variant) -> bool: return str(issue).contains("button")), "layout scan catches button text clipping")
	_check(issues.any(func(issue: Variant) -> bool: return str(issue).contains("vertical") or str(issue).contains("hidden lines")), "layout scan catches wrapped label height clipping")
	boot.dispose()
	boot.queue_free()
	await process_frame
	print(JSON.stringify({"suite": "ui-contracts", "ok": failures.is_empty(), "failures": failures}))
	quit(0 if failures.is_empty() else 1)
