extends SceneTree

const Board := preload("res://pushbox/scripts/board.gd")
const Session := preload("res://pushbox/scripts/session.gd")
const Preview := preload("res://pushbox/scripts/preview.gd")
const Loader := preload("res://pushbox/scripts/level_loader.gd")
var checks: int = 0
var failures: int = 0

func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		print("FAIL " + label)

func fresh(config: Dictionary = {}) -> RefCounted:
	var b := Board.new()
	b.configure(Loader.json("res://pushbox/rules.json"), Loader.json("res://pushbox/content/default/materials.json").materials)
	var cells := PackedInt32Array()
	cells.resize(61440)
	b.read(cells)
	b.player = Vector2i(1,10)
	b.set("mechanisms", config.duplicate(true))
	return b

func _initialize() -> void:
	var b := fresh()
	for name in ["iron_crate", "acid", "fume", "lava", "pumice", "ice"]:
		check(b.name_ids.has(name), "material " + name)
	if failures:
		finish()
		return
	b = fresh({"vine_seeds":[{"at":[4,8],"height":3}]})
	b._paint(Vector2i(5,8),"water")
	b.resolve_round()
	check(Vector2i(4,6) in b.ladders and b.ladders.size() == 3, "water grows three climbable rungs")
	var saved: Dictionary = b.state()
	b.ladders.clear()
	b.restore(saved)
	check(b.state() == saved and b.ladders.size() == 3, "dynamic ladder snapshot restores")
	b = fresh({"cloud_pads":[[4,6]]})
	check(b._supported({"at":Vector2i(4,5),"kind":"wood"}), "cloud supports wood")
	check(not b._supported({"at":Vector2i(4,5),"kind":"iron"}), "iron penetrates cloud")
	b = fresh({"teleporters":[{"from":[3,5],"to":[8,5]}]})
	b._paint(Vector2i(3,6),"bedrock")
	b._paint(Vector2i(8,6),"bedrock")
	b.boxes = [{"id":"A","at":Vector2i(3,5),"kind":"wood"}]
	b._paint(Vector2i(3,5),"crate")
	b.resolve_round()
	check(b.boxes[0].at == Vector2i(8,5), "portal moves box across wall")
	b = fresh({"gravity_zones":[{"rect":[3,2,4,6],"active_when":{"lever":"G"}}]})
	b.levers = [{"id":"G","at":Vector2i(1,10),"on":true}]
	b.boxes = [{"id":"A","at":Vector2i(4,7),"kind":"wood"},{"id":"I","at":Vector2i(5,7),"kind":"iron"}]
	for box in b.boxes:
		b._paint(box.at, b.rules.box_kinds[box.kind].material)
	b._paint(Vector2i(5,8),"bedrock")
	b.resolve_round()
	check(b.boxes[0].at == Vector2i(4,2) and b.boxes[1].at == Vector2i(5,7), "local gravity raises wood, locks iron")
	b = fresh({"hourglasses":[{"tiles":[[6,4]],"open_when":{"moves_gt":0}}]})
	b._paint(Vector2i(6,4),"gate")
	b.resolve_round()
	check(b.category(Vector2i(6,4)) == "SOLID", "hourglass waits for a move")
	b.moves = 1
	b.resolve_round()
	check(b.category(Vector2i(6,4)) == "OPEN", "hourglass opens after threshold")
	b = fresh({"geysers":[{"at":[7,5],"every":2,"material":"water"}]})
	b.moves = 2
	b.resolve_round()
	check(b.counts(Vector2i(7,5)).fluid == 256, "geyser emits one tile on scheduled move")
	b._paint(Vector2i(7,5),"empty")
	b.resolve_round()
	check(b.counts(Vector2i(7,5)).empty == 256, "geyser does not repeat within settlement")
	b = fresh({"freezers":[{"tiles":[[6,6]],"active_when":{"lever":"L"}}]})
	b.levers = [{"id":"L","at":Vector2i(1,10),"on":true}]
	b._paint(Vector2i(6,6),"water")
	b.resolve_round()
	check(b.category(Vector2i(6,6)) == "SOLID" and b.tag_count(Vector2i(6,6),"ice") == 256, "freeze creates solid ice")
	b.levers[0].on = false
	b.resolve_round()
	check(b.category(Vector2i(6,6)) == "WATER", "thaw restores water")
	b = fresh({"stalactites":[{"at":[5,3],"support":[5,2]}]})
	b._paint(Vector2i(5,3),"bedrock")
	b._paint(Vector2i(5,7),"cracked_rock")
	b._paint(Vector2i(5,9),"bedrock")
	b.resolve_round()
	check(b.mechanisms.stalactites[0].at == [5,8] and b.counts(Vector2i(5,7)).breakable == 0, "released hammer pierces fragile rock, lands as dam")
	b = fresh({"scales":[{"left":[4,5],"right":[8,5],"lift":2}]})
	b.boxes = [{"id":"I","at":Vector2i(4,5),"kind":"iron"},{"id":"A","at":Vector2i(8,5),"kind":"wood"}]
	for box in b.boxes:
		b._paint(box.at,b.rules.box_kinds[box.kind].material)
	b.resolve_round()
	b.resolve_round()
	check(b.boxes[0].at == Vector2i(4,7) and b.boxes[1].at == Vector2i(8,3), "left heavy descends and right cargo rises two tiles")
	check(not b.resolve_round().changed, "loaded scale stabilizes without oscillation")
	b = fresh({"wind_zones":[{"rect":[2,2,8,8],"direction":"R"}]})
	b.player = Vector2i(3,5)
	b.bag = {"sand":256}
	check(b.apply_action("POUR_R").legal and b.counts(Vector2i(5,5)).loose == 256 and b.counts(Vector2i(4,5)).empty == 256, "wind shifts pour one tile")
	b = fresh({"teleporters":[{"from":[3,5],"to":[8,5]}]})
	b._paint(Vector2i(3,5),"sand")
	b._paint(Vector2i(8,5),"iron_crate")
	b.resolve_round()
	check(b.counts(Vector2i(3,5)).loose == 256, "blocked receiver preserves sender sand")
	b._paint(Vector2i(8,5),"empty")
	b.resolve_round()
	check(b.counts(Vector2i(8,5)).loose == 256 and b.counts(Vector2i(3,5)).empty == 256, "portal conserves all sand cells")
	b = fresh({"gravity_zones":[{"rect":[3,2,4,6],"active_when":{"lever":"G"}}]})
	b.levers = [{"id":"G","at":Vector2i(1,10),"on":true}]
	b._paint(Vector2i(4,7),"sand")
	b.resolve_round()
	check(b.counts(Vector2i(4,2)).loose == 256, "inverted sand reaches roof")
	b.levers[0].on = false
	b.resolve_round()
	check(b.ids.count(b.name_ids.levitated_sand) == 0 and b.ids.count(b.name_ids.sand) == 256, "normal gravity restores conserved powder")
	b = fresh({"scales":[{"left":[4,5],"right":[8,5],"lift":2}]})
	b.boxes = [{"id":"I","at":Vector2i(4,5),"kind":"iron"},{"id":"A","at":Vector2i(8,5),"kind":"wood"}]
	for box in b.boxes:
		b._paint(box.at,b.rules.box_kinds[box.kind].material)
	b.player = Vector2i(8,4)
	b.resolve_round()
	b.resolve_round()
	check(b.boxes[1].at == Vector2i(8,3) and b.player == Vector2i(8,2), "scale carries a player standing on its cargo")
	b = fresh({"stalactites":[{"at":[5,3],"support":[5,2]}]})
	b._paint(Vector2i(5,3),"bedrock")
	b._paint(Vector2i(5,8),"water")
	b._paint(Vector2i(5,9),"bedrock")
	b.resolve_round()
	check(b.ids.count(b.name_ids.water) == 256,"falling hammer displaces water without deleting it")
	batch_cache_checks()
	sdk_checks()
	finish()

func batch_cache_checks() -> void:
	# Mixed sand/water loads exercise the scale/portal displacement path and
	# cached classification; uniform sand never reaches this code path.
	var b := fresh()
	var source := Vector2i(3,5)
	var dest := Vector2i(8,5)
	for y in 12:
		for x in 16:
			b._set_cell(source.x*16+x,source.y*16+y,"sand" if y < 8 else "water")
	b._paint(dest,"water")
	check(b.category(source) == "SAND" and b.category(dest) == "WATER","warm mixed-load category caches")
	var data: Dictionary = Board.Biome.tile_data(b,source)
	b._commands.clear()
	Board.Biome.move_loose(b,source,dest)
	check(b.ids.count(b.name_ids.sand) == 128 and b.ids.count(b.name_ids.water) == 320,"mixed transfer conserves sand and displaced water")
	check(b.counts(source).fluid == 192 and b.counts(dest).loose == 128,"mixed transfer invalidates both count caches")
	check(b.category(source) == "WATER" and b.category(dest) == "SAND","mixed transfer invalidates both category caches")
	check(b._commands.size() == 256 and b._commands[0].args == [48,80,"water"] and b._commands[1].args == [128,80,"sand"] and b._commands[-1].args == [143,87,"sand"],"mixed transfer retains exact alternating SDK writes")
	Board.Biome.restore_tile(b,source,data)
	check(b.counts(source).loose == 128 and b.counts(source).fluid == 64 and b.category(source) == "SAND","mixed underlay restoration refreshes cached classifications")
	check(Board.Biome.convert_material(b,source,"water","ice"),"partial water converts without touching powder")
	check(b.tag_count(source,"ice") == 64 and b.counts(source).fluid == 0 and b.counts(source).loose == 128,"partial conversion refreshes all cached tags")

func finish() -> void:
	print("Mechanisms Stage2A: %d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)

func sdk_checks() -> void:
	var cases: Array = [
		{"vine_seeds":[{"at":[5,8],"height":3}]},
		{"hourglasses":[{"tiles":[[5,5]],"open_when":{"moves_gt":0}}]},
		{"scales":[{"left":[4,6],"right":[8,6],"lift":2}]},
		{"stalactites":[{"at":[5,3],"support":[5,2]}]},
		{"geysers":[{"at":[6,8],"every":1}]},
		{"freezers":[{"tiles":[[5,8]],"active_when":{"lever":"L"}}]},
		{"wind_zones":[{"rect":[1,5,8,5],"direction":"R"}]},
		{"teleporters":[{"from":[5,9],"to":[12,9]}]},
		{"gravity_zones":[{"rect":[4,2,4,8],"active_when":{"lever":"L"}}]}
	]
	DirAccess.make_dir_recursive_absolute("res://artifacts/stage2a/fixtures")
	for i in cases.size():
		var grid: Array = []
		for y in 11:
			grid.append("####################" if y in [0,10] else "#..................#")
		grid[8] = "#....w.............#"
		var level := {"format":"pushbox.level/1","content":"default","id":"mechanism_fixture","map":grid,"legend":{"#":"bedrock",".":"empty","w":"water"},"entities":{"player":[1,9],"boxes":[{"id":"A","kind":"wood","at":[5,9]}],"targets":[[18,9]],"levers":[{"id":"L","at":[1,9]}]},"biome_mechanisms":cases[i],"budget":{"sand_cells":256,"bombs":0},"seed":1}
		var path: String = "res://artifacts/stage2a/fixtures/mechanism-%d.json" % i
		var file := FileAccess.open(path,FileAccess.WRITE)
		file.store_string(JSON.stringify(level))
		file.close()
		var session := Session.new()
		var reason: String = session.load_level(path,root)
		check(reason == "", "SDK mechanism fixture loads " + str(i) + reason)
		if not reason.is_empty():
			continue
		session.settle_sync()
		var preview := Preview.new()
		check(preview.configure(session,root) == "", "preview fixture loads")
		var before: String = session.world.get_state_hash()
		var state: Dictionary = session.board.state()
		var prediction: Dictionary = preview.predict(session,"USE")
		check(session.perform("USE",true).legal, "mechanism action legal")
		session.settle_sync()
		check(session.errors.is_empty(), "mechanism fixture settles " + str(i) + str(session.errors))
		var after: String = session.world.get_state_hash()
		var after_state: Dictionary = session.board.state()
		check(prediction.hash == after and prediction.game_state == after_state, "T6 complete mechanism state " + str(i))
		check(session.undo() and before == session.world.get_state_hash() and session.board.state() == state, "T5 restores mechanism " + str(i))
		session.perform("USE")
		session.settle_sync()
		check(after == session.world.get_state_hash() and after_state == session.board.state(), "T5 repeats mechanism " + str(i))
		preview.dispose()
		session.dispose()

	var reaction_level := {"format":"pushbox.level/1","content":"default","id":"reaction_fixture","seed":1,"map":["############", "#......#w###", "#..a...#w###", "#..a...#w###", "#..a...#m###", "###c####m###", "############"],"legend":{"#":"bedrock",".":"empty","a":"acid","c":"cracked_rock","w":"water","m":"lava"},"entities":{"player":[1,5],"boxes":[],"targets":[]},"budget":{}}
	var reaction_path: String = "res://artifacts/stage2a/fixtures/reactions.json"
	var reaction_file := FileAccess.open(reaction_path,FileAccess.WRITE)
	reaction_file.store_string(JSON.stringify(reaction_level))
	reaction_file.close()
	var reaction_session := Session.new()
	check(reaction_session.load_level(reaction_path,root) == "", "SDK extended reaction registry loads")
	reaction_session.settle_sync()
	check(reaction_session.board.ids.count(reaction_session.board.name_ids.cracked_rock) == 0, "SDK acid erodes and crumbles rock")
	check(reaction_session.board.ids.count(reaction_session.board.name_ids.lava) == 0 and reaction_session.board.ids.count(reaction_session.board.name_ids.pumice) >= 512, "SDK convection converts entire lava pool to dense pumice")
	check(reaction_session.errors.is_empty(), "SDK reactions reach quiescence")
	reaction_session.dispose()
