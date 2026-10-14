extends RefCounted
## Deterministic native-pixel primitives shared by all code-authored art.
const Palette := preload("res://pushbox/scripts/art/palette.gd")

static func canvas(size: Vector2i, color: Color = Color(0,0,0,0)) -> Image:
	var result := Image.create(size.x, size.y, false, Image.FORMAT_RGBA8)
	result.fill(color)
	return result

static func compile(rows: Array) -> Image:
	var result: Image = canvas(Vector2i(rows[0].length(), rows.size()))
	for y in rows.size():
		for x in rows[y].length():
			var code: String = rows[y][x]
			if code != ".":
				result.set_pixel(x, y, Palette.PALETTE[code])
	return result

static func rect(image: Image, x: int, y: int, width: int, height: int, color: Color) -> void:
	var clipped := Rect2i(x,y,width,height).intersection(Rect2i(Vector2i.ZERO,image.get_size()))
	if clipped.has_area():
		image.fill_rect(clipped, color)

static func line(image: Image, start: Vector2i, end: Vector2i, color: Color) -> void:
	var dx: int = absi(end.x-start.x)
	var dy: int = -absi(end.y-start.y)
	var sx: int = 1 if start.x < end.x else -1
	var sy: int = 1 if start.y < end.y else -1
	var error: int = dx+dy
	var at: Vector2i = start
	while true:
		if Rect2i(Vector2i.ZERO,image.get_size()).has_point(at):
			image.set_pixelv(at,color)
		if at == end:
			break
		var twice: int = error*2
		if twice >= dy:
			error += dy
			at.x += sx
		if twice <= dx:
			error += dx
			at.y += sy

static func h32(x: int, y: int) -> int:
	return absi((x*73856093) ^ (y*19349663)) & 0x7fffffff

static func dither(image: Image, area: Rect2i, color: Color) -> void:
	for y in range(area.position.y,area.end.y,2):
		for x in range(area.position.x+(y%4)/2,area.end.x,2):
			rect(image,x,y,1,1,color)
