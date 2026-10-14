extends RefCounted
const Base := preload("res://pushbox/scripts/art/themes/theme_base.gd")
static func spec() -> Dictionary:
	return Base.make(0, "dungeon", {}, {})

static func baseline_background() -> Image:
	var result := Image.create(320, 180, false, Image.FORMAT_RGBA8)
	result.fill(Color("181425"))
	for y in range(0, 180, 16):
		for x in range(-16, 320, 32):
			var offset: int = 16 if (y / 16) % 2 else 0
			for py in range(y, mini(y + 15, 180)):
				for px in range(maxi(0, x + offset), mini(320, x + offset + 31)):
					result.set_pixel(px, py, Color("262b44"))
	for x in [88, 218]:
		_line(result, Vector2i(x, 36), Vector2i(x + 2, 43))
		_line(result, Vector2i(x + 2, 43), Vector2i(x - 1, 48))
		_line(result, Vector2i(x - 1, 48), Vector2i(x + 2, 55))
	return result

static func _line(result: Image, start: Vector2i, end: Vector2i) -> void:
	# Integer Bresenham, identical to the authored one-pixel root strokes.
	var dx: int = absi(end.x - start.x)
	var dy: int = -absi(end.y - start.y)
	var sx: int = 1 if start.x < end.x else -1
	var sy: int = 1 if start.y < end.y else -1
	var error: int = dx + dy
	var at: Vector2i = start
	while true:
		result.set_pixel(at.x, at.y, Color("3e2731"))
		if at == end:
			break
		var twice: int = error * 2
		if twice >= dy:
			error += dy
			at.x += sx
		if twice <= dx:
			error += dx
			at.y += sy

static func background(size: Vector2i) -> Image:
	return preload("res://pushbox/scripts/art/themes/natural_backdrops.gd").dungeon(size)
