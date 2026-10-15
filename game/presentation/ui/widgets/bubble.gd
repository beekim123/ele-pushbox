class_name PortitorBubble
extends Control
## Reusable text layout. Pending bubble art is a conspicuous flat placeholder.
var issues: Array[String] = []
var box: Rect2
var below: bool = false
var tail_x: float = 0
var _lines: PackedStringArray = []
var _revealed: float = 0
var _total: int = 0

func configure(text: String, speaker: Vector2, name_text: String, placeholder_text: String) -> void:
	for child: Node in get_children():
		child.queue_free()
	var face: Font = PortitorUI.font(true)
	var lines: PackedStringArray = _wrap(text, face, 158)
	_lines = lines
	_total = text.length()
	var settings: Node = get_node_or_null("/root/Settings")
	_revealed = 0 if settings == null or bool(settings.values.get("typewriter", true)) else _total
	issues.clear()
	if lines.size() > 4:
		issues.append("bubble exceeds four lines")
	var width: float = 16
	for line: String in lines:
		width = maxf(width, face.get_string_size(line, HORIZONTAL_ALIGNMENT_LEFT, -1, 10).x)
	width = minf(168, width + 10)
	var height: float = min(4, lines.size()) * 12 + 7
	below = speaker.y - 4 - height - 2 < 22
	box = Rect2(clampf(roundf(speaker.x - width / 2), 3, 317 - width), minf(177 - height, speaker.y + 24) if below else speaker.y - height - 6, width, height)
	tail_x = clampf(speaker.x, box.position.x + 5, box.end.x - 6)
	var title: String = name_text + " · " + placeholder_text
	var title_width: float = minf(310, PortitorUI.font().get_string_size(title, HORIZONTAL_ALIGNMENT_LEFT, -1, 12).x + 2)
	var name_tag: Label = PortitorUI.label(title, title_width)
	name_tag.position = Vector2(clampf(box.position.x + 4, 3, 317 - title_width), maxf(0, box.position.y - 14))
	name_tag.add_theme_color_override("font_color", PortitorUI.GOLD)
	add_child(name_tag)
	queue_redraw()

func _process(delta: float) -> void:
	if _revealed < _total:
		_revealed = minf(_total, _revealed + delta * 30)
		queue_redraw()

func reveal_all() -> void:
	_revealed = _total
	queue_redraw()

func _draw() -> void:
	draw_rect(box, Color("e4a672"))
	var x: float = tail_x
	var y: float = box.position.y if below else box.end.y
	draw_rect(Rect2(x, y - 4 if below else y, 2, 4), Color("e4a672"))
	var remaining: int = floori(_revealed)
	for line_index: int in mini(4, _lines.size()):
		var line: String = _lines[line_index]
		draw_string(PortitorUI.font(true), box.position + Vector2(5, 13 + line_index * 12), line.left(maxi(0, remaining)), HORIZONTAL_ALIGNMENT_LEFT, -1, 10, Color("3e2731"))
		remaining -= line.length()

static func _wrap(text: String, face: Font, width: float) -> PackedStringArray:
	var lines := PackedStringArray()
	var current: String = ""
	var tokens: PackedStringArray = text.split(" ") if text.contains(" ") else text.split("")
	var separator: String = " " if text.contains(" ") else ""
	for token: String in tokens:
		var candidate: String = current + (separator if not current.is_empty() else "") + token
		if face.get_string_size(candidate, HORIZONTAL_ALIGNMENT_LEFT, -1, 10).x > width and not current.is_empty() and not "，。！？；：、,.!?;:".contains(token):
			lines.append(current)
			current = token
		else:
			current = candidate
	if not current.is_empty():
		lines.append(current)
	return lines
