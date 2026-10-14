extends CanvasLayer
## The only persistent UI: room name and physical inventory icons.
const Style := preload("res://pushbox/scripts/ui/pixel_style.gd")
const ROOM_NAMES := ["梯子", "挖与倒", "放水", "压板与炸药", "炸沙抬水位"]
var painter: Node2D
var session: RefCounted
var room_index: int = 0
var room_age: float = 0.0
var idle_seconds: float = 0.0
var dragging: bool = false
var pointer: Vector2 = Vector2.ZERO
var bag_bounce: float = 0.0
var _show_bag: bool = false
var _bag: int = 0
var _bombs: int = 0
var _gained: bool = false

func _ready() -> void:
	painter = Node2D.new()
	painter.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	add_child(painter)
	painter.draw.connect(_draw_hud)

func set_room(source: RefCounted, index: int) -> void:
	session = source
	room_index = index
	room_age = 0.0
	idle_seconds = 0.0
	_show_bag = source.level.legend.values().has("sand") and source.level.map.any(func(row: String) -> bool: return row.contains("s"))
	update_state(source)

func update_state(source: RefCounted, _tool: String = "", _previewing: bool = false) -> void:
	session = source
	var next: int = source.board.total_bag()
	if next != _bag:
		_gained = next > _bag
		bag_bounce = 0.25
	_bag = next
	_bombs = source.board.bombs
	painter.queue_redraw()

func _process(delta: float) -> void:
	room_age += delta
	idle_seconds += delta
	bag_bounce = maxf(0.0, bag_bounce - delta)
	if room_age < 3.5 or idle_seconds > 60.0 or dragging or bag_bounce > 0:
		painter.queue_redraw()

func bomb_rects() -> Array[Rect2]:
	var result: Array[Rect2] = []
	var bags: int = maxi(1, ceili(_bag / 256.0)) if _show_bag or _bag > 0 else 0
	var x: float = bag_position().x - bags * 14.0
	for i in _bombs:
		result.append(Rect2(x - i * 14, 5, 12, 12))
	return result

func bomb_at(at: Vector2) -> bool:
	for rect in bomb_rects():
		if rect.has_point(at):
			return true
	return false

func bag_position() -> Vector2:
	return Vector2(get_viewport().get_visible_rect().size.x - 16, 5)

func _draw_hud() -> void:
	if session == null:
		return
	var color := Color.WHITE
	color.a = 1.0 if room_age < 3.0 else 0.55
	Style.text(painter, "%d · %s" % [room_index + 1, ROOM_NAMES[room_index]], Vector2(7, 15), color)
	if idle_seconds > 60.0:
		Style.text(painter, "Esc 可以看提示", Vector2(7, 29), Color(1, 1, 1, minf(0.6, (idle_seconds - 60.0) / 2.0)))
	if _show_bag or _bag > 0:
		var count: int = maxi(1, ceili(_bag / 256.0))
		for i in count:
			var fill: int = mini(7, roundi(clampi(_bag - i * 256, 0, 256) / 256.0 * 7))
			painter.draw_texture(Style.texture("icon_sandbag_%d" % fill), bag_position() - Vector2(i * 14, 1 if bag_bounce > 0.12 else 0))
		if bag_bounce > 0.12 and _gained:
			Style.text(painter, "+", bag_position() + Vector2(1, 25), Style.YELLOW)
	# Bombs sit left of all bags, with one independent draggable icon per bomb.
	for rect in bomb_rects():
		painter.draw_texture(Style.texture("icon_bomb"), rect.position)
	if dragging:
		painter.draw_texture(Style.texture("icon_bomb"), (pointer - Vector2(6, 6)).round())
