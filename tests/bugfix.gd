extends SceneTree
## Reproduce collision-looking step animation and resize/input layout failures.
const Game := preload("res://pushbox/scripts/game.gd")
var checks: int = 0
var failures: int = 0
var resize_depth: int = 0
var max_resize_depth: int = 0

func resize_begin() -> void:
	resize_depth += 1
	max_resize_depth = maxi(max_resize_depth, resize_depth)

func resize_end() -> void:
	resize_depth -= 1

func check(value: bool, message: String) -> void:
	checks += 1
	if not value:
		failures += 1
		print("FAIL " + message)

func frame() -> void:
	await process_frame
	await RenderingServer.frame_post_draw

func idle(game: Node) -> void:
	for _i in 1200:
		if not game.session.running and game.animation_left == 0 and not game._opening and game.view.entrance <= 0:
			return
		await frame()
	check(false, "game becomes idle within the frame limit")

func resize_window(size: Vector2i) -> void:
	max_resize_depth = 0
	root.size = size
	await frame()
	await frame()
	var stretch: Vector2 = root.get_screen_transform().get_scale()
	print("RESIZE physical=%s logical=%s screen_scale=%s" % [root.size, root.get_visible_rect().size, stretch])
	check(is_equal_approx(stretch.x, roundf(stretch.x)) and is_equal_approx(stretch.y, roundf(stretch.y)), "actual screen transform stays at an integer pixel scale after resize")
	check(max_resize_depth <= 1, "layout never reenters the viewport size signal and overwrites the outer screen attachment")

func capture(name: String) -> void:
	DirAccess.make_dir_recursive_absolute("res://artifacts/2026-10-14-bugfix/captures")
	root.get_texture().get_image().save_png("res://artifacts/2026-10-14-bugfix/captures/%s.png" % name)

func click(game: Node, at: Vector2, pressed: bool) -> void:
	var event := InputEventMouseButton.new()
	event.position = at
	event.global_position = at
	event.button_index = MOUSE_BUTTON_LEFT
	event.pressed = pressed
	game._input(event)

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	await resize_window(Vector2i(1280, 720))
	root.size_changed.connect(resize_begin)
	var game := Game.new()
	root.add_child(game)
	root.size_changed.connect(resize_end)
	await idle(game)
	game.request_action("R")
	check(game.session.board.player == Vector2i(6, 7) and game.session.board.moves == 0, "D1 two-high wall blocks ordinary walking")
	game.request_action("U")
	await idle(game)
	game.request_action("R")
	game.set_physics_process(false)
	check(game.session.board.player == Vector2i(7, 5), "existing one-step climb keeps its original destination")
	var obstacle := Rect2(112, 96, 16, 16)
	var intersects: bool = false
	for fraction in [1.0/6, 2.0/6, 3.0/6, 4.0/6, 5.0/6]:
		game.view.fraction = fraction
		var body := Rect2(game.view._point("player"), Vector2(16, 16))
		intersects = intersects or body.intersects(obstacle)
	check(not intersects, "step animation never cuts through the solid corner")
	game.view.fraction = 0.5
	game.view.queue_redraw()
	await frame()
	capture("step-midpoint")
	game.view.fraction = 1.0
	check(game.view._point("player") == Vector2(112, 80), "step animation ends at the original tile")
	game.set_physics_process(true)
	game.skip_animation = true
	await idle(game)
	game.select_level(1)
	await idle(game)
	await frame()
	var actor_rect := Rect2i(128, 112, 16, 16)
	game.request_action("DIG_L")
	await idle(game)
	while game.view._pose_left > 0:
		await frame()
	game._pointer = Vector2(-100, -100)
	game.cancel_preview()
	await frame()
	var left_image: Image = root.get_texture().get_image()
	var sprite: Image = Game.Style.texture("miner_idle_%d" % (int(game.view.clock * 8) % 2)).get_image()
	var opaque: int = 0
	var matching: int = 0
	for y in 16:
		for x in 16:
			var expected: Color = sprite.get_pixel(15 - x, y)
			if expected.a == 1.0:
				opaque += 1
				if left_image.get_pixel(actor_rect.position.x + x, actor_rect.position.y + y).is_equal_approx(expected):
					matching += 1
	check(game.session.board.player == Vector2i(8, 7), "digging left does not move the logical player")
	check(opaque > 0 and matching == opaque, "turning left mirrors every opaque miner pixel inside its logical tile")
	capture("left-facing")
	game.utility("restart")
	await idle(game)
	await frame()
	var rock: PackedByteArray = root.get_texture().get_image().get_region(Rect2i(80, 48, 16, 16)).get_data()
	await resize_window(Vector2i(960, 720))
	check(root.get_visible_rect().size == Vector2(320, 240), "4:3 window expands the logical height instead of keeping a letterboxed 16:9 canvas")
	check(game.view.position == Vector2(0, 30) and game.session.world.position == Vector2(0, 30), "world and actors stay centered together in a taller window")
	check(root.get_texture().get_image().get_region(Rect2i(80, 78, 16, 16)).get_data() == rock, "taller layout preserves the terrain texture and clipping at its new position")
	game.pause_menu.toggle()
	check(game.pause_menu._rect().position == Vector2(86, 44), "pause menu follows the taller viewport")
	await frame()
	capture("tall-menu")
	game.pause_menu.close()
	await resize_window(Vector2i(1200, 540))
	check(root.get_visible_rect().size == Vector2(400, 180), "wide window expands the logical width at integer scale")
	check(game.view.position == Vector2(40, 0) and game.session.world.position == Vector2(40, 0), "wide window centers the board and SDK together")
	check(root.get_texture().get_image().get_region(Rect2i(120, 48, 16, 16)).get_data() == rock, "wide layout preserves the same terrain pixels")
	check(game.hud.bag_position() == Vector2(384, 5), "inventory stays at the actual right edge")
	check(game._action_at(Vector2(160, 120), "left") == "DIG_L", "screen-space click still targets the visible adjacent sand after centering")
	await frame()
	capture("wide-room")
	await resize_window(Vector2i(1000, 700))
	check(root.get_visible_rect().size == Vector2(333, 233), "odd window dimensions use all available whole pixels at scale three")
	check(game._action_at(Vector2(127, 147), "left") == "DIG_L", "odd-size rounding preserves the visible click target")
	await resize_window(Vector2i(480, 720))
	check(root.get_visible_rect().size == Vector2(480, 720), "portrait window fills its canvas without large integer-scale bars")
	check(game.view.position == Vector2(80, 270) and game.hud.bag_position() == Vector2(464, 5), "portrait layout centers the board and keeps inventory on screen")
	check(game._action_at(Vector2(200, 390), "left") == "DIG_L", "portrait click coordinates still select the visible sand")
	await frame()
	capture("portrait-room")
	await resize_window(Vector2i(1200, 540))
	game.select_level(4)
	await idle(game)
	var before: String = game.session.world.get_state_hash()
	click(game, Vector2(376, 11), true)
	check(game._dragging, "bomb can be picked up from its new HUD position")
	click(game, Vector2(144, 72), false)
	await idle(game)
	check(game.session.board.moves == 1 and game.session.board.bombs == 0, "bomb released onto the centered board executes once")
	game.utility("undo")
	await idle(game)
	check(game.session.world.get_state_hash() == before and game.session.board.bombs == 1, "undo restores the same SDK state after resized drag/drop")
	game.view.feedback("BOMB_L", 0)
	await frame()
	var image: Image = root.get_texture().get_image()
	check(image.get_pixel(0, 0).is_equal_approx(Color.WHITE), "explosion flash covers the extra left area")
	if image.get_width() >= 400:
		check(image.get_pixel(399, 179).is_equal_approx(Color.WHITE), "explosion flash covers the extra right area")
	else:
		check(false, "explosion flash has a full-width viewport to cover")
	while game.view._shake_frames > 0:
		await frame()
	await resize_window(Vector2i(1280, 720))
	check(game.view.position == Vector2.ZERO and game.hud.bag_position() == Vector2(304, 5), "returning to 16:9 restores the original board and HUD layout")
	game.free()
	print("Bugfix: %d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)
