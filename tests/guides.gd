extends SceneTree
## Guide progression must follow successful actions and skip learned events.
const Game := preload("res://pushbox/scripts/game.gd")
const Loader := preload("res://pushbox/scripts/level_loader.gd")
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

func do_action(game: Node, action: String) -> void:
	game.request_action(action)
	game.skip_animation = true
	await idle(game)

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	var game := Game.new()
	root.add_child(game)
	await idle(game)
	if game.get("guide") == null:
		check(false, "D1 has data-driven wall keycap guide")
		game.free()
		print("Guides: %d checks, %d failures" % [checks, failures])
		quit(1)
		return
	# Fresh learner injected through the ordinary configure boundary; no disk mutation.
	game.guide.configure(game.session.board, game.session.level, {})
	game.guide.advance(0.0)
	check(game.guide.active.get("id") == "climb", "D1 starts with UP keycap")
	await do_action(game, "U")
	check(game.guide.active.get("id") == "climb", "UP stays until player reaches platform")
	await do_action(game, "U")
	check(game.guide.active.get("id") == "push", "horizontal keycaps appear on platform")
	await do_action(game, "R")
	await do_action(game, "R")
	check(game.guide.active.is_empty(), "push guide vanishes after pushing")
	game.select_level(1)
	await idle(game)
	game.guide.configure(game.session.board, game.session.level, {})
	game.guide.advance(0.0)
	check(game.guide.active.get("id") == "dig", "D2 left mouse guide visible before digging")
	game.utility("next_hint")
	check(game.guide.hint_action == "DIG_L", "menu next hint demonstrates matched author action")
	await do_action(game, "DIG_L")
	check(game.guide.hint_action.is_empty(), "successful action clears obsolete hint demonstration")
	check(game.guide.active.get("id") == "pour", "D2 right mouse guide appears immediately after digging")
	await do_action(game, "POUR_R")
	check(game.guide.active.is_empty(), "D2 mouse guides disappear after successful actions")
	var learned: Dictionary = game.guide.progress.duplicate(true)
	game.utility("restart")
	await idle(game)
	game.guide.configure(game.session.board, game.session.level, learned)
	game.guide.advance(0.0)
	check(game.guide.active.is_empty(), "completed guides skipped on replay")
	game.guide.configure(game.session.board, game.session.level, {})
	game.guide.notify("poured")
	game.guide.notify("dug")
	game.guide.advance(0.0)
	check(game.guide.active.is_empty(), "done event before guide start skips that guide")
	game.select_level(2)
	await idle(game)
	game.guide.configure(game.session.board, game.session.level, {})
	game.guide.advance(0.0)
	check(game.guide.active.is_empty(), "D3 pull guide waits for lever tile")
	for _i in 5:
		await do_action(game, "R")
	check(game.guide.active.get("id") == "pull", "D3 UP pull appears on lever")
	game.request_direction("U")
	game.skip_animation = true
	await idle(game)
	check(game.guide.active.is_empty(), "D3 pull guide vanishes after UP interaction")
	game.select_level(3)
	await idle(game)
	game.guide.configure(game.session.board, game.session.level, {})
	game.guide.advance(0.0)
	check(game.guide.active.get("id") == "drag", "D4 hand demonstrates dragging")
	game.guide.advance(2.1)
	check(game.guide.active.is_empty(), "D4 demonstration ends after two seconds")
	game.guide.advance(0.1)
	check(game.guide.active.is_empty(), "D4 timed demonstration stays dismissed")
	game.guide.configure(game.session.board, game.session.level, {})
	game.guide.notify("bomb_dragged")
	game.guide.advance(0.0)
	check(game.guide.active.is_empty(), "first bomb drag permanently skips demonstration")
	game.select_level(4)
	await idle(game)
	check(game.guide.active.is_empty(), "D5 has no guides")
	var level: Dictionary = Loader.json("res://pushbox/levels/d3.json")
	var materials: Array = Loader.json("res://pushbox/content/default/materials.json").materials
	var rules: Dictionary = Loader.json("res://pushbox/rules.json")
	level.guides[0].start = {"player_at": [6]}
	check(not Loader.validate(level, materials, rules).is_empty(), "loader rejects malformed player_at guide before runtime")
	level = Loader.json("res://pushbox/levels/d3.json")
	level.guides[0].done = "lever_usde"
	check(not Loader.validate(level, materials, rules).is_empty(), "loader rejects misspelled guide completion event")
	game.free()
	print("Guides: %d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)
