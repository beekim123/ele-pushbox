extends RefCounted
const Ops := preload("res://pushbox/scripts/art/canvas_ops.gd")
static func image(name: String) -> Image:
	var result: Image = Ops.canvas(Vector2i(16,16))
	if name == "stalactite_0":
		for y in 15:
			var width: int = maxi(1,16-y)
			Ops.rect(result,(16-width)/2,y,width,1,Color("181425"))
			Ops.rect(result,(16-width)/2+1,y,maxi(0,width-2),1,Color("5a6988"))
		Ops.line(result,Vector2i(3,1),Vector2i(8,12),Color("8b9bb4"))
		Ops.line(result,Vector2i(9,2),Vector2i(8,8),Color("2ce8f5"))
	elif name == "geyser_0":
		Ops.rect(result,1,12,14,4,Color("181425"))
		Ops.rect(result,2,13,12,2,Color("5a6988"))
		Ops.rect(result,5,11,6,2,Color("193c3e"))
		for i in 4:
			Ops.rect(result,4+i*2,3+i%3,1,8-i%3,Color("63c74d"))
		Ops.rect(result,6,1,1,2,Color("fee761"))
	else:
		return null
	return result
