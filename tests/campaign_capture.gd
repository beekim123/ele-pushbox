extends SceneTree
const Game := preload("res://pushbox/scripts/game.gd")
const Catalog := preload("res://pushbox/scripts/campaign_catalog.gd")
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
	var path: String = "res://artifacts/stage2a/captures/"+name
	native.save_png(path+"-native.png")
	var enlarged: Image = native.duplicate()
	enlarged.resize(1920,1080,Image.INTERPOLATE_NEAREST)
	enlarged.save_png(path+"-1920x1080.png")
	captures.append({"name":name,"native":[native.get_width(),native.get_height()],"output":[1920,1080]})
	checks += 1
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
		await process_frame
		game.open_observation(map,5)
		await capture(Catalog.THEMES[map]+"-observation")
		await process_frame
		game.select_level_path(Catalog.path(map,5),"campaign",5)
		game.skip_animation = true
		for _i in 900:
			if not game.session.running and not game._opening:
				break
			await frame()
		game.view.entrance = 0
		game.view.queue_redraw()
		await capture(Catalog.THEMES[map]+"-opening")
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
	file.store_string(JSON.stringify({"display":DisplayServer.get_name(),"captures":captures,"checks":checks,"failures":failures},"  ")+"\n")
	file.close()
	print("Campaign captures: %d checks, %d failures" % [checks,failures])
	quit(1 if failures else 0)
