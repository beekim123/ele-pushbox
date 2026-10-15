class_name UnimplementedTar82f4e1
extends "res://gameplay/mechanics/mechanic.gd"
## mechanic:tar: catalog path only; not registered by any playable mode.

var unimplemented: bool = true

func implementation_available() -> bool:
	return false
