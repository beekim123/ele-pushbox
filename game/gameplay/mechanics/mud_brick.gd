class_name UnimplementedMudBrick571cf8
extends "res://gameplay/mechanics/mechanic.gd"
## mechanic:mud_brick: catalog path only; not registered by any playable mode.

var unimplemented: bool = true

func implementation_available() -> bool:
	return false
