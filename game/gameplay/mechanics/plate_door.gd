class_name PlateDoorMechanic
extends "res://gameplay/mechanics/mechanic.gd"

func on_settle_step() -> bool:
	var context = session()
	var grid = context.grid
	var changed: bool = false
	for group_index: int in range(grid.groups.size()):
		var group: Dictionary = grid.groups[group_index]
		var pressed: bool = not group.plates.is_empty()
		for index: int in group.plates:
			var x: int = index % grid.width
			var y: int = int(index / grid.width)
			pressed = pressed and (grid.is_player(x, y) or grid.crate_index(x, y) >= 0 or grid.supports(x, y))
		pressed = pressed or context.link_enabled(group_index)
		var want: int = 2 if (pressed and bool(group.latch)) or int(grid.open[group_index]) == 2 else (1 if pressed else 0)
		if want == int(grid.open[group_index]):
			continue
		var blocked: bool = false
		if want == 0:
			for index: int in group.doors:
				blocked = blocked or context.door_blocked(index)
		if not blocked and context.set_door_group(group_index, want):
			changed = true
	return changed
