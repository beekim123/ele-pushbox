extends Node2D
## One 320px UI; clipped map supports full overview and native detail panning.
signal closed
const Catalog := preload("res://pushbox/scripts/campaign_catalog.gd")
const Board := preload("res://pushbox/scripts/board.gd")
const Ecology := preload("res://pushbox/scripts/render/ambient_ecology.gd")
const MapLayer := preload("res://pushbox/scripts/ui/showcase_map_layer.gd")
var clock: float = 0.0
var panorama: bool = true
var _camera := Vector2.ZERO
var _camera_target := Vector2.ZERO
var _dragging: bool = false
var _map_layer: Node2D
var _clip: Control
var _ecology_background: Node2D
var _ecology_points: Dictionary = {}
var campaign_mode: bool = false
var level_index: int = 0
var _hover: String = ""
const Style := preload("res://pushbox/scripts/ui/pixel_style.gd")
const Registry := preload("res://pushbox/scripts/art/art_registry.gd")
const Loader := preload("res://pushbox/scripts/level_loader.gd")
const Binder := preload("res://pushbox/scripts/render/theme_shader_binder.gd")
const Gates := preload("res://pushbox/scripts/render/gate_painter.gd")
const SHADER := preload("res://pushbox/scripts/render/world.gdshader")
const THEMES := ["dungeon","forest","ruins","cave","sky_island","cosmos"]
const LABELS := ["地牢","森林","遗迹","洞穴","天空岛","宇宙"]
const IDS := {"bedrock":1,"cracked_rock":2,"crate":3,"gate":4,"sand":5,"water":6,"iron_crate":7,"acid":8,"lava":9,"pumice":10,"ice":11}
const GLYPHS := {"#":1,"c":2,"s":5,"w":6,"a":8,"m":9,"p":9,"u":10,"i":11}
var index: int = 0
var theme_id: String = "dungeon"
var map_size := Vector2i.ZERO
var map_origin := Vector2.ZERO
var map_data: Dictionary = {}
var terrain: Sprite2D
var _background: Sprite2D
var _cache: Dictionary = {}
var _sprites: Array[Dictionary] = []
var _gates: Array[Dictionary] = []

func _ready() -> void:
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_background = Sprite2D.new()
	_background.centered = false
	_background.z_index = -2
	add_child(_background)
	_ecology_background = Ecology.new()
	_ecology_background.z_index = -2
	add_child(_ecology_background)
	_clip = Control.new()
	_clip.position = Vector2(8,29)
	_clip.size = Vector2(304,122)
	_clip.clip_contents = true
	_clip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_clip)
	_map_layer = MapLayer.new()
	_map_layer.host = self
	_clip.add_child(_map_layer)
	terrain = Sprite2D.new()
	terrain.centered = false
	terrain.z_index = -1
	_map_layer.add_child(terrain)
	hide()

func open(value: int = 0) -> void:
	campaign_mode = false
	show()
	select_biome(value)

func conceal() -> void:
	hide()

func select_biome(value: int) -> void:
	if campaign_mode:
		select_campaign(value,level_index)
		return
	if terrain.material == null:
		terrain.material = ShaderMaterial.new()
		terrain.material.shader = SHADER
		terrain.material.set_shader_parameter("local_pixel_coordinates",true)
	index = posmod(value,THEMES.size())
	theme_id = THEMES[index]
	if not _cache.has(theme_id):
		var data: Dictionary = Loader.json("res://pushbox/levels/showcase/%s.json" % theme_id)
		var size := Vector2i(data.size[0],data.size[1])
		var image := Image.create(size.x*16,size.y*16,false,Image.FORMAT_RGBA8)
		for y in size.y:
			for x in size.x:
				var id: int = GLYPHS.get(data.map[y][x],0)
				image.fill_rect(Rect2i(x*16,y*16,16,16),Color(id/255.0,0,0,1))
				if id == IDS.sand or id == IDS.pumice:
					for py in range(y*16,y*16+16):
						for px in range(x*16,x*16+16):
							var variant: int = Registry.Ops.h32(px,py)%3
							image.set_pixel(px,py,Color(id/255.0,(variant<<4)/255.0,0,1))
		_cache[theme_id] = {"data":data,"texture":ImageTexture.create_from_image(image)}
	map_data = _cache[theme_id].data
	map_size = Vector2i(map_data.size[0],map_data.size[1])
	map_origin = Vector2.ZERO
	_background.texture = Registry.background(theme_id,Vector2i(320,180))
	terrain.texture = _cache[theme_id].texture
	terrain.position = Vector2.ZERO
	Binder.apply(terrain.material,theme_id,IDS)
	terrain.material.set_shader_parameter("room_rect",Vector4(0,0,map_size.x*16,map_size.y*16))
	terrain.material.set_shader_parameter("cell_texture_size",map_size*16)
	terrain.material.set_shader_parameter("world_origin",terrain.global_position)
	_sprites.clear()
	_gates.clear()
	var gate_columns: Dictionary = {}
	for prop in map_data.props:
		if prop.sprite == "gate":
			var x: int = prop.at[0]
			if not gate_columns.has(x):
				gate_columns[x] = []
			gate_columns[x].append(prop.at[1])
		else:
			_sprites.append({"sprite":prop.sprite,"texture":Style.themed_texture(prop.sprite,theme_id),"at":Vector2(prop.at[0]*16,prop.at[1]*16),"flip":prop.get("flip",false)})
	for x in gate_columns:
		var ys: Array = gate_columns[x]
		ys.sort()
		for i in ys.size():
			_gates.append({"at":Vector2(x*16,ys[i]*16),"i":i,"count":ys.size()})
	fit_map()

func previous_rect() -> Rect2:
	return Rect2(8,151,16,16)

func next_rect() -> Rect2:
	return Rect2(296,151,16,16)

func theme_rect(value: int) -> Rect2:
	return Rect2(37+value*41,151,39,15)

func handle(event: InputEvent) -> void:
	if _handle_camera(event): return
	if campaign_mode:
		_handle_campaign(event)
		return
	if event is InputEventKey and event.pressed and not event.echo:
		match event.physical_keycode:
			KEY_LEFT,KEY_A:
				select_biome(index-1)
			KEY_RIGHT,KEY_D:
				select_biome(index+1)
			KEY_Q:
				select_biome(index-1)
			KEY_E:
				select_biome(index+1)
			KEY_ESCAPE:
				closed.emit()
	elif event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		var at: Vector2 = to_local(event.position)
		if previous_rect().has_point(at):
			select_biome(index-1)
		elif next_rect().has_point(at):
			select_biome(index+1)
		elif Rect2(8,3,32,21).has_point(at):
			closed.emit()
		else:
			for i in THEMES.size():
				if theme_rect(i).has_point(at):
					select_biome(i)

func find_exposed_tile(top: bool) -> Vector2i:
	for y in range(1,map_size.y-1):
		for x in range(1,map_size.x-1):
			if map_data.map[y][x] == "#" and map_data.map[y+(-1 if top else 1)][x] == ".":
				return Vector2i(x,y)
	return Vector2i(-1,-1)

func _center_text(value: String, y: int, color: Color) -> void:
	var width: float = Style.font().get_string_size(value,HORIZONTAL_ALIGNMENT_LEFT,-1,12).x
	Style.text(self,value,Vector2(floori((320-width)/2),y),color)

func _process(delta: float) -> void:
	if not visible: return
	clock += delta
	if not panorama:
		_camera = _camera.lerp(_camera_target,minf(1,delta*12))
		_map_layer.position = (Vector2(152,61)-_camera).round()
		map_origin = _clip.position+_map_layer.position
		refresh_world_origin()
	_map_layer.queue_redraw()
	queue_redraw()

func refresh_world_origin() -> void:
	if terrain.material != null:
		terrain.material.set_shader_parameter("world_origin",terrain.global_position)

func set_panorama(value: bool) -> void:
	panorama = value
	fit_map()

func fit_map() -> void:
	var pixels := Vector2(map_size*16)
	var divisor: int = maxi(1,ceili(maxf(pixels.x/304,pixels.y/122))) if panorama else 1
	_map_layer.scale = Vector2.ONE/divisor
	_camera = pixels/2
	_camera_target = _camera
	_map_layer.position = (Vector2(152,61)-pixels*_map_layer.scale/2).floor()
	map_origin = _clip.position+_map_layer.position
	_ecology_background.theme_id = theme_id
	_ecology_background.queue_redraw()
	_ecology_points = Ecology.anchors(map_data)
	refresh_world_origin()
	_map_layer.queue_redraw()
	queue_redraw()

func _handle_camera(event: InputEvent) -> bool:
	if event is InputEventKey and event.pressed and not event.echo:
		if event.physical_keycode == KEY_F:
			set_panorama(not panorama)
			return true
		if not panorama and event.physical_keycode in [KEY_LEFT,KEY_RIGHT,KEY_UP,KEY_DOWN]:
			var direction: Vector2 = {KEY_LEFT:Vector2.LEFT,KEY_RIGHT:Vector2.RIGHT,KEY_UP:Vector2.UP,KEY_DOWN:Vector2.DOWN}[event.physical_keycode]
			_camera_target = (_camera_target+direction*24).clamp(Vector2.ZERO,Vector2(map_size*16))
			return true
	if event is InputEventMouseButton:
		var at: Vector2 = to_local(event.position)
		if Rect2(8,29,304,122).has_point(at) and event.button_index == MOUSE_BUTTON_LEFT:
			_dragging = event.pressed and not panorama
			return _dragging
		if event.button_index == MOUSE_BUTTON_LEFT and not event.pressed: _dragging = false
	if event is InputEventMouseMotion and _dragging:
		_camera_target = (_camera_target-event.relative/global_scale).clamp(Vector2.ZERO,Vector2(map_size*16))
		return true
	return false

func draw_map(canvas: CanvasItem) -> void:
	Ecology.surface(canvas,theme_id,clock,_ecology_points)
	for prop in _sprites:
		var texture: Texture2D = Style.themed_texture(Ecology.prop_name(prop.sprite,clock),theme_id)
		var at: Vector2 = prop.at+Ecology.prop_offset(prop.sprite,clock,prop.at)
		if prop.flip:
			canvas.draw_texture_rect(texture,Rect2(at+Vector2(0,texture.get_height()),Vector2(texture.get_width(),-texture.get_height())),false)
		else:
			canvas.draw_texture(texture,at)
	for gate in _gates:
		Gates.tile(canvas,gate.at,theme_id,gate.i,gate.count,0.0)

func _draw() -> void:
	if map_data.is_empty(): return
	Style.text(self,"Esc",Vector2(8,17))
	var title: String = map_data.title.replace("："," ")
	_center_text(title,17,Style.YELLOW)
	Style.text(self,"F",Vector2(292,17),Style.YELLOW)
	for rect in [previous_rect(),next_rect()]: Style.panel(self,rect)
	draw_polygon(PackedVector2Array([Vector2(12,159),Vector2(19,155),Vector2(19,163)]),PackedColorArray([Style.YELLOW]))
	draw_polygon(PackedVector2Array([Vector2(308,159),Vector2(301,155),Vector2(301,163)]),PackedColorArray([Style.YELLOW]))
	for i in THEMES.size():
		var rect: Rect2 = theme_rect(i)
		if i==index: draw_line(rect.position+Vector2(4,14),rect.end-Vector2(4,1),Style.YELLOW)
		Style.text(self,LABELS[i],rect.position+Vector2(2,11),Style.YELLOW if i==index else Style.WHITE)
	_center_text(_hover if not _hover.is_empty() else ("F 全景 / 原生 · 方向键 / 拖动平移" if not panorama else "Q/E 世界 · A/D 切图 · F 原生细节"),176,Style.WHITE)

func open_campaign(map: int, selected_level: int = 0) -> void:
	campaign_mode = true
	show()
	select_campaign(map,selected_level)

func select_campaign(map: int, selected_level: int) -> void:
	index = posmod(map,6)
	level_index = posmod(selected_level,6)
	theme_id = THEMES[index]
	_hover = ""
	var level: Dictionary = Loader.json(Catalog.path(index,level_index))
	if level.is_empty():
		return
	if terrain.material == null:
		terrain.material = ShaderMaterial.new()
		terrain.material.shader = SHADER
		terrain.material.set_shader_parameter("local_pixel_coordinates",true)
	map_size = Vector2i(level.map[0].length(),level.map.size())
	map_origin = Vector2.ZERO
	map_data = {"title":level.title,"map":level.map,"size":[map_size.x,map_size.y],"features":Catalog.FEATURES[index]}
	var image := Image.create(map_size.x*16,map_size.y*16,false,Image.FORMAT_RGBA8)
	for y in map_size.y:
		for x in map_size.x:
			var entry: Variant = level.legend[level.map[y][x]]
			var name: String = entry if entry is String else entry.material
			var id: int = IDS.get(name,0)
			var filled: int = 16 if entry is String else floori(float(entry.get("fill",1))*16)
			image.fill_rect(Rect2i(x*16,y*16+16-filled,16,filled),Color(id/255.0,0,0,1))
	terrain.texture = ImageTexture.create_from_image(image)
	terrain.position = Vector2.ZERO
	_background.texture = Registry.background(theme_id,Vector2i(320,180))
	Binder.apply(terrain.material,theme_id,IDS)
	terrain.material.set_shader_parameter("room_rect",Vector4(0,0,map_size.x*16,map_size.y*16))
	terrain.material.set_shader_parameter("cell_texture_size",map_size*16)
	terrain.material.set_shader_parameter("world_origin",terrain.global_position)
	_sprites.clear()
	_gates.clear()
	var board := Board.new()
	board.configure(Loader.json("res://pushbox/rules.json"),Loader.json("res://pushbox/content/default/materials.json").materials)
	Loader.populate(board,level)
	for at in board.targets:
		_observe_prop(at-board.origin,"target_idle_0","箱体目标")
	for at in board.ladders:
		_observe_prop(at-board.origin,"ladder_static_0","上下攀爬")
	for lever in board.levers:
		_observe_prop(lever.at-board.origin,"lever_left_0","站在此处扳动")
	for prop in board.Biome.props(board):
		_observe_prop(prop.at-board.origin,prop.sprite,prop.label)
	for rock in board.mechanisms.get("stalactites",[]):
		var at := Vector2i(rock.at[0],rock.at[1])
		image.fill_rect(Rect2i(at*16,Vector2i(16,16)),Color(IDS.bedrock/255.0,0,0,1))
	terrain.texture.update(image)
	for gate in board.gates:
		for i in gate.tiles.size():
			_gates.append({"at":Vector2(gate.tiles[i]-board.origin)*16,"i":i,"count":gate.tiles.size()})
	for box in board.boxes:
		_observe_prop(box.at-board.origin,"crate_iron_0" if box.kind == "iron" else "crate_static_0","沉水铁箱" if box.kind == "iron" else "浮水轻木箱")
	_observe_prop(board.player-board.origin,"miner_idle_0","玩家起点")
	fit_map()

func _observe_prop(at: Vector2i, sprite: String, label: String) -> void:
	_sprites.append({"sprite":sprite,"texture":Style.themed_texture(sprite,theme_id),"at":Vector2(at)*16,"label":label,"flip":false})

func _handle_campaign(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		match event.physical_keycode:
			KEY_ESCAPE,KEY_TAB:
				closed.emit()
			KEY_LEFT,KEY_A:
				select_campaign(index,level_index-1)
			KEY_RIGHT,KEY_D:
				select_campaign(index,level_index+1)
			KEY_UP,KEY_Q:
				select_campaign(index-1,level_index)
			KEY_DOWN,KEY_E:
				select_campaign(index+1,level_index)
	elif event is InputEventMouseMotion:
		_hover = ""
		var at: Vector2 = _map_layer.to_local(event.position)
		for prop in _sprites:
			if Rect2(prop.at,prop.texture.get_size()).has_point(at):
				_hover = prop.label
		queue_redraw()
	elif event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		var at: Vector2 = to_local(event.position)
		if previous_rect().has_point(at):
			select_campaign(index,level_index-1)
		elif next_rect().has_point(at):
			select_campaign(index,level_index+1)
		elif Rect2(8,3,32,21).has_point(at):
			closed.emit()
		else:
			for map in 6:
				if theme_rect(map).has_point(at):
					select_campaign(map,level_index)
