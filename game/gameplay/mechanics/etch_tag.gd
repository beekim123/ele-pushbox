class_name UnimplementedEtchTage1e43c
extends "res://gameplay/mechanics/mechanic.gd"
## mechanic:etch_tag: catalog path only; not registered by any playable mode.

var unimplemented: bool = true

func implementation_available() -> bool:
	return false
