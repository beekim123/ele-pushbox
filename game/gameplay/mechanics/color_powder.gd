class_name UnimplementedColorPowder2abd4c
extends "res://gameplay/mechanics/mechanic.gd"
## mechanic:color_powder: catalog path only; not registered by any playable mode.

var unimplemented: bool = true

func implementation_available() -> bool:
	return false
