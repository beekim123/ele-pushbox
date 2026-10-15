class_name UnimplementedLanternReveal1155ea
extends "res://gameplay/mechanics/mechanic.gd"
## mechanic:lantern_reveal: catalog path only; not registered by any playable mode.

var unimplemented: bool = true

func implementation_available() -> bool:
	return false
