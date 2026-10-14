extends RefCounted
## Connect a ThemeSpec to either SDK chunk materials or the static showcase.
const Registry := preload("res://pushbox/scripts/art/art_registry.gd")
const MATERIAL_NAMES := {"bedrock":"bedrock_id","cracked_rock":"cracked_id","crate":"crate_id","gate":"gate_id","sand":"sand_id","water":"water_id","iron_crate":"iron_crate_id","acid":"acid_id","lava":"lava_id","pumice":"pumice_id","ice":"ice_id","levitated_sand":"levitated_sand_id","levitated_pumice":"levitated_pumice_id","fume":"fume_id"}

static func apply(material: ShaderMaterial, theme_id: String, ids: Dictionary) -> void:
	var spec: Dictionary = Registry.theme(theme_id)
	material.set_shader_parameter("biome_style_id",spec.index)
	for key in spec.colors:
		if key.begins_with("bedrock_") or key.begins_with("cracked_") or key.begins_with("sand_") or key.begins_with("water_"):
			material.set_shader_parameter(key,spec.colors[key])
	for name in MATERIAL_NAMES:
		material.set_shader_parameter(MATERIAL_NAMES[name],ids.get(name,-1))
