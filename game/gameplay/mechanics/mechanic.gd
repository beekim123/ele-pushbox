class_name LevelMechanic
extends RefCounted
## Mechanisms share only the public session/grid API; no presentation dependency.

var _context: WeakRef

func setup(_spec: Dictionary, session) -> void:
	_context = weakref(session)

func session():
	return _context.get_ref() if _context != null else null

func actions() -> Array[String]:
	return []

func try_action(_action: String) -> Dictionary:
	return {"handled": false}

func on_settle_step() -> bool:
	return false

func goals() -> Array[Dictionary]:
	return []

func get_state() -> Dictionary:
	return {}

func set_state(_state: Dictionary) -> void:
	pass

func observe() -> Array[Dictionary]:
	return []
