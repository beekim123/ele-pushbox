extends Node2D
var host: Node2D
func _draw() -> void:
	if host != null: host.draw_map(self)
