extends Node2D
## Pixel nine-slice and text rows; all modal input is consumed here.
signal requested(action: String)
signal level_selected(index: int)
signal outlines_changed(value: bool)
const Style := preload("res://pushbox/scripts/ui/pixel_style.gd")
const ROOT_ROWS := ["继续", "提示", "重开", "选关", "设置", "退出"]
var opened: bool = false
var page: String = "root"
var selected: int = 0
var outlines: bool = false
var hint_lines: PackedStringArray = []

func rows() -> Array:
	match page:
		"hints": return ["规则提示", "下一步提示", "返回"]
		"levels": return ["1 · 梯子", "2 · 挖与倒", "3 · 放水", "4 · 压板与炸药", "5 · 炸沙抬水位", "返回"]
		"settings": return ["格子类别：%s" % ("开" if outlines else "关"), "重看引导", "返回"]
		"message": return ["返回"]
	return ROOT_ROWS

func toggle() -> void:
	if opened and page != "root":
		page = "root"
		selected = 0
	else:
		opened = not opened
		page = "root"
		selected = 0
	queue_redraw()

func close() -> void:
	opened = false
	queue_redraw()

func show_hint(value: String) -> void:
	hint_lines = PackedStringArray()
	var line := ""
	for letter in value:
		if Style.font().get_string_size(line + letter, HORIZONTAL_ALIGNMENT_LEFT, -1, 12).x > 198:
			hint_lines.append(line)
			line = ""
		line += letter
	if not line.is_empty():
		hint_lines.append(line)
	page = "message"
	selected = 0
	queue_redraw()

func _rect() -> Rect2:
	if page == "message":
		return Rect2(48, 48, 224, 84)
	return Rect2(86, 14 + (6 - rows().size()) * 10, 148, rows().size() * 20 + 12)

func handle(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed:
		var code: int = event.physical_keycode
		if code == KEY_ESCAPE:
			toggle()
		elif code in [KEY_UP, KEY_W, KEY_DOWN, KEY_S]:
			selected = posmod(selected + (-1 if code in [KEY_UP, KEY_W] else 1), rows().size())
			queue_redraw()
		elif code in [KEY_ENTER, KEY_SPACE]:
			activate()
	elif event is InputEventMouseMotion or event is InputEventMouseButton:
		var rect: Rect2 = _rect()
		var row: int = int((event.position.y - rect.position.y - 6) / 20)
		if page == "message":
			row = 0
		if rect.has_point(event.position) and row >= 0 and row < rows().size():
			selected = row
			queue_redraw()
			if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
				activate()

func activate() -> void:
	match page:
		"root":
			match selected:
				0: close()
				1: page = "hints"; selected = 0
				2: close(); requested.emit("restart")
				3: page = "levels"; selected = 0
				4: page = "settings"; selected = 0
				5: requested.emit("quit")
		"hints":
			if selected < 2:
				requested.emit("rule_hint" if selected == 0 else "next_hint")
			else:
				page = "root"; selected = 1
		"levels":
			if selected < 5:
				close(); level_selected.emit(selected)
			else:
				page = "root"; selected = 3
		"settings":
			if selected == 0:
				outlines = not outlines
				outlines_changed.emit(outlines)
			elif selected == 1:
				close()
				requested.emit("reset_guides")
			else:
				page = "root"; selected = 4
		"message": page = "hints"; selected = 0
	queue_redraw()

func _draw() -> void:
	if not opened:
		return
	var rect: Rect2 = _rect()
	Style.panel(self, rect)
	if page == "message":
		for i in mini(2, hint_lines.size()):
			Style.text(self, hint_lines[i], rect.position + Vector2(12, 24 + i * 16))
		Style.text(self, "返回", rect.position + Vector2(20, 70), Style.YELLOW)
		draw_polygon(PackedVector2Array([rect.position + Vector2(9, 61), rect.position + Vector2(9, 68), rect.position + Vector2(13, 65)]), PackedColorArray([Style.YELLOW]))
		return
	var options: Array = rows()
	for i in options.size():
		var at: Vector2 = rect.position + Vector2(22, 20 + i * 20)
		Style.text(self, options[i], at, Style.YELLOW if i == selected else Style.WHITE)
		if i == selected:
			draw_polygon(PackedVector2Array([at + Vector2(-11, -9), at + Vector2(-11, -2), at + Vector2(-7, -5)]), PackedColorArray([Style.YELLOW]))
