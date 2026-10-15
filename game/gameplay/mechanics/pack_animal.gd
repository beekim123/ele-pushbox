class_name UnimplementedPackAnimal846a99
extends "res://gameplay/mechanics/mechanic.gd"
## mechanic:pack_animal: catalog path only; not registered by any playable mode.

var unimplemented: bool = true

func implementation_available() -> bool:
	return false
