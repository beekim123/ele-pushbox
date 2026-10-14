extends Node2D
## Sprite presentation and hover overlays at one SDK cell per screen pixel.
const Style := preload("res://pushbox/scripts/ui/pixel_style.gd")
const Art := preload("res://pushbox/scripts/art/art_registry.gd")
const Gates := preload("res://pushbox/scripts/render/gate_painter.gd")
const SIZE := 16.0
var theme_id: String = "dungeon"
var board: RefCounted
var outlines: bool = false
var preview: Dictionary = {}
var hover_action: String = ""
var pointer: Vector2 = Vector2.ZERO
var classes := PackedStringArray()
var _from: Dictionary = {}
var _to: Dictionary = {}
var fraction: float = 1.0
var message: String = ""
var action: String = ""
var winning: bool = false
var draw_us: int = 0
var _read_revision: int = -1
var draw_frame: int = -1
var clock: float = 0.0
var _anim_frame: int = -1
var _pose_left: float = 0.0
var _facing: int = 1
var _gate_from: Dictionary = {}
var _gate_to: Dictionary = {}
var _gate_age: float = 1.0
var _particles: Array[Dictionary] = []
var _flash_frames: int = 0
var _shake_frames: int = 0
var entrance: float = 0.0
var exit_fade: float = 0.0
var inventory_anchor := Vector2(310, 11)

func set_outlines(value: bool) -> void:
	outlines = value
	if value and board != null and board.ids.size() == 61440:
		classes = board.categories()
	queue_redraw()

func _ready() -> void:
	RenderingServer.frame_post_draw.connect(_after_render)

func _after_render() -> void:
	if _flash_frames > 0:
		_flash_frames = 0
		queue_redraw()

func _process(delta: float) -> void:
	clock += delta
	_pose_left = maxf(0.0, _pose_left - delta)
	_gate_age = minf(1.0, _gate_age + delta * 10.0)
	entrance = maxf(0.0, entrance - delta * 3.0)
	for particle in _particles:
		particle.age += delta
	_particles = _particles.filter(func(item: Dictionary) -> bool: return item.age < item.life)
	var next_frame: int = int(clock * 8)
	if next_frame != _anim_frame or not _particles.is_empty() or _gate_age < 1.0 or entrance > 0:
		_anim_frame = next_frame
		queue_redraw()

func feedback(next_action: String, amount: int) -> void:
	action = next_action
	_pose_left = 0.4
	if next_action.ends_with("_L") or next_action == "L":
		_facing = -1
	elif next_action.ends_with("_R") or next_action == "R":
		_facing = 1
	var at: Vector2 = Vector2(board.player + board._direction(next_action)) * 16 + Vector2(8,8)
	if next_action.begins_with("BOMB"):
		_flash_frames = 1
		_shake_frames = 4
		_emit(at, Art.theme(theme_id).colors.particle_rock, 12)
	elif next_action.begins_with("DIG"):
		_emit(at, Art.theme(theme_id).colors.particle_sand, 4)
		if amount > 0:
			_particles.append({"at": at, "velocity": Vector2.ZERO, "age": 0.0, "life": 0.55, "color": Color("fee761"), "fly": true})
	elif next_action.begins_with("POUR"):
		_emit(at, Art.theme(theme_id).colors.sand_light, 4)
	queue_redraw()

func _emit(at: Vector2, color: Color, count: int = 4) -> void:
	for i in count:
		_particles.append({"at": at, "velocity": Vector2((i % 5 - 2) * 13, -18 - (i % 3) * 8), "age": 0.0, "life": 0.45 + (i % 3) * 0.07, "color": color, "fly": false})

func shake_offset() -> Vector2:
	if _shake_frames <= 0:
		return Vector2.ZERO
	return Vector2([2, -2, 1, -1][_shake_frames - 1], 0)

func visual_tick() -> void:
	if _flash_frames > 0 or _shake_frames > 0:
		queue_redraw()
	_shake_frames = maxi(0, _shake_frames - 1)


func sync(animated: bool = false) -> void:
	var next: Dictionary = {"player": Vector2(board.player) * SIZE}
	for box in board.boxes:
		next[box.id] = Vector2(box.at) * SIZE
	var gates: Dictionary = {}
	for gate in board.gates:
		gates[gate.id] = gate.open
	if gates != _gate_to:
		_gate_from = _gate_to.duplicate()
		_gate_to = gates
		_gate_age = 0.0 if not _gate_from.is_empty() else 1.0
	var redraw: bool = next != _to or fraction != 1.0
	if animated:
		for actor in next:
			if _to.has(actor) and next[actor].y > _to[actor].y:
				var tile := Vector2i(next[actor] / 16)
				var water: bool = tile.y < 11 and board.counts(tile + Vector2i.DOWN).fluid > 0
				_emit(next[actor] + Vector2(8, 15), Color("2ce8f5") if water else Color("8b9bb4"), 4)
	_from = _to.duplicate()
	_to = next
	fraction = 0.0 if animated and not _from.is_empty() else 1.0
	if board.ids.size() == 61440 and _read_revision != board.read_revision:
		if outlines:
			classes = board.categories()
		_read_revision = board.read_revision
		redraw = true
	if redraw:
		queue_redraw()

func _point(key: String) -> Vector2:
	var target: Vector2 = _to.get(key, Vector2.ZERO)
	var start: Vector2 = _from.get(key, target)
	if key == "player" and absf(target.x - start.x) == SIZE and start.y - target.y == SIZE:
		var corner := Vector2(start.x, target.y)
		return (start.lerp(corner, fraction * 2) if fraction < 0.5 else corner.lerp(target, fraction * 2 - 1)).round()
	return start.lerp(target, fraction).round()

func _sprite(name: String, at: Vector2, color: Color = Color.WHITE) -> void:
	draw_texture(Style.themed_texture(name,theme_id), at.round(), color)

func _box_sprite(box: Dictionary) -> String:
	return "crate_iron_0" if box.get("kind","wood") == "iron" else "crate_static_0"

func _draw_gate_tile(tile: Vector2i, i: int, count: int, openness: float) -> void:
	Gates.tile(self,Vector2(tile)*SIZE,theme_id,i,count,openness)

func _dashed(rect: Rect2, color: Color) -> void:
	for x in range(0, int(rect.size.x), 4):
		draw_line(rect.position + Vector2(x, 0), rect.position + Vector2(x + 1, 0), color)
		draw_line(rect.end - Vector2(x, 0), rect.end - Vector2(x + 1, 0), color)
	for y in range(0, int(rect.size.y), 4):
		draw_line(rect.position + Vector2(0, y), rect.position + Vector2(0, y + 1), color)
		draw_line(rect.end - Vector2(0, y), rect.end - Vector2(0, y + 1), color)

func _draw() -> void:
	var started: int = Time.get_ticks_usec()
	draw_frame = Engine.get_process_frames()
	if board == null:
		return
	var lantern: Vector2 = Vector2(board.origin) * 16 + Vector2(int((20 - board.origin.x * 2) / 2) * 16, 16)
	_sprite("lantern_idle_%d" % (int(clock * 2) % 2), lantern)
	for at in board.targets:
		_sprite("target_%s_%d" % ["lit" if winning or board.box_at(at) >= 0 else "idle", int(clock * 8) % (2 if winning or board.box_at(at) >= 0 else 4)], Vector2(at) * SIZE)
		if winning or board.box_at(at) >= 0:
			draw_rect(Rect2(Vector2(at) * 16 + Vector2(1,1), Vector2(14,14)), Style.YELLOW, false)
	for at in board.ladders:
		_sprite("ladder_static_0", Vector2(at) * SIZE)
	for lever in board.levers:
		_sprite("lever_right_0" if lever.on else "lever_left_0", Vector2(lever.at) * SIZE)
	for gate in board.gates:
		if gate.open_when.has("plate"):
			var at: Array = gate.open_when.plate
			var tile: Vector2i = board.origin + Vector2i(at[0], at[1])
			_sprite("plate_down_0" if gate.open else "plate_up_0", Vector2(tile) * SIZE + Vector2(0, 12))
		for i in gate.tiles.size():
			var tile: Vector2i = gate.tiles[i]
			var before: float = 1.0 if _gate_from.get(gate.id, gate.open) else 0.0
			var after: float = 1.0 if gate.open else 0.0
			_draw_gate_tile(tile,i,gate.tiles.size(),lerpf(before,after,_gate_age))
	if outlines:
		for i in classes.size():
			if classes[i] in ["SAND", "WATER"]:
				draw_rect(Rect2(Vector2(i % 20, i / 20) * SIZE, Vector2(16, 16)), Color("fee761") if classes[i] == "SAND" else Color("2ce8f5"), false)
	for box in board.boxes:
		var bob: float = 0.0
		if board.ids.size() == 61440 and box.at.y < 11 and board.counts(box.at + Vector2i.DOWN).fluid >= 64:
			bob = 1.0 if int(clock * 2) % 2 == 0 and fraction == 1.0 else 0.0
		_sprite(_box_sprite(box), _point(box.id) + Vector2(0, -bob))
		if winning and int(clock * 8) % 2 == 0:
			draw_rect(Rect2(_point(box.id) + Vector2(1,1),Vector2(14,14)), Color.WHITE, false)
	var p: Vector2 = _point("player")
	var pose: String = "idle"
	var frame_count: int = 2
	if winning:
		pose = "win"
	elif fraction < 1.0 and _from.get("player", p).y < _to.get("player", p).y:
		pose = "fall"; frame_count = 1
	elif _pose_left > 0 or fraction < 1.0:
		if action.begins_with("DIG"): pose = "dig"; frame_count = 3
		elif action.begins_with("POUR"): pose = "pour"; frame_count = 3
		elif action in ["U", "D"]: pose = "climb"
		elif action in ["L", "R"]:
			pose = "walk"; frame_count = 4
			for box in board.boxes:
				if _from.get(box.id, _to.get(box.id)) != _to.get(box.id):
					pose = "push"
	var miner: Texture2D = Style.themed_texture("miner_%s_%d" % [pose, int(clock * 8) % frame_count],theme_id)
	var miner_rect := Rect2(p, Vector2(16 * _facing,16))
	draw_texture_rect(miner, miner_rect, false)
	if not message.is_empty():
		var width: float = Style.font().get_string_size(message, HORIZONTAL_ALIGNMENT_LEFT, -1, 12).x
		Style.text(self, message, Vector2(clampf(p.x + 8 - width / 2, 4, 316 - width), p.y - 5), Style.YELLOW)
	if winning:
		Style.text(self, "过关", Vector2(148, 34), Style.YELLOW)
	if not hover_action.is_empty():
		var target: Vector2i = board.player + board._direction(hover_action)
		var color: Color = Color("f77622") if hover_action.begins_with("DIG") else Style.YELLOW
		draw_rect(Rect2(Vector2(target) * SIZE, Vector2(16, 16)), color, false)
		if hover_action.begins_with("BOMB"):
			draw_arc(Vector2(target) * SIZE + Vector2(8,8), float(board.rules.bomb.radius_cells), 0, TAU, 64, Color("feae34"))
		else:
			_sprite("cursor_shovel" if hover_action.begins_with("DIG") else "icon_sandbag_7", pointer)
	if not preview.is_empty():
		for tile in preview.changed:
			var category: String = preview.categories[tile.y * 20 + tile.x]
			var color: Color = {"SAND": Color("ead4aa"), "WATER": Color("2ce8f5"), "SOLID": Color("c0cbdc"), "BOX": Style.YELLOW}.get(category, Style.WHITE)
			_dashed(Rect2(Vector2(tile) * SIZE + Vector2(1, 1), Vector2(14, 14)), color)
		var flash: float = 0.3 + 0.15 * sin(Time.get_ticks_msec() / 150.0)
		for cell in preview.removed:
			draw_rect(Rect2(Vector2(cell), Vector2.ONE), Color(0.8941, 0.2314, 0.2667, flash))
		if preview.player != board.player:
			_sprite("miner_idle_0", Vector2(preview.player) * SIZE, Color(1,1,1,0.45))
			_dashed(Rect2(Vector2(preview.player) * SIZE, Vector2(15,15)), Style.WHITE)
		for box in preview.boxes:
			var old: Vector2i = Vector2i(-1,-1)
			for original in board.boxes:
				if original.id == box.id:
					old = original.at
			if box.at != old:
				_sprite(_box_sprite(box), Vector2(box.at) * SIZE, Color(1,1,1,0.45))
				_dashed(Rect2(Vector2(box.at) * SIZE, Vector2(15,15)), Style.YELLOW)
	for particle in _particles:
		var age: float = particle.age
		if particle.fly:
			var t: float = age / particle.life
			var at: Vector2 = (particle.at as Vector2).lerp(inventory_anchor, t) + Vector2(0, -sin(t * PI) * 24)
			draw_rect(Rect2(at.round(),Vector2(2,2)), particle.color)
		else:
			var at: Vector2 = particle.at + particle.velocity * age + Vector2(0,70 * age * age)
			draw_rect(Rect2(at.round(), Vector2.ONE), particle.color)
	if _flash_frames > 0:
		draw_rect(Rect2(-global_position, get_viewport_rect().size), Color.WHITE)
	if entrance > 0 or exit_fade > 0:
		draw_rect(Rect2(-global_position, get_viewport_rect().size), Color(Style.INK, maxf(entrance, exit_fade)))
	draw_us = Time.get_ticks_usec() - started
