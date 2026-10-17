extends SceneTree
## Real GPU captures, compared with exported references. Differences are data.
var references: Array[Dictionary] = []
var issues: Array = []
var reference_issues: Array[String] = []
var behaviors: Array[Dictionary] = []

class ChapterAvailabilityFixture extends "res://modes/lab/controller.gd":
	## Reference art shows the first two cards unlocked. This presentation-only
	## controller is never used to enter a level or to alter SDK verification.
	func available(index: int) -> bool:
		return index >= 0 and index < groups.size() and index < 2

func _initialize() -> void:
	create_timer(90.0).timeout.connect(func() -> void: printerr("FAIL: capture timeout"); quit(1))
	call_deferred("_run")

func _run() -> void:
	if DisplayServer.get_name() == "headless":
		push_error("UI capture requires an actual rendering driver")
		quit(1)
		return
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://reports/shots"))
	root.size = Vector2i(320, 180)
	root.get_node("Settings").values["window_scale"] = 1
	var app: Node = load("res://app/boot.tscn").instantiate()
	root.add_child(app)
	app.set_process(false)
	var locale: Node = root.get_node("Locale")
	var settings: Node = root.get_node("Settings")
	# Cosmetic UI sample from ui.screen.levels; this is isolated test progress,
	# not an SDK completion claim and never written into the player's save.
	var save: Node = root.get_node("Save")
	save.data["progress"] = {}
	for uid: String in ["level:M01", "level:M02", "level:M04", "level:M06"]:
		save.data.progress[uid] = {"cleared":true,"skipped":false,"moves":4}
	save.data.progress["level:M03"] = {"cleared":false,"skipped":true,"moves":0}
	save.data["rule_cards_seen"] = ["mechanic:push", "mechanic:ladder", "mechanic:dig", "mechanic:pour", "mechanic:plate_door", "mechanic:fall"]
	settings.values["window_scale"] = "auto"
	settings.values["show_grid"] = false
	settings.values["open_all_levels"] = false
	settings.values["music"] = 0.8
	settings.values["sfx"] = 0.8
	settings.values["ambience"] = "full"
	settings.values["typewriter"] = false
	var frame_peak: float = 0
	for language: String in ["zh-Hans", "en"]:
		print("capture language: " + language)
		locale.set_language(language)
		app.lab.level_index = 4 # Reference overlay fixture M05.
		app.start_level()
		print("capture level ready: " + language)
		app.world_view.fixed_tick = 0
		for name: String in ["chapters", "levels", "pause", "settings", "hint", "complete", "rulecard", "dialogue"]:
			print("capture: " + name + "." + language)
			var runtime_lab: RefCounted = app.lab
			if name == "chapters":
				var fixture := ChapterAvailabilityFixture.new()
				fixture.groups = runtime_lab.groups.duplicate(true)
				fixture.groups[1]["levels"] = fixture.groups[1].get("levels", []).slice(0, 7)
				fixture.group_index = 1
				fixture.level_index = runtime_lab.level_index
				app.lab = fixture
			else:
				app.lab.group_index = 0
			if name in ["pause", "hint", "complete", "dialogue"]:
				app.lab.level_index = 4
				app.start_level()
			if name == "hint": app.hint_level = 3
			if name == "complete":
				for action: String in app.session.spec.solution:
					app.session.perform(action)
				app.world_view.pose = "win"
			if name == "rulecard": app.lab.level_index = 2; app.start_level(); app.rule_uid = "mechanic:dig"
			if name == "dialogue":
				# The boot router currently treats dialogue as a standalone page,
				# disposing the SDK session. Capture this overlay component over
				# the same live M05 fixture instead, without changing boot/gameplay.
				app.show_screen("hint")
				var parent: Node = app.screen.get_parent()
				parent.remove_child(app.screen)
				app.screen.queue_free()
				var overlay: Variant = load("res://presentation/ui/screens/screen.gd").new()
				overlay.screen_name = "dialogue"
				app.screen = overlay
				parent.add_child(overlay)
				overlay.configure(app)
			else:
				app.show_screen(name)
			if name == "settings": app.screen.set_focus(1)
			# Three frames settle the nested UPDATE_ONCE preview viewports.
			# Read after a completed GPU draw, without awaiting a freed screen.
			for frame: int in 3: await process_frame
			RenderingServer.force_draw(false)
			var image: Image = root.get_texture().get_image()
			if name == "hint":
				var ink_pixels: int = 0
				for child: Node in app.screen.get_children():
					if child is PortitorBubble:
						var area: Rect2i = Rect2i(child.box).grow(-3)
						for y: int in range(area.position.y, area.end.y):
							for x: int in range(area.position.x, area.end.x):
								if image.get_pixel(x, y).to_rgba32() == Color("ffffff").to_rgba32(): ink_pixels += 1
				behaviors.append({"id":"ui.hint_body_visible." + language,"ok":ink_pixels > 0,"actual_ink_pixels":ink_pixels})
				if ink_pixels == 0: issues.append("hint text must render in front of placeholder background: " + language)
			var output: String = "res://reports/shots/" + name + "." + language + ".png"
			image.save_png(output)
			var expected_path: String = ProjectSettings.globalize_path("res://../art/export/reference/" + name + "." + language + ".png")
			var expected: Image = Image.load_from_file(expected_path)
			var different: int = 0
			var color_differences: Dictionary = {}
			var region_differences: Dictionary = {"hud":0,"body":0,"footer":0}
			if expected == null or expected.get_size() != image.get_size():
				different = 320 * 180
			else:
				for y: int in range(180):
					for x: int in range(320):
						if image.get_pixel(x, y).to_rgba32() != expected.get_pixel(x, y).to_rgba32():
							different += 1
							var pair: String = expected.get_pixel(x, y).to_html() + " -> " + image.get_pixel(x, y).to_html()
							color_differences[pair] = int(color_differences.get(pair, 0)) + 1
							var region: String = "hud" if y < 24 else "footer" if y >= 161 else "body"
							region_differences[region] += 1
			if name in ["chapters", "levels", "settings", "pause", "hint", "rulecard", "dialogue", "complete"] and different > 1700:
				reference_issues.append("G2 reference differs by more than 1700 pixels: %s.%s = %d" % [name, language, different])
			issues.append_array(app.layout_issues())
			var reference: Dictionary = {"name":name + "." + language,"diff_pixels":different,"pixels":57600,"screenshot":"game/reports/shots/" + name + "." + language + ".png","approved":false,"note":"Development Control layout; pending UI/bubble approvals. Geometry and glyph differences are unresolved, not waived."}
			if name in ["chapters", "levels", "settings", "pause", "hint", "rulecard", "dialogue", "complete"]:
				reference["diff_by_region"] = region_differences
				var pairs: Array = color_differences.keys()
				pairs.sort_custom(func(a: String, b: String) -> bool: return int(color_differences[a]) > int(color_differences[b]))
				reference["largest_color_differences"] = pairs.slice(0, 8).map(func(pair: String) -> Dictionary: return {"colors":pair,"pixels":color_differences[pair]})
				reference["note"] = "G2 artwork APR-0007; live localized Controls, 1700-pixel acceptance threshold. Runtime UI approval is not inferred from artwork approval."
			if name == "chapters":
				var counts: Dictionary = {}
				for group: Dictionary in app.lab.groups:
					counts[str(group.id)] = group.get("levels", []).size()
				reference["ui_fixture"] = {"kind":"presentation_only_availability", "available_group_indices":[0,1], "sample_level_counts":counts, "sdk_unlocked":false}
				reference["note"] += " Chapter availability is a UI-only reference fixture; the second chapter uses the reference sample of seven levels; no SDK unlock is claimed."
				app.lab = runtime_lab
			if name == "dialogue": reference["ui_fixture"] = {"kind":"dialogue_component_over_live_M05", "boot_router_integration":false}
			references.append(reference)
			frame_peak = maxf(frame_peak, Performance.get_monitor(Performance.TIME_PROCESS) * 1000)
	app.lab.level_index = 0
	app.start_level()
	app.world_view.fixed_tick = 0
	app.set_process(true)
	app.perform("L")
	while app.get("_busy"): await process_frame
	await process_frame
	RenderingServer.force_draw(false)
	var before_feedback: PackedByteArray = root.get_texture().get_image().get_data()
	var before_moves: int = int(app.session.state().moves)
	var before_hash: String = app.session.world.get_state_hash()
	app.perform("L") # Bedrock blocks this action.
	await process_frame
	RenderingServer.force_draw(false)
	var visual_changed: bool = root.get_texture().get_image().get_data() != before_feedback
	var unchanged: bool = int(app.session.state().moves) == before_moves and app.session.world.get_state_hash() == before_hash
	behaviors.append({"id":"ui.blocked_feedback_and_no_move","ok":visual_changed and unchanged,"pixels_changed":visual_changed,"moves_and_sdk_unchanged":unchanged})
	if not visual_changed or not unchanged: issues.append("blocked action must show feedback without changing moves or SDK")
	app.lab.level_index = 3
	app.start_level()
	app.set_process(true)
	app.perform("R")
	while app.get("_busy"): await process_frame
	app.perform("R")
	while app.get("_busy"): await process_frame
	app.perform("POUR_R")
	while app.get("_busy"): await process_frame
	app.undo()
	var metrics: Dictionary = {"settle_advance_peak_us":app.settle_peak_us,"undo_peak_us":app.undo_peak_us,"process_frame_peak_ms":frame_peak,"memory_static_peak_bytes":Performance.get_monitor(Performance.MEMORY_STATIC_MAX),"fps_observed":Engine.get_frames_per_second(),"full_performance_acceptance":false,"note":"Short capture run only; includes Control/layout construction. A sustained all-level benchmark is still required."}
	var report: Dictionary = {"references":references,"layout_issues":issues,"reference_issues":reference_issues,"behaviors":behaviors,"performance":metrics}
	var file := FileAccess.open("res://reports/ui-reference-report.json", FileAccess.WRITE)
	file.store_string(JSON.stringify(report, "  "))
	file.close()
	print(JSON.stringify({"suite":"ui-gpu","captures":references.size(),"layout_issues":issues.size(),"reference_issues":reference_issues.size(),"different_reference_count":references.filter(func(item: Dictionary) -> bool: return item.diff_pixels > 0).size(),"performance":metrics}))
	app.dispose()
	quit(0 if issues.is_empty() and reference_issues.is_empty() else 1)
