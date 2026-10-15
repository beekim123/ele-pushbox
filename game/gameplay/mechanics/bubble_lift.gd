class_name UnimplementedBubbleLiftfec1dd
extends "res://gameplay/mechanics/mechanic.gd"
## mechanic:bubble_lift: catalog path only; not registered by any playable mode.

var unimplemented: bool = true

func implementation_available() -> bool:
	return false
