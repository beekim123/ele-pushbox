extends SceneTree
## Real input regression: missing direct-click routing/cache/modal interception.
const Game := preload("res://pushbox/scripts/game.gd")
var checks: int = 0
var failures: int = 0

func check(value: bool, message: String) -> void:
	checks += 1
	if not value:
		failures += 1
		print("FAIL " + message)

func key(code: int) -> void:
	var event := InputEventKey.new()
	event.physical_keycode = code
	event.keycode = code
	event.pressed = true
	Input.parse_input_event(event)
	Input.flush_buffered_events()
	event = event.duplicate()
	event.pressed = false
	Input.parse_input_event(event)
	Input.flush_buffered_events()

func motion(at: Vector2) -> void:
	var event := InputEventMouseMotion.new()
	event.position = at
	event.global_position = at
	Input.parse_input_event(event)
	Input.flush_buffered_events()

func click(at: Vector2, button: int = MOUSE_BUTTON_LEFT, pressed: bool = true) -> void:
	var event := InputEventMouseButton.new()
	event.position = at
	event.global_position = at
	event.button_index = button
	event.pressed = pressed
	Input.parse_input_event(event)
	Input.flush_buffered_events()

func point(game: Node, relative: Vector2i) -> Vector2:
	var size: float = float(game.session.world.cell_scale) * 16
	return game.BOARD_POSITION + Vector2(game.session.board.player + relative) * size + Vector2.ONE * size / 2

func idle(game: Node) -> void:
	for _i in 600:
		if not game.session.running and game.animation_left == 0 and not game._opening:
			break
		await process_frame
	await process_frame

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	var game := Game.new()
	root.add_child(game)
	game.select_level(1)
	await idle(game)
	var before: String = game.session.world.get_state_hash()
	var left: Vector2 = point(game, Vector2i.LEFT)
	motion(left)
	for _i in 40:
		await process_frame
	check(game.preview_result.get("action") == "DIG_L", "hover predicts adjacent sand without selecting a tool")
	check(game.session.world.get_state_hash() == before and game.session.board.moves == 0, "hover never advances real world")
	click(left)
	click(left, MOUSE_BUTTON_LEFT, false)
	await idle(game)
	check(game.session.board.total_bag() == 220 and game.session.board.moves == 1, "one left click digs 220; no confirmation")
	var dig_hash: String = game.session.world.get_state_hash()
	var right: Vector2 = point(game, Vector2i.RIGHT)
	motion(right)
	for _i in 40:
		await process_frame
	check(game.preview_result.get("action") == "POUR_R", "hover predicts pour after digging")
	var expected: Dictionary = game.preview_result.duplicate(true)
	click(right, MOUSE_BUTTON_RIGHT)
	click(right, MOUSE_BUTTON_RIGHT, false)
	await idle(game)
	check(game.session.board.counts(game.session.board.origin + Vector2i(4, 4)).loose == 192, "one right click pours matching D2 fixture")
	check(not expected.is_empty() and game.session.world.get_state_hash() == expected.get("hash"), "T6 hover/click full world hash matches")
	key(KEY_Z)
	await idle(game)
	check(game.session.board.total_bag() == 220 and game.session.world.get_state_hash() == dig_hash, "Z restores exact source after pour")
	key(KEY_R)
	await idle(game)
	check(game.session.board.moves == 0 and game.session.board.total_bag() == 0, "R immediately restarts")
	key(KEY_ESCAPE)
	var paused_moves: int = game.session.board.moves
	key(KEY_D)
	await idle(game)
	check(game.session.board.moves == paused_moves, "Esc menu intercepts movement")
	key(KEY_ESCAPE)
	game.select_level(2)
	await idle(game)
	for _i in 5:
		key(KEY_D)
		await idle(game)
	key(KEY_W)
	await idle(game)
	check(game.session.board.levers[0].on and game.session.board.moves == 6, "UP uses lever on player's tile")
	game.select_level(4)
	await idle(game)
	var bomb_hash: String = game.session.world.get_state_hash()
	var bomb_origin: Vector2 = game.hud.bomb_rects()[0].get_center()
	click(bomb_origin)
	motion(point(game, Vector2i.LEFT))
	for _i in 100:
		await process_frame
	var bomb_expected: Dictionary = game.preview_result.duplicate(true)
	check(bomb_expected.get("action") == "BOMB_L" and game.session.world.get_state_hash() == bomb_hash, "bomb drag predicts without consuming budget")
	var calculations: int = game.preview.calculations
	motion(Vector2(10, 30))
	await process_frame
	motion(point(game, Vector2i.LEFT))
	for _i in 10:
		await process_frame
	check(game.preview.calculations == calculations, "same turn/target cached after leaving and returning")
	click(bomb_origin, MOUSE_BUTTON_LEFT, false)
	check(game.session.board.bombs == 1 and game.session.board.moves == 0, "drag back to HUD cancels")
	click(bomb_origin)
	motion(point(game, Vector2i.LEFT))
	click(point(game, Vector2i.LEFT), MOUSE_BUTTON_LEFT, false)
	await idle(game)
	check(game.session.board.bombs == 0 and game.session.board.moves == 1, "bomb drop executes once")
	check(game.session.world.get_state_hash() == bomb_expected.get("hash"), "T6 drag/drop exact hash matches")
	key(KEY_Z)
	await idle(game)
	check(game.session.world.get_state_hash() == bomb_hash and game.session.board.bombs == 1, "Z restores consumed bomb and full terrain")
	var undo_tick: int = game.session.world.get_tick()
	motion(point(game, Vector2i.LEFT))
	click(Vector2(10, 30))
	check(game.session.world.get_tick() == undo_tick and game.view.message.is_empty(), "far clicks are silent and do not advance time")
	game.free()
	print("v03 input: %d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)
