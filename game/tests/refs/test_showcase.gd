extends SceneTree
const Illustration = preload("res://tests/refs/illustration_view.gd")
const Raster = preload("res://presentation/render/palette_raster.gd")
var failures: int = 0
var cases: Array[Dictionary] = []

class IllustrationSession extends RefCounted:
	var spec: Dictionary
	var snapshot: Dictionary
	var world: Variant = null
	func state() -> Dictionary:
		return snapshot.duplicate(true)

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	if DisplayServer.get_name() == "headless":
		push_error("Showcase GPU reference test requires a rendering driver")
		quit(1)
		return
	var refs: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://tests/refs/workbench.reference.json"))
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://reports/shots"))
	for item: Dictionary in refs.showcases:
		var viewport: SubViewport = SubViewport.new()
		viewport.size = Vector2i(320, 180)
		viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
		viewport.canvas_item_default_texture_filter = Viewport.DEFAULT_CANVAS_ITEM_TEXTURE_FILTER_NEAREST
		root.add_child(viewport)
		var view: Node2D = Illustration.new()
		view.fixed_tick = 0
		view.ambient_mode = "full"
		viewport.add_child(view)
		var fixture: IllustrationSession = IllustrationSession.new()
		fixture.spec = item.spec.duplicate(true)
		fixture.spec.chapter = str(item.theme).get_slice(".", 1)
		fixture.snapshot = item.state
		view.set_session(fixture)
		view.set_theme_uid(item.theme)
		await process_frame
		await RenderingServer.frame_post_draw
		var image: Image = viewport.get_texture().get_image()
		var differences: int = 0
		var first: Array[int] = []
		for y: int in range(180):
			for x: int in range(320):
				if image.get_pixel(x, y).to_rgba32() != Raster.color_of(item.expected[y].substr(x, 1)).to_rgba32():
					differences += 1
					if first.is_empty():
						first.assign([x, y])
		if differences > 0:
			failures += 1
		var capture: String = "res://reports/shots/showcase-%s.png" % str(item.theme).get_slice(".", 1)
		image.save_png(capture)
		cases.append({"theme": item.theme, "pixel_differences": differences, "first_difference": first, "capture": capture, "passed": differences == 0, "sdk_validation": false, "fixture": "Frozen scene.js SHOWCASE, HUD excluded"})
		print(item.theme, " showcase differences=", differences, " first=", first)
		viewport.queue_free()
		await process_frame
	var output: FileAccess = FileAccess.open("res://reports/showcase-reference-report.json", FileAccess.WRITE)
	output.store_string(JSON.stringify({"format": "portitor.showcase-references/1", "cases": cases}, "  "))
	quit(0 if failures == 0 else 1)
