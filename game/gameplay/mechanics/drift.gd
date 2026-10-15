class_name UnimplementedDrift354967
extends "res://gameplay/mechanics/mechanic.gd"
## mechanic:drift: catalog path only; not registered by any playable mode.

var unimplemented: bool = true

func implementation_available() -> bool:
	return false
