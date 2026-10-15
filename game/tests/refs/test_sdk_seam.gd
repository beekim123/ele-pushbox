extends SceneTree
## Actual SDK texture ABI + x=256 neighbour seam. One SDK world, six themes.
const SdkWorld = preload("res://sim/ele_world.gd")
const Terrain = preload("res://presentation/render/terrain/terrain_material.gd")
const Raster = preload("res://presentation/render/palette_raster.gd")

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	if DisplayServer.get_name() == "headless":
		push_error("SDK seam rendering requires a rendering driver")
		quit(1)
		return
	var refs: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://tests/refs/workbench.reference.json"))
	if not refs.has("seam"):
		push_error("Regenerate workbench references for SDK seam fixture")
		quit(1)
		return
	var world: RefCounted = SdkWorld.new()
	if not world.open(1, true):
		push_error(world.last_error)
		quit(1)
		return
	for y: int in range(5):
		for x: int in range(20):
			var code: String = refs.seam.materials[y].substr(x, 1)
			if code != "0":
				world.paint_rect(x * 16, y * 16, 16, 16, "bedrock" if code == "1" else "packed_earth")
	world.step(1)
	var tiles: Array = world.get_render_tiles()
	var cases: Array[Dictionary] = []
	var failures: int = 0
	if tiles.size() < 2:
		push_error("SDK seam test needs both real render tiles")
		world.dispose()
		quit(1)
		return
	for uid: String in refs.seam.expected:
		var viewport: SubViewport = SubViewport.new()
		viewport.size = Vector2i(320, 80)
		viewport.transparent_bg = true
		viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
		root.add_child(viewport)
		var rect: ColorRect = ColorRect.new()
		rect.size = Vector2(320, 80)
		var material: ShaderMaterial = Terrain.create(root.get_node("Registry").art(uid).params)
		material.set_shader_parameter("sdk_mode", true)
		material.set_shader_parameter("grid_size", Vector2i(20, 5))
		material.set_shader_parameter("rock_id", world.material_ids.bedrock)
		material.set_shader_parameter("earth_id", world.material_ids.packed_earth)
		for tile: Dictionary in tiles:
			var right: bool = int(tile.rect.position.x) >= 256
			material.set_shader_parameter("sdk_right" if right else "sdk_left", tile.texture)
			material.set_shader_parameter("right_origin" if right else "left_origin", tile.rect.position)
		rect.material = material
		viewport.add_child(rect)
		await process_frame
		await RenderingServer.frame_post_draw
		var image: Image = viewport.get_texture().get_image()
		var different: int = 0
		for y: int in range(80):
			for x: int in range(320):
				if image.get_pixel(x, y).to_rgba32() != Raster.color_of(refs.seam.expected[uid][y].substr(x, 1)).to_rgba32():
					different += 1
		if different > 0:
			failures += 1
		cases.append({"theme": uid, "pixel_differences": different, "passed": different == 0, "real_sdk_tiles": tiles.size(), "seam_x": 256})
		print(uid, " SDK seam differences=", different)
		viewport.queue_free()
		await process_frame
	world.dispose()
	var output: FileAccess = FileAccess.open("res://reports/sdk-seam-reference-report.json", FileAccess.WRITE)
	output.store_string(JSON.stringify({"format": "portitor.sdk-seam-references/1", "cases": cases}, "  "))
	quit(0 if failures == 0 else 1)
