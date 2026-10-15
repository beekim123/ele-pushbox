class_name LevelCheckpointStore
extends RefCounted
## Persistent native SDK + game state checkpoints, committed by atomic manifest.
## Generations are immutable. A failed save never overwrites a referenced pair.

const VERSION: int = 1
const MANIFEST_FORMAT: String = "pushbox.checkpoint/1"
const STATE_FORMAT: String = "pushbox.checkpoint-state/1"
const MANIFEST_NAME: String = "manifest.json"
const BACKUP_NAME: String = "manifest.prev.json"
const SDK_NAME: String = "world.snap"
const STATE_NAME: String = "state.json"
const Grid = preload("res://gameplay/grid/grid_state.gd")

var last_error: String = ""
var load_status: String = "not_found"
var _serial: int = 0

func save_checkpoint(world, state: Dictionary, uid: String, spec_hash: String) -> Error:
	last_error = ""
	if not _valid_identity(uid, spec_hash) or not _valid_game_state(state):
		return _fail(ERR_INVALID_DATA, "Checkpoint requires a uid, a SHA-256 specification hash and a valid game snapshot state")
	var directory: String = _directory(uid)
	var error: Error = DirAccess.make_dir_recursive_absolute(directory)
	if error != OK:
		return _fail(error, "Cannot create checkpoint directory: %s" % directory)
	var primary: Dictionary = _read_manifest(directory.path_join(MANIFEST_NAME), uid)
	var backup: Dictionary = _read_manifest(directory.path_join(BACKUP_NAME), uid)
	var previous: Array[Dictionary] = _valid_records(directory, primary, uid, spec_hash)
	if previous.is_empty():
		previous = _valid_records(directory, backup, uid, spec_hash)
	var generation: String = _new_generation(directory)
	if generation.is_empty():
		return _fail(ERR_ALREADY_EXISTS, "Cannot allocate a unique checkpoint generation")
	var generation_dir: String = directory.path_join(generation)
	error = DirAccess.make_dir_absolute(generation_dir)
	if error != OK:
		return _fail(error, "Cannot create checkpoint generation: %s" % generation)
	var sdk_path: String = generation_dir.path_join(SDK_NAME)
	var original_world_error: String = str(world.last_error)
	var sdk_error: int = int(world.save_snapshot(sdk_path))
	var snapshot_error: String = str(world.last_error)
	# Persistence failure is reported by this store, not as a physics failure.
	world.last_error = original_world_error
	if sdk_error != OK:
		_remove_generation(directory, generation)
		return _fail(ERR_CANT_CREATE, "Cannot save checkpoint SDK snapshot (SDK %d): %s" % [sdk_error, snapshot_error])
	var sdk_bytes: int = _file_size(sdk_path)
	var sdk_sha: String = FileAccess.get_sha256(sdk_path)
	if sdk_bytes <= 0 or not _valid_sha(sdk_sha):
		_remove_generation(directory, generation)
		return _fail(ERR_FILE_CORRUPT, "Saved checkpoint SDK snapshot is empty or unreadable")
	var envelope: Dictionary = {"format": STATE_FORMAT, "version": VERSION, "uid": uid, "spec_hash": spec_hash, "generation": generation, "state": state}
	var state_text: String = JSON.stringify(envelope)
	var state_path: String = generation_dir.path_join(STATE_NAME)
	error = _write_verified(state_path, state_text)
	if error != OK:
		_remove_generation(directory, generation)
		return _fail(error, "Cannot write and verify checkpoint game state")
	var record: Dictionary = {"version": VERSION, "uid": uid, "spec_hash": spec_hash, "generation": generation, "sdk_sha256": sdk_sha, "sdk_bytes": sdk_bytes, "state_sha256": state_text.sha256_text(), "state_bytes": state_text.to_utf8_buffer().size()}
	# This second read checks both completed files and every state-envelope field.
	if _validated_state(directory, record, uid, spec_hash).is_empty():
		_remove_generation(directory, generation)
		return _fail(ERR_FILE_CORRUPT, "Checkpoint readback, metadata or SHA-256 verification failed")
	var records: Array[Dictionary] = [record]
	if not previous.is_empty():
		records.append(previous[0].duplicate(true))
	var manifest: Dictionary = _manifest(uid, spec_hash, records)
	# Refresh the fallback before replacing the primary. If either rename fails,
	# the old primary and all files it references remain untouched.
	if not primary.is_empty():
		var old_hash: String = str(primary.get("spec_hash", ""))
		var old_records: Array[Dictionary] = _valid_records(directory, primary, uid, old_hash)
		if not old_records.is_empty():
			error = _commit_manifest(directory.path_join(BACKUP_NAME), _manifest(uid, old_hash, old_records), generation)
			if error != OK:
				_remove_generation(directory, generation)
				return _fail(error, "Cannot commit checkpoint fallback manifest; previous checkpoint retained")
	error = _commit_manifest(directory.path_join(MANIFEST_NAME), manifest, generation)
	if error != OK:
		_remove_generation(directory, generation)
		return _fail(error, "Cannot atomically commit checkpoint manifest; previous checkpoint retained")
	# Cleanup is after the commit and only touches unreferenced owned generations.
	_prune(directory, uid)
	return OK

func load_checkpoint(world, uid: String, spec_hash: String) -> Dictionary:
	last_error = ""
	load_status = "not_found"
	if not _valid_identity(uid, spec_hash):
		load_status = "failed"
		_fail(ERR_INVALID_DATA, "Checkpoint load requires a uid and a SHA-256 specification hash")
		return {}
	var directory: String = _directory(uid)
	if not DirAccess.dir_exists_absolute(directory):
		return {}
	var primary_path: String = directory.path_join(MANIFEST_NAME)
	var backup_path: String = directory.path_join(BACKUP_NAME)
	var primary: Dictionary = _read_manifest(primary_path, uid)
	var backup: Dictionary = _read_manifest(backup_path, uid)
	var authoritative: Dictionary = primary if not primary.is_empty() else backup
	if not authoritative.is_empty() and str(authoritative.get("spec_hash", "")) != spec_hash:
		discard(uid)
		load_status = "spec_changed"
		var cleanup_error: String = last_error
		last_error = "Checkpoint invalidated because the level specification changed"
		if not cleanup_error.is_empty():
			last_error += "; " + cleanup_error
		return {}
	var attempted: Dictionary = {}
	var sdk_failures: Array[String] = []
	var original_world_error: String = str(world.last_error)
	for manifest: Dictionary in [primary, backup]:
		if manifest.is_empty() or str(manifest.get("spec_hash", "")) != spec_hash:
			continue
		for value: Variant in manifest.get("records", []):
			if not value is Dictionary:
				continue
			var record: Dictionary = value
			var generation: String = str(record.get("generation", ""))
			if attempted.has(generation):
				continue
			var state: Dictionary = _validated_state(directory, record, uid, spec_hash)
			if state.is_empty():
				continue
			# A damaged primary record must not suppress a valid reference to the
			# same generation in the fallback manifest.
			attempted[generation] = true
			var error: int = int(world.load_snapshot(directory.path_join(generation).path_join(SDK_NAME)))
			if error == OK:
				world.last_error = ""
				last_error = ""
				load_status = "loaded"
				return state
			sdk_failures.append("%s (SDK %d): %s" % [generation, error, str(world.last_error)])
			world.last_error = original_world_error
	if not FileAccess.file_exists(primary_path) and not FileAccess.file_exists(backup_path):
		return {}
	load_status = "failed"
	last_error = "No valid checkpoint with matching uid, specification, version and file hashes"
	if not sdk_failures.is_empty():
		last_error += "; native snapshot load failed: " + "; ".join(sdk_failures)
	return {}

func discard(uid: String) -> void:
	last_error = ""
	if uid.is_empty():
		last_error = "Cannot discard a checkpoint without its uid"
		return
	var directory: String = _directory(uid)
	var access: DirAccess = DirAccess.open(directory)
	if access == null:
		if DirAccess.dir_exists_absolute(directory):
			last_error = "Cannot open checkpoint directory for removal"
		return
	# Remove both publication points before deleting their payloads.
	for name: String in [MANIFEST_NAME, BACKUP_NAME]:
		var path: String = directory.path_join(name)
		if FileAccess.file_exists(path) and DirAccess.remove_absolute(path) != OK:
			last_error = "Cannot invalidate checkpoint manifest: " + name
			return
	for name: String in access.get_files():
		if _is_manifest_temporary(name):
			DirAccess.remove_absolute(directory.path_join(name))
	for name: String in access.get_directories():
		if _valid_generation(name):
			_remove_generation(directory, name)
	if DirAccess.remove_absolute(directory) != OK:
		last_error = "Checkpoint invalidated, but some unreferenced files could not be removed"

func _directory(uid: String) -> String:
	var test_root: String = OS.get_environment("PUSHBOX_TEST_STORAGE")
	var base: String = test_root.path_join("checkpoints") if not test_root.is_empty() else "user://checkpoints"
	# Raw resource identifiers never become path segments.
	return ProjectSettings.globalize_path(base.path_join(uid.sha256_text()))

func _new_generation(directory: String) -> String:
	for attempt: int in range(8):
		_serial += 1
		var nonce: String = "%d:%d:%d:%d" % [OS.get_process_id(), Time.get_ticks_usec(), int(Time.get_unix_time_from_system() * 1000000.0), _serial]
		var generation: String = "gen-" + nonce.sha256_text().left(32)
		if not DirAccess.dir_exists_absolute(directory.path_join(generation)) and not FileAccess.file_exists(directory.path_join(generation)):
			return generation
	return ""

func _manifest(uid: String, spec_hash: String, records: Array[Dictionary]) -> Dictionary:
	return {"format": MANIFEST_FORMAT, "version": VERSION, "uid": uid, "spec_hash": spec_hash, "records": records}

func _read_manifest(path: String, uid: String) -> Dictionary:
	if not FileAccess.file_exists(path):
		return {}
	var value: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	if not value is Dictionary:
		return {}
	var manifest: Dictionary = value
	if str(manifest.get("format", "")) != MANIFEST_FORMAT or manifest.get("version", 0) != VERSION or str(manifest.get("uid", "")) != uid:
		return {}
	if not _valid_sha(str(manifest.get("spec_hash", ""))) or not manifest.get("records", null) is Array:
		return {}
	var records: Array = manifest.records
	return manifest if records.size() >= 1 and records.size() <= 2 else {}

func _valid_records(directory: String, manifest: Dictionary, uid: String, spec_hash: String) -> Array[Dictionary]:
	var records: Array[Dictionary] = []
	if manifest.is_empty() or str(manifest.get("spec_hash", "")) != spec_hash:
		return records
	for value: Variant in manifest.get("records", []):
		if value is Dictionary and not _validated_state(directory, value, uid, spec_hash).is_empty():
			records.append(value.duplicate(true))
	return records

func _validated_state(directory: String, record: Dictionary, uid: String, spec_hash: String) -> Dictionary:
	var generation: String = str(record.get("generation", ""))
	if not _valid_generation(generation) or record.get("version", 0) != VERSION or str(record.get("uid", "")) != uid or str(record.get("spec_hash", "")) != spec_hash:
		return {}
	var generation_dir: String = directory.path_join(generation)
	var sdk_path: String = generation_dir.path_join(SDK_NAME)
	var state_path: String = generation_dir.path_join(STATE_NAME)
	if not _bounded_integer(record.get("sdk_bytes", null), 1, 2147483647) or not _bounded_integer(record.get("state_bytes", null), 1, 2147483647):
		return {}
	if not _verified_file(sdk_path, str(record.get("sdk_sha256", "")), int(record.get("sdk_bytes", 0))) or not _verified_file(state_path, str(record.get("state_sha256", "")), int(record.get("state_bytes", 0))):
		return {}
	var value: Variant = JSON.parse_string(FileAccess.get_file_as_string(state_path))
	if not value is Dictionary:
		return {}
	var envelope: Dictionary = value
	if str(envelope.get("format", "")) != STATE_FORMAT or envelope.get("version", 0) != VERSION or str(envelope.get("uid", "")) != uid or str(envelope.get("spec_hash", "")) != spec_hash or str(envelope.get("generation", "")) != generation:
		return {}
	var state: Variant = envelope.get("state", null)
	return state if state is Dictionary and _valid_game_state(state) else {}

func _verified_file(path: String, sha: String, size: int) -> bool:
	return size > 0 and _valid_sha(sha) and _file_size(path) == size and FileAccess.get_sha256(path) == sha

func _file_size(path: String) -> int:
	var file: FileAccess = FileAccess.open(path, FileAccess.READ)
	if file == null:
		return -1
	var size: int = file.get_length()
	file.close()
	return size

func _write_verified(path: String, text: String) -> Error:
	var file: FileAccess = FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		return FileAccess.get_open_error()
	file.store_string(text)
	file.flush()
	var error: Error = file.get_error()
	file.close()
	if error != OK:
		return error
	if not _verified_file(path, text.sha256_text(), text.to_utf8_buffer().size()) or FileAccess.get_file_as_string(path) != text:
		return ERR_FILE_CORRUPT
	return OK

func _commit_manifest(path: String, manifest: Dictionary, generation: String) -> Error:
	var temporary: String = path + "." + generation + ".tmp"
	var error: Error = _write_verified(temporary, JSON.stringify(manifest))
	if error == OK:
		# Both paths share a directory and filesystem; rename replaces atomically.
		error = DirAccess.rename_absolute(temporary, path)
	if error != OK and FileAccess.file_exists(temporary):
		DirAccess.remove_absolute(temporary)
	return error

func _prune(directory: String, uid: String) -> void:
	var keep: Dictionary = {}
	for name: String in [MANIFEST_NAME, BACKUP_NAME]:
		var manifest: Dictionary = _read_manifest(directory.path_join(name), uid)
		for value: Variant in manifest.get("records", []):
			if value is Dictionary and _valid_generation(str(value.get("generation", ""))):
				keep[str(value.generation)] = true
	var access: DirAccess = DirAccess.open(directory)
	if access == null:
		return
	for name: String in access.get_directories():
		if _valid_generation(name) and not keep.has(name):
			_remove_generation(directory, name)
	for name: String in access.get_files():
		if _is_manifest_temporary(name):
			DirAccess.remove_absolute(directory.path_join(name))

func _remove_generation(directory: String, generation: String) -> void:
	if not _valid_generation(generation):
		return
	var generation_dir: String = directory.path_join(generation)
	for name: String in [SDK_NAME, STATE_NAME]:
		var path: String = generation_dir.path_join(name)
		if FileAccess.file_exists(path):
			DirAccess.remove_absolute(path)
	DirAccess.remove_absolute(generation_dir)

func _is_manifest_temporary(name: String) -> bool:
	return (name.begins_with(MANIFEST_NAME + ".gen-") or name.begins_with(BACKUP_NAME + ".gen-")) and name.ends_with(".tmp")

func _valid_generation(value: String) -> bool:
	if not value.begins_with("gen-") or value.length() != 36:
		return false
	return _valid_hex(value.substr(4))

func _valid_sha(value: String) -> bool:
	return value.length() == 64 and _valid_hex(value)

func _valid_hex(value: String) -> bool:
	for index: int in range(value.length()):
		if value.substr(index, 1) not in "0123456789abcdef":
			return false
	return not value.is_empty()

func _valid_identity(uid: String, spec_hash: String) -> bool:
	return not uid.is_empty() and _valid_sha(spec_hash)

func _json_compatible(value: Variant) -> bool:
	match typeof(value):
		TYPE_NIL, TYPE_BOOL, TYPE_INT, TYPE_STRING, TYPE_STRING_NAME:
			return true
		TYPE_FLOAT:
			return is_finite(float(value))
		TYPE_ARRAY:
			for item: Variant in value:
				if not _json_compatible(item):
					return false
			return true
		TYPE_DICTIONARY:
			for key: Variant in value:
				if (not key is String and not key is StringName) or not _json_compatible(value[key]):
					return false
			return true
	return false

func _valid_game_state(state: Dictionary) -> bool:
	if not _json_compatible(state) or not state.get("grid", null) is Dictionary or not state.get("mechanisms", null) is Dictionary:
		return false
	var grid: Dictionary = state.grid
	if not _bounded_integer(grid.get("w", null), 3, 20) or not _bounded_integer(grid.get("h", null), 3, 10):
		return false
	var width: int = int(grid.w)
	var height: int = int(grid.h)
	var tiles: int = width * height
	if not grid.get("terrain", null) is Array or grid.terrain.size() != tiles:
		return false
	for value: Variant in grid.terrain:
		if not _bounded_integer(value, 0, Grid.Terrain.size() - 1):
			return false
	if not grid.get("player", null) is Dictionary or not _valid_position(grid.player, width, height):
		return false
	if not grid.get("crates", null) is Array:
		return false
	var occupied: Dictionary = {"%d:%d" % [int(grid.player.x), int(grid.player.y)]: true}
	var entity_ids: Dictionary = {}
	for value: Variant in grid.crates:
		if not value is Dictionary or not _valid_position(value, width, height) or not value.get("kind", null) is String or str(value.kind).is_empty():
			return false
		var key: String = "%d:%d" % [int(value.x), int(value.y)]
		if occupied.has(key):
			return false
		occupied[key] = true
		if value.has("id"):
			if not value.id is String or str(value.id).is_empty() or entity_ids.has(value.id):
				return false
			entity_ids[value.id] = true
	if not grid.get("bag", null) is Dictionary or not _bounded_integer(grid.bag.get("sand", null), 0, 9) or not _bounded_integer(grid.bag.get("bomb", null), 0, 2147483647):
		return false
	if not grid.get("open", null) is Array or not grid.get("devices", null) is Array or not _bounded_integer(grid.get("moves", null), 0, 2147483647):
		return false
	for value: Variant in grid.open:
		if not _bounded_integer(value, 0, 2):
			return false
	for value: Variant in grid.devices:
		if not value is Dictionary or not value.get("type", null) is String or str(value.type).is_empty():
			return false
	if grid.has("markers"):
		if not grid.markers is Array or grid.markers.size() != tiles:
			return false
		for value: Variant in grid.markers:
			if not _bounded_integer(value, 0, Grid.Marker.size() - 1):
				return false
	for value: Variant in state.mechanisms.values():
		if not value is Dictionary:
			return false
	if state.has("phase_ticks") and not _bounded_integer(state.phase_ticks, 0, 2147483647):
		return false
	if state.has("layer_pulses"):
		if not state.layer_pulses is Array:
			return false
		for value: Variant in state.layer_pulses:
			if not value is Dictionary or not value.get("layer", null) is String or str(value.layer).is_empty() or not value.get("area", null) is Array or value.area.size() != 4:
				return false
			var area: Array = value.area
			if not _bounded_integer(area[0], 0, width - 1) or not _bounded_integer(area[1], 0, height - 1) or not _bounded_integer(area[2], 1, width) or not _bounded_integer(area[3], 1, height):
				return false
			if int(area[0]) + int(area[2]) > width or int(area[1]) + int(area[3]) > height:
				return false
	return true

func _valid_position(value: Dictionary, width: int, height: int) -> bool:
	return _bounded_integer(value.get("x", null), 0, width - 1) and _bounded_integer(value.get("y", null), 0, height - 1)

func _bounded_integer(value: Variant, minimum: int, maximum: int) -> bool:
	if typeof(value) not in [TYPE_INT, TYPE_FLOAT]:
		return false
	var number: float = float(value)
	return is_finite(number) and number >= float(minimum) and number <= float(maximum) and number == float(int(number))

func _fail(error: Error, message: String) -> Error:
	last_error = message
	return error
