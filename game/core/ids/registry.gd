class_name ResourceRegistry
extends RefCounted
## The authoring uid map is the only entry point for runtime resources.

var entries: Dictionary = {}
var content: Dictionary = {}
var arts: Dictionary = {}
var errors: Array[String] = []
var _cache: Dictionary = {}
var _levels: Dictionary = {}

func load_registry() -> Error:
	entries.clear()
	_cache.clear()
	_levels.clear()
	errors.clear()
	var manifest := _read_json("res://generated/id-map.json")
	if manifest.get("format") != "pushbox.idmap/1":
		errors.append("Unsupported or missing id map")
		return ERR_INVALID_DATA
	for item in manifest.get("entries", []):
		entries[str(item.uid)] = item
	content = _read_json("res://generated/content-manifest.json")
	arts = _read_json("res://generated/art-index.json")
	for group in content.get("groups", []):
		for level in group.get("levels", []):
			if level.get("spec") != null:
				_levels["level:" + str(level.id)] = level
	return OK if errors.is_empty() else ERR_INVALID_DATA

func entry(uid: String) -> Dictionary:
	return entries.get(uid, {}).duplicate(true)

func all(domain: String) -> Array:
	var result: Array = []
	for uid in entries:
		if entries[uid].get("domain") == domain:
			result.append(entries[uid].duplicate(true))
	return result

func art(uid: String) -> Dictionary:
	return arts.get(uid, {}).duplicate(true)

func get_resource(uid: String) -> Variant:
	if _cache.has(uid):
		return _cache[uid]
	var item := entry(uid)
	if item.is_empty():
		errors.append("Unknown resource uid: " + uid)
		return null
	var value: Variant = null
	var location := str(item.get("game", ""))
	if item.domain == "level":
		return level_spec(uid)
	elif item.domain == "text":
		return TranslationServer.translate(str(item.id))
	elif "#" in location:
		var parts := location.split("#", false, 1)
		var catalog := _read_json(parts[0])
		for candidate in catalog.get("entries", []):
			if str(candidate.get("id")) == str(item.id):
				value = candidate.duplicate(true)
				break
	elif ResourceLoader.exists(location):
		value = load(location)
	if value == null:
		errors.append("Missing mapped resource: " + uid)
	else:
		_cache[uid] = value
	return value

func level_spec(uid: String) -> Dictionary:
	if not _levels.has(uid) or not entries.has(uid):
		errors.append("Level is not in content manifest: " + uid)
		return {}
	var item: Dictionary = entries[uid]
	var approved_level: Dictionary = _levels[uid]
	if str(item.get("sha256")) != str(approved_level.get("sha256")):
		errors.append("Level manifest hash mismatch: " + uid)
		return {}
	var location := str(item.get("game", ""))
	if FileAccess.get_sha256(location) != str(item.get("sha256")):
		errors.append("Level file hash mismatch: " + uid)
		return {}
	return _read_json(location)

func author_route(uid: String) -> Array:
	if not _levels.has(uid):
		return []
	var location := "res://generated/content/routes/%s.json" % entries[uid].id
	if not FileAccess.file_exists(location):
		return []
	var data: Variant = JSON.parse_string(FileAccess.get_file_as_string(location))
	return data.duplicate(true) if data is Array else []

func _read_json(location: String) -> Dictionary:
	if not FileAccess.file_exists(location):
		errors.append("Missing data: " + location)
		return {}
	var data: Variant = JSON.parse_string(FileAccess.get_file_as_string(location))
	if not data is Dictionary:
		errors.append("Invalid JSON object: " + location)
		return {}
	return data
