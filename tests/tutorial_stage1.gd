extends SceneTree
const Session := preload("res://pushbox/scripts/session.gd")
const Preview := preload("res://pushbox/scripts/preview.gd")
const Guide := preload("res://pushbox/scripts/ui/guide.gd")
const Game := preload("res://pushbox/scripts/game.gd")
var checks: int = 0
var failures: int = 0
var evidence: Array = []
var capture_enabled: bool = OS.get_cmdline_user_args().has("--capture-stage1")
var captures: Array = []
var performance_enabled: bool = OS.get_cmdline_user_args().has("--check-performance")
var frame_samples: Array[int] = []
var hover_latency: Array[int] = []

func check(value: bool, message: String) -> void:
	checks += 1
	if not value:
		failures += 1
		print("FAIL " + message)

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	for room in 4:
		var path: String = "res://pushbox/levels/tutorial/t%02d.json" % (room + 1)
		if not FileAccess.file_exists(path):
			check(false, path + " exists")
			continue
		var session := Session.new()
		var reason: String = session.load_level(path, root)
		check(reason.is_empty(), "tutorial validates: " + reason)
		if not reason.is_empty():
			session.dispose()
			continue
		check(session.world.threads == 1, "single worker")
		session.settle_sync()
		session.seal_opening()
		var opening_hash: String = session.world.get_state_hash()
		check(session.level.map.size() == [6,6,8,5][room] and session.level.map[0].length() == [10,10,11,12][room], "specified tutorial dimensions")
		if room == 0:
			check(session.level.solution.size() == 8, "T01 eight-step solution")
			for action in ["R", "U", "U", "D"]:
				check(session.perform(action).legal, "T01 step and up/down ladder")
				session.settle_sync()
			check(session.board.player-session.board.origin == Vector2i(2,2), "D climbs one tile down")
			check(session.restart(), "restore after ladder control probe")
		var preview := Preview.new()
		check(preview.configure(session, root).is_empty(), "preview configured")
		var learned: Dictionary = {}
		var guide := Guide.new()
		root.add_child(guide)
		guide.configure(session.board, session.level, learned)
		check(not guide.active.is_empty(), "opening guide visible")
		if room == 1:
			check(not learned.has("t02:return"), "future guide cannot complete before its after dependency")
		check(session.level.solution_hashes.size() == session.level.solution.size(), "every solution hash recorded")
		check(session.level.solution_keys.size() == session.level.solution.size(), "every position key recorded")
		var rows: Array = []
		for step in session.level.solution.size():
			var action: String = session.level.solution[step]
			var before_hash: String = session.world.get_state_hash()
			var before_state: Dictionary = session.board.state()
			var predicted: Dictionary = preview.predict(session, action)
			check(session.world.get_state_hash() == before_hash and session.board.state() == before_state, "T6 preview does not mutate real state")
			check(session.perform(action, true).legal, "T1 action legal " + action)
			session.settle_sync()
			var after_hash: String = session.world.get_state_hash()
			check(predicted.hash == after_hash and predicted.game_state == session.board.state(), "T6 complete predicted hash/state identical")
			check(predicted.categories == session.board.categories() and predicted.tick == session.world.get_tick(), "T6 categories and stop tick identical")
			if session.level.solution_hashes.size() > step:
				check(after_hash == session.level.solution_hashes[step], "T1 recorded hash")
			if session.level.solution_keys.size() > step:
				check(session.board.position_key() == session.level.solution_keys[step], "T1 recorded key")
			check(session.errors.is_empty() and session.last_rounds <= 16 and session.max_round_ticks <= 1200, "settlement limits")
			if room == 2 and action == "USE":
				check(session.board.boxes[0].at-session.board.origin == Vector2i(6,4), "T03 releasing water floats box one tile below exit")
			if room == 2 and action == "POUR_R":
				check(session.board.boxes[0].at-session.board.origin == Vector2i(6,3), "T03 one bag raises box to exit")
				check(session.board.counts(session.board.origin+Vector2i(4,6)).loose >= 250, "sand reaches deep sump")
				for at in [Vector2i(4,5), Vector2i(5,5), Vector2i(6,5), Vector2i(7,5)]:
					check(session.board.category(session.board.origin+at) == "WATER", "bottom pipe remains four-connected WATER")
			rows.append({"action": action, "hash": after_hash, "player": str(session.board.player-session.board.origin), "actors": session.board.actors_key(), "ticks": session.last_ticks})
			if action.begins_with("DIG"):
				guide.notify("dug")
			elif action.begins_with("POUR"):
				guide.notify("poured")
			elif action == "USE":
				guide.notify("lever_used")
			elif action.begins_with("BOMB"):
				guide.notify("bomb_dragged")
			else:
				guide.notify("moved")
			guide.advance(0.0)
			check(session.undo(), "T5 undo")
			check(session.world.get_state_hash() == before_hash and session.board.state() == before_state, "T5 restores exact state")
			check(session.perform(action, true).legal, "T5 redo action")
			session.settle_sync()
			check(session.world.get_state_hash() == after_hash, "T5 redo identical hash")
		check(session.board.won(), "T1 victory T%02d" % (room+1))
		check(guide.active.is_empty(), "all tutorial guides disappear after completion")
		check(session.restart() and session.world.get_state_hash() == opening_hash, "restart opening state")
		guide.configure(session.board, session.level, learned)
		check(guide.active.is_empty(), "learned guides remain dismissed after restart")
		evidence.append({"level": room+1, "steps": rows})
		guide.free()
		preview.dispose()
		session.dispose()
		print("Tutorial T%02d checked" % (room+1))
	if failures == 0:
		await navigation()
	DirAccess.make_dir_recursive_absolute("res://artifacts/stage1")
	var file := FileAccess.open("res://artifacts/stage1/tutorial-replay.json", FileAccess.WRITE)
	file.store_string(JSON.stringify({"checks": checks, "failures": failures, "workers": 1, "levels": evidence}, "  ") + "\n")
	if capture_enabled:
		var manifest := FileAccess.open("res://artifacts/stage1/captures/manifest.json", FileAccess.WRITE)
		manifest.store_string(JSON.stringify({"display": DisplayServer.get_name(), "screens": captures}, "  ") + "\n")
	print("Tutorial stage1: %d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)

func idle(game: Node) -> void:
	var last: int = game.frame_us.size()
	for _i in 1200:
		if not game.session.running and not game._opening and game.animation_left == 0 and not game._campaign_save_pending:
			return
		await frame()
		if performance_enabled and game.frame_us.size() > last:
			var overlay: int = game.view.draw_us if game.view.draw_frame == Engine.get_process_frames() else 0
			var upload: int = game.session.world.get_stats().upload_us
			var complete: int = game.frame_us[-1] + upload + overlay
			frame_samples.append(complete)
			if complete > 4000:
				print("T8 slow tutorial room=",game.level_index+1," move=",game.session.board.moves," us=",complete," physics_us=",game.frame_us[-1]," upload_us=",upload," draw_us=",overlay," phases=",game.frame_timing)
			last = game.frame_us.size()
	check(false, "game idle within bound")

func navigation() -> void:
	var game := Game.new()
	game.start_in_lobby = true
	game.progress_path = "user://tutorial-stage1-test.json"
	DirAccess.remove_absolute(game.progress_path)
	root.add_child(game)
	game.set_process_input(false)
	game._guide_progress.clear()
	await capture("lobby")
	game.lobby.activate()
	check(game.lobby.page == "tutorial", "lobby tutorial panel")
	await capture("tutorial-select")
	game.lobby.activate()
	check(game.mode == "tutorial" and game.session.level.id == "t01", "panel selects real T01")
	for room in 4:
		await idle(game)
		if capture_enabled:
			while game.view.entrance > 0:
				await process_frame
		await capture("t%02d-opening" % (room+1))
		check(game.level_index == room and game.session.level.id == "t%02d" % (room+1), "same-mode level order")
		game._pointer = Vector2(-100,-100)
		var actions: Array = game.session.level.solution.duplicate()
		for action in actions:
			if performance_enabled:
				print("Tutorial UI begin room=%d move=%d action=%s" % [room+1,game.session.board.moves,action])
			var predicted: Dictionary = {}
			if action.contains("_"):
				var at: Vector2 = game.view.to_global(Vector2(game.session.board.player+game.session.board._direction(action))*16+Vector2(8,8))
				if action.begins_with("BOMB"):
					click(game, game.hud.bomb_rects()[0].get_center(), MOUSE_BUTTON_LEFT, true)
				var event := InputEventMouseMotion.new()
				event.position = at
				var began: int = Time.get_ticks_usec()
				game._input(event)
				for _i in 120:
					await frame()
					if not game.preview_result.is_empty():
						break
				check(not game.preview_result.is_empty(), "real hover overlay completed")
				predicted = game.preview_result.duplicate(true)
				if performance_enabled and not predicted.is_empty():
					hover_latency.append(Time.get_ticks_usec()-began)
					print("Tutorial preview room=%d action=%s cpu_us=%d latency_us=%d phases=%s slices=%s" % [room+1,action,game.preview.last_us,hover_latency[-1],JSON.stringify(game.preview.phase_us),JSON.stringify(game.preview.frame_slices_us)])
				if room == 1 and action == "DIG_L" and game.session.board.moves == 0:
					await capture("t02-hover-dig")
				if room == 3:
					await capture("t04-drag-preview")
				if action.begins_with("BOMB"):
					click(game, at, MOUSE_BUTTON_LEFT, false)
				else:
					click(game, at, MOUSE_BUTTON_LEFT if action.begins_with("DIG") else MOUSE_BUTTON_RIGHT, true)
			else:
				game.request_direction("U" if action == "USE" else action)
			game._pointer = Vector2(-100,-100)
			await idle(game)
			if performance_enabled:
				print("Tutorial UI end room=%d move=%d running=%s" % [room+1,game.session.board.moves,game.session.running])
			if not predicted.is_empty():
				check(predicted.hash == game.session.world.get_state_hash(), "T6 real mouse hover/click hash identical")
			if room == 2 and action in ["USE", "POUR_R"]:
				await capture("t03-water-release" if action == "USE" else "t03-sump-raised")
		check(game.view.winning, "UI victory")
		check(game.lobby.completed_count() == room + 1, "completed progress refreshed once per level")
		game.guide.advance(0.0)
		check(game.guide.active.is_empty(), "UI guides dismissed by real controls")
		game._process(1.6)
	check(game.session == null and game.lobby.visible and game.lobby.page == "modes", "T04 returns to lobby")
	game.lobby.load_progress()
	check(game.lobby.completed_count() == 4, "4/4 persisted")
	await capture("lobby-complete")
	game.select_tutorial(0)
	await idle(game)
	game.pause_menu.toggle()
	await capture("pause-menu")
	game.pause_menu.selected = 4
	game.pause_menu.activate()
	check(game.lobby.visible and game.session == null, "Esc return-to-lobby row")
	if performance_enabled:
		check(not frame_samples.is_empty() and frame_samples.max() <= 4000, "tutorial T8 settlement peak <=4ms")
		check(hover_latency.size() == 5 and hover_latency.max() <= 100000, "tutorial T8 all five rendered previews <=100ms")
		var timing := FileAccess.open("res://artifacts/stage1/tutorial-performance.json", FileAccess.WRITE)
		timing.store_string(JSON.stringify({"display": DisplayServer.get_name(), "workers": 1, "frame_samples": frame_samples.size(), "frame_max_us": frame_samples.max(), "hover_samples": hover_latency.size(), "hover_max_us": hover_latency.max(), "hover_latency_us": hover_latency}, "  ") + "\n")
		print("Tutorial T8 frames=%d peak=%s hover=%s" % [frame_samples.size(),frame_samples.max(),hover_latency.max()])
	game.free()
	DirAccess.remove_absolute("user://tutorial-stage1-test.json")

func click(game: Node, at: Vector2, button: int, pressed: bool) -> void:
	var event := InputEventMouseButton.new()
	event.position = at
	event.button_index = button
	event.pressed = pressed
	game._input(event)

func frame() -> void:
	await process_frame
	if performance_enabled:
		await RenderingServer.frame_post_draw

func capture(name: String) -> void:
	if not capture_enabled:
		return
	for _i in 10:
		await process_frame
		if name.begins_with("lobby") or name == "tutorial-select":
			continue
		break
	await process_frame
	await RenderingServer.frame_post_draw
	DirAccess.make_dir_recursive_absolute("res://artifacts/stage1/captures")
	var native: Image = root.get_texture().get_image()
	check(root.size == Vector2i(1920,1080) and native.get_size() == Vector2i(320,180), "real 1920x1080 window, integer scale 6")
	native.save_png("res://artifacts/stage1/captures/%s-native.png" % name)
	var output: Image = native.duplicate()
	output.resize(1920,1080,Image.INTERPOLATE_NEAREST)
	output.save_png("res://artifacts/stage1/captures/%s.png" % name)
	captures.append({"name": name, "window": [root.size.x,root.size.y], "native": [native.get_width(),native.get_height()], "output": [1920,1080], "scale": 6})
	print("CAPTURE " + name)
