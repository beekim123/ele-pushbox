class_name UnimplementedFreeze693fa0
extends "res://gameplay/mechanics/mechanic.gd"
## mechanic:freeze: catalog path only; not registered by any playable mode.

var unimplemented: bool = true

func implementation_available() -> bool:
	return false
