class_name UnimplementedLaserMirror472975
extends "res://gameplay/mechanics/mechanic.gd"
## mechanic:laser_mirror: catalog path only; not registered by any playable mode.

var unimplemented: bool = true

func implementation_available() -> bool:
	return false
