extends SceneTree
const Session := preload("res://pushbox/scripts/session.gd")
const Preview := preload("res://pushbox/scripts/preview.gd")
const Catalog := preload("res://pushbox/scripts/campaign_catalog.gd")
const Game := preload("res://pushbox/scripts/game.gd")
var checks: int = 0
var failures: int = 0
var solved: int = 0
var rows: Array = []
func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		print("FAIL " + label)
func _initialize() -> void:
	call_deferred("run")
func key(game: Node, code: int) -> void:
	var event := InputEventKey.new()
	event.physical_keycode = code
	event.pressed = true
	game._input(event)
func run() -> void:
	for map in 6:
		for index in 6:
			var id: String = Catalog.id(map,index)
			var s := Session.new()
			var reason: String = s.load_level(Catalog.path(map,index),root)
			check(reason == "",id + " loads: " + reason)
			if not reason.is_empty():
				continue
			s.settle_sync()
			s.seal_opening()
			check(s.level.id == id and s.level.campaign.stars == index/2+1, id + " identity and difficulty")
			check(not s.board.won() and not s.level.solution.is_empty(),id + " nontrivial author solution")
			check(s.level.solution.size() == s.level.solution_hashes.size() and s.level.solution.size() == s.level.solution_keys.size(),id + " every step has an author hash and key")
			var preview := Preview.new()
			var raised_by_pour: Dictionary = {}
			check(preview.configure(s,root) == "",id + " T6 preview loads")
			for step in s.level.solution.size():
				var action: String = s.level.solution[step]
				var label: String = "%s step %d %s" % [id,step+1,action]
				check(action != "U" or not s.board.action_reason("USE").is_empty(),label + " climb is reachable through real Up input")
				var before: String = s.world.get_state_hash()
				var state: Dictionary = s.board.state()
				var prediction: Dictionary = preview.predict(s,action)
				check(prediction.get("legal",false),label + " T6 action legal")
				check(s.world.get_state_hash() == before and s.board.state() == state,label + " preview leaves real state untouched")
				check(s.perform(action,true).legal,label + " T1 action legal")
				s.settle_sync()
				var hash_value: String = s.world.get_state_hash()
				var after_state: Dictionary = s.board.state()
				if action.begins_with("POUR_"):
					for box_index in after_state.boxes.size():
						var box: Dictionary = after_state.boxes[box_index]
						if box.kind == "wood" and box.at[1] < state.boxes[box_index].at[1]:
							raised_by_pour[box.id] = true
				check(hash_value == s.level.solution_hashes[step] and s.board.position_key() == s.level.solution_keys[step],label + " T1 author hash and key")
				check(hash_value == prediction.get("hash") and after_state == prediction.get("game_state") and s.world.get_tick() == prediction.get("tick"),label + " T6 exact SDK, mechanism state, stop tick")
				check(s.errors.is_empty() and s.last_rounds <= 16 and s.max_round_ticks <= 1200,label + " T7 no timeout or oscillation " + str(s.errors))
				check(s.undo() and s.world.get_state_hash() == before and s.board.state() == state,label + " T5 restores complete state")
				check(s.perform(action).legal,label + " T5 repeated action legal")
				s.settle_sync()
				check(hash_value == s.world.get_state_hash() and s.board.state() == after_state,label + " T5 identical replay")
			check(s.board.won(),id + " all goals occupied")
			if id == "D_06":
				check(raised_by_pour.has("A") and raised_by_pour.has("B"),"D_06 both wood crates rise after pouring recovered mine sand")
			if id == "D_05":
				check(raised_by_pour.has("A"),"D_05 buoyancy requires pouring excavated sand")
			if s.board.won():
				solved += 1
			rows.append({"id":id,"actions":s.level.solution.size(),"won":s.board.won(),"errors":Array(s.errors)})
			check(s.restart() and s.board.moves == 0,id + " restart restores opening mechanisms")
			preview.dispose()
			s.dispose()
			print("PASS campaign ",id)
	check(solved == 36,"36/36 campaign levels solved")
	await ui_checks()
	var output := FileAccess.open("res://artifacts/stage2a/campaign-verification.json",FileAccess.WRITE)
	output.store_string(JSON.stringify({"solved":solved,"total":36,"checks":checks,"failures":failures,"levels":rows,"workers":1},"  ")+"\n")
	output.close()
	print("Campaign Stage2A: %d/36 solved, %d checks, %d failures" % [solved,checks,failures])
	quit(1 if failures else 0)
func ui_checks() -> void:
	var game := Game.new()
	game.start_in_lobby = true
	game.progress_path = "user://stage2a-ui-test.json"
	DirAccess.remove_absolute(game.progress_path)
	root.add_child(game)
	game.lobby.selected = 1
	key(game,KEY_ENTER)
	check(game.lobby.page == "campaign","Enter opens map pool")
	for map in 6:
		game.lobby.map_index = map
		for index in 6:
			game.lobby.selected = index
			key(game,KEY_TAB)
			check(game.showcase.visible and game.showcase.campaign_mode and game.showcase.map_data.title == Catalog.TITLES[map][index],"Tab observes actual level including locks")
			check(game.session == null and game.lobby.completed.is_empty(),"observation starts no physics and grants no win")
			key(game,KEY_TAB)
			check(game.lobby.visible and game.lobby.page == "campaign" and not game.showcase.visible,"Tab returns to same pool")
	game.lobby.map_index = 0
	game.lobby.selected = 0
	key(game,KEY_ENTER)
	check(game.mode == "campaign" and game.session.level.id == "D_01","UI selection opens actual first campaign level")
	game.skip_animation = true
	for _i in 300:
		if not game.session.running and not game._opening:
			break
		await process_frame
	for action in game.session.level.solution:
		game.request_action(action)
		for _i in 300:
			if not game.session.running and game.animation_left == 0:
				break
			await process_frame
	check(game.session.board.won() and game.lobby.map_count(0) == 1,"real UI victory persists campaign progress")
	game.return_lobby("campaign")
	game.lobby.mark_completed("D_04")
	game.lobby.mark_completed("D_06")
	check(game.lobby.map_unlocked(1) and game.lobby.badge(0) == "通行银章","actual pool unlocks next style after nonconsecutive three wins")
	game.lobby.load_progress()
	check(game.lobby.map_count(0) == 3 and game.lobby.map_unlocked(1),"next map unlock survives UI save reload")
	game.lobby.mark_completed("F_01",true)
	game.free()
	var saved: Dictionary = Session.Loader.json("user://stage2a-ui-test.json")
	check(saved.get("completed",{}).get("F_01",false),"exiting flushes a pending campaign save")
	DirAccess.remove_absolute("user://stage2a-ui-test.json")
