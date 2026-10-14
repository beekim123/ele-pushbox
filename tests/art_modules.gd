extends SceneTree
const Style := preload("res://pushbox/scripts/ui/pixel_style.gd")
const Loader := preload("res://pushbox/scripts/level_loader.gd")
var checks: int = 0
var failures: int = 0

func check(value: bool, message: String) -> void:
	checks += 1
	if not value:
		failures += 1
		print("FAIL " + message)

func _initialize() -> void:
	if not FileAccess.file_exists("res://pushbox/scripts/art/art_registry.gd"):
		check(false, "modular art registry exists")
		finish()
		return
	var registry: GDScript = load("res://pushbox/scripts/art/art_registry.gd")
	var style: GDScript = load("res://pushbox/scripts/ui/pixel_style.gd")
	Style.warm_assets()
	check(registry.get("_themed_textures").is_empty(), "warming baseline does not generate themes")
	var fixtures: Dictionary = Loader.json("res://tests/fixtures/art_rgba_v03.json")
	var held: Dictionary = {}
	for name in fixtures:
		held[name] = Style.texture(name)
	for id in ["dungeon", "forest", "ruins", "cave", "sky_island", "cosmos"]:
		var texture: Texture2D = style.call("themed_texture", "crate_static_0", id)
		check(texture == style.call("themed_texture", "crate_static_0", id), id + " theme cache identity")
		check(texture.get_size() == Vector2(16,16), id + " crate size")
		if id != "dungeon":
			check(texture != held.crate_static_0, id + " independent variant")
			var bg: Texture2D = registry.call("background", id, Vector2i(320,180))
			check(bg == registry.call("background", id, Vector2i(320,180)), id + " background cache")
			var crop: Image = bg.get_image().get_region(Rect2i(80,48,160,80))
			var colors: Dictionary = {}
			for y in range(0,80,2):
				for x in range(0,160,2):
					colors[crop.get_pixel(x,y).to_html()] = true
			check(colors.size() >= 3, id + " cropped background retains multiple visual anchors")
	check(style.call("themed_texture", "crate_static_0", "unknown") == held.crate_static_0, "unknown theme falls back to baseline reference")
	check(style.call("themed_texture", "panel_9slice", "forest") == held.panel_9slice, "UI fallback uses baseline reference")
	check(style.call("themed_texture", "crate_iron_0", "cosmos").get_size() == Vector2(16,16), "iron crate exists")
	for name in fixtures:
		var texture: Texture2D = Style.texture(name)
		check(texture == held[name], name + " baseline survives themed generation")
		var digest := HashingContext.new()
		digest.start(HashingContext.HASH_SHA256)
		digest.update(texture.get_image().get_data())
		check(digest.finish().hex_encode() == fixtures[name].sha256, name + " baseline remains byte exact")
	finish()

func finish() -> void:
	print("Art modules: %d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)
