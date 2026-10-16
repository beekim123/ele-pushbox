extends SceneTree
const SOURCE = preload("res://tests/chapters/hint_source.gd")
## Isolated F08 Hint UI regression with a real SDK session. Never plays a move.
var boot: Node
var checks: Array[Dictionary] = []
var spec_sha256: String = ""

func _initialize() -> void:
	create_timer(30.0).timeout.connect(func() -> void: _finish("Hint UI test timed out"))
	call_deferred("_run")

func _snapshot() -> Dictionary:
	return {"state_sha256":JSON.stringify(boot.session.state()).sha256_text(),"sdk_hash":boot.session.world.get_state_hash(),"tick":boot.session.world.get_stats().get("tick",-1),"moves":boot.session.grid.moves,"observe_sha256":JSON.stringify(boot.session.observe()).sha256_text()}

func _check(name: String, before: Dictionary, expected_hint: int) -> void:
	var after: Dictionary = _snapshot()
	checks.append({"name":name,"ok":before == after and boot.current_screen == "hint" and int(boot.hint_level) == expected_hint,"before":before,"after":after,"screen":boot.current_screen,"hint_level":boot.hint_level})

func _reveal_hint() -> void:
	for child: Node in boot.screen.get_children():
		if child is PortitorBubble: child.reveal_all()

func _press_h() -> void:
	var event := InputEventKey.new()
	event.physical_keycode = KEY_H
	event.keycode = KEY_H
	event.pressed = true
	Input.parse_input_event(event)
	await process_frame
	var release := InputEventKey.new()
	release.physical_keycode = KEY_H
	release.keycode = KEY_H
	release.pressed = false
	Input.parse_input_event(release)
	await process_frame

func _run() -> void:
	var bytes: PackedByteArray = FileAccess.get_file_as_bytes("res://generated/content/levels/lab/thermal/F08.json")
	if bytes.is_empty():
		_finish("Imported F08 spec is missing")
		return
	var digest := HashingContext.new()
	digest.start(HashingContext.HASH_SHA256)
	digest.update(bytes)
	spec_sha256 = digest.finish().hex_encode()
	boot = load("res://app/boot.tscn").instantiate()
	root.add_child(boot)
	await process_frame
	boot.lab.open_all_levels = true
	var found: bool = false
	for group_index: int in range(boot.lab.groups.size()):
		if str(boot.lab.groups[group_index].id) != "thermal": continue
		for level_index: int in range(boot.lab.groups[group_index].levels.size()):
			if str(boot.lab.groups[group_index].levels[level_index].id) == "F08":
				boot.lab.group_index = group_index
				boot.lab.level_index = level_index
				found = true
	if not found:
		_finish("F08 not found in imported manifest")
		return
	root.get_node("Save").data["rule_cards_seen"] = ["mechanic:push","mechanic:ladder","mechanic:dig","mechanic:pour","mechanic:plate_door","mechanic:fall"]
	boot.start_level()
	await process_frame
	if boot.session == null or boot.current_screen != "play":
		_finish("F08 did not open in the actual play HUD")
		return
	var button: Button
	for child: Node in boot.screen.get_children():
		if child is Button and (child as Button).position == Vector2(277,3): button = child as Button
	if button == null:
		_finish("Actual Hint HUD button was not found")
		return
	var before: Dictionary = _snapshot()
	button.pressed.emit()
	await process_frame
	_check("actual_HUD_hint_button",before,1)
	_reveal_hint()
	await _press_h()
	_check("physical_H_second_hint",before,2)
	_reveal_hint()
	await _press_h()
	_check("physical_H_third_hint",before,3)
	_finish("")

func _finish(error: String) -> void:
	var passed: bool = error.is_empty() and checks.size() == 3 and checks.all(func(item: Dictionary) -> bool: return bool(item.ok))
	var result: Dictionary = {"format":"portitor.thermal-hint-ui/1","id":"F08","spec_sha256":spec_sha256,"source_sha256":SOURCE.fingerprint(),"runtime":"real-ele-sdk","ok":passed,"error":error,"checks":checks}
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://tests/results"))
	var output = FileAccess.open("res://tests/results/thermal-hint-ui.json",FileAccess.WRITE)
	if output != null:
		output.store_string(JSON.stringify(result,"\t"))
		output.close()
	if is_instance_valid(boot):
		boot.dispose()
		boot.queue_free()
	print("PORTITOR_THERMAL_HINT_UI=" + JSON.stringify(result))
	quit(0 if passed else 1)
