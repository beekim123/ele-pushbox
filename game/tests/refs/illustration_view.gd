extends "res://presentation/render/world_view.gd"
## Test fixture ONLY. Representative scenes are illustrations, never SDK proof.
## Everything else (composition, approved sprites, lights, shader) is production.

func _bind_materials(state: Dictionary) -> void:
	_map_texture = _grid_texture(state)
	_terrain_material.set_shader_parameter("sdk_mode", false)
	_terrain_material.set_shader_parameter("map_texture", _map_texture)
	last_limitation = "Reference illustration fixture; no SDK simulation"
