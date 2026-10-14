extends SceneTree
## Author-only recording; never touches D1-D5 or alters physical rules.
const Session := preload("res://pushbox/scripts/session.gd")

func _initialize() -> void:
	var recordings: Array = []
	for room in 4:
		var path: String = "res://pushbox/levels/tutorial/t%02d.json" % (room+1)
		var session := Session.new()
		var reason: String = session.load_level(path, root)
		if not reason.is_empty():
			print("FAIL load " + reason)
			quit(1)
			return
		session.settle_sync()
		print("OPEN T%02d player=%s boxes=%s" % [room+1, session.board.player-session.board.origin, session.board.boxes])
		var hashes: Array = []
		var keys: Array = []
		for action in session.level.solution:
			if not session.perform(action).legal:
				print("FAIL action " + action + " at " + str(session.board.player-session.board.origin))
				session.dispose()
				quit(1)
				return
			session.settle_sync()
			hashes.append(session.world.get_state_hash())
			keys.append(session.board.position_key())
			print("T%02d %s player=%s box=%s bag=%d" % [room+1, action, session.board.player-session.board.origin, session.board.boxes, session.board.total_bag()])
			if room == 2:
				for at in [Vector2i(4,4),Vector2i(4,5),Vector2i(5,5),Vector2i(6,5),Vector2i(4,6),Vector2i(6,4)]:
					print("  water %s=%d sand=%d category=%s" % [at, session.board.counts(at+session.board.origin).fluid, session.board.counts(at+session.board.origin).loose, session.board.category(at+session.board.origin)])
		if not session.board.won() or not session.errors.is_empty():
			print("FAIL T%02d victory=%s errors=%s" % [room+1, session.board.won(),session.errors])
			session.dispose()
			quit(1)
			return
		session.level.solution_hashes = hashes
		session.level.solution_keys = keys
		recordings.append(session.level.duplicate(true))
		session.dispose()
	DirAccess.make_dir_recursive_absolute("res://artifacts/stage1/recorded")
	for room in 4:
		var file := FileAccess.open("res://artifacts/stage1/recorded/t%02d.json" % (room+1), FileAccess.WRITE)
		file.store_string(JSON.stringify(recordings[room], "  ") + "\n")
	print("Record tutorial: 4/4")
	quit(0)
