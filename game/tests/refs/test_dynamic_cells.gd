extends SceneTree
## Real M04 POUR_R capture: verifies nonempty SDK sand, its legal palette and
## the exact colour variant read from RGBA SDK render textures. Also records
## combined SDK(4 ticks)+WorldView main-thread time; does not assert a budget.
const Session = preload("res://gameplay/session/level_session.gd")
const View = preload("res://presentation/render/world_view.gd")
const Palette = preload("res://presentation/render/palette_raster.gd")
const Sprites = preload("res://presentation/render/sprites/sprite_assets.gd")

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	if DisplayServer.get_name() == "headless":
		push_error("Dynamic cell rendering requires a rendering driver")
		quit(1)
		return
	var registry: Node = root.get_node("Registry")
	var session: RefCounted = Session.new()
	if not session.setup(registry.level_spec("level:M04")):
		push_error(session.last_error)
		quit(1)
		return
	for action: String in ["R", "R"]:
		var move_result: Dictionary = session.perform(action)
		if not move_result.get("accepted", false):
			push_error("M04 setup move failed: " + action)
			session.dispose()
			quit(1)
			return
	var viewport: SubViewport = SubViewport.new()
	viewport.size = Vector2i(320, 180)
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	viewport.canvas_item_default_texture_filter = Viewport.DEFAULT_CANVAS_ITEM_TEXTURE_FILTER_NEAREST
	root.add_child(viewport)
	var view: Node2D = View.new()
	view.fixed_tick = 0
	viewport.add_child(view)
	view.set_session(session)
	var begin: Dictionary = session.begin_action("POUR_R")
	if not begin.get("accepted", false):
		push_error("M04 pour rejected")
		session.dispose()
		quit(1)
		return
	var measured_frames: int = 0
	var peak_combined_us: int = 0
	var peak_render_us: int = 0
	var peak_render_stages: Dictionary = {}
	while session.busy:
		var start: int = Time.get_ticks_usec()
		var step: Dictionary = session.advance_settle(4)
		view.fixed_tick += 1
		view.refresh()
		peak_combined_us = maxi(peak_combined_us, Time.get_ticks_usec() - start)
		peak_render_us = maxi(peak_render_us, view.last_refresh_us)
		for stage: String in view.last_refresh_stages:
			peak_render_stages[stage] = maxi(int(peak_render_stages.get(stage, 0)), int(view.last_refresh_stages[stage]))
		measured_frames += 1
		if not str(step.get("error", "")).is_empty():
			push_error(step.error)
			session.dispose()
			quit(1)
			return
		await process_frame
		await RenderingServer.frame_post_draw
	view.environment_mode = "off"
	view.fixed_tick = 0
	view.refresh()
	await process_frame
	await RenderingServer.frame_post_draw
	var image: Image = viewport.get_texture().get_image()
	var width: int = session.width * 16
	var height: int = session.height * 16
	var origin: Vector2i = Vector2i((320 - width) >> 1, 20 + ((160 - height) >> 1))
	var ids: PackedInt32Array = session.world.get_material_ids(0, 0, width, height)
	var sand_id: int = session.world.material_ids.sand
	var theme: Dictionary = registry.art("art:theme.dungeon").params
	var allowed: Array[int] = []
	for code: String in theme.sand.base + [theme.sand.grain, theme.sand.top]:
		allowed.append(Palette.color_of(code).to_rgba32())
	var raw_tiles: Array[Dictionary] = []
	for tile: Dictionary in session.world.get_render_tiles():
		raw_tiles.append({"rect": tile.rect, "image": tile.texture.get_image()})
	var actual_cells: int = 0
	var covered_cells: int = 0
	var palette_errors: int = 0
	var variant_errors: int = 0
	var observed: Dictionary = {}
	var sprite_mask: RefCounted = Palette.new(320, 180)
	var player: Dictionary = session.state().player
	Sprites.blit(sprite_mask, "art:char.portitor", "idle", 0, origin + Vector2i(int(player.x) * 16 + 8, int(player.y) * 16 + 16))
	for y: int in range(height):
		for x: int in range(width):
			if int(ids[y * width + x]) != sand_id:
				continue
			actual_cells += 1
			if sprite_mask.get_code(origin.x + x, origin.y + y) != ".":
				covered_cells += 1
				continue
			var pixel: int = image.get_pixel(origin.x + x, origin.y + y).to_rgba32()
			observed[str(pixel)] = true
			if not allowed.has(pixel):
				palette_errors += 1
			var variant: int = 0
			for tile: Dictionary in raw_tiles:
				if tile.rect.has_point(Vector2i(x, y)):
					var raw: Color = tile.image.get_pixel(x - int(tile.rect.position.x), y - int(tile.rect.position.y))
					variant = (raw.g8 >> 4) & 3
					break
			var expected: String = theme.sand.base[variant % 3]
			if y == 0 or int(ids[(y - 1) * width + x]) != sand_id:
				expected = theme.sand.top
			if pixel != Palette.color_of(expected).to_rgba32():
				variant_errors += 1
	var passed: bool = actual_cells > covered_cells and palette_errors == 0 and variant_errors == 0 and not raw_tiles.is_empty()
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://reports/shots"))
	image.save_png("res://reports/shots/dynamic-M04.png")
	var report: Dictionary = {"format": "portitor.dynamic-render/1", "level": "level:M04", "actions": ["R", "R", "POUR_R"], "actual_sdk_sand_cells": actual_cells, "approved_player_pixels_covering_sand": covered_cells, "palette_errors": palette_errors, "variant_errors": variant_errors, "observed_rgba": observed.keys(), "sdk_tiles": raw_tiles.size(), "passed": passed, "measured_settle_frames": measured_frames, "peak_combined_main_thread_us": peak_combined_us, "peak_world_view_us": peak_render_us, "timing_includes": "SDK advance(4) + WorldView CPU composition/upload; default full environment; GPU wait excluded", "capture": "res://reports/shots/dynamic-M04.png"}
	report.peak_render_stage_us = peak_render_stages
	var output: FileAccess = FileAccess.open("res://reports/dynamic-render-report.json", FileAccess.WRITE)
	output.store_string(JSON.stringify(report, "  "))
	print(JSON.stringify(report))
	viewport.queue_free()
	await process_frame
	session.dispose()
	quit(0 if passed else 1)
