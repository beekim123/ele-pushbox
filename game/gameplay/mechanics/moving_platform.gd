class_name UnimplementedMovingPlatform83be10
extends "res://gameplay/mechanics/mechanic.gd"
## mechanic:moving_platform: catalog path only; not registered by any playable mode.

var unimplemented: bool = true

func implementation_available() -> bool:
	return false
