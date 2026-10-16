extends RefCounted
## LV-06 specification assertions over measured SDK states and isolated branches.
const H = preload("res://tests/chapters/helpers.gd")
const LAMP_CASES = preload("res://tests/chapters/lamp_cases.gd")

func evaluate(spec: Dictionary, trace: Array, _runs: Array, summary: Dictionary) -> Array[Dictionary]:
	var rows: Array[Dictionary] = []
	var opening: Dictionary = H.sample(trace,0)
	var final: Dictionary = H.sample(trace)
	var bomb: Dictionary = H.action(trace,"BOMB_R")
	var common: bool = H.common(summary)
	match str(spec.id):
		"Q01":
			var lure: Dictionary = H.branch(spec,["R","R","BOMB_R"])
			rows.append(H.row(spec.checks[0], H.tile(bomb,4,2,"cracked_rock") == 0 and H.tile(bomb,5,3,"cracked_rock") >= 128, {"high_blast":bomb}, not bomb.is_empty()))
			rows.append(H.row(spec.checks[1], lure.get("accepted_steps",0) == 3 and H.box(lure.get("final",{}),5,3), {"low_blast":lure}))
			rows.append(H.row(spec.checks[2], H.box(final,8,2) and common, summary))
		"Q02":
			var lure: Dictionary = H.branch(spec,["R","R","U","U","BOMB_R"])
			rows.append(H.row(spec.checks[0], H.tile(bomb,4,3,"bedrock") == 256 and H.tile(bomb,5,3,"cracked_rock") == 0 and H.tile(lure.get("final",{}),5,3,"cracked_rock") >= 128, {"author":bomb,"low_lure":lure}, not bomb.is_empty()))
			rows.append(H.row(spec.checks[1], H.box(final,5,6) and H.player(final,2,2) and bool(summary.won), final))
			rows.append(H.row(spec.checks[2], bool(summary.complete_actions) and bool(summary.undo_ok) and bool(summary.restart_ok) and bool(summary.limits_ok), summary))
		"Q03":
			var burning: bool = false
			for tick: Dictionary in summary.physics:
				for probe: Dictionary in tick.cells:
					burning = burning or bool(probe.cell.get("burning",false))
			var right_clear: bool = not bomb.is_empty()
			for y: int in range(spec.map.size()):
				for x: int in range(str(spec.map[y]).length()):
					if x >= 4 and str(spec.map[y]).substr(x,1) == "f": right_clear = right_clear and H.tile(bomb,x,y,"fuse") == 0
			rows.append(H.row(spec.checks[0], burning and right_clear and H.tile(bomb,8,3,"cracked_rock") == 0, {"burning_sampled":burning,"right_fuse_clear":right_clear,"endpoint":bomb}, not bomb.is_empty()))
			var lure: Dictionary = H.branch(spec,["BOMB_L"])
			rows.append(H.row(spec.checks[1], lure.get("accepted_steps",0) == 1 and H.tile(lure.get("final",{}),8,3,"cracked_rock") == H.tile(opening,8,3,"cracked_rock"), lure))
			var blast_index: int = -1
			for index: int in range(trace.size()):
				if str(trace[index].action) == "BOMB_R": blast_index = index; break
			var start_tick: int = int(H.sample(trace,blast_index-1).get("tick",-1)) if blast_index > 0 else -1
			var phase: int = int(spec.get("phase_ticks",480))
			var boundary: Dictionary = {}
			var first_clear_elapsed: int = -1
			for tick: Dictionary in summary.physics:
				if int(tick.get("move",-1)) != blast_index: continue
				var remaining: int = 0
				for probe: Dictionary in tick.get("fuse_tiles",[]):
					if int(probe.tile[0]) >= 4: remaining += int(probe.count)
				if int(tick.tick) <= start_tick + phase: boundary = {"tick":tick.tick,"right_fuse_cells":remaining,"whole_fuse_cells":tick.materials.get("fuse",0)}
				if remaining == 0 and first_clear_elapsed < 0: first_clear_elapsed = int(tick.tick) - start_tick
			var stage_ok: bool = not boundary.is_empty() and int(boundary.right_fuse_cells) == 0 and first_clear_elapsed >= 0 and first_clear_elapsed <= phase
			rows.append(H.row(spec.checks[2], stage_ok and right_clear and bool(summary.limits_ok), {"phase_ticks":phase,"blast_start_tick":start_tick,"at_phase_boundary":boundary,"first_right_clear_elapsed":first_clear_elapsed,"final_right_clear":right_clear,"max_ticks":summary.max_ticks,"max_rounds":summary.max_rounds}, not boundary.is_empty()))
			rows.append(H.row(spec.checks[3], common, summary))
		"Q04":
			var in_bin: int = H.tile(final,6,4,"gravel") + H.tile(final,6,5,"gravel")
			rows.append(H.row(spec.checks[0], H.material(opening,"gravel") == 512 and H.material(final,"gravel") == 512 and in_bin == 512 and bool(H.device(final,"bin").get("latched",false)), {"bin_gravel":in_bin,"final":final}))
			rows.append(H.row(spec.checks[1], bool(summary.won) and H.tile(bomb,6,4,"gravel") >= 128, {"support_after_blast":H.tile(bomb,6,4,"gravel"),"won":summary.won}, not bomb.is_empty()))
			var lure: Dictionary = H.branch(spec,["R","R","R","BOMB_R","L","U","U","BOMB_R"])
			var remaining: int = H.tile(lure.get("final",{}),6,4,"gravel") + H.tile(lure.get("final",{}),6,5,"gravel")
			rows.append(H.row(spec.checks[2], lure.get("accepted_steps",0) == 8 and remaining < 512 and not bool(lure.get("won",false)), {"settled_bin_gravel":remaining,"branch":lure}))
			rows.append(H.row(spec.checks[3], H.player(final,9,3) and common, summary))
		"Q07":
			var loaded: Dictionary = H.sample(trace,3)
			var rolled: Dictionary = H.sample(trace,8)
			rows.append(H.row(spec.checks[0], H.box(loaded,6,4) and H.point(H.device(loaded,"mine_cart").get("at",[]),6,5) and H.box(rolled,10,4) and H.point(H.device(rolled,"mine_cart").get("at",[]),10,5) and H.player(rolled,6,5), {"loaded":loaded,"rolled":rolled}, trace.size() > 8))
			var lure: Dictionary = H.branch(spec,["R","R","D","D","R","R"])
			rows.append(H.row(spec.checks[1], lure.get("accepted_steps",0) == 6 and not H.box(lure.get("final",{}),10,4) and not bool(lure.get("won",false)), {"empty_cart_branch":lure,"scope":"Measured specified lure; design-model continuation census supplies topology, not SDK exhaustive search."}))
			rows.append(H.row(spec.checks[2], common and H.material(final,"crate") == 256, {"summary":summary,"crate_cells":H.material(final,"crate"),"scope":"SDK cell ownership and complete undo; dynamic burning/lifetime prohibition covered by gameplay safety tests."}))
		"Q08":
			var lit: bool = false
			var dark: bool = false
			for entry: Dictionary in trace:
				var value: Dictionary = entry.actual
				if value.is_empty(): continue
				var p: Dictionary = value.state.player
				var expected: bool = (int(p.x)-5)*(int(p.x)-5)+(int(p.y)-4)*(int(p.y)-4) <= 4
				var owned: bool = H.tile(value,5,4,"bedrock") == 256
				lit = lit or expected and owned
				dark = dark or not expected and not owned
			rows.append(H.row(spec.checks[0], lit and dark, {"lit_and_dark_observed":[lit,dark]}))
			var held: bool = false
			for entry: Dictionary in trace: held = held or H.box(entry.actual,5,3)
			rows.append(H.row(spec.checks[1], held and H.box(final,5,6), {"held":held,"final":final}))
			var isolated: Dictionary = LAMP_CASES.run()
			rows.append(H.row(spec.checks[2], bool(isolated.ok), isolated))
			rows.append(H.row(spec.checks[3], common, summary))
		"Q09":
			var second: Dictionary = H.action(trace,"BOMB_R",2)
			rows.append(H.row(spec.checks[0], H.box(opening,6,2,3) and H.box(bomb,6,2,2) and H.box(second,6,2,1), {"first":bomb,"second":second}, not second.is_empty()))
			var lure: Dictionary = H.branch(spec,["R","R","U","U","U","R","BOMB_R","R","R"])
			rows.append(H.row(spec.checks[1], H.box(final,7,6,1) and H.player(final,4,2) and bool(summary.won) and not bool(lure.get("won",false)), {"author":final,"one_shell_lure":lure}))
			rows.append(H.row(spec.checks[2], common, {"summary":summary,"scope":"Blast/push/fall snapshots; burning/acid shell loss deliberately outside this level's claim."}))
		"Q10":
			var first_roll: Dictionary = H.sample(trace,6)
			rows.append(H.row(spec.checks[0], H.point(H.device(first_roll,"mine_cart").get("at",[]),7,6) and H.box(first_roll,7,4) and H.player(first_roll,3,6), first_roll, trace.size() > 6))
			rows.append(H.row(spec.checks[1], H.tile(bomb,7,5,"cracked_rock") == 0 and H.tile(bomb,8,6,"cracked_rock") == 0 and H.box(bomb,7,5) and H.point(H.device(bomb,"mine_cart").get("at",[]),7,6), bomb, not bomb.is_empty()))
			var lure: Dictionary = H.branch(spec,["R","R","R","BOMB_D"])
			rows.append(H.row(spec.checks[2], H.box(final,10,5) and H.point(H.device(final,"mine_cart").get("at",[]),10,6) and H.player(final,7,6) and not bool(lure.get("won",false)), {"author":final,"upper_lure":lure}))
			rows.append(H.row(spec.checks[3], common, {"summary":summary,"scope":"Replay and complete snapshots; prohibition remains the common safe-to-move rule."}))
	return rows
