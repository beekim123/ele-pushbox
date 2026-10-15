class_name UnimplementedLava391211
extends "res://gameplay/mechanics/mechanic.gd"
## mechanic:lava: catalog path only; not registered by any playable mode.

var unimplemented: bool = true

func implementation_available() -> bool:
	return false
