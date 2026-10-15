class_name UnimplementedGasRise08c77b
extends "res://gameplay/mechanics/mechanic.gd"
## mechanic:gas_rise: catalog path only; not registered by any playable mode.

var unimplemented: bool = true

func implementation_available() -> bool:
	return false
