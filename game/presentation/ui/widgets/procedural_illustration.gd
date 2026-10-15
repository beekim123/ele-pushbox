class_name ProceduralIllustration
extends TextureRect
## ui.js mapThumb/rulecard illustrations from approved rules and assets.
## Decorative drawings only: this widget creates no SDK world.

const RASTER = preload("res://presentation/render/palette_raster.gd")
const BACKGROUND = preload("res://presentation/render/themes/background.gd")
const AMBIENT = preload("res://presentation/render/ambient/ambient.gd")
const SPRITES = preload("res://presentation/render/sprites/sprite_assets.gd")
const TERRAIN = preload("res://presentation/render/terrain/terrain_material.gd")
const PALETTE_SHADER: Shader = preload("res://presentation/render/sprites/palette.gdshader")

var dug: bool = false
var _theme_uid: String
var _theme: Dictionary = {}
var _kind: String = "chapter"
var _with_hero: bool = true
var _dimensions: Vector2i
var _map: Dictionary = {}
var _origin: Vector2i
var _floor_row: int = 0
var _viewport: SubViewport
var _background: Sprite2D
var _back: Sprite2D
var _front: Sprite2D
var _terrain: ColorRect
var _material: ShaderMaterial
var _tick: int = -1
var _background_key: int = -1
var _hero_key: int = -1

func configure_chapter(theme_uid: String, dimensions: Vector2i, tick: int = 0, with_hero: bool = true) -> void:
	_kind = "chapter"
	_with_hero = with_hero
	_configure(theme_uid, dimensions, tick)

func configure_rulecard(theme_uid: String, tick: int = 0) -> void:
	_kind = "rulecard"
	_with_hero = true
	_configure(theme_uid, Vector2i(56, 32), tick)

func _configure(theme_uid: String, dimensions: Vector2i, tick: int) -> void:
	_theme_uid = theme_uid
	_dimensions = dimensions
	size = Vector2(dimensions)
	expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	stretch_mode = TextureRect.STRETCH_SCALE
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	var art: Dictionary = Registry.art(theme_uid)
	if not art.get("approved", false):
		push_error("Illustration requires an approved theme: " + theme_uid)
		return
	_theme = art.get("params", {})
	_rebuild_map(false)
	if DisplayServer.get_name() == "headless":
		dug = _kind == "rulecard" and (tick / 60) % 2 == 1
		return
	_viewport = SubViewport.new()
	_viewport.size = dimensions
	_viewport.transparent_bg = true
	_viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	_viewport.canvas_item_default_texture_filter = Viewport.DEFAULT_CANVAS_ITEM_TEXTURE_FILTER_NEAREST
	add_child(_viewport)
	_background = _sprite_layer()
	_back = _sprite_layer()
	_terrain = ColorRect.new()
	_terrain.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_terrain.position = Vector2(_origin)
	_terrain.size = Vector2(int(_map.w) * 16, int(_map.h) * 16)
	_material = TERRAIN.create(_theme)
	_material.set_shader_parameter("grid_size", Vector2i(_map.w, _map.h))
	_terrain.material = _material
	_viewport.add_child(_terrain)
	_front = _sprite_layer()
	texture = _viewport.get_texture()
	set_tick(tick)

func _sprite_layer() -> Sprite2D:
	var layer := Sprite2D.new()
	layer.centered = false
	var material := ShaderMaterial.new()
	material.shader = PALETTE_SHADER
	layer.material = material
	_viewport.add_child(layer)
	return layer

func _rebuild_map(is_dug: bool) -> void:
	var width: int = 4 if _kind == "rulecard" else ceili(float(_dimensions.x) / 16) + 1
	_floor_row = 1 if _kind == "rulecard" else floori(float(_dimensions.y - 12) / 16)
	var height: int = 2 if _kind == "rulecard" else _floor_row + 2
	_origin = Vector2i(-4, 0) if _kind == "rulecard" else Vector2i(0, _dimensions.y - 12 - _floor_row * 16)
	var cells: Array[int] = []
	for y: int in height:
		for x: int in width:
			cells.append(1 if y >= _floor_row else 3 if _kind == "rulecard" and y == 0 and x == 2 and not is_dug else 0)
	_map = {"w": width, "h": height, "terrain": cells}
	if _material != null:
		_upload_map()

func _upload_map() -> void:
	var bytes := PackedByteArray()
	bytes.resize(int(_map.w) * int(_map.h))
	for index: int in bytes.size():
		bytes[index] = int(_map.terrain[index])
	var image := Image.create_from_data(_map.w, _map.h, false, Image.FORMAT_R8, bytes)
	_material.set_shader_parameter("map_texture", ImageTexture.create_from_image(image))

func set_tick(tick: int) -> void:
	if _viewport == null or _theme.is_empty() or tick == _tick:
		return
	var next_dug: bool = _kind == "rulecard" and (tick / 60) % 2 == 1
	if _tick < 0 or next_dug != dug:
		dug = next_dug
		_rebuild_map(dug)
	_tick = tick
	_material.set_shader_parameter("visual_tick", tick >> 3)
	var background_key: int = tick >> 4 if _theme.background.style in ["sky", "cosmos"] else 0
	if background_key != _background_key:
		_background_key = background_key
		var raster = RASTER.new(_dimensions.x, _dimensions.y)
		BACKGROUND.draw(raster, _theme, Rect2i(Vector2i.ZERO, _dimensions), tick)
		_update_texture(_background, raster.image())
	if _kind == "rulecard":
		var animation: String = "idle" if dug else "dig"
		var frame: int = SPRITES.frame_at(Registry.art("art:char.portitor"), animation, tick)
		var key: int = frame + (100 if dug else 0)
		if key == _hero_key:
			return
		_hero_key = key
		var actor = RASTER.new(56, 32)
		SPRITES.blit(actor, "art:char.portitor", animation, tick, Vector2i(20, 16))
		_update_texture(_front, actor.image())
		return
	var occupied: Callable = func(x: int, y: int) -> bool: return _with_hero and y == _floor_row - 1 and (x == 1 or x == 2)
	var options: Dictionary = {"mode": "one", "seed": AMBIENT.seed_of(_theme_uid.trim_prefix("art:")), "has": SPRITES.has}
	var area := Rect2i(0, 0, _dimensions.x, _dimensions.y - 14)
	var back = RASTER.new(_dimensions.x, _dimensions.y)
	var front = RASTER.new(_dimensions.x, _dimensions.y)
	for command: Dictionary in AMBIENT.plan(_theme, _map, _origin, tick, "back", occupied, area, Callable(), options):
		SPRITES.blit(back, command.uid, command.anim, command.tick, Vector2i(command.x, command.y), command.flip)
	for command: Dictionary in AMBIENT.plan(_theme, _map, _origin, tick, "front", occupied, area, Callable(), options):
		SPRITES.blit(front, command.uid, command.anim, command.tick, Vector2i(command.x, command.y), command.flip)
	if _with_hero:
		SPRITES.blit(front, "art:char.portitor", "idle", tick, Vector2i(24, _origin.y + _floor_row * 16))
		SPRITES.blit(front, "art:obj.crate_wood", "default", 0, Vector2i(40, _origin.y + _floor_row * 16))
	_update_texture(_back, back.image())
	_update_texture(_front, front.image())

func _update_texture(layer: Sprite2D, image: Image) -> void:
	if layer.texture == null:
		layer.texture = ImageTexture.create_from_image(image)
	else:
		(layer.texture as ImageTexture).update(image)

func prepare_reference() -> void:
	if _viewport == null or not is_inside_tree() or DisplayServer.get_name() == "headless":
		return
	await get_tree().process_frame
	await RenderingServer.frame_post_draw
