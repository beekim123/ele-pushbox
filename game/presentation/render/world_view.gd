class_name WorldView
extends Node2D
## 320x180 composition from scene.js. The SDK supplies every moving cell; the
## tile model is used only for rule markers and stable decoration placement.
const Raster = preload("res://presentation/render/palette_raster.gd")
const Background = preload("res://presentation/render/themes/background.gd")
const Ambient = preload("res://presentation/render/ambient/ambient.gd")
const EnvEffects = preload("res://presentation/render/env/environment.gd")
const Sprites = preload("res://presentation/render/sprites/sprite_assets.gd")
const Terrain = preload("res://presentation/render/terrain/terrain_material.gd")
const PALETTE_SHADER: Shader = preload("res://presentation/render/sprites/palette.gdshader")
const VIEW_SIZE: Vector2i = Vector2i(320, 180)
const HUD_HEIGHT: int = 20
const LIGHTING_CACHE_LIMIT: int = 16
const LAYER_CACHE_LIMIT: int = 8
const THEME_UIDS: Dictionary = {"dungeon": "art:theme.dungeon", "ruins": "art:theme.ruins", "cave": "art:theme.cave", "forest": "art:theme.forest", "sky": "art:theme.sky", "cosmos": "art:theme.cosmos"}
var environment_mode: String = "full"
var background_dim_steps: int = 0
var show_grid: bool = false
var observe: bool = false
var pose: String = "idle"
var facing_left: bool = false
var fixed_tick: int = -1
var ambient_mode: String = "" # Empty chooses sparse in play, one in menus; full is review only.
var target: Dictionary = {}
var last_limitation: String = ""
var last_refresh_us: int = 0
var max_refresh_us: int = 0
var last_refresh_stages: Dictionary = {}
var theme_uid: String = "art:theme.dungeon"
var session: Variant = null
var _theme: Dictionary = {}
var _opening: Dictionary = {}
var _spec: Dictionary = {}
var _origin: Vector2i = Vector2i.ZERO
var _elapsed: float = 0
var _backdrop: bool = true
var _lobby_scene: bool = true
var _back: Sprite2D
var _front: Sprite2D
var _plants_front: Sprite2D
var _terrain: ColorRect
var _terrain_material: ShaderMaterial
var _base_raster: RefCounted
var _static_background: RefCounted
var _base_key: String = ""
var _map_texture: ImageTexture
var _last_frame_key: String = ""
var _lighting_cache: Dictionary = {}
var _plants_cache: Dictionary = {}
var _entities_cache: Dictionary = {}
var _ambient_candidates: Dictionary = {}
var _blocked_started_tick: int = -1
var _back_upload_key: String = ""
var _plants_upload_key: String = ""
var _front_upload_key: String = ""

func _ready() -> void:
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_ensure_layers()
	if _theme.is_empty():
		set_backdrop(theme_uid)
	refresh()

func _process(delta: float) -> void:
	_elapsed += delta * 60
	refresh()

func set_session(value: Variant) -> void:
	if value != null and value == session and not _backdrop:
		# HUD refreshes rebind the current owner after every action. Decoration
		# candidates and animation time belong to the opening, not this state.
		refresh()
		return
	session = value
	_backdrop = value == null
	_elapsed = 0
	_blocked_started_tick = -1
	_last_frame_key = ""
	_clear_render_caches()
	if value != null:
		_spec = value.spec.duplicate(true)
		_opening = _parse_opening(_spec)
		# The starting state may include SDK settlement; use its rule classes.
		var state: Dictionary = value.state()
		if not state.is_empty():
			_opening.terrain = state.terrain.duplicate()
			_opening.crates = state.crates.duplicate(true)
			_opening.player = state.player.duplicate(true)
		set_theme_uid(THEME_UIDS.get(str(_spec.get("chapter", "dungeon")), "art:theme.dungeon"))
	refresh()

func set_theme_uid(uid: String) -> void:
	var asset: Dictionary = Sprites.metadata(uid)
	if asset.is_empty() or asset.get("params", {}).is_empty():
		last_limitation = "Unapproved or missing theme: " + uid
		push_error(last_limitation)
		return
	theme_uid = uid
	_theme = asset.params
	_terrain_material = Terrain.create(_theme)
	_base_key = ""
	_static_background = null
	_last_frame_key = ""
	_clear_render_caches()
	_ensure_layers()
	_terrain.material = _terrain_material
	refresh()

func set_backdrop(uid: String, lobby_scene: bool = true) -> void:
	session = null
	_backdrop = true
	_lobby_scene = lobby_scene
	_blocked_started_tick = -1
	_clear_render_caches()
	_spec = {"map": [], "chapter": uid.get_slice(":", 1).trim_prefix("theme."), "bag": {}, "devices": []}
	var rows: Array[String] = []
	for y: int in range(11):
		var row: String = ""
		for x: int in range(21):
			row += "#" if y >= 9 or (lobby_scene and (x == 18 or x == 19) and (y == 7 or y == 8)) else "."
		rows.append(row)
	_spec.map = rows
	_opening = _parse_opening(_spec)
	_origin = Vector2i(0, 12)
	_map_texture = _grid_texture(_opening)
	set_theme_uid(uid)

func blocked_feedback() -> void:
	# Pure presentation: two integer offset frames at 8fps, then rest at tick15.
	# The session, terrain and every other sprite keep their current positions.
	_blocked_started_tick = fixed_tick if fixed_tick >= 0 else floori(_elapsed)
	_last_frame_key = ""
	refresh()

func _blocked_actor_offset(tick: int) -> int:
	var elapsed: int = tick - _blocked_started_tick
	if _blocked_started_tick < 0 or elapsed < 0 or elapsed >= 15:
		return 0
	return -1 if floori(float(elapsed) * 8.0 / 60.0) == 0 else 1

func refresh() -> void:
	if _theme.is_empty() or not is_inside_tree():
		return
	var started_us: int = Time.get_ticks_usec()
	_ensure_layers()
	var tick: int = fixed_tick if fixed_tick >= 0 else floori(_elapsed)
	var state: Dictionary = _opening if _backdrop else session.state()
	if state.is_empty():
		return
	var w: int = int(state.get("w", _opening.w))
	var h: int = int(state.get("h", _opening.h))
	_origin = Vector2i(0, 12) if _backdrop else Vector2i((320 - w * 16) >> 1, 20 + ((160 - h * 16) >> 1))
	var key: String = "%s|%d|%s|%d|%s|%s|%s|%s|%s|%s|%s|%d" % [theme_uid, tick, environment_mode, background_dim_steps, show_grid, observe, pose, facing_left, ambient_mode, target, state, _blocked_actor_offset(tick)]
	if key == _last_frame_key:
		# SDK cell shapes/variants may change without crossing a tile-class
		# threshold or a visual tick boundary. CPU-layer reuse must never stop
		# the real render texture refresh, including repeated HUD rebinds.
		_bind_materials(state)
		last_refresh_us = Time.get_ticks_usec() - started_us
		last_refresh_stages = {"cached": last_refresh_us}
		return
	_last_frame_key = key
	var measured_us: int = Time.get_ticks_usec()
	last_refresh_stages = {"state_and_key": measured_us - started_us}
	var area: Rect2i = Rect2i(0, 0, 320, 150) if _backdrop else Rect2i(_origin + Vector2i(16, 16), Vector2i(maxi(32, (w - 2) * 16), maxi(32, (h - 2) * 16)))
	var occupied: Callable = _occupied_opening
	var alive: Callable = Callable() if _backdrop else _alive.bind(state)
	var lights: Array[Dictionary] = []
	var opts: Dictionary = {"mode": ambient_mode if not ambient_mode.is_empty() else "one" if _backdrop else "sparse", "seed": Ambient.seed_of(theme_uid.trim_prefix("art:")) if _backdrop else Ambient.seed_of(str(_spec.get("id", ""))), "out": lights, "has": Sprites.has, "candidate_cache": _ambient_candidates}
	var back_commands: Array[Dictionary] = Ambient.plan(_theme, _opening, _origin, tick, "back", occupied, area, alive, opts)
	var front_commands: Array[Dictionary] = Ambient.plan(_theme, _opening, _origin, tick, "front", occupied, area, alive, opts)
	last_refresh_stages.ambient_plan = Time.get_ticks_usec() - measured_us
	measured_us = Time.get_ticks_usec()
	var env_area: Rect2i = Rect2i(0, 20, 320, 136) if _backdrop else Rect2i(_origin, Vector2i(w * 16, h * 16))
	var ctx: Dictionary = {"tick": tick, "area": env_area, "lights": lights, "weather": _spec.get("weather"), "level": "lite" if environment_mode == "lights" else environment_mode}
	var background_tick: int = tick >> 4 if _theme.background.style in ["sky", "cosmos"] else 0
	var base_key: String = "%s:%d" % [theme_uid, background_tick]
	if _static_background == null:
		_static_background = Raster.new(320, 180)
		Background.draw_static(_static_background, _theme, Rect2i(Vector2i.ZERO, VIEW_SIZE))
	if base_key != _base_key:
		_base_raster = _static_background.copy()
		Background.draw_dynamic(_base_raster, _theme, Rect2i(Vector2i.ZERO, VIEW_SIZE), tick)
		_base_key = base_key
	var lighting_key: String = str([base_key, environment_mode, EnvEffects.lighting_phase(_theme, ctx)])
	var quiet: bool = EnvEffects.quiet_weather(_theme, ctx)
	var world_area: Rect2i = Rect2i(_origin, Vector2i(w * 16, h * 16))
	var observing: bool = observe and not _backdrop
	var back_key: String = str([lighting_key, Sprites.command_phase(back_commands), observing, world_area])
	var back_raster: RefCounted = null
	if not quiet or back_key != _back_upload_key:
		if not _lighting_cache.has(lighting_key):
			var lit: RefCounted = _base_raster.copy()
			EnvEffects.draw_background_light(lit, _theme, ctx)
			_cache_layer(_lighting_cache, lighting_key, lit, LIGHTING_CACHE_LIMIT)
		back_raster = _lighting_cache[lighting_key].copy()
		if not quiet:
			EnvEffects.draw_weather_back(back_raster, _theme, ctx)
		_blit_commands(back_raster, back_commands)
	last_refresh_stages.background_environment = Time.get_ticks_usec() - measured_us
	measured_us = Time.get_ticks_usec()
	var plants_key: String = str(Sprites.command_phase(front_commands))
	var plants_final_key: String = str([plants_key, observing, world_area])
	var plants_raster: RefCounted = null
	if not quiet or plants_final_key != _plants_upload_key:
		if not _plants_cache.has(plants_key):
			var plants: RefCounted = Raster.new(320, 180)
			_blit_commands(plants, front_commands)
			_cache_layer(_plants_cache, plants_key, plants, LAYER_CACHE_LIMIT)
		plants_raster = _plants_cache[plants_key].copy()
	var entities_key: String = _entity_phase(state, tick)
	var front_final_key: String = str([entities_key, target, observing, show_grid, world_area, state.get("terrain") if observing else null])
	var front_raster: RefCounted = null
	if not quiet or front_final_key != _front_upload_key:
		if not _entities_cache.has(entities_key):
			var entities: RefCounted = Raster.new(320, 180)
			if _backdrop:
				if _lobby_scene:
					_draw_lobby_entities(entities, tick)
			else:
				_draw_entities(entities, state, tick)
			_cache_layer(_entities_cache, entities_key, entities, LAYER_CACHE_LIMIT)
		front_raster = _entities_cache[entities_key].copy()
		if not quiet:
			EnvEffects.draw(front_raster, _theme, "front", ctx)
		if not _backdrop:
			_draw_targets(front_raster)
	if observing:
		if back_raster != null:
			back_raster.remap(world_area, Raster.DIM_MAP)
		if plants_raster != null:
			plants_raster.remap(world_area, Raster.DIM_MAP)
		if front_raster != null:
			front_raster.remap(world_area, Raster.DIM_MAP)
			_draw_observe(front_raster, state)
	if front_raster != null and not _backdrop and (show_grid or observe):
		_draw_grid(front_raster, w, h)
	last_refresh_stages.foreground_entities = Time.get_ticks_usec() - measured_us
	measured_us = Time.get_ticks_usec()
	if back_raster != null:
		_update_texture(_back, back_raster.image())
	if plants_raster != null:
		_update_texture(_plants_front, plants_raster.image())
	if front_raster != null:
		_update_texture(_front, front_raster.image())
	_back_upload_key = back_key if quiet else ""
	_plants_upload_key = plants_final_key if quiet else ""
	_front_upload_key = front_final_key if quiet else ""
	var vignette: int = int(_theme.get("env", {}).get("vignette", 0)) if environment_mode != "off" else 0
	(_back.material as ShaderMaterial).set_shader_parameter("vignette_width", vignette)
	(_plants_front.material as ShaderMaterial).set_shader_parameter("vignette_width", vignette)
	for sprite: Sprite2D in [_back, _plants_front, _front]:
		(sprite.material as ShaderMaterial).set_shader_parameter("background_dim_steps", maxi(0, background_dim_steps))
	last_refresh_stages.texture_upload = Time.get_ticks_usec() - measured_us
	measured_us = Time.get_ticks_usec()
	_terrain.position = _origin
	_terrain.size = Vector2(w * 16, h * 16)
	_terrain_material.set_shader_parameter("grid_size", Vector2i(w, h))
	_terrain_material.set_shader_parameter("visual_tick", tick >> 3)
	_terrain_material.set_shader_parameter("screen_origin", _origin)
	_terrain_material.set_shader_parameter("vignette_width", vignette)
	_terrain_material.set_shader_parameter("observe", observe and not _backdrop)
	_terrain_material.set_shader_parameter("background_dim_steps", maxi(0, background_dim_steps))
	_bind_materials(state)
	last_refresh_stages.terrain_binding = Time.get_ticks_usec() - measured_us
	last_refresh_us = Time.get_ticks_usec() - started_us
	max_refresh_us = maxi(max_refresh_us, last_refresh_us)

func _clear_render_caches() -> void:
	# state() does not contain the opening marker/group/symbol layout.
	# New owners and menu layouts therefore invalidate all dependent layers.
	_lighting_cache.clear()
	_plants_cache.clear()
	_entities_cache.clear()
	_ambient_candidates.clear()
	_back_upload_key = ""
	_plants_upload_key = ""
	_front_upload_key = ""

static func _cache_layer(cache: Dictionary, key: String, raster: RefCounted, limit: int) -> void:
	if cache.size() >= limit:
		cache.erase(cache.keys()[0])
	cache[key] = raster

func _entity_phase(state: Dictionary, tick: int) -> String:
	var actor_pose: String = "push" if _backdrop else "win" if state.get("won", false) else pose
	var frames: Array[int] = []
	for pair: Array in [["art:char.portitor", actor_pose], ["art:mech.socket", "idle"], ["art:mech.exit_flag", "idle"], ["art:mech.socket_lit", "lit"]]:
		frames.append(Sprites.frame_at(Sprites.metadata(pair[0]), pair[1], tick))
	return str([_backdrop, _lobby_scene, _origin, state.get("player"), state.get("crates"), state.get("doors"), state.get("won", false), facing_left, frames, _blocked_actor_offset(tick)])

func _draw_targets(raster: RefCounted) -> void:
	if target.is_empty():
		return
	var cells: Array = target.get("cells", [target])
	for cell: Dictionary in cells:
		Sprites.blit(raster, "art:ui.target", cell.get("kind", target.get("kind", "push")), 0, _anchor(int(cell.x), int(cell.y)))

func _bind_materials(state: Dictionary) -> void:
	if _backdrop:
		_terrain_material.set_shader_parameter("sdk_mode", false)
		_terrain_material.set_shader_parameter("map_texture", _map_texture)
		return
	var world: Variant = session.world
	if world == null or not world.is_started():
		last_limitation = "No real SDK cells available; moving materials are not drawn."
		# Static geometry remains visible. This does not stand in for SDK sand.
		var fallback: Dictionary = state.duplicate(true)
		for i: int in range(fallback.terrain.size()):
			if int(fallback.terrain[i]) >= 4:
				fallback.terrain[i] = 0
		_map_texture = _grid_texture(fallback)
		_terrain_material.set_shader_parameter("sdk_mode", false)
		_terrain_material.set_shader_parameter("map_texture", _map_texture)
		return
	last_limitation = ""
	_terrain_material.set_shader_parameter("sdk_mode", true)
	var ids: Dictionary = world.material_ids
	for pair: Array in [["rock_id", "bedrock"], ["cracked_id", "cracked_rock"], ["earth_id", "packed_earth"], ["sand_id", "sand"], ["water_id", "water"]]:
		_terrain_material.set_shader_parameter(pair[0], int(ids.get(pair[1], -1)))
	var tiles: Array = world.get_render_tiles()
	if tiles.is_empty():
		var actual: Image = world.render_material_image()
		_map_texture = ImageTexture.create_from_image(actual)
		_terrain_material.set_shader_parameter("cell_image_mode", true)
		_terrain_material.set_shader_parameter("map_texture", _map_texture)
		last_limitation = "SDK render tiles unavailable; actual material IDs are shown with variant zero."
	else:
		_terrain_material.set_shader_parameter("cell_image_mode", false)
		for tile: Dictionary in tiles:
			var right: bool = int(tile.rect.position.x) >= 256
			_terrain_material.set_shader_parameter("sdk_right" if right else "sdk_left", tile.texture)
			_terrain_material.set_shader_parameter("right_origin" if right else "left_origin", tile.rect.position)

func _ensure_layers() -> void:
	if _back != null:
		return
	_back = Sprite2D.new()
	_back.centered = false
	_back.material = _palette_material()
	add_child(_back)
	_terrain = ColorRect.new()
	_terrain.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_terrain)
	_plants_front = Sprite2D.new()
	_plants_front.centered = false
	_plants_front.material = _palette_material()
	add_child(_plants_front)
	_front = Sprite2D.new()
	_front.centered = false
	_front.material = _palette_material()
	add_child(_front)
	if _terrain_material != null:
		_terrain.material = _terrain_material

static func _update_texture(sprite: Sprite2D, image: Image) -> void:
	if sprite.texture == null:
		sprite.texture = ImageTexture.create_from_image(image)
	else:
		(sprite.texture as ImageTexture).update(image)

static func _palette_material() -> ShaderMaterial:
	var material: ShaderMaterial = ShaderMaterial.new()
	material.shader = PALETTE_SHADER
	return material

static func draw_asset(canvas: CanvasItem, uid: String, animation: Variant, tick: int, anchor: Vector2, flip: bool = false) -> void:
	Sprites.draw_asset(canvas, uid, animation, tick, anchor, flip)

static func _blit_commands(raster: RefCounted, commands: Array[Dictionary]) -> void:
	for command: Dictionary in commands:
		Sprites.blit(raster, command.uid, command.anim, command.tick, Vector2i(command.x, command.y), command.flip)

func _draw_lobby_entities(raster: RefCounted, tick: int) -> void:
	for position: Vector2i in [Vector2i(232, 156), Vector2i(248, 156), Vector2i(248, 140)]:
		Sprites.blit(raster, "art:obj.crate_wood", "default", 0, position)
	Sprites.blit(raster, "art:char.portitor", "push", tick, Vector2i(216 + _blocked_actor_offset(tick), 156))
	Sprites.blit(raster, "art:mech.exit_flag", "idle", tick, Vector2i(300, 124))

func _draw_entities(raster: RefCounted, state: Dictionary, tick: int) -> void:
	var w: int = _opening.w
	for i: int in range(_opening.markers.size()):
		var marker: int = _opening.markers[i]
		if marker == 0:
			continue
		var p: Vector2i = _anchor(i % w, i / w)
		var crate: bool = _crate_at(state, i % w, i / w)
		match marker:
			1: Sprites.blit(raster, "art:mech.ladder", "default", 0, p)
			2:
				if not crate:
					Sprites.blit(raster, "art:mech.socket", "idle", tick, p)
			3: Sprites.blit(raster, "art:mech.exit_flag", "idle", tick, p)
			4:
				var pressed: bool = crate or (int(state.player.x) == i % w and int(state.player.y) == i / w)
				Sprites.blit(raster, "art:mech.plate", "down" if pressed else "up", 0, p)
				if not pressed:
					Sprites.blit(raster, "art:mech.link_symbol", _symbol(i), 0, p - Vector2i(0, 7))
	for group_index: int in range(_opening.groups.size()):
		var group: Dictionary = _opening.groups[group_index]
		var opened: bool = bool(state.doors[group_index]) if group_index < state.get("doors", []).size() else false
		for i: int in group.doors:
			var p: Vector2i = _anchor(i % w, i / w)
			Sprites.blit(raster, "art:mech.door", "open" if opened else "closed", 0, p)
			Sprites.blit(raster, "art:mech.link_symbol", _symbol(i), 0, p - Vector2i(0, 12))
	for crate: Dictionary in state.crates:
		var p: Vector2i = _anchor(crate.x, crate.y)
		Sprites.blit(raster, "art:obj.crate_iron" if crate.kind == "iron" else "art:obj.crate_wood", "default", 0, p)
		if int(_opening.markers[int(crate.y) * w + int(crate.x)]) == 2:
			Sprites.blit(raster, "art:mech.socket_lit", "lit", tick, p)
	Sprites.blit(raster, "art:char.portitor", "win" if state.get("won", false) else pose, tick, _anchor(state.player.x, state.player.y) + Vector2i(_blocked_actor_offset(tick), 0), facing_left)

func _anchor(x: int, y: int) -> Vector2i:
	return _origin + Vector2i(x * 16 + 8, y * 16 + 16)

func _symbol(index: int) -> Variant:
	for group: Dictionary in _opening.groups:
		if index in group.plates or index in group.doors:
			return group.get("symbol", 0)
	return 0

func _occupied_opening(x: int, y: int) -> bool:
	if _backdrop:
		return _lobby_scene and ((y == 8 and x >= 12 and x <= 15) or (y == 7 and x == 15) or (y == 6 and (x == 18 or x == 19)))
	var index: int = y * int(_opening.w) + x
	if int(_opening.markers[index]) != 0 or _crate_at(_opening, x, y):
		return true
	if not _opening.player.is_empty() and int(_opening.player.x) == x and int(_opening.player.y) == y:
		return true
	for group: Dictionary in _opening.groups:
		if index in group.doors:
			return true
	for device: Dictionary in _spec.get("devices", []):
		if device.get("at", []) == [x, y] or device.get("button", []) == [x, y]:
			return true
	return false

func _alive(x: int, y: int, state: Dictionary) -> bool:
	return Ambient.at(state, x, y) == 0 and not _crate_at(state, x, y) and (Ambient.at(state, x, y + 1) != 0 or Ambient.at(state, x, y - 1) != 0)

static func _crate_at(state: Dictionary, x: int, y: int) -> bool:
	for crate: Dictionary in state.crates:
		if int(crate.x) == x and int(crate.y) == y:
			return true
	return false

static func _grid_texture(state: Dictionary) -> ImageTexture:
	var data: PackedByteArray = PackedByteArray()
	data.resize(int(state.w) * int(state.h))
	for i: int in range(data.size()):
		data[i] = int(state.terrain[i])
	return ImageTexture.create_from_image(Image.create_from_data(state.w, state.h, false, Image.FORMAT_R8, data))

static func _parse_opening(spec: Dictionary) -> Dictionary:
	var rows: Array = spec.map
	var width: int = str(rows[0]).length()
	var result: Dictionary = {"w": width, "h": rows.size(), "terrain": [], "markers": [], "crates": [], "player": {}, "groups": [], "doors": [], "bag": {}, "won": false}
	var doors: Array[int] = []
	var plates: Array[int] = []
	for y: int in range(rows.size()):
		for x: int in range(width):
			var c: String = str(rows[y]).substr(x, 1)
			var material: int = {"#": 1, "%": 2, "e": 3, "s": 4, "~": 5}.get(c, 0)
			var marker: int = {"H": 1, "h": 1, "o": 2, "b": 2, "X": 3, "_": 4}.get(c, 0)
			result.terrain.append(material)
			result.markers.append(marker)
			if c in ["B", "I", "b"]:
				result.crates.append({"x": x, "y": y, "kind": "iron" if c == "I" else "wood"})
			if c in ["P", "h"]:
				result.player = {"x": x, "y": y}
			if c == "|":
				doors.append(y * width + x)
			if c == "_":
				plates.append(y * width + x)
	if spec.has("links"):
		for index: int in range(spec.links.size()):
			var link: Dictionary = spec.links[index]
			var group: Dictionary = {"plates": [], "doors": [], "symbol": link.get("symbol", ["circle", "triangle", "square"][index % 3])}
			for p: Array in link.get("plates", []):
				var i: int = int(p[1]) * width + int(p[0])
				group.plates.append(i)
				result.markers[i] = 4
			for p: Array in link.get("doors", []):
				group.doors.append(int(p[1]) * width + int(p[0]))
			result.groups.append(group)
	else:
		result.groups.append({"plates": plates, "doors": doors})
	return result

func _draw_grid(raster: RefCounted, width: int, height: int) -> void:
	for y: int in range(height + 1):
		for x: int in range(0, width * 16, 2):
			raster.set_code(_origin.x + x, _origin.y + y * 16 - (1 if y == height else 0), "v")
	for x: int in range(width + 1):
		for y: int in range(0, height * 16, 2):
			raster.set_code(_origin.x + x * 16 - (1 if x == width else 0), _origin.y + y, "v")

func _draw_observe(raster: RefCounted, state: Dictionary) -> void:
	var w: int = _opening.w
	for i: int in range(state.terrain.size()):
		var icon: String = {1: "solid", 2: "solid", 3: "earth", 4: "sand", 5: "water"}.get(int(state.terrain[i]), "")
		for group_index: int in range(_opening.groups.size()):
			if i in _opening.groups[group_index].doors and not bool(state.doors[group_index]):
				icon = "solid"
		if not icon.is_empty():
			Sprites.blit(raster, "art:ui.class_icon", icon, 0, _anchor(i % w, i / w) - Vector2i(0, 8))
	for group: Dictionary in _opening.groups:
		for plate: int in group.plates:
			for door: int in group.doors:
				var a: Vector2i = _anchor(plate % w, plate / w) - Vector2i(0, 4)
				var b: Vector2i = _anchor(door % w, door / w) - Vector2i(0, 8)
				var count: int = maxi(absi(a.x - b.x), absi(a.y - b.y))
				for k: int in range(0, count + 1, 2):
					var p: Vector2 = Vector2(a).lerp(Vector2(b), float(k) / maxi(1, count))
					raster.set_code(floori(p.x + 0.5), floori(p.y + 0.5), "s")

func render_texture(uid: String, tick: int = 0) -> Texture2D:
	## Async GPU thumbnail; call with await. Uses the same shader, never a ref PNG.
	if DisplayServer.get_name() == "headless":
		return null
	var viewport: SubViewport = SubViewport.new()
	viewport.size = VIEW_SIZE
	viewport.transparent_bg = true
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	viewport.canvas_item_default_texture_filter = Viewport.DEFAULT_CANVAS_ITEM_TEXTURE_FILTER_NEAREST
	get_tree().root.add_child(viewport)
	var view: Node2D = get_script().new()
	view.fixed_tick = tick
	view.set_backdrop(uid, false)
	viewport.add_child(view)
	await get_tree().process_frame
	await RenderingServer.frame_post_draw
	var result: ImageTexture = ImageTexture.create_from_image(viewport.get_texture().get_image())
	viewport.queue_free()
	return result

func render_thumbnail(uid: String, size: Vector2i, tick: int = 0, with_hero: bool = true) -> Texture2D:
	## Exact ui.js mapThumb geometry at the requested native card resolution.
	## The thumbnail is an illustration and intentionally has no weather/light.
	if DisplayServer.get_name() == "headless" or size.x <= 0 or size.y <= 12:
		return null
	var asset: Dictionary = Sprites.metadata(uid)
	if asset.is_empty():
		return null
	var theme: Dictionary = asset.params
	var cols: int = ceili(float(size.x) / 16) + 1
	var floor_row: int = floori(float(size.y - 12) / 16)
	var oy: int = size.y - 12 - floor_row * 16
	var map: Dictionary = {"w": cols, "h": floor_row + 2, "terrain": []}
	for y: int in range(map.h):
		for _x: int in range(cols):
			map.terrain.append(1 if y >= floor_row else 0)
	var busy: Callable = func(x: int, y: int) -> bool: return with_hero and y == floor_row - 1 and (x == 1 or x == 2)
	var options: Dictionary = {"mode": "one", "seed": Ambient.seed_of(uid.get_slice(":", 1)), "has": Sprites.has}
	var area: Rect2i = Rect2i(0, 0, size.x, size.y - 14)
	var back: RefCounted = Raster.new(size.x, size.y)
	Background.draw(back, theme, Rect2i(Vector2i.ZERO, size), tick)
	_blit_commands(back, Ambient.plan(theme, map, Vector2i(0, oy), tick, "back", busy, area, Callable(), options))
	var front: RefCounted = Raster.new(size.x, size.y)
	_blit_commands(front, Ambient.plan(theme, map, Vector2i(0, oy), tick, "front", busy, area, Callable(), options))
	if with_hero:
		Sprites.blit(front, "art:char.portitor", "idle", tick, Vector2i(24, oy + floor_row * 16))
		Sprites.blit(front, "art:obj.crate_wood", "default", 0, Vector2i(40, oy + floor_row * 16))
	var viewport: SubViewport = SubViewport.new()
	viewport.size = size
	viewport.transparent_bg = true
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	viewport.canvas_item_default_texture_filter = Viewport.DEFAULT_CANVAS_ITEM_TEXTURE_FILTER_NEAREST
	get_tree().root.add_child(viewport)
	var back_sprite: Sprite2D = Sprite2D.new()
	back_sprite.centered = false
	back_sprite.material = _palette_material()
	back_sprite.texture = ImageTexture.create_from_image(back.image())
	viewport.add_child(back_sprite)
	var terrain: ColorRect = ColorRect.new()
	terrain.position = Vector2(0, oy)
	terrain.size = Vector2(cols * 16, int(map.h) * 16)
	var shader_material: ShaderMaterial = Terrain.create(theme)
	shader_material.set_shader_parameter("grid_size", Vector2i(cols, map.h))
	shader_material.set_shader_parameter("visual_tick", tick >> 3)
	shader_material.set_shader_parameter("map_texture", _grid_texture(map))
	terrain.material = shader_material
	viewport.add_child(terrain)
	var front_sprite: Sprite2D = Sprite2D.new()
	front_sprite.centered = false
	front_sprite.material = _palette_material()
	front_sprite.texture = ImageTexture.create_from_image(front.image())
	viewport.add_child(front_sprite)
	await get_tree().process_frame
	await RenderingServer.frame_post_draw
	var result: ImageTexture = ImageTexture.create_from_image(viewport.get_texture().get_image())
	viewport.queue_free()
	return result
