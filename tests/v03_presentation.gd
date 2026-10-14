extends SceneTree
const Game := preload("res://pushbox/scripts/game.gd")
var checks: int = 0
var failures: int = 0

func check(value: bool, message: String) -> void:
	checks += 1
	if not value:
		failures += 1
		print("FAIL " + message)

func idle(game: Node) -> void:
	while game.session.running or game.animation_left > 0 or game._opening:
		await process_frame
	await process_frame

func solve(game: Node) -> void:
	for action in game.session.level.solution:
		game.request_action(action)
		game.skip_animation = true
		await idle(game)

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	var game := Game.new()
	root.add_child(game)
	await idle(game)
	await solve(game)
	var moves: int = game.session.board.moves
	game.request_action("L")
	check(game.session.board.moves == moves, "victory interval prevents ordinary action delaying auto-next")
	game.select_level(4)
	await idle(game)
	await solve(game)
	game._process(1.6)
	check(game.view.exit_fade == 0.0 and game.level_index == 4, "D5 retains visible victory scene after countdown")
	game.utility("restart")
	await idle(game)
	check(game.view.exit_fade == 0.0 and not game.view.winning, "restart clears all victory presentation")
	game.select_level(1)
	await idle(game)
	var event := InputEventMouseMotion.new()
	event.position = Vector2(game.session.board.player + Vector2i.LEFT) * 16 + Vector2(8,8)
	game._input(event)
	await process_frame
	await process_frame
	if DisplayServer.get_name() != "headless":
		check(Input.get_mouse_mode() == Input.MOUSE_MODE_HIDDEN, "hover activates tool cursor")
	game.request_action("DIG_L")
	event.position = Vector2(10,30)
	game._input(event)
	game.skip_animation = true
	await idle(game)
	check(Input.get_mouse_mode() == Input.MOUSE_MODE_VISIBLE, "cancelling hover restores normal cursor after pointing away during settlement")
	game.select_level(2)
	await idle(game)
	game.session.board.gates[0].open = true
	game.view.sync(false)
	check(game.view._gate_age < 1.0, "gate state alone starts six-frame presentation tween")
	game.view.feedback("BOMB_L", 0)
	game.view.visual_tick()
	check(game.view._flash_frames > 0, "flash survives update until a render consumes it")
	game.free()
	print("v03 presentation: %d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)
