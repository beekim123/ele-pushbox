class_name ApprovedSpriteAssets
extends RefCounted
## Shared sprite path for world and UI. All lookups go through uid + Registry.
const Palette = preload("res://presentation/render/palette_raster.gd")
static var _images: Dictionary = {}
static var _textures: Dictionary = {}
static var _metadata_cache: Dictionary = {}
static var _sparse_sheets: Dictionary = {}
static var _rgba_indices: Dictionary = {}

static func metadata(uid: String) -> Dictionary:
	if _metadata_cache.has(uid):
		return _metadata_cache[uid]
	var tree: SceneTree = Engine.get_main_loop() as SceneTree
	if tree == null or not tree.root.has_node("Registry"):
		return {}
	var entry: Dictionary = tree.root.get_node("Registry").art(uid)
	if not bool(entry.get("approved", false)):
		return {}
	_metadata_cache[uid] = entry
	return entry

static func has(uid: String) -> bool:
	return not metadata(uid).is_empty()

static func frame_at(asset: Dictionary, animation: Variant, tick: int) -> int:
	if animation is int or animation is float:
		return int(animation)
	var a: Dictionary = asset.get("animations", {}).get(str(animation), {})
	if a.is_empty() or a.get("frames", []).is_empty():
		return 0
	var frames: Array = a.frames
	if float(a.get("fps", 0)) == 0 or frames.size() == 1:
		return int(frames[0])
	var step: int = floori(float(tick) * float(a.fps) / 60)
	return int(frames[posmod(step, frames.size()) if bool(a.get("loop", false)) else mini(maxi(0, step), frames.size() - 1)])

static func texture(uid: String) -> Texture2D:
	if _textures.has(uid):
		return _textures[uid]
	var asset: Dictionary = metadata(uid)
	var path: String = asset.get("texture_path", "")
	if path.is_empty():
		return null
	var result: Texture2D = load(path) as Texture2D
	if result != null:
		_textures[uid] = result
	return result

static func _image(uid: String) -> Image:
	if not _images.has(uid):
		var sheet: Texture2D = texture(uid)
		if sheet == null:
			return null
		var image: Image = sheet.get_image()
		if image.is_compressed():
			image.decompress()
		image.convert(Image.FORMAT_RGBA8)
		_images[uid] = image
	return _images[uid]

static func _sparse_frame(uid: String, size: Vector2i, frame: int) -> Array[Vector3i]:
	if not _sparse_sheets.has(uid):
		if _rgba_indices.is_empty():
			for i: int in range(Palette.HEX.size()):
				_rgba_indices[Color.html(Palette.HEX[i]).to_rgba32()] = i
		var source: Image = _image(uid)
		var frames: Dictionary = {}
		# Decode the whole approved strip at first use, outside later pose/frame
		# changes. All animation frames then share the same sparse integer path.
		for index: int in range(source.get_width() / size.x):
			var points: Array[Vector3i] = []
			for y: int in range(size.y):
				for x: int in range(size.x):
					var color: Color = source.get_pixel(index * size.x + x, y)
					if color.a8 == 0:
						continue
					var code: int = _rgba_indices.get(color.to_rgba32(), -1)
					if code >= 0:
						points.append(Vector3i(x, y, code))
			frames[index] = points
		_sparse_sheets[uid] = frames
	return _sparse_sheets[uid][frame]

static func blit(raster: RefCounted, uid: String, animation: Variant, tick: int, anchor: Vector2i, flip: bool = false, visible_rows: int = -1) -> void:
	var asset: Dictionary = metadata(uid)
	if asset.is_empty():
		return
	var source: Image = _image(uid)
	if source == null:
		return
	var size: Vector2i = Vector2i(int(asset.size[0]), int(asset.size[1]))
	var pivot: Vector2i = Vector2i(size.x - int(asset.anchor[0]) if flip else int(asset.anchor[0]), int(asset.anchor[1]))
	var frame: int = frame_at(asset, animation, tick)
	if frame < 0 or (frame + 1) * size.x > source.get_width():
		push_error("Invalid animation frame for " + uid)
		return
	var points: Array[Vector3i] = _sparse_frame(uid, size, frame)
	if visible_rows >= 0 and visible_rows < size.y:
		var clipped: Array[Vector3i] = []
		for point: Vector3i in points:
			if point.y >= size.y - visible_rows: clipped.append(point)
		points = clipped
	raster.blit_sparse(points, anchor - pivot, size.x, flip)

static func command_phase(commands: Array[Dictionary]) -> Array:
	var phase: Array = []
	for command: Dictionary in commands:
		var asset: Dictionary = metadata(command.uid)
		if not asset.is_empty():
			phase.append([command.uid, frame_at(asset, command.anim, command.tick), command.x, command.y, command.flip])
	return phase

static func draw_asset(canvas: CanvasItem, uid: String, animation: Variant, tick: int, anchor: Vector2, flip: bool = false) -> void:
	# Invoke from the receiving CanvasItem's _draw(). No dimensions/anchors guessed.
	var asset: Dictionary = metadata(uid)
	var sheet: Texture2D = texture(uid)
	if asset.is_empty() or sheet == null:
		return
	var size: Vector2 = Vector2(float(asset.size[0]), float(asset.size[1]))
	var pivot: Vector2 = Vector2(size.x - float(asset.anchor[0]) if flip else float(asset.anchor[0]), float(asset.anchor[1]))
	var destination: Rect2 = Rect2(anchor.floor() - pivot, size)
	if flip:
		destination.position.x += size.x
		destination.size.x = -size.x
	canvas.draw_texture_rect_region(sheet, destination, Rect2(Vector2(frame_at(asset, animation, tick) * size.x, 0), size))
