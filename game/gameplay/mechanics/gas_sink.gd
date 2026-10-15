class_name UnimplementedGasSinkb1aa30
extends "res://gameplay/mechanics/mechanic.gd"
## mechanic:gas_sink: catalog path only; not registered by any playable mode.

var unimplemented: bool = true

func implementation_available() -> bool:
	return false
