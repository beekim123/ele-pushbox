class_name UnimplementedRotatingWalla92ee7
extends "res://gameplay/mechanics/mechanic.gd"
## mechanic:rotating_wall: catalog path only; not registered by any playable mode.

var unimplemented: bool = true

func implementation_available() -> bool:
	return false
