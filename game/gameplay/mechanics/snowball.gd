class_name UnimplementedSnowballecb560
extends "res://gameplay/mechanics/mechanic.gd"
## mechanic:snowball: catalog path only; not registered by any playable mode.

var unimplemented: bool = true

func implementation_available() -> bool:
	return false
