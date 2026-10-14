extends "res://pushbox/scripts/ui/biome_showcase_view.gd"
## Actual authored terrain and props; overview is the sole miniature scale.
func _ready() -> void:
	super._ready()
	_clip.position = Vector2.ZERO
	_clip.size = Vector2(104,66)
	terrain.z_index = 0
	_background.hide()
	_ecology_background.hide()
func _draw() -> void:
	pass
func _process(delta: float) -> void:
	clock += delta
	_map_layer.queue_redraw()
func fit_map() -> void:
	var pixels := Vector2(map_size*16)
	var divisor: int = maxi(1,ceili(maxf(pixels.x/104,pixels.y/66)))
	_map_layer.scale = Vector2.ONE/divisor
	_map_layer.position = (Vector2(52,33)-pixels*_map_layer.scale/2).floor()
	map_origin = _map_layer.position
	_ecology_points = Ecology.anchors(map_data)
	refresh_world_origin()
	_map_layer.queue_redraw()
