class_name UnimplementedRigid3cab16
extends "res://gameplay/mechanics/mechanic.gd"
## mechanic:rigid: catalog path only; not registered by any playable mode.

var unimplemented: bool = true

func implementation_available() -> bool:
	return false
