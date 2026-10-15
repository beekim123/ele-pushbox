class_name UnimplementedLift3b8fda
extends "res://gameplay/mechanics/mechanic.gd"
## mechanic:lift: catalog path only; not registered by any playable mode.

var unimplemented: bool = true

func implementation_available() -> bool:
	return false
