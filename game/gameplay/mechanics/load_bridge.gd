class_name UnimplementedLoadBridge25c2a5
extends "res://gameplay/mechanics/mechanic.gd"
## mechanic:load_bridge: catalog path only; not registered by any playable mode.

var unimplemented: bool = true

func implementation_available() -> bool:
	return false
