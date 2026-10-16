extends RefCounted
## Isolated real-SDK counterexamples. These copies never replace author specs.
const H = preload("res://tests/chapters/helpers.gd")
const SESSION = preload("res://gameplay/session/level_session.gd")

static func _tile(spec: Dictionary, x: int, y: int, symbol: String) -> void:
	var value: String = str(spec.map[y])
	spec.map[y] = value.substr(0, x) + symbol + value.substr(x + 1)

static func _fixture(map: Array, devices: Array, mechanism: String) -> Dictionary:
	return {"id":"react-isolated-" + mechanism,"format":"pushbox.levelspec/1","chapter":"forest","mode":"lab","group":"react","mechanisms":[mechanism],"map":map,"devices":devices,"bag":{"sand":0,"bomb":0}}

static func run(spec: Dictionary) -> Dictionary:
	var result: Dictionary = {}
	match str(spec.id):
		"G01":
			result.merge(_acid_contact_samples())
		"G02":
			result.decoy = H.branch(spec, ["L","L","L","L","L","DIG_L"])
			result.merge(_acid_contact_samples())
		"G03":
			# One sand bag is the complete resource available after opening the vent.
			result.trap = H.branch(spec, ["L","L","L","L","DIG_L","L","L","POUR_R","R","R"])
		"G04":
			result.trap = H.branch(spec, ["L","L","DIG_D"])
		"G05":
			result.early = H.branch(spec, ["R","U","L","L","L","L"])
			var repeat_spec: Dictionary = spec.duplicate(true)
			_tile(repeat_spec,9,5,"X")
			result.repeat = H.branch(repeat_spec, spec.solution + ["U","U"])
			result.repeat_scope = "isolated copy adds an unlit exit solely to allow input after the original goals would win"
			var control: Dictionary = spec.duplicate(true)
			control.devices[0].to = "plug"
			result.static_control = _static_lifetime_control(control)
			result.control_scope = "isolated material control: release writes static plug without lifetime; does not disable the production SDK rule"
		"G06":
			var wrong: Array = ["L","L","L","L","L","DIG_L"]
			result.left = H.branch(spec, wrong)
			result.left_two_bags = H.branch(spec, wrong + ["DIG_R","POUR_L","POUR_L"])
			var latch: Dictionary = _fixture(["#######","###.###","###.###","#P..###","###~###","###p###","###.###","#######"], [
				{"type":"vine","root":[3,4],"height":4,"need":256},
				{"type":"release","cells":[[3,5]],"to":"empty"},
				{"type":"lever","at":[1,3],"action":{"release":1}},
			], "vine")
			result.latch = H.branch(latch,["U"])
		"G08":
			var pad: Array = [{"type":"bounce","at":[3,4],"height":2}]
			result.flat = H.branch(_fixture(["#######","###H###","###.###","#P..###","#######"],pad,"bounce"),["R","R"])
			result.blocked = H.branch(_fixture(["#######","#######","#P..###","###.###","###.###","#######"],pad,"bounce"),["R","R"])
			result.crate = H.branch(_fixture(["#######","###H###","#P.B###","###.###","###.###","#######"],pad,"bounce"),[])
		"G09":
			var blocked_actions: Array = spec.solution.slice(1,11) + ["L","L","U"]
			result.late_open = H.branch(spec,blocked_actions)
			result.person = H.branch(spec,["U","R","D"])
			result.merge(_seesaw_samples())
		"G10":
			result.near_pour = H.branch(spec,["DIG_L","POUR_R"])
			result.person = H.branch(spec,spec.solution.slice(0,11) + ["L"])
			result.repeat = H.branch(spec,spec.solution.slice(0,12) + ["R","L","R","R"])
			result.merge(_seesaw_samples())
	return result

static func _acid_contact_samples() -> Dictionary:
	var result: Dictionary = {}
	for symbol: String in ["L","M","R"]:
		var isolated: Dictionary = _fixture(["#######","#P#####","###a###","###"+symbol+"###","#######"],[],"acid")
		result["contact_"+symbol] = H.branch(isolated,[])
	return result

static func _static_lifetime_control(spec: Dictionary) -> Dictionary:
	var session = SESSION.new()
	session.render_enabled = false
	if not session.setup(spec):
		var error: String = session.last_error
		session.dispose()
		return {"setup_ok":false,"error":error}
	var opening: Dictionary = H.capture(session)
	var accepted: int = 0
	var results: Array[Dictionary] = []
	for action: String in spec.solution:
		var result: Dictionary = session.perform(action)
		result.erase("hashes")
		results.append(result)
		if not bool(result.get("accepted",false)) or not str(result.get("error","")).is_empty(): break
		accepted += 1
	# Actual SDK ticks, with the normal tick observer still counting the bin.
	# This isolated static material has no lifetime; production definitions stay intact.
	var step_error: int = session.world.step(180)
	var final: Dictionary = H.capture(session)
	session.dispose()
	return {"setup_ok":true,"accepted_steps":accepted,"requested_steps":spec.solution.size(),"opening":opening,"final":final,"results":results,"extra_sdk_ticks":180,"step_error":step_error}

static func _seesaw_samples() -> Dictionary:
	var board: Dictionary = _fixture(["###########","###########","###o.#..IP#","####.#.####","####B#.####","####.#.####","###########"], [
		{"type":"seesaw","ends":[[4,5],[6,5]],"height":2,"threshold":1,"landings":[[3,2],[7,2]]},
	], "seesaw")
	var result: Dictionary = {"left_control":H.branch(board,["L","L"])}
	var vertical: Dictionary = board.duplicate(true)
	_tile(vertical,4,3,"#")
	result.vertical_block = H.branch(vertical,["L","L"])
	var horizontal: Dictionary = board.duplicate(true)
	_tile(horizontal,3,2,"#")
	result.horizontal_block = H.branch(horizontal,["L","L"])
	var occupied: Dictionary = board.duplicate(true)
	_tile(occupied,3,2,"B")
	result.occupied_landing = H.branch(occupied,["L","L"])
	var right: Dictionary = board.duplicate(true)
	right.map[2] = "#PI..#.o###"
	right.map[4] = "####.#B####"
	result.right_control = H.branch(right,["R","R"])
	return result
