extends RefCounted
const Base := preload("res://pushbox/scripts/art/themes/theme_base.gd")
const Ops := preload("res://pushbox/scripts/art/canvas_ops.gd")

static func spec() -> Dictionary:
	return Base.make(3,"cave",{
		"bedrock_base": Color("3a4466"), "bedrock_seam": Color("193c3e"), "bedrock_edge": Color("5a6988"), "bedrock_trim": Color("262b44"),
		"cracked_base": Color("733e39"), "cracked_edge": Color("feae34"), "cracked_vein": Color("fee761"),
		"sand_base": Color("68386c"), "sand_mid": Color("b55088"), "sand_light": Color("c0cbdc"),
		"accent": Color("2ce8f5"), "particle_rock": Color("fee761"), "particle_sand": Color("b55088")
	},{"e4a672":"2ce8f5", "b86f50":"5a6988", "733e39":"262b44", "fee761":"2ce8f5", "feae34":"b55088"})

static func background(size: Vector2i) -> Image:
	return preload("res://pushbox/scripts/art/themes/natural_backdrops.gd").cave(size)
