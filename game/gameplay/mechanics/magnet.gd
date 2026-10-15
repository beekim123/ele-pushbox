class_name UnimplementedMagnetf1bed9
extends "res://gameplay/mechanics/mechanic.gd"
## mechanic:magnet: catalog path only; not registered by any playable mode.

var unimplemented: bool = true

func implementation_available() -> bool:
	return false
