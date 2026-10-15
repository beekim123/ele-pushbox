class_name UnimplementedWindPumpfb3169
extends "res://gameplay/mechanics/mechanic.gd"
## mechanic:wind_pump: catalog path only; not registered by any playable mode.

var unimplemented: bool = true

func implementation_available() -> bool:
	return false
