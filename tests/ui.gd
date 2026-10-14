extends SceneTree

var failures: int = 0

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	if not FileAccess.file_exists("res://pushbox/scenes/main.tscn"):
		print("FAIL M2: playable scene missing")
		quit(1)
		return
	var scene: PackedScene = load("res://pushbox/scenes/main.tscn")
	var game: Node = scene.instantiate()
	root.add_child(game)
	for room in 5:
		game.select_level(room)
		while game.session.running or game._opening:
			await process_frame
		for action in game.session.level.solution:
			game.request_action(action)
			game.skip_animation = true
			while game.session.running or game.animation_left > 0:
				await process_frame
		if not game.session.board.won():
			failures += 1
		print("UI D%d victory=%s" % [room + 1, game.session.board.won()])
	game.close_sessions()
	game.free()
	print("UI: %d failures" % failures)
	quit(1 if failures else 0)
