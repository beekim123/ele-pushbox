class_name UnimplementedGust9fbbd8
extends "res://gameplay/mechanics/mechanic.gd"
## mechanic:gust: catalog path only; not registered by any playable mode.

var unimplemented: bool = true

func implementation_available() -> bool:
	return false
