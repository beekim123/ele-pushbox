extends SceneTree
const Session := preload("res://pushbox/scripts/session.gd")
const Catalog := preload("res://pushbox/scripts/campaign_catalog.gd")
const Biome := preload("res://pushbox/scripts/biome_mechanisms.gd")
var rows: Array = []
var failures: Array = []

func _initialize() -> void:
	call_deferred("run")

func hit(trace: Dictionary, kind: String, detail: Dictionary = {}) -> void:
	if not trace.has(kind):
		trace[kind] = {"count":0,"first":detail}
	trace[kind].count += 1

func settle(s: RefCounted, trace: Dictionary, observe: bool) -> void:
	while s.running:
		if not observe:
			s.advance(4)
			continue
		if s.phase == Session.Phase.RESOLVE:
			if not s.board._round_active:
				s.board.begin_resolve_round()
				# Session increments this at the same point; retain that accounting.
				s.last_rounds += 1
			var item: Array = s.board._round_items[s.board._round_cursor]
			var kind: String = item[0]
			var before: Variant = item[1].duplicate(true) if item[1] is Dictionary else item[1]
			var commands: int = s.board._commands.size()
			var box_at := Vector2i(-1,-1)
			var inverted: bool = false
			if kind == "box":
				var box: Dictionary = s.board.boxes[item[1]]
				box_at = box.at
				inverted = Biome.gravity(s.board,box) < 0
				if box.kind == "wood" and Biome.cloud(s.board,box.at+Vector2i.DOWN):
					hit(trace,"cloud_wood_support",{"move":s.board.moves})
			s.advance_frame(1)
			var added: int = s.board._commands.size()-commands
			if kind in ["vine_seeds","hourglasses","scales","stalactites","geysers","freezers","teleporters","gravity_zones"]:
				if kind == "geysers":
					if added > 0:
						hit(trace,kind,{"move":s.board.moves,"commands":added})
				elif before != item[1] or added > 0:
					hit(trace,kind,{"move":s.board.moves,"commands":added})
			if kind == "box" and inverted and s.board.boxes[item[1]].at.y < box_at.y:
				hit(trace,"gravity_box_rise",{"move":s.board.moves})
			if kind == "gate" and before.open and not s.board.condition(before.open_when) and item[1].open:
				hit(trace,"gate_close_blocked",{"move":s.board.moves})
		else:
			var ticking: bool = s.phase == Session.Phase.TICKS
			s.advance_frame(1)
			if ticking and int(s.world.get_stats().get("pressure_moves",0)) > 0:
				hit(trace,"liquid_pressure",{"move":s.board.moves})

func replay(path: String, disabled: String = "") -> Dictionary:
	var s := Session.new()
	var reason: String = s.load_level(path,root)
	if not reason.is_empty():
		return {"load_error":reason,"won":false}
	var trace: Dictionary = {}
	if not disabled.is_empty():
		s.board.mechanisms.erase(disabled)
	settle(s,trace,disabled.is_empty())
	var initial_materials: Dictionary = {}
	for name in ["acid","cracked_rock","water","lava","pumice","ice","sand"]:
		initial_materials[name] = s.board.ids.count(s.board.name_ids[name])
	var completed: int = 0
	var mismatches: Array = []
	var illegal: Dictionary = {}
	for i in s.level.solution.size():
		var action: String = s.level.solution[i]
		if disabled.is_empty() and action.begins_with("POUR_"):
			var target: Vector2i = s.board.player + (Vector2i.RIGHT if action == "POUR_R" else Vector2i.LEFT)
			if Biome.poured_at(s.board,target) != target:
				hit(trace,"wind_pour_shift",{"move":s.board.moves+1})
		var result: Dictionary = s.perform(action)
		if not result.legal:
			illegal = {"step":i+1,"action":action,"reason":result.get("reason","")}
			break
		settle(s,trace,disabled.is_empty())
		completed += 1
		if disabled.is_empty() and (s.world.get_state_hash() != s.level.solution_hashes[i] or s.board.position_key() != s.level.solution_keys[i]):
			mismatches.append(i+1)
		if not s.errors.is_empty():
			break
	var final_materials: Dictionary = {}
	for name in initial_materials:
		final_materials[name] = s.board.ids.count(s.board.name_ids[name])
	var answer := {"won":s.board.won(),"completed_actions":completed,"author_actions":s.level.solution.size(),"hash_or_key_mismatches":mismatches,"illegal":illegal,"errors":Array(s.errors),"trace":trace,"initial_materials":initial_materials,"final_materials":final_materials,"final_mechanisms":s.board.mechanisms.duplicate(true)}
	s.dispose()
	return answer

func run() -> void:
	if OS.get_user_data_dir() != OS.get_environment("PUSHBOX_AUDIT_USER_DIR"):
		push_error("User directory isolation failed: "+OS.get_user_data_dir())
		quit(1)
		return
	for map_index in 6:
		for index in 6:
			var path: String = Catalog.path(map_index,index)
			var data: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(path))
			var baseline: Dictionary = replay(path)
			if not baseline.won or baseline.completed_actions != baseline.author_actions or not baseline.illegal.is_empty() or not baseline.hash_or_key_mismatches.is_empty() or not baseline.errors.is_empty():
				failures.append(data.id)
			var disabled_results: Dictionary = {}
			for kind in data.get("biome_mechanisms",{}):
				if not data.biome_mechanisms[kind].is_empty():
					disabled_results[kind] = replay(path,kind)
			rows.append({"id":data.id,"theme":data.theme_id,"baseline":baseline,"disabled":disabled_results})
			print("AUDIT ",data.id," won=",baseline.won," disabled=",disabled_results.keys())
			var output := FileAccess.open("res://evidence/runtime.json",FileAccess.WRITE)
			output.store_string(JSON.stringify({"complete":false,"levels":rows,"failures":failures},"  ")+"\n")
	var output := FileAccess.open("res://evidence/runtime.json",FileAccess.WRITE)
	output.store_string(JSON.stringify({"complete":true,"levels":rows,"failures":failures,"workers":1,"scope":"author-path replay and one-family-at-a-time ablation; not exhaustive solvability"},"  ")+"\n")
	print("AUDIT COMPLETE levels=",rows.size()," failures=",failures)
	quit(0 if failures.is_empty() else 1)
