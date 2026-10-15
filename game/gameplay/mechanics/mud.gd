class_name UnimplementedMud5310a9
extends "res://gameplay/mechanics/mechanic.gd"
## mechanic:mud: catalog path only; not registered by any playable mode.

var unimplemented: bool = true

func implementation_available() -> bool:
	return false
