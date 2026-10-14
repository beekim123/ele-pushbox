extends SceneTree
const Game := preload("res://pushbox/scripts/game.gd")
const Catalog := preload("res://pushbox/scripts/campaign_catalog.gd")
var failures: int = 0
var samples: Array[int] = []
var local_samples: Array[int] = []
var rows: Array = []
var peak_timing: Dictionary = {}
func _initialize() -> void:
	call_deferred("run")
func frame() -> void:
	await process_frame
	await RenderingServer.frame_post_draw
func idle(game: Node) -> bool:
	var waited: int = 0
	var last: int = game.frame_us.size()
	while game.session.running or game.animation_left > 0 or game._opening or game._campaign_save_pending:
		await frame()
		waited += 1
		if waited > 900 or game.session == null:
			failures += 1
			print("FAIL T8 idle deadline level=",game.session.level.id if game.session != null else "none", " running=",game.session.running if game.session != null else false," opening=",game._opening," opening_failed=",game._opening_failed," save=",game._campaign_save_pending," animation=",game.animation_left)
			return false
		if game.frame_us.size() > last:
			var upload: int = game.session.world.get_stats().upload_us
			var overlay: int = game.view.draw_us if game.view.draw_frame == Engine.get_process_frames() else 0
			var value: int = game.frame_us[-1]+upload+overlay
			samples.append(value)
			if local_samples.is_empty() or value > local_samples.max():
				peak_timing = game.frame_timing.duplicate(true)
			local_samples.append(value)
			if value > 4000:
				failures += 1
				print("FAIL T8 ",game.session.level.id," move=",game.session.board.moves," us=",value," physics_us=",game.frame_us[-1]," upload_us=",upload," draw_us=",overlay," phases=",game.frame_timing)
			last = game.frame_us.size()
	return true
func run() -> void:
	var game := Game.new()
	game.start_in_lobby = true
	game.progress_path = "user://stage2a-performance.json"
	root.add_child(game)
	for map in 6:
		for index in 6:
			var filter: String = OS.get_environment("PUSHBOX_CAMPAIGN_ID")
			if not filter.is_empty() and filter != Catalog.id(map,index):
				continue
			await process_frame
			game.return_lobby("campaign")
			await process_frame
			print("BEGIN T8 ",Catalog.id(map,index))
			game.select_level_path(Catalog.path(map,index),"campaign",index)
			print("LOADED T8 ",Catalog.id(map,index))
			game.frame_us.clear()
			local_samples.clear()
			if not await idle(game):
				game.free(); quit(1); return
			for action in game.session.level.solution:
				await process_frame
				if OS.get_environment("PUSHBOX_CAMPAIGN_TRACE") == "1":
					print("ACTION T8 ",action," move=",game.session.board.moves)
				if action in ["L","R","U","D","USE"]:
					game.request_direction("U" if action == "USE" else action)
				else:
					game.request_action(action)
				if not await idle(game):
					game.free(); quit(1); return
			if not game.session.board.won() or not game.session.errors.is_empty():
				failures += 1
				print("FAIL T8 replay ",game.session.level.id," ",game.session.errors)
			rows.append({"id":game.session.level.id,"samples":local_samples.size(),"max_us":local_samples.max(),"won":game.session.board.won()})
			print("T8 ",game.session.level.id," samples=",local_samples.size()," max_us=",local_samples.max(), " peak=",peak_timing)
	await process_frame
	game.free()
	samples.sort()
	var report := {"display":DisplayServer.get_name(),"workers":1,"threshold_us":4000,"samples":samples.size(),"max_us":samples.max(),"p95_us":samples[ceili(samples.size()*0.95)-1],"failures":failures,"levels":rows}
	var file := FileAccess.open("res://artifacts/stage2a/performance%s.json" % ("-"+OS.get_environment("PUSHBOX_CAMPAIGN_ID") if not OS.get_environment("PUSHBOX_CAMPAIGN_ID").is_empty() else ""),FileAccess.WRITE)
	file.store_string(JSON.stringify(report,"  ")+"\n")
	file.close()
	print("Campaign T8: ",samples.size()," frames, max_us=",samples.max(),", ",failures," failures")
	quit(1 if failures else 0)
