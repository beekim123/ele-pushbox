class_name UnimplementedDarkness95c3e9
extends "res://gameplay/mechanics/mechanic.gd"
## mechanic:darkness: catalog path only; not registered by any playable mode.

var unimplemented: bool = true

func implementation_available() -> bool:
	return false
