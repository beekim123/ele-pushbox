class_name UnimplementedLifetimee7f48a
extends "res://gameplay/mechanics/mechanic.gd"
## mechanic:lifetime: catalog path only; not registered by any playable mode.

var unimplemented: bool = true

func implementation_available() -> bool:
	return false
