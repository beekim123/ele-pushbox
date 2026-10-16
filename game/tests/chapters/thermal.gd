extends RefCounted
## Each returned row retains an original spec.checks text and all sub-evidence.
## Passing the author route never substitutes for burning/coupler/negative checks.
const H = preload("res://tests/chapters/helpers.gd")
const CASES = preload("res://tests/chapters/thermal_cases.gd")

func _assert(name: String, passed: bool, facts: Variant, available: bool = true) -> Dictionary:
	return {"name":name,"ok":available and passed,"status":("pass" if passed else "fail") if available else "not_run","facts":facts}

func _position(value: Dictionary, x: int, y: int) -> bool:
	return H.point([value.get("x"),value.get("y")],x,y)

func _box(value: Dictionary, x: int, y: int) -> bool:
	for crate: Dictionary in value.get("state",{}).get("crates",[]):
		if _position(crate,x,y): return true
	return false

func _player(value: Dictionary, x: int, y: int) -> bool:
	return _position(value.get("state",{}).get("player",{}),x,y)

func _case(name: String, isolated: Dictionary) -> Dictionary:
	var result: Dictionary = isolated.get(name,{"status":"not_run","ok":false,"reason":"Isolated case did not produce evidence"}).duplicate(true)
	result["name"] = name
	return result

func _row(text: String, assertions: Array) -> Dictionary:
	var status: String = "pass"
	for item: Dictionary in assertions:
		if str(item.get("status","not_run")) == "fail": status = "fail"
		elif str(item.get("status","not_run")) == "not_run" and status != "fail": status = "not_run"
	if assertions.is_empty(): status = "not_run"
	return {"text":text,"ok":status == "pass","status":status,"detail":assertions}

func _common(summary: Dictionary, runs: Array) -> Dictionary:
	return _assert("three_runs_undo_restart_limits",H.common(summary) and bool(summary.get("complete_actions",false)) and runs.size() == 3,{"won":summary.get("won"),"consistent":summary.get("consistent"),"undo_ok":summary.get("undo_ok"),"restart_ok":summary.get("restart_ok"),"complete_actions":summary.get("complete_actions"),"max_ticks":summary.get("max_ticks"),"max_rounds":summary.get("max_rounds"),"runs":runs})

func _cells_preserved(trace: Array, material: String, count: int) -> bool:
	if trace.is_empty(): return false
	for step: Dictionary in trace:
		if H.material(step.actual,material) != count: return false
	return true

func _burn_history(summary: Dictionary, point: Vector2i) -> Dictionary:
	var first_lit: int = -1
	var first_empty: int = -1
	var samples: int = 0
	var raw_lit: Dictionary = {}
	for entry: Dictionary in summary.get("physics",[]):
		samples += 1
		for probe: Dictionary in entry.get("cells",[]):
			if H.point(probe.get("tile",[]),point.x,point.y) and bool(probe.get("cell",{}).get("burning",false)) and first_lit < 0:
				first_lit = int(entry.tick)
				raw_lit = probe.cell.duplicate(true)
		if first_lit >= 0 and int(entry.get("materials",{}).get("wood",-1)) == 0 and first_empty < 0:
			first_empty = int(entry.tick)
	return {"first_burning_tick":first_lit,"first_all_wood_empty_tick":first_empty,"sample_count":samples,"burning_cell":raw_lit}

func _all_ice(trace: Array, from_step: int, first_x: int, last_x: int, y: int, total: int) -> bool:
	if trace.size() <= from_step: return false
	for index: int in range(from_step,trace.size()):
		var value: Dictionary = H.sample(trace,index)
		if H.material(value,"ice") != total: return false
		for x: int in range(first_x,last_x + 1):
			if H.tile(value,x,y,"ice") < 128: return false
	return true

func _crate_foot_is_dry(trace: Array) -> bool:
	for index: int in range(1,trace.size()):
		var previous: Array = H.sample(trace,index - 1).get("state",{}).get("crates",[])
		var current: Array = H.sample(trace,index).get("state",{}).get("crates",[])
		if previous.size() != 1 or current.size() != 1: return false
		if previous[0].x != current[0].x and H.tile(H.sample(trace,index),int(current[0].x),int(current[0].y) + 1,"bedrock") != 256: return false
		for observation: Dictionary in H.sample(trace,index).get("observe",[]):
			if str(observation.get("type","")) == "ice_slide" and not observation.get("last_slide",{}).is_empty(): return false
	return true

func _gust_steps(trace: Array) -> Dictionary:
	var facts: Array[Dictionary] = []
	var ok: bool = trace.size() > 1
	for index: int in range(trace.size()):
		var value: Dictionary = H.sample(trace,index)
		var wood: Dictionary = {}
		var iron: Dictionary = {}
		for crate: Dictionary in value.get("state",{}).get("crates",[]):
			if str(crate.kind) == "wood": wood = crate
			if str(crate.kind) == "iron": iron = crate
		var expected_x: int = mini(3 + index,7)
		var step_ok: bool = _position(wood,expected_x,4) and H.material(value,"crate") == 256 and H.material(value,"iron_crate") == 256
		if index > 0: step_ok = step_ok and _position(iron,8,4)
		else: step_ok = step_ok and _position(iron,9,3)
		ok = ok and step_ok
		facts.append({"step":index,"wood":wood,"iron":iron,"expected_wood_x":expected_x,"ok":step_ok})
	return _assert("gust_once_per_legal_action_light_kind_and_occupancy",ok,facts)

func evaluate(spec: Dictionary, trace: Array, runs: Array, summary: Dictionary) -> Array[Dictionary]:
	var rows: Array[Dictionary] = []
	if trace.is_empty():
		for text: String in spec.get("checks",[]): rows.append(_row(text,[_assert("setup",false,"No successful opening SDK sample was produced",false)]))
		return rows
	var isolated: Dictionary = CASES.new().run_for(spec)
	var opening: Dictionary = H.sample(trace,0)
	var final: Dictionary = H.sample(trace)
	var common: Dictionary = _common(summary,runs)
	var body: Array = []
	match str(spec.id):
		"F01":
			var history: Dictionary = _burn_history(summary,Vector2i(6,3))
			var burned: bool = int(history.first_burning_tick) >= 0 and int(history.first_all_wood_empty_tick) > int(history.first_burning_tick)
			var before_fire: Dictionary = H.sample(trace,1)
			var after_fire: Dictionary = H.sample(trace,2)
			var phase_used: int = int(history.first_all_wood_empty_tick) - int(before_fire.get("tick",0))
			body = [
				[_assert("author_8_and_positions",spec.solution.size() == 8 and bool(summary.won) and _box(final,6,5) and _player(final,8,3),{"steps":spec.solution.size(),"final":final.state}),_case("blocked_before_burn",isolated)],
				[_assert("sdk_burning_then_empty",burned and H.material(after_fire,"wood") == 0,history),_assert("crate_and_bedrock_preserved",_cells_preserved(trace,"crate",256) and _cells_preserved(trace,"bedrock",H.material(opening,"bedrock")),{"opening":opening.materials,"final":final.materials}),_case("torch_geometry",isolated),_case("sdk_burn_spread",isolated)],
				[_assert("burnout_within_authored_phase",burned and phase_used > 0 and phase_used <= 180 and H.material(after_fire,"wood") == 0,{"phase_ticks":180,"observed_burnout_offset":phase_used,"action_result":trace[2].get("result",{})} if trace.size() > 2 else history),common]
			]
		"F02":
			var frozen: Dictionary = H.sample(trace,2)
			body = [
				[_assert("author_8_exit",spec.solution.size() == 8 and bool(summary.won) and _player(final,8,3),final.state),_case("unfrozen_return",isolated)],
				[_case("coupler_first_tick",isolated),_assert("frozen_top_and_outside_water_preserved",H.material(frozen,"ice") == 1024 and H.material(frozen,"water") == 1024 and _all_ice(trace,2,3,6,4,1024),{"after_freeze":frozen.get("materials",{}),"final":final.materials})],
				[_assert("ice_support_marker_and_no_auto_melt",_all_ice(trace,2,3,6,4,1024) and H.material(final,"water") == 1024 and _player(final,8,3),{"final":final.state,"ice":H.material(final,"ice")}),common]
			]
		"F03":
			body = [
				[_assert("author_9_all_lamps",spec.solution.size() == 9 and bool(summary.won) and _box(final,6,3),final.state),_case("early_melt",isolated)],
				[_assert("ice_water_equal_conversion_bin",H.material(opening,"ice") == 256 and H.material(final,"ice") == 0 and H.material(final,"water") == 256 and H.tile(final,4,6,"water") == 256,{"opening":opening.materials,"final":final.materials,"bin":H.tile(final,4,6,"water")}),_case("early_melt",isolated)],
				[_assert("push_destinations_bedrock_no_slide",_crate_foot_is_dry(trace),{"trace_steps":trace.size()}),common]
			]
		"F04":
			var lower: Dictionary = _burn_history(summary,Vector2i(6,3))
			var upper: Dictionary = _burn_history(summary,Vector2i(6,2))
			var blast_after: Dictionary = H.sample(trace,4)
			var blast_before: Dictionary = H.sample(trace,3)
			var first_empty: int = int(lower.first_all_wood_empty_tick)
			var offset: int = first_empty - int(blast_before.get("tick",0))
			var sequence_ok: bool = int(lower.first_burning_tick) >= 0 and int(upper.first_burning_tick) > int(lower.first_burning_tick) and first_empty > int(upper.first_burning_tick)
			body = [
				[_assert("author_8_exit_bomb_spent",spec.solution.size() == 8 and bool(summary.won) and _player(final,9,3) and int(final.state.get("bag",{}).get("bomb",-1)) == 0,final.state),_case("diagonal_blast",isolated)],
				[_assert("surviving_wood_burns_then_spreads_up",sequence_ok and H.material(blast_after,"wood") == 0,{"lower":lower,"upper":upper,"post_blast":blast_after.get("materials",{})}),_assert("bedrock_blast_origin_preserved",H.tile(blast_after,6,4,"bedrock") == 256 and _cells_preserved(trace,"bedrock",H.material(opening,"bedrock")),{"origin_bedrock":H.tile(blast_after,6,4,"bedrock")})],
				[_case("wood_material",isolated),_assert("burnout_within_authored_180",sequence_ok and offset > 0 and offset <= 180,{"burnout_offset":offset,"phase_ticks":180}),common]
			]
		"F07":
			body = [
				[_assert("author_13_keeps_brake_and_positions",spec.solution.size() == 13 and bool(summary.won) and _box(final,7,3) and _player(final,4,3) and H.tile(final,8,3,"packed_earth") == 256,{"final":final.state,"earth":H.tile(final,8,3,"packed_earth")})],
				[_case("remove_brake",isolated)],
				[_case("slide_boundaries",isolated),_assert("crate_footprints_not_duplicated",_cells_preserved(trace,"crate",256),{"final_crate_cells":H.material(final,"crate")}),common]
			]
		"F08":
			body = [
				[_assert("author_10_three_lamps",spec.solution.size() == 10 and bool(summary.won) and _box(final,7,4) and _box(final,8,4) and _player(final,2,1),final.state),_case("wrong_ladder",isolated)],
				[_gust_steps(trace),_assert("first_iron_fall_then_wood_gust",_box(H.sample(trace,1),8,4) and _box(H.sample(trace,1),4,4),H.sample(trace,1).get("state",{}))],
				[_case("gust_non_actions",isolated),_case("hint_ui",isolated),common]
			]
		"F09":
			var frozen: Dictionary = H.sample(trace,1)
			var brake: Dictionary = H.sample(trace,4)
			body = [
				[_assert("author_13_brake_box_and_player",spec.solution.size() == 13 and bool(summary.won) and _box(final,7,3) and _player(final,5,3) and H.tile(final,8,3,"sand") >= 128,{"final":final.state,"brake_sand":H.tile(final,8,3,"sand")}),_case("unfrozen_iron",isolated),_case("no_brake",isolated)],
				[_assert("freeze_768_and_lower_water",H.material(frozen,"ice") == 768 and H.material(frozen,"water") == 768 and _all_ice(trace,1,6,8,4,768),{"after_freeze":frozen.get("materials",{})}),_assert("wall_brake_sand_threshold_stable",H.tile(brake,8,3,"sand") >= 128 and H.tile(final,8,3,"sand") >= 128 and _cells_preserved(trace.slice(4),"sand",256),{"after_pour":H.tile(brake,8,3,"sand"),"final":H.tile(final,8,3,"sand"),"all_sand":H.material(final,"sand")}),_case("premature_sand",isolated)],
				[_case("unfrozen_iron",isolated),_case("no_brake",isolated),_assert("ice_slide_and_sand_stop",_box(final,7,3) and H.tile(final,8,3,"sand") >= 128 and _cells_preserved(trace,"iron_crate",256),final.state)],
				[common]
			]
	for index: int in range(spec.get("checks",[]).size()):
		var assertions: Array = body[index] if index < body.size() else []
		rows.append(_row(str(spec.checks[index]),assertions))
	return rows
