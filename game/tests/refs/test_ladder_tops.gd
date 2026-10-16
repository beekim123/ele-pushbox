extends SceneTree
const Tops = preload("res://presentation/render/ladder_tops.gd")
const Sprites = preload("res://presentation/render/sprites/sprite_assets.gd")
const Raster = preload("res://presentation/render/palette_raster.gd")
const View = preload("res://presentation/render/world_view.gd")
var issues: Array[String] = []
var checks: int = 0
func _initialize() -> void: call_deferred("_run")
func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok: issues.append(label)
func _run() -> void:
	var fixture: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://tests/results/ladder-tops.reference.json"))
	for item: Dictionary in fixture.cases:
		var width: int = str(item.spec.map[0]).length()
		var actual: Array = []
		for i: int in range(item.markers.size()):
			if Tops.is_top(item.spec,item.markers,i % width,i / width): actual.append(i)
		var same: bool = actual.size() == item.caps.size()
		for index: int in range(mini(actual.size(),item.caps.size())): same = same and int(actual[index]) == int(item.caps[index])
		check(same,"classification " + str(item.id) + "/" + str(item.kind))
	for uid: String in ["art:mech.ladder","art:mech.vine","art:mech.rope_ladder"]:
		var full := Raster.new(16,16)
		var clipped := Raster.new(16,16)
		var animation: String = "top" if uid == "art:mech.vine" else "default"
		Sprites.blit(full,uid,animation,0,Vector2i(8,16))
		Sprites.blit(clipped,uid,animation,0,Vector2i(8,16),false,4)
		var kept: int = 0
		for y: int in range(16):
			for x: int in range(16):
				check(clipped.get_code(x,y) == (full.get_code(x,y) if y >= 12 else "."),uid + " pixel " + str(Vector2i(x,y)))
				if y >= 12 and clipped.get_code(x,y) != ".": kept += 1
		check(kept > 0,uid + " visible cap")
	# Exercise the actual world compositor, including the platform's logical H.
	var spec: Dictionary = root.get_node("Registry").level_spec("level:F07")
	var view := View.new()
	view._spec = spec
	view._opening = View._parse_opening(spec)
	view._origin = Vector2i.ZERO
	var state: Dictionary = view._opening.duplicate(true)
	state.player = {"x":-20,"y":-20}
	state.crates = []
	var raster := Raster.new(320,180)
	view._draw_entities(raster,state,0)
	for x: int in [2,9]:
		for yy: int in range(12):
			for xx: int in range(16): check(raster.get_code(x*16+xx,16+yy)==".","F07 upper rung removed")
		check(int(state.markers[11+x])==1,"F07 logical head retained")
	# Grown vine markers must not produce an additional wooden ladder layer.
	check(Tops.vine_cells({"w":6,"devices":[{"type":"vine","grown":true,"ladder_cells":[[2.0,1.0],[2.0,2.0]]}]}).size()==2,"JSON-grown vine coordinates")
	view.free()
	var result: Dictionary = {"suite":"ladder-tops","ok":issues.is_empty(),"cases":fixture.cases.size(),"checks":checks,"issues":issues}
	var file := FileAccess.open("res://tests/results/ladder-tops.json",FileAccess.WRITE)
	file.store_string(JSON.stringify(result,"\t")); file.close()
	print(JSON.stringify(result))
	quit(0 if issues.is_empty() else 1)
