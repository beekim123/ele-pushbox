extends RefCounted
## LV-09 causal cross-chapter assertions. Pending visual approval stays separate.
const H = preload("res://tests/chapters/helpers.gd")

func _observed(sample: Dictionary, kind: String) -> Dictionary:
	for item: Dictionary in sample.get("observe",[]):
		if str(item.get("type",item.get("kind",""))) == kind: return item
	return {}

func evaluate(spec: Dictionary, trace: Array, _runs: Array, summary: Dictionary) -> Array[Dictionary]:
	var rows: Array[Dictionary] = []
	var opening: Dictionary = H.sample(trace,0)
	var final: Dictionary = H.sample(trace)
	match str(spec.id):
		"E01":
			var released: Dictionary = H.sample(trace,3)
			var balanced: bool = true
			for entry: Dictionary in trace:
				balanced = balanced and H.material(entry.actual,"acid") == H.material(entry.actual,"limestone_a")
			for entry: Dictionary in summary.physics:
				balanced = balanced and int(entry.materials.get("acid",0)) == int(entry.materials.get("limestone_a",0))
			rows.append(H.row(spec.checks[0], H.material(opening,"acid") == 256 and H.material(opening,"limestone_a") == 256 and balanced and H.material(released,"acid") == 0 and H.material(released,"limestone_a") == 0 and H.tile(released,7,4,"packed_earth") == 256 and H.material(final,"bedrock") == H.material(opening,"bedrock"), {"one_to_one":balanced,"released":released}, trace.size()>3))
			rows.append(H.row(spec.checks[1], H.box(released,1,2) and H.player(H.sample(trace,7),6,4) and H.player(final,8,4) and final.get("state",{}).get("doors",[]).has(true), {"released":released,"entered_shaft":H.sample(trace,7),"final":final}, trace.size()>7))
			var person: Dictionary = spec.duplicate(true)
			person.map[2] = "#P.B..|####"
			var before_leaving: Dictionary = H.branch(person,[])
			var after_leaving: Dictionary = H.branch(person,["R"])
			rows.append(H.row(spec.checks[2], before_leaving.get("setup_ok",false) and before_leaving.get("final",{}).get("state",{}).get("doors",[]).has(true) and H.material(before_leaving.get("final",{}),"acid") == 0 and int(after_leaving.get("accepted_steps",0)) == 1 and not after_leaving.get("final",{}).get("state",{}).get("doors",[]).has(true), {"scope":"isolated copy starts the person on the linked plate; same crate, shaft, acid and nonlatched link","person_on_plate":before_leaving,"left_plate":after_leaving}))
		"E02":
			var held: Dictionary = H.sample(trace,8)
			rows.append(H.row(spec.checks[0], H.box(held,5,3) and H.box(final,9,3) and H.tile(final,5,4,"bedrock") == 0 and H.tile(final,5,6,"crate") == 0, {"held_before_retreat":held,"after_retreat":final,"scope":"Fall and portal occur in one complete settlement; all static ownership and final positions measured."}, trace.size()>9))
			rows.append(H.row(spec.checks[1], bool(summary.won) and H.box(final,9,3) and final.state.crates.size()==1, final))
			rows.append(H.row(spec.checks[2], H.material(opening,"crate") == 256 and H.material(final,"crate") == 256 and bool(summary.undo_ok), {"crate_cells":H.material(final,"crate"),"scope":"Portal occupancy/snapshots measured; visual settings boundary independently covered by lamp SDK fixture."}))
		"E03":
			var grown: Dictionary = H.sample(trace,8)
			rows.append(H.row(spec.checks[0], H.material(opening,"ice") == 256 and H.material(grown,"ice") == 0 and H.material(grown,"water") == 256 and H.tile(grown,4,6,"water") >= 256 and bool(H.device(grown,"vine").get("grown",false)), grown, trace.size()>8))
			rows.append(H.row(spec.checks[1], H.box(grown,6,3) and H.device(grown,"vine").get("ladder_cells",[]).size() == 6 and H.player(final,6,1) and bool(summary.won), {"grown":grown,"final":final}, trace.size()>8))
			var early: Dictionary = H.branch(spec,["R","U"])
			rows.append(H.row(spec.checks[2], early.get("accepted_steps",0) == 2 and not H.box(early.get("final",{}),6,3) and H.material(early.get("final",{}),"water") == 256 and bool(summary.undo_ok), early))
		"E04":
			var released: Dictionary = H.action(trace,"BOMB_R")
			var on_crate_peak: int = 0
			for entry: Dictionary in summary.physics:
				if int(entry.get("move",-1)) != 5: continue
				for probe: Dictionary in entry.get("probes",[]):
					if H.point(probe.get("tile",[]),6,4): on_crate_peak = maxi(on_crate_peak,int(probe.get("materials",{}).get("gravel",0)))
			rows.append(H.row(spec.checks[0], H.tile(released,6,4,"cracked_rock") == 0 and H.material(opening,"gravel") == 256 and H.material(released,"gravel") == 256 and on_crate_peak == 256, {"peak_gravel_on_crate":on_crate_peak,"after_blast":released}, not released.is_empty()))
			var bridge: Dictionary = _observed(final,"bridge")
			var early: Dictionary = H.branch(spec,["R","U","BOMB_R","D","R"])
			var early_value: Dictionary = early.get("final",{})
			var before_bomb: Dictionary = H.sample(trace,4)
			var recorded_overload: bool = false
			for entry: Dictionary in summary.physics:
				for observed: Dictionary in entry.get("observe",[]):
					if str(observed.get("kind","")) == "bridge" and int(observed.get("load",0)) == 2 and int(observed.get("capacity",0)) == 1: recorded_overload = true
			var only_box: Dictionary = _observed(before_bomb,"bridge")
			var only_gravel: Dictionary = _observed(early_value,"bridge")
			rows.append(H.row(spec.checks[1], H.box(final,6,7) and H.tile(final,6,6,"gravel") == 256 and bool(bridge.get("broken",false)) and recorded_overload and int(only_box.get("load",0)) == 1 and bool(only_box.get("cracked",false)) and int(only_gravel.get("load",0)) == 1 and bool(only_gravel.get("cracked",false)), {"bridge":bridge,"only_box":only_box,"only_gravel":only_gravel,"overload_observed":recorded_overload,"final":final}))
			var author_bridge_cells: int = H.tile(final,6,6,"bridge")
			rows.append(H.row(spec.checks[2], early.get("accepted_steps",0) == 5 and not H.box(early_value,6,7) and H.box(early_value,5,5) and H.tile(early_value,6,5,"gravel") == 256 and H.material(early_value,"gravel") == 256 and not bool(only_gravel.get("broken",true)) and author_bridge_cells == 0 and bool(summary.undo_ok), {"early_blast":early,"author_bridge_cells":author_bridge_cells}))
			var blast_result: Dictionary = trace[5].get("result",{}) if trace.size()>5 else {}
			rows.append(H.row(spec.checks[3], not blast_result.is_empty() and bool(blast_result.get("accepted",false)) and str(blast_result.get("error","")).is_empty() and int(blast_result.get("ticks",1200)) < 1200 and H.material(released,"gravel") == 256, blast_result))
		"E05":
			var positioned: Dictionary = H.sample(trace,4)
			rows.append(H.row(spec.checks[0], H.point(H.device(positioned,"mine_cart").get("at",[]),8,6) and H.player(positioned,3,6) and H.box(positioned,5,3), positioned, trace.size()>4))
			rows.append(H.row(spec.checks[1], H.box(final,8,5) and H.player(final,5,3) and not _observed(final,"ice_slide").get("last_slide",{}).is_empty(), final))
			var early: Dictionary = H.branch(spec,["R","R","R"])
			rows.append(H.row(spec.checks[2], early.get("accepted_steps",0)==3 and H.box(early.get("final",{}),8,8) and H.material(final,"crate") == 256 and bool(summary.undo_ok), {"early_slide":early,"final_crate_cells":H.material(final,"crate")}))
		"E06":
			var waiting: Dictionary = H.sample(trace,8)
			var launched: Dictionary = H.sample(trace,9)
			rows.append(H.row(spec.checks[0], H.box(waiting,2,3) and H.player(waiting,6,6), waiting, trace.size()>8))
			rows.append(H.row(spec.checks[1], H.box(launched,3,6) and H.player(launched,7,4) and not _observed(launched,"seesaw").get("last_launch",{}).is_empty(), launched, trace.size()>9))
			var early: Dictionary = H.branch(spec,["R","U"])
			rows.append(H.row(spec.checks[2], early.get("accepted_steps",0)==2 and H.box(early.get("final",{}),3,6) and not bool(early.get("won",false)) and bool(summary.undo_ok), early))
			rows.append(H.row(spec.checks[3], H.box(launched,3,6) and H.player(launched,7,4) and H.material(final,"crate") == 256 and bool(summary.undo_ok), {"after_opening":launched,"summary":summary}, trace.size()>9))
	for text: String in spec.checks:
		if text.begins_with("候选设计模型结果不能代替真实SDK"):
			rows.append(H.row(text,H.common(summary) and bool(summary.complete_actions),summary))
		elif text.begins_with("逐步记录tick"):
			rows.append(H.row(text,bool(summary.limits_ok) and bool(summary.complete_actions),{"limits_ok":summary.limits_ok,"max_ticks":summary.max_ticks,"max_rounds":summary.max_rounds}))
	return rows
