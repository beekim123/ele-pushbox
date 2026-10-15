class_name UnimplementedMineCart26b8f5
extends "res://gameplay/mechanics/mechanic.gd"
## mechanic:mine_cart: catalog path only; not registered by any playable mode.

var unimplemented: bool = true

func implementation_available() -> bool:
	return false
