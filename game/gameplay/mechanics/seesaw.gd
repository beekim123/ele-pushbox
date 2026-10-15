class_name UnimplementedSeesaw6e54f3
extends "res://gameplay/mechanics/mechanic.gd"
## mechanic:seesaw: catalog path only; not registered by any playable mode.

var unimplemented: bool = true

func implementation_available() -> bool:
	return false
