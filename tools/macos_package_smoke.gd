extends Node
## Runs inside the exported PCK using its bundled runtime and SDK.
const Session := preload("res://pushbox/scripts/session.gd")
const Game := preload("res://pushbox/scripts/game.gd")
const Catalog := preload("res://pushbox/scripts/campaign_catalog.gd")
const Preview := preload("res://pushbox/scripts/preview.gd")
const Style := preload("res://pushbox/scripts/ui/pixel_style.gd")
var checks: int = 0
var failures: int = 0

func check(value: bool, message: String) -> void:
	checks += 1
	if not value:
		failures += 1
		print("FAIL " + message)

func _ready() -> void:
	call_deferred("run")

func run() -> void:
	check(ClassDB.class_exists("EleWorld"), "bundled SDK loads")
	check(Style.font().data.size() > 1000, "raw Chinese pixel font survives export")
	check(not FileAccess.file_exists("res://pushbox/assets/sprites/miner_idle_0.png"), "no legacy PNG in package")
	for room in 4:
		var session := Session.new()
		check(session.load_level("res://pushbox/levels/tutorial/t%02d.json" % (room+1),self).is_empty(), "packed JSON and content load")
		check(session.world.threads == 1, "one SDK worker")
		session.settle_sync()
		session.seal_opening()
		for step in session.level.solution.size():
			var before: String = session.world.get_state_hash()
			var action: String = session.level.solution[step]
			check(session.perform(action,true).legal, "packed author action legal")
			session.settle_sync()
			check(session.world.get_state_hash() == session.level.solution_hashes[step], "packed author hash")
			check(session.undo() and session.world.get_state_hash() == before, "packed undo")
			check(session.perform(action,true).legal, "packed redo legal")
			session.settle_sync()
			check(session.world.get_state_hash() == session.level.solution_hashes[step], "packed redo hash")
		check(session.board.won() and session.errors.is_empty(), "packed tutorial victory")
		session.dispose()
		print("PACKAGE T%02d replay/undo PASS" % (room+1))
	if OS.has_feature("stage2a") or OS.has_feature("art-ui-polish"):
		for map in 6:
			for index in 6:
				var session := Session.new()
				check(session.load_level(Catalog.path(map,index),self).is_empty(),"packed campaign loads")
				session.settle_sync()
				var preview := Preview.new()
				check(preview.configure(session,self) == "","packed preview loads")
				for step in session.level.solution.size():
					var action: String = session.level.solution[step]
					var prediction: Dictionary = preview.predict(session,action)
					check(session.perform(action).legal,"packed campaign action")
					session.settle_sync()
					check(session.world.get_state_hash() == session.level.solution_hashes[step] and session.board.position_key() == session.level.solution_keys[step],"packed campaign author fingerprint")
					check(prediction.hash == session.world.get_state_hash() and prediction.game_state == session.board.state(),"packed campaign T6")
				check(session.board.won() and session.errors.is_empty(),"packed campaign wins")
				print("PACKAGE ",Catalog.id(map,index)," PASS")
				preview.dispose()
				session.dispose()
	var game := Game.new()
	game.start_in_lobby = true
	game.progress_path = "user://package-smoke-progress.json"
	get_tree().root.add_child(game)
	game.guide.learned.disconnect(game._save_guides)
	check(game.lobby.visible and game.session == null, "packed startup lobby")
	game.free()
	print("MAC PACKAGE: %d checks, %d failures" % [checks,failures])
	get_tree().quit(1 if failures else 0)
