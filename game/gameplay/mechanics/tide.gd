class_name UnimplementedTide7b3541
extends "res://gameplay/mechanics/mechanic.gd"
## mechanic:tide: catalog path only; not registered by any playable mode.

var unimplemented: bool = true

func implementation_available() -> bool:
	return false
