class_name UnimplementedFuse7d3d3a
extends "res://gameplay/mechanics/mechanic.gd"
## mechanic:fuse: catalog path only; not registered by any playable mode.

var unimplemented: bool = true

func implementation_available() -> bool:
	return false
