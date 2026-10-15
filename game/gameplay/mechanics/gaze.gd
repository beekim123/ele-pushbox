class_name UnimplementedGaze333fe5
extends "res://gameplay/mechanics/mechanic.gd"
## mechanic:gaze: catalog path only; not registered by any playable mode.

var unimplemented: bool = true

func implementation_available() -> bool:
	return false
