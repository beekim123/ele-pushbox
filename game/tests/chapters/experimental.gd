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
			rows.append(H.row(spec.checks[0], H.material(opening,"acid") == 256 and H.material(opening,"limestone_a") == 256 and balanced and H.tile(released,6,3,"limestone_a") < 128, {"one_to_one":balanced,"released":released}, trace.size()>3))
			rows.append(H.row(spec.checks[1], H.box(released,6,5) and final.get("state",{}).get("doors",[]).has(true), {"released":released,"final":final}, trace.size()>3))
			var before_leaving: Dictionary = H.branch(spec,["R","D","R","R"])
			var after_leaving: Dictionary = H.branch(spec,["R","D","R","R","R"])
			rows.append(H.row(spec.checks[2], before_leaving.get("final",{}).get("state",{}).get("doors",[]).has(true) and not after_leaving.get("final",{}).get("state",{}).get("doors",[]).has(true), {"person_on_plate":before_leaving,"left_plate":after_leaving}))
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
			rows.append(H.row(spec.checks[0], H.tile(released,6,3,"cracked_rock") == 0 and H.material(opening,"gravel") == 512 and H.material(released,"gravel") == 512, released, not released.is_empty()))
			var bridge: Dictionary = _observed(final,"bridge")
			rows.append(H.row(spec.checks[1], H.box(final,6,8) and bool(bridge.get("broken",false)), {"bridge":bridge,"final":final}))
			var early: Dictionary = H.branch(spec,["R","U","BOMB_R"])
			rows.append(H.row(spec.checks[2], early.get("accepted_steps",0) == 3 and not H.box(early.get("final",{}),6,8) and H.material(early.get("final",{}),"gravel") == 512 and bool(summary.undo_ok), early))
			var recorded_overload: bool = false
			for entry: Dictionary in summary.physics:
				for observed: Dictionary in entry.get("observe",[]):
					if str(observed.get("kind","")) == "bridge" and int(observed.get("load",0)) > 2: recorded_overload = true
			rows.append(H.row(spec.checks[3], recorded_overload and bool(bridge.get("broken",false)) and H.material(final,"gravel") == 512, {"overload_observed":recorded_overload,"bridge":bridge,"whole_gravel":H.material(final,"gravel")}))
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
			rows.append(H.row(text,false,{"limits_ok":summary.limits_ok,"max_ticks":summary.max_ticks,"max_rounds":summary.max_rounds,"reason":"SDK limits measured; the combined placeholder/approval clause needs a visual/human check."},false))
	return rows
