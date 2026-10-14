extends RefCounted
const Base := preload("res://pushbox/scripts/art/themes/theme_base.gd")
const Ops := preload("res://pushbox/scripts/art/canvas_ops.gd")

static func spec() -> Dictionary:
	return Base.make(5,"cosmos",{
		"bedrock_base": Color("5a6988"), "bedrock_seam": Color("262b44"), "bedrock_edge": Color("c0cbdc"), "bedrock_trim": Color("8b9bb4"),
		"cracked_base": Color("3a4466"), "cracked_edge": Color("2ce8f5"), "cracked_vein": Color("ff0044"),
		"sand_base": Color("8b9bb4"), "sand_mid": Color("c0cbdc"), "sand_light": Color("ffffff"),
		"water_base": Color("0099db",0.85), "water_edge": Color("2ce8f5"),
		"accent": Color("ff0044"), "particle_rock": Color("2ce8f5"), "particle_sand": Color("c0cbdc")
	},{"e4a672":"2ce8f5", "b86f50":"5a6988", "733e39":"3a4466", "3e2731":"181425", "fee761":"ff0044", "feae34":"2ce8f5"})

static func background(size: Vector2i) -> Image:
	return preload("res://pushbox/scripts/art/themes/natural_backdrops.gd").cosmos(size)
