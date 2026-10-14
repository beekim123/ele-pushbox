extends RefCounted
## Dual-track cached facade. Theme generation never mutates baseline images.
const Ops := preload("res://pushbox/scripts/art/canvas_ops.gd")
const Palette := preload("res://pushbox/scripts/art/palette.gd")
const Miner := preload("res://pushbox/scripts/art/sprites/actors/miner_art.gd")
const Hazards := preload("res://pushbox/scripts/art/sprites/actors/hazards_art.gd")
const Crates := preload("res://pushbox/scripts/art/sprites/props/crates_art.gd")
const Mechanisms := preload("res://pushbox/scripts/art/sprites/props/mechanisms_art.gd")
const Gimmicks := preload("res://pushbox/scripts/art/sprites/props/biome_gimmicks_art.gd")
const Ambient := preload("res://pushbox/scripts/art/sprites/props/ambient_art.gd")
const Fx := preload("res://pushbox/scripts/art/sprites/fx/particles_art.gd")
const Icons := preload("res://pushbox/scripts/art/sprites/ui/hud_icons_art.gd")
const Prompts := preload("res://pushbox/scripts/art/sprites/ui/prompts_art.gd")
const MODULES := [Miner,Crates,Mechanisms,Ambient,Icons,Prompts]
const THEMES := {
	"dungeon": preload("res://pushbox/scripts/art/themes/theme_dungeon.gd"),
	"forest": preload("res://pushbox/scripts/art/themes/theme_forest.gd"),
	"ruins": preload("res://pushbox/scripts/art/themes/theme_ruins.gd"),
	"cave": preload("res://pushbox/scripts/art/themes/theme_cave.gd"),
	"sky_island": preload("res://pushbox/scripts/art/themes/theme_sky_island.gd"),
	"cosmos": preload("res://pushbox/scripts/art/themes/theme_cosmos.gd")
}
static var _base_textures: Dictionary = {}
static var _themed_textures: Dictionary = {}
static var _backgrounds: Dictionary = {}
static var _specs: Dictionary = {}

static func names() -> Array:
	var result: Array = ["cave_bg"]
	for module in MODULES:
		result.append_array(module.NAMES.keys())
	return result

static func image(name: String) -> Image:
	if name == "cave_bg":
		return THEMES.dungeon.baseline_background()
	for module in MODULES:
		if module.NAMES.has(name):
			return Ops.compile(module.PIXELS[module.NAMES[name]])
	var extra: Image = _exclusive(name,"dungeon")
	if extra != null:
		return extra
	push_error("Unknown procedural sprite: " + name)
	return Ops.canvas(Vector2i.ONE)

static func texture(name: String) -> Texture2D:
	if not _base_textures.has(name):
		_base_textures[name] = ImageTexture.create_from_image(image(name))
	return _base_textures[name]

static func theme(id: String) -> Dictionary:
	var key: String = id if THEMES.has(id) else "dungeon"
	if not _specs.has(key):
		_specs[key] = THEMES[key].spec()
	return _specs[key]

static func themed_texture(name: String, id: String) -> Texture2D:
	if not THEMES.has(id) or (id == "dungeon" and not name.begins_with("lantern_idle_")):
		return texture(name)
	if name == "cave_bg":
		return background(id,Vector2i(320,180))
	if not _themed_textures.has(id):
		_themed_textures[id] = {}
	if not _themed_textures[id].has(name):
		var generated: Image = _exclusive(name,id)
		if generated == null:
			if name.begins_with("miner_") or Mechanisms.NAMES.has(name) or Crates.NAMES.has(name):
				generated = Palette.swap(texture(name).get_image(),theme(id).remap)
				if name == "crate_static_0":
					generated = Crates.decorate_wood(generated,theme(id).index)
			else:
				_themed_textures[id][name] = texture(name)
				return _themed_textures[id][name]
		_themed_textures[id][name] = ImageTexture.create_from_image(generated)
	return _themed_textures[id][name]

static func _exclusive(name: String, id: String) -> Image:
	var spec: Dictionary = theme(id)
	if name == "crate_iron_0":
		return Crates.iron(spec.index)
	if name.begins_with("lantern_idle_"):
		return Ambient.themed_lamp(spec.index,spec.colors.accent,int(name.get_slice("_",2)))
	var result: Image = Hazards.image(name)
	if result == null:
		result = Gimmicks.image(name,spec.colors.accent)
	if result == null:
		result = Fx.image(name,spec.colors.accent)
	return result

static func background(id: String, size: Vector2i) -> Texture2D:
	var key: String = "%s:%dx%d" % [id,size.x,size.y]
	if not _backgrounds.has(key):
		var result: Image
		var module: GDScript = THEMES.get(id,THEMES.dungeon)
		result = module.background(size)
		_backgrounds[key] = ImageTexture.create_from_image(result)
	return _backgrounds[key]
