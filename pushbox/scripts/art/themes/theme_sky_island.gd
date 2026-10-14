extends RefCounted
const Base := preload("res://pushbox/scripts/art/themes/theme_base.gd")
const Ops := preload("res://pushbox/scripts/art/canvas_ops.gd")

static func spec() -> Dictionary:
	return Base.make(4,"sky_island",{
		"bedrock_base": Color("c0cbdc"), "bedrock_seam": Color("8b9bb4"), "bedrock_edge": Color("ffffff"), "bedrock_trim": Color("ead4aa"),
		"cracked_base": Color("ead4aa"), "cracked_edge": Color("ffffff"), "cracked_vein": Color("feae34"),
		"sand_base": Color("feae34"), "sand_mid": Color("fee761"), "sand_light": Color("ffffff"),
		"accent": Color("fee761"), "particle_rock": Color("c0cbdc"), "particle_sand": Color("fee761")
	},{"e4a672":"ffffff", "b86f50":"c0cbdc", "733e39":"8b9bb4", "3e2731":"181425", "8b9bb4":"ead4aa", "5a6988":"feae34"})

static func background(size: Vector2i) -> Image:
	return preload("res://pushbox/scripts/art/themes/natural_backdrops.gd").sky(size)
