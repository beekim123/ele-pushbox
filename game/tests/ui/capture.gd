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
	_check_lobby_hash()
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
	save.data["last_level_uid"] = "level:M05"
	save.data["coins"] = 1280
	var frame_peak: float = 0
	for language: String in ["zh-Hans", "en"]:
		print("capture language: " + language)
		locale.set_language(language)
		app.lab.level_index = 4 # Reference overlay fixture M05.
		app.start_level()
		print("capture level ready: " + language)
		app.world_view.fixed_tick = 0
		for name: String in ["lobby", "chapters", "levels", "pause", "settings", "hint", "complete", "rulecard", "dialogue"]:
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
			_record_capture(app, image, name + "." + language, name, language)
			if name == "chapters": app.lab = runtime_lab
			frame_peak = maxf(frame_peak, Performance.get_monitor(Performance.TIME_PROCESS) * 1000)
	# Six chapter appearances, using only an in-memory presentation fixture.
	# No select_group/save call and no mutation of the catalog or SDK state.
	var lobby_lab: RefCounted = app.lab
	var lobby_save: Dictionary = save.data.duplicate(true)
	var skin_fixture := ChapterAvailabilityFixture.new()
	var themes: Array[String] = ["dungeon", "ruins", "cave", "forest", "sky", "cosmos"]
	for index: int in themes.size():
		var group: Dictionary = lobby_lab.groups[0].duplicate(true)
		group["theme"] = "theme." + themes[index]
		group["order"] = index + 1
		skin_fixture.groups.append(group)
	app.lab = skin_fixture
	locale.set_language("zh-Hans")
	for index: int in themes.size():
		skin_fixture.group_index = index
		app.show_screen("lobby")
		for frame: int in 3: await process_frame
		RenderingServer.force_draw(false)
		var image: Image = root.get_texture().get_image()
		_record_capture(app, image, "lobby." + themes[index], "lobby", themes[index])
		var selected_theme: String = str(app.screen.get_meta("lobby_theme", ""))
		var expected_skin: String = ["S2","S3","S1","S5","S4","S6"][index]
		var selected_skin: String = str(app.screen.get_meta("lobby_skin", ""))
		behaviors.append({"id":"ui.lobby_chapter_skin." + themes[index], "ok":selected_theme == themes[index] and selected_skin == expected_skin, "actual_theme":selected_theme, "actual_skin":selected_skin})
		if selected_theme != themes[index] or selected_skin != expected_skin: issues.append("lobby must follow current chapter: " + themes[index])
		app.screen.move_focus(1)
		for frame: int in 2: await process_frame
		var menu_focus_ok: bool = app.screen.focus_index == 1 and app.screen.buttons[1].has_focus()
		behaviors.append({"id":"ui.lobby_keyboard_focus." + themes[index], "ok":menu_focus_ok})
		if not menu_focus_ok: issues.append("lobby keyboard focus failed: " + themes[index])
	app.lab = lobby_lab
	var save_unchanged: bool = save.data == lobby_save
	behaviors.append({"id":"ui.lobby_fixture_preserves_save", "ok":save_unchanged})
	if not save_unchanged: issues.append("lobby captures changed save data")
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

func _record_capture(app: Node, image: Image, capture_name: String, name: String, language: String) -> void:
	var output: String = "res://reports/shots/" + capture_name + ".png"
	image.save_png(output)
	var expected_path: String = ProjectSettings.globalize_path("res://../art/export/reference/" + capture_name + ".png")
	var expected: Image = Image.load_from_file(expected_path)
	var different: int = 0
	var color_differences: Dictionary = {}
	var region_differences: Dictionary = {"hud":0,"body":0,"footer":0}
	var lobby_regions: Dictionary = {"title":0,"chapter":0,"menu":0,"backdrop":0,"keys":0,"floor":0}
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
					if name == "lobby":
						var part: String = "floor" if y>=156 and x>=160 else "keys" if y>=160 else "backdrop" if x>=190 else "title" if y<59 else "chapter" if y<84 else "menu"
						lobby_regions[part] += 1
	if name in ["chapters", "levels", "settings", "pause", "hint", "rulecard", "dialogue", "complete", "lobby"] and different > 1700:
		reference_issues.append("UI reference differs by more than 1700 pixels: %s.%s = %d" % [name, language, different])
	issues.append_array(app.layout_issues())
	var reference: Dictionary = {"name":capture_name,"diff_pixels":different,"pixels":57600,"screenshot":"game/reports/shots/" + capture_name + ".png","approved":false,"note":"Development Control layout; pending UI/bubble approvals. Geometry and glyph differences are unresolved, not waived."}
	if name in ["chapters", "levels", "settings", "pause", "hint", "rulecard", "dialogue", "complete", "lobby"]:
		reference["diff_by_region"] = region_differences
		var pairs: Array = color_differences.keys()
		pairs.sort_custom(func(a: String, b: String) -> bool: return int(color_differences[a]) > int(color_differences[b]))
		reference["largest_color_differences"] = pairs.slice(0, 8).map(func(pair: String) -> Dictionary: return {"colors":pair,"pixels":color_differences[pair]})
		reference["note"] = "Lobby artwork APR-0008; live chapter skin, 1700-pixel acceptance threshold. Runtime UI approval is not inferred from artwork approval." if name == "lobby" else "G2 artwork APR-0007; live localized Controls, 1700-pixel acceptance threshold. Runtime UI approval is not inferred from artwork approval."
	if name == "chapters":
		var counts: Dictionary = {}
		for group: Dictionary in app.lab.groups:
			counts[str(group.id)] = group.get("levels", []).size()
		reference["ui_fixture"] = {"kind":"presentation_only_availability", "available_group_indices":[0,1], "sample_level_counts":counts, "sdk_unlocked":false}
		reference["note"] += " Chapter availability is a UI-only reference fixture; the second chapter uses the reference sample of seven levels; no SDK unlock is claimed."
	if name == "lobby": reference["diff_by_lobby_region"] = lobby_regions
	if name == "dialogue": reference["ui_fixture"] = {"kind":"dialogue_component_over_live_M05", "boot_router_integration":false}
	references.append(reference)

func _check_lobby_hash() -> void:
	# Expected values generated in Node from ui-kit.js:24-30 (Hh/BigInt).
	# Includes UI coordinates, signed inputs and both int64 limits.
	var cases: Array = [
		[0, 0, 0, 0],
		[1, 0, 0, 694],
		[0, 1, 0, 352],
		[0, 0, 1, 453],
		[13, 9, 4, 196],
		[14, 64, 8, 703],
		[320, 180, 50, 652],
		[1199, 172, 50, 587],
		[-40, -20, 0, 78],
		[-3, -1, 51, 677],
		[34, 18, -2, 4],
		[71, 37, 53, 66],
		[108, 56, -4, 978],
		[145, 75, 55, 423],
		[182, 94, -6, 707],
		[219, 113, 57, 911],
		[256, 132, -8, 409],
		[293, 151, 59, 506],
		[330, 170, -10, 121],
		[-34, 189, 61, 860],
		[3, -3, -12, 118],
		[40, 16, 63, 18],
		[77, 35, -14, 707],
		[114, 54, 65, 520],
		[151, 73, -16, 752],
		[188, 92, 67, 868],
		[225, 111, -18, 87],
		[262, 130, 69, 48],
		[299, 149, -20, 562],
		[336, 168, 71, 919],
		[-28, 187, -22, 752],
		[9, -5, 73, 184],
		[46, 14, -24, 557],
		[83, 33, 75, 976],
		[120, 52, -26, 389],
		[157, 71, 77, 199],
		[194, 90, -28, 461],
		[231, 109, 79, 283],
		[268, 128, -30, 120],
		[305, 147, 81, 277],
		[342, 166, -32, 194],
		[-22, 185, 83, 399],
		[15, -7, -34, 214],
		[52, 12, 85, 774],
		[89, 31, -36, 178],
		[126, 50, 87, 892],
		[163, 69, -38, 594],
		[200, 88, 89, 805],
		[2147483647, 0, 0, 961],
		[0, 2147483647, 0, 171],
		[0, 0, 2147483647, 258],
		[2147483647, -1, 2147483647, 29],
		[-2147483648, 0, 0, 636],
		[0, -2147483648, 0, 284],
		[0, 0, -2147483648, 620],
		[-2147483648, -1, -2147483648, 207],
		[9223372036854775807, 0, 0, 357],
		[0, 9223372036854775807, 0, 271],
		[0, 0, 9223372036854775807, 430],
		[9223372036854775807, -1, 9223372036854775807, 597],
		[-9223372036854775808, 0, 0, 256],
		[0, -9223372036854775808, 0, 64],
		[0, 0, -9223372036854775808, 520],
		[-9223372036854775808, -1, -9223372036854775808, 679],
	]
	var skin: Control = load("res://presentation/ui/widgets/lobby_skins.gd").new()
	var mismatches: Array[String] = []
	for sample: Array in cases:
		var actual: int = skin._hash(sample[0], sample[1], sample[2])
		if actual != sample[3]:
			mismatches.append("Hh(%s, %s, %s): expected %s, got %s" % [sample[0], sample[1], sample[2], sample[3], actual])
	skin.free()
	behaviors.append({"id":"ui.lobby_hash_matches_bigint", "ok":mismatches.is_empty(), "cases":cases.size(), "mismatches":mismatches})
	if not mismatches.is_empty(): issues.append("lobby hash differs from Hh: %s/%s cases" % [mismatches.size(), cases.size()])
	print(JSON.stringify({"suite":"ui-lobby-hash", "cases":cases.size(), "failures":mismatches}))
