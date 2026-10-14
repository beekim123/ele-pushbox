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
	var image: Image = Ops.canvas(size,Color("181425"))
	for y in range(0,size.y,8):
		var x: int = (size.x/3+y)%size.x
		Ops.rect(image,x,y,80,8,Color("262b44"))
		Ops.rect(image,x+24,y,32,8,Color("68386c"))
	for y in range(-32,size.y,45):
		for x in range(-32,size.x,64):
			if (x/64+y/45)%3 == 0:
				Ops.line(image,Vector2i(x,y),Vector2i(x+32,y+32),Color("262b44"))
				Ops.line(image,Vector2i(x+32,y),Vector2i(x,y+32),Color("262b44"))
			Ops.rect(image,x+5,y+12,1,5,Color("c0cbdc"))
			Ops.rect(image,x+3,y+14,5,1,Color("c0cbdc"))
			Ops.rect(image,x+54,y+25,1,1,Color("8b9bb4"))
	return image
