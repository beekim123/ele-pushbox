extends Node2D
## A 320x180 native canvas; Game centers it using the same integer layout.
signal level_selected(index: int)
signal settings_requested
signal campaign_selected(map: int, index: int)
signal observation_requested(map: int, index: int)
signal showcase_requested
const Catalog := preload("res://pushbox/scripts/campaign_catalog.gd")
const Ecology := preload("res://pushbox/scripts/render/ambient_ecology.gd")
const Miniature := preload("res://pushbox/scripts/ui/mini_diorama.gd")
const CARD_TITLES := [
	["沉铁开道","一沙千斤","一沙二用","爆柱填渊","铁木双井","矿井枢纽"],
	["甘霖育藤","浮木渡津","筑坝引泉","斩藤落箱","双藤交错","巨木水殿"],
	["黄金天平","流沙漏斗","掬沙称重","沙漏水钟","双盘博弈","日轮内殿"],
	["滴酸穿石","水火化沙","引酸入渠","钟乳石坠","双色沙漏","幽光熔脉"],
	["履冰过渊","轻重云垫","冰封水位","顺风扬沙","破冰坠锚","云海圣域"],
	["量子跃迁","隔空传沙","失重回廊","离子冷却","星门双生","曲率舱"]]
var _miniature: Node2D
var _mini_key := Vector2i(-1,-1)
var _ecology_points: Dictionary = {}
var map_index: int = 0
var _thumbnails: Dictionary = {}
const Style := preload("res://pushbox/scripts/ui/pixel_style.gd")
const TITLES := ["教学模式", "闯关模式", "挑战模式"]
const LEVEL_NAMES := ["移动与推箱", "挖沙与造坡", "放水与浮箱", "机关与爆破"]
const CHALLENGE_LOCK_HINT := "六图银章开放"
const LEVEL_IDS := ["t01", "t02", "t03", "t04"]
var page: String = "modes"
var selected: int = 0
var progress_path: String = "user://progress.json"
var completed: Dictionary = {}
var clock: float = 0.0
var _frame: int = -1
var _fade: float = 0.0
var _save_pending: bool = false
var _staged_save: bool = false
var _write_task: int = -1
var _write_success: bool = false
var _write_generation: int = 0
var _generation: int = 0

func _ready() -> void:
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	load_progress()
	Ecology.warm()
	_miniature = Miniature.new()
	_miniature.position = Vector2(10,73)
	add_child(_miniature)

func _exit_tree() -> void:
	save_progress()

func load_progress() -> void:
	if _write_task >= 0:
		save_progress()
	_generation += 1
	completed.clear()
	_save_pending = false
	_staged_save = false
	if not FileAccess.file_exists(progress_path):
		return
	var data: Variant = JSON.parse_string(FileAccess.get_file_as_string(progress_path))
	if not data is Dictionary or not data.get("completed") is Dictionary:
		return
	for id in data.completed:
		if data.completed[id] == true and (id in LEVEL_IDS or Catalog.locate(id).x >= 0):
			completed[id] = true
	queue_redraw()

func mark_completed(id: String, defer_save: bool = false) -> void:
	if not id in LEVEL_IDS and Catalog.locate(id).x < 0:
		return
	if not completed.has(id):
		completed[id] = true
		_generation += 1
		_staged_save = false
		_save_pending = true
	if not defer_save:
		save_progress()
	queue_redraw()

func stage_progress() -> bool:
	finish_progress_write(true)
	if not _save_pending:
		return false
	_staged_save = _store_payload(progress_path+".tmp", JSON.stringify({"version":2,"completed":completed})+"\n")
	if not _staged_save:
		push_warning("无法保存进度")
	return _staged_save

static func _store_payload(path: String, payload: String) -> bool:
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		return false
	var written: bool = file.store_string(payload)
	file.flush()
	written = written and file.get_error() == OK
	file.close()
	return written

func _write_payload(path: String, payload: String) -> void:
	# Only immutable arguments enter the worker; the main thread reads this
	# result after joining the task. No SDK or scene operation runs here.
	_write_success = _store_payload(path,payload)

func begin_progress_write() -> bool:
	if not _save_pending:
		return false
	if _write_task >= 0:
		return true
	_staged_save = false
	_write_success = false
	_write_generation = _generation
	var payload: String = JSON.stringify({"version":2,"completed":completed})+"\n"
	_write_task = WorkerThreadPool.add_task(_write_payload.bind(progress_path+".tmp",payload),false,"progress write")
	return true

func finish_progress_write(wait: bool = false) -> bool:
	if _write_task < 0:
		return true
	if not wait and not WorkerThreadPool.is_task_completed(_write_task):
		return false
	WorkerThreadPool.wait_for_task_completion(_write_task)
	_write_task = -1
	_staged_save = _write_success and _write_generation == _generation
	if not _write_success:
		push_warning("无法保存进度")
	return true

func commit_progress() -> void:
	if not _staged_save:
		return
	if DirAccess.rename_absolute(progress_path+".tmp",progress_path) == OK:
		_save_pending = false
	else:
		push_warning("无法保存进度")
	_staged_save = false

func save_progress() -> void:
	# Exiting/explicit callers join the same one-worker task before committing.
	finish_progress_write(true)
	if _save_pending and (_staged_save or stage_progress()):
		commit_progress()

func completed_count() -> int:
	return LEVEL_IDS.filter(func(id: String) -> bool: return completed.has(id)).size()

func map_count(map: int) -> int:
	return Catalog.count(completed,map)

func map_unlocked(map: int) -> bool:
	return Catalog.map_unlocked(completed,map)

func level_unlocked(map: int, index: int) -> bool:
	return Catalog.level_unlocked(completed,map,index)

func badge(map: int) -> String:
	return "全清金冠" if map_count(map) == 6 else ("通行银章" if map_count(map) >= 3 else "尚未通行")

func mainline_complete() -> bool:
	return Catalog.mainline_complete(completed)

func campaign_count() -> int:
	var total: int = 0
	for map in 6:
		total += map_count(map)
	return total

func challenge_unlocked() -> bool:
	return mainline_complete() or campaign_count() >= 24

func map_rect(index: int) -> Rect2:
	return Rect2(21+index*48,25,38,24)

func pool_rect(index: int) -> Rect2:
	return Rect2(124+(index%2)*98,56+(index/2)*35,90,32)

func observation_rect() -> Rect2:
	return Rect2(12,141,100,16)

func _handle_campaign(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		match event.physical_keycode:
			KEY_ESCAPE:
				show_page()
			KEY_TAB:
				observation_requested.emit(map_index,selected)
			KEY_Q,KEY_E:
				map_index = posmod(map_index + (-1 if event.physical_keycode == KEY_Q else 1),6)
				selected = 0
			KEY_LEFT,KEY_A:
				selected = posmod(selected-1,6)
			KEY_RIGHT,KEY_D:
				selected = posmod(selected+1,6)
			KEY_UP,KEY_W:
				selected = posmod(selected-2,6)
			KEY_DOWN,KEY_S:
				selected = posmod(selected+2,6)
			KEY_ENTER:
				if level_unlocked(map_index,selected):
					campaign_selected.emit(map_index,selected)
	elif event is InputEventMouseMotion or event is InputEventMouseButton:
		var at: Vector2 = to_local(event.position)
		var clicked: bool = event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT
		for map in 6:
			if map_rect(map).has_point(at) and clicked:
				map_index = map
				selected = 0
		if observation_rect().has_point(at) and clicked:
			observation_requested.emit(map_index,selected)
		for index in 6:
			if pool_rect(index).has_point(at):
				selected = index
				if clicked and level_unlocked(map_index,index):
					campaign_selected.emit(map_index,index)
	queue_redraw()

func show_page(value: String = "modes", index: int = 0) -> void:
	page = value
	selected = index
	_fade = 0.12
	show()
	set_process(true)
	queue_redraw()

func conceal() -> void:
	hide()
	set_process(false)

func card_rect(index: int) -> Rect2:
	return Rect2(16 + index * 100, 44, 88, 92)

func rows() -> Array:
	var result: Array = []
	for i in LEVEL_NAMES.size():
		result.append("T%02d · %s" % [i + 1, LEVEL_NAMES[i]])
	return result + ["返回大厅"]

func row_rect(index: int) -> Rect2:
	return Rect2(70, 43 + index * 21, 180, 20)

func showcase_rect() -> Rect2:
	return Rect2(86,137,148,14)

func handle(event: InputEvent) -> void:
	if page == "campaign":
		_handle_campaign(event)
		return
	if event is InputEventKey and event.pressed and not event.echo:
		var code: int = event.physical_keycode
		if code == KEY_B and page == "modes":
			showcase_requested.emit()
		elif code == KEY_ESCAPE:
			if page in ["tutorial", "challenge"]:
				show_page()
			else:
				settings_requested.emit()
		elif code in [KEY_LEFT, KEY_A, KEY_UP, KEY_W, KEY_RIGHT, KEY_D, KEY_DOWN, KEY_S]:
			var backwards: bool = code in [KEY_LEFT, KEY_A, KEY_UP, KEY_W]
			selected = posmod(selected + (-1 if backwards else 1), 3 if page == "modes" else 5)
			queue_redraw()
		elif code == KEY_ENTER:
			activate()
	elif event is InputEventMouseMotion or event is InputEventMouseButton:
		var at: Vector2 = to_local(event.position)
		if page == "modes" and showcase_rect().has_point(at):
			if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
				showcase_requested.emit()
			return
		for i in (3 if page == "modes" else 5):
			var rect: Rect2 = card_rect(i) if page == "modes" else row_rect(i)
			if rect.has_point(at):
				selected = i
				queue_redraw()
				if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
					activate()
				break

func activate() -> void:
	if page == "challenge":
		show_page()
		return
	if page == "modes":
		if selected == 0:
			show_page("tutorial")
		elif selected == 1:
			show_page("campaign")
		elif selected == 2 and challenge_unlocked():
			show_page("challenge")
	elif selected == 4:
		show_page()
	else:
		level_selected.emit(selected)

func _process(delta: float) -> void:
	clock += delta
	_miniature.visible = page == "campaign"
	if page == "campaign" and _mini_key != Vector2i(map_index,selected):
		_mini_key = Vector2i(map_index,selected)
		_miniature.select_campaign(map_index,selected)
		_miniature.show()
	_fade = maxf(0.0, _fade - delta)
	var next: int = int(clock * 30)
	if next != _frame or _fade > 0:
		_frame = next
		queue_redraw()

func _center_text(value: String, x: float, y: float, color: Color = Style.WHITE) -> void:
	var width: float = Style.font().get_string_size(value, HORIZONTAL_ALIGNMENT_LEFT, -1, 12).x
	Style.text(self, value, Vector2(x - width / 2, y), color)

func _draw() -> void:
	var theme: String = Catalog.THEMES[map_index] if page=="campaign" else "dungeon"
	draw_texture(Style.Art.background(theme,Vector2i(320,180)),Vector2.ZERO)
	Ecology.backdrop(self,theme,clock)
	if page == "campaign":
		_draw_campaign()
		return
	for x in [28, 284]:
		draw_line(Vector2(x + 4,0), Vector2(x + 4,15), Color("3e2731"))
		draw_texture(Style.themed_texture("lantern_idle_%d" % (int(clock * 4) % 4),theme), Vector2(x,15))
	_center_text("推箱子：沙与水", 160, 28, Style.YELLOW)
	if page == "challenge":
		_center_text("主线通行完成",160,77,Style.YELLOW)
		_center_text("第三阶段挑战关卡筹备中",160,103)
		_center_text("Enter / Esc 返回大厅",160,145)
		return
	if page == "modes":
		for i in 3:
			var rect: Rect2 = card_rect(i)
			Style.panel(self, rect)
			if selected == i:
				draw_rect(rect.grow(-1), Style.YELLOW, false, 1)
				draw_polygon(PackedVector2Array([Vector2(rect.position.x+40,144), Vector2(rect.position.x+48,144), Vector2(rect.position.x+44,140)]), PackedColorArray([Style.YELLOW]))
			var center: float = rect.get_center().x
			_center_text(TITLES[i], center, 61, Style.YELLOW if i == selected else Style.WHITE)
			if i == 0:
				draw_texture_rect(Style.texture("miner_idle_%d" % (int(clock * 2) % 2)), Rect2(center-22,68,32,32), false)
				draw_texture_rect(Style.texture("icon_sandbag_7"), Rect2(center+6,80,24,24), false)
			elif i == 1:
				draw_texture_rect(Style.texture("crate_static_0"), Rect2(center-30,74,32,32), false)
				draw_texture_rect(Style.texture("mode_campaign"), Rect2(center-2,71,24,24), false)
			else:
				draw_texture_rect(Style.texture("mode_challenge"), Rect2(center-12,73,24,24), false)
			_center_text(["基础操作", "特性增量", "地狱大图"][i], center, 114)
			if i == 0:
				_center_text("已通 %d/4 关" % completed_count(), center, 130, Style.YELLOW)
			elif i == 1:
				_center_text("已通 %d/36" % campaign_count(), center, 130, Style.YELLOW)
			else:
				if not challenge_unlocked():
					draw_texture(Style.texture("icon_lock"), Vector2(center-3,98))
				_center_text("入口已解锁" if challenge_unlocked() else CHALLENGE_LOCK_HINT, center, 130, Color("8b9bb4"))
		Style.panel(self,showcase_rect())
		_center_text("地图风格预览 · B",160,148,Style.YELLOW)
	else:
		Style.panel(self, Rect2(62,34,196,117))
		for i in 5:
			var at: Vector2 = row_rect(i).position + Vector2(12,14)
			Style.text(self, rows()[i], at, Style.YELLOW if i == selected else Style.WHITE)
			if i == selected:
				draw_polygon(PackedVector2Array([at+Vector2(-8,-8),at+Vector2(-8,-2),at+Vector2(-4,-5)]), PackedColorArray([Style.YELLOW]))
			if i < 4 and completed.has(LEVEL_IDS[i]):
				draw_texture(Style.texture("target_lit_0"), at + Vector2(149,-12))
	_center_text("方向键 / 鼠标选择　Enter / 左键进入", 160, 162, Color("c0cbdc"))
	_center_text("Esc 设置" if page == "modes" else "Esc 返回大厅", 160, 176, Color("8b9bb4"))
	if _fade > 0:
		draw_rect(Rect2(0,34,320,118), Color(Style.INK, _fade / 0.12 * 0.35))

func _star(at: Vector2, color: Color = Style.YELLOW) -> void:
	var rows: Array[String] = ["...#...","...#...","#######",".#####.","..###..",".##.##.","##...##"]
	for y in rows.size():
		for x in rows[y].length():
			if rows[y][x]=="#": draw_rect(Rect2(at+Vector2(x,y),Vector2.ONE),color)

func _route_icon(map: int, at: Vector2, color: Color) -> void:
	match map:
		0:
			draw_rect(Rect2(at,Vector2(12,9)),color,false)
			draw_line(at+Vector2(0,4),at+Vector2(11,4),color)
			draw_line(at+Vector2(5,0),at+Vector2(5,4),color)
			draw_line(at+Vector2(8,4),at+Vector2(8,8),color)
		1:
			draw_polygon(PackedVector2Array([at+Vector2(0,8),at+Vector2(3,2),at+Vector2(10,0),at+Vector2(11,6),at+Vector2(6,10)]),PackedColorArray([color]))
			draw_line(at+Vector2(1,9),at+Vector2(9,2),Color("265c42"))
		2:
			draw_arc(at+Vector2(6,5),3,0,TAU,12,color)
			for i in 4:
				var v := Vector2(cos(i*PI/2),sin(i*PI/2))
				draw_line(at+Vector2(6,5)+v*5,at+Vector2(6,5)+v*6,color)
		3:
			draw_polygon(PackedVector2Array([at+Vector2(1,9),at+Vector2(3,0),at+Vector2(7,2),at+Vector2(10,10)]),PackedColorArray([color]))
			draw_line(at+Vector2(4,2),at+Vector2(5,8),Style.WHITE)
		4:
			draw_polygon(PackedVector2Array([at+Vector2(0,8),at+Vector2(9,0),at+Vector2(12,4),at+Vector2(5,10)]),PackedColorArray([color]))
			draw_line(at+Vector2(1,10),at+Vector2(9,2),Color("8b9bb4"))
		5:
			draw_arc(at+Vector2(6,5),4,0,TAU,14,color)
			draw_line(at+Vector2(0,9),at+Vector2(12,1),Style.WHITE)
			_star(at+Vector2(4,3),color)

func _draw_campaign() -> void:
	Style.text(self,"Esc",Vector2(8,17))
	_center_text(Catalog.MAP_NAMES[map_index],160,18,Style.YELLOW)
	draw_texture(Style.themed_texture("lantern_idle_%d"%(int(clock*4)%4),Catalog.THEMES[map_index]),Vector2(268,0))
	Style.text(self,"%d/6"%map_count(map_index),Vector2(287,17),Style.YELLOW)
	for map in 6:
		var center: Vector2 = map_rect(map).get_center()
		if map<5:
			for x in range(int(center.x+13),int(center.x+37),4):
				draw_rect(Rect2(x,center.y,2,1),Color("8b9bb4"))
		var color: Color = Style.Art.theme(Catalog.THEMES[map]).colors.accent if map_unlocked(map) else Color("5a6988")
		draw_arc(center,12,0,TAU,16,color)
		_route_icon(map,center-Vector2(6,5),color)
		if map==map_index: draw_arc(center,14,0,TAU,16,Style.YELLOW)
		if not map_unlocked(map): draw_texture(Style.texture("icon_lock"),center+Vector2(8,4))
		elif map_count(map)>=3:
			var at: Vector2 = center+Vector2(7,5)
			if map_count(map)==6:
				draw_line(at+Vector2(0,4),at+Vector2(7,4),Style.YELLOW)
				draw_line(at,at+Vector2(1,3),Style.YELLOW)
				draw_line(at+Vector2(3,1),at+Vector2(3,3),Style.YELLOW)
				draw_line(at+Vector2(6,0),at+Vector2(5,3),Style.YELLOW)
			else:
				draw_rect(Rect2(at+Vector2(1,1),Vector2(5,5)),Color("c0cbdc"),false)
				draw_rect(Rect2(at+Vector2(2,2),Vector2(3,2)),Style.WHITE)
				draw_line(at+Vector2(3,-1),at+Vector2(3,1),Color("c0cbdc"))
	Style.panel(self,Rect2(8,54,108,104))
	Style.text(self,CARD_TITLES[map_index][selected],Vector2(14,68),Style.YELLOW)
	var theme: String = Catalog.THEMES[map_index]
	if theme=="forest":
		draw_line(Vector2(8,63),Vector2(7,134),Color("63c74d"))
		for y in [72,98,126]:
			draw_line(Vector2(8,y),Vector2(4,y-3),Color("3e8948"))
			_star(Vector2(3,y),Color("f6757a"))
	elif theme=="sky_island":
		draw_texture(Ecology._textures.cloud1,Vector2(40,135))
	elif theme=="ruins":
		for x in range(16,110,12): draw_line(Vector2(x,139),Vector2(x+3,137),Style.YELLOW)
	Style.panel(self,observation_rect())
	Style.text(self,"Tab 观察大地图",Vector2(16,153),Style.YELLOW)
	for index in 6:
		var rect: Rect2 = pool_rect(index)
		Style.panel(self,rect)
		var unlocked: bool = level_unlocked(map_index,index)
		if index==selected:
			draw_rect(rect.grow(-1),Style.YELLOW if int(clock*3)%2 else Color("feae34"),false)
			var cursor: Texture2D = Style.themed_texture("miner_idle_%d"%(int(clock*2)%2),theme)
			draw_texture(cursor,rect.position-Vector2(11,-8))
		Style.text(self,"%02d"%(index+1),rect.position+Vector2(5,13),Style.YELLOW)
		Style.text(self,CARD_TITLES[map_index][index],rect.position+Vector2(22,13),Style.WHITE if unlocked else Color("8b9bb4"))
		for star in index/2+1: _star(rect.position+Vector2(6+star*9,21))
		if completed.has(Catalog.id(map_index,index)):
			draw_texture(Style.texture("target_lit_0"),rect.position+Vector2(68,15))
		elif not unlocked:
			draw_texture(Style.texture("icon_lock"),rect.position+Vector2(76,21))
		else:
			draw_polygon(PackedVector2Array([rect.position+Vector2(76,21),rect.position+Vector2(76,27),rect.position+Vector2(81,24)]),PackedColorArray([Style.YELLOW]))
	_center_text("Q/E 世界 · 方向键选关 · Enter 进入",160,175,Style.WHITE)
