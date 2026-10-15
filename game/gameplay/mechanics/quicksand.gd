class_name UnimplementedQuicksand2bb56f
extends "res://gameplay/mechanics/mechanic.gd"
## mechanic:quicksand: catalog path only; not registered by any playable mode.

var unimplemented: bool = true

func implementation_available() -> bool:
	return false
