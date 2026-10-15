class_name UnimplementedFloatSink200c82
extends "res://gameplay/mechanics/mechanic.gd"
## mechanic:float_sink: catalog path only; not registered by any playable mode.

var unimplemented: bool = true

func implementation_available() -> bool:
	return false
