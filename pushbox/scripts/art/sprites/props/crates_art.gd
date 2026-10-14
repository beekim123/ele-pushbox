extends RefCounted
## Authored baseline matrices; retain every symbol and alias exactly.
const PIXELS := {
	"crate_static_0": [
		"gggggggggggggggg",
		"gddddddddddddddg",
		"gdfffffffffffedg",
		"gdfeeeeeeeeeffdg",
		"gdfefeeeeeeeffdg",
		"gdfeefeeeeeeefdg",
		"gdfeeefeeeeeefdg",
		"gdfeeeefeeeeefdg",
		"gdfeeeeefeeeefdg",
		"gdfeeeeeefeeefdg",
		"gdfeeeeeeefeefdg",
		"gdfeeeeeeeefefdg",
		"gdffeeeeeeeeefdg",
		"gdffffffffffffdg",
		"gddddddddddddddg",
		"gggggggggggggggg",
	],
}
const NAMES := {
	"crate_static_0": "crate_static_0",
}

const Ops := preload("res://pushbox/scripts/art/canvas_ops.gd")
static func decorate_wood(result: Image, theme: int) -> Image:
	match theme:
		1:
			for y in [3,7,11]:
				Ops.rect(result,2,y,12,1,Color("265c42"))
			Ops.rect(result,3,2,2,2,Color("63c74d"))
			Ops.rect(result,11,11,2,2,Color("63c74d"))
		2:
			for at in [Vector2i(1,1),Vector2i(12,1),Vector2i(1,12),Vector2i(12,12)]:
				Ops.rect(result,at.x,at.y,3,3,Color("fee761"))
			Ops.rect(result,6,6,4,4,Color("733e39"))
			Ops.rect(result,7,7,2,2,Color("feae34"))
		3:
			for x in [3,11]:
				Ops.rect(result,x,2,2,12,Color("8b9bb4"))
			Ops.rect(result,7,6,2,4,Color("2ce8f5"))
		4:
			Ops.line(result,Vector2i(4,10),Vector2i(10,4),Color("ffffff"))
			Ops.line(result,Vector2i(6,10),Vector2i(11,5),Color("ffffff"))
			Ops.rect(result,6,11,5,1,Color("feae34"))
		5:
			Ops.rect(result,2,3,12,2,Color("8b9bb4"))
			Ops.rect(result,2,11,12,2,Color("8b9bb4"))
			Ops.rect(result,5,6,6,4,Color("181425"))
			Ops.rect(result,6,7,4,1,Color("2ce8f5"))
	return result

static func iron(theme: int) -> Image:
	var result: Image = Ops.canvas(Vector2i(16,16),Color("181425"))
	var base: Color = Color(["5a6988","265c42","262b44","3a4466","c0cbdc","5a6988"][theme])
	var edge: Color = Color(["c0cbdc","63c74d","feae34","2ce8f5","ffffff","2ce8f5"][theme])
	Ops.rect(result,1,1,14,14,base)
	Ops.rect(result,1,1,14,1,edge)
	Ops.rect(result,1,2,1,12,edge)
	Ops.rect(result,3,3,10,10,Color("181425"))
	Ops.rect(result,4,4,8,8,base)
	Ops.line(result,Vector2i(5,5),Vector2i(10,10),edge)
	Ops.line(result,Vector2i(10,5),Vector2i(5,10),edge)
	for at in [Vector2i(2,2),Vector2i(12,2),Vector2i(2,12),Vector2i(12,12)]:
		Ops.rect(result,at.x,at.y,2,2,edge)
	return result
