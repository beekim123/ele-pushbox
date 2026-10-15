class_name UnimplementedPushMonster261d6b
extends "res://gameplay/mechanics/mechanic.gd"
## mechanic:push_monster: catalog path only; not registered by any playable mode.

var unimplemented: bool = true

func implementation_available() -> bool:
	return false
