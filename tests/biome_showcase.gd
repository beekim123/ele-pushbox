extends SceneTree
const Game := preload("res://pushbox/scripts/game.gd")
const Style := preload("res://pushbox/scripts/ui/pixel_style.gd")
var checks: int = 0
var failures: int = 0
var captures: Array = []

class GateProbe extends Node2D:
	const Gates := preload("res://pushbox/scripts/render/gate_painter.gd")
	var theme_id: String = "dungeon"
	var openness: float = 0.0
	func _draw() -> void:
		for i in 4:
			Gates.tile(self,Vector2(0,i*16),theme_id,i,4,openness)

func material_and_gate_probe(show: Node) -> void:
	var viewport := SubViewport.new()
	viewport.size = Vector2i(192,128)
	viewport.transparent_bg = true
	viewport.disable_3d = true
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(viewport)
	var encoded := Image.create(192,48,false,Image.FORMAT_RGBA8)
	for id in 12:
		encoded.fill_rect(Rect2i(id*16,16,16,16),Color(id/255.0,0,0,1))
	var sprite := Sprite2D.new()
	sprite.centered = false
	sprite.texture = ImageTexture.create_from_image(encoded)
	sprite.material = ShaderMaterial.new()
	sprite.material.shader = show.SHADER
	show.Binder.apply(sprite.material,show.theme_id,show.IDS)
	sprite.material.set_shader_parameter("world_origin",Vector2.ZERO)
	sprite.material.set_shader_parameter("room_rect",Vector4(0,0,192,48))
	sprite.material.set_shader_parameter("cell_texture_size",Vector2i(192,48))
	viewport.add_child(sprite)
	var gate := GateProbe.new()
	gate.theme_id = show.theme_id
	gate.position = Vector2(0,56)
	viewport.add_child(gate)
	await frame()
	await frame()
	var pixels: Image = viewport.get_texture().get_image()
	for id in [0,3,4,7]:
		check(pixels.get_pixel(id*16+8,24).a == 0.0,"empty / wood / gate / iron placeholder transparent")
	for id in [1,2,5,6,8,9,10,11]:
		check(pixels.get_pixel(id*16+8,24).a > 0.7,"new and old material %d rendered" % id)
	check(pixels.get_pixel(184,16).is_equal_approx(Color.WHITE),"ice bridge reflective top")
	check(pixels.get_pixel(136,16).is_equal_approx(Style.YELLOW),"acid exposed surface")
	if show.index == 1:
		for y in [16,17,18]:
			check(pixels.get_pixel(24,y).is_equal_approx(Color("63c74d")),"forest 3px grass at native pixel resolution")
	if show.index == 4:
		for y in [29,30,31]:
			check(pixels.get_pixel(24,y).is_equal_approx(Color.WHITE),"sky 3px cloud underside at native pixel resolution")
	if show.index == 5:
		for y in [16,17]:
			var color: Color = pixels.get_pixel(24,y)
			check(color.is_equal_approx(Color("fee761")) or color.is_equal_approx(Style.INK),"cosmos 2px hazard cap")
	if show.index == 3:
		check(pixels.get_pixel(39,20).is_equal_approx(Style.YELLOW),"cave crack is bright sulfur")
	if show.index < 4:
		for i in 4:
			check(pixels.get_pixel(2,61+i*16).a > 0.9,"mechanical gate four-height repeating sample")
	else:
		var before: Color = pixels.get_pixel(2,57)
		check(before.a > 0.9 and pixels.get_pixel(8,80).a > 0.9,"energy gate closed beam and emitter")
		gate.openness = 1.0
		gate.queue_redraw()
		await frame()
		var opened: Image = viewport.get_texture().get_image()
		check(opened.get_pixel(2,57).is_equal_approx(before),"energy top emitter stays fixed")
		check(opened.get_pixel(8,80).a == 0.0,"energy beam disappears")
		check(opened.get_pixel(2,118).a > 0.9,"energy bottom emitter stays fixed")
	viewport.free()

func check(value: bool, message: String) -> void:
	checks += 1
	if not value:
		failures += 1
		print("FAIL " + message)

func frame() -> void:
	await process_frame
	await RenderingServer.frame_post_draw

func key(game: Node, code: int) -> void:
	var event := InputEventKey.new()
	event.physical_keycode = code
	event.pressed = true
	game._input(event)

func click(game: Node, at: Vector2) -> void:
	var event := InputEventMouseButton.new()
	event.position = at
	event.pressed = true
	event.button_index = MOUSE_BUTTON_LEFT
	game._input(event)

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	if not FileAccess.file_exists("res://pushbox/scripts/ui/biome_showcase_view.gd"):
		check(false,"six-biome real renderer exists")
		finish()
		return
	var game := Game.new()
	game.start_in_lobby = true
	game.progress_path = "user://showcase-test.json"
	root.add_child(game)
	game.set_process_input(false)
	check(game.showcase.terrain.material == null,"showcase shader is created only on entry")
	game.lobby._fade = 0.0
	await frame()
	DirAccess.make_dir_recursive_absolute("res://artifacts/biome-preview/captures/")
	var entry: Image = root.get_texture().get_image()
	check(entry.get_size() == Vector2i(320,180),"lobby keeps baseline canvas")
	entry.save_png("res://artifacts/biome-preview/captures/lobby-entry-native.png")
	entry.resize(1920,1080,Image.INTERPOLATE_NEAREST)
	entry.save_png("res://artifacts/biome-preview/captures/lobby-entry-1920x1080.png")
	click(game,game.lobby.to_global(game.lobby.showcase_rect().get_center()))
	await frame()
	check(game.showcase.visible and game.session == null,"lobby opens visual preview without physics session")
	check(root.content_scale_size == Vector2i(320,180),"shared 320px native UI canvas")
	var dimensions: Array = [Vector2i(24,13),Vector2i(28,15),Vector2i(28,15),Vector2i(30,16),Vector2i(30,16),Vector2i(32,18)]
	var digests: Dictionary = {}
	for index in 6:
		game.showcase.select_biome(index)
		await frame()
		await frame()
		var show: Node = game.showcase
		check(show.map_size == dimensions[index],"biome %d blueprint dimensions" % index)
		check(show.map_data.map.size() == dimensions[index].y,"biome height")
		for row in show.map_data.map:
			check(row.length() == dimensions[index].x,"fixed tile width")
		check(show.terrain.texture.get_size() == Vector2(show.map_size*16),"encoded world texture size")
		check(show.terrain.material.get_shader_parameter("biome_style_id") == index,"theme binder index")
		for name in show.IDS:
			check(show.terrain.material.get_shader_parameter(show.Binder.MATERIAL_NAMES[name]) == show.IDS[name],"all material uniforms bound")
		check(show.map_origin.x >= 8 and show.map_origin.y >= 29 and show.map_origin.y+show.map_size.y*16*show._map_layer.scale.y <= 155,"whole large map is visible")
		var native: Image = root.get_texture().get_image()
		check(native.get_size() == Vector2i(320,180),"captured native viewport")
		var digest := HashingContext.new()
		digest.start(HashingContext.HASH_SHA256)
		digest.update(native.get_data())
		var hash: String = digest.finish().hex_encode()
		check(not digests.has(hash),"six visibly distinct rendered scenes")
		digests[hash] = true
		check(native.get_pixelv(Vector2i(show.map_origin)+Vector2i(8,8)).a > 0.9,"real scene pixels present")
		var folder: String = "res://artifacts/biome-preview/captures/"
		DirAccess.make_dir_recursive_absolute(folder)
		check(native.save_png(folder+show.theme_id+"-native.png") == OK,"native screenshot export")
		var enlarged: Image = native.duplicate()
		enlarged.resize(1920,1080,Image.INTERPOLATE_NEAREST)
		check(enlarged.save_png(folder+show.theme_id+"-1920x1080.png") == OK,"integer x3 screenshot export")
		captures.append({"theme":show.theme_id,"map_tiles":[show.map_size.x,show.map_size.y],"native":[320,180],"export":[1920,1080],"scale":6,"sha256_rgba":hash})
		await material_and_gate_probe(show)
	key(game,KEY_RIGHT)
	check(game.showcase.index == 0,"right wraps cosmos to dungeon")
	key(game,KEY_LEFT)
	check(game.showcase.index == 5,"left wraps dungeon to cosmos")
	click(game,game.showcase.to_global(game.showcase.next_rect().get_center()))
	check(game.showcase.index == 0,"mouse next works")
	key(game,KEY_ESCAPE)
	check(not game.showcase.visible and game.lobby.visible and root.content_scale_size == Vector2i(320,180),"Esc restores lobby canvas")
	key(game,KEY_B)
	game.select_level(0)
	check(not game.showcase.visible and game.session.level.id == "d1" and root.content_scale_size == Vector2i(320,180),"direct select_level leaves preview and preserves legacy API")
	check(game.view._box_sprite({"kind":"iron"}) == "crate_iron_0","real and hover boxes share kind mapping")
	game.return_lobby()
	game.free()
	var file := FileAccess.open("res://artifacts/biome-preview/captures/manifest.json",FileAccess.WRITE)
	file.store_string(JSON.stringify({"display":DisplayServer.get_name(),"workers":1,"checks":checks,"failures":failures,"lobby_entry":{"native":[320,180],"export":[1920,1080],"scale":6},"screens":captures},"  ")+"\n")
	finish()

func finish() -> void:
	print("Biome showcase: %d checks, %d failures" % [checks,failures])
	quit(1 if failures else 0)
