extends SceneTree
## Compare scheduled work against the frozen original Session and recorded hashes.
const Session := preload("res://pushbox/scripts/session.gd")
const Original := preload("res://tests/fixtures/session_sync_v03.gd")
var checks: int = 0
var failures: int = 0

func check(value: bool, message: String) -> void:
	checks += 1
	if not value:
		failures += 1
		print("FAIL " + message)

func finish_frames(session: RefCounted) -> void:
	var calls: int = 0
	while session.running and calls < 10000:
		var old_phase: int = session.phase
		var old_tick: int = session.world.get_tick()
		session.advance_frame(4)
		if old_phase != session.Phase.TICKS and old_phase != session.Phase.COMMIT_LAST:
			check(session.world.get_tick() == old_tick, "read/count/resolve/key phases never add SDK ticks")
		calls += 1
	check(not session.running, "scheduled settlement completes")

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	var probe := Session.new()
	if not probe.has_method("advance_frame"):
		check(false, "Session can yield read/count/resolve/key work between frames")
		print("Session scheduling: %d checks, %d failures" % [checks, failures])
		quit(1)
		return
	probe = null
	for room in 5:
		var scheduled := Session.new()
		var original := Original.new()
		var path: String = "res://pushbox/levels/d%d.json" % (room+1)
		check(scheduled.load_level(path, root) == "", "scheduled load")
		check(original.load_level(path, root) == "", "original load")
		finish_frames(scheduled)
		original.settle_sync()
		check(scheduled.world.get_state_hash() == original.world.get_state_hash(), "opening world identical to original")
		check(scheduled.history == original.history, "opening hint keys unchanged")
		scheduled.seal_opening()
		original.seal_opening()
		for step in scheduled.level.solution.size():
			var action: String = scheduled.level.solution[step]
			check(scheduled.perform(action, true).legal and original.perform(action, true).legal, "author action legal")
			finish_frames(scheduled)
			original.settle_sync()
			check(scheduled.world.get_tick() == original.world.get_tick(), "same stop tick")
			check(scheduled.world.get_state_hash() == scheduled.level.solution_hashes[step], "recorded T1 hash unchanged")
			check(scheduled.world.get_state_hash() == original.world.get_state_hash(), "same complete original SDK hash")
			check(scheduled.board.state() == original.board.state(), "same complete original discrete state")
			check(scheduled.history == original.history and scheduled.last_rounds == original.last_rounds, "same keys and round count")
		check(scheduled.board.won() and scheduled.errors.is_empty(), "author solution wins without warnings")
		if room == 0:
			# Only the player falls; capped final round has no SDK commands.
			scheduled.board.rules.settle.max_rounds = 1
			original.board.rules.settle.max_rounds = 1
			check(scheduled.perform("R").legal and original.perform("R").legal, "empty warning fixture action")
			finish_frames(scheduled)
			original.settle_sync()
			check(scheduled.errors == original.errors and scheduled.errors == ["max_rounds reached"], "empty final commit preserves original warning")
			check(scheduled.world.get_tick() == original.world.get_tick() and scheduled.world.get_state_hash() == original.world.get_state_hash(), "empty final commit adds no extra SDK tick")
			check(scheduled.board.state() == original.board.state() and scheduled.history == original.history, "empty final commit completes with original state and history")
		scheduled.dispose()
		original.dispose()
	# Interrupt after material reading has begun; undo must cancel pending work.
	var s := Session.new()
	check(s.load_level("res://pushbox/levels/d2.json", root) == "", "undo fixture load")
	finish_frames(s)
	s.seal_opening()
	var opening_hash: String = s.world.get_state_hash()
	var opening_state: Dictionary = s.board.state()
	check(s.perform("DIG_L", true).legal, "undo fixture action")
	while s.running and s.phase != s.Phase.COUNTS:
		s.advance_frame(1)
	check(s.running and s.phase == s.Phase.COUNTS, "interrupt inside staged read work")
	check(s.undo(), "undo succeeds mid-read")
	s.advance_frame(4)
	check(not s.running and s.world.get_state_hash() == opening_hash and s.board.state() == opening_state, "undo cancels pending phases without a later tick")
	check(s.perform("DIG_L").legal, "action legal after interrupted undo")
	finish_frames(s)
	check(s.board.total_bag() == 220 and s.world.get_state_hash() == s.level.solution_hashes[0], "redo retains D2 numeric fixture and hash")
	s.dispose()
	# A capped round with crate/gate writes must commit the original final tick.
	var capped := Session.new()
	var capped_original := Original.new()
	check(capped.load_level("res://pushbox/levels/d4.json", root) == "" and capped_original.load_level("res://pushbox/levels/d4.json", root) == "", "nonempty warning fixture load")
	finish_frames(capped)
	capped_original.settle_sync()
	for _i in 2:
		check(capped.perform("R").legal and capped_original.perform("R").legal, "nonempty warning setup action")
		finish_frames(capped)
		capped_original.settle_sync()
	capped.board.rules.settle.max_rounds = 1
	capped_original.board.rules.settle.max_rounds = 1
	check(capped.perform("R").legal and capped_original.perform("R").legal, "nonempty warning action")
	finish_frames(capped)
	capped_original.settle_sync()
	check(capped.errors == ["max_rounds reached"] and capped.errors == capped_original.errors, "nonempty final commit warning unchanged")
	check(capped.world.get_tick() == capped_original.world.get_tick() and capped.world.get_state_hash() == capped_original.world.get_state_hash(), "nonempty final commit retains original SDK ticks/hash")
	check(capped.board.state() == capped_original.board.state() and capped.history == capped_original.history, "nonempty final commit retains original discrete state/key")
	capped.dispose()
	capped_original.dispose()
	# Undo during a biome mutation must discard its unfinished round cursor,
	# before any of the queued commands are submitted to the SDK.
	var staged := Session.new()
	check(staged.load_level("res://pushbox/levels/campaign/ruins/c_ruins_04.json",root) == "","staged mechanism fixture loads")
	finish_frames(staged)
	staged.seal_opening()
	var staged_hash: String = staged.world.get_state_hash()
	var staged_state: Dictionary = staged.board.state()
	check(staged.perform("USE",true).legal,"staged hourglass action")
	var guard: int = 0
	while staged.running and not (staged.board._round_active and staged.board._round_changed) and guard < 2000:
		staged.advance_frame(4)
		guard += 1
	check(staged.board._round_active and staged.board.mechanisms.hourglasses[0].get("opened",false),"interrupt after hourglass mutation before round commit")
	check(staged.undo(),"undo unfinished biome round")
	staged.advance_frame(4)
	check(not staged.board._round_active and not staged.running and staged.world.get_state_hash() == staged_hash and staged.board.state() == staged_state,"undo cancels staged mechanism and pending SDK writes")
	check(staged.perform("USE",true).legal,"redo staged mechanism")
	finish_frames(staged)
	check(staged.world.get_state_hash() == staged.level.solution_hashes[0] and staged.board.position_key() == staged.level.solution_keys[0],"sliced mechanism retains recorded hash and key")
	check(staged.undo() and staged.perform("USE",true).legal,"prepare interrupted category key")
	guard = 0
	while staged.running and staged.phase != staged.Phase.CATEGORIES and guard < 2000:
		staged.advance_frame(4)
		guard += 1
	staged.advance_frame(4)
	check(staged.phase == staged.Phase.CATEGORIES and staged._key_cursor == 64,"key categories span bounded frozen frames")
	check(staged.undo(),"undo partial category key")
	staged.advance_frame(4)
	check(not staged.running and staged._key_cursor == 0 and staged.world.get_state_hash() == staged_hash and staged.board.state() == staged_state,"undo discards partial key without a later history commit")
	staged.dispose()
	print("Session scheduling: %d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)
