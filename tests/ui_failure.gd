extends SceneTree

const Game := preload("res://pushbox/scripts/game.gd")
var failures: int = 0
var checks: int = 0

func check(value: bool, message: String) -> void:
	checks += 1
	if not value:
		failures += 1
		print("FAIL " + message)

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	var game: Node = Game.new()
	root.add_child(game)
	var directory: String = game.session._snapshot_dir
	game.session._snapshot_dir = "/dev/null/not-a-directory"
	for _i in 45:
		await process_frame
		if game.get("_opening_failed") == true:
			break
	check(game._opening and game.get("_opening_failed") == true and game.session.initial.is_empty(), "failed opening snapshot keeps input frozen")
	game.utility("replay")
	check(not game._replaying, "failed opening cannot start author replay")
	game.session._snapshot_dir = directory
	game.utility("restart")
	for _i in 120:
		await process_frame
		if not game._opening:
			break
	check(not game._opening and not game.session.initial.is_empty(), "R retries opening snapshot after storage recovery")
	game.session.initial = {}
	game.utility("replay")
	check(not game._replaying and game.session.board.moves == 0, "replay refuses a failed restart")
	game.free()
	print("UI failure paths: %d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)
