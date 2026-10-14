extends RefCounted
## Display-only cave hazards. No settlement behavior lives in the art layer.
const Ops := preload("res://pushbox/scripts/art/canvas_ops.gd")

static func image(name: String) -> Image:
	if name == "stalactite_0":
		var result: Image = Ops.canvas(Vector2i(32,32))
		for y in 30:
			var width: int = maxi(2,30-y)
			Ops.rect(result,(32-width)/2,y,width,1,Color("181425"))
			Ops.rect(result,(32-width)/2+1,y,maxi(0,width-2),1,Color("5a6988"))
		Ops.line(result,Vector2i(6,2),Vector2i(16,27),Color("8b9bb4"))
		Ops.line(result,Vector2i(21,2),Vector2i(16,20),Color("3a4466"))
		Ops.line(result,Vector2i(15,3),Vector2i(18,12),Color("2ce8f5"))
		return result
	if name == "geyser_0":
		var result: Image = Ops.canvas(Vector2i(32,32))
		Ops.rect(result,3,24,26,7,Color("181425"))
		Ops.rect(result,5,25,22,5,Color("5a6988"))
		Ops.rect(result,9,23,14,3,Color("193c3e"))
		for i in 5:
			Ops.rect(result,10+i*2,6+(i%3)*4,2,17-(i%3)*4,Color("63c74d"))
		Ops.rect(result,12,2,2,3,Color("fee761"))
		Ops.rect(result,20,8,2,2,Color("fee761"))
		return result
	return null
