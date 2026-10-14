extends RefCounted
## ENDESGA 32 symbol table and semantic palette remapping.
const PALETTE := {
	"a": Color("be4a2f"), # rust
	"b": Color("d77643"), # orange_d
	"c": Color("ead4aa"), # sand_l
	"d": Color("e4a672"), # sand
	"e": Color("b86f50"), # clay
	"f": Color("733e39"), # brown
	"g": Color("3e2731"), # brown_d
	"h": Color("a22633"), # red_d
	"i": Color("e43b44"), # red
	"j": Color("f77622"), # orange
	"k": Color("feae34"), # gold
	"l": Color("fee761"), # yellow
	"m": Color("63c74d"), # green
	"n": Color("3e8948"), # green_d
	"o": Color("265c42"), # green_dd
	"p": Color("193c3e"), # teal_dd
	"q": Color("124e89"), # blue_d
	"r": Color("0099db"), # blue
	"s": Color("2ce8f5"), # cyan
	"t": Color("ffffff"), # white
	"u": Color("c0cbdc"), # grey_l
	"v": Color("8b9bb4"), # grey
	"w": Color("5a6988"), # slate
	"x": Color("3a4466"), # slate_d
	"y": Color("262b44"), # navy
	"z": Color("181425"), # ink
	"A": Color("ff0044"), # magenta
	"B": Color("68386c"), # plum
	"C": Color("b55088"), # pink_d
	"D": Color("f6757a"), # pink
	"E": Color("e8b796"), # skin
	"F": Color("c28569"), # skin_d
}

static func swap(source: Image, replacements: Dictionary) -> Image:
	var result: Image = source.duplicate()
	for y in result.get_height():
		for x in result.get_width():
			var original: Color = result.get_pixel(x,y)
			if original.a > 0 and replacements.has(original.to_html(false)):
				result.set_pixel(x,y,Color(replacements[original.to_html(false)]))
	return result
