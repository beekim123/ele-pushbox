extends SceneTree
const Lobby := preload("res://pushbox/scripts/ui/lobby_view.gd")
var checks: int = 0
var failures: int = 0
func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		print("FAIL " + label)
func _initialize() -> void:
	var lobby := Lobby.new()
	lobby.progress_path = "user://campaign-progress-test.json"
	DirAccess.remove_absolute(lobby.progress_path)
	root.add_child(lobby)
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
	print("Campaign progression: %d checks, %d failures" % [checks,failures])
	quit(1 if failures else 0)
