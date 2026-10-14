extends RefCounted
const Base := preload("res://pushbox/scripts/art/themes/theme_base.gd")
const Ops := preload("res://pushbox/scripts/art/canvas_ops.gd")

static func spec() -> Dictionary:
	return Base.make(1,"forest",{
		"bedrock_base": Color("733e39"), "bedrock_seam": Color("3e2731"), "bedrock_edge": Color("63c74d"), "bedrock_trim": Color("3e8948"),
		"cracked_base": Color("b86f50"), "cracked_edge": Color("e4a672"), "cracked_vein": Color("3e2731"),
		"sand_base": Color("feae34"), "sand_mid": Color("fee761"), "sand_light": Color("ead4aa"),
		"water_base": Color("3e8948",0.80), "water_deep": Color("265c42",0.90), "water_edge": Color("63c74d"),
		"accent": Color("63c74d"), "particle_rock": Color("733e39"), "particle_sand": Color("fee761")
	},{"e4a672":"63c74d", "b86f50":"3e8948", "733e39":"265c42", "8b9bb4":"3e8948", "5a6988":"265c42", "fee761":"63c74d"})

static func background(size: Vector2i) -> Image:
	return preload("res://pushbox/scripts/art/themes/natural_backdrops.gd").forest(size)
