class_name UnimplementedConveyor932fb2
extends "res://gameplay/mechanics/mechanic.gd"
## mechanic:conveyor: catalog path only; not registered by any playable mode.

var unimplemented: bool = true

func implementation_available() -> bool:
	return false
