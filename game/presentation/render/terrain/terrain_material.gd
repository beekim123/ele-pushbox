class_name TerrainMaterial
extends RefCounted
const SHADER: Shader = preload("res://presentation/render/terrain/terrain.gdshader")
const Raster = preload("res://presentation/render/palette_raster.gd")

static func create(theme: Dictionary) -> ShaderMaterial:
	var material: ShaderMaterial = ShaderMaterial.new()
	material.shader = SHADER
	var values: PackedInt32Array = PackedInt32Array()
	for group: Array in [["rock", "base.0", "base.1", "seam", "speck", "light", "light2", "dark", "edge", "top", "under"], ["earth", "base.0", "base.1", "clump", "pebble", "pebbleShade", "crust", "crust2", "dark", "frame", "bevel"], ["cracked", "base.0", "base.1", "crack", "crackLight", "light", "dark", "frame", "bevel"], ["sand", "base.0", "base.1", "base.2", "grain", "top"], ["water", "body", "upper", "surface", "glint"]]:
		var params: Dictionary = theme.get(group[0], {})
		for key: String in group.slice(1):
			var code: String = "."
			if key.begins_with("base."):
				var base: Array = params.get("base", [])
				var index: int = key.get_slice(".", 1).to_int()
				if index < base.size():
					code = base[index]
			else:
				code = params.get(key, ".")
			values.append(maxi(0, Raster.CODES.find(code)))
	material.set_shader_parameter("colors", values)
	material.set_shader_parameter("rock_pattern", ["brick", "block", "rough", "grass", "marble", "cloud", "panel"].find(theme.rock.pattern))
	material.set_shader_parameter("hazard_trim", theme.rock.get("trim") == "hazard")
	return material
