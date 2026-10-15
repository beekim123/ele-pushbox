class_name UnimplementedDrumBeat2de513
extends "res://gameplay/mechanics/mechanic.gd"
## mechanic:drum_beat: catalog path only; not registered by any playable mode.

var unimplemented: bool = true

func implementation_available() -> bool:
	return false
