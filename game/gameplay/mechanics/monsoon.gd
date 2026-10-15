class_name UnimplementedMonsoon9d8e6c
extends "res://gameplay/mechanics/mechanic.gd"
## mechanic:monsoon: catalog path only; not registered by any playable mode.

var unimplemented: bool = true

func implementation_available() -> bool:
	return false
