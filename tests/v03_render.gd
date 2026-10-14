extends SceneTree
const Game := preload("res://pushbox/scripts/game.gd")
var failures: int = 0

func frame() -> void:
	await process_frame
	await RenderingServer.frame_post_draw

func idle(game: Node) -> void:
	while game.session.running or game._opening or game.view.entrance > 0:
		await frame()
	await frame()

func white_pixels(rect: Rect2i) -> int:
	var result: int = 0
	var image: Image = root.get_texture().get_image()
	for y in range(rect.position.y, rect.end.y):
		for x in range(rect.position.x, rect.end.x):
			if image.get_pixel(x,y).is_equal_approx(Color.WHITE):
				result += 1
	return result

func check(value: bool, message: String) -> void:
	if not value:
		failures += 1
		print("FAIL " + message)

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	var game := Game.new()
	root.add_child(game)
	game.select_level(1)
	await idle(game)
	game.guide.configure(game.session.board, game.session.level, {})
	await frame()
	check(white_pixels(Rect2i(130,92,64,13)) > 20, "D2 left-mouse guide actually rendered")
	game.select_level(4)
	await idle(game)
	check(white_pixels(Rect2i(130,92,64,13)) == 0, "D5 clears previous room's retained guide draw commands")
	game.view.feedback("BOMB_L",0)
	await frame()
	check(root.get_texture().get_image().get_pixel(160,90).is_equal_approx(Color.WHITE), "explosion visibly flashes white for one rendered frame")
	await frame()
	check(not root.get_texture().get_image().get_pixel(160,90).is_equal_approx(Color.WHITE), "white flash disappears on following frame")
	game.free()
	print("v03 render: 4 checks, %d failures" % failures)
	quit(1 if failures else 0)
