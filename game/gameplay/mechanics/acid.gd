class_name UnimplementedAcida0a4cb
extends "res://gameplay/mechanics/mechanic.gd"
## mechanic:acid: catalog path only; not registered by any playable mode.

var unimplemented: bool = true

func implementation_available() -> bool:
	return false
