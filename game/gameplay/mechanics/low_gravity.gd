class_name UnimplementedLowGravityc7c56d
extends "res://gameplay/mechanics/mechanic.gd"
## mechanic:low_gravity: catalog path only; not registered by any playable mode.

var unimplemented: bool = true

func implementation_available() -> bool:
	return false
