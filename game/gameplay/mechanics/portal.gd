class_name UnimplementedPortal2c3b7d
extends "res://gameplay/mechanics/mechanic.gd"
## mechanic:portal: catalog path only; not registered by any playable mode.

var unimplemented: bool = true

func implementation_available() -> bool:
	return false
