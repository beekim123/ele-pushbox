class_name UnimplementedBounce6af3b1
extends "res://gameplay/mechanics/mechanic.gd"
## mechanic:bounce: catalog path only; not registered by any playable mode.

var unimplemented: bool = true

func implementation_available() -> bool:
	return false
