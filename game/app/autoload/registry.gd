class_name RegistryService
extends Node

const INDEX = preload("res://core/ids/registry.gd")
var _index = INDEX.new()
var load_error: Error = OK

func _ready() -> void:
	load_error = _index.load_registry()
	if load_error != OK:
		for message in _index.errors:
			push_error(message)

func entry(uid: String) -> Dictionary:
	return _index.entry(uid)

func all(domain: String) -> Array:
	return _index.all(domain)

func get_resource(uid: String) -> Variant:
	if uid.begins_with("art:") and _reject_unapproved_release(uid):
		return null
	return _index.get_resource(uid)

func level_spec(uid: String) -> Dictionary:
	return _index.level_spec(uid)

func author_route(uid: String) -> Array:
	return _index.author_route(uid)

func art(uid: String) -> Dictionary:
	if _reject_unapproved_release(uid):
		return {}
	return _index.art(uid)

func _reject_unapproved_release(uid: String) -> bool:
	if OS.is_debug_build() and OS.get_environment("PUSHBOX_FORCE_RELEASE_CHECK") != "1":
		return false
	var metadata: Dictionary = _index.art(uid)
	if not metadata.is_empty() and metadata.get("approved", false) and not metadata.get("placeholder", true):
		return false
	push_error("Release build refused unapproved or missing art: " + uid)
	if is_inside_tree():
		get_tree().quit(1)
	return true
