class_name PortitorBubble
extends Control
## Live G2 speech/thought text with speaker anchors and typewriter support.
var issues: Array[String] = []
var box: Rect2
var below: bool = false
var tail_x: float = 0
var _lines: PackedStringArray = []
var _revealed: float = 0
var _total: int = 0
var _thought: bool = false
var _labels: Array[Label] = []

static func layout(value: String, minimum: int = 100, maximum: int = 224, limit: int = 6) -> Dictionary:
	var G2: GDScript = load("res://presentation/ui/widgets/g2.gd")
	var width: int = minimum
	var lines: PackedStringArray = _wrap(value, G2.font(true), width - 12)
	while lines.size() > limit and width < maximum:
		width = mini(maximum, width + 12)
		lines = _wrap(value, G2.font(true), width - 12)
	return {"w": width, "h": lines.size() * 12 + 10, "lines": lines}

func configure(value: String, speaker: Vector2, name_text: String, _placeholder_text: String) -> void:
	var G2: GDScript = load("res://presentation/ui/widgets/g2.gd")
	var shape: Dictionary = layout(value, 100, 224, 6)
	below = speaker.y - float(shape.h) - 9 < 22
	var at := Vector2(clampf(roundf(speaker.x - float(shape.w) / 2), 4, 316 - float(shape.w)), minf(177 - float(shape.h), speaker.y + 24) if below else maxf(22, speaker.y - float(shape.h) - 9))
	configure_layout(value, Rect2(at, Vector2(shape.w, shape.h)), speaker.x, name_text, false, below)

func configure_layout(value: String, area: Rect2, speaker_x: float, name_text: String = "", thought: bool = false, tail_above: bool = false) -> void:
	var G2: GDScript = load("res://presentation/ui/widgets/g2.gd")
	for child: Node in get_children():
		remove_child(child)
		child.queue_free()
	_labels.clear()
	issues.clear()
	box = area
	below = tail_above
	_thought = thought
	tail_x = clampf(speaker_x, box.position.x + 5, box.end.x - 6)
	_lines = _wrap(value, G2.font(true), box.size.x - 12)
	_total = 0
	for line: String in _lines: _total += line.length()
	var settings: Node = get_node_or_null("/root/Settings")
	_revealed = 0 if settings == null or bool(settings.values.get("typewriter", true)) else _total
	if _lines.size() * 12 + 10 > box.size.y: issues.append("bubble text exceeds available height")
	var panel: TextureRect = G2.box(self, box, {"r":4, "rings":["z", "u"], "fill":"y"})
	panel.name = "ApprovedBubble"
	panel.show_behind_parent = true
	for index: int in _lines.size():
		_labels.append(G2.text(self, box.position + Vector2(6, 6 + index * 12), _lines[index], "u" if thought else "t", true))
	if not name_text.is_empty():
		var name_width: int = G2.measure(name_text, true) + 8
		var name_at := Vector2(clampf(box.position.x + 5, 4, 316 - name_width), maxf(21, box.position.y - 9))
		G2.tag(self, name_at, name_text)
	_update_reveal()
	queue_redraw()

func _process(delta: float) -> void:
	if _revealed < _total:
		_revealed = minf(_total, _revealed + delta * 30)
		_update_reveal()

func reveal_all() -> void:
	_revealed = _total
	_update_reveal()

func _update_reveal() -> void:
	var remaining: int = floori(_revealed)
	for label: Label in _labels:
		label.visible_characters = maxi(0, remaining)
		remaining -= label.text.length()

func _draw() -> void:
	var G2: GDScript = load("res://presentation/ui/widgets/g2.gd")
	var y: int = int(box.position.y if below else box.end.y) - (2 if not below else 0)
	var direction: int = -1 if below else 1
	if _thought:
		for step: int in 3:
			var radius: int = 2 if step == 0 else 1
			var center := Vector2(tail_x + step * 3, y + direction * (3 + step * 4))
			draw_circle(center, radius + 1, G2.RASTER.color_of("z"))
			draw_circle(center, radius, G2.RASTER.color_of("u"))
			if step == 0: draw_circle(center, 1, G2.RASTER.color_of("y"))
	else:
		for step: int in 6:
			var span: int = 6 - step
			draw_rect(Rect2(tail_x - 3, y + direction * step, span, 1), G2.RASTER.color_of("z"))
			if span > 2: draw_rect(Rect2(tail_x - 2, y + direction * step, span - 2, 1), G2.RASTER.color_of("u"))
			if span > 4: draw_rect(Rect2(tail_x - 1, y + direction * step, span - 4, 1), G2.RASTER.color_of("y"))

static func _wrap(value: String, face: Font, width: float, font_size: int = 10) -> PackedStringArray:
	var expression := RegEx.new()
	expression.compile("[　-鿿가-힯＀-￯]|[^\\s　-鿿가-힯＀-￯]+|\\s+")
	var lines := PackedStringArray()
	var line: String = ""
	for match_result: RegExMatch in expression.search_all(value):
		var token: String = match_result.get_string()
		if token.contains("\n"):
			lines.append(line.rstrip(" \t"))
			line = ""
		elif token.strip_edges().is_empty():
			if not line.is_empty(): line += " "
		elif line.is_empty() or face.get_string_size(line + token, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x <= width:
			line += token
		else:
			if "，。：；、！？）」』”…,.:;!?)".contains(token.left(1)) and line.length() > 1:
				lines.append(line.left(-1).rstrip(" \t"))
				line = line.right(1) + token
			else:
				lines.append(line.rstrip(" \t"))
				line = token
	if not line.is_empty(): lines.append(line.rstrip(" \t"))
	return lines
