extends RefCounted
const H = preload("res://tests/chapters/helpers.gd")
static func run() -> Dictionary:
	var spec: Dictionary = {"id":"lamp-owner","group":"blast","seed":12,"profile":["cells"],"mechanisms":["lantern_reveal"],"map":["########","########","#...####","#..P...#","########","########"],"devices":[{"type":"lantern_reveal","cells":[[4,3]],"material":"bedrock"}]}
	var near: Dictionary = H.branch(spec,["L"])
	var far: Dictionary = H.branch(spec,["L","L"])
	var variant: Dictionary = spec.duplicate(true)
	variant.environment = "off"
	var dark_visual: Dictionary = H.branch(variant,["L","L"])
	var wet: Dictionary = H.branch({"id":"lamp-unowned-water","group":"blast","seed":13,"profile":["cells"],"mechanisms":["lantern_reveal"],"map":["########","########","#P##~###","########","########"],"devices":[{"type":"lantern_reveal","cells":[[4,2]],"material":"bedrock"}]},[])
	var near_lit: bool = near.get("accepted_steps",0) == 1 and H.tile(near.get("final",{}),4,3,"bedrock") == 256
	var far_dark: bool = far.get("accepted_steps",0) == 2 and H.tile(far.get("final",{}),4,3,"bedrock") == 0 and H.material(far.get("opening",{}),"bedrock") - H.material(far.get("final",{}),"bedrock") == 256
	var protected: bool = bool(wet.get("setup_ok",false)) and H.material(wet.get("final",{}),"water") == 256
	var independent: bool = far.get("final",{}).get("hash","") == dark_visual.get("final",{}).get("hash","different")
	return {"ok":near_lit and far_dark and protected and independent,"at_two_lit":near_lit,"at_three_dark_own_only":far_dark,"unowned_water_preserved":protected,"visual_option_independent":independent,"near":near,"far":far,"wet":wet}
