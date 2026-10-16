extends RefCounted
const HINT_SOURCE = preload("res://tests/chapters/hint_source.gd")
## LV-08 isolated real-SDK cases. No source spec or shared service is changed.
const SESSION = preload("res://gameplay/session/level_session.gd")
const WORLD = preload("res://sim/ele_world.gd")
const MATERIALS = preload("res://sim/materials.gd")
const H = preload("res://tests/chapters/helpers.gd")

func _test(ok: bool, facts: Variant) -> Dictionary:
	return {"status":"pass" if ok else "fail", "ok":ok, "facts":facts}

func _missing(reason: String) -> Dictionary:
	return {"status":"not_run", "ok":false, "reason":reason}

func _open(spec: Dictionary) -> Variant:
	var context = SESSION.new()
	context.render_enabled = false
	if not context.setup(spec):
		var error: String = context.last_error
		context.dispose()
		return {"error":error}
	return context

func _count(context, material: String, tile: Vector2i = Vector2i(-1,-1)) -> int:
	var area: Rect2i = Rect2i(0,0,context.width * 16,context.height * 16) if tile.x < 0 else context.cell_rect(tile.x,tile.y)
	return context.world.count_material(material,area)

func _play(context, actions: Array) -> Dictionary:
	var results: Array[Dictionary] = []
	for action: String in actions:
		var result: Dictionary = context.perform(action)
		result["tick_hash_count"] = result.get("hashes",[]).size()
		result.erase("hashes")
		results.append(result)
		if not bool(result.get("accepted",false)) or not str(result.get("error","")).is_empty():
			return {"ok":false,"results":results,"state":context.state(),"error":result}
	return {"ok":true,"results":results,"state":context.state(),"won":context.is_won()}

func _crate(context, kind: String) -> Dictionary:
	for crate: Dictionary in context.grid.crates:
		if str(crate.kind) == kind:
			return crate.duplicate(true)
	return {}

func _at(value: Dictionary, x: int, y: int) -> bool:
	return H.point([value.get("x"),value.get("y")],x,y)

func run_for(spec: Dictionary) -> Dictionary:
	match str(spec.id):
		"F01": return {"blocked_before_burn":_f01_blocked(spec),"torch_geometry":_circle_boundary(spec),"sdk_burn_spread":_burn_spread()}
		"F02": return _f02_cases(spec)
		"F03": return {"early_melt":_f03_early(spec)}
		"F04": return {"diagonal_blast":_f04_diagonal(spec),"wood_material":_wood_definition(spec)}
		"F07": return {"remove_brake":_f07_remove_brake(spec),"slide_boundaries":_slide_boundaries()}
		"F08": return {"wrong_ladder":_f08_wrong_ladder(spec),"gust_non_actions":_gust_non_actions(spec),"hint_ui":_hint_ui(spec)}
		"F09": return {"unfrozen_iron":_f09_without_freeze(spec),"no_brake":_f09_no_brake(spec),"premature_sand":_f09_early_sand(spec)}
	return {}

func _f01_blocked(spec: Dictionary) -> Dictionary:
	var context = _open(spec)
	if context is Dictionary: return _missing(str(context.error))
	var route: Dictionary = _play(context,["R","R"])
	var blocked: Dictionary = context.perform("R")
	var facts: Dictionary = {"route":route,"attempt":blocked,"wood":_count(context,"wood"),"crate":_crate(context,"wood"),"player":context.grid.player.duplicate()}
	var passed: bool = route.ok and not bool(blocked.get("accepted",false)) and _count(context,"wood") == 512 and _at(_crate(context,"wood"),6,2) and not context.is_won()
	context.dispose()
	return _test(passed,facts)

func _circle_boundary(spec: Dictionary) -> Dictionary:
	# Keep the real temperature layer but disable diffusion in this disposable
	# SDK profile. Exact command footprint is otherwise obscured by thermal flow.
	var context = _open(spec)
	if context is Dictionary: return _missing(str(context.error))
	var world = context.world
	var profile: Dictionary = world.profile.duplicate(true)
	profile.solvers = [{"name":"cells"}]
	var path: String = world.storage_dir.path_join("thermal-circle-profile.json")
	var file = FileAccess.open(path,FileAccess.WRITE)
	if file == null:
		world.dispose()
		return _missing("Cannot write isolated circle profile")
	file.store_string(JSON.stringify(profile))
	file.close()
	world.node.call("stop")
	world.node.set("profile_path",path)
	if int(world.node.call("start")) != 0:
		var error: String = str(world.node.call("get_last_error"))
		world.dispose()
		return _missing(error)
	var device_ok: bool = context.trigger_device(0)
	var errors: Array[int] = [world.step(1)]
	var probes: Array[Dictionary] = []
	var passed: bool = device_ok and errors == [0]
	for point: Vector2i in [Vector2i(104,64),Vector2i(88,64),Vector2i(120,64),Vector2i(104,48),Vector2i(104,80),Vector2i(88,48),Vector2i(121,64)]:
		var expected: int = 6000 if point.distance_squared_to(Vector2i(104,64)) <= 256 else 2344
		var actual: int = world.layer_value("temperature",point.x,point.y)
		probes.append({"cell":[point.x,point.y],"expected":expected,"actual":actual})
		passed = passed and actual == expected
	context.dispose()
	return _test(passed,{"device_trigger":device_ok,"errors":errors,"isolated_without_diffusion":true,"probes":probes})

func _burn_spread() -> Dictionary:
	var world = WORLD.new()
	if not world.open(1,false,{"group":"thermal","profile":["cells","thermal"]}):
		var error: String = world.last_error
		world.dispose()
		return _missing(error)
	var commands_ok: bool = world.paint_rect(64,64,48,16,"wood") == 0 and world.paint_rect(64,96,16,16,"crate") == 0 and world.paint_rect(96,96,16,16,"bedrock") == 0 and world.paint_layer_circle("temperature",72,72,4,6000) == 0
	var lit: bool = false
	var propagated: bool = false
	var first_lit: int = -1
	var first_spread: int = -1
	var burned_out: int = -1
	for tick: int in range(1,241):
		if world.step(1) != 0:
			commands_ok = false
			break
		if bool(world.get_cell(72,72).get("burning",false)):
			lit = true
			if first_lit < 0: first_lit = tick
		if bool(world.get_cell(104,72).get("burning",false)):
			propagated = true
			if first_spread < 0: first_spread = tick
		if world.count_material("wood",Rect2i(64,64,48,16)) == 0 and burned_out < 0:
			burned_out = tick
	var counts: Dictionary = {"wood":world.count_material("wood",Rect2i(64,64,48,16)),"crate":world.count_material("crate",Rect2i(64,96,16,16)),"bedrock":world.count_material("bedrock",Rect2i(96,96,16,16))}
	world.dispose()
	return _test(commands_ok and lit and propagated and counts.wood == 0 and counts.crate == 256 and counts.bedrock == 256,{"first_lit":first_lit,"first_spread_outside_circle":first_spread,"burned_out_tick":burned_out,"counts":counts})

func _f02_cases(spec: Dictionary) -> Dictionary:
	var context = _open(spec)
	if context is Dictionary: return {"unfrozen_return":_missing(str(context.error)),"coupler_first_tick":_missing(str(context.error))}
	var into_pool: Dictionary = _play(context,["R"])
	var submerged: bool = int(context.grid.player.y) >= 4
	var return_route: Dictionary = _play(context,["L","U","U","L"])
	var return_ok: bool = into_pool.ok and submerged and return_route.ok and _at(context.grid.player,2,3)
	var negative: Dictionary = _test(return_ok,{"into_pool":into_pool,"return":return_route})
	context.dispose()
	context = _open(spec)
	if context is Dictionary: return {"unfrozen_return":negative,"coupler_first_tick":_missing(str(context.error))}
	var prefix: Dictionary = _play(context,["L"])
	var samples: Array[Dictionary] = []
	var original_observer: Callable = context.world.tick_observer
	context.world.tick_observer = func() -> void:
		original_observer.call()
		if samples.is_empty():
			samples.append({"ice":_count(context,"ice"),"water":_count(context,"water"),"frost_value":context.world.layer_value("frost",56,72),"ladder":context.grid.is_ladder(3,4),"profile":context.world.profile.duplicate(true)})
	var action: Dictionary = context.perform("U")
	var first: Dictionary = samples[0] if not samples.is_empty() else {}
	var accepted: bool = prefix.ok and bool(action.get("accepted",false)) and str(action.get("error","")).is_empty()
	var result: Dictionary = _test(accepted and int(first.get("ice",-1)) == 1024 and int(first.get("water",-1)) == 1024 and bool(first.get("ladder",false)),{"first_tick":first,"action":action,"frost_after":context.world.layer_value("frost",56,72)})
	context.dispose()
	return {"unfrozen_return":negative,"coupler_first_tick":result}

func _f03_early(spec: Dictionary) -> Dictionary:
	var context = _open(spec)
	if context is Dictionary: return _missing(str(context.error))
	var action: Dictionary = _play(context,["U"])
	var crate: Dictionary = _crate(context,"wood")
	var facts: Dictionary = {"action":action,"crate":crate,"water":_count(context,"water"),"ice":_count(context,"ice"),"crate_cells":_count(context,"crate"),"bin_water":_count(context,"water",Vector2i(4,6)),"goals":context.goal_lights()}
	# In this one-cell shaft a single water tile's floating box cannot reach
	# y=3; the closed walls and lack of upward crate actions make it trapped.
	var passed: bool = action.ok and _at(crate,4,5) and _count(context,"crate") == 256 and _count(context,"water",Vector2i(4,6)) == 256 and _count(context,"water") == 256 and _count(context,"ice") == 0 and not context.is_won()
	context.dispose()
	return _test(passed,facts)

func _f04_diagonal(spec: Dictionary) -> Dictionary:
	var context = _open(spec)
	if context is Dictionary: return _missing(str(context.error))
	var route: Dictionary = _play(context,["R","R"])
	var before: Dictionary = context.grid.player.duplicate()
	var action: Dictionary = context.perform("BOMB_R")
	var facts: Dictionary = {"route":route,"origin":before,"action":action,"wood":_count(context,"wood"),"bomb":context.grid.bag.bomb,"won":context.is_won()}
	var passed: bool = route.ok and _at(before,4,4) and bool(action.get("accepted",false)) and _count(context,"wood") == 512 and int(context.grid.bag.bomb) == 0 and not context.is_won()
	context.dispose()
	return _test(passed,facts)

func _wood_definition(spec: Dictionary) -> Dictionary:
	for material: Dictionary in MATERIALS.definitions(spec).materials:
		if str(material.name) == "wood":
			return _test(int(material.get("blast_resistance",0)) == 65535 and material.has("burnable"),{"registered_material_definition":material,"source":"sim/materials.gd"})
	return _missing("wood material definition unavailable")

func _f07_remove_brake(spec: Dictionary) -> Dictionary:
	var context = _open(spec)
	if context is Dictionary: return _missing(str(context.error))
	var route: Dictionary = _play(context,["DIG_L","L","L","L","L","L"])
	var crate: Dictionary = _crate(context,"wood")
	var facts: Dictionary = {"route":route,"crate":crate,"earth":_count(context,"packed_earth",Vector2i(8,3)),"won":context.is_won()}
	var passed: bool = route.ok and _at(crate,1,3) and _count(context,"packed_earth",Vector2i(8,3)) == 0 and not context.is_won()
	context.dispose()
	return _test(passed,facts)

func _slide_boundaries() -> Dictionary:
	var fixture: Dictionary = {"id":"SDK-THERMAL-ICE-EDGE","group":"thermal","map":["##########","#PB.....o#","###iii####","##########"],"mechanisms":["ice_slide"],"profile":["cells"],"bag":{"sand":0,"bomb":0}}
	var context = _open(fixture)
	if context is Dictionary: return _missing(str(context.error))
	var action: Dictionary = context.perform("R")
	var dry_ok: bool = bool(action.get("accepted",false)) and _at(_crate(context,"wood"),6,1) and _at(context.grid.player,2,1) and _count(context,"crate") == 256
	var facts: Dictionary = {"dry_edge_action":action,"dry_edge_state":context.state(),"crate_cells":_count(context,"crate")}
	context.dispose()
	fixture.map = ["##########","#PB..I...#","###iiiii##","##########"]
	context = _open(fixture)
	if context is Dictionary: return _missing(str(context.error))
	action = context.perform("R")
	var chain_ok: bool = bool(action.get("accepted",false)) and _at(_crate(context,"wood"),4,1) and _at(_crate(context,"iron"),5,1) and _count(context,"crate") == 256 and _count(context,"iron_crate") == 256
	facts["blocked_action"] = action
	facts["blocked_state"] = context.state()
	facts["iron_cells"] = _count(context,"iron_crate")
	context.dispose()
	return _test(dry_ok and chain_ok,facts)

func _f08_wrong_ladder(spec: Dictionary) -> Dictionary:
	var context = _open(spec)
	if context is Dictionary: return _missing(str(context.error))
	var route: Dictionary = _play(context,["U","U","L","L","L"])
	var wood: Dictionary = _crate(context,"wood")
	var iron: Dictionary = _crate(context,"iron")
	var passed: bool = route.ok and _at(wood,8,4) and _at(iron,9,3) and not context.is_won()
	var facts: Dictionary = {"route":route,"wood":wood,"iron":iron,"goals":context.goal_lights()}
	context.dispose()
	return _test(passed,facts)

func _gust_non_actions(spec: Dictionary) -> Dictionary:
	var context = _open(spec)
	if context is Dictionary: return _missing(str(context.error))
	var before: Dictionary = context.state()
	var hash_before: String = context.world.get_state_hash()
	context.observe()
	context.goal_lights()
	var invalid: Dictionary = context.perform("R")
	var passed: bool = not bool(invalid.get("accepted",false)) and context.state() == before and context.world.get_state_hash() == hash_before
	var facts: Dictionary = {"opening_wood":_crate(context,"wood"),"invalid":invalid,"state_unchanged":context.state() == before,"hash_unchanged":context.world.get_state_hash() == hash_before}
	context.dispose()
	return _test(passed,facts)

func _f09_without_freeze(spec: Dictionary) -> Dictionary:
	var context = _open(spec)
	if context is Dictionary: return _missing(str(context.error))
	var route: Dictionary = _play(context,["L","U","L","L","R","R","R"])
	var iron: Dictionary = _crate(context,"iron")
	var passed: bool = route.ok and int(iron.get("y",-1)) >= 5 and not context.is_won() and _count(context,"iron_crate") == 256
	var facts: Dictionary = {"route":route,"iron":iron,"ice":_count(context,"ice"),"water":_count(context,"water")}
	context.dispose()
	return _test(passed,facts)

func _f09_no_brake(spec: Dictionary) -> Dictionary:
	var context = _open(spec)
	if context is Dictionary: return _missing(str(context.error))
	var route: Dictionary = _play(context,["U","L","U","L","L","R","R","R"])
	var iron: Dictionary = _crate(context,"iron")
	var passed: bool = route.ok and _at(iron,8,3) and not context.is_won()
	var facts: Dictionary = {"route":route,"iron":iron,"ice":_count(context,"ice"),"sand":_count(context,"sand")}
	context.dispose()
	return _test(passed,facts)

func _f09_early_sand(spec: Dictionary) -> Dictionary:
	var context = _open(spec)
	if context is Dictionary: return _missing(str(context.error))
	var route: Dictionary = _play(context,["POUR_R"])
	var bottom_sand: int = 0
	for x: int in range(6,9): bottom_sand += _count(context,"sand",Vector2i(x,5))
	var facts: Dictionary = {"route":route,"bottom_sand":bottom_sand,"brake_sand":_count(context,"sand",Vector2i(8,3)),"all_sand":_count(context,"sand"),"water":_count(context,"water")}
	var passed: bool = route.ok and bottom_sand >= 128 and _count(context,"sand",Vector2i(8,3)) < 128 and _count(context,"sand") == 256
	context.dispose()
	return _test(passed,facts)


func _hint_ui(spec: Dictionary) -> Dictionary:
	var path: String = "res://tests/results/thermal-hint-ui.json"
	if not FileAccess.file_exists(path): return _missing("Run thermal_hint_ui.gd against the current imported F08 first")
	var value: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	if not value is Dictionary: return _missing("Hint UI evidence is not a JSON object")
	if str(value.get("source_sha256","")) != HINT_SOURCE.fingerprint(): return _missing("Hint UI evidence source SHA does not match the current code")
	var bytes: PackedByteArray = FileAccess.get_file_as_bytes("res://generated/content/levels/lab/thermal/" + str(spec.id) + ".json")
	var digest := HashingContext.new()
	digest.start(HashingContext.HASH_SHA256)
	digest.update(bytes)
	var expected: String = digest.finish().hex_encode()
	if str(value.get("spec_sha256","")) != expected: return _missing("Hint UI evidence spec SHA does not match the current imported level")
	var passed: bool = str(value.get("format","")) == "portitor.thermal-hint-ui/1" and str(value.get("runtime","")) == "real-ele-sdk" and str(value.get("id","")) == str(spec.id) and bool(value.get("ok",false)) and value.get("checks",[]).size() == 3
	for item: Dictionary in value.get("checks",[]):
		passed = passed and bool(item.get("ok",false)) and item.get("before",{}) == item.get("after",{})
	return _test(passed,{"evidence":path,"result":value})
