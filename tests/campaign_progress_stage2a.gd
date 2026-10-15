extends SceneTree
const Lobby := preload("res://pushbox/scripts/ui/lobby_view.gd")
const Game := preload("res://pushbox/scripts/game.gd")
var checks: int = 0
var failures: int = 0
func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		print("FAIL " + label)
func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	var lobby := Lobby.new()
	lobby.progress_path = "user://campaign-progress-test.json"
	DirAccess.remove_absolute(lobby.progress_path)
	root.add_child(lobby)
	lobby.all_levels_open = false # Exercise earned progression with the override off.
	if not lobby.has_method("map_unlocked"):
		check(false, "campaign progression API exists")
	else:
		for map in 6:
			check(lobby.map_unlocked(map) == (map == 0), "only first map starts unlocked")
		for map in 6:
			for i in 6:
				check(lobby.level_unlocked(map,i) == (i < 2), "fresh map opens first pair")
			for pair in [[1,4],[3,6],[5,6]]:
				lobby.mark_completed(lobby.Catalog.id(map,pair[0]))
				lobby.mark_completed(lobby.Catalog.id(map,pair[0]))
				check(lobby.map_count(map) == (1 if pair[0] == 1 else (2 if pair[0] == 3 else 3)), "duplicate wins do not count twice")
				check(lobby.level_unlocked(map,pair[1]-1), "sliding pair opens")
			check(lobby.badge(map) == "通行银章", "any three grant silver")
			if map < 5:
				check(lobby.map_unlocked(map+1), "any three immediately unlock next map")
		check(lobby.mainline_complete(), "all six silver badges finish mainline")
		for map in 6:
			for i in [0,2,4]:
				lobby.mark_completed(lobby.Catalog.id(map,i))
			check(lobby.badge(map) == "全清金冠", "all six grant gold")
		lobby.load_progress()
		check(lobby.completed.size() == 36 and lobby.mainline_complete(), "36 wins survive durable reload")
		lobby.mark_completed("invalid")
		check(lobby.completed.size() == 36, "unknown ids rejected")
		for invalid in ["D_1","D_001","D_00","D_07","Q_01","F_1a","t01"]:
			check(lobby.Catalog.locate(invalid).x < 0,"malformed campaign ids rejected")
		var selected_levels: Array = []
		lobby.level_selected.connect(func(index: int) -> void: selected_levels.append(index))
		lobby.show_page("challenge")
		lobby.activate()
		check(selected_levels.is_empty(), "future challenge panel cannot launch a tutorial")
		check(lobby.page == "modes", "future challenge panel returns to lobby")
		check(lobby.has_method("begin_progress_write"), "progress write can use the existing single worker")
		if lobby.has_method("begin_progress_write"):
			var durable_path: String = lobby.progress_path
			lobby.mark_completed("t01",true)
			check(lobby.begin_progress_write(), "begin immutable progress write")
			lobby.mark_completed("t02",true)
			check(lobby.finish_progress_write(true) and not lobby._staged_save and lobby._save_pending,"new win invalidates older in-flight payload")
			check(lobby.begin_progress_write() and lobby.finish_progress_write(true) and lobby._staged_save,"latest payload stages successfully")
			lobby.commit_progress()
			lobby.load_progress()
			check(lobby.completed.size() == 38 and lobby.completed.has("t02"),"async commit preserves both new wins and all 36 levels")
			lobby.progress_path = "/dev/null/progress-async.json"
			lobby.mark_completed("t03",true)
			check(lobby.begin_progress_write() and lobby.finish_progress_write(true) and lobby._save_pending and not lobby._staged_save,"failed async write remains retryable")
			lobby.progress_path = durable_path
			lobby.save_progress()
			lobby.load_progress()
			check(lobby.completed.has("t03"),"sync retry durably saves a failed async payload")
	lobby.free()
	DirAccess.remove_absolute("user://campaign-progress-test.json")
	all_levels_settings_checks()
	print("Campaign progression: %d checks, %d failures" % [checks,failures])
	quit(1 if failures else 0)

func all_levels_settings_checks() -> void:
	var path: String = "user://all-levels-settings-test.json"
	DirAccess.remove_absolute(path)
	var lobby := Lobby.new()
	lobby.progress_path = path
	root.add_child(lobby)
	if not lobby.has_method("set_all_levels_open"):
		check(false,"settings can open every campaign level without granting victories")
		lobby.free()
		return
	for map in 6:
		check(lobby.map_unlocked(map),"default setting opens each map")
		for index in 6:
			check(lobby.level_unlocked(map,index),"default setting permits all 36 levels")
	check(not lobby.map_unlocked(-1) and not lobby.map_unlocked(6) and not lobby.level_unlocked(0,6) and not lobby.level_unlocked(6,0),"open-all setting rejects invalid selections")
	check(lobby.completed.is_empty() and lobby.badge(5) == "尚未通行" and not lobby.mainline_complete(),"open-all grants no wins badges or mainline completion")
	lobby.call("set_all_levels_open",false)
	check(not lobby.map_unlocked(5) and lobby.level_unlocked(0,0) and not lobby.level_unlocked(0,2),"turning off restores normal progression")
	lobby.mark_completed("D_01")
	check(lobby.level_unlocked(0,3) and not lobby.map_unlocked(1),"real completion still expands the normal pool")
	lobby.free()
	var reloaded := Lobby.new()
	reloaded.progress_path = path
	root.add_child(reloaded)
	check(reloaded.get("all_levels_open") == false and not reloaded.map_unlocked(5) and reloaded.completed.size() == 1,"closed setting and real win survive restart")
	reloaded.call("set_all_levels_open",true)
	reloaded.load_progress()
	check(reloaded.level_unlocked(5,5) and reloaded.completed.size() == 1 and reloaded.map_count(0) == 1,"reopening persists without changing actual progress")
	reloaded.mark_completed("D_02",true)
	check(reloaded.begin_progress_write(),"prepare in-flight progress before setting toggle")
	reloaded.call("set_all_levels_open",false)
	reloaded.load_progress()
	check(reloaded.get("all_levels_open") == false and reloaded.completed.has("D_02"),"setting change survives in-flight write without dropping a win")
	reloaded.free()
	var legacy_path: String = path+"-legacy"
	var file := FileAccess.open(legacy_path,FileAccess.WRITE)
	file.store_string('{"version":2,"completed":{"D_01":true}}')
	file.close()
	var legacy := Lobby.new()
	legacy.progress_path = legacy_path
	root.add_child(legacy)
	check(legacy.level_unlocked(5,5) and legacy.completed.size() == 1 and legacy.completed.has("D_01"),"existing saves without the setting open all levels and keep their wins")
	legacy.free()
	DirAccess.remove_absolute(legacy_path)
	var game := Game.new()
	game.start_in_lobby = true
	game.progress_path = path
	root.add_child(game)
	game._lobby_settings()
	check(game.pause_menu.get("all_levels_open") == false,"settings menu reflects persisted value")
	game.pause_menu.selected = 2
	var enter := InputEventKey.new()
	enter.physical_keycode = KEY_ENTER
	enter.pressed = true
	game.pause_menu.handle(enter)
	check(game.pause_menu.opened and game.lobby.level_unlocked(5,5) and game.pause_menu.get("all_levels_open") == true,"settings keyboard toggle opens every map immediately")
	game.pause_menu.close()
	game.select_campaign(5,5)
	check(game.session != null and game.session.level.id == "X_06","fresh progress can enter final campaign level")
	check(game.lobby.completed.size() == 2 and game.lobby.map_count(5) == 0,"opening final level fabricates no progress")
	var before: String = game.session.world.get_state_hash()
	game.pause_menu.opened = true
	game.pause_menu.page = "settings"
	game.pause_menu.selected = 2
	game.pause_menu.handle(enter)
	check(not game.lobby.level_unlocked(5,5) and game.session.level.id == "X_06" and game.session.world.get_state_hash() == before,"in-game toggle preserves the active board and SDK state")
	game.free()
	DirAccess.remove_absolute(path)
