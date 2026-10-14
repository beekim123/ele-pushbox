extends Node2D
## One data-driven instruction at a time; completion survives undo/restart.
signal learned
const Style := preload("res://pushbox/scripts/ui/pixel_style.gd")
var board: RefCounted
var level: Dictionary = {}
var progress: Dictionary = {}
var active: Dictionary = {}
var events: Dictionary = {}
var _timed_out: Dictionary = {}
var elapsed: float = 0.0
var shown_for: float = 0.0
var hint_action: String = ""
var hint_left: float = 0.0
var hand_start := Vector2(294, 18)

func configure(source: RefCounted, data: Dictionary, learned_progress: Dictionary) -> void:
	board = source
	level = data
	progress = learned_progress
	events = {}
	_timed_out = {}
	active = {}
	elapsed = 0.0
	shown_for = 0.0
	hint_action = ""
	hint_left = 0.0
	advance(0.0)
	queue_redraw()

func notify(event_name: String) -> void:
	events[event_name] = true
	advance(0.0)

func _key(item: Dictionary) -> String:
	return str(level.id) + ":" + str(item.id)

func _condition(expression: Variant) -> bool:
	if expression is String:
		return true if expression == "start" else events.has(expression)
	if expression is Dictionary:
		if expression.has("player_at"):
			return board.player == board.origin + Vector2i(expression.player_at[0], expression.player_at[1])
		if expression.has("all"):
			return expression.all.all(func(item: Variant) -> bool: return _condition(item))
		if expression.has("any"):
			return expression.any.any(func(item: Variant) -> bool: return _condition(item))
		if expression.has("not"):
			return not _condition(expression["not"])
		return board.condition(expression)
	return false

func advance(delta: float) -> void:
	if board == null:
		return
	elapsed += delta
	shown_for += delta
	hint_left = maxf(0.0, hint_left - delta)
	var old: String = active.get("id", "")
	var completed: bool = false
	for item in level.get("guides", []):
		if not progress.has(_key(item)) and _condition(item.get("done", "")):
			progress[_key(item)] = true
			completed = true
	active = {}
	for item in level.get("guides", []):
		if progress.has(_key(item)) or _timed_out.has(item.id):
			continue
		var after: String = item.get("after", "")
		if not after.is_empty() and not progress.has(str(level.id) + ":" + after):
			continue
		if old == item.id or _condition(item.get("start", "start")):
			active = item
			break
	if active.get("id", "") != old:
		shown_for = 0.0
	# Hand demos time out visually, without claiming the player has learned drag.
	if active.has("hand") and shown_for >= 2.0:
		_timed_out[active.id] = true
		active = {}
	if completed:
		learned.emit()
	if active.get("id", "") != old or not active.is_empty() or not hint_action.is_empty() or level.get("id") == "d1":
		queue_redraw()

func cancel_hint() -> void:
	hint_action = ""
	hint_left = 0.0
	queue_redraw()

func demonstrate(action: String) -> void:
	hint_action = action
	hint_left = 4.0
	queue_redraw()

func _caps(value: String, at: Vector2) -> void:
	var names: Array = {"UP": ["up"], "DOWN": ["down"], "LEFT": ["left"], "RIGHT": ["right"], "LEFT_RIGHT": ["left", "right"], "Z_R": ["z", "r"]}.get(value, [])
	for i in names.size():
		draw_texture(Style.texture("keycap_" + names[i]), (at + Vector2(i * 16, 0)).round())

func _instruction(item: Dictionary) -> void:
	if item.has("mouse"):
		var target: Array = item.mouse.at
		var at: Vector2 = Vector2(board.origin + Vector2i(target[0], target[1])) * 16 + Vector2(2,-20)
		at.y += -1 if int(elapsed * 3) % 2 == 0 else 0
		draw_texture(Style.texture("mouse_" + item.mouse.button), at.round())
		Style.text(self, item.get("text", ""), at + Vector2(16,11))
	elif item.has("keycap"):
		var point: Variant = item.get("point", "player")
		var at: Vector2 = Vector2(board.player) * 16 + Vector2(1,-17)
		if point is Array:
			at = Vector2(board.origin + Vector2i(point[0],point[1])) * 16 + Vector2(1,1)
		_caps(item.keycap, at)
		var offset: float = 32.0 if item.keycap in ["LEFT_RIGHT", "Z_R"] else 16.0
		Style.text(self, item.get("text", ""), at + Vector2(offset,11), Style.YELLOW)
	elif item.has("hand"):
		var t: float = fmod(shown_for, 1.0)
		var at: Vector2 = hand_start.lerp(Vector2(246,51), t)
		draw_texture(Style.texture("icon_bomb"), at.round())
		draw_texture(Style.texture("hand_drag"), (at + Vector2(3,7)).round())

func _draw() -> void:
	if board == null:
		return
	if level.id == "d1":
		Style.text(self, "Z 撤销 · R 重开", Vector2(board.origin) * 16 + Vector2(8,94))
	if hint_left > 0 and not hint_action.is_empty():
		if hint_action.contains("_"):
			var target: Vector2i = board.player + board._direction(hint_action) - board.origin
			var item: Dictionary = {"mouse": {"at": [target.x,target.y], "button": "left" if hint_action.begins_with("DIG") else "right"}, "text": "左键挖沙" if hint_action.begins_with("DIG") else "右键倒沙"}
			if hint_action.begins_with("BOMB"):
				var at: Vector2 = Vector2(board.player + board._direction(hint_action)) * 16
				draw_texture(Style.texture("hand_drag"), at + Vector2(2,-16))
				Style.text(self, "拖到这里", at + Vector2(16,-5), Style.YELLOW)
			else:
				_instruction(item)
		else:
			_instruction({"keycap": {"L":"LEFT", "R":"RIGHT", "U":"UP", "D":"DOWN", "USE":"UP"}.get(hint_action, "UP"), "text": "拉" if hint_action == "USE" else ""})
	elif not active.is_empty():
		_instruction(active)
