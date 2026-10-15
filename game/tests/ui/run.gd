extends SceneTree
## Exercises the application's public flow and both locale layouts.
var failures: Array[String] = []

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	if not ResourceLoader.exists("res://app/boot.tscn"):
		failures.append("boot scene missing: playable menu flow unavailable")
	else:
		var boot: Node = load("res://app/boot.tscn").instantiate()
		root.add_child(boot)
		await process_frame
		for lang: String in ["zh-Hans", "en"]:
			root.get_node("Locale").set_language(lang)
			for screen: String in ["lobby", "chapters", "levels", "settings", "pause", "hint", "complete", "rulecard"]:
				boot.show_screen(screen)
				await process_frame
				var issues: Array = boot.layout_issues()
				if not issues.is_empty():
					failures.append(lang + "/" + screen + ": " + str(issues))
			for level_index: int in range(7):
				boot.lab.group_index = 0
				boot.lab.level_index = level_index
				boot.start_level()
				for tier: int in range(1, 4):
					boot.hint_level = tier
					boot.show_screen("hint")
					await process_frame
					var issues: Array = boot.layout_issues()
					if not issues.is_empty(): failures.append(lang + "/" + boot.lab.level_uid() + "/hint" + str(tier) + ": " + str(issues))
		root.get_node("Save").data.erase("last_level_uid")
		boot.lab.group_index = 0
		boot.show_screen("lobby")
		boot.activate_menu(0)
		if boot.current_screen != "chapters":
			failures.append("lobby Enter must open chapters")
		boot.activate_menu(0)
		if boot.current_screen != "levels":
			failures.append("chapter Enter must open levels")
		boot.activate_menu(0)
		if boot.current_screen != "play" or boot.session == null:
			failures.append("level Enter must create a real SDK session")
		boot.set("_busy", true)
		boot.set("_demo_running", true)
		boot.start_level()
		if boot.get("_busy") or boot.get("_demo_running"): failures.append("changing level cancels old pending simulation/demo state")
		root.get_node("Save").data["last_level_uid"] = "level:M01"
		boot.lab.group_index = 1
		boot.show_screen("lobby")
		boot.activate_menu(0)
		if boot.current_screen != "play" or boot.lab.group_index != 0: failures.append("continue restores the saved uid after browsing another chapter")
		boot.world_view.set_meta("observe_toggle", true)
		var before: String = LabController.comparable(boot.session.state())
		var key := InputEventKey.new()
		key.pressed = true
		key.physical_keycode = KEY_RIGHT
		boot._input(key)
		if LabController.comparable(boot.session.state()) != before: failures.append("observation prevents keyboard actions")
		boot.world_view.set_meta("observe_toggle", false)
		root.get_node("Save").data["rule_cards_seen"] = []
		boot.lab.group_index = 0
		boot.lab.level_index = 5
		boot.start_level()
		for expected_uid: String in ["mechanic:dig", "mechanic:pour", "mechanic:plate_door"]:
			if boot.current_screen != "rulecard" or boot.rule_uid != expected_uid: failures.append("jumping to M06 explains each unlearned prerequisite: " + expected_uid)
			boot.activate_menu(0)
		if boot.current_screen != "play": failures.append("closing prerequisite cards resumes the actual level")
		boot.start_level()
		if boot.current_screen != "play": failures.append("already seen prerequisite cards do not repeat")
		boot.dispose()
	print(JSON.stringify({"suite":"ui","ok":failures.is_empty(),"failures":failures}))
	quit(0 if failures.is_empty() else 1)
