extends SceneTree
const Game := preload("res://pushbox/scripts/game.gd")
var directory: String = "m1"

func _initialize() -> void:
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--milestone="):
			directory = argument.trim_prefix("--milestone=")
	call_deferred("run")

func idle(game: Node) -> void:
	while game.session.running or game.animation_left > 0 or game._opening:
		await process_frame
	if directory == "m3":
		game.guide.configure(game.session.board, game.session.level, {})
	game.guide.visible = directory == "m3"
	while game.view.entrance > 0:
		await process_frame
	await process_frame

func capture(name: String) -> void:
	await process_frame
	await RenderingServer.frame_post_draw
	var native: Image = root.get_texture().get_image()
	native.save_png("res://artifacts/v03/%s/%s-native.png" % [directory, name])
	var output: Image = native.duplicate()
	output.resize(1920, 1080, Image.INTERPOLATE_NEAREST)
	output.save_png("res://artifacts/v03/%s/%s.png" % [directory, name])
	if directory == "m2":
		output.resize(1280, 720, Image.INTERPOLATE_NEAREST)
		output.save_png("res://artifacts/v03/%s/%s-720.png" % [directory, name])
	print("CAPTURE %s/%s native=%s delivered=1920×1080 integer×6" % [directory, name, native.get_size()])

func move_pointer(game: Node, at: Vector2) -> void:
	var event := InputEventMouseMotion.new()
	event.position = at
	game._input(event)

func run() -> void:
	var game := Game.new()
	root.add_child(game)
	await idle(game)
	await capture("d1-opening")
	game.select_level(1)
	await idle(game)
	move_pointer(game, Vector2(game.session.board.player + Vector2i.LEFT) * 16 + Vector2(8,8))
	for _i in 120:
		await process_frame
		if not game.preview_result.is_empty():
			break
	await capture("d2-hover-dig")
	game.select_level(4)
	await idle(game)
	var press := InputEventMouseButton.new()
	press.button_index = MOUSE_BUTTON_LEFT
	press.pressed = true
	press.position = game.hud.bomb_rects()[0].get_center()
	game._input(press)
	move_pointer(game, Vector2(game.session.board.player + Vector2i.LEFT) * 16 + Vector2(8,8))
	for _i in 180:
		await process_frame
		if not game.preview_result.is_empty():
			break
	await capture("d5-drag-bomb")
	game.select_level(0)
	await idle(game)
	var escape := InputEventKey.new()
	escape.physical_keycode = KEY_ESCAPE
	escape.pressed = true
	game._input(escape)
	await capture("esc-menu")
	game.free()
	print("Capture: 4 screens")
	quit()
