class_name UnimplementedVine292240
extends "res://gameplay/mechanics/mechanic.gd"
## mechanic:vine: catalog path only; not registered by any playable mode.

var unimplemented: bool = true

func implementation_available() -> bool:
	return false
