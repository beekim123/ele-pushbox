extends SceneTree

const Session := preload("res://pushbox/scripts/session.gd")

func _initialize() -> void:
	for room in 5:
		var path: String = "res://pushbox/levels/d%d.json" % (room + 1)
		var session := Session.new()
		if session.load_level(path, root) != "":
			quit(1)
			return
		session.settle_sync()
		var hashes: Array = []
		var keys: Array = []
		for action in session.level.solution:
			if not session.perform(action).legal:
				quit(1)
				return
			session.settle_sync()
			hashes.append(session.world.get_state_hash())
			keys.append(session.board.position_key())
		if not session.board.won() or not session.errors.is_empty():
			quit(1)
			return
		session.level.solution_hashes = hashes
		session.level.solution_keys = keys
		var file := FileAccess.open(path, FileAccess.WRITE)
		file.store_string(JSON.stringify(session.level, "  ") + "\n")
		print("RECORDED D%d: %d author hashes and position keys" % [room + 1, hashes.size()])
		session.dispose()
	quit(0)
