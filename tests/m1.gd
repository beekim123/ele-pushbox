extends SceneTree

var failures: int = 0

func check(value: bool, message: String) -> void:
	if not value:
		failures += 1
		print("FAIL " + message)

func _initialize() -> void:
	if not FileAccess.file_exists("res://pushbox/scripts/session.gd"):
		check(false, "M1: turn session missing")
		quit(1)
		return
	var script: Script = load("res://pushbox/scripts/session.gd")
	var totals: Array = [37, 152, 143, 67, 331]
	# Independently measured final hashes in the C++ design reference, quiet=4.
	var reference_hashes: Array = ["f5035a8f3add078b", "0e2e31d497c8f065", "eaed66cff82f8d0e", "63a73ebeee246a90", "bccb123a3177c99e"]
	for i in 5:
		var session: RefCounted = script.new()
		check(session.load_level("res://pushbox/levels/d%d.json" % (i + 1), root) == "", "level load D%d" % (i + 1))
		session.settle_sync()
		for step in session.level.solution.size():
			var action: String = session.level.solution[step]
			check(session.perform(action).legal, "D%d step %d action legal" % [i + 1, step + 1])
			session.settle_sync()
			var b: RefCounted = session.board
			var o: Vector2i = b.origin
			if i == 1 and step == 0:
				check(b.total_bag() == 220, "D2 dig=220")
			if i == 1 and step == 1:
				check(b.counts(o + Vector2i(4, 4)).loose == 192, "D2 pour (4,4)=192")
				check(b.counts(o + Vector2i(3, 4)).loose == 58, "D2 pour (3,4)=58")
			if i == 2 and step == 5:
				check(b.counts(o + Vector2i(5, 4)).fluid == 160, "D3 (5,4)=160")
			if i == 4 and step == 0:
				check(b.counts(o + Vector2i(1, 2)).loose == 200, "D5 blast (1,2)=200")
			if i == 4 and step == 4:
				check(b.total_bag() == 456, "D5 bag=456")
			if i == 4 and step in [8, 9]:
				check(b.counts(o + Vector2i(7, 3)).fluid == (128 if step == 8 else 224), "D5 pour water")
			print("D%d step=%d action=%s ticks=%d rounds=%d player=%s bag=%d hash=%s" % [i + 1, step + 1, action, session.last_ticks, session.last_rounds, b.player - o, b.total_bag(), session.world.get_state_hash()])
		check(session.board.won(), "D%d victory" % (i + 1))
		check(session.world.get_state_hash() == reference_hashes[i], "D%d independent C++ final hash" % (i + 1))
		check(session.total_ticks == totals[i], "D%d total ticks expected %d actual %d" % [i + 1, totals[i], session.total_ticks])
		check(session.errors.is_empty(), "D%d settlement errors: %s" % [i + 1, session.errors])
		print("D%d WIN=%s ticks=%d" % [i + 1, session.board.won(), session.total_ticks])
		session.dispose()
	print("M1: %d failures" % failures)
	quit(1 if failures else 0)
