extends SceneTree
## Requires a real rendering driver (do not use --headless). Compares all pixels
## of six terrain patterns to the frozen workbench, including exposed corners.
var failures: Array[String] = []

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var renderer_path: String = "res://presentation/render/terrain/terrain_material.gd"
	if not FileAccess.file_exists(renderer_path):
		push_error("Missing renderer: " + renderer_path)
		quit(1)
		return
	if DisplayServer.get_name() == "headless":
		push_error("GPU reference test needs a rendering driver; headless results are not GPU validation")
		quit(1)
		return
	var factory: GDScript = load(renderer_path)
	var raster_script: GDScript = load("res://presentation/render/palette_raster.gd")
	var refs: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://tests/refs/workbench.reference.json"))
	for item: Dictionary in refs.cases:
		var viewport: SubViewport = SubViewport.new()
		viewport.size = Vector2i(128, 80)
		viewport.transparent_bg = true
		viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
		viewport.canvas_item_default_texture_filter = Viewport.DEFAULT_CANVAS_ITEM_TEXTURE_FILTER_NEAREST
		root.add_child(viewport)
		var materials: Image = Image.create(8, 5, false, Image.FORMAT_R8)
		for y: int in range(5):
			for x: int in range(8):
				materials.set_pixel(x, y, Color(float(item.materials[y].substr(x, 1).to_int()) / 255.0, 0, 0, 1))
		var rect: ColorRect = ColorRect.new()
		rect.size = Vector2(128, 80)
		var shader_material: ShaderMaterial = factory.create(root.get_node("Registry").art(item.theme).params)
		shader_material.set_shader_parameter("map_texture", ImageTexture.create_from_image(materials))
		shader_material.set_shader_parameter("grid_size", Vector2i(8, 5))
		shader_material.set_shader_parameter("visual_tick", int(item.tick) >> 3)
		rect.material = shader_material
		viewport.add_child(rect)
		await process_frame
		await RenderingServer.frame_post_draw
		var result: Image = viewport.get_texture().get_image()
		var different: int = 0
		for y: int in range(80):
			for x: int in range(128):
				var code: String = item.terrain[y].substr(x, 1)
				var expected: Color = raster_script.color_of(code)
				var actual: Color = result.get_pixel(x, y)
				if actual.to_rgba32() != expected.to_rgba32():
					different += 1
		if different > 0:
			failures.append("%s tick=%d: %d / 10240 terrain pixels differ" % [item.theme, item.tick, different])
		viewport.queue_free()
	for failure: String in failures:
		push_error(failure)
	print("terrain GPU reference failures: ", failures.size())
	quit(0 if failures.is_empty() else 1)
