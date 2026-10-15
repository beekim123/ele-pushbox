class_name AffinityService
extends RefCounted
var _state: Dictionary = {}
func get_state() -> Dictionary:
	return _state.duplicate(true)
func set_state(value: Dictionary) -> void:
	_state = value.duplicate(true)
