class_name UnimplementedCommunicatingfbf971
extends "res://gameplay/mechanics/mechanic.gd"
## mechanic:communicating: catalog path only; not registered by any playable mode.

var unimplemented: bool = true

func implementation_available() -> bool:
	return false
