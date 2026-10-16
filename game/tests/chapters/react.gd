extends RefCounted
## Dedicated acceptance of original spec.checks. Victory is never substituted
## for a material count or a negative fixture. Uncovered claims remain not_run.
const H = preload("res://tests/chapters/helpers.gd")
const SAMPLES = preload("res://tests/chapters/react_samples.gd")
const MATERIALS = preload("res://sim/materials.gd")

func evaluate(spec: Dictionary, trace: Array, runs: Array, summary: Dictionary) -> Array[Dictionary]:
	var assertions: Dictionary = {}
	var extra: Dictionary = SAMPLES.run(spec)
	match str(spec.id):
		"G01", "G02": _acid(spec,trace,summary,extra,assertions)
		"G03", "G04": _gas(spec,trace,summary,extra,assertions)
		"G05": _lifetime(trace,summary,extra,assertions)
		"G06": _vine(trace,summary,extra,assertions)
		"G08": _bounce(trace,extra,assertions)
		"G09", "G10": _seesaw(spec,trace,summary,extra,assertions)
	var result: Array[Dictionary] = []
	for text: String in spec.get("checks",[]):
		var evidence: Dictionary = _claim(false,"No dedicated physical assertion covers this clause.",false)
		if text.contains("同一seed从开局连续回放3次"):
			evidence = _claim(H.common(summary) and bool(summary.complete_actions) and runs.size()==3,{"scope":"three-author-replays","summary":_compact(summary),"runs":runs})
		elif text.contains("记录逐步tick、结算轮数与材料计数"):
			evidence = _claim(bool(summary.limits_ok) and bool(summary.complete_actions) and not trace.is_empty(),{"scope":"author-settlement-measurements","summary":_compact(summary),"trace_steps":trace.size(),"physics_samples":summary.get("physics",[]).size()})
		elif text.begins_with("模型边界"):
			evidence = _claim(false,"A design-model boundary declaration is not an SDK experiment; material assertions below are separate.",false)
		elif text.begins_with("待用户美术确认"):
			evidence = _claim(false,"User art approval and placeholder presentation require their own human/visual check; headless SDK replay cannot approve assets.",false)
		else:
			for phrase: String in assertions:
				if text.contains(phrase):
					evidence = assertions[phrase]
					break
		result.append(H.row(text,bool(evidence.ok),evidence.detail,bool(evidence.available)))
	return result

func _claim(ok: bool, detail: Variant, available: bool = true) -> Dictionary:
	return {"ok":ok,"detail":detail,"available":available}

func _compact(summary: Dictionary) -> Dictionary:
	var copy: Dictionary = summary.duplicate()
	copy.erase("physics")
	return copy

func _ready(branch: Dictionary) -> bool:
	return bool(branch.get("setup_ok",false))

func _complete(branch: Dictionary) -> bool:
	return _ready(branch) and int(branch.get("accepted_steps",-1))==int(branch.get("requested_steps",-2))

func _observation(value: Dictionary, kind: String) -> Dictionary:
	for item: Dictionary in value.get("observe",[]):
		if str(item.get("type",item.get("kind","")))==kind: return item
	return {}

func _light(value: Dictionary, kind: String) -> bool:
	for goal: Dictionary in value.get("goals",[]):
		if str(goal.get("kind",goal.get("type","")))==kind: return bool(goal.get("lit",false))
	return false

func _acid(spec: Dictionary, trace: Array, summary: Dictionary, extra: Dictionary, out: Dictionary) -> void:
	var opening: Dictionary = H.sample(trace,0)
	var final: Dictionary = H.sample(trace)
	var initial_acid: int = H.material(opening,"acid")
	var initial_rock: int = H.material(opening,"limestone_a")+H.material(opening,"limestone_b")
	var conserved: bool = initial_acid==(256 if str(spec.id)=="G01" else 512) and initial_rock>0
	var ledger: Array[Dictionary] = []
	for item: Dictionary in trace:
		var actual: Dictionary = item.actual
		var acid: int = H.material(actual,"acid")
		var rock: int = H.material(actual,"limestone_a")+H.material(actual,"limestone_b")
		conserved = conserved and acid-rock==initial_acid-initial_rock and H.material(actual,"hard_rock")==H.material(opening,"hard_rock")
		ledger.append({"step":item.step,"acid":acid,"soft_rock":rock,"hard_rock":H.material(actual,"hard_rock")})
	for item: Dictionary in summary.get("physics",[]):
		var value: Dictionary = {"materials":item.get("materials",{})}
		conserved = conserved and H.material(value,"acid")-H.material(value,"limestone_a")-H.material(value,"limestone_b")==initial_acid-initial_rock
	var rule: Dictionary = MATERIALS.reactions(spec)
	var rules: Array = rule.get("reactions",[])
	var tagged_rule: bool = rules.size()==1 and str(rules[0].get("b",""))=="#etchable" and int(rules[0].get("chance",0))==256
	var contacts_ok: bool = true
	var contacts_available: bool = true
	var contacts: Dictionary = {}
	for symbol: String in ["L","M","R"]:
		var contact_branch: Dictionary = extra.get("contact_"+symbol,{})
		contacts[symbol] = contact_branch
		contacts_available = contacts_available and _ready(contact_branch)
		var contact_value: Dictionary = contact_branch.get("final",{})
		if symbol=="R": contacts_ok = contacts_ok and H.material(contact_value,"hard_rock")==256 and H.material(contact_value,"acid")==256
		else:
			var name: String = "limestone_a" if symbol=="L" else "limestone_b"
			contacts_ok = contacts_ok and H.material(contact_value,name)<256 and H.material(contact_value,"acid")==H.material(contact_value,name)
	var main_clear: bool = H.tile(final,4,4,"limestone_a")==0 if str(spec.id)=="G01" else H.tile(final,4,5,"limestone_a")==0 and H.tile(final,4,6,"limestone_b")==0
	var acid_clear: bool = H.material(final,"acid")==0
	var walls_intact: bool = H.material(final,"bedrock")==H.material(opening,"bedrock") and H.material(final,"hard_rock")==H.material(opening,"hard_rock")
	var after_release: Dictionary = H.action(trace,"DIG_L")
	var earth_intact: bool = H.material(after_release,"packed_earth")==H.material(opening,"packed_earth")-256
	var detail: Dictionary = {"scope":"author-sdk-cell-ledger-and-isolated-tag-contact-controls","ledger":ledger,"reaction_table":rule,"isolated_contacts":contacts,"target_rock_clear":main_clear,"acid_clear":acid_clear,"walls_intact":walls_intact,"after_release":after_release}
	var available: bool = not opening.is_empty() and not after_release.is_empty() and contacts_available
	if str(spec.id)=="G01":
		out["挖塞后256 acid cell"] = _claim(conserved and tagged_rule and contacts_ok and main_clear and acid_clear and walls_intact and earth_intact,detail,available)
		out["人物向左进入[4,2]"] = _claim(H.player(H.sample(trace,6),4,4) and H.player(final,2,4) and _light(final,"exit"),{"entry":H.sample(trace,6),"final":final},trace.size()>6)
	else:
		var single_m: bool = H.tile(opening,4,5,"limestone_a")==0 and H.tile(opening,4,6,"limestone_b")==256 and H.tile(after_release,4,6,"limestone_b")==0 and main_clear
		var retained: bool = H.material(after_release,"acid")==256 and H.tile(after_release,4,6,"acid")==256 and H.material(final,"acid")==256 and H.tile(after_release,3,6,"packed_earth")==256
		var single_detail: Dictionary = detail.duplicate()
		single_detail["scope"] = "single-M author reaction; sealed-well residual measured before the later deliberate exit excavation"
		single_detail["single_m"] = single_m
		single_detail["retained_acid_before_exit_dig"] = retained
		out["与M[4,6]一对一反应"] = _claim(conserved and tagged_rule and contacts_ok and single_m and retained and walls_intact and earth_intact,single_detail,available)
		var branch: Dictionary = extra.get("decoy",{})
		var measured: Dictionary = branch.get("final",{})
		var decoy_ok: bool = _complete(branch) and H.tile(measured,7,5,"limestone_a")==0 and H.tile(measured,7,6,"hard_rock")==256 and H.material(measured,"acid")==256 and H.tile(measured,4,5,"limestone_a")==0 and H.tile(measured,4,6,"limestone_b")==256 and not bool(branch.get("won",false))
		out["挖开右塞[7,2]"] = _claim(decoy_ok,{"decoy_branch":branch},_ready(branch))

func _gas(spec: Dictionary, trace: Array, summary: Dictionary, extra: Dictionary, out: Dictionary) -> void:
	var opening: Dictionary = H.sample(trace,0)
	var final: Dictionary = H.sample(trace)
	var material: String = "smoke" if str(spec.id)=="G03" else "fog"
	var conserved: bool = H.material(opening,material)==1024
	var peak: int = 0
	var premature: bool = false
	var have_bins: bool = false
	for point: Dictionary in summary.get("physics",[]):
		conserved = conserved and int(point.get("materials",{}).get(material,0))==1024
		for bin: Dictionary in point.get("bins",[]):
			if str(bin.get("material",material))!=material: continue
			have_bins = true
			peak = maxi(peak,int(bin.get("count",0)))
			if bool(bin.get("latched",false)) and peak<512: premature = true
	out["源室初始4格1024cell"] = _claim(conserved and peak>=512 and not premature and bool(H.device(final,"bin").get("latched",false)),{"scope":"author-per-tick-sdk-bin-count","initial":H.material(opening,material),"final":H.material(final,material),"peak":peak,"premature_latch":premature,"bin_samples_available":have_bins},have_bins)
	var trap: Dictionary = extra.get("trap",{})
	var trapped: Dictionary = trap.get("final",{})
	var failed_exit: bool = _ready(trap) and not _light(trapped,"exit") and not bool(trap.get("won",false))
	out["确认进入气井或诱饵水坑"] = _claim(failed_exit and _light(final,"bin") and _light(final,"exit"),{"scope":"author-two-goals-plus-isolated-wrong-route","branch":trap},not final.is_empty() and _ready(trap))
	if str(spec.id)=="G03":
		var last_results: Array = trap.get("results",[])
		var refused: bool = not last_results.is_empty() and not bool(last_results.back().get("accepted",false))
		out["唯一沙袋不足以从三格深烟室造阶"] = _claim(failed_exit and refused and H.player(trapped,4,7) and int(trapped.get("state",{}).get("bag",{}).get("sand",-1))==0,{"scope":"concrete-one-bag-stair-escape-attempt-not-an-exhaustive-SDK-search","branch":trap},_ready(trap))

func _lifetime(trace: Array, summary: Dictionary, extra: Dictionary, out: Dictionary) -> void:
	var ordinary_static: bool = true
	for item: Dictionary in trace:
		if str(item.action)=="U": break
		ordinary_static = ordinary_static and H.material(item.actual,"plug")==256 and H.material(item.actual,"plug_decay")==0
	var positive_reg: bool = false
	var expired: bool = false
	var previous: int = 121
	var reg_monotone: bool = true
	var timeline: Array[Dictionary] = []
	for point: Dictionary in summary.get("physics",[]):
		for probe: Dictionary in point.get("cells",[]):
			if not H.point(probe.get("tile",[]),8,3): continue
			var reg: int = int(probe.get("cell",{}).get("reg",0))
			if reg>0:
				positive_reg = true
				reg_monotone = reg_monotone and reg<=previous
				previous = reg
			if positive_reg and reg==0 and int(point.get("materials",{}).get("plug_decay",0))==0: expired = true
			timeline.append({"tick":point.get("tick",-1),"reg":reg,"remaining_decay":point.get("materials",{}).get("plug_decay",0)})
	var control: Dictionary = extra.get("static_control",{})
	var control_value: Dictionary = control.get("final",{})
	var static_holds: bool = _complete(control) and int(control.get("step_error",-1))==0 and H.material(control_value,"plug")==256 and not bool(H.device(control_value,"bin").get("latched",false))
	out["静止p普通动作后不衰减"] = _claim(ordinary_static and positive_reg and reg_monotone and expired and static_holds,{"scope":"author-sdk-reg-countdown-plus-isolated-static-material-control","timeline":timeline,"control":control,"control_scope":extra.get("control_scope","")},not timeline.is_empty() and _ready(control))
	var early: Dictionary = extra.get("early",{})
	var repeat_branch: Dictionary = extra.get("repeat",{})
	var final: Dictionary = H.sample(trace)
	var repeat_value: Dictionary = repeat_branch.get("final",{})
	var delivered: bool = H.box(final,1,2) and H.material(final,"sand")==512 and bool(H.device(final,"bin").get("latched",false))
	var no_refresh: bool = _complete(repeat_branch) and H.box(repeat_value,1,2) and H.material(repeat_value,"plug_decay")==0 and H.material(repeat_value,"sand")==512 and int(H.device(repeat_value,"lift").get("stop",-1))==1
	out["斗[8,5..6]"] = _claim(delivered and _complete(early) and not bool(early.get("won",false)) and no_refresh,{"scope":"author-delivery-and-isolated-early/repeated-release","early":early,"repeat":repeat_branch,"repeat_scope":extra.get("repeat_scope","")},not final.is_empty() and _ready(early) and _ready(repeat_branch))

func _vine(trace: Array, summary: Dictionary, extra: Dictionary, out: Dictionary) -> void:
	var opening: Dictionary = H.sample(trace,0)
	var final: Dictionary = H.sample(trace)
	var after: Dictionary = H.action(trace,"DIG_L")
	var grown: Dictionary = H.device(after,"vine")
	var left: Dictionary = extra.get("left",{})
	var left_value: Dictionary = left.get("final",{})
	var two: Dictionary = extra.get("left_two_bags",{})
	var two_value: Dictionary = two.get("final",{})
	var no_right_growth: bool = _complete(left) and H.material(left_value,"water")==512 and H.tile(left_value,6,7,"water")<256 and not bool(H.device(left_value,"vine").get("grown",false))
	out["挖左塞[4,4]后水分流"] = _claim(no_right_growth and _complete(two) and H.material(two_value,"water")==512 and H.tile(two_value,6,7,"water")<256 and not bool(H.device(two_value,"vine").get("grown",false)),{"scope":"isolated-left-drain-and-two-bag-attempt","left":left,"two_bags":two},_ready(left) and _ready(two))
	var proper: bool = H.material(opening,"water")==512 and H.material(final,"water")==512 and bool(grown.get("grown",false)) and int(grown.get("water_count",0))>=256 and not bool(H.device(opening,"vine").get("grown",false))
	var negative_materials_preserved: bool = no_right_growth
	out["512cell水从右塞流入右根"] = _claim(proper and negative_materials_preserved,{"scope":"author-sdk-root-count-and-left-control","root_count_after_dig":H.tile(after,6,7,"water"),"vine":grown,"water_total":H.material(final,"water"),"left":left},not after.is_empty() and _ready(left))
	var latch: Dictionary = extra.get("latch",{})
	var cells: Array = grown.get("ladder_cells",[])
	var continuous: bool = cells.size()==7
	for y: int in range(1,8):
		var found: bool = false
		for cell: Variant in cells:
			if H.point(cell,6,y): found = true
		continuous = continuous and found
	var latch_final: Dictionary = latch.get("final",{})
	var stays: bool = _complete(latch) and H.tile(latch_final,3,4,"water")<256 and H.material(latch_final,"water")==256 and bool(H.device(latch_final,"vine").get("grown",false))
	out["height=7包含root"] = _claim(continuous and stays and bool(summary.undo_ok) and bool(summary.restart_ok),{"scope":"author-ladder-cells-and-isolated-drained-root-latch","cells":cells,"drained_root_control":latch,"undo_ok":summary.undo_ok,"restart_ok":summary.restart_ok},not after.is_empty() and _ready(latch))

func _bounce(trace: Array, extra: Dictionary, out: Dictionary) -> void:
	var after: Dictionary = H.action(trace,"L",5)
	var launch: Dictionary = _observation(after,"bounce").get("last_launch",{})
	var flat: Dictionary = extra.get("flat",{})
	var blocked: Dictionary = extra.get("blocked",{})
	var crate: Dictionary = extra.get("crate",{})
	var flat_ok: bool = _complete(flat) and H.player(flat.get("final",{}),3,3) and _observation(flat.get("final",{}),"bounce").get("last_launch",{}).is_empty()
	var blocked_ok: bool = _complete(blocked) and H.player(blocked.get("final",{}),3,3) and _observation(blocked.get("final",{}),"bounce").get("last_launch",{}).is_empty()
	var launched: bool = H.point(launch.get("from",[]),4,6) and H.point(launch.get("to",[]),4,4) and H.player(after,4,4)
	out["人物从[5,5]横移到[4,5]"] = _claim(launched and flat_ok and blocked_ok,{"scope":"author-launch-plus-isolated-flat/blocked-controls","launch":launch,"flat":flat,"blocked":blocked},not after.is_empty() and _ready(flat) and _ready(blocked))
	var crate_final: Dictionary = crate.get("final",{})
	var crate_launch: Dictionary = _observation(crate_final,"bounce").get("last_launch",{})
	var crate_ok: bool = _ready(crate) and H.box(crate_final,3,3) and H.point(crate_launch.get("from",[]),3,3) and H.point(crate_launch.get("to",[]),3,1) and crate_final.get("state",{}).get("crates",[]).size()==1
	out["箱子落台、人物落台"] = _claim(launched and blocked_ok and crate_ok,{"scope":"author-person-and-isolated-crate-normal-gravity/blocked-sweep","crate":crate,"blocked":blocked},not after.is_empty() and _ready(crate) and _ready(blocked))

func _seesaw(spec: Dictionary, trace: Array, summary: Dictionary, extra: Dictionary, out: Dictionary) -> void:
	var opening: Dictionary = H.sample(trace,0)
	var final: Dictionary = H.sample(trace)
	var launch: Dictionary = _observation(final,"seesaw").get("last_launch",{})
	var initial_no_launch: bool = _observation(opening,"seesaw").get("last_launch",{}).is_empty() and H.box(opening,4,6)
	var right: Dictionary = extra.get("right_control",{})
	var right_launch: Dictionary = _observation(right.get("final",{}),"seesaw").get("last_launch",{})
	var path_ok: bool = H.point(launch.get("from",[]),4,6) and H.point(launch.get("to",[]),3,4) and H.box(final,3,4) and _complete(right) and H.box(right.get("final",{}),7,2) and H.point(right_launch.get("from",[]),6,4) and H.point(right_launch.get("to",[]),7,2)
	out["左端载物从[4,6]"] = _claim(path_ok,{"scope":"author-left-launch-and-isolated-mirrored-right-launch","launch":launch,"mirrored":right},not final.is_empty() and _ready(right))
	var blocked_ok: bool = true
	var blocked_available: bool = true
	var controls: Dictionary = {}
	for name: String in ["vertical_block","horizontal_block","occupied_landing"]:
		var branch: Dictionary = extra.get(name,{})
		blocked_available = blocked_available and _ready(branch)
		blocked_ok = blocked_ok and _complete(branch) and H.box(branch.get("final",{}),4,4) and _observation(branch.get("final",{}),"seesaw").get("last_launch",{}).is_empty()
		controls[name] = branch
	var person: Dictionary = extra.get("person",{})
	var person_value: Dictionary = person.get("final",{})
	out["人物跳右井只能亮箱槽"] = _claim(_complete(person) and H.box(person_value,3,4) and not _light(person_value,"exit") and not bool(person.get("won",false)),{"scope":"concrete-person-fall-branch","branch":person},_ready(person))
	if str(spec.id)=="G09":
		var late: Dictionary = extra.get("late_open",{})
		var late_value: Dictionary = late.get("final",{})
		out["开局载重仅作基线"] = _claim(initial_no_launch and path_ok and _complete(late) and H.box(late_value,4,6) and _observation(late_value,"seesaw").get("last_launch",{}).is_empty(),{"scope":"author-baseline-and-real-late-door-open-without-new-impact","late_open":late},not final.is_empty() and _ready(late))
	else:
		var near: Dictionary = extra.get("near_pour",{})
		var repeat_branch: Dictionary = extra.get("repeat",{})
		var repeat_value: Dictionary = repeat_branch.get("final",{})
		var repeated_launch: Dictionary = _observation(repeat_value,"seesaw").get("last_launch",{})
		var near_results: Array = near.get("results",[])
		var near_refused: bool = near_results.size()==2 and not bool(near_results[1].get("accepted",false))
		var no_repeat: bool = _complete(repeat_branch) and H.material(repeat_value,"sand")==256 and H.box(repeat_value,3,4) and int(repeated_launch.get("move",-1))==12
		out["开局[6,4]门闭"] = _claim(near_refused and no_repeat and not bool(opening.get("state",{}).get("doors",[true])[0]) and not bool(final.get("state",{}).get("doors",[true])[0]),{"scope":"starting-shore-rejection-and-far-plate-repeated-crossing","near_pour":near,"repeat":repeat_branch},_ready(near) and _ready(repeat_branch))
		out["建立初始端点载重基线"] = _claim(initial_no_launch and blocked_ok and path_ok and no_repeat,{"scope":"author-baseline-and-isolated-three-sweep-blockers","controls":controls,"repeat":repeat_branch},not final.is_empty() and blocked_available and _ready(repeat_branch))
		var after_dig: Dictionary = H.action(trace,"DIG_L")
		var after_pour: Dictionary = H.action(trace,"POUR_L")
		var landing_count: int = H.tile(after_pour,6,6,"sand")
		var phase_evidence: Array[Dictionary] = []
		for point: Dictionary in summary.get("physics",[]):
			if int(point.get("move",-1))!=12: continue
			phase_evidence.append(point)
		var actual_sand: bool = int(after_dig.get("state",{}).get("bag",{}).get("sand",-1))==1 and H.material(after_pour,"sand")==256 and landing_count>=128 and int(after_pour.get("state",{}).get("bag",{}).get("sand",-1))==0 and H.box(after_pour,3,4)
		# Store the complete pre-classification samples. A dedicated timing claim
		# needs a >=128 end probe before a launch; never infer it from victory.
		var threshold_seen: bool = false
		var ordering_ok: bool = true
		for point: Dictionary in phase_evidence:
			for probe: Dictionary in point.get("probes",[]):
				if H.point(probe.get("tile",[]),6,6) and int(probe.get("materials",{}).get("sand",0))>=128: threshold_seen = true
			for observed: Dictionary in point.get("observe",[]):
				if str(observed.get("type",""))=="seesaw" and not observed.get("last_launch",{}).is_empty() and not threshold_seen: ordering_ok = false
		out["唯一沙袋来自挖[4,4]"] = _claim(actual_sand and threshold_seen and ordering_ok and no_repeat,{"scope":"actual-SDK-sand-classification-before-game-layer-launch","landing_count":landing_count,"move12_physics":phase_evidence,"threshold_seen":threshold_seen,"ordering_ok":ordering_ok},not after_pour.is_empty() and not phase_evidence.is_empty())
