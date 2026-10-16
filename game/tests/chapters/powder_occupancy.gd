extends SceneTree
## Thin powder is displaced by crate occupancy, then falls only through the SDK.
const SESSION = preload("res://gameplay/session/level_session.gd")
var failures: Array[String] = []
var cases: Array[Dictionary] = []

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	for material: String in ["sand", "gravel"]:
		for blocker: String in ["", "solid", "player", "crate", "thin-solid"]:
			_push(material, blocker)
		for mode: String in ["ice_slide", "mine_cart", "portal", "fall"]:
			for blocked: bool in [false, true]:
				if mode != "fall" or not blocked:
					_mechanism(material, mode, blocked)
		for blocker: String in ["", "headroom", "deck"]:
			_lift(material,blocker)
	var report: Dictionary = {"suite":"powder-occupancy", "ok":failures.is_empty(), "cases":cases, "failures":failures}
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://tests/results"))
	var file := FileAccess.open("res://tests/results/powder-occupancy.json", FileAccess.WRITE)
	if file == null:
		printerr("Cannot write powder occupancy evidence")
		quit(1)
		return
	file.store_string(JSON.stringify(report, "\t"))
	file.close()
	print("PORTITOR_TEST_RESULT=" + JSON.stringify(report))
	quit(0 if failures.is_empty() else 1)

func _push(material: String, blocker: String) -> void:
	var session = SESSION.new()
	session.render_enabled = false
	var spec: Dictionary = {"id":"thin-powder", "group":"thermal", "mechanisms":["gravel"], "map":["#######", "#.....#", "#PB.o.#", "#######"]}
	if not session.setup(spec):
		failures.append("setup: " + session.last_error)
		session.dispose()
		return
	# A settled 32-cell layer below classification threshold in the next tile.
	session.world.paint_rect(48, 46, 16, 2, material)
	session.world.step(1)
	if blocker == "solid": session.set_tile_material(3, 1, "bedrock")
	if blocker == "player": session.grid.player = {"x":3, "y":1}
	if blocker == "crate":
		session.grid.crates.append({"x":3, "y":1, "kind":"wood"})
		session.world.paint_rect(48, 16, 16, 16, "crate")
	if blocker == "thin-solid": session.world.set_cell(48, 16, "bedrock")
	session.world.step(1)
	var total_before: int = session.material_count(Rect2i(0,0,112,64), material)
	var before_hash: String = session.world.get_state_hash()
	var before_state: String = JSON.stringify(session.state())
	var result: Dictionary
	if blocker == "player":
		result = {"accepted":session.move_crate(0, Vector2i(3,2))}
	else:
		result = session.perform("R")
	var expected: bool = blocker.is_empty()
	var accepted: bool = bool(result.get("accepted",false))
	var unchanged: bool = session.world.get_state_hash() == before_hash and JSON.stringify(session.state()) == before_state
	var total_after: int = session.material_count(Rect2i(0,0,112,64), material)
	var ok: bool = total_before == 32 and total_after == 32 and accepted == expected and (expected or unchanged)
	if expected:
		ok = ok and int(session.grid.crates[0].x) == 3 and session.undo() and session.world.get_state_hash() == before_hash
	cases.append({"material":material,"blocker":blocker,"before":total_before,"after":total_after,"accepted":accepted,"unchanged_on_rejection":unchanged,"ok":ok})
	if not ok: failures.append(material + "/" + blocker)
	session.dispose()

func _lift(material: String, blocker: String) -> void:
	var spec: Dictionary = {"id":"powder-lift", "group":"thermal", "map":["##########", "#.......o#", "#........#", "#........#", "#.B......#", "#P.......#", "##########"], "devices":[{"type":"lift", "stops":[[2,5],[5,3]], "width":1}]}
	var session = SESSION.new()
	session.render_enabled = false
	if not session.setup(spec):
		failures.append("lift setup: "+session.last_error)
		session.dispose()
		return
	if blocker == "headroom": session.set_tile_material(5,1,"bedrock")
	var y: int = 3 if blocker == "deck" else 2
	# Submit the public movement while powder occupies its intended destination.
	# Preparation uses an SDK tick; the move must conserve even a moving layer.
	session.world.paint_rect(80,y*16+2,16,2,material)
	session.world.step(1)
	session.on_physics_tick()
	var before: int = session.material_count(Rect2i(0,0,160,112),material)
	var before_hash: String = session.world.get_state_hash()
	var moved: bool = session.move_platform(0)
	var result: Dictionary = load("res://sim/settle.gd").new().run(session.world)
	var after: int = session.material_count(Rect2i(0,0,160,112),material)
	var crate: Dictionary = session.grid.crates[0]
	var ok: bool = bool(result.ok) and before == 32 and after == 32 and moved == blocker.is_empty() and int(crate.x) == (5 if blocker.is_empty() else 2)
	cases.append({"mode":"lift", "material":material, "blocker":blocker, "before":before, "after":after, "moved":moved, "before_hash":before_hash, "ok":ok})
	if not ok: failures.append("lift/"+material+"/"+blocker)
	session.dispose()

func _mechanism(material: String, mode: String, blocked: bool) -> void:
	var spec: Dictionary = {"id":"powder-"+mode, "group":"thermal", "map":["##########", "#........#", "#PB....o.#", "##########"], "devices":[]}
	var destination := Vector2i(4,2)
	if mode == "mine_cart":
		spec.map = ["##########", "#........#", "#..B...o.#", "#.P......#", "##########"]
		spec.devices = [{"type":"mine_cart", "at":[3,3], "width":1, "track":[[3,3],[4,3],[5,3],[6,3]]}]
	if mode == "portal": destination = Vector2i(6,2)
	if mode == "fall": destination = Vector2i(3,2)
	var session = SESSION.new()
	session.render_enabled = false
	if not session.setup(spec):
		failures.append(mode + ": " + session.last_error)
		session.dispose()
		return
	if mode == "ice_slide":
		for x: int in range(3,7): session.set_tile_material(x,3,"ice")
	if mode == "fall":
		session.move_crate(0, Vector2i(3,1))
		load("res://sim/settle.gd").new().run(session.world)
	if blocked: session.set_tile_material(destination.x,1,"bedrock")
	session.world.paint_rect(destination.x*16, destination.y*16+(2 if mode == "mine_cart" else 14), 16, 2, material)
	session.world.step(1)
	session.on_physics_tick()
	if mode != "mine_cart": load("res://sim/settle.gd").new().run(session.world)
	var before: int = session.material_count(Rect2i(0,0,160,80),material)
	var result: Dictionary = {}
	var exact_offsets: bool = true
	if mode in ["ice_slide", "mine_cart"]:
		result = session.perform("R")
	elif mode == "portal":
		session.grid.devices.append({"type":"portal", "pads":[[2,2],[6,2]], "blocked":[]})
		var portal = load("res://gameplay/mechanics/portal.gd").new()
		portal.setup(spec,session)
		result.accepted = portal.on_settle_step()
	else:
		# Compare every material and local cell offset before SDK gravity resumes.
		var ids: PackedInt32Array = session.material_ids_view()
		result.accepted = session.move_crate(0,destination,"exchange")
		var moved: PackedInt32Array = session.material_ids_view()
		for y: int in range(32,48):
			for x: int in range(48,64):
				if ids[y*320+x] == int(session.world.material_ids[material]):
					exact_offsets = exact_offsets and moved[(y-16)*320+x] == ids[y*320+x]
	if mode in ["portal", "fall"]: load("res://sim/settle.gd").new().run(session.world)
	var after: int = session.material_count(Rect2i(0,0,160,80),material)
	var crate: Dictionary = session.grid.crates[0]
	var expected_x: int = 3 if blocked else 7
	if mode == "mine_cart": expected_x = 3 if blocked else 6
	if mode == "portal": expected_x = 2 if blocked else 6
	if mode == "fall": expected_x = 3
	var expected_accepted: bool = mode == "ice_slide" or not blocked
	var ok: bool = before == 32 and after == 32 and bool(result.get("accepted",false)) == expected_accepted and int(crate.x) == expected_x and exact_offsets
	if mode == "fall": ok = ok and int(crate.y) == 2
	if not str(result.get("error","")).is_empty(): ok = false
	cases.append({"mode":mode,"material":material,"blocked":blocked,"before":before,"after":after,"crate":crate.duplicate(),"local_offsets_preserved":exact_offsets if mode == "fall" else null,"result":{ "accepted":result.get("accepted"),"error":result.get("error","")},"ok":ok})
	if not ok: failures.append(mode + "/" + material + "/" + str(blocked))
	session.dispose()
