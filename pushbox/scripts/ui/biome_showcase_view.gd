extends Node2D
## Static authored panoramas rendered by the same terrain shader as gameplay.
signal closed
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
	terrain = Sprite2D.new()
	terrain.centered = false
	terrain.z_index = -1
	add_child(terrain)
	hide()

func open(value: int = 0) -> void:
	show()
	select_biome(value)

func conceal() -> void:
	hide()

func select_biome(value: int) -> void:
	if terrain.material == null:
		terrain.material = ShaderMaterial.new()
		terrain.material.shader = SHADER
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
	map_origin = Vector2((640-map_size.x*16)/2,40+(288-map_size.y*16)/2).floor()
	_background.texture = Registry.background(theme_id,Vector2i(640,360))
	terrain.texture = _cache[theme_id].texture
	terrain.position = map_origin
	Binder.apply(terrain.material,theme_id,IDS)
	terrain.material.set_shader_parameter("room_rect",Vector4(0,0,map_size.x*16,map_size.y*16))
	terrain.material.set_shader_parameter("cell_texture_size",map_size*16)
	terrain.material.set_shader_parameter("world_origin",to_global(map_origin))
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
			_sprites.append({"texture":Style.themed_texture(prop.sprite,theme_id),"at":Vector2(prop.at[0]*16,prop.at[1]*16),"flip":prop.get("flip",false)})
	for x in gate_columns:
		var ys: Array = gate_columns[x]
		ys.sort()
		for i in ys.size():
			_gates.append({"at":Vector2(x*16,ys[i]*16),"i":i,"count":ys.size()})
	queue_redraw()

func previous_rect() -> Rect2:
	return Rect2(12,169,32,30)

func next_rect() -> Rect2:
	return Rect2(596,169,32,30)

func theme_rect(value: int) -> Rect2:
	return Rect2(161+value*53,333,50,15)

func handle(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		match event.physical_keycode:
			KEY_LEFT,KEY_A:
				select_biome(index-1)
			KEY_RIGHT,KEY_D:
				select_biome(index+1)
			KEY_ESCAPE:
				closed.emit()
	elif event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		var at: Vector2 = to_local(event.position)
		if previous_rect().has_point(at):
			select_biome(index-1)
		elif next_rect().has_point(at):
			select_biome(index+1)
		elif Rect2(8,5,68,25).has_point(at):
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
	Style.text(self,value,Vector2(floori((640-width)/2),y),color)

func _draw() -> void:
	if map_data.is_empty():
		return
	for prop in _sprites:
		var texture: Texture2D = prop.texture
		var at: Vector2 = map_origin+prop.at
		if prop.flip:
			draw_texture_rect(texture,Rect2(at+Vector2(0,texture.get_height()),Vector2(texture.get_width(),-texture.get_height())),false)
		else:
			draw_texture(texture,at)
	for gate in _gates:
		Gates.tile(self,map_origin+gate.at,theme_id,gate.i,gate.count,0.0)
	draw_rect(Rect2(0,0,640,36),Style.INK)
	draw_rect(Rect2(0,331,640,29),Style.INK)
	_center_text("%02d / 06  %s · %s" % [index+1,LABELS[index],map_data.title],18,Registry.theme(theme_id).colors.accent)
	_center_text("%d × %d 格　地图风格预览　左右键 / 点击箭头切换" % [map_size.x,map_size.y],32,Color("8b9bb4"))
	Style.text(self,"返回大厅",Vector2(8,18),Style.WHITE)
	for rect in [previous_rect(),next_rect()]:
		Style.panel(self,rect)
	draw_polygon(PackedVector2Array([Vector2(24,184),Vector2(32,178),Vector2(32,190)]),PackedColorArray([Style.YELLOW]))
	draw_polygon(PackedVector2Array([Vector2(616,184),Vector2(608,178),Vector2(608,190)]),PackedColorArray([Style.YELLOW]))
	for i in THEMES.size():
		var rect: Rect2 = theme_rect(i)
		if i == index:
			draw_rect(rect,Color("3a4466"))
		Style.text(self,LABELS[i],rect.position+Vector2(5,12),Style.YELLOW if i == index else Color("8b9bb4"))
	_center_text(map_data.features,359,Color("c0cbdc"))
