class_name PortitorG2
extends RefCounted
## G2 tokens and pixel geometry mirror workbench/js/core/ui-common.js.
## Text stays live and localized; textures contain only palette shapes.
const RASTER = preload("res://presentation/render/palette_raster.gd")
const PANEL: Dictionary = {"r": 4, "rings": ["z", "u"], "fill": "y"}
const SMALL: Dictionary = {"r": 3, "rings": ["z", "u"], "fill": "y"}
const BUTTONS: Dictionary = {
	"n": {"r": 3, "rings": ["z"], "fill": "x", "top": ["w", 1]},
	"sel": {"r": 3, "rings": ["z"], "fill": "t", "bottom": ["u", 1]},
	"dis": {"r": 3, "rings": ["z", "x"], "fill": "y"}}
const INK: Dictionary = {"n": "t", "sel": "y", "dis": "w"}
const KEY: Dictionary = {"r": 1, "rings": ["z"], "fill": "x", "top": ["w", 1]}
const NEIGHBORS: Array[Vector2i] = [Vector2i.LEFT, Vector2i.RIGHT, Vector2i.UP, Vector2i.DOWN]
static var _textures: Dictionary = {}
static var _fonts: Dictionary = {}

static func font(small: bool = false) -> Font:
	if not _fonts.has(small):
		var source: FontVariation = PortitorUI.font(small) as FontVariation
		var face := FontVariation.new()
		face.base_font = source.base_font
		face.spacing_top = source.spacing_top
		face.spacing_bottom = source.spacing_bottom
		# The workbench places bitmap glyphs individually, without kerning.
		face.opentype_features = {"kern": 0}
		_fonts[small] = face
	return _fonts[small]

static func measure(value: String, small: bool = false) -> int:
	return roundi(font(small).get_string_size(value, HORIZONTAL_ALIGNMENT_LEFT, -1, 10 if small else 12).x)

static func fit(value: String, room: int, small: bool = false) -> String:
	if measure(value, small) <= room:
		return value
	var result: String = value
	while not result.is_empty() and measure(result + "…", small) > room:
		result = result.left(-1)
	return result + "…" if room >= measure("…", small) else ""

static func text(parent: Node, at: Vector2, value: String, code: String = "t", small: bool = false, align: String = "l", room: int = -1) -> Label:
	var shown: String = fit(value, room, small) if room >= 0 else value
	var width: int = measure(shown, small)
	var node: Label = PortitorUI.label(shown, maxi(1, width), small)
	node.add_theme_font_override("font", font(small))
	node.position = at - Vector2(width / 2 if align == "c" else width if align == "r" else 0, 2 if small else 1)
	node.add_theme_color_override("font_color", RASTER.color_of(code))
	parent.add_child(node)
	return node

static func mask(dimensions: Vector2i, radius: int) -> Dictionary:
	var result: Dictionary = {}
	for y: int in dimensions.y:
		for x: int in dimensions.x:
			var dx: float = maxf(0, radius - minf(x + 0.5, dimensions.x - x - 0.5))
			var dy: float = maxf(0, radius - minf(y + 0.5, dimensions.y - y - 0.5))
			if dx * dx + dy * dy <= radius * radius:
				result[Vector2i(x, y)] = true
	return result

static func _shrink(points: Dictionary) -> Dictionary:
	var result: Dictionary = {}
	for point: Vector2i in points:
		var inside: bool = true
		for offset: Vector2i in NEIGHBORS + [Vector2i(-1, -1), Vector2i(1, -1), Vector2i(-1, 1), Vector2i(1, 1)]:
			if not points.has(point + offset):
				inside = false
				break
		if inside:
			result[point] = true
	return result

static func box_texture(dimensions: Vector2i, style: Dictionary) -> Texture2D:
	var key: String = str(dimensions) + JSON.stringify(style)
	if _textures.has(key):
		return _textures[key]
	var image: Image = Image.create(dimensions.x, dimensions.y, false, Image.FORMAT_RGBA8)
	var points: Dictionary = mask(dimensions, int(style.get("r", 0)))
	for code: String in style.get("rings", []):
		var inside: Dictionary = _shrink(points)
		for point: Vector2i in points:
			if not inside.has(point): image.set_pixelv(point, RASTER.color_of(code))
		points = inside
	for point: Vector2i in points:
		if style.has("fill"): image.set_pixelv(point, RASTER.color_of(style.fill))
	for side: String in ["top", "bottom"]:
		if not style.has(side): continue
		var band: Array = style[side]
		var direction: int = -1 if side == "top" else 1
		for point: Vector2i in points:
			for offset: int in range(1, int(band[1]) + 1):
				if not points.has(point + Vector2i(0, direction * offset)):
					image.set_pixelv(point, RASTER.color_of(band[0]))
					break
	var texture: ImageTexture = ImageTexture.create_from_image(image)
	_textures[key] = texture
	return texture

static func box(parent: Node, rect: Rect2, style: Dictionary) -> TextureRect:
	var node := TextureRect.new()
	node.texture = box_texture(Vector2i(rect.size), style)
	node.position = rect.position
	node.size = rect.size
	node.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	node.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(node)
	return node

static func rect(parent: Node, area: Rect2, code: String) -> ColorRect:
	var node := ColorRect.new()
	node.position = area.position
	node.size = area.size
	node.color = RASTER.color_of(code)
	node.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(node)
	return node

static func panel(parent: Node, area: Rect2, small: bool = false) -> TextureRect:
	return box(parent, area, SMALL if small else PANEL)

static func plate(parent: Node, area: Rect2) -> TextureRect:
	return box(parent, area, SMALL)

static func heading(parent: Node, at: Vector2, value: String, room: int = 304) -> void:
	var shown: String = fit(value, room - 14)
	plate(parent, Rect2(at, Vector2(measure(shown) + 14, 17)))
	text(parent, at + Vector2(7, 3), shown)

static func title(parent: Node, area: Rect2, value: String) -> void:
	var shown: String = fit(value, int(area.size.x) - 40)
	var width: int = measure(shown)
	var center: int = int(area.position.x) + int(area.size.x) / 2
	text(parent, Vector2(center, area.position.y + 6), shown, "t", false, "c")
	rect(parent, Rect2(center - width / 2 - 13, area.position.y + 11, 7, 1), "m")
	rect(parent, Rect2(center + width - width / 2 + 6, area.position.y + 11, 7, 1), "m")
	rect(parent, Rect2(area.position.x + 6, area.position.y + 20, area.size.x - 12, 1), "x")

static func row(parent: Node, area: Rect2) -> TextureRect:
	return box(parent, area, {"r": 3, "fill": "t"})

static func button(parent: Node, area: Rect2, value: String, action: Callable) -> Button:
	var node := Button.new()
	node.position = area.position
	node.size = Vector2(maxf(area.size.x, measure(value) + 12), area.size.y)
	node.text = value
	node.add_theme_font_override("font", font())
	node.add_theme_font_size_override("font_size", 12)
	for state: String in ["normal", "hover", "pressed", "focus", "disabled"]:
		var token: String = "dis" if state == "disabled" else "n" if state == "normal" else "sel"
		var style := StyleBoxTexture.new()
		style.texture = box_texture(Vector2i(node.size), BUTTONS[token])
		node.add_theme_stylebox_override(state, style)
		node.add_theme_color_override("font_" + ("color" if state == "normal" else state + "_color"), RASTER.color_of(INK[token]))
	node.pressed.connect(action)
	parent.add_child(node)
	return node

static func arrow(parent: Node, at: Vector2, direction: String, code: String = "m") -> void:
	for i: int in 3:
		for j: int in range(-i, i + 1):
			var offset: Vector2 = Vector2(i, j) if direction == "left" else Vector2(-i, j) if direction == "right" else Vector2(j, i) if direction == "up" else Vector2(j, -i)
			rect(parent, Rect2(at + offset, Vector2.ONE), code)

static func cursor(parent: Node, at: Vector2, direction: String = "right") -> Control:
	var node := Control.new()
	node.position = at
	node.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(node)
	var points: Dictionary = {}
	for i: int in 4:
		for j: int in range(-i, i + 1):
			points[Vector2i(i, j) if direction == "left" else Vector2i(-i, j) if direction == "right" else Vector2i(j, i) if direction == "up" else Vector2i(j, -i)] = true
	for point: Vector2i in points:
		for offset: Vector2i in NEIGHBORS:
			if not points.has(point + offset): rect(node, Rect2(Vector2(point + offset), Vector2.ONE), "z")
	for point: Vector2i in points:
		rect(node, Rect2(Vector2(point), Vector2.ONE), "m")
	return node

static func key_width(value: String) -> int:
	return 11 if value in ["up", "down", "left", "right"] else measure(value, true) + 7

static func keycap(parent: Node, at: Vector2, value: String) -> int:
	var width: int = key_width(value)
	box(parent, Rect2(at, Vector2(width, 11)), KEY)
	if value in ["up", "down", "left", "right"]:
		arrow(parent, at + (Vector2(5, 3) if value == "up" else Vector2(5, 7) if value == "down" else Vector2(4, 5) if value == "left" else Vector2(6, 5)), value, "t")
	else:
		text(parent, at + Vector2(width / 2, 1), value, "t", true, "c")
	return width

static func keybar(parent: Node, groups: Array[Dictionary], at: Vector2 = Vector2(160, 164)) -> void:
	var width: int = 0
	for index: int in groups.size():
		var group: Dictionary = groups[index]
		for key: String in group["keys"]:
			width += key_width(key) + 1
		width += 2 + measure(group.label, true) + (9 if index < groups.size() - 1 else 0)
	var x: int = int(at.x) - (width + 12) / 2
	plate(parent, Rect2(x, at.y - 2, width + 12, 15))
	x += 6
	for group: Dictionary in groups:
		for index: int in group["keys"].size():
			x += keycap(parent, Vector2(x, at.y), group["keys"][index]) + (1 if index < group["keys"].size() - 1 else 0)
		x += 3
		text(parent, Vector2(x, at.y + 1), group.label, "t", true)
		x += measure(group.label, true) + 9

static func slider(parent: Node, at: Vector2, width: int, value: float) -> Control:
	var node := Control.new()
	node.position = at
	node.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(node)
	var fx: int = 3 + roundi((width - 7) * clampf(value, 0, 1))
	box(node, Rect2(0, 2, width, 5), {"r": 2, "rings": ["z"], "fill": "x"})
	rect(node, Rect2(1, 3, fx - 1, 3), "m")
	box(node, Rect2(fx - 3, 0, 7, 9), {"r": 2, "rings": ["z"], "fill": "t"})
	return node

static func toggle(parent: Node, at: Vector2, enabled: bool) -> void:
	box(parent, Rect2(at, Vector2(19, 11)), {"r": 5, "rings": ["z"], "fill": "m" if enabled else "x"})
	box(parent, Rect2(at + Vector2(9 if enabled else 1, 1), Vector2(9, 9)), {"r": 4, "fill": "t"})

static func tag(parent: Node, at: Vector2, value: String, quiet: bool = false) -> int:
	var width: int = measure(value, true) + 8
	box(parent, Rect2(at, Vector2(width, 12)), {"r": 2, "rings": ["u"], "fill": "y"} if quiet else {"r": 2, "fill": "m"})
	text(parent, at + Vector2(4, 1), value, "t" if quiet else "y", true)
	return width

static func well(parent: Node, area: Rect2, selected: bool = false) -> TextureRect:
	return box(parent, area, {"r": 2, "rings": ["m" if selected else "z"], "fill": "z"})

static func dot(parent: Node, center: Vector2, radius: int, code: String) -> void:
	var points: Dictionary = {}
	for y: int in range(-radius, radius + 1):
		for x: int in range(-radius, radius + 1):
			if x * x + y * y <= radius * radius + radius * 0.8: points[Vector2i(x, y)] = true
	for point: Vector2i in points:
		for offset: Vector2i in NEIGHBORS:
			if not points.has(point + offset): rect(parent, Rect2(center + Vector2(point + offset), Vector2.ONE), "z")
	for point: Vector2i in points:
		rect(parent, Rect2(center + Vector2(point), Vector2.ONE), code)

static func icon(parent: Node, uid: String, animation: String, at: Vector2, code: String = "") -> TextureRect:
	var atlas: AtlasTexture = PortitorUI.atlas(uid, animation)
	if atlas == null: return null
	var texture: Texture2D = atlas
	if not code.is_empty():
		var pixels: Image = atlas.get_image()
		for y: int in pixels.get_height():
			for x: int in pixels.get_width():
				if pixels.get_pixel(x, y).a > 0: pixels.set_pixel(x, y, RASTER.color_of(code))
		texture = ImageTexture.create_from_image(pixels)
	var node := TextureRect.new()
	node.texture = texture
	node.position = at
	node.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(node)
	return node

class LevelPicture extends TextureRect:
	## Presentation-only initial map, using the same approved palette shaders.
	## No SDK world, input, save, or simulation is created by a thumbnail.
	const ILLUSTRATION = preload("res://presentation/ui/widgets/procedural_illustration.gd")
	const PIXELS = preload("res://presentation/render/palette_raster.gd")
	var viewport: SubViewport

	func configure(spec: Dictionary, theme_uid: String, tick: int) -> void:
		size = Vector2(126, 44)
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		if DisplayServer.get_name() == "headless": return
		var rows: Array = spec.get("map", [])
		if rows.is_empty(): return
		var art: Dictionary = Registry.art(theme_uid)
		if not art.get("approved", false): return
		var theme: Dictionary = art.get("params", {})
		var map_width: int = str(rows[0]).length()
		var map_height: int = rows.size()
		var origin := Vector2i((320 - map_width * 16) / 2, (180 - map_height * 16) / 2 + 10)
		viewport = SubViewport.new()
		viewport.size = Vector2i(320, 180)
		viewport.transparent_bg = false
		viewport.render_target_update_mode = SubViewport.UPDATE_ONCE
		viewport.canvas_item_default_texture_filter = Viewport.DEFAULT_CANVAS_ITEM_TEXTURE_FILTER_NEAREST
		add_child(viewport)
		var backdrop = PIXELS.new(320, 180)
		ILLUSTRATION.BACKGROUND.draw(backdrop, theme, Rect2i(0, 0, 320, 180), tick)
		_layer(backdrop.image())
		var cells := PackedByteArray()
		cells.resize(map_width * map_height)
		var actors = PIXELS.new(320, 180)
		var sprites: Dictionary = {"P":["char.portitor","idle"], "b":["obj.crate_wood","default"], "B":["obj.crate_wood","default"], "X":["mech.exit_flag","idle"], "I":["obj.crate_iron","default"], "H":["mech.ladder","default"], "e":["mech.exit_flag","idle"], "|":["mech.door","closed"], "_":["mech.plate","up"]}
		for y: int in map_height:
			for x: int in map_width:
				var glyph: String = str(rows[y]).substr(x, 1)
				cells[y * map_width + x] = 1 if glyph == "#" else 3 if glyph == "%" else 0
				if sprites.has(glyph):
					var sprite: Array = sprites[glyph]
					if Registry.art("art:" + str(sprite[0])).get("approved", false):
						ILLUSTRATION.SPRITES.blit(actors, "art:" + str(sprite[0]), str(sprite[1]), tick, origin + Vector2i(x * 16 + 8, y * 16 + 16))
		var terrain := ColorRect.new()
		terrain.position = Vector2(origin)
		terrain.size = Vector2(map_width * 16, map_height * 16)
		var material: ShaderMaterial = ILLUSTRATION.TERRAIN.create(theme)
		material.set_shader_parameter("grid_size", Vector2i(map_width, map_height))
		material.set_shader_parameter("map_texture", ImageTexture.create_from_image(Image.create_from_data(map_width, map_height, false, Image.FORMAT_R8, cells)))
		material.set_shader_parameter("visual_tick", tick >> 3)
		terrain.material = material
		viewport.add_child(terrain)
		_layer(actors.image())
		var crop := AtlasTexture.new()
		crop.atlas = viewport.get_texture()
		crop.region = Rect2(91, 85, 126, 44)
		texture = crop

	func _layer(pixels: Image) -> void:
		var node := Sprite2D.new()
		node.centered = false
		node.texture = ImageTexture.create_from_image(pixels)
		var material := ShaderMaterial.new()
		material.shader = ILLUSTRATION.PALETTE_SHADER
		node.material = material
		viewport.add_child(node)

class ChapterPicture extends LevelPicture:
	## The reference crops the same decorative stage around x=232, floor y=156.
	## These samples are illustrations, independent of chapter progress or SDKs.
	func configure_chapter(theme_uid: String, dimensions: Vector2i, _tick: int, big: bool) -> void:
		size = Vector2(dimensions)
		expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		if DisplayServer.get_name() == "headless": return
		var art: Dictionary = Registry.art(theme_uid)
		if not art.get("approved", false): return
		var theme: Dictionary = art.get("params", {})
		viewport = SubViewport.new()
		viewport.size = Vector2i(320, 180)
		viewport.render_target_update_mode = SubViewport.UPDATE_ONCE
		viewport.canvas_item_default_texture_filter = Viewport.DEFAULT_CANVAS_ITEM_TEXTURE_FILTER_NEAREST
		add_child(viewport)
		var backdrop = PIXELS.new(320, 180)
		ILLUSTRATION.BACKGROUND.draw(backdrop, theme, Rect2i(0, 0, 320, 180), 0)
		_layer(backdrop.image())
		var cells: Array[int] = []
		for y: int in 11:
			for x: int in 20:
				cells.append(1 if y >= 9 else 3 if y >= 6 and x in [11, 12] else 0)
		var map: Dictionary = {"w":20,"h":11,"terrain":cells}
		var occupied: Callable = func(x: int, y: int) -> bool: return (y == 8 and x in [13, 14, 15]) or (y == 7 and x == 15)
		var options: Dictionary = {"mode":"one","seed":ILLUSTRATION.AMBIENT.seed_of(theme_uid.trim_prefix("art:")),"has":ILLUSTRATION.SPRITES.has}
		var origin := Vector2i(0, 12)
		var back = PIXELS.new(320, 180)
		var front = PIXELS.new(320, 180)
		for command: Dictionary in ILLUSTRATION.AMBIENT.plan(theme, map, origin, 0, "back", occupied, Rect2i(0, 0, 320, 154), Callable(), options):
			ILLUSTRATION.SPRITES.blit(back, command.uid, command.anim, command.tick, Vector2i(command.x, command.y), command.flip)
		_layer(back.image())
		var terrain := ColorRect.new()
		terrain.position = Vector2(origin)
		terrain.size = Vector2(320, 176)
		var material: ShaderMaterial = ILLUSTRATION.TERRAIN.create(theme)
		material.set_shader_parameter("grid_size", Vector2i(20, 11))
		material.set_shader_parameter("map_texture", ImageTexture.create_from_image(Image.create_from_data(20, 11, false, Image.FORMAT_R8, PackedByteArray(cells))))
		material.set_shader_parameter("visual_tick", 0)
		terrain.material = material
		# Backdrop masonry is one palette step behind the foreground props.
		var masonry := SubViewport.new()
		masonry.size = Vector2i(320, 180)
		masonry.transparent_bg = true
		masonry.render_target_update_mode = SubViewport.UPDATE_ONCE
		masonry.canvas_item_default_texture_filter = Viewport.DEFAULT_CANVAS_ITEM_TEXTURE_FILTER_NEAREST
		viewport.add_child(masonry)
		masonry.add_child(terrain)
		var stone := Sprite2D.new()
		stone.centered = false
		stone.texture = masonry.get_texture()
		var dim := ShaderMaterial.new()
		dim.shader = preload("res://presentation/ui/widgets/palette_dim.gdshader")
		dim.set_shader_parameter("dim_steps", 1)
		stone.material = dim
		viewport.add_child(stone)
		for command: Dictionary in ILLUSTRATION.AMBIENT.plan(theme, map, origin, 0, "front", occupied, Rect2i(0, 0, 320, 154), Callable(), options):
			ILLUSTRATION.SPRITES.blit(front, command.uid, command.anim, command.tick, Vector2i(command.x, command.y), command.flip)
		ILLUSTRATION.SPRITES.blit(front, "art:char.portitor", "idle", 0, Vector2i(216, 156))
		for at: Vector2i in [Vector2i(232, 156), Vector2i(248, 156), Vector2i(248, 140)]:
			ILLUSTRATION.SPRITES.blit(front, "art:obj.crate_wood", "default", 0, at)
		_layer(front.image())
		var crop := AtlasTexture.new()
		crop.atlas = viewport.get_texture()
		crop.region = Rect2(232 - dimensions.x / 2, (157 if big else 156) - dimensions.y, dimensions.x, dimensions.y)
		texture = crop

	func set_tick(_tick: int) -> void:
		pass # chapterImage in the reference always renders tick 0.

	func prepare_reference() -> void:
		if viewport != null and is_inside_tree():
			await get_tree().process_frame
			await RenderingServer.frame_post_draw

class RulePicture extends LevelPicture:
	## Presentation-only cross section from the G2 rule illustration:
	## a two-cell earth pillar next to the miner, with intact floor below.
	func configure_rule(_spec: Dictionary, theme_uid: String, tick: int) -> void:
		var sample: Dictionary = {"map":["############", "############", "#### #######", "### %#######", "#  P%      #", "############", "############"]}
		configure(sample, theme_uid, tick)
		if viewport != null:
			for child: Node in viewport.get_children():
				if child is ColorRect and child.material is ShaderMaterial:
					child.position.y -= 1
				elif child is Sprite2D and child != viewport.get_child(0):
					child.position.y -= 1
		if viewport != null:
			var adornments = PIXELS.new(320, 180)
			for decoration: Array in [["art:deco.dungeon_moss", "default", Vector2i(136, 91)], ["art:deco.dungeon_torch", "flicker", Vector2i(148, 96)]]:
				if Registry.art(decoration[0]).get("approved", false): ILLUSTRATION.SPRITES.blit(adornments, decoration[0], decoration[1], tick, decoration[2])
			_layer(adornments.image())
		expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		size = Vector2(56, 44)
		if texture is AtlasTexture: (texture as AtlasTexture).region = Rect2(106, 84, 56, 44)

	func set_tick(_tick: int) -> void:
		pass

static func overlay_capsule(parent: Node, area: Rect2) -> void:
	box(parent, area, {"r":4, "rings":["r"], "fill":"y"})
	rect(parent, Rect2(area.position + Vector2(2, 0), Vector2(area.size.x - 4, 1)), "s")
	rect(parent, Rect2(area.position + Vector2(2, area.size.y - 1), Vector2(area.size.x - 4, 1)), "q")

static func pip(parent: Node, center: Vector2, code: String, radius: int = 2, filled: bool = true) -> void:
	var points: Dictionary = {}
	for y: int in range(-radius, radius + 1):
		for x: int in range(-radius, radius + 1):
			if absi(x) + absi(y) <= radius: points[Vector2i(x, y)] = true
	for point: Vector2i in points:
		for neighbor: Vector2i in NEIGHBORS:
			if not points.has(point + neighbor): rect(parent, Rect2(center + Vector2(point + neighbor), Vector2.ONE), "z")
	for point: Vector2i in points: rect(parent, Rect2(center + Vector2(point), Vector2.ONE), code if filled or absi(point.x) + absi(point.y) == radius else "y")
	if filled: rect(parent, Rect2(center + Vector2(0, -1), Vector2.ONE), "t")

static func overlay_icon(parent: Node, uid: String, animation: String, at: Vector2, dim: bool) -> TextureRect:
	var node: TextureRect = icon(parent, uid, animation, at)
	if node == null or not dim: return node
	var shades: Dictionary = {"t":"u", "u":"v", "v":"w", "w":"x", "x":"y", "y":"z", "l":"k", "k":"j", "j":"b", "b":"e", "e":"f", "f":"g", "d":"e", "c":"d", "s":"r", "r":"q", "q":"p", "m":"n", "n":"o", "o":"p"}
	var replacements: Dictionary = {}
	for code: String in shades: replacements[RASTER.color_of(code).to_rgba32()] = RASTER.color_of(shades[code])
	var pixels: Image = node.texture.get_image()
	for y: int in pixels.get_height():
		for x: int in pixels.get_width():
			var color: Color = pixels.get_pixel(x, y)
			var opaque: Color = Color(color.r, color.g, color.b, 1)
			if color.a > 0 and replacements.has(opaque.to_rgba32()):
				var shade: Color = replacements[opaque.to_rgba32()]
				shade.a = color.a
				pixels.set_pixel(x, y, shade)
	node.texture = ImageTexture.create_from_image(pixels)
	node.set_meta("g2_overlay_dimmed", true)
	return node
