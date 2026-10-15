class_name UnimplementedDayNightd9b5ad
extends "res://gameplay/mechanics/mechanic.gd"
## mechanic:day_night: catalog path only; not registered by any playable mode.

var unimplemented: bool = true

func implementation_available() -> bool:
	return false
