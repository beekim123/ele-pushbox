extends RefCounted
## Single-cell mechanisms are authored at 16px; tall funnels retain 16x32.
const Ops := preload("res://pushbox/scripts/art/canvas_ops.gd")
static func image(name: String, accent: Color = Color("fee761")) -> Image:
	var result: Image = Ops.canvas(Vector2i(16,16))
	var ink := Color("181425")
	var gold := Color("feae34")
	var light := Color("fee761")
	match name:
		"vine_ladder_0":
			for x in [3,11]:
				Ops.rect(result,x,0,2,16,Color("265c42"))
				Ops.rect(result,x,0,1,16,Color("63c74d"))
			for y in [2,8,14]:
				Ops.line(result,Vector2i(3,y),Vector2i(12,y+1),Color("3e8948"))
				Ops.line(result,Vector2i(3,y),Vector2i(0,y-2),Color("63c74d"))
				Ops.line(result,Vector2i(12,y+1),Vector2i(15,y-1),Color("63c74d"))
		"sand_funnel_0":
			result = Ops.canvas(Vector2i(16,32))
			Ops.rect(result,0,1,16,3,ink)
			Ops.rect(result,1,1,14,1,light)
			for y in range(4,12):
				var half: int = maxi(2,8-(y-3)/2)
				Ops.rect(result,8-half,y,half*2,1,ink)
				Ops.rect(result,9-half,y,half*2-2,1,gold)
			Ops.rect(result,6,11,4,4,Color("733e39"))
			for y in range(16,32,3):
				Ops.rect(result,7,y,1,2,light)
		"golden_scale_0":
			result = Ops.canvas(Vector2i(64,48))
			Ops.rect(result,30,5,4,38,ink)
			Ops.rect(result,31,6,2,35,gold)
			Ops.rect(result,4,8,56,3,ink)
			Ops.rect(result,5,8,54,1,light)
			for x in [6,22,42,58]:
				Ops.line(result,Vector2i(x,10),Vector2i(x,28),gold)
			for x in [4,40]:
				Ops.rect(result,x,28,22,4,ink)
				Ops.rect(result,x+1,29,20,1,light)
				Ops.rect(result,x+4,31,14,2,gold)
			Ops.rect(result,24,42,16,4,ink)
			Ops.rect(result,25,43,14,2,gold)
		"scale_pan_0":
			for x in [1,14]:
				Ops.line(result,Vector2i(x,0),Vector2i(x,10),gold)
			Ops.rect(result,0,10,16,3,ink)
			Ops.rect(result,1,10,14,1,light)
			Ops.rect(result,3,13,10,2,gold)
		"wind_emitter_0","wind_emitter_1","wind_emitter_2","wind_emitter_3":
			var f: int = int(name.get_slice("_",2))
			Ops.rect(result,6,6,3,8,ink)
			Ops.rect(result,7,6,1,7,gold)
			Ops.rect(result,3,14,10,2,ink)
			Ops.rect(result,4,14,8,1,gold)
			var tips: Array[Vector2i] = [Vector2i(5,0),Vector2i(4,4),Vector2i(0,5),Vector2i(-4,4)]
			var tip: Vector2i = tips[f]
			for i in 4:
				Ops.line(result,Vector2i(7,6),Vector2i(7,6)+tip,Color("ffffff") if i%2 == 0 else accent)
				tip = Vector2i(-tip.y,tip.x)
			Ops.rect(result,6,5,3,3,Color("8b9bb4"))
			Ops.rect(result,7,6,1,1,gold)
		"cloud_pad_0":
			for y in range(6,13):
				var inset: int = [5,2,0,0,1,2,4][y-6]
				Ops.rect(result,inset,y,16-inset*2,1,Color("ffffff") if y<10 else Color("c0cbdc"))
			Ops.rect(result,3,5,4,2,Color("ffffff"))
			Ops.rect(result,9,4,4,4,Color("ffffff"))
		"gravity_console_0":
			Ops.rect(result,1,3,14,11,ink)
			Ops.rect(result,2,4,12,9,Color("5a6988"))
			Ops.rect(result,3,5,10,5,Color("193c3e"))
			Ops.line(result,Vector2i(6,9),Vector2i(6,5),Color("2ce8f5"))
			Ops.line(result,Vector2i(4,7),Vector2i(6,5),Color("2ce8f5"))
			Ops.line(result,Vector2i(6,5),Vector2i(8,7),Color("2ce8f5"))
			Ops.rect(result,10,6,2,3,accent)
			Ops.rect(result,3,12,2,1,light)
			Ops.rect(result,8,12,3,1,accent)
			Ops.rect(result,0,14,16,2,Color("262b44"))
		"quantum_pad_0":
			Ops.rect(result,1,12,14,4,ink)
			Ops.rect(result,2,13,12,2,Color("5a6988"))
			Ops.rect(result,3,11,10,1,accent)
			for x in [3,12]:
				Ops.rect(result,x,2,1,8,Color(accent,0.6))
				Ops.rect(result,x-1,4,3,2,accent)
			Ops.rect(result,7,6,2,2,Color("2ce8f5"))
			Ops.rect(result,6,10,4,1,Color("ffffff"))
		"magnetic_rail_0":
			Ops.rect(result,0,1,16,4,ink)
			Ops.rect(result,0,2,16,2,Color("2ce8f5"))
			for x in [2,7,12]:
				Ops.rect(result,x,5,2,5,accent)
		_:
			return null
	return result
