class_name UnimplementedTrapMonsterb1b022
extends "res://gameplay/mechanics/mechanic.gd"
## mechanic:trap_monster: catalog path only; not registered by any playable mode.

var unimplemented: bool = true

func implementation_available() -> bool:
	return false
