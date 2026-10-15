class_name UnimplementedIceSlidef1b7f2
extends "res://gameplay/mechanics/mechanic.gd"
## mechanic:ice_slide: catalog path only; not registered by any playable mode.

var unimplemented: bool = true

func implementation_available() -> bool:
	return false
