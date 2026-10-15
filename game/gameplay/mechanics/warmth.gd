class_name UnimplementedWarmth55d64b
extends "res://gameplay/mechanics/mechanic.gd"
## mechanic:warmth: catalog path only; not registered by any playable mode.

var unimplemented: bool = true

func implementation_available() -> bool:
	return false
