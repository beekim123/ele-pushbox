class_name UnimplementedWaterFlowb24202
extends "res://gameplay/mechanics/mechanic.gd"
## mechanic:water_flow: catalog path only; not registered by any playable mode.

var unimplemented: bool = true

func implementation_available() -> bool:
	return false
