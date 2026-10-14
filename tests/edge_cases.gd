extends SceneTree

const Board := preload("res://pushbox/scripts/board.gd")
const Loader := preload("res://pushbox/scripts/level_loader.gd")
const Session := preload("res://pushbox/scripts/session.gd")
const Preview := preload("res://pushbox/scripts/preview.gd")
var failures: int = 0
var checks: int = 0
var materials: Array
var rules: Dictionary

func check(value: bool, message: String) -> void:
	checks += 1
	if not value:
		failures += 1
		print("FAIL " + message)

func board_fixture() -> RefCounted:
	var board := Board.new()
	board.configure(rules, materials)
	var cells := PackedInt32Array()
	cells.resize(61440)
	cells.fill(1)
	for y in range(1, 6):
		for x in range(1, 7):
			tile(cells, Vector2i(x, y), 0)
	board.read(cells)
	board.player = Vector2i(1, 5)
	return board

func tile(cells: PackedInt32Array, at: Vector2i, material: int, amount: int = 256) -> void:
	for i in 256:
		cells[(at.y * 16 + i / 16) * 320 + at.x * 16 + i % 16] = material if i < amount else 0

func _initialize() -> void:
	materials = Loader.json("res://pushbox/content/default/materials.json").materials
	rules = Loader.json("res://pushbox/rules.json")
	for amount in [0, 16, 17]:
		var b: RefCounted = board_fixture()
		tile(b.ids, Vector2i(4, 5), 3, amount)
		b.gates = [{"id": "g", "tiles": [Vector2i(4, 5), Vector2i(4, 4)], "open": true, "open_when": {"lever": "off"}}]
		b.resolve_round()
		check(b.gates[0].open == (amount == 17), "T4 gate closes only at <=16 cells")
		check(int(b.gate_crushed.get("sand", 0)) == (0 if amount == 17 else amount), "T4 exact gate crush count")
	var b: RefCounted = board_fixture()
	b.gates = [{"id": "g", "tiles": [Vector2i(1, 5)], "open": true, "open_when": {"lever": "off"}}]
	b.resolve_round()
	check(b.gates[0].open, "occupied gate defers closing")
	b = board_fixture()
	b.boxes = [{"id": "A", "at": Vector2i(4, 5), "kind": "wood"}]
	tile(b.ids, Vector2i(4, 5), 5)
	b.gates = [{"id": "g", "tiles": [Vector2i(4, 5)], "open": true, "open_when": {"lever": "off"}}]
	b.resolve_round()
	check(b.gates[0].open and b.gate_crushed.is_empty(), "box in gate group defers closing")
	b = board_fixture()
	tile(b.ids, Vector2i(4, 5), 3, 15)
	tile(b.ids, Vector2i(4, 4), 3, 2)
	b.gates = [{"id": "g", "tiles": [Vector2i(4, 5), Vector2i(4, 4)], "open": true, "open_when": {"lever": "off"}}]
	b.resolve_round()
	check(b.gates[0].open, "crush_max applies to combined gate group count")
	b = board_fixture()
	b.boxes = [{"id": "A", "at": Vector2i(2, 5), "kind": "wood"}, {"id": "B", "at": Vector2i(3, 5), "kind": "wood"}]
	tile(b.ids, Vector2i(2, 5), 5)
	tile(b.ids, Vector2i(3, 5), 5)
	check(b.apply_action("R").legal and b.player == Vector2i(2, 4), "blocked chain push steps up")
	check(b.boxes[0].at == Vector2i(2, 5) and b.boxes[1].at == Vector2i(3, 5), "no chain push")
	b = board_fixture()
	b.boxes = [{"id": "A", "at": Vector2i(2, 5), "kind": "wood"}, {"id": "B", "at": Vector2i(2, 4), "kind": "wood"}]
	tile(b.ids, Vector2i(2, 5), 5)
	tile(b.ids, Vector2i(2, 4), 5)
	check(not b.apply_action("R").legal, "cannot push a box with box on top")
	b = board_fixture()
	tile(b.ids, Vector2i(2, 5), 4, 100)
	b.boxes = [{"id": "A", "at": Vector2i(3, 5), "kind": "wood"}]
	tile(b.ids, Vector2i(3, 5), 5)
	b.player = Vector2i(4, 5)
	var water_before: int = b.ids.count(4)
	check(b.apply_action("L").legal, "push into subthreshold water")
	check(b.ids.count(4) == water_before, "T4 box swap conserves fluid")
	check(b.counts(Vector2i(3, 5)).fluid == 100, "displaced water returns to old box tile")
	b = board_fixture()
	tile(b.ids, Vector2i(1, 5), 3)
	b.read(b.ids)
	b.resolve_round()
	check(b.player == Vector2i(1, 4), "buried player escapes upward")
	b = board_fixture()
	b.player = Vector2i(0, 5)
	b.resolve_round()
	check(b.trapped, "no escape records trapped")
	b = board_fixture()
	check(b.condition({"count": {"rect": [0, 0, 1, 1], "tag": "fixed", "gte": 256}}), "generic material-count condition supports any tag")
	check(b.condition({"all": [{"not": {"lever": "absent"}}, {"any": [{"moves_gt": -1}, {"water": [1, 1]}]}]}), "composed mechanism conditions")
	b = board_fixture()
	var extended: Array = materials.duplicate(true)
	extended.append({"name": "gravel", "class": "powder", "tags": ["loose"]})
	b.configure(rules, extended)
	b.bag = {"gravel": 3, "sand": 2}
	var poured: Dictionary = b.apply_action("POUR_R")
	check(poured.amount == 5 and b.total_bag() == 0, "multi-material bag spends exact amount")
	check(poured.commands.map(func(c: Dictionary) -> String: return c.args[2]) == ["sand", "sand", "gravel", "gravel", "gravel"], "pour order uses listed materials then sorted extras")
	tile(b.ids, Vector2i(2, 5), 3, 100)
	for i in range(100, 200):
		b.ids[(80 + i / 16) * 320 + 32 + i % 16] = 7
	for i in range(200, 256):
		b.ids[(80 + i / 16) * 320 + 32 + i % 16] = 4
	b.read(b.ids)
	check(b.apply_action("DIG_R").amount == 200, "dig counts each loose material")
	check(b.bag.sand == 100 and b.bag.gravel == 100 and b.ids.count(4) == 56, "dig keeps water and separates bag materials")
	var prior_moves: int = b.moves
	check(not b.apply_action("POUR_D").legal and not b.apply_action("BOMB_L").legal and b.moves == prior_moves, "forbidden tools do not consume turn")
	b = board_fixture()
	var override: Dictionary = Loader.merge(rules, {"bomb": {"crumble_tag": "fixed"}})
	b.configure(override, materials)
	tile(b.ids, Vector2i(4, 5), 1, 64)
	b.read(b.ids)
	b.resolve_round()
	check(b.tag_count(Vector2i(4, 5), "fixed") == 0, "rules_override changes crumble tag")
	b = board_fixture()
	override = Loader.merge(rules, {"dig": {"tag": "fluid"}, "classify": {"order": [{"class": "SOLID", "tag": "solid"}, {"class": "SAND", "tag": "fluid"}]}})
	b.configure(override, materials)
	tile(b.ids, Vector2i(2, 5), 4)
	b.read(b.ids)
	check(b.apply_action("DIG_R").amount == 256 and b.total_bag() == 256, "rules_override changes dig tag")
	var room: Dictionary = Loader.json("res://pushbox/levels/d1.json")
	var bad: Dictionary = room.duplicate(true)
	bad.map[1] = "#..x.....#"
	check(not Loader.validate(bad, materials, rules).is_empty(), "unknown legend rejected")
	bad = room.duplicate(true)
	bad.legend["#"] = {"material": "bedrock", "fill": 0.5}
	check(not Loader.validate(bad, materials, rules).is_empty(), "partial static fill rejected")
	bad = Loader.json("res://pushbox/levels/d3.json")
	bad.mechanisms[0].tiles = [[6.0, 6.0]]
	check(not Loader.validate(bad, materials, rules).is_empty(), "gate mismatch rejected")
	bad = room.duplicate(true)
	bad.map[0] = "###"
	check(not Loader.validate(bad, materials, rules).is_empty(), "unequal rows rejected")
	var session := Session.new()
	check(session.load_level("res://pushbox/levels/d1.json", root) == "", "queue test level loads")
	session.settle_sync()
	var pure := Board.new()
	pure.configure(rules, materials)
	pure.read(session.board.ids)
	for y in 12:
		for x in 20:
			var at := Vector2i(x, y)
			for tag in ["solid", "loose", "fluid", "breakable", "empty"]:
				check(pure.counts(at)[tag] == session.board.counts(at)[tag], "native supplied counts equal pure ID counts")
	var commands: Array = []
	for i in 4100:
		commands.append({"op": "set_cell", "args": [0, 0, "bedrock"]})
	session._begin(commands)
	session.settle_sync()
	check(session.errors.is_empty() and session.world.get_stats().commands_rejected == 0, "4100 commands split across ticks")
	check(session.world.get_material_at(0, 0) == "bedrock", "batched final command executes")
	var saved_dir: String = session._snapshot_dir
	session._snapshot_dir = "/dev/null/not-a-directory"
	var saved_state: Dictionary = session.board.state()
	var saved_hash: String = session.world.get_state_hash()
	check(not session.perform("U", true).legal, "snapshot failure aborts action")
	check(session.board.state() == saved_state and session.world.get_state_hash() == saved_hash, "snapshot failure leaves game and world unchanged")
	session._snapshot_dir = saved_dir
	session.dispose()
	session = Session.new()
	session.load_level("res://pushbox/levels/d1.json", root)
	session.settle_sync()
	session.board.rules.settle.max_rounds = 1
	for action in session.level.solution:
		session.perform(action)
		session.settle_sync()
	check("max_rounds reached" in session.errors, "capped resolution records warning")
	check(session.board.ids == session.world.get_material_ids(0, 0, 320, 192), "capped resolution commits final batch consistently")
	session.dispose()
	session = Session.new()
	session.load_level("res://pushbox/levels/d5.json", root)
	session.settle_sync()
	var preview := Preview.new()
	preview.configure(session, root)
	var prediction: Dictionary = preview.predict(session, "BOMB_L", true)
	check(prediction.removed.size() == 543, "preview marks the 543 blast-destroyed source cells, not cells moved by gravity")
	check(not (session.board.origin + Vector2i(1, 1)) * 16 in prediction.removed, "outside-blast falling grain is not marked destroyed")
	preview.dispose()
	session.dispose()
	print("Edge cases: %d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)
