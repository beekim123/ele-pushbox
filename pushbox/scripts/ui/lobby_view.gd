extends Node2D
## A 320x180 native canvas; Game centers it using the same integer layout.
signal level_selected(index: int)
signal settings_requested
const Style := preload("res://pushbox/scripts/ui/pixel_style.gd")
const TITLES := ["教学模式", "闯关模式", "挑战模式"]
const LEVEL_NAMES := ["移动与推箱", "挖沙与造坡", "放水与浮箱", "机关与爆破"]
const LEVEL_IDS := ["t01", "t02", "t03", "t04"]
var page: String = "modes"
var selected: int = 0
var progress_path: String = "user://progress.json"
var completed: Dictionary = {}
var clock: float = 0.0
var _frame: int = -1
var _fade: float = 0.0
var _save_pending: bool = false

func _ready() -> void:
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	load_progress()

func load_progress() -> void:
	completed.clear()
	_save_pending = false
	if not FileAccess.file_exists(progress_path):
		return
	var data: Variant = JSON.parse_string(FileAccess.get_file_as_string(progress_path))
	if not data is Dictionary or not data.get("completed") is Dictionary:
		return
	for id in LEVEL_IDS:
		if data.completed.get(id) == true:
			completed[id] = true
	queue_redraw()

func mark_completed(id: String) -> void:
	if not id in LEVEL_IDS:
		return
	if not completed.has(id):
		completed[id] = true
		_save_pending = true
	save_progress()
	queue_redraw()

func save_progress() -> void:
	if not _save_pending:
		return
	# Write then rename: an interrupted write cannot truncate the old progress.
	var file := FileAccess.open(progress_path + ".tmp", FileAccess.WRITE)
	if file != null:
		var written: bool = file.store_string(JSON.stringify({"version": 1, "completed": completed}) + "\n")
		file.flush()
		written = written and file.get_error() == OK
		file.close()
		if written and DirAccess.rename_absolute(progress_path + ".tmp", progress_path) == OK:
			_save_pending = false
		else:
			push_warning("无法保存教学进度")
	else:
		push_warning("无法保存教学进度")

func completed_count() -> int:
	return completed.size()

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

func handle(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		var code: int = event.physical_keycode
		if code == KEY_ESCAPE:
			if page == "tutorial":
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
		for i in (3 if page == "modes" else 5):
			var rect: Rect2 = card_rect(i) if page == "modes" else row_rect(i)
			if rect.has_point(at):
				selected = i
				queue_redraw()
				if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
					activate()
				break

func activate() -> void:
	if page == "modes":
		if selected == 0:
			show_page("tutorial")
	elif selected == 4:
		show_page()
	else:
		level_selected.emit(selected)

func _process(delta: float) -> void:
	clock += delta
	_fade = maxf(0.0, _fade - delta)
	var next: int = int(clock * 8)
	if next != _frame or _fade > 0:
		_frame = next
		queue_redraw()

func _center_text(value: String, x: float, y: float, color: Color = Style.WHITE) -> void:
	var width: float = Style.font().get_string_size(value, HORIZONTAL_ALIGNMENT_LEFT, -1, 12).x
	Style.text(self, value, Vector2(x - width / 2, y), color)

func _draw() -> void:
	draw_texture(Style.texture("cave_bg"), Vector2.ZERO)
	for x in [28, 284]:
		draw_line(Vector2(x + 4,0), Vector2(x + 4,15), Color("3e2731"))
		draw_texture(Style.texture("lantern_idle_%d" % (int(clock * 2) % 2)), Vector2(x,15))
	_center_text("推箱子：沙与水", 160, 28, Style.YELLOW)
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
				draw_texture_rect(Style.texture("crate_static_0"), Rect2(center-26,78,24,24), false)
				draw_texture_rect(Style.texture("mode_campaign"), Rect2(center-2,71,24,24), false)
			else:
				draw_texture_rect(Style.texture("mode_challenge"), Rect2(center-12,73,24,24), false)
			_center_text(["基础操作", "特性增量", "地狱大图"][i], center, 114)
			if i == 0:
				_center_text("已通 %d/4 关" % completed_count(), center, 130, Style.YELLOW)
			else:
				draw_texture(Style.texture("icon_lock"), Vector2(center-3,98))
				_center_text("第二阶段开放" if i == 1 else "第三阶段开放", center, 130, Color("8b9bb4"))
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
	for i in 8:
		var at := Vector2(fposmod(i * 43 + clock * (1 + i % 2), 316) + 2, 148 + i % 3 * 2)
		draw_rect(Rect2(at.floor(), Vector2.ONE), Color("5a6988"))
	if _fade > 0:
		draw_rect(Rect2(0,34,320,118), Color(Style.INK, _fade / 0.12 * 0.35))
