extends SceneTree
const Game := preload("res://pushbox/scripts/game.gd")
const Catalog := preload("res://pushbox/scripts/campaign_catalog.gd")
var animation_pairs: Array = []
var checks: int = 0
var failures: int = 0
var captures: Array = []
func _initialize() -> void:
	call_deferred("run")
func frame() -> void:
	await process_frame
	await RenderingServer.frame_post_draw
func capture(name: String) -> void:
	await frame()
	await frame()
	var native: Image = root.get_texture().get_image()
	check_native(native)
	var path: String = "res://artifacts/stage2a/captures/"+name
	native.save_png(path+"-native.png")
	var enlarged: Image = native.duplicate()
	enlarged.resize(1920,1080,Image.INTERPOLATE_NEAREST)
	enlarged.save_png(path+"-1920x1080.png")
	captures.append({"name":name,"native":[native.get_width(),native.get_height()],"output":[1920,1080]})
	checks += 1
func check_native(image: Image) -> void:
	checks += 1
	if image.get_size()!=Vector2i(320,180):
		failures += 1
		print("FAIL capture native canvas ",image.get_size())
func opening(game: Node, map: int, index: int) -> void:
	game.select_level_path(Catalog.path(map,index),"campaign",index)
	game.skip_animation = true
	for _i in 900:
		if not game.session.running and not game._opening: break
		await frame()
	game.view.entrance = 0
	game.view.queue_redraw()
func run() -> void:
	DirAccess.make_dir_recursive_absolute("res://artifacts/stage2a/captures")
	root.size = Vector2i(1920,1080)
	var game := Game.new()
	game.start_in_lobby = true
	game.progress_path = "user://campaign-captures.json"
	root.add_child(game)
	game.lobby.show_page("campaign")
	await capture("campaign-pool")
	for map in 6:
		game.return_lobby("campaign")
		game.lobby.map_index = map
		game.lobby.selected = 5
		await capture(Catalog.THEMES[map]+"-pool")
		game.open_showcase()
		game.showcase.select_biome(map)
		await capture(Catalog.THEMES[map]+"-showcase-panorama")
		game.showcase.set_panorama(false)
		await capture(Catalog.THEMES[map]+"-showcase-detail")
		game.open_observation(map,5)
		game.showcase.set_panorama(true)
		await capture(Catalog.THEMES[map]+"-observation")
		var samples: Array = []
		for time in [0.0,0.35,0.8]:
			game.showcase.clock = time
			game.showcase._ecology_background.clock = time
			game.showcase._map_layer.queue_redraw()
			await capture(Catalog.THEMES[map]+"-animation-"+str(samples.size()))
			samples.append(root.get_texture().get_image().get_data())
		checks += 1
		if samples[0]==samples[1] or samples[1]==samples[2]:
			failures += 1
			print("FAIL visible animation ",Catalog.THEMES[map])
		animation_pairs.append({"theme":Catalog.THEMES[map],"times":[0,0.35,0.8],"all_frames_changed":samples[0]!=samples[1] and samples[1]!=samples[2]})
		for index in 6:
			await opening(game,map,index)
			await capture(Catalog.THEMES[map]+"-opening-%02d"%(index+1))
	await process_frame
	game.return_lobby("campaign")
	for id in ["D_01","D_04","D_06"]:
		game.lobby.mark_completed(id)
	await capture("campaign-silver-unlock")
	game.lobby.map_index = 1
	game.lobby.queue_redraw()
	await capture("forest-pool-unlocked")
	await process_frame
	game.free()
	var file := FileAccess.open("res://artifacts/stage2a/captures/manifest.json",FileAccess.WRITE)
	file.store_string(JSON.stringify({"display":DisplayServer.get_name(),"captures":captures,"animation_pairs":animation_pairs,"checks":checks,"failures":failures},"  ")+"\n")
	file.close()
	print("Campaign captures: %d checks, %d failures" % [checks,failures])
	quit(1 if failures else 0)
