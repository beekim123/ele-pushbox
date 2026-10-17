class_name UnimplementedHintAnimal9011c2
extends "res://gameplay/mechanics/mechanic.gd"
## mechanic:hint_animal: catalog path only; not registered by any playable mode.

var unimplemented: bool = true

func implementation_available() -> bool:
	return false
