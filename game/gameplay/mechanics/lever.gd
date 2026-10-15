class_name UnimplementedLever143f21
extends "res://gameplay/mechanics/mechanic.gd"
## mechanic:lever: catalog path only; not registered by any playable mode.

var unimplemented: bool = true

func implementation_available() -> bool:
	return false
