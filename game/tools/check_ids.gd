class_name IdContractCheck
extends SceneTree
## Engine-side counterpart to import_resources.mjs checkIds(a/b/c).

var failures: Array[Dictionary] = []
var _known: Dictionary = {}

func _initialize() -> void:
	call_deferred("_run")

func _read(location: String) -> Dictionary:
	if not FileAccess.file_exists(location):
		return {}
	var result: Variant = JSON.parse_string(FileAccess.get_file_as_string(location))
	return result if result is Dictionary else {}

func _fail(check: String, uid: String, location: String, detail: String) -> void:
	failures.append({"check": check, "uid": uid, "path": location, "detail": detail})

func _run() -> void:
	var id_map := _read("res://generated/id-map.json")
	var arts := _read("res://generated/art-index.json")
	var inventory := _read("res://generated/import-inventory.json")
	if id_map.is_empty() or inventory.is_empty():
		_fail("a", "", "res://generated/", "Import resources before running id checks")
	var translations: Array[Dictionary] = [_read("res://generated/content/i18n/zh-Hans.json"), _read("res://generated/content/i18n/en.json")]
	for item in id_map.get("entries", []):
		_known[str(item.uid)] = true
	for item in id_map.get("entries", []):
		var uid := str(item.uid)
		var location := str(item.game)
		if str(item.domain) == "text":
			for translation in translations:
				if not translation.get(str(item.id)) is String:
					_fail("a", uid, location, "Translation key is missing")
			continue
		var parts := location.split("#", false, 1)
		if not FileAccess.file_exists(parts[0]):
			_fail("a", uid, location, "Mapped destination is missing")
			continue
		if parts.size() == 2:
			var found := false
			for row in _read(parts[0]).get("entries", []):
				found = found or str(row.get("id")) == str(item.id)
			if not found:
				_fail("a", uid, location, "Catalog fragment is missing")
		elif parts[0].ends_with(".gd") or parts[0].ends_with(".tscn") or parts[0].ends_with(".tres"):
			if load(parts[0]) == null:
				_fail("a", uid, location, "Godot could not load mapped resource")
		if str(item.domain) == "level" and FileAccess.get_sha256(parts[0]) != str(item.sha256):
			_fail("a", uid, location, "Level SHA-256 mismatch")
		if str(item.domain) == "art":
			var metadata: Dictionary = arts.get(uid, {})
			if metadata.get("hash") != item.get("hash") or metadata.get("version") != item.get("version") or metadata.get("approved") != item.get("approved"):
				_fail("a", uid, location, "Art version/hash/approval mismatch")
			var texture := str(metadata.get("texture_path", ""))
			if not texture.is_empty() and FileAccess.get_sha256(texture) != str(metadata.get("png_sha256")):
				_fail("a", uid, texture, "Art PNG SHA-256 mismatch")
	var expression := RegEx.new()
	expression.compile("""["']([a-z][a-z0-9_]*:[A-Za-z0-9_][A-Za-z0-9_.-]*)["']""")
	for file in _walk("res://"):
		if file.begins_with("res://generated/") or file.begins_with("res://.godot/") or file.begins_with("res://tests/"):
			continue
		if file.ends_with(".gd") or file.ends_with(".tscn"):
			for occurrence in expression.search_all(FileAccess.get_file_as_string(file)):
				var uid := occurrence.get_string(1)
				if uid.ends_with("."):
					continue
				if not _known.has(uid):
					_fail("b", uid, file, "Unknown uid in game code or scene")
	var owned: Dictionary = {}
	for item in inventory.get("files", []):
		owned["res://" + str(item.path)] = item
	for file in _walk("res://generated"):
		if (file.ends_with(".import") and owned.has(file.trim_suffix(".import"))) or (file.ends_with(".uid") and owned.has(file.trim_suffix(".uid"))):
			continue
		var item: Dictionary = owned.get(file, {})
		if item.is_empty() or item.get("owners", []).is_empty():
			_fail("c", "", file, "Generated file has no owner uid")
			continue
		for uid in item.owners:
			if not _known.has(uid):
				_fail("c", str(uid), file, "Generated file owner is unknown")
		if item.get("sha256") != null and str(item.sha256) != FileAccess.get_sha256(file):
			_fail("c", "", file, "Generated file changed after import")
	for file in owned:
		if not FileAccess.file_exists(file):
			_fail("c", "", file, "Inventory file is missing")
	var checks: Array[Dictionary] = []
	for check in ["a", "b", "c"]:
		checks.append({"id": check, "ok": not failures.any(func(failure: Dictionary) -> bool: return failure.check == check)})
	var result := {"format": "portitor.id-checks/1", "checks": checks, "errors": failures, "uid_count": _known.size()}
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://reports"))
	var output := FileAccess.open("res://reports/id-checks.json", FileAccess.WRITE)
	if output != null:
		output.store_string(JSON.stringify(result, " ") + "\n")
		output.close()
	print("id checks: %d uid(s), %d failure(s)" % [_known.size(), failures.size()])
	for failure in failures:
		printerr(JSON.stringify(failure))
	quit(0 if failures.is_empty() else 1)

func _walk(location: String) -> Array[String]:
	var files: Array[String] = []
	var directory := DirAccess.open(location)
	if directory == null:
		return files
	directory.list_dir_begin()
	var name := directory.get_next()
	while not name.is_empty():
		if name != "." and name != ".." and name != ".godot":
			var child := location.path_join(name)
			if directory.current_is_dir():
				files.append_array(_walk(child))
			else:
				files.append(child)
		name = directory.get_next()
	directory.list_dir_end()
	return files
