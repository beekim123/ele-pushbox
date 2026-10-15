class_name PortitorUI
extends RefCounted
## Controls share the approved panels/icons and the original dynamic fonts.
const INK := Color("c0cbdc")
const GOLD := Color("fee761")
const DARK := Color("181425")
const FONT_PATH := "res://bin/fonts/fusion-pixel-12px/fusion-pixel-12px-proportional-zh_hans.otf.woff2"
const SMALL_FONT_PATH := "res://bin/fonts/fusion-pixel-10px/fusion-pixel-10px-proportional-sc.woff2"
static var _font: FontFile
static var _small: FontFile
static var _menu_face: FontVariation
static var _bubble_face: FontVariation

static func font(small: bool = false) -> Font:
	if _font == null:
		_font = load(FONT_PATH) as FontFile
		_small = load(SMALL_FONT_PATH) as FontFile
		for item: FontFile in [_font, _small]:
			if item != null:
				item.antialiasing = TextServer.FONT_ANTIALIASING_NONE
				item.hinting = TextServer.HINTING_NONE
				item.subpixel_positioning = TextServer.SUBPIXEL_POSITIONING_DISABLED
				item.multichannel_signed_distance_field = false
		_menu_face = FontVariation.new()
		_menu_face.base_font = _font
		_menu_face.spacing_top = -2 # Pillow baseline 11, line height 14.
		_bubble_face = FontVariation.new()
		_bubble_face.base_font = _small
		_bubble_face.spacing_top = -2
		_bubble_face.spacing_bottom = -2 # Pillow baseline 10, line height 12.
	return _bubble_face if small else _menu_face

static func label(text: String, width: float, small: bool = false, wrap: bool = false) -> Label:
	var node := Label.new()
	node.add_theme_font_override("font", font(small))
	node.add_theme_font_size_override("font_size", 10 if small else 12)
	node.add_theme_color_override("font_color", INK)
	node.add_theme_constant_override("line_spacing", 0)
	node.custom_minimum_size.x = width
	node.size.x = width
	if wrap:
		node.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		node.custom_maximum_size.x = width
	else:
		node.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	node.text = text
	node.reset_size()
	node.size.x = width
	# Font overrides invalidate minimum-size caches after entering the tree.
	# Reset again after that notification so the initial default-font height
	# cannot survive on absolutely positioned labels.
	node.call_deferred("reset_size")
	node.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return node

static func atlas(uid: String, animation: String = "default", index: int = 0) -> AtlasTexture:
	var registry: Node = Engine.get_main_loop().root.get_node("Registry")
	var art: Dictionary = registry.art(uid)
	var path: String = art.get("texture_path", "")
	if path.is_empty() or not art.get("approved", false):
		return null
	var texture: Texture2D = load(path) as Texture2D
	var dimensions: Array = art.get("size", [16, 16])
	var animations: Dictionary = art.get("animations", {})
	var frames: Array = animations.get(animation, {}).get("frames", [index])
	var frame: int = int(frames[index % frames.size()])
	var result := AtlasTexture.new()
	result.atlas = texture
	result.region = Rect2(frame * int(dimensions[0]), 0, int(dimensions[0]), int(dimensions[1]))
	return result

static func panel_style(frame: int = 0) -> StyleBox:
	var texture: AtlasTexture = atlas("art:ui.panel", "default", frame)
	if texture == null:
		var plain := StyleBoxFlat.new()
		plain.bg_color = DARK
		return plain
	var result := StyleBoxTexture.new()
	result.texture = texture
	for side: int in [SIDE_LEFT, SIDE_TOP, SIDE_RIGHT, SIDE_BOTTOM]:
		result.set_texture_margin(side, 6)
		result.set_content_margin(side, 0)
	return result

static func button(text: String, action: Callable, width: float = 100, icon_uid: String = "", icon_animation: String = "default") -> Button:
	var node := Button.new()
	node.text = text
	node.add_theme_font_override("font", font())
	node.add_theme_font_size_override("font_size", 12)
	node.add_theme_color_override("font_color", INK)
	node.add_theme_color_override("font_focus_color", GOLD)
	node.add_theme_color_override("font_hover_color", GOLD)
	node.add_theme_stylebox_override("normal", panel_style())
	node.add_theme_stylebox_override("focus", panel_style(1))
	node.add_theme_stylebox_override("hover", panel_style(1))
	node.add_theme_stylebox_override("pressed", panel_style(1))
	node.custom_minimum_size = Vector2(width, 15)
	node.alignment = HORIZONTAL_ALIGNMENT_LEFT
	if not icon_uid.is_empty():
		node.icon = atlas(icon_uid, icon_animation)
	node.pressed.connect(action)
	return node

static func panel(rect: Rect2, frame: int = 0) -> PanelContainer:
	var node := PanelContainer.new()
	node.position = rect.position
	node.size = rect.size
	node.add_theme_stylebox_override("panel", panel_style(frame))
	return node

static func margin(left: int = 6, top: int = 3, right: int = 6, bottom: int = 3) -> MarginContainer:
	var node := MarginContainer.new()
	for pair: Array in [["margin_left", left], ["margin_top", top], ["margin_right", right], ["margin_bottom", bottom]]:
		node.add_theme_constant_override(pair[0], pair[1])
	return node

static func column(gap: int = 1) -> VBoxContainer:
	var node := VBoxContainer.new()
	node.add_theme_constant_override("separation", gap)
	return node
