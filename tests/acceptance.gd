extends SceneTree

const Session := preload("res://pushbox/scripts/session.gd")
const Loader := preload("res://pushbox/scripts/level_loader.gd")

var failures: int = 0
var checks: int = 0
var baselines: Array = []

func check(value: bool, message: String) -> void:
	checks += 1
	if not value:
		failures += 1
		print("FAIL " + message)

func material_total(session: RefCounted, name: String) -> int:
	return session.board.ids.count(session.board.name_ids[name])

func _initialize() -> void:
	if not FileAccess.file_exists("res://pushbox/scripts/preview.gd"):
		check(false, "M3: shared preview session is missing")
		quit(1)
		return
	var preview_script: Script = load("res://pushbox/scripts/preview.gd")
	for room in 5:
		var s := Session.new()
		check(s.load_level("res://pushbox/levels/d%d.json" % (room + 1), root) == "", "load")
		s.settle_sync()
		s.seal_opening()
		var opening_hash: String = s.world.get_state_hash()
		var fixture: Array = []
		var keys: Array = []
		var actors: Array = []
		var preview: RefCounted = preview_script.new()
		check(preview.configure(s, root) == "", "preview loads same content")
		var invalid_tick: int = s.world.get_tick()
		check(not s.perform("POUR_D").legal, "invalid action rejected")
		check(s.world.get_tick() == invalid_tick and s.board.moves == 0, "invalid action leaves world and moves unchanged")
		for step in s.level.solution.size():
			var action: String = s.level.solution[step]
			var before_hash: String = s.world.get_state_hash()
			var before_state: Dictionary = s.board.state()
			var old_sand: int = material_total(s, "sand") + s.board.total_bag()
			var old_water: int = material_total(s, "water")
			var old_exploded: int = s.exploded
			var predicted: Dictionary = preview.predict(s, action)
			check(s.world.get_state_hash() == before_hash, "T6 preview leaves real world unchanged")
			check(s.perform(action, true).legal, "T1 action legal")
			s.settle_sync()
			var hash_value: String = s.world.get_state_hash()
			check(s.world.get_tick() == predicted.tick, "T6 same stop tick")
			check(s.board.actors_key() == predicted.actors, "T6 same actors")
			check(s.board.categories() == predicted.categories, "T6 same categories")
			check(hash_value == predicted.hash, "T6 same complete world hash")
			check(s.board.state() == predicted.game_state, "T6 same complete game state")
			var lost: int = old_sand + old_water - material_total(s, "sand") - s.board.total_bag() - material_total(s, "water")
			if action.begins_with("BOMB_"):
				var cracked: int = 1 if room == 3 or room == 4 else 0
				check(lost + cracked * 256 == s.exploded - old_exploded, "T4 explosion destruction independently accounted")
			else:
				check(material_total(s, "sand") + s.board.total_bag() == old_sand, "T4 sand + bag conserved")
				check(material_total(s, "water") == old_water, "T4 water conserved")
			check(s.last_rounds <= 16 and s.max_round_ticks <= 1200 and s.errors.is_empty(), "T7 settlement within limits")
			fixture.append(hash_value)
			keys.append(s.board.position_key())
			actors.append(s.board.actors_key())
			check(s.undo(), "T5 undo succeeds")
			check(s.world.get_state_hash() == before_hash, "T5 restores exact start hash")
			check(s.board.state() == before_state, "T5 restores complete game state")
			check(s.perform(action, true).legal, "T5 repeated action legal")
			s.settle_sync()
			check(s.world.get_state_hash() == hash_value, "T5 repeat hash identical")
			if not s.level.solution_hashes.is_empty():
				check(hash_value == s.level.solution_hashes[step], "T1 recorded author hash")
		check(s.board.won(), "T1 all boxes on goals")
		check(s.restart() and s.world.get_state_hash() == opening_hash, "restart exact opening")
		baselines.append({"hashes": fixture, "keys": keys, "actors": actors})
		preview.dispose()
		s.dispose()
		print("PASS T1/T4/T5/T6/T7 D%d" % (room + 1))
	for config in [{"classify": {"threshold": 104}}, {"classify": {"threshold": 152}}, {"box_kinds": {"wood": {"float_support": 48}}}, {"box_kinds": {"wood": {"float_support": 80}}}, {"classify": {"threshold": 104}, "box_kinds": {"wood": {"float_support": 48}}}, {"classify": {"threshold": 104}, "box_kinds": {"wood": {"float_support": 80}}}, {"classify": {"threshold": 152}, "box_kinds": {"wood": {"float_support": 48}}}, {"classify": {"threshold": 152}, "box_kinds": {"wood": {"float_support": 80}}}, {}]:
		for room in 5:
			var s := Session.new()
			check(s.load_level("res://pushbox/levels/d%d.json" % (room + 1), root) == "", "variant load")
			s.board.rules = Loader.merge(s.board.rules, config)
			s.settle_sync()
			for step in s.level.solution.size():
				check(s.perform(s.level.solution[step]).legal, "variant legal")
				s.settle_sync()
				check(s.board.actors_key() == baselines[room].actors[step], "T3 each step actors unchanged")
				if config.is_empty():
					check(s.world.get_state_hash() == baselines[room].hashes[step], "T2 single-worker repeated determinism")
			check(s.board.won() and s.errors.is_empty(), "T3 victory without settlement error")
			s.dispose()
		print("PASS T3/T2 variant %s" % JSON.stringify(config))
	print("T2 threads 4/8: NOT RUN (explicit user resource constraint)")
	print("Acceptance: %d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)
