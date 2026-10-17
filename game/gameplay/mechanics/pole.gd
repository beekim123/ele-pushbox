class_name UnimplementedPoled0dc74
extends "res://gameplay/mechanics/mechanic.gd"
## mechanic:pole: catalog path only; not registered by any playable mode.

var unimplemented: bool = true

func implementation_available() -> bool:
	return false
