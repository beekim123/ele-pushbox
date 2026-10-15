class_name UnimplementedParticles1b4c74
extends "res://gameplay/mechanics/mechanic.gd"
## mechanic:particles: catalog path only; not registered by any playable mode.

var unimplemented: bool = true

func implementation_available() -> bool:
	return false
