class_name UnimplementedPower9e8187
extends "res://gameplay/mechanics/mechanic.gd"
## mechanic:power: catalog path only; not registered by any playable mode.

var unimplemented: bool = true

func implementation_available() -> bool:
	return false
