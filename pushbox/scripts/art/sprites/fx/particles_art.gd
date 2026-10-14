extends RefCounted
const Ops := preload("res://pushbox/scripts/art/canvas_ops.gd")

static func image(name: String, accent: Color) -> Image:
	if name != "spark_0":
		return null
	var result: Image = Ops.canvas(Vector2i(8,8))
	Ops.rect(result,3,0,1,7,accent)
	Ops.rect(result,0,3,7,1,accent)
	Ops.rect(result,3,3,1,1,Color.WHITE)
	return result
