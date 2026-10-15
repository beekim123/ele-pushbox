class_name FloatSinkMechanic
extends "res://gameplay/mechanics/mechanic.gd"
## Gravity exchanges iron crates with water; this phase raises wooden crates.

func on_settle_step() -> bool:
	var context = session()
	var changed: bool = false
	for index: int in range(context.grid.crates.size()):
		if str(context.grid.crates[index].kind) == "wood":
			changed = context.float_crate(index) or changed
	return changed

func observe() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for crate: Dictionary in session().grid.crates:
		result.append({"kind": "float_sink", "x": int(crate.x), "y": int(crate.y), "floats": str(crate.kind) == "wood"})
	return result
