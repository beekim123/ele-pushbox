class_name UnimplementedGravel2c2aa9
extends "res://gameplay/mechanics/mechanic.gd"
## mechanic:gravel: catalog path only; not registered by any playable mode.

var unimplemented: bool = true

func implementation_available() -> bool:
	return false
