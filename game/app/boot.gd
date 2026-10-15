class_name PortitorApp
extends Node
## Routes screens and owns the one active SDK session.
const UI_IS_CANDIDATE: bool = true
# Small scheduling headroom targets at least 60 delivered frames per second.
# All artwork animation still advances on the renderer's 60 Hz integer clock.
const FRAME_CAP: int = 64
var current_screen: String = "lobby"
var session: RefCounted
var world_view: Node2D
var screen: Control
var lab := LabController.new()
var hint_level: int = 1
var return_screen: String = "lobby"
var _busy: bool = false
var _undo_hold: float = 0
var _hint_history: Array[Dictionary] = []
var _runtime_error: String = ""
var _pose: String = "idle"
var _demo_running: bool = false
var _pending_before: Dictionary = {}
var _pending_action: String = ""
var _last_action_accepted: bool = false
var _bomb_dragging: bool = false
var settle_peak_us: int = 0
var undo_peak_us: int = 0
var _fast_forward: bool = false
var _demo_serial: int = 0
var _pose_remaining: float = 0
var rule_uid: String = "mechanic:dig"
var _rule_queue: Array[String] = []
var _target_rule_key: String = ""
var _target_rule_accepted: bool = false
var _refresh_pending: bool = false

func _ready() -> void:
	if not OS.is_debug_build() and UI_IS_CANDIDATE:
		push_error("Release refused: stage-one UI still contains explicitly marked placeholders.")
		get_tree().quit(1)
		return
	Engine.max_fps = FRAME_CAP
	_apply_window_scale()
	get_window().title = Locale.text("text:game.title")
	lab.configure(JSON.parse_string(FileAccess.get_file_as_string("res://generated/content-manifest.json")))
	lab.open_all_levels = bool(Settings.values.get("open_all_levels", false))
	var renderer: Script = load("res://presentation/render/world_view.gd")
	if renderer != null:
		world_view = renderer.new()
		add_child(world_view)
	Locale.changed.connect(_refresh)
	Settings.value_changed.connect(_settings_changed)
	if DisplayServer.get_name() != "headless":
		Input.set_custom_mouse_cursor(PortitorUI.atlas("art:ui.cursor"))
	show_screen("lobby")
	call_deferred("_start_requested_level")

func _start_requested_level() -> void:
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with("--level="):
			var uid: String = argument.trim_prefix("--level=")
			for group_index: int in range(lab.groups.size()):
				if not lab.available(group_index):
					continue
				for index: int in range(lab.groups[group_index].get("levels", []).size()):
					if "level:" + str(lab.groups[group_index].levels[index].id) == uid:
						lab.group_index = group_index
						lab.level_index = index
						start_level()
						return

func _process(delta: float) -> void:
	if world_view != null and not _busy and current_screen in ["play", "hint"]:
		_pose_remaining = maxf(0, _pose_remaining - delta)
		if _pose_remaining <= 0:
			world_view.set("pose", "idle")
	if session != null and _busy:
		var started: int = Time.get_ticks_usec()
		var result: Dictionary = session.advance_settle(4)
		while _fast_forward and not result.get("finished", false) and not str(result.get("phase", "")).begins_with("snapshot") and result.get("phase", "") not in ["committed", "classification"] and Time.get_ticks_usec() - started < 2500:
			result = session.advance_settle(4)
		settle_peak_us = maxi(settle_peak_us, Time.get_ticks_usec() - started)
		if result.get("finished", false):
			_busy = false
			_fast_forward = false
			_finish_action(result)
	if current_screen == "play" and Input.is_physical_key_pressed(KEY_Z):
		_undo_hold += delta
		if _undo_hold > 0.18:
			_undo_hold = 0
			undo()
	else:
		_undo_hold = 0
	if world_view != null:
		world_view.set("observe", (Input.is_physical_key_pressed(KEY_TAB) or bool(world_view.get_meta("observe_toggle", false))) and current_screen in ["play", "hint"])
		world_view.set("show_grid", Settings.values.get("show_grid", false))
		_update_target()

func _input(event: InputEvent) -> void:
	if _bomb_dragging and event is InputEventMouseButton:
		var drag_mouse: InputEventMouseButton = event as InputEventMouseButton
		if not drag_mouse.pressed and drag_mouse.button_index == MOUSE_BUTTON_LEFT:
			_finish_bomb_drag(drag_mouse.position)
			get_viewport().set_input_as_handled()
			return
		if drag_mouse.pressed and drag_mouse.button_index == MOUSE_BUTTON_RIGHT:
			_bomb_dragging = false
			get_viewport().set_input_as_handled()
			return
	if event is InputEventMouseButton and event.pressed:
		if _busy:
			_fast_forward = true
			get_viewport().set_input_as_handled()
			return
		if _demo_running:
			_demo_running = false
			_demo_serial += 1
			get_viewport().set_input_as_handled()
			return
	if event is InputEventKey:
		var key: InputEventKey = event as InputEventKey
		if not key.pressed:
			return
		if key.echo and key.physical_keycode in [KEY_ENTER, KEY_KP_ENTER, KEY_SPACE, KEY_ESCAPE, KEY_H, KEY_R, KEY_Z]:
			return
		if current_screen == "hint" and screen != null:
			for child: Node in screen.get_children():
				if child is PortitorBubble and child.get("_revealed") < child.get("_total"):
					child.reveal_all()
					if key.physical_keycode in [KEY_H, KEY_ENTER, KEY_KP_ENTER, KEY_SPACE]:
						get_viewport().set_input_as_handled()
						return
					break
		if _demo_running:
			_demo_running = false
			_demo_serial += 1
			get_viewport().set_input_as_handled()
			return
		if _busy:
			_fast_forward = true
			get_viewport().set_input_as_handled()
			return
		if key.physical_keycode == KEY_ESCAPE:
			if _bomb_dragging:
				_bomb_dragging = false
			else:
				back()
		elif current_screen == "hint" and key.physical_keycode in [KEY_ENTER, KEY_KP_ENTER, KEY_SPACE]:
			activate_menu(int(screen.get("focus_index")) if screen != null else 0)
		elif current_screen == "hint" and hint_level == 3 and not key.shift_pressed and not key.ctrl_pressed and key.physical_keycode in [KEY_UP, KEY_W, KEY_DOWN, KEY_S]:
			screen.call("move_focus", -1 if key.physical_keycode in [KEY_UP, KEY_W] else 1)
		elif current_screen in ["play", "hint"]:
			if _observing():
				return
			match key.physical_keycode:
				KEY_Z: undo()
				KEY_R: restart()
				KEY_H: hint_level = mini(3, hint_level + 1) if current_screen == "hint" else 1; show_screen("hint")
				_:
					var direction: String = _direction(key.physical_keycode)
					if not direction.is_empty():
						var action: String = ("BOMB_" if Input.is_physical_key_pressed(KEY_B) else "DIG_" if key.shift_pressed else "POUR_" if key.ctrl_pressed or key.meta_pressed else "") + direction
						perform(action)
		elif current_screen == "hint" and key.physical_keycode == KEY_H:
			hint_level = mini(3, hint_level + 1)
			_refresh()
		elif current_screen == "chapters" and key.physical_keycode in [KEY_LEFT, KEY_A, KEY_RIGHT, KEY_D]:
			change_chapter(-1 if key.physical_keycode in [KEY_LEFT, KEY_A] else 1)
		elif current_screen == "settings" and key.physical_keycode in [KEY_LEFT, KEY_A, KEY_RIGHT, KEY_D]:
			adjust_setting(screen.get("focus_index"), -1 if key.physical_keycode in [KEY_LEFT, KEY_A] else 1)
		elif key.physical_keycode in [KEY_UP, KEY_W, KEY_DOWN, KEY_S]:
			if screen != null:
				screen.call("move_focus", -1 if key.physical_keycode in [KEY_UP, KEY_W] else 1)
		elif key.physical_keycode in [KEY_ENTER, KEY_KP_ENTER, KEY_SPACE]:
			activate_menu(int(screen.get("focus_index")) if screen != null else 0)
		else:
			return
		get_viewport().set_input_as_handled()
	elif event is InputEventMouseButton and current_screen in ["play", "hint"] and not _observing():
		var mouse: InputEventMouseButton = event as InputEventMouseButton
		if mouse.pressed and mouse.button_index in [MOUSE_BUTTON_LEFT, MOUSE_BUTTON_RIGHT] and session != null:
			var state: Dictionary = session.state()
			var offset := Vector2((320 - session.width * 16) / 2, 20 + (160 - session.height * 16) / 2)
			var tile: Vector2i = Vector2i((mouse.position - offset) / 16)
			var d: Vector2i = tile - Vector2i(state.player.x, state.player.y)
			if abs(d.x) + abs(d.y) == 1:
				var direction: String = "L" if d.x < 0 else "R" if d.x > 0 else "D" if d.y > 0 else "U"
				perform(("DIG_" if mouse.button_index == MOUSE_BUTTON_LEFT else "POUR_") + direction)

static func _direction(key: int) -> String:
	match key:
		KEY_LEFT, KEY_A: return "L"
		KEY_RIGHT, KEY_D: return "R"
		KEY_UP, KEY_W: return "U"
		KEY_DOWN, KEY_S: return "D"
	return ""

func begin_bomb_drag() -> void:
	if session != null and not _busy and not _demo_running and current_screen in ["play", "hint"] and not _observing() and int(session.grid.bag.get("bomb", 0)) > 0:
		_bomb_dragging = true

func bomb_dragging() -> bool:
	return _bomb_dragging

func _finish_bomb_drag(position: Vector2) -> void:
	_bomb_dragging = false
	if session == null or _busy or current_screen not in ["play", "hint"] or _observing():
		return
	var offset := Vector2((320 - session.width * 16) / 2, 20 + (160 - session.height * 16) / 2)
	var local: Vector2 = (position - offset) / 16
	var destination := Vector2i(floori(local.x), floori(local.y))
	var delta: Vector2i = destination - Vector2i(int(session.grid.player.x), int(session.grid.player.y))
	if abs(delta.x) + abs(delta.y) == 1:
		var direction: String = "L" if delta.x < 0 else "R" if delta.x > 0 else "D" if delta.y > 0 else "U"
		perform("BOMB_" + direction)

func show_screen(name: String) -> void:
	_bomb_dragging = false
	var within_level: bool = name in ["play", "pause", "hint", "complete", "rulecard"] or (name == "settings" and return_screen == "pause")
	if session != null and not within_level:
		_persist_level_checkpoint()
		session.dispose()
		session = null
		_busy = false
		_fast_forward = false
		_demo_running = false
		_demo_serial += 1
		_hint_history.clear()
	current_screen = name
	if world_view != null:
		world_view.set_meta("observe_toggle", false)
	if screen != null:
		remove_child(screen)
		screen.queue_free()
	var packed: PackedScene = load("res://presentation/ui/screens/play.tscn") as PackedScene if name == "play" else Registry.get_resource("art:ui.screen." + name) as PackedScene
	if packed == null:
		return
	screen = packed.instantiate()
	add_child(screen)
	screen.call("configure", self)
	if world_view != null:
		if session != null and within_level:
			world_view.call("set_session", session)
		else:
			var theme: String = "art:" + str(lab.current_group().get("theme", "theme.dungeon"))
			world_view.call("set_backdrop", theme, name == "lobby")
		world_view.set("environment_mode", str(Settings.values.get("ambience", "full")))

func _refresh() -> void:
	if not is_inside_tree() or _refresh_pending:
		return
	_refresh_pending = true
	call_deferred("_flush_refresh")

func _flush_refresh() -> void:
	_refresh_pending = false
	if not is_inside_tree():
		return
	get_window().title = Locale.text("text:game.title")
	var focus: int = int(screen.get("focus_index")) if screen != null else 0
	show_screen(current_screen)
	if screen != null:
		screen.call("set_focus", focus)

func _settings_changed(key: String, _value: Variant) -> void:
	if key == "open_all_levels":
		lab.open_all_levels = bool(_value)
	if key == "window_scale":
		_apply_window_scale()
	if current_screen == "settings" and key in ["music", "sfx"] and screen != null:
		screen.refresh_volume(key)
	else:
		_refresh()

func set_volume(key: String, value: float) -> void:
	if key in ["music", "sfx"]:
		Settings.set_value(key, roundi(clampf(value, 0, 1) * 10.0) / 10.0)

func _apply_window_scale() -> void:
	var value: Variant = Settings.values.get("window_scale", "auto")
	var scale_value: int = int(value) if str(value).is_valid_int() else 4
	if str(value) == "auto" and DisplayServer.get_name() != "headless":
		var usable: Rect2i = DisplayServer.screen_get_usable_rect()
		scale_value = mini(usable.size.x / 320, usable.size.y / 180)
	get_window().size = Vector2i(320, 180) * clampi(scale_value, 1, 6)

func activate_menu(index: int) -> void:
	match current_screen:
		"lobby":
			match index:
				0:
					var resume_uid: String = str(Save.data.get("last_level_uid", ""))
					if not resume_uid.is_empty():
						for group_index: int in lab.groups.size():
							if not lab.available(group_index): continue
							for level_index: int in lab.groups[group_index].levels.size():
								if "level:" + str(lab.groups[group_index].levels[level_index].id) == resume_uid:
									lab.group_index = group_index
									lab.level_index = level_index
									start_level(true)
									return
					show_screen("chapters")
				1: show_screen("chapters")
				2: return_screen = "lobby"; show_screen("settings")
				3: get_tree().quit()
		"chapters":
			if lab.available(lab.group_index):
				lab.level_index = 0
				show_screen("levels")
		"levels":
			lab.level_index = clampi(index, 0, maxi(0, lab.levels().size() - 1))
			start_level()
		"pause":
			match index:
				0: show_screen("play")
				1: hint_level = 1; show_screen("hint")
				2: restart(); show_screen("play")
				3: Save.mark_level(lab.level_uid(), false, true, 0); show_screen("levels")
				4: show_screen("levels")
				5: return_screen = "pause"; show_screen("settings")
				6: show_screen("lobby")
		"hint":
			if hint_level < 3:
				hint_level += 1
				_refresh()
			elif index == 0:
				demonstrate()
			else:
				rewind_correct()
		"complete":
			if index == 0 and lab.level_index + 1 < lab.levels().size():
				lab.level_index += 1
				start_level()
			else:
				show_screen("levels")
		"rulecard": close_rule_card()
		"settings": adjust_setting(index, 1)

func change_chapter(amount: int) -> void:
	var old_index: int = lab.group_index
	lab.group_index = clampi(lab.group_index + amount, 0, lab.groups.size() - 1)
	if screen != null and old_index != lab.group_index and screen.has_method("slide_chapter"):
		screen.call("slide_chapter", old_index, lab.group_index)

func start_level(resume_checkpoint: bool = false) -> void:
	if not lab.available(lab.group_index):
		return
	if not lab.stage_available(lab.group_index) or not lab.has_spec():
		_runtime_error = Locale.text("text:chapter.preview")
		show_screen("levels")
		return
	_busy = false
	_fast_forward = false
	_demo_running = false
	_demo_serial += 1
	_runtime_error = ""
	_pending_before = {}
	_pending_action = ""
	_target_rule_key = ""
	if session != null:
		_persist_level_checkpoint()
		session.dispose()
		session = null
	var spec: Dictionary = Registry.level_spec(lab.level_uid())
	if spec.is_empty():
		_runtime_error = Locale.text("text:chapter.preview")
		show_screen("levels")
		return
	var script: Script = load("res://gameplay/session/level_session.gd")
	session = script.new()
	if not session.setup(spec):
		_runtime_error = Locale.text("text:error.runtime", {"reason":session.last_error})
		session.dispose()
		session = null
		show_screen("lobby")
		return
	session.configure_checkpoint(lab.level_uid(), str(Registry.entry(lab.level_uid()).get("sha256", "")))
	var opening: Dictionary = session.state().duplicate(true)
	var checkpoint: Dictionary = session.restore_checkpoint() if resume_checkpoint else {}
	if bool(checkpoint.get("fatal", false)) or bool(checkpoint.get("failed", false)):
		# A failed Continue returns to the lobby with the old publication point
		# intact. Disposal is direct, so scene-exit autosave cannot replace it.
		_runtime_error = Locale.text("text:error.runtime", {"reason": str(session.checkpoint_error)})
		session.dispose()
		session = null
		show_screen("lobby")
		return
	var saved_route: Variant = checkpoint.get("mode_state", {}).get("author_route", [])
	var route: Array = saved_route if saved_route is Array and not saved_route.is_empty() else Registry.author_route(lab.level_uid())
	lab.begin_route(opening, route, spec.get("solution", []))
	_persist_level_checkpoint()
	Save.data["last_level_uid"] = lab.level_uid()
	Save.save_progress()
	_hint_history = [session.state().duplicate(true)]
	if bool(session.state().get("won", false)):
		# A committed winning checkpoint is still a real goal state if a crash
		# happened before progress.json was atomically committed.
		Save.mark_level(lab.level_uid(), true, false, int(session.state().get("moves", 0)))
		show_screen("complete")
		return
	show_screen("play")
	_rule_queue.clear()
	var seen_value: Variant = Save.data.get("rule_cards_seen", [])
	var seen: Array = seen_value if seen_value is Array else []
	var aliases: Dictionary = {"push":"mechanic:push", "ladder":"mechanic:ladder", "dig":"mechanic:dig", "pour":"mechanic:pour", "plate":"mechanic:plate_door", "fall":"mechanic:fall"}
	for concept: String in spec.get("requires", []):
		var uid: String = aliases.get(concept, "")
		if not uid.is_empty() and not seen.has(uid) and not _rule_queue.has(uid): _rule_queue.append(uid)
	if str(spec.id) == "M03" and not seen.has("mechanic:dig"):
		_rule_queue.append("mechanic:dig")
	if not _rule_queue.is_empty():
		rule_uid = _rule_queue.pop_front()
		show_screen("rulecard")

func close_rule_card() -> void:
	var seen_value: Variant = Save.data.get("rule_cards_seen", [])
	var seen: Array = seen_value if seen_value is Array else []
	if not seen.has(rule_uid): seen.append(rule_uid)
	Save.data["rule_cards_seen"] = seen
	Save.save_progress()
	if not _rule_queue.is_empty():
		rule_uid = _rule_queue.pop_front()
		show_screen("rulecard")
	else:
		show_screen("play")

func rule_card_text() -> Dictionary:
	if rule_uid == "mechanic:dig":
		return {"name":"rule.earth.name", "text":"rule.earth.text", "icon":"art:ui.class_icon", "animation":"earth"}
	var id: String = rule_uid.trim_prefix("mechanic:")
	var icons: Dictionary = {"push":"art:obj.crate_wood", "ladder":"art:mech.ladder", "pour":"art:item.sandbag", "plate_door":"art:mech.plate", "fall":"art:obj.crate_wood"}
	return {"name":"extra.rule." + id + ".name", "text":"extra.rule." + id + ".text", "icon":icons.get(id, "art:obj.crate_wood"), "animation":"up" if id == "plate_door" else "default"}

func perform(action: String) -> void:
	if session == null or _busy:
		return
	_pending_before = session.state().duplicate(true)
	_pending_action = action
	_last_action_accepted = false
	var result: Dictionary = session.begin_action(action, true)
	if world_view != null and result.get("accepted", false):
		world_view.set("pose", {"walk":"walk","step":"walk","push":"push","dig":"dig","pour":"pour","climb":"climb"}.get(result.get("kind", ""), "idle"))
		world_view.set("facing_left", action.ends_with("L"))
		_pose_remaining = 0.25
	_busy = not result.get("finished", true)
	if not _busy:
		_finish_action(result)

func _finish_action(result: Dictionary) -> void:
	_last_action_accepted = bool(result.get("accepted", false)) and str(result.get("error", "")).is_empty()
	if not str(result.get("error", "")).is_empty():
		_runtime_error = Locale.text("text:error.runtime", {"reason": str(result.error)})
		_refresh()
		return
	_runtime_error = ""
	if not result.get("accepted", false) and result.get("error", "").is_empty() and world_view != null:
		world_view.blocked_feedback()
	if result.get("accepted", false):
		lab.record_action(_pending_before, _pending_action, session.state())
		_hint_history.append(_pending_before)
		var learned: String = {"walk":"mechanic:push", "step":"mechanic:push", "push":"mechanic:push", "climb":"mechanic:ladder", "dig":"mechanic:dig", "pour":"mechanic:pour"}.get(result.get("kind", ""), "")
		if not learned.is_empty(): _mark_rule_seen(learned)
		if session.state().get("doors") != _pending_before.get("doors"): _mark_rule_seen("mechanic:plate_door")
		if session.state().player.y > _pending_before.player.y: _mark_rule_seen("mechanic:fall")
		if _hint_history.size() > 200:
			_hint_history.pop_front()
		_persist_level_checkpoint()
	if result.get("won", false):
		if world_view != null: world_view.set("pose", "win")
		Save.mark_level(lab.level_uid(), true, false, session.state().get("moves", 0))
		show_screen("complete")
	else:
		if current_screen == "play" and screen != null and screen.has_method("refresh_session"):
			screen.refresh_session()
		else:
			_refresh()

func _mark_rule_seen(uid: String) -> void:
	var value: Variant = Save.data.get("rule_cards_seen", [])
	var seen: Array = value if value is Array else []
	if seen.has(uid): return
	seen.append(uid)
	Save.data["rule_cards_seen"] = seen
	Save.save_progress()

func undo() -> void:
	if session == null or _busy:
		return
	var start: int = Time.get_ticks_usec()
	if session.undo():
		undo_peak_us = maxi(undo_peak_us, Time.get_ticks_usec() - start)
		if _hint_history.size() > 1:
			_hint_history.pop_back()
		_persist_level_checkpoint()
		show_screen("play")

func restart() -> void:
	if session != null and session.restart():
		_persist_level_checkpoint()
		show_screen("play")

func demonstrate() -> void:
	if session == null:
		return
	var index: int = lab.route_index(session.state())
	if index < 0:
		rewind_correct()
		return
	show_screen("play")
	_demo_running = true
	_demo_serial += 1
	var serial: int = _demo_serial
	var active_session: RefCounted = session
	var actions: Array = session.spec.solution
	for step: int in range(index, actions.size()):
		if current_screen != "play" or not _demo_running or serial != _demo_serial or active_session != session:
			break
		if lab.route_index(session.state()) != step:
			break
		perform(actions[step])
		while _busy:
			await get_tree().process_frame
			if serial != _demo_serial or active_session != session:
				return
		if not _last_action_accepted:
			break
		await get_tree().create_timer(0.22).timeout
		if serial != _demo_serial or active_session != session:
			return
	if serial == _demo_serial:
		_demo_running = false

func rewind_correct() -> void:
	if session == null:
		return
	for _step: int in range(200):
		if lab.route_index(session.state()) >= 0:
			show_screen("play")
			return
		if not session.undo():
			break
		_persist_level_checkpoint()
	_runtime_error = Locale.text("text:hint.restart")
	_refresh()

func back() -> void:
	match current_screen:
		"play": show_screen("pause")
		"pause", "hint": show_screen("play")
		"rulecard": close_rule_card()
		"levels": show_screen("chapters")
		"settings": show_screen(return_screen)
		"complete": show_screen("levels")
		_: show_screen("lobby")

func adjust_setting(index: int, amount: int) -> void:
	var fields: Array[String] = ["language", "music", "sfx", "window_scale", "ambience", "show_grid", "open_all_levels", "tutorial"]
	if index < 0 or index >= fields.size():
		return
	var key: String = fields[index]
	var value: Variant = Settings.values.get(key)
	match key:
		"language": Settings.set_value(key, "en" if Locale.language == "zh-Hans" else "zh-Hans")
		"music", "sfx": set_volume(key, float(value) + amount * 0.1)
		"ambience":
			var choices: Array[String] = ["full", "lights", "off"]
			Settings.set_value(key, choices[posmod(choices.find(str(value)) + amount, 3)])
		"window_scale":
			var choices: Array = ["auto", 1, 2, 3, 4, 5, 6]
			Settings.set_value(key, choices[posmod(choices.find(value) + amount, choices.size())])
		"show_grid", "open_all_levels": Settings.set_value(key, not bool(value))
		"tutorial": Save.data["rule_cards_seen"] = []; Save.save_progress(); _refresh()

func toggle_observe() -> void:
	if world_view != null:
		world_view.set_meta("observe_toggle", not bool(world_view.get_meta("observe_toggle", false)))

func _observing() -> bool:
	return Input.is_physical_key_pressed(KEY_TAB) or (world_view != null and bool(world_view.get_meta("observe_toggle", false)))

func _update_target() -> void:
	if world_view == null or session == null or current_screen not in ["play", "hint"] or _busy:
		if world_view != null:
			world_view.set("target", {})
		return
	var state: Dictionary = session.state()
	if current_screen == "hint" and hint_level == 1 and not _bomb_dragging and not Input.is_physical_key_pressed(KEY_B):
		world_view.set("target", {"cells": _hint_target_cells()})
		return
	var p := Vector2i(state.player.x, state.player.y)
	var destination := Vector2i(-1, -1)
	var kind: String = "bomb" if _bomb_dragging or Input.is_physical_key_pressed(KEY_B) else "dig" if Input.is_physical_key_pressed(KEY_SHIFT) else "pour" if Input.is_physical_key_pressed(KEY_CTRL) or Input.is_physical_key_pressed(KEY_META) else "push"
	for pair: Array in [[KEY_LEFT, Vector2i.LEFT], [KEY_A, Vector2i.LEFT], [KEY_RIGHT, Vector2i.RIGHT], [KEY_D, Vector2i.RIGHT], [KEY_UP, Vector2i.UP], [KEY_W, Vector2i.UP], [KEY_DOWN, Vector2i.DOWN], [KEY_S, Vector2i.DOWN]]:
		if Input.is_physical_key_pressed(pair[0]):
			destination = p + pair[1]
	if destination.x < 0:
		var offset := Vector2((320 - session.width * 16) / 2, 20 + (160 - session.height * 16) / 2)
		destination = Vector2i((get_viewport().get_mouse_position() - offset) / 16)
	if abs(destination.x - p.x) + abs(destination.y - p.y) != 1:
		world_view.set("target", {})
		return
	var direction: String = "L" if destination.x < p.x else "R" if destination.x > p.x else "D" if destination.y > p.y else "U"
	var action: String = ("BOMB_" if kind == "bomb" else "DIG_" if kind == "dig" else "POUR_" if kind == "pour" else "") + direction
	# A settled world cannot change between inputs (auto_step=false). Cache
	# the read-only safety query by actual SDK hash plus complete game state.
	var rule_key: String = str([action, state, session.world.get_state_hash()])
	if rule_key != _target_rule_key:
		_target_rule_key = rule_key
		_target_rule_accepted = bool(session.can_perform(action).get("accepted", false))
	if not _target_rule_accepted:
		world_view.set("target", {})
		return
	# Rule-only projection: no second SDK world and no simulation preview.
	if kind == "push":
		for crate: Dictionary in state.crates:
			if Vector2i(crate.x, crate.y) == destination:
				destination += Vector2i.LEFT if direction == "L" else Vector2i.RIGHT
				while destination.y + 1 < session.height and session.grid.is_free(destination.x, destination.y + 1):
					if str(crate.kind) == "wood" and session.grid.terrain_at(destination.x, destination.y + 1) == session.grid.Terrain.WATER:
						break
					destination.y += 1
	world_view.set("target", _target_cells(destination, kind))

func _target_cells(destination: Vector2i, kind: String) -> Dictionary:
	var result: Dictionary = {"x": destination.x, "y": destination.y, "kind": kind}
	if kind == "pour":
		var cells: Array[Dictionary] = []
		for y: int in session.height:
			cells.append({"x": destination.x, "y": y, "kind": kind})
		result.cells = cells
	elif kind == "bomb":
		# The SDK explosion is a pixel-space circle, including its diagonal reach.
		result.blast_center = destination * 16 + Vector2i(8, 8)
		result.blast_radius = 20
		var affected: Array[Dictionary] = []
		for y: int in range(maxi(0, destination.y - 2), mini(session.height, destination.y + 3)):
			for x: int in range(maxi(0, destination.x - 2), mini(session.width, destination.x + 3)):
				var nearest := Vector2i(clampi(result.blast_center.x, x * 16, x * 16 + 15), clampi(result.blast_center.y, y * 16, y * 16 + 15))
				if nearest.distance_squared_to(result.blast_center) <= 20 * 20:
					affected.append({"x": x, "y": y, "kind": "bomb"})
		result.cells = affected
	return result

func _hint_target_cells() -> Array[Dictionary]:
	# Resolve the objects named by each existing first hint from the live grid.
	# This only selects outlines; it never steps or predicts an SDK world.
	var cells: Array[Dictionary] = []
	var uid: String = lab.level_uid()
	var state: Dictionary = session.state()
	if uid in ["level:M02", "level:M07"]:
		for crate: Dictionary in state.crates:
			cells.append({"x": int(crate.x), "y": int(crate.y), "kind": "push"})
	for y: int in session.height:
		for x: int in session.width:
			var i: int = session.grid.tile_index(x, y)
			var marker: int = session.grid.markers[i]
			var selected: bool = (uid in ["level:M01", "level:M02"] and marker == session.grid.Marker.SOCKET) or (uid in ["level:M03", "level:M07"] and session.grid.terrain[i] == session.grid.Terrain.EARTH) or (uid == "level:M05" and (marker == session.grid.Marker.PLATE or session.grid.door_at.has(i)))
			if selected:
				cells.append({"x": x, "y": y, "kind": "dig" if uid in ["level:M03", "level:M07"] else "push"})
			if uid in ["level:M04", "level:M06"] and marker == session.grid.Marker.EXIT:
				for step_y: int in range(y + 1, mini(session.height - 1, y + 3)):
					cells.append({"x": x, "y": step_y, "kind": "push"})
	if str(session.spec.get("group", "basics")) != "basics":
		var selected: Dictionary = {}
		for cell: Dictionary in cells:
			selected[str([cell.x, cell.y])] = cell
		for device: Dictionary in state.get("devices", []):
			var points: Array = []
			for field: String in ["at", "root", "button"]:
				if device.get(field, []).size() == 2:
					points.append(device[field])
			for field: String in ["cells", "pads", "stops", "ends", "landings"]:
				points.append_array(device.get(field, []))
			if device.get("rect", []).size() == 4:
				points.append([device.rect[0], device.rect[1]])
			for point: Array in points:
				selected[str(point)] = {"x": int(point[0]), "y": int(point[1]), "kind": "push"}
		for y: int in range(session.height):
			for x: int in range(session.width):
				var terrain: int = session.grid.terrain_at(x, y)
				if terrain not in [session.grid.Terrain.EMPTY, session.grid.Terrain.ROCK]:
					selected[str([x, y])] = {"x": x, "y": y, "kind": "dig" if terrain == session.grid.Terrain.EARTH else "push"}
		cells.clear()
		for cell: Dictionary in selected.values():
			cells.append(cell)
	return cells

func layout_issues() -> Array:
	return screen.call("layout_issues") if screen != null else []

func _persist_level_checkpoint() -> void:
	if session == null or bool(session.busy):
		return
	if not session.save_checkpoint({"author_route": lab.route}):
		_runtime_error = Locale.text("text:error.runtime", {"reason": str(session.checkpoint_error)})
		push_warning(str(session.checkpoint_error))

func dispose() -> void:
	_persist_level_checkpoint()
	_demo_running = false
	_demo_serial += 1
	if DisplayServer.get_name() != "headless":
		Input.set_custom_mouse_cursor(null)
	if session != null:
		session.dispose()
		session = null

func _exit_tree() -> void:
	dispose()
