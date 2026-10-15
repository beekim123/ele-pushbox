class_name UnimplementedPetalTrailfc0260
extends "res://gameplay/mechanics/mechanic.gd"
## mechanic:petal_trail: catalog path only; not registered by any playable mode.

var unimplemented: bool = true

func implementation_available() -> bool:
	return false
