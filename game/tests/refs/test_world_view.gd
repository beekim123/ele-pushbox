extends SceneTree
## Windowed, serial real-SDK captures of M01-M07. Excludes HUD (owned by UI).
## Sand cells are reported separately because their SDK variant travels with
## each cell; a design-model arrangement is never presented as SDK validation.
const Session = preload("res://gameplay/session/level_session.gd")
const View = preload("res://presentation/render/world_view.gd")
const Palette = preload("res://presentation/render/palette_raster.gd")
var failures: int = 0
var cases: Array[Dictionary] = []

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	if DisplayServer.get_name() == "headless":
		push_error("World reference screenshots require a real rendering driver")
		quit(1)
		return
	var registry: Node = root.get_node("Registry")
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://reports/shots"))
	for number: int in range(1, 8):
		var code: String = "M%02d" % number
		var spec: Dictionary = registry.level_spec("level:" + code)
		var session: RefCounted = Session.new()
		if not session.setup(spec):
			cases.append({"level": code, "error": session.last_error, "passed": false})
			failures += 1
			session.dispose()
			continue
		var viewport: SubViewport = SubViewport.new()
		viewport.size = Vector2i(320, 180)
		viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
		viewport.canvas_item_default_texture_filter = Viewport.DEFAULT_CANVAS_ITEM_TEXTURE_FILTER_NEAREST
		root.add_child(viewport)
		var view: Node2D = View.new()
		view.environment_mode = "off"
		view.fixed_tick = 0
		viewport.add_child(view)
		view.set_session(session)
		await process_frame
		await RenderingServer.frame_post_draw
		var actual: Image = viewport.get_texture().get_image()
		var expected: Image = Image.new()
		var reference_path: String = ProjectSettings.globalize_path("res://").path_join("../art/export/reference/level.%s.png" % code).simplify_path()
		var load_error: Error = expected.load(reference_path)
		var mismatches: int = 0
		var masked_dynamic: int = 0
		var dynamic_palette_invalid: int = 0
		var first: Array[int] = []
		var state: Dictionary = session.state()
		var width: int = state.w
		var height: int = state.h
		var origin: Vector2i = Vector2i((320 - width * 16) >> 1, 20 + ((160 - height * 16) >> 1))
		var ids: PackedInt32Array = session.world.get_material_ids(0, 0, width * 16, height * 16)
		var sand_id: int = session.world.material_ids.get("sand", -1)
		var sand_colors: Array[int] = []
		var theme: Dictionary = registry.art("art:theme.dungeon").params
		for color_code: String in theme.sand.base + [theme.sand.grain, theme.sand.top]:
			sand_colors.append(Palette.color_of(color_code).to_rgba32())
		if load_error == OK:
			for y: int in range(20, 180):
				for x: int in range(320):
					var local: Vector2i = Vector2i(x, y) - origin
					if local.x >= 0 and local.y >= 0 and local.x < width * 16 and local.y < height * 16:
						var tile_index: int = (local.y / 16) * width + local.x / 16
						var id: int = ids[local.y * width * 16 + local.x]
						var actual_color: int = actual.get_pixel(x, y).to_rgba32()
						var expected_color: int = expected.get_pixel(x, y).to_rgba32()
						if id == sand_id:
							if sand_colors.has(actual_color):
								masked_dynamic += 1
								continue
							# An identical approved foreground sprite may cover sand.
							if actual_color != expected_color:
								dynamic_palette_invalid += 1
						elif id == 0 and int(state.terrain[tile_index]) == 4 and sand_colors.has(expected_color):
							# Only actual empty cells can differ in dynamic sand shape.
							# Static terrain and sprite pixels remain strictly compared.
							masked_dynamic += 1
							continue
					if actual.get_pixel(x, y).to_rgba32() != expected.get_pixel(x, y).to_rgba32():
						mismatches += 1
						if first.is_empty():
							first.assign([x, y])
		var passed: bool = load_error == OK and mismatches == 0 and dynamic_palette_invalid == 0
		if not passed:
			failures += 1
		var capture: String = "res://reports/shots/world-%s.png" % code
		actual.save_png(capture)
		cases.append({"level": code, "passed": passed, "reference_error": load_error, "static_pixel_differences": mismatches, "first_difference": first, "sdk_dynamic_pixels_excluded": masked_dynamic, "dynamic_palette_invalid": dynamic_palette_invalid, "capture": capture, "limitation": view.last_limitation})
		print(code, " static pixel differences=", mismatches, " dynamic masked=", masked_dynamic)
		viewport.queue_free()
		await process_frame
		session.dispose()
	var output: FileAccess = FileAccess.open("res://reports/world-reference-report.json", FileAccess.WRITE)
	output.store_string(JSON.stringify({"format": "portitor.world-references/1", "hud": "excluded; separate UI validation", "cases": cases}, "  "))
	print("World reference report: ", ProjectSettings.globalize_path("res://reports/world-reference-report.json"))
	quit(0 if failures == 0 else 1)
