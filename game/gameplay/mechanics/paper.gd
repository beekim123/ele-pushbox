class_name UnimplementedPaper0ef327
extends "res://gameplay/mechanics/mechanic.gd"
## mechanic:paper: catalog path only; not registered by any playable mode.

var unimplemented: bool = true

func implementation_available() -> bool:
	return false
