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
	var image: Image = Ops.canvas(size,Color("3e2731"))
	for x in range(-32,size.x,64):
		Ops.rect(image,x+16,0,18,size.y,Color("733e39"))
		Ops.rect(image,x+20,0,2,size.y,Color("b86f50"))
		for y in range(0,size.y,45):
			Ops.rect(image,x+11,y+2,28,5,Color("b86f50"))
			Ops.rect(image,x+6,y+20,12,12,Color("733e39"))
			Ops.rect(image,x+9,y+23,6,6,Color("b86f50"))
			Ops.rect(image,x+11,y+21,2,10,Color("b86f50"))
			Ops.rect(image,x+7,y+25,10,2,Color("b86f50"))
	return image
