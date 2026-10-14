extends SceneTree
const Style := preload("res://pushbox/scripts/ui/pixel_style.gd")
const Loader := preload("res://pushbox/scripts/level_loader.gd")
var failures: int = 0
var checks: int = 0

func check(value: bool, message: String) -> void:
	checks += 1
	if not value:
		failures += 1
		print("FAIL " + message)

func _initialize() -> void:
	Style.warm_assets()
	var fixtures: Dictionary = Loader.json("res://tests/fixtures/art_rgba_v03.json")
	for name in fixtures:
		var texture: Texture2D = Style.texture(name)
		var image: Image = texture.get_image()
		check(image.get_size() == Vector2i(fixtures[name].size[0], fixtures[name].size[1]), name + " exact canvas")
		var digest := HashingContext.new()
		digest.start(HashingContext.HASH_SHA256)
		digest.update(image.get_data())
		check(digest.finish().hex_encode() == fixtures[name].sha256, name + " exact RGBA pixels")
		check(Style.texture(name) == texture, name + " cached in memory")
	var source: String = FileAccess.get_file_as_string("res://pushbox/scripts/ui/pixel_style.gd")
	check(not source.contains(".png") and not source.contains("Image.load_from_file"), "Style has no PNG loader")
	var shader: String = FileAccess.get_file_as_string("res://pushbox/scripts/render/world.gdshader")
	check(not shader.contains("bedrock_tex") and not shader.contains("cracked_tex"), "terrain has no external samplers")
	print("Procedural art: %d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)
