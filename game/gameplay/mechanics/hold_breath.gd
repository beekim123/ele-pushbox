class_name UnimplementedHoldBreath0133e5
extends "res://gameplay/mechanics/mechanic.gd"
## mechanic:hold_breath: catalog path only; not registered by any playable mode.

var unimplemented: bool = true

func implementation_available() -> bool:
	return false
