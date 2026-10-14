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
static func themed_lamp(theme: int, accent: Color, frame: int = 0) -> Image:
	var result: Image = Ops.canvas(Vector2i(16,24))
	var f: int = posmod(frame,4)
	var dark := Color("181425")
	Ops.line(result,Vector2i(7,0),Vector2i(7,5),Color("8b9bb4"))
	if theme == 2:
		Ops.rect(result,3,18,10,3,dark)
		Ops.rect(result,4,18,8,1,Color("fee761"))
		for y in range(6+f%3,18):
			var half: int = maxi(1,(y-4)/3)
			Ops.rect(result,8-half+(f-1)%2,y,half*2,1,Color("f77622"))
			Ops.rect(result,7,y+2,2,1,Color("fee761"))
		Ops.rect(result,7+f/2,13,1,4,Color("ffffff"))
	else:
		Ops.rect(result,4,6,8,13,dark)
		Ops.rect(result,5,7,6,10,Color("3e8948") if theme == 1 else Color("5a6988"))
		Ops.rect(result,4,6,8,1,Color("feae34") if theme in [0,4] else accent)
		Ops.rect(result,4,18,8,1,accent)
		var glow: Color = [accent,Color("fee761"),Color("ffffff"),Color("ead4aa")][f]
		if theme == 3:
			for y in range(8,17):
				Ops.rect(result,7-(y-8)/4,y,2+(y-8)/2,1,glow)
		elif theme == 5:
			Ops.line(result,Vector2i(7,8),Vector2i(7,16),glow)
			Ops.rect(result,5,10+f,6,1,accent)
		else:
			Ops.rect(result,6,9,4,6,glow)
			Ops.rect(result,7+(f%2),8+(f/2),1,2,Color("ffffff"))
		Ops.rect(result,7,20,2,2,accent)
	return result
