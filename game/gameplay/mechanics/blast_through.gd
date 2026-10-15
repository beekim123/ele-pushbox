class_name UnimplementedBlastThroughb04f86
extends "res://gameplay/mechanics/mechanic.gd"
## mechanic:blast_through: catalog path only; not registered by any playable mode.

var unimplemented: bool = true

func implementation_available() -> bool:
	return false
