extends RefCounted
## Authored baseline matrices; retain every symbol and alias exactly.
const PIXELS := {
	"lantern_idle_0": [
		"...zz...",
		"..zvvz..",
		"..z..z..",
		".zzzzzz.",
		".zkllkz.",
		".zjlljz.",
		".zjlljz.",
		".zkllkz.",
		".zjjjjz.",
		".zzzzzz.",
		"...zz...",
		"........",
	],
	"lantern_idle_1": [
		"...zz...",
		"..zvvz..",
		"..z..z..",
		".zzzzzz.",
		".zkllkz.",
		".zjcljz.",
		".zjlljz.",
		".zkllkz.",
		".zjjjjz.",
		".zzzzzz.",
		"...zz...",
		"........",
	],
	"tex_bedrock_0": [
		"yyyyyyyyyyyyyyyy",
		"ywwwwwwwwwwwwwww",
		"ywxxxxxxxxxxxxxx",
		"ywxxxxxxxxxxxxxx",
		"ywxxxxxxxxxxxxxx",
		"ywxxxxxxxxxxxxxx",
		"ywxxxxxxxxxxxxxx",
		"ywxxxxxxxxxxxxxx",
		"ywxxxxxxxxxxxxxx",
		"ywxyyyyyxxxxxxxx",
		"ywxxxxxxxxxxxxxx",
		"ywxxxxxxxxxxxxxx",
		"ywxxxxxxxxxxxxxx",
		"ywxxxxxxxxxxxxxx",
		"ywxxxxxxxxxxxxxx",
		"ywxxxxxxxxxxxxxx",
	],
	"tex_bedrock_1": [
		"yyyyyyyyyyyyyyyy",
		"ywwwwwwwwwwwwwww",
		"ywxxxxxxxxxxxxxx",
		"ywxxxxxxxxxxxxxx",
		"ywxxxxxxxxxxxxxx",
		"ywxxxxxxxxxxxxxx",
		"ywxxxxxxxxxxxxxx",
		"ywxxxxxxxxxxxxxx",
		"ywxxxxxxxxxxxxxx",
		"ywxxxxxyyyyyxxxx",
		"ywxxxxxxxxxxxxxx",
		"ywxxxxxxxxxxxxxx",
		"ywxxxxxxxxxxxxxx",
		"ywxxxxxxxxxxxxxx",
		"ywxxxxxxxxxxxxxx",
		"ywxxxxxxxxxxxxxx",
	],
	"tex_cracked_0": [
		"dddddddddggddddd",
		"dFFFFFFFFgFFFFFF",
		"dFFFFFFFggFFFFFF",
		"dFFFFFFFgFFFFFFF",
		"gFFFFFFggFFFFFFF",
		"dggFFFggggFFFFFF",
		"dFFgggFFgggFFFFF",
		"dFFFFFFFFgggFFFF",
		"dFFFFFFggggFFFFF",
		"dFFFFFgggFFFFFFF",
		"dFFFFFggggFFFFFF",
		"dFFFFFggFFgggFFF",
		"dFFFFFFggFFFFgFF",
		"dFFFFFFggFFFFFgF",
		"dFFFFFFFggFFFFFg",
		"dFFFFFFFggFFFFFF",
	],
}
const NAMES := {
	"lantern_idle_0": "lantern_idle_0",
	"lantern_idle_1": "lantern_idle_1",
	"tex_bedrock_0": "tex_bedrock_0",
	"tex_bedrock_1": "tex_bedrock_1",
	"tex_cracked_0": "tex_cracked_0",
	"tex_cracked_1": "tex_cracked_0",
}

const Ops := preload("res://pushbox/scripts/art/canvas_ops.gd")
static func themed_lamp(theme: int, accent: Color) -> Image:
	var result: Image = Ops.canvas(Vector2i(16,24))
	Ops.rect(result,7,0,1,5,Color("181425"))
	match theme:
		1:
			Ops.rect(result,4,5,8,14,Color("181425"))
			Ops.rect(result,5,6,6,12,Color("265c42"))
			Ops.rect(result,7,9,2,2,Color("fee761"))
			Ops.rect(result,9,14,1,1,Color("63c74d"))
			Ops.rect(result,4,7,8,1,Color("3e8948"))
			Ops.rect(result,4,17,8,1,Color("3e8948"))
		2:
			Ops.rect(result,3,16,10,6,Color("181425"))
			Ops.rect(result,4,17,8,3,Color("feae34"))
			Ops.rect(result,5,9,6,7,Color("f77622"))
			Ops.rect(result,6,7,3,8,Color("fee761"))
			Ops.rect(result,7,6,1,6,Color("ffffff"))
		3:
			Ops.rect(result,3,16,10,5,Color("181425"))
			Ops.rect(result,4,9,3,9,Color("0099db"))
			Ops.rect(result,8,5,3,13,Color("2ce8f5"))
			Ops.rect(result,11,12,2,6,Color("b55088"))
			Ops.rect(result,8,5,1,10,Color("ffffff"))
		4:
			Ops.rect(result,3,6,10,12,Color("181425"))
			Ops.rect(result,4,7,8,10,Color("c0cbdc"))
			Ops.rect(result,6,8,4,7,Color("ffffff"))
			Ops.rect(result,4,17,8,1,Color("feae34"))
			Ops.rect(result,7,19,1,4,Color("fee761"))
		5:
			Ops.rect(result,4,17,8,5,Color("181425"))
			Ops.rect(result,5,18,6,3,Color("5a6988"))
			Ops.rect(result,7,6,2,10,accent)
			Ops.rect(result,4,8,8,1,Color("2ce8f5"))
			Ops.rect(result,6,5,4,1,Color("ffffff"))
	return result
