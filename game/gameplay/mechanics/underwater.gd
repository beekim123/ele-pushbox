class_name UnimplementedUnderwater44fc4c
extends "res://gameplay/mechanics/mechanic.gd"
## mechanic:underwater: catalog path only; not registered by any playable mode.

var unimplemented: bool = true

func implementation_available() -> bool:
	return false
