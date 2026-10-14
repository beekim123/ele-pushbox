extends RefCounted
## Pure visual silhouettes for the future biome mechanisms.
const Ops := preload("res://pushbox/scripts/art/canvas_ops.gd")

static func image(name: String, accent: Color = Color("fee761")) -> Image:
	var result: Image
	match name:
		"vine_ladder_0":
			result = Ops.canvas(Vector2i(16,16))
			for x in [3,11]:
				Ops.rect(result,x,0,3,16,Color("181425"))
				Ops.rect(result,x+1,0,1,16,Color("63c74d"))
			for y in [2,8,14]:
				Ops.rect(result,4,y,9,2,Color("3e8948"))
				Ops.rect(result,1,y+1,3,2,Color("63c74d"))
				Ops.rect(result,12,y-1,3,2,Color("63c74d"))
		"sand_funnel_0":
			result = Ops.canvas(Vector2i(32,32))
			Ops.rect(result,1,1,30,4,Color("181425"))
			Ops.rect(result,2,2,28,2,Color("fee761"))
			for y in range(5,21):
				var half: int = 14-(y-5)/2
				Ops.rect(result,16-half,y,half*2,1,Color("181425"))
				Ops.rect(result,17-half,y,half*2-2,1,Color("feae34"))
			Ops.rect(result,13,20,6,4,Color("733e39"))
			Ops.rect(result,15,24,2,8,Color("fee761"))
			Ops.rect(result,14,27,1,2,Color("ead4aa"))
		"golden_scale_0":
			result = Ops.canvas(Vector2i(64,48))
			Ops.rect(result,30,5,4,38,Color("181425"))
			Ops.rect(result,31,6,2,35,Color("feae34"))
			Ops.rect(result,4,8,56,3,Color("181425"))
			Ops.rect(result,5,8,54,1,Color("fee761"))
			for x in [6,22,42,58]:
				Ops.line(result,Vector2i(x,10),Vector2i(x,28),Color("feae34"))
			for x in [4,40]:
				Ops.rect(result,x,28,22,4,Color("181425"))
				Ops.rect(result,x+1,29,20,1,Color("fee761"))
				Ops.rect(result,x+4,31,14,2,Color("feae34"))
			Ops.rect(result,24,42,16,4,Color("181425"))
			Ops.rect(result,25,43,14,2,Color("feae34"))
		"scale_pan_0":
			result = Ops.canvas(Vector2i(32,32))
			for x in [4,27]:
				Ops.line(result,Vector2i(x,0),Vector2i(x,23),Color("fee761"))
			Ops.rect(result,2,23,28,4,Color("181425"))
			Ops.rect(result,3,24,26,1,Color("fee761"))
			Ops.rect(result,6,27,20,2,Color("feae34"))
		"wind_emitter_0":
			result = Ops.canvas(Vector2i(32,32))
			Ops.rect(result,7,10,16,15,Color("181425"))
			Ops.rect(result,8,11,14,13,Color("c0cbdc"))
			Ops.rect(result,6,24,18,6,Color("181425"))
			Ops.rect(result,7,25,16,4,Color("feae34"))
			Ops.line(result,Vector2i(15,3),Vector2i(15,22),Color("feae34"))
			Ops.line(result,Vector2i(4,5),Vector2i(27,5),accent)
			Ops.line(result,Vector2i(23,2),Vector2i(28,5),accent)
			Ops.line(result,Vector2i(23,8),Vector2i(28,5),accent)
			Ops.rect(result,12,13,7,7,Color("0099db"))
			Ops.rect(result,14,15,3,3,Color("ffffff"))
		"cloud_pad_0":
			result = Ops.canvas(Vector2i(16,16))
			Ops.rect(result,0,8,16,5,Color("181425"))
			Ops.rect(result,1,7,14,5,Color("ffffff"))
			Ops.rect(result,3,5,9,3,Color("ffffff"))
			Ops.rect(result,3,12,10,2,Color("c0cbdc"))
		"gravity_console_0":
			result = Ops.canvas(Vector2i(32,32))
			Ops.rect(result,2,5,28,22,Color("181425"))
			Ops.rect(result,3,6,26,20,Color("5a6988"))
			Ops.rect(result,6,9,19,11,Color("193c3e"))
			Ops.line(result,Vector2i(12,17),Vector2i(12,10),Color("2ce8f5"))
			Ops.line(result,Vector2i(9,13),Vector2i(12,10),Color("2ce8f5"))
			Ops.line(result,Vector2i(12,10),Vector2i(15,13),Color("2ce8f5"))
			Ops.line(result,Vector2i(20,10),Vector2i(20,17),accent)
			Ops.rect(result,6,23,2,2,accent)
			Ops.rect(result,10,23,2,2,Color("fee761"))
			Ops.rect(result,4,27,24,4,Color("262b44"))
		"quantum_pad_0":
			result = Ops.canvas(Vector2i(32,32))
			Ops.rect(result,3,23,26,8,Color("181425"))
			Ops.rect(result,4,24,24,6,Color("5a6988"))
			Ops.rect(result,7,22,18,2,accent)
			Ops.rect(result,10,20,12,2,Color("ffffff"))
			for x in [8,23]:
				Ops.rect(result,x,2,1,16,Color(accent,0.45))
				Ops.rect(result,x-1,5,3,3,accent)
			Ops.rect(result,14,9,4,4,Color("2ce8f5"))
		"magnetic_rail_0":
			result = Ops.canvas(Vector2i(16,16))
			Ops.rect(result,0,1,16,4,Color("181425"))
			Ops.rect(result,0,2,16,2,Color("2ce8f5"))
			for x in [2,7,12]:
				Ops.rect(result,x,5,2,5,accent)
		_:
			return null
	return result
