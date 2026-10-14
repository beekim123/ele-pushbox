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
	var image: Image = Ops.canvas(size,Color("68386c"))
	var bands: Array = ["68386c","b55088","f6757a","e8b796"]
	for band in bands.size():
		Ops.rect(image,0,band*size.y/4,size.x,size.y/4+1,Color(bands[band]))
	for y in range(0,size.y,45):
		for x in range(-32,size.x,64):
			Ops.rect(image,x+7,y+30,47,6,Color("c0cbdc"))
			Ops.rect(image,x+15,y+24,28,6,Color("c0cbdc"))
			Ops.rect(image,x+20,y+20,16,4,Color("c0cbdc"))
			Ops.rect(image,x+12,y+28,34,3,Color("ffffff"))
	return image
