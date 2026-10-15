class_name UnimplementedBombafa947
extends "res://gameplay/mechanics/mechanic.gd"
## mechanic:bomb: catalog path only; not registered by any playable mode.

var unimplemented: bool = true

func implementation_available() -> bool:
	return false
