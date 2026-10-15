class_name UnimplementedBin94327d
extends "res://gameplay/mechanics/mechanic.gd"
## mechanic:bin: catalog path only; not registered by any playable mode.

var unimplemented: bool = true

func implementation_available() -> bool:
	return false
