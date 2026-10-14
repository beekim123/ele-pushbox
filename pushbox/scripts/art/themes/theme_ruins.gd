extends RefCounted
const Base := preload("res://pushbox/scripts/art/themes/theme_base.gd")
const Ops := preload("res://pushbox/scripts/art/canvas_ops.gd")

static func spec() -> Dictionary:
	return Base.make(2,"ruins",{
		"bedrock_base": Color("b86f50"), "bedrock_seam": Color("733e39"), "bedrock_edge": Color("feae34"), "bedrock_trim": Color("e4a672"),
		"cracked_base": Color("c28569"), "cracked_edge": Color("ead4aa"), "cracked_vein": Color("733e39"),
		"sand_base": Color("feae34"), "sand_mid": Color("fee761"), "sand_light": Color("ead4aa"),
		"accent": Color("feae34"), "particle_sand": Color("fee761")
	},{"e4a672":"fee761", "b86f50":"feae34", "733e39":"b86f50", "8b9bb4":"feae34", "5a6988":"b86f50", "c0cbdc":"ead4aa"})

static func background(size: Vector2i) -> Image:
	return preload("res://pushbox/scripts/art/themes/natural_backdrops.gd").ruins(size)
