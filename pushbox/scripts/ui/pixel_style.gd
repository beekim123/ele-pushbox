extends RefCounted
## Shared native-pixel drawing; resources stay replaceable by filename.
const INK := Color("181425")
const WHITE := Color("ffffff")
const YELLOW := Color("fee761")
static var _font: FontFile
static var _textures: Dictionary = {}
static var _panel: StyleBoxTexture

static func font() -> FontFile:
	if _font == null:
		_font = FontFile.new()
		_font.data = FileAccess.get_file_as_bytes("res://pushbox/assets/fonts/fusion-pixel-12px-proportional-zh_hans.otf.woff2")
		_font.antialiasing = TextServer.FONT_ANTIALIASING_NONE
		_font.hinting = TextServer.HINTING_NONE
		_font.subpixel_positioning = TextServer.SUBPIXEL_POSITIONING_DISABLED
		_font.allow_system_fallback = false
		_font.oversampling = 1.0
	return _font

static func texture(name: String) -> Texture2D:
	if not _textures.has(name):
		var image := Image.load_from_file("res://pushbox/assets/sprites/%s.png" % name)
		_textures[name] = ImageTexture.create_from_image(image)
	return _textures[name]

static func text(canvas: CanvasItem, value: String, at: Vector2, color: Color = WHITE) -> void:
	var p: Vector2 = at.round()
	canvas.draw_string_outline(font(), p, value, HORIZONTAL_ALIGNMENT_LEFT, -1, 12, 1, INK)
	canvas.draw_string(font(), p, value, HORIZONTAL_ALIGNMENT_LEFT, -1, 12, color)

static func panel(canvas: CanvasItem, rect: Rect2) -> void:
	if _panel == null:
		_panel = StyleBoxTexture.new()
		_panel.texture = texture("panel_9slice")
		for side in [SIDE_LEFT, SIDE_TOP, SIDE_RIGHT, SIDE_BOTTOM]:
			_panel.set_texture_margin(side, 3)
	canvas.draw_style_box(_panel, rect)

static func warm_assets() -> void:
	font()
	var directory := DirAccess.open("res://pushbox/assets/sprites")
	for filename in directory.get_files():
		if filename.ends_with(".png"):
			texture(filename.trim_suffix(".png"))
