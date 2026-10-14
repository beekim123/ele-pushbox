extends Node2D
## Input and turn orchestration; settlement rules remain owned by Session.
const Session := preload("res://pushbox/scripts/session.gd")
const Preview := preload("res://pushbox/scripts/preview.gd")
const View := preload("res://pushbox/scripts/ui/board_view.gd")
const Hud := preload("res://pushbox/scripts/ui/hud.gd")
const Guide := preload("res://pushbox/scripts/ui/guide.gd")
const Style := preload("res://pushbox/scripts/ui/pixel_style.gd")
const Lobby := preload("res://pushbox/scripts/ui/lobby_view.gd")
const Showcase := preload("res://pushbox/scripts/ui/biome_showcase_view.gd")
const ThemeBinder := preload("res://pushbox/scripts/render/theme_shader_binder.gd")
const PauseMenu := preload("res://pushbox/scripts/ui/pause_menu.gd")
const Catalog := preload("res://pushbox/scripts/campaign_catalog.gd")
var campaign_map: int = 0
var _campaign_save_pending: bool = false
const BOARD_POSITION := Vector2.ZERO
var start_in_lobby: bool = not OS.get_cmdline_args().has("--script")
var progress_path: String = "user://progress.json"
var mode: String = "legacy"
var lobby: Node2D
var showcase: Node2D
var session: RefCounted
var preview: RefCounted
const Ecology := preload("res://pushbox/scripts/render/ambient_ecology.gd")
var ecology_background: Node2D
var background: Sprite2D
var view: Node2D
var hud: CanvasLayer
var pause_menu: Node2D
var guide: Node2D
var _guide_progress: Dictionary = {}
var level_index: int = 0
var preview_result: Dictionary = {}
var animation_left: int = 0
var skip_animation: bool = false
var _opening: bool = false
var _opening_failed: bool = false
var _replaying: bool = false
var _replay_index: int = 0
var _message_left: float = 0.0
var _pointer := Vector2(-100, -100)
var _hover_action: String = ""
var _hover_delay: int = 0
var _dragging: bool = false
var _victory_left: float = -1.0
var frame_us: Array[int] = []
var frame_timing: Dictionary = {}
var _board_position := Vector2.ZERO
var _world_origin := Vector2(INF, INF)
var _layout_queued: bool = false

func _ready() -> void:
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	Style.warm_assets()
	background = Sprite2D.new()
	background.centered = false
	background.region_enabled = true
	background.texture = Style.texture("cave_bg")
	add_child(background)
	ecology_background = Ecology.new()
	background.add_child(ecology_background)
	view = View.new()
	view.position = BOARD_POSITION
	view.z_index = 2
	add_child(view)
	guide = Guide.new()
	view.add_child(guide)
	_guide_progress = Session.Loader.json("user://guides-v03.json")
	guide.learned.connect(_save_guides)
	hud = Hud.new()
	add_child(hud)
	pause_menu = PauseMenu.new()
	hud.add_child(pause_menu)
	pause_menu.requested.connect(utility)
	pause_menu.level_selected.connect(_select_menu_level)
	pause_menu.outlines_changed.connect(view.set_outlines)
	lobby = Lobby.new()
	lobby.progress_path = progress_path
	lobby.z_index = 10
	add_child(lobby)
	lobby.level_selected.connect(select_tutorial)
	lobby.settings_requested.connect(_lobby_settings)
	lobby.showcase_requested.connect(open_showcase)
	lobby.campaign_selected.connect(select_campaign)
	lobby.observation_requested.connect(open_observation)
	showcase = Showcase.new()
	showcase.z_index = 11
	add_child(showcase)
	showcase.closed.connect(_close_showcase)
	get_viewport().size_changed.connect(_on_viewport_resized)
	if start_in_lobby:
		return_lobby()
	else:
		select_level(0)

func select_level(index: int) -> void:
	select_level_path("res://pushbox/levels/d%d.json" % (clampi(index, 0, 4) + 1), "legacy", clampi(index, 0, 4))

func select_tutorial(index: int) -> void:
	select_level_path("res://pushbox/levels/tutorial/t%02d.json" % (clampi(index, 0, 3) + 1), "tutorial", clampi(index, 0, 3))

func select_campaign(map: int, index: int) -> void:
	if not lobby.level_unlocked(map,index):
		return
	campaign_map = map
	lobby.map_index = map
	select_level_path(Catalog.path(map,index), "campaign", index)

func open_observation(map: int, index: int) -> void:
	return_lobby("campaign")
	lobby.conceal()
	showcase.open_campaign(map,index)
	_layout()

func _close_showcase() -> void:
	if showcase.campaign_mode:
		lobby.map_index = showcase.index
		return_lobby("campaign")
	else:
		return_lobby()

func _select_menu_level(index: int) -> void:
	if mode == "campaign":
		return_lobby("campaign")
	elif mode == "tutorial":
		select_tutorial(index)
	else:
		select_level(index)

func _lobby_settings() -> void:
	pause_menu.lobby_context = true
	pause_menu.opened = true
	pause_menu.page = "settings"
	pause_menu.selected = 0
	pause_menu.queue_redraw()

func return_lobby(page: String = "modes") -> void:
	if showcase != null:
		showcase.conceal()
	cancel_preview(true)
	_dragging = false
	hud.dragging = false
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
	lobby.save_progress()
	_campaign_save_pending = false
	close_sessions()
	hud.session = null
	hud.painter.hide()
	view.hide()
	view.set_process(false)
	background.hide()
	pause_menu.close()
	_victory_left = -1.0
	_replaying = false
	lobby.show_page(page, level_index if page == "campaign" and mode == "campaign" else 0)
	_layout()

func open_showcase() -> void:
	return_lobby()
	lobby.conceal()
	showcase.open()
	_layout()

func select_level_path(path: String, next_mode: String = "legacy", index: int = 0) -> void:
	showcase.conceal()
	close_sessions()
	mode = next_mode
	level_index = index
	lobby.conceal()
	background.show()
	view.show()
	view.set_process(true)
	hud.painter.show()
	pause_menu.lobby_context = false
	pause_menu.tutorial = mode == "tutorial"
	pause_menu.campaign = mode == "campaign"
	session = Session.new()
	var reason: String = session.load_level(path, self, true)
	if not reason.is_empty():
		push_error(reason)
		return_lobby("tutorial")
		return
	session.world.position = BOARD_POSITION
	session.world.z_index = 1
	view.theme_id = session.level.get("theme_id","dungeon")
	background.texture = Style.Art.background(view.theme_id,Vector2i(320,180)) if mode == "campaign" else Style.themed_texture("cave_bg",view.theme_id)
	ecology_background.visible = mode == "campaign"
	ecology_background.theme_id = view.theme_id
	ecology_background.seed = int(session.level.seed)
	ecology_background.extent = Vector2(320,180)
	view.ecology_enabled = mode == "campaign"
	view.ecology_background = ecology_background
	view.ecology_points = Ecology.anchors(session.level,Vector2(session.board.origin)*16) if mode == "campaign" else {}
	# Theme variants can read back baseline textures. Prepare every animation
	# pose during loading so first victory/tool poses never stall settlement.
	for sprite_name in Style.Art.names():
		Style.themed_texture(sprite_name,view.theme_id)
	Style.themed_texture("crate_iron_0",view.theme_id)
	for prop in session.board.Biome.props(session.board):
		Style.themed_texture(prop.sprite,view.theme_id)
		for f in 4:
			Style.themed_texture(Ecology.prop_name(prop.sprite,f/4.0),view.theme_id)
	_configure_render()
	background.position = Vector2(session.board.origin) * 16
	background.region_rect = Rect2(Vector2.ZERO,Vector2(320,180)) if mode == "campaign" else Rect2(background.position, Vector2(session.level.map[0].length() * 16, session.level.map.size() * 16))
	preview = Preview.new()
	reason = preview.configure(session, self)
	if not reason.is_empty():
		push_error(reason)
	view.board = session.board
	view.preview = {}
	view.hover_action = ""
	view._to.clear()
	view._read_revision = -1
	view.message = ""
	view.winning = false
	view.sync()
	view.entrance = 1.0
	view.exit_fade = 0.0
	guide.configure(session.board, session.level, _guide_progress)
	preview_result = {}
	_hover_action = ""
	_dragging = false
	hud.dragging = false
	animation_left = 0
	skip_animation = false
	_opening = true
	_opening_failed = false
	_replaying = false
	_replay_index = 0
	_victory_left = -1.0
	pause_menu.close()
	hud.set_room(session, level_index)
	_layout()

func _layout() -> void:
	var window := get_window()
	var base: Vector2i = Vector2i(320,180)
	var pixel_scale: int = maxi(1, floori(minf(window.size.x / float(base.x), window.size.y / float(base.y))))
	var canvas := Vector2i(maxi(base.x, window.size.x / pixel_scale), maxi(base.y, window.size.y / pixel_scale))
	if window.content_scale_size != canvas:
		window.content_scale_size = canvas
	_board_position = ((get_viewport_rect().size - Vector2(320, 180)) / 2).round()
	lobby.position = _board_position
	if showcase != null and showcase.visible:
		showcase.position = _board_position
		showcase.refresh_world_origin()
	if session == null:
		pause_menu.queue_redraw()
		return
	view.position = _board_position
	session.world.position = _board_position
	background.position = _board_position if mode == "campaign" else _board_position + Vector2(session.board.origin) * 16
	view.inventory_anchor = hud.bag_position() + Vector2(6, 6) - _board_position
	var bombs: Array[Rect2] = hud.bomb_rects()
	if not bombs.is_empty():
		guide.hand_start = bombs[0].position + Vector2(-10, 13) - _board_position
	_refresh_world_origin()
	hud.painter.queue_redraw()
	pause_menu.queue_redraw()
	view.queue_redraw()

func _on_viewport_resized() -> void:
	if _layout_queued:
		return
	# Window attaches its screen rect after emitting size_changed. Resizing
	# inside that signal lets the outer update overwrite the new attachment.
	_layout_queued = true
	_apply_resize.call_deferred()

func _apply_resize() -> void:
	_layout_queued = false
	cancel_preview()
	_layout()
	if session == null:
		return
	_pointer = get_viewport().get_mouse_position()
	_sync_pointer()

func _sync_pointer() -> void:
	hud.pointer = _pointer
	view.pointer = view.to_local(_pointer)

func _refresh_world_origin() -> void:
	var at: Vector2 = session.world.global_position
	if at == _world_origin:
		return
	_world_origin = at
	for sprite in session.world.get_children():
		if sprite is Sprite2D and sprite.material is ShaderMaterial:
			sprite.material.set_shader_parameter("world_origin", at)

func _configure_render() -> void:
	_world_origin = Vector2(INF, INF)
	for sprite in session.world.get_children():
		if not sprite is Sprite2D or not sprite.material is ShaderMaterial:
			continue
		var shader_material: ShaderMaterial = sprite.material
		var ids: Dictionary = {}
		for material_name in ThemeBinder.MATERIAL_NAMES:
			ids[material_name] = session.board.name_ids.get(material_name,-1)
		ThemeBinder.apply(shader_material,view.theme_id,ids)
		shader_material.set_shader_parameter("room_rect", Vector4(session.board.origin.x * 16, session.board.origin.y * 16, session.level.map[0].length() * 16, session.level.map.size() * 16))

func _physics_process(_delta: float) -> void:
	if session == null or not is_instance_valid(session.world) or pause_menu.opened:
		return
	if _campaign_save_pending and not session.running:
		var save_start: int = Time.get_ticks_usec()
		var save_phase: String = "CAMPAIGN_COMMIT" if lobby._staged_save else "CAMPAIGN_WRITE"
		if lobby._staged_save:
			lobby.commit_progress()
			_campaign_save_pending = false
		elif lobby._write_task >= 0:
			if lobby.finish_progress_write() and not lobby._write_success:
				_campaign_save_pending = false
		elif not lobby.begin_progress_write():
			_campaign_save_pending = false
		frame_timing = {"phase":save_phase, "bookkeeping_us":Time.get_ticks_usec()-save_start}
		frame_us.append(Time.get_ticks_usec()-save_start)
		return
	if animation_left > 0 and not skip_animation:
		animation_left -= 1
		view.fraction = 1.0 - animation_left / 6.0
		view.queue_redraw()
		return
	animation_left = 0
	view.fraction = 1.0
	if _opening and not session.running:
		if _opening_failed:
			return
		var start: int = Time.get_ticks_usec()
		if session._opening_task < 0:
			session.begin_opening_snapshot()
		if session.opening_snapshot_finished():
			if session.initial.is_empty():
				_opening_failed = true
				_message("无法保存，按 R 重试")
			else:
				_opening = false
		hud.update_state(session)
		frame_timing = {"bookkeeping_us": Time.get_ticks_usec() - start}
		frame_us.append(Time.get_ticks_usec() - start)
		return
	if session.running:
		var start: int = Time.get_ticks_usec()
		var before: String = session.board.actors_key()
		if skip_animation:
			session.advance(1200)
		else:
			session.advance_frame(1 if _opening else int(session.board.rules.settle.play_speed))
		var ticked: int = Time.get_ticks_usec()
		var moved: bool = before != session.board.actors_key()
		view.sync(moved and not skip_animation)
		var viewed: int = Time.get_ticks_usec()
		if moved and not skip_animation:
			animation_left = 6
		if not session.running and not _opening:
			if not session.errors.is_empty():
				push_warning("; ".join(session.errors))
			if session.board.trapped:
				_message("? 按 Z 撤销")
			if session.board.won():
				if mode in ["campaign","tutorial"]:
					lobby.mark_completed(session.level.id,true)
					_campaign_save_pending = true
				_victory_left = 1.5
				view.winning = true
		hud.update_state(session)
		frame_timing = {"tick_us": ticked - start, "pump_us":session.last_pump_us,"sdk_step_us":session.last_sdk_step_us, "phase": session.last_work_phase, "read_us": session.last_read_us, "count_us": session.last_count_us, "resolve_us": session.last_resolve_us, "key_us": session.last_key_us, "view_us": viewed - ticked, "bookkeeping_us": Time.get_ticks_usec() - viewed}
		frame_us.append(Time.get_ticks_usec() - start)
	elif _replaying:
		if _replay_index < session.level.solution.size():
			request_action(session.level.solution[_replay_index])
			_replay_index += 1
		else:
			_replaying = false
	elif not _hover_action.is_empty():
		if _hover_delay > 0:
			_hover_delay -= 1
		elif preview.pending:
			_accept_preview(preview.advance_budget())
		elif preview_result.is_empty():
			_accept_preview(preview.begin(session, _hover_action, true))

func _process(delta: float) -> void:
	if session == null or pause_menu.opened:
		return
	var shake: Vector2 = view.shake_offset()
	view.position = _board_position + shake
	session.world.position = _board_position + shake
	_refresh_world_origin()
	_sync_pointer()
	view.visual_tick()
	if not _opening:
		guide.advance(delta)
	if _message_left > 0:
		_message_left -= delta
		if _message_left <= 0:
			view.message = ""
			view.queue_redraw()
	if _victory_left > 0 and not _replaying and not _campaign_save_pending:
		_victory_left -= delta
		view.exit_fade = clampf((0.3 - _victory_left) / 0.3, 0.0, 1.0) if mode == "tutorial" or level_index < 4 else 0.0
		view.queue_redraw()
		if _victory_left <= 0:
			if mode == "campaign":
				return_lobby("campaign")
			elif mode == "tutorial":
				if level_index == 3:
					return_lobby()
				else:
					select_tutorial(level_index + 1)
			elif level_index < 4:
				select_level(level_index + 1)
			return
	if not session.running and animation_left == 0 and not _opening and not _replaying and _victory_left < 0:
		_update_hover()
	if not preview_result.is_empty():
		view.queue_redraw()

func _message(value: String) -> void:
	view.message = value
	_message_left = 1.5
	view.queue_redraw()

func cancel_preview(invalidate: bool = false) -> void:
	preview_result = {}
	_hover_action = ""
	if preview != null:
		preview.pending = false
		if invalidate:
			preview.invalidate()
	if view != null:
		view.preview = {}
		view.hover_action = ""
		view.queue_redraw()
	Input.set_mouse_mode(Input.MOUSE_MODE_HIDDEN if _dragging else Input.MOUSE_MODE_VISIBLE)

func _action_at(at: Vector2, mode: String = "hover") -> String:
	at = view.to_local(at)
	if at.x < 0 or at.x >= 320 or at.y < 0 or at.y >= 180:
		return ""
	var tile := Vector2i(floori(at.x / 16), floori(at.y / 16))
	var direction: Vector2i = tile - session.board.player
	var suffix: String = {Vector2i.LEFT: "L", Vector2i.RIGHT: "R", Vector2i.DOWN: "D"}.get(direction, "")
	if mode == "bomb":
		var bomb: String = "BOMB_" + suffix
		return bomb if not suffix.is_empty() and session.board.action_reason(bomb).is_empty() else ""
	if mode == "left" and tile == session.board.player and session.board.action_reason("USE").is_empty():
		return "USE"
	if suffix.is_empty():
		return ""
	var dig: String = "DIG_" + suffix
	var pour: String = "POUR_" + suffix
	if mode in ["hover", "left"] and session.board.action_reason(dig).is_empty():
		return dig
	if mode in ["hover", "right"] and direction != Vector2i.DOWN and session.board.action_reason(pour).is_empty():
		return pour
	return ""

func _update_hover() -> void:
	var next: String = _action_at(_pointer, "bomb" if _dragging else "hover")
	Input.set_mouse_mode(Input.MOUSE_MODE_HIDDEN if not next.is_empty() or _dragging else Input.MOUSE_MODE_VISIBLE)
	if next == _hover_action:
		return
	cancel_preview()
	_hover_action = next
	view.hover_action = next
	_hover_delay = 0
	view.queue_redraw()
	Input.set_mouse_mode(Input.MOUSE_MODE_HIDDEN if not next.is_empty() or _dragging else Input.MOUSE_MODE_VISIBLE)
	if not next.is_empty():
		# Start on the pointer frame, including one existing 3.5ms work slice.
		# Waiting for the next physics frame to begin added two idle display
		# frames to long water previews. The cloned Session/rules stay identical.
		_accept_preview(preview.begin(session, next, true))
		if preview.pending:
			_accept_preview(preview.advance_budget())

func _accept_preview(result: Dictionary) -> void:
	if result.is_empty() or result.get("action") != _hover_action:
		return
	if not result.get("legal", false):
		return
	preview_result = result
	view.preview = result
	view.queue_redraw()

func request_direction(direction: String) -> void:
	if session == null:
		return
	request_action("USE" if direction == "U" and session.board.action_reason("USE").is_empty() else direction)

func request_action(action: String, _direct: bool = true) -> void:
	if session == null or session.running or animation_left > 0 or _opening or _campaign_save_pending or pause_menu.opened or view.winning:
		return
	var reason: String = session.board.action_reason(action)
	if not reason.is_empty():
		_message(reason)
		return
	cancel_preview(true)
	_victory_left = -1.0
	view.winning = false
	var before: String = session.board.actors_key()
	var result: Dictionary = session.perform(action, true)
	if result.legal:
		guide.cancel_hint()
		hud.idle_seconds = 0.0
		view.feedback(action, int(result.get("amount", 0)))
		if action == "USE":
			guide.notify("lever_used")
		elif action.begins_with("DIG"):
			guide.notify("dug")
		elif action.begins_with("POUR"):
			guide.notify("poured")
		elif before != session.board.actors_key():
			guide.notify("moved")
		view.sync(before != session.board.actors_key())
		if before != session.board.actors_key() and not skip_animation:
			animation_left = 6
		skip_animation = false
		hud.update_state(session)
	else:
		_message(result.reason)

func utility(action: String) -> void:
	if _campaign_save_pending:
		lobby.save_progress()
		_campaign_save_pending = false
	if action == "quit":
		get_tree().quit()
		return
	if action == "campaign_pool":
		return_lobby("campaign")
		return
	if action == "lobby":
		return_lobby("campaign" if mode == "campaign" else "modes")
		return
	if action == "reset_guides":
		_guide_progress.clear()
		if session != null:
			guide.configure(session.board, session.level, _guide_progress)
		_save_guides()
		return
	if session == null:
		return
	if _opening:
		if _opening_failed and action == "restart":
			_opening_failed = false
		return
	if action in ["undo", "restart"]:
		guide.cancel_hint()
		_replaying = false
		cancel_preview(true)
		_dragging = false
		hud.dragging = false
		var ok: bool = session.undo() if action == "undo" else session.restart()
		if ok:
			animation_left = 0
			_victory_left = -1.0
			view.winning = false
			view.exit_fade = 0.0
			view.message = ""
			view.sync()
			_configure_render()
		else:
			_message("还没有可撤销的回合")
		hud.update_state(session)
		return
	if session.running or animation_left > 0:
		return
	if action == "rule_hint":
		var hint: String = "人物能登一格，木箱会浮在水面"
		for item in session.level.hints:
			if session.board.condition(item.when):
				hint = item.text
		pause_menu.show_hint(hint)
	elif action == "next_hint":
		var keys: Array = [session.history[0]] + session.level.solution_keys
		var at: int = keys.find(session.board.position_key())
		if at >= 0:
			if at < session.level.solution.size():
				pause_menu.close()
				guide.demonstrate(session.level.solution[at])
			else:
				pause_menu.show_hint("所有箱子已经到位")
		else:
			var distance: int = -1
			for i in range(session.history.size() - 1, -1, -1):
				if session.history[i] in keys:
					distance = session.history.size() - 1 - i
					break
			pause_menu.show_hint("你已经走上了自己的路线，撤销 %d 步可回到提示位置" % distance if distance > 0 and distance <= session.undo_stack.size() else "你已经走上了自己的路线，可以重开回到提示位置")
	elif action == "replay" and OS.has_feature("editor"):
		cancel_preview(true)
		_replaying = false
		if not session.restart():
			_message("开局读取失败，请重新选关")
			return
		view.sync()
		_configure_render()
		_victory_left = -1.0
		view.winning = false
		view.exit_fade = 0.0
		_replaying = true
		_replay_index = 0

func _action_label(action: String) -> String:
	var direction: String = {"L": "←", "R": "→", "U": "↑", "D": "↓", "USE": "拉杆 ↑"}.get(action.get_slice("_", action.get_slice_count("_") - 1), action)
	return {"DIG": "左键挖沙 ", "POUR": "右键倒沙 ", "BOMB": "拖炸药 "}.get(action.get_slice("_", 0), "") + direction

func _input(event: InputEvent) -> void:
	if showcase.visible:
		showcase.handle(event)
		get_viewport().set_input_as_handled()
		return
	if pause_menu.opened:
		pause_menu.handle(event)
		get_viewport().set_input_as_handled()
		return
	if lobby.visible:
		lobby.handle(event)
		get_viewport().set_input_as_handled()
		return
	if session == null:
		return
	if event is InputEventKey and event.pressed:
		var key: int = event.physical_keycode
		if key == KEY_ESCAPE and not event.echo:
			cancel_preview()
			_dragging = false
			hud.dragging = false
			Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
			pause_menu.toggle()
		elif key == KEY_Z:
			utility("undo")
		elif key == KEY_R and not event.echo:
			utility("restart")
		elif session.running or animation_left > 0:
			skip_animation = true
		elif key == KEY_F12 and not event.echo:
			utility("replay")
		elif key in [KEY_LEFT, KEY_A, KEY_RIGHT, KEY_D, KEY_UP, KEY_W, KEY_DOWN, KEY_S]:
			request_direction({KEY_LEFT: "L", KEY_A: "L", KEY_RIGHT: "R", KEY_D: "R", KEY_UP: "U", KEY_W: "U", KEY_DOWN: "D", KEY_S: "D"}[key])
		get_viewport().set_input_as_handled()
	elif event is InputEventMouseMotion:
		_pointer = event.position
		_sync_pointer()
		view.queue_redraw()
	elif event is InputEventMouseButton:
		_pointer = event.position
		_sync_pointer()
		view.queue_redraw()
		if _opening:
			return
		if session.running or animation_left > 0:
			if event.pressed:
				skip_animation = true
			return
		if event.button_index == MOUSE_BUTTON_LEFT:
			if event.pressed and hud.bomb_at(_pointer):
				_dragging = true
				hud.dragging = true
				guide.notify("bomb_dragged")
				cancel_preview()
				Input.set_mouse_mode(Input.MOUSE_MODE_HIDDEN)
			elif not event.pressed and _dragging:
				var bomb: String = _action_at(_pointer, "bomb") if not hud.bomb_at(_pointer) else ""
				_dragging = false
				hud.dragging = false
				cancel_preview()
				Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
				if not bomb.is_empty():
					request_action(bomb)
			elif event.pressed:
				var action: String = _action_at(_pointer, "left")
				if not action.is_empty():
					request_action(action)
		elif event.button_index == MOUSE_BUTTON_RIGHT and event.pressed and not _dragging:
			var action: String = _action_at(_pointer, "right")
			if not action.is_empty():
				request_action(action)
		get_viewport().set_input_as_handled()

func _save_guides() -> void:
	var file := FileAccess.open("user://guides-v03.json", FileAccess.WRITE)
	if file != null:
		file.store_string(JSON.stringify(_guide_progress))

func close_sessions() -> void:
	if _campaign_save_pending and is_instance_valid(lobby):
		lobby.save_progress()
		_campaign_save_pending = false
	if preview != null:
		preview.dispose()
		preview = null
	if session != null:
		session.dispose()
		session = null

func _exit_tree() -> void:
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
	close_sessions()
