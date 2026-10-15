class_name SimulationSnapshot
extends RefCounted
## The SDK file and the game JSON form one undo point; neither is sufficient alone.

var last_save_profile: Dictionary = {}

func save(world, state: Dictionary, label: String) -> Dictionary:
	return finish_save(begin_save(world, state, label))

func begin_save(world, state: Dictionary, label: String) -> Dictionary:
	var started: int = Time.get_ticks_usec()
	var path: String = world.storage_dir.path_join(label + ".snap")
	if world.save_snapshot(path) != 0:
		return {}
	return {"path": path, "state_path": path + ".json", "pending_state": state, "sdk_file_save_us": Time.get_ticks_usec() - started}

func finish_save(pending: Dictionary) -> Dictionary:
	if pending.is_empty():
		return {}
	var started: int = Time.get_ticks_usec()
	var file: FileAccess = FileAccess.open(str(pending.state_path), FileAccess.WRITE)
	if file == null:
		remove(pending)
		return {}
	var encoded: String = JSON.stringify(pending.pending_state)
	file.store_string(encoded)
	var written: bool = file.get_error() == OK
	file.close()
	if not written or FileAccess.get_file_as_string(str(pending.state_path)) != encoded:
		remove(pending)
		return {}
	last_save_profile = {"sdk_file_save_us": int(pending.sdk_file_save_us), "game_json_save_us": Time.get_ticks_usec() - started}
	return {"path": pending.path, "state_path": pending.state_path}

func load_into(world, snapshot: Dictionary) -> Dictionary:
	if snapshot.is_empty():
		return {}
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(str(snapshot.state_path)))
	if not parsed is Dictionary:
		return {}
	if world.load_snapshot(str(snapshot.path)) != 0:
		return {}
	return parsed

func remove(snapshot: Dictionary) -> void:
	if snapshot.has("path"):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(str(snapshot.path)))
	if snapshot.has("state_path"):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(str(snapshot.state_path)))
