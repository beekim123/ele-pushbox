extends SceneTree
## Runtime contract checks. Run in a disposable user-data directory.

var failures: Array[String] = []

func _initialize() -> void:
	call_deferred("_run")

func _expect(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)
		printerr("FAIL: " + message)

func _script(path: String) -> Script:
	if not FileAccess.file_exists(path):
		_expect(false, "core service has not been implemented: " + path)
		return null
	return load(path) as Script

func _run() -> void:
	var stat_script := _script("res://core/stats/stat.gd")
	if stat_script != null:
		var stat = stat_script.new(100.0, 0.0, 120.0)
		stat.add_modifier("test:add", 10.0, 0.0)
		stat.add_modifier("test:mul", 0.0, 0.5)
		_expect(is_equal_approx(stat.value(), 120.0), "stat applies source modifiers then clamps")
		stat.remove_modifier("test:mul")
		_expect(is_equal_approx(stat.value(), 110.0), "removing a stat modifier restores other sources")
	var save_script := _script("res://core/save/save_store.gd")
	if save_script != null:
		var save_path := "user://core-test-%s.json" % OS.get_process_id()
		var store = save_script.new(save_path)
		store.data["future_system"] = {"unknown": 7}
		store.mark_level("level:M01", true, false, 5)
		_expect(store.save_progress() == OK, "save writes atomically")
		var restored = save_script.new(save_path)
		_expect(restored.load_progress() == OK, "save reload succeeds")
		_expect(restored.data.get("future_system", {}).get("unknown") == 7, "unknown save sections survive roundtrip")
		_expect(restored.level_data("level:M01").get("cleared", false), "level progress survives roundtrip")
		restored.mark_level("level:M01", false, true, 99)
		_expect(restored.level_data("level:M01").get("cleared", false), "skipping a cleared level cannot erase completion")
		_expect(restored.level_data("level:M01").get("moves", 0) == 5, "worse replay cannot replace best move count")
		var corrupt := FileAccess.open(save_path, FileAccess.WRITE)
		corrupt.store_string("{broken")
		corrupt.close()
		var recovered = save_script.new(save_path)
		_expect(recovered.load_progress() != OK, "corrupt save is reported")
		_expect(not recovered.corrupt_backup.is_empty() and FileAccess.file_exists(recovered.corrupt_backup), "corrupt save is preserved as a backup")
		_expect(recovered.data.get("version") == 1, "corrupt save restores current schema")
		for candidate in [save_path, save_path + ".tmp", recovered.corrupt_backup]:
			if FileAccess.file_exists(candidate):
				DirAccess.remove_absolute(ProjectSettings.globalize_path(candidate))
		var invalid_structures: Array[Dictionary] = [
			{"version": 1, "progress": {"level:M01": null}},
			{"version": 1, "progress": []},
			{"version": 1, "settings": []},
			{"version": 1, "progress": {"level:M01": {"cleared": "yes"}}},
			{"version": 1, "progress": {"level:M01": {"moves": "five"}}},
			{"version": 1, "settings": {"music": []}},
			{"version": 1, "settings": {"show_grid": "false"}},
		]
		for index: int in invalid_structures.size():
			var structure_path := "user://core-bad-structure-%s-%d.json" % [OS.get_process_id(), index]
			var source_bytes := JSON.stringify(invalid_structures[index])
			var structure_file := FileAccess.open(structure_path, FileAccess.WRITE)
			structure_file.store_string(source_bytes)
			structure_file.close()
			var invalid_store = save_script.new(structure_path)
			var load_result: Error = invalid_store.load_progress()
			_expect(load_result == ERR_INVALID_DATA, "invalid known save structure is rejected: case %d" % index)
			var has_backup: bool = not invalid_store.corrupt_backup.is_empty() and FileAccess.file_exists(invalid_store.corrupt_backup)
			_expect(has_backup, "invalid known save structure is backed up: case %d" % index)
			if has_backup:
				_expect(FileAccess.get_file_as_string(invalid_store.corrupt_backup) == source_bytes, "invalid structure backup preserves exact input: case %d" % index)
			# Do not call level_data on the known bad row until load rejects it;
			# this keeps the red regression from crashing on null.duplicate().
			if load_result == ERR_INVALID_DATA:
				_expect(invalid_store.level_data("level:M01").get("cleared") == false, "invalid structure rebuilds usable default progress: case %d" % index)
			for candidate in [structure_path, invalid_store.corrupt_backup]:
				if FileAccess.file_exists(candidate):
					DirAccess.remove_absolute(ProjectSettings.globalize_path(candidate))
		var future_path := "user://core-future-shape-%s.json" % OS.get_process_id()
		# JSON's numeric values deserialize as floats in Godot. Use that
		# representation in this literal oracle so equality checks content,
		# not an int-versus-float distinction absent from the JSON format.
		var opaque: Array = ["opaque", null, {"nested": [1.0, true]}]
		var future_file := FileAccess.open(future_path, FileAccess.WRITE)
		future_file.store_string(JSON.stringify({"version": 1, "progress": {}, "settings": {}, "future_system": opaque}))
		future_file.close()
		var future_store = save_script.new(future_path)
		_expect(future_store.load_progress() == OK, "unknown save sections do not trigger structure recovery")
		_expect(future_store.data.get("future_system") == opaque, "unknown save section values survive type validation unchanged")
		DirAccess.remove_absolute(ProjectSettings.globalize_path(future_path))
	var save_service_script := _script("res://app/autoload/save.gd")
	if save_service_script != null:
		var old_storage := OS.get_environment("PUSHBOX_TEST_STORAGE")
		var test_directory := OS.get_environment("TMPDIR").path_join("portitor-save-service-%s" % OS.get_process_id())
		if test_directory.is_empty() or not test_directory.is_absolute_path():
			test_directory = "/tmp/portitor-save-service-%s" % OS.get_process_id()
		OS.set_environment("PUSHBOX_TEST_STORAGE", test_directory)
		var service = save_service_script.new()
		# Guard before any persistence operation: a failing test must never
		# write the real user://progress.json.
		var isolated: bool = service._store.location == test_directory.path_join("progress.json")
		_expect(isolated, "SaveService honors the isolated test storage directory")
		if isolated:
			root.add_child(service)
			service.mark_level("level:M01", true, false, 3)
			_expect(FileAccess.file_exists(test_directory.path_join("progress.json")), "SaveService persists only inside the test directory")
			DirAccess.remove_absolute(test_directory.path_join("progress.json"))
			DirAccess.remove_absolute(test_directory)
		service.free()
		if old_storage.is_empty():
			OS.unset_environment("PUSHBOX_TEST_STORAGE")
		else:
			OS.set_environment("PUSHBOX_TEST_STORAGE", old_storage)
	var settings_script := _script("res://app/autoload/settings.gd")
	if settings_script != null:
		var settings = settings_script.new()
		settings.set_value("music", 100)
		_expect(settings.values.get("music") == 1.0, "volume is clamped to supported range")
		settings.set_value("ambience", "invalid")
		_expect(settings.values.get("ambience") == "full", "invalid environment choice preserves a valid mode")
		settings.free()
	var locale_script := _script("res://app/autoload/locale.gd")
	if locale_script != null:
		# Real TranslationServer fixture: the test does not depend on generated
		# content or accept a missing-key fallback as successful translation.
		var english := Translation.new()
		english.locale = "en"
		english.add_message("hint.title", "Hint {n}/3")
		TranslationServer.add_translation(english)
		var locale = locale_script.new()
		root.add_child(locale)
		locale.language = "en"
		_expect(locale.text("text:hint.title", {"n": 2}) == "Hint 2/3", "locale substitutes named parameters")
		locale.language = "zh-Hans"
		_expect(locale.language == "zh-Hans", "locale accepts the authoring locale name")
		locale.free()
		TranslationServer.remove_translation(english)
	print("core services: %d failure(s)" % failures.size())
	quit(0 if failures.is_empty() else 1)
