extends SceneTree
const Game := preload("res://pushbox/scripts/game.gd")
var checks: int = 0
var failures: int = 0

func check(value: bool, message: String) -> void:
	checks += 1
	if not value:
		failures += 1
		print("FAIL " + message)

func key(game: Node, code: int) -> void:
	var event := InputEventKey.new()
	event.physical_keycode = code
	event.pressed = true
	game._input(event)

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	if not FileAccess.file_exists("res://pushbox/scripts/ui/lobby_view.gd"):
		check(false, "lobby exists")
		print("Lobby stage1: %d checks, %d failures" % [checks, failures])
		quit(1)
		return
	var game := Game.new()
	game.start_in_lobby = true
	game.progress_path = "user://lobby-stage1-test.json"
	DirAccess.remove_absolute(game.progress_path)
	root.add_child(game)
	check(game.session == null and game.lobby.visible, "normal startup opens lobby without a world")
	check(game.lobby.card_rect(0) == Rect2(16,44,88,92), "88x92 cards on 320x180 canvas")
	check(game.lobby.completed_count() == 0, "new progress is empty")
	key(game, KEY_D)
	check(game.lobby.selected == 1, "WASD selects campaign")
	key(game, KEY_ENTER)
	check(game.lobby.page == "modes", "campaign stays locked")
	key(game, KEY_RIGHT)
	key(game, KEY_ENTER)
	check(game.lobby.page == "modes", "challenge stays locked")
	key(game, KEY_RIGHT)
	key(game, KEY_ENTER)
	check(game.lobby.page == "tutorial", "Enter opens tutorial panel")
	check(game.lobby.rows().size() == 5, "four tutorials plus return")
	key(game, KEY_ESCAPE)
	check(game.lobby.page == "modes", "Esc returns from level panel")
	var motion := InputEventMouseMotion.new()
	motion.position = game.lobby.to_global(game.lobby.card_rect(0).get_center())
	game._input(motion)
	check(game.lobby.selected == 0, "mouse hover selects tutorial")
	var click := InputEventMouseButton.new()
	click.position = motion.position
	click.pressed = true
	click.button_index = MOUSE_BUTTON_LEFT
	game._input(click)
	check(game.lobby.page == "tutorial", "left click opens tutorial panel")
	game.lobby.mark_completed("t01")
	game.lobby.mark_completed("t01")
	game.lobby.mark_completed("d1")
	check(game.lobby.completed_count() == 1, "save is idempotent and ignores legacy levels")
	game.lobby.load_progress()
	check(game.lobby.completed_count() == 1, "progress survives reload")
	var previous: PackedByteArray = FileAccess.get_file_as_bytes(game.progress_path)
	game.lobby.progress_path = "/dev/null/progress.json"
	game.lobby.mark_completed("t02")
	check(FileAccess.get_file_as_bytes(game.progress_path) == previous, "failed save preserves previous durable progress")
	game.lobby.progress_path = game.progress_path
	game.lobby.mark_completed("t02")
	game.lobby.load_progress()
	check(game.lobby.completed_count() == 2, "already-completed level retries a failed save")
	game.select_level(0)
	check(not game.lobby.visible and game.session.level.id == "d1", "select_level bypasses lobby")
	check(game.pause_menu.ROOT_ROWS == ["继续", "提示", "重开", "选关", "返回大厅", "设置", "退出"], "pause menu contains return to lobby")
	game.utility("lobby")
	check(game.session == null and game.preview == null and game.lobby.visible, "return releases both real and preview worlds")
	key(game, KEY_ESCAPE)
	check(game.pause_menu.opened and game.pause_menu.page == "settings", "lobby Esc opens settings")
	key(game, KEY_ESCAPE)
	check(not game.pause_menu.opened, "settings Esc returns to lobby")
	game.free()
	DirAccess.remove_absolute("user://lobby-stage1-test.json")
	print("Lobby stage1: %d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)
