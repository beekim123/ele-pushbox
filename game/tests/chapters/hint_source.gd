extends RefCounted
## Cached UI evidence is valid only for the exact source code that produced it.
static func _files(directory: String) -> Array[String]:
	var result: Array[String] = []
	var opened := DirAccess.open(directory)
	if opened == null: return result
	for name: String in opened.get_files():
		if name.get_extension() in ["gd","tscn","gdshader","mjs","py"]: result.append(directory.path_join(name))
	for name: String in opened.get_directories():
		if name != "results": result.append_array(_files(directory.path_join(name)))
	return result
static func fingerprint() -> String:
	var paths: Array[String] = ["res://project.godot","res://ele.gdextension"]
	for directory: String in ["app","core","sim","gameplay","modes","meta","presentation","tools","tests"]:
		paths.append_array(_files("res://" + directory))
	paths.sort()
	var digest := HashingContext.new()
	digest.start(HashingContext.HASH_SHA256)
	for path: String in paths:
		digest.update(path.to_utf8_buffer())
		digest.update(FileAccess.get_file_as_bytes(path))
	return digest.finish().hex_encode()
