class_name UnimplementedBlastIgnite1ccd62
extends "res://gameplay/mechanics/mechanic.gd"
## mechanic:blast_ignite: catalog path only; not registered by any playable mode.

var unimplemented: bool = true

func implementation_available() -> bool:
	return false
