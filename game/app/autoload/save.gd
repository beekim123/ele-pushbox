class_name SaveService
extends Node

signal changed

const STORE = preload("res://core/save/save_store.gd")
var _store = STORE.new()
var load_error: Error = OK
var data: Dictionary:
	get:
		return _store.data
	set(value):
		_store.data = value

func _init() -> void:
	var isolated_storage := OS.get_environment("PUSHBOX_TEST_STORAGE")
	if not isolated_storage.is_empty():
		_store = STORE.new(isolated_storage.path_join("progress.json"))

func _ready() -> void:
	load_error = _store.load_progress()
	if load_error != OK:
		push_warning("Progress was reset; corrupt input preserved at " + _store.corrupt_backup)

func save_progress() -> Error:
	var result: Error = _store.save_progress()
	if result == OK:
		changed.emit()
	return result

func mark_level(uid: String, cleared: bool, skipped: bool, moves: int) -> void:
	_store.mark_level(uid, cleared, skipped, moves)
	save_progress()

func level_data(uid: String) -> Dictionary:
	return _store.level_data(uid)
