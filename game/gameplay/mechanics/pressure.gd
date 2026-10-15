class_name UnimplementedPressure677edf
extends "res://gameplay/mechanics/mechanic.gd"
## mechanic:pressure: catalog path only; not registered by any playable mode.

var unimplemented: bool = true

func implementation_available() -> bool:
	return false
