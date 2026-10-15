class_name SaveStore
extends RefCounted

const SCHEMA = preload("res://core/save/schema.gd")
var data: Dictionary = SCHEMA.defaults()
var location: String
var corrupt_backup: String = ""

func _init(save_location: String = "user://progress.json") -> void:
	location = save_location

func load_progress() -> Error:
	corrupt_backup = ""
	if not FileAccess.file_exists(location):
		data = SCHEMA.defaults()
		return OK
	var parser := JSON.new()
	var result := parser.parse(FileAccess.get_file_as_string(location))
	if result != OK or not parser.data is Dictionary:
		return _recover_corrupt(ERR_PARSE_ERROR)
	var source: Dictionary = parser.data
	if not _valid_structure(source):
		return _recover_corrupt(ERR_INVALID_DATA)
	data = SCHEMA.normalize(source)
	return OK

func _valid_structure(source: Dictionary) -> bool:
	var version: Variant = source.get("version")
	if not _is_number(version) or float(version) != float(SCHEMA.VERSION):
		return false
	# Missing version-one sections may take their defaults. A present known
	# section with the wrong shape is corrupt and must never be normalized
	# into an apparently successful empty save.
	for section: String in SCHEMA.SECTIONS:
		if source.has(section) and not source[section] is Dictionary:
			return false
	var progress: Dictionary = source.get("progress", {})
	for row: Variant in progress.values():
		if not row is Dictionary:
			return false
		for field: String in ["cleared", "skipped"]:
			if row.has(field) and not row[field] is bool:
				return false
		if row.has("moves"):
			if not _is_number(row.moves) or float(row.moves) < 0.0 or float(row.moves) != floorf(float(row.moves)):
				return false
	var settings: Dictionary = source.get("settings", {})
	for field: String in ["language", "ambience"]:
		if settings.has(field) and not settings[field] is String:
			return false
	for field: String in ["music", "sfx"]:
		if settings.has(field) and not _is_number(settings[field]):
			return false
	for field: String in ["show_grid", "open_all_levels", "typewriter"]:
		if settings.has(field) and not settings[field] is bool:
			return false
	if settings.has("window_scale") and not settings.window_scale is String:
		if not _is_number(settings.window_scale) or float(settings.window_scale) != floorf(float(settings.window_scale)):
			return false
	# Unknown top-level sections, settings and progress-row fields retain all
	# JSON values for forward compatibility; only known field types are checked.
	return true

func _is_number(value: Variant) -> bool:
	return (value is int or value is float) and is_finite(float(value))

func save_progress() -> Error:
	var target := ProjectSettings.globalize_path(location)
	var directory := target.get_base_dir()
	var result := DirAccess.make_dir_recursive_absolute(directory)
	if result != OK:
		return result
	var temporary := target + ".tmp"
	var file := FileAccess.open(temporary, FileAccess.WRITE)
	if file == null:
		return FileAccess.get_open_error()
	file.store_string(JSON.stringify(data, "\t") + "\n")
	file.flush()
	file.close()
	return DirAccess.rename_absolute(temporary, target)

func level_data(uid: String) -> Dictionary:
	return data.get("progress", {}).get(uid, {"cleared": false, "skipped": false, "moves": 0}).duplicate(true)

func mark_level(uid: String, cleared: bool, skipped: bool, moves: int) -> void:
	if not uid.begins_with("level:"):
		push_error("Progress requires a level uid")
		return
	var previous := level_data(uid)
	var was_cleared := bool(previous.get("cleared", false))
	previous["cleared"] = was_cleared or cleared
	previous["skipped"] = (bool(previous.get("skipped", false)) or skipped) and not previous.cleared
	if cleared and (not was_cleared or int(previous.get("moves", 0)) > moves):
		previous["moves"] = maxi(0, moves)
	data["progress"][uid] = previous

func _recover_corrupt(reason: Error) -> Error:
	var suffix := "%s-%s" % [int(Time.get_unix_time_from_system() * 1000.0), OS.get_process_id()]
	var backup := location + ".corrupt-" + suffix
	var result := DirAccess.rename_absolute(ProjectSettings.globalize_path(location), ProjectSettings.globalize_path(backup))
	if result == OK:
		corrupt_backup = backup
	data = SCHEMA.defaults()
	return reason
