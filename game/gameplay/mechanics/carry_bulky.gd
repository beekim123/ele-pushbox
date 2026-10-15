class_name UnimplementedCarryBulkyc4d556
extends "res://gameplay/mechanics/mechanic.gd"
## mechanic:carry_bulky: catalog path only; not registered by any playable mode.

var unimplemented: bool = true

func implementation_available() -> bool:
	return false
