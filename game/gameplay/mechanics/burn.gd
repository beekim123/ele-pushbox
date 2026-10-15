class_name UnimplementedBurn3d7064
extends "res://gameplay/mechanics/mechanic.gd"
## mechanic:burn: catalog path only; not registered by any playable mode.

var unimplemented: bool = true

func implementation_available() -> bool:
	return false
