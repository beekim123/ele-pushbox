class_name UnimplementedCrushMonster400f5b
extends "res://gameplay/mechanics/mechanic.gd"
## mechanic:crush_monster: catalog path only; not registered by any playable mode.

var unimplemented: bool = true

func implementation_available() -> bool:
	return false
