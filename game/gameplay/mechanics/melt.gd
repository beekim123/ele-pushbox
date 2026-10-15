class_name UnimplementedMeltd25722
extends "res://gameplay/mechanics/mechanic.gd"
## mechanic:melt: catalog path only; not registered by any playable mode.

var unimplemented: bool = true

func implementation_available() -> bool:
	return false
