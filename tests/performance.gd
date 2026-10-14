extends SceneTree
const Game := preload("res://pushbox/scripts/game.gd")
var frames: Array[int] = []
var previews: Array[int] = []
var preview_latency: Array[int] = []
var failures: int = 0
var rows: Array = []
var frame_samples: Array[int] = []

func statistics(values: Array[int]) -> Dictionary:
	var ordered: Array[int] = values.duplicate()
	ordered.sort()
	if ordered.is_empty():
		return {"samples": 0, "max_us": 0}
	return {"samples": ordered.size(), "min_us": ordered[0], "p50_us": ordered[ordered.size() / 2], "p95_us": ordered[mini(ordered.size()-1, ceili(ordered.size()*0.95)-1)], "max_us": ordered[-1]}

func _initialize() -> void:
	call_deferred("run")

func rendered_frame() -> void:
	await process_frame
	if DisplayServer.get_name() != "headless":
		await RenderingServer.frame_post_draw

func idle(game: Node) -> void:
	var last: int = game.frame_us.size()
	while game.session.running or game.animation_left > 0 or game._opening:
		await rendered_frame()
		if game.frame_us.size() > last:
			var upload: int = game.session.world.get_stats().upload_us
			var overlay: int = game.view.draw_us if game.view.draw_frame == Engine.get_process_frames() else 0
			var complete: int = game.frame_us[-1] + upload + overlay
			frame_samples.append(complete)
			if complete > 4000:
				print("T8 slow frame room=%d move=%d time_us=%d phases=%s" % [game.level_index+1, game.session.board.moves, complete, JSON.stringify(game.frame_timing)])
			last = game.frame_us.size()

func run() -> void:
	var game := Game.new()
	root.add_child(game)
	for room in 5:
		var load_begin: int = Time.get_ticks_usec()
		game.select_level(room)
		var load_us: int = Time.get_ticks_usec() - load_begin
		game.frame_us.clear()
		frame_samples.clear()
		await idle(game)
		var local_previews: Array[int] = []
		var local_latency: Array[int] = []
		for action in game.session.level.solution:
			var predicted: Dictionary = {}
			if action.contains("_"):
				game.cancel_preview()
				game._dragging = action.begins_with("BOMB")
				game._pointer = game.view.to_global(Vector2(game.session.board.player + game.session.board._direction(action)) * 16 + Vector2(8,8))
				var began: int = Time.get_ticks_usec()
				for _i in 120:
					await rendered_frame()
					if not game.preview_result.is_empty():
						break
				if game.preview_result.is_empty():
					failures += 1
					print("FAIL preview did not complete " + action)
				else:
					predicted = game.preview_result.duplicate(true)
					local_previews.append(game.preview.last_us)
					previews.append(game.preview.last_us)
					var latency: int = Time.get_ticks_usec() - began
					local_latency.append(latency)
					preview_latency.append(latency)
					print("T8 preview room=%d action=%s cpu_us=%d latency_us=%d" % [room+1, action, game.preview.last_us, latency])
					print("T8 preview phases=%s slices=%s" % [JSON.stringify(game.preview.phase_us), JSON.stringify(game.preview.frame_slices_us)])
				game._dragging = false
			game.request_action(action)
			game._pointer = Vector2(-100,-100)
			await idle(game)
			if not predicted.is_empty() and predicted.hash != game.session.world.get_state_hash():
				failures += 1
				print("FAIL rendered hover T6 " + action)
		frames.append_array(frame_samples)
		if not game.session.board.won() or not game.session.errors.is_empty():
			failures += 1
		rows.append({"level":room+1, "load_us":load_us, "frames":statistics(frame_samples), "preview_cpu":statistics(local_previews), "preview_latency":statistics(local_latency)})
		print("T8 D%d %s" % [room+1, JSON.stringify(rows[-1])])
	var summary: Dictionary = {"display":DisplayServer.get_name(), "workers":1, "frames":statistics(frames), "preview_cpu":statistics(previews), "preview_latency":statistics(preview_latency), "rooms":rows, "scope":"Settlement CPU: Game physics + SDK upload + BoardView draw, max 4 real-world ticks per frame (opening 1), 1.5ms soft SDK-step budget, separate material-read/32-tile-count (1ms soft budget)/one-mechanism/actor/gate resolution slices and 64-tile key-category frames; previews drain the same phases in a 3.5ms soft work budget. Preview CPU includes snapshot I/O and result diff; latency measured from pointer target to completed rendered overlay, with vsync. Load/shader initialization reported separately. GPU raster and OS compositor excluded from CPU frame metric."}
	DirAccess.make_dir_recursive_absolute("res://artifacts/v03/logs")
	var file := FileAccess.open("res://artifacts/v03/logs/performance-%s.json" % DisplayServer.get_name(), FileAccess.WRITE)
	file.store_string(JSON.stringify(summary, "  ") + "\n")
	if summary.frames.max_us > 4000 or summary.preview_cpu.max_us > 100000 or summary.preview_latency.max_us > 100000:
		failures += 1
	print("T8 summary " + JSON.stringify(summary))
	game.free()
	print("Performance: %d failures" % failures)
	quit(1 if failures else 0)
