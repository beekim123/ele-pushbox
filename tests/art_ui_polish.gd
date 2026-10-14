extends SceneTree
const Art := preload("res://pushbox/scripts/art/art_registry.gd")
const Game := preload("res://pushbox/scripts/game.gd")
const Ecology := preload("res://pushbox/scripts/render/ambient_ecology.gd")
const Catalog := preload("res://pushbox/scripts/campaign_catalog.gd")
class SurfaceProbe extends Node2D:
	var theme: String = "ruins"
	var clock: float = 0.35
	var points: Dictionary = {"floor":[],"ceiling":[],"liquid":[{"at":Vector2(4,14),"kind":"w"}]}
	func _draw() -> void:
		Ecology.surface(self,theme,clock,points)

var checks: int = 0
var failures: int = 0
func check(value: bool, label: String) -> void:
	checks += 1
	if not value:
		failures += 1
		print("FAIL polish: ",label)
func _initialize() -> void:
	call_deferred("run")
func frame() -> void:
	await process_frame
	await RenderingServer.frame_post_draw
func first_white_y(image: Image) -> int:
	for y in image.get_height():
		for x in image.get_width():
			if image.get_pixel(x,y).is_equal_approx(Color.WHITE): return y
	return -1
func surface_motion_checks() -> void:
	Ecology.warm()
	check(Ecology._textures.moth0.get_size()==Vector2(6,6),"crystal moth uses prescribed 6px native canvas")
	check(Ecology._textures.moth0.get_image().get_pixel(0,1).a<1,"moth wings are translucent")
	var viewport := SubViewport.new()
	viewport.size = Vector2i(48,32)
	viewport.transparent_bg = true
	viewport.disable_3d = true
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(viewport)
	var probe := SurfaceProbe.new()
	viewport.add_child(probe)
	await frame()
	await frame()
	var before: PackedByteArray = viewport.get_texture().get_image().get_data()
	probe.clock = 0.8
	probe.queue_redraw()
	await frame()
	check(before!=viewport.get_texture().get_image().get_data(),"reeds visibly sway between non-extremal phases")
	probe.theme = "sky_island"
	probe.points = {"floor":[Vector2(16,96)],"ceiling":[],"liquid":[]}
	probe.position = Vector2(-12,-80)
	probe.clock = 0.2
	probe.queue_redraw()
	await frame()
	var start: int = first_white_y(viewport.get_texture().get_image())
	probe.clock = 1.0
	probe.queue_redraw()
	await frame()
	check(start>=0 and start!=first_white_y(viewport.get_texture().get_image()),"cloud sprite actually hops by a native pixel")
	viewport.free()
func run() -> void:
	await surface_motion_checks()
	for theme in Catalog.THEMES:
		var frames: Array[PackedByteArray] = []
		for f in 4:
			var pixels: PackedByteArray = Art.themed_texture("lantern_idle_%d"%f,theme).get_image().get_data()
			check(not pixels in frames,theme+" lamp frame %d is distinct"%f)
			frames.append(pixels)
	for name in ["scale_pan_0","wind_emitter_0","gravity_console_0","quantum_pad_0","stalactite_0","geyser_0"]:
		check(Art.themed_texture(name,"forest").get_size() == Vector2(16,16),name+" single tile is native 16px")
	check(Art.themed_texture("sand_funnel_0","ruins").get_size() == Vector2(16,32),"tall funnel preserves two-cell native drawing")
	check(Art.themed_texture("golden_scale_0","ruins").get_size() == Vector2(64,48),"multi-cell scale preserves native drawing")
	var wind_frames: Array[PackedByteArray] = []
	for f in 4:
		var pixels: PackedByteArray = Art.themed_texture("wind_emitter_%d"%f,"sky_island").get_image().get_data()
		check(not pixels in wind_frames,"windmill four rotational frames")
		wind_frames.append(pixels)
	var game := Game.new()
	game.start_in_lobby = true
	game.progress_path = "user://polish.json"
	root.size = Vector2i(1280,720)
	root.add_child(game)
	await frame()
	DirAccess.make_dir_recursive_absolute("res://artifacts/stage2a/captures")
	var lobby_image: Image = root.get_texture().get_image()
	lobby_image.save_png("res://artifacts/stage2a/captures/lobby-native.png")
	lobby_image.resize(1920,1080,Image.INTERPOLATE_NEAREST)
	lobby_image.save_png("res://artifacts/stage2a/captures/lobby-1920x1080.png")
	for map in 6:
		for index in 6:
			var title: String = game.lobby.CARD_TITLES[map][index]
			check(game.lobby.Style.font().get_string_size(title,HORIZONTAL_ALIGNMENT_LEFT,-1,12).x<=58,"all card titles fit with breathing padding")
	check(game.lobby.Style.font().get_string_size(game.lobby.CHALLENGE_LOCK_HINT,HORIZONTAL_ALIGNMENT_LEFT,-1,12).x<=game.lobby.card_rect(2).size.x-8,"mode hint leaves four pixel padding")
	check(game.lobby.Style.font().get_descent(12)+176<180,"footer font fits canvas vertically")
	game.open_showcase()
	await frame()
	check(root.content_scale_size == Vector2i(320,180),"showcase shares 320px UI canvas")
	var first_clock: float = game.showcase.clock
	await frame()
	check(game.showcase.clock>first_clock,"showcase animation loop advances")
	game.showcase.set_panorama(false)
	var before: Vector2 = game.showcase._camera_target
	var key := InputEventKey.new()
	key.pressed = true
	key.physical_keycode = KEY_RIGHT
	game.showcase.handle(key)
	check(game.showcase._camera_target.x>before.x,"detail arrows pan map")
	check(game.showcase._map_layer.scale==Vector2.ONE,"detail map keeps 1:1 pixels")
	await frame()
	check(game.showcase._camera.x>before.x,"camera actually moves")
	game.showcase.set_panorama(true)
	for map in 6:
		game.showcase.select_campaign(map,5)
		await frame()
		await frame()
		var start: PackedByteArray = root.get_texture().get_image().get_data()
		game.showcase.clock += 0.7
		game.showcase._ecology_background.clock += 0.7
		game.showcase.queue_redraw()
		await frame()
		check(start!=root.get_texture().get_image().get_data(),Catalog.THEMES[map]+" real rendered animation changes")
		var texture: Texture2D = game.showcase.terrain.texture
		check(texture.get_size()==Vector2(game.showcase.map_size*16),"native terrain survives overview scaling")
		for prop in game.showcase._sprites:
			check(not prop.has("size") or prop.size==prop.texture.get_size(),"observation never compresses mechanism")
	game.select_level_path(Catalog.path(1,0),"campaign",0)
	for _i in 900:
		if not game.session.running and not game._opening: break
		await frame()
	check(game.background.region_rect==Rect2(0,0,320,180),"small campaign rooms retain full scenic canvas")
	check(game.background.position==game._board_position,"full background aligns with 320px canvas")
	var state: String = game.session.world.get_state_hash()
	var position_key: String = game.session.board.position_key()
	for _i in 5: await frame()
	check(game.session.world.get_state_hash()==state and game.session.board.position_key()==position_key,"ecology clock leaves SDK hash / logical key untouched")
	for index in 6:
		var data: Dictionary = game.Session.Loader.json(Catalog.path(4,index))
		check(data.map[0]==".".repeat(data.map[0].length()),"sky has no solid ceiling")
		check(data.map.any(func(row: String) -> bool: return row[0]!="#") and data.map.any(func(row: String) -> bool: return row[-1]!="#"),"sky has no continuous side enclosure")
		check(data.map[-1].contains("."),"sky has no continuous basement")
	game.free()
	print("Art UI polish: %d checks, %d failures" % [checks,failures])
	quit(1 if failures else 0)
