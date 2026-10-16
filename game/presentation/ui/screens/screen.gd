class_name PortitorScreen
extends Control
## Each screen has its own scene; this presenter builds shared Control widgets.
@export var screen_name: String = "lobby"
var app: Node
var focus_index: int = 0
var buttons: Array[Button] = []
var _issues: Array[String] = []
var _chapter_cards: Control
var _tween: Tween
var _row_records: Array[Dictionary] = []
var _details: Control
const RASTER = preload("res://presentation/render/palette_raster.gd")
const ILLUSTRATION = preload("res://presentation/ui/widgets/procedural_illustration.gd")
const DIM_SHADER: Shader = preload("res://presentation/ui/widgets/palette_dim.gdshader")
var _preview_pool: Dictionary = {}
var _card_previews: Array[Dictionary] = []
var _rule_preview: Variant = null
var _rule_bag: TextureRect
var _rule_icon: TextureRect
var _rule_icon_uid: String = ""
var _rule_icon_animation: String = "default"
var _elapsed_ticks: float = 0.0
var _volume_rows: Dictionary = {}
static var _dim_materials: Dictionary = {}

func configure(controller: Node) -> void:
	app = controller
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_PASS
	if app.world_view != null:
		app.world_view.background_dim_steps = 2 if screen_name in ["chapters", "levels", "pause", "settings", "rulecard"] else 0
	match screen_name:
		"lobby": _lobby()
		"chapters": _chapters()
		"levels": _levels()
		"play": _hud()
		"pause": _pause()
		"settings": _settings()
		"hint": _hint()
		"complete": _complete()
		"rulecard": _rulecard()
		"dialogue": _dialogue()
	if screen_name not in ["play", "hint"] and not bool(Registry.art("art:ui.screen." + screen_name).get("approved", false)):
		var marker_at: Vector2 = Vector2(8, 145) if screen_name == "levels" else Vector2(252, 0) if screen_name in ["chapters", "settings"] else Vector2(252, 164)
		var marker: Label = _flow_label(t("dev.placeholder"), marker_at, 64, true)
		marker.add_theme_color_override("font_color", Color("feae34"))
	elif _level_has_placeholder():
		var marker: Label = _flow_label(t("dev.placeholder"), Vector2(4, 164), 110, true)
		marker.name = "LevelPlaceholderLabel"
		marker.add_theme_color_override("font_color", Color("feae34"))
	if not buttons.is_empty():
		call_deferred("_focus_first")
	var error: String = str(app.get("_runtime_error"))
	if not error.is_empty():
		_flow_label(error, Vector2(8, 140), 300, true, true)
	if OS.is_debug_build():
		call_deferred("_report_layout_issues")

func t(key: String, params: Dictionary = {}) -> String:
	return Locale.text("text:" + key, params)

func _unhandled_key_input(event: InputEvent) -> void:
	if screen_name != "levels" or _details == null or not event is InputEventKey:
		return
	var key: InputEventKey = event as InputEventKey
	if not key.pressed or key.physical_keycode not in [KEY_PAGEUP, KEY_PAGEDOWN]:
		return
	var description: ScrollContainer = _details.get_node_or_null("LevelDiscoveryScroll") as ScrollContainer
	if description != null:
		description.scroll_vertical += -39 if key.physical_keycode == KEY_PAGEUP else 39
		get_viewport().set_input_as_handled()

func _process(delta: float) -> void:
	_elapsed_ticks += delta * 60.0
	var tick: int = _visual_tick()
	for preview: Dictionary in _card_previews:
		preview.node.set_tick(tick + int(preview.index) * 97)
	if _rule_preview != null:
		_rule_preview.set_tick(tick)
		if _rule_bag != null:
			_rule_bag.visible = bool(_rule_preview.dug)
	if _rule_icon != null:
		var frame_count: int = int(Registry.art(_rule_icon_uid).get("frame_count", 1))
		var phase: int = (tick / 60) % mini(2, maxi(1, frame_count))
		_rule_icon.texture = PortitorUI.atlas(_rule_icon_uid, "default", phase) if frame_count > 1 else PortitorUI.atlas(_rule_icon_uid, _rule_icon_animation)
	var bomb_preview: Control = get_node_or_null("BombDragPreview") as Control
	if bomb_preview != null:
		bomb_preview.visible = app.bomb_dragging()
		bomb_preview.position = get_local_mouse_position() - Vector2(8, 8)

func _visual_tick() -> int:
	return int(app.world_view.fixed_tick) if app != null and app.world_view != null and int(app.world_view.fixed_tick) >= 0 else floori(_elapsed_ticks)

func _exit_tree() -> void:
	for preview: Variant in _preview_pool.values():
		if is_instance_valid(preview) and preview.get_parent() == null:
			preview.free()
	_preview_pool.clear()

func _dim_item(item: Node, steps: int) -> void:
	if steps <= 0:
		return
	if not _dim_materials.has(steps):
		var material := ShaderMaterial.new()
		material.shader = DIM_SHADER
		material.set_shader_parameter("dim_steps", steps)
		_dim_materials[steps] = material
	if item is CanvasItem:
		(item as CanvasItem).material = _dim_materials[steps]
	for child: Node in item.get_children():
		# The thumbnail's own SubViewport uses verified R8 decode shaders;
		# remap only its finished RGBA TextureRect, never those internals.
		if not child is SubViewport:
			_dim_item(child, steps)

func _text(key: String, location: Vector2, width: int, params: Dictionary = {}, wrap: bool = false) -> Label:
	return _flow_label(t(key, params), location, width, false, wrap)

func _box(rect: Rect2, frame: int = 0) -> VBoxContainer:
	var outer: PanelContainer = PortitorUI.panel(rect, frame)
	add_child(outer)
	var margin: MarginContainer = PortitorUI.margin()
	outer.add_child(margin)
	var column: VBoxContainer = PortitorUI.column()
	margin.add_child(column)
	return column

func _button(parent: Node, key: String, index: int, width: float, icon: String = "", icon_animation: String = "default") -> Button:
	var node: Button = PortitorUI.button(t(key), func() -> void: app.activate_menu(index), width, icon, icon_animation)
	node.focus_entered.connect(func() -> void: focus_index = index)
	parent.add_child(node)
	buttons.append(node)
	return node

func _measure(text: String) -> int:
	return roundi(PortitorUI.font().get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, 12).x)

func _color(code: String) -> Color:
	return RASTER.color_of(code)

func _rectangle(rect: Rect2, code: String, parent: Node = null) -> ColorRect:
	var node := ColorRect.new()
	node.position = rect.position
	node.size = rect.size
	node.color = _color(code)
	node.mouse_filter = Control.MOUSE_FILTER_IGNORE
	(parent if parent != null else self).add_child(node)
	return node

func _panel(rect: Rect2, frame: int = 0, parent: Node = null) -> NinePatchRect:
	var node := NinePatchRect.new()
	var texture: AtlasTexture = PortitorUI.atlas("art:ui.panel", ["normal", "focused", "wood"][frame])
	if texture != null:
		node.texture = texture.atlas
		node.region_rect = texture.region
	var margins: Array = Registry.art("art:ui.panel").get("ninepatch", [6, 6, 6, 6])
	node.patch_margin_top = int(margins[0])
	node.patch_margin_right = int(margins[1])
	node.patch_margin_bottom = int(margins[2])
	node.patch_margin_left = int(margins[3])
	node.axis_stretch_horizontal = NinePatchRect.AXIS_STRETCH_MODE_TILE
	node.axis_stretch_vertical = NinePatchRect.AXIS_STRETCH_MODE_TILE
	node.position = rect.position
	node.size = rect.size
	node.mouse_filter = Control.MOUSE_FILTER_IGNORE
	(parent if parent != null else self).add_child(node)
	return node

func _flow_label(text: String, location: Vector2, width: float, small: bool = false, wrap: bool = false, parent: Node = null) -> Label:
	# The design positions text regions; containers own the text inside them.
	# Zero margins retain the original glyph origin and measured pixel width.
	var region: MarginContainer = PortitorUI.margin(0, 0, 0, 0)
	region.position = location
	region.custom_minimum_size.x = maxf(1, width)
	region.custom_maximum_size.x = maxf(1, width)
	region.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 0)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	region.add_child(row)
	var node: Label = PortitorUI.label(text, maxf(1, width), small, wrap)
	node.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	node.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	row.add_child(node)
	region.size = Vector2(maxf(1, width), node.get_combined_minimum_size().y)
	(parent if parent != null else self).add_child(region)
	return node

func _label(text: String, location: Vector2, width: float, code: String = "u", shadow: String = "", parent: Node = null) -> Label:
	var node: Label = _flow_label(text, location, width, false, false, parent)
	node.add_theme_color_override("font_color", _color(code))
	if not shadow.is_empty():
		node.add_theme_color_override("font_shadow_color", _color(shadow))
		node.add_theme_constant_override("shadow_offset_x", 0)
		node.add_theme_constant_override("shadow_offset_y", 1)
	return node

func _centered(text: String, center: int, y: int, width: int, code: String = "u", shadow: String = "") -> Label:
	var measured: int = mini(width, _measure(text))
	return _label(text, Vector2(center - measured / 2, y), measured, code, shadow)

func _text2x(text: String, location: Vector2, code: String = "l", shadow: String = "", parent: Node = null) -> Label:
	var width: int = _measure(text) + 2
	if not shadow.is_empty():
		var shade: Label = _label(text, location + Vector2(1, 2), width, shadow, "", parent)
		(shade.get_parent().get_parent() as Control).scale = Vector2(2, 2)
	var node: Label = _label(text, location, width, code, "", parent)
	(node.get_parent().get_parent() as Control).scale = Vector2(2, 2)
	return node

func _sprite(uid: String, animation: String, anchor: Vector2, parent: Node = null) -> TextureRect:
	var node := TextureRect.new()
	node.texture = PortitorUI.atlas(uid, animation)
	var info: Dictionary = Registry.art(uid)
	var origin: Array = info.get("anchor", [0, 0])
	node.position = anchor - Vector2(origin[0], origin[1])
	node.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	var dimensions: Array = info.get("size", [0, 0])
	node.size = Vector2(dimensions[0], dimensions[1])
	node.mouse_filter = Control.MOUSE_FILTER_IGNORE
	(parent if parent != null else self).add_child(node)
	return node

func _wrapped(text: String, width: int) -> Array[String]:
	var expression := RegEx.new()
	expression.compile("[　-鿿가-힯＀-￯]|[^\\s　-鿿가-힯＀-￯]+|\\s+")
	var lines: Array[String] = []
	var line: String = ""
	for token_match: RegExMatch in expression.search_all(text):
		var token: String = token_match.get_string()
		if token.strip_edges().is_empty():
			if not line.is_empty():
				line += " "
			continue
		if line.is_empty() or _measure(line + token) <= width:
			line += token
			continue
		if "，。：；、！？）」』”…,.:;!?)".contains(token.left(1)) and line.length() > 1:
			lines.append(line.left(-1))
			line = line.right(1) + token
			continue
		lines.append(line.rstrip(" \t\n"))
		line = token
		while _measure(line) > width and line.length() > 1:
			var cut: int = line.length() - 1
			while cut > 1 and _measure(line.left(cut)) > width:
				cut -= 1
			lines.append(line.left(cut))
			line = line.substr(cut)
	if not line.is_empty():
		lines.append(line.rstrip(" \t\n"))
	return lines

func _paragraph(text: String, location: Vector2, width: int, max_lines: int, code: String = "u", parent: Node = null) -> void:
	var lines: Array[String] = _wrapped(text, width)
	if lines.size() > max_lines:
		_issues.append("paragraph clipped: " + text)
	var region: MarginContainer = PortitorUI.margin(0, 0, 0, 0)
	region.position = location
	region.custom_minimum_size.x = width
	region.custom_maximum_size.x = width
	region.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var column: VBoxContainer = PortitorUI.column(-1) # 14px font height, 13px reference line stride.
	column.mouse_filter = Control.MOUSE_FILTER_IGNORE
	region.add_child(column)
	(parent if parent != null else self).add_child(region)
	for index: int in mini(max_lines, lines.size()):
		_label(lines[index], Vector2.ZERO, width, code, "", column)

func _row(rect: Rect2, index: int, active_rect: Rect2 = Rect2(), panel_always: bool = false, activation: Callable = Callable()) -> Button:
	if panel_always:
		_panel(rect)
	var node := Button.new()
	node.position = rect.position
	node.size = rect.size
	node.custom_minimum_size = rect.size
	node.add_theme_font_override("font", PortitorUI.font())
	node.add_theme_font_size_override("font_size", 12)
	for state: String in ["normal", "hover", "pressed", "focus", "disabled"]:
		node.add_theme_stylebox_override(state, StyleBoxEmpty.new())
	add_child(node)
	var active: NinePatchRect = _panel(active_rect if active_rect.has_area() else rect, 1)
	active.visible = index == focus_index
	_row_records.append({"index": index, "active": active, "labels": []})
	node.focus_entered.connect(func() -> void:
		focus_index = index
		_sync_rows()
		if screen_name == "levels":
			app.lab.level_index = index
			_update_level_details())
	node.pressed.connect(activation if activation.is_valid() else func() -> void: app.activate_menu(index))
	buttons.append(node)
	return node

func _row_label(index: int, text: String, location: Vector2, width: int, normal: String = "u", selected: String = "l") -> Label:
	var node: Label = _label(text, location, width, selected if index == focus_index else normal)
	for record: Dictionary in _row_records:
		if record.index == index:
			record.labels.append({"node": node, "normal": normal, "selected": selected})
	return node

func _sync_rows() -> void:
	for record: Dictionary in _row_records:
		record.active.visible = int(record.index) == focus_index
		if record.has("pointer"):
			record.pointer.visible = int(record.index) == focus_index
		if record.get("never_highlight", false):
			record.active.visible = false
		for entry: Dictionary in record.labels:
			entry.node.add_theme_color_override("font_color", _color(entry.selected if int(record.index) == focus_index else entry.normal))

	for key: String in _volume_rows:
		refresh_volume(key)

func _wide_key(text: String, location: Vector2) -> int:
	var width: int = _measure(text) + 8
	_rectangle(Rect2(location + Vector2(1, 0), Vector2(width - 2, 13)), "z")
	_rectangle(Rect2(location + Vector2(0, 1), Vector2(width, 11)), "z")
	_rectangle(Rect2(location + Vector2(1, 1), Vector2(width - 2, 10)), "u")
	_rectangle(Rect2(location + Vector2(1, 11), Vector2(width - 2, 1)), "v")
	_label(text, location + Vector2(4, -1), width - 8, "y")
	return width

func _keybar(groups: Array[Dictionary]) -> void:
	_rectangle(Rect2(0, 161, 320, 19), "z")
	_rectangle(Rect2(0, 161, 320, 1), "y")
	var total: int = 0
	for group: Dictionary in groups:
		for key: String in group["keys"]:
			total += (_measure(key) + 8 if key in ["Enter", "Esc"] else 13) + 1
		total += 3 + _measure(t(group.label)) + 10
	var full: bool = total <= 304
	if not full:
		_issues.append("keybar labels dropped")
	var x: int = 8
	for group: Dictionary in groups:
		for key: String in group["keys"]:
			if key in ["Enter", "Esc"]:
				x += _wide_key(key, Vector2(x, 164)) + 1
			else:
				_sprite("art:ui.keycap", key, Vector2(x, 164))
				x += 14
		if full:
			_label(t(group.label), Vector2(x, 163), _measure(t(group.label)), "v")
			x += 3 + _measure(t(group.label))
		x += 10

func _lobby() -> void:
	_sprite("art:obj.crate_wood", "default", Vector2(24, 30))
	var title: String = t("game.title")
	if _measure(title) * 2 <= 200:
		_text2x(title, Vector2(38, 6), "l", "z")
	else:
		_label(title, Vector2(38, 12), 200, "l", "z")
	_paragraph(t("game.tagline"), Vector2(16, 36), 200, 2, "c")
	var chapter: Dictionary = app.lab.current_group()
	_label(t("lobby.current", {"chapter": _chapter_name(int(chapter.get("order", 1))), "theme": t(str(chapter.get("theme", "theme.dungeon")))}), Vector2(16, 64), 200, "k", "z")
	var keys: Array[String] = ["menu.continue", "menu.chapters", "menu.settings", "menu.quit"]
	var icon_names: Array[String] = ["continue", "chapters", "settings", "quit"]
	var detail: String = str(Save.data.get("last_level_uid", app.lab.level_uid())).trim_prefix("level:")
	var width: int = 96
	for index: int in keys.size():
		width = maxi(width, _measure(t(keys[index]) + ("  " + detail if index == 0 and not detail.is_empty() else "")) + 34)
	width = mini(180, width)
	_panel(Rect2(14, 82, width, 8 + keys.size() * 16))
	for index: int in keys.size():
		var y: int = 86 + index * 16
		_row(Rect2(17, y - 1, width - 6, 16), index)
		_sprite("art:ui.menu_icons", icon_names[index], Vector2(21, y + 1))
		var detail_width: int = _measure(detail) + 6 if index == 0 and not detail.is_empty() else 0
		_row_label(index, t(keys[index]), Vector2(36, y), width - 30 - detail_width)
		if index == 0 and not detail.is_empty():
			_label(detail, Vector2(14 + width - 8 - _measure(detail), y), _measure(detail), "v")
	_keybar([{"keys": ["up", "down"], "label": "keys.select"}, {"keys": ["Enter"], "label": "keys.confirm"}])

func _chapter_name(order: int) -> String:
	return t("chapter.n", {"n": order}) if order <= 5 else t("extra.chapter.review") if order == 6 else t("chapter.extra")

func _chapters() -> void:
	_label(t("chapters.title"), Vector2(10, 4), 200, "l", "z")
	_chapter_cards = Control.new()
	add_child(_chapter_cards)
	_draw_cards(float(app.lab.group_index))
	call_deferred("_prepare_thumbnails")
	var group: Dictionary = app.lab.current_group()
	_centered(_chapter_name(int(group.order)) + " · " + t(group.theme), 160, 116, 300, "l", "z")
	_panel(Rect2(6, 148, 308, 30))
	var body: String
	if not app.lab.stage_available(app.lab.group_index):
		body = t("chapter.preview") if app.lab.open_all_levels else t("chapter.unavailable")
	elif app.lab.available(app.lab.group_index):
		body = t("extra.chapter.review_blurb") if int(group.order) == 6 else t("chapter." + str(int(group.order)) + ".blurb")
	else:
		body = t("chapters.unlock", {"chapter": _chapter_name(maxi(1, int(group.order) - 1)), "n": _unlock_need(app.lab.group_index)}) if int(group.order) <= 5 else t("chapters.later")
	_paragraph(body, Vector2(12, 149), 296, 2, "u" if app.lab.available(app.lab.group_index) else "v")
	_page_indicator()

func _unlock_need(index: int) -> int:
	return app.lab.unlock_need(index)

func _page_indicator() -> void:
	var pages := Control.new()
	pages.name = "ChapterPageIndicator"
	pages.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(pages)
	var count: int = app.lab.groups.size()
	if count > 16:
		var current: Label = _flow_label(t("progress", {"a": app.lab.group_index + 1, "b": count}), Vector2(115, 132), 90, false, false, pages)
		current.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		_chapter_arrow("left", -1, 130)
		_chapter_arrow("right", 1, 177)
		return
	var total: int = count * 10 + 4
	var cursor: int = 160 - total / 2
	for index: int in count:
		var active: bool = index == app.lab.group_index
		var marker := ColorRect.new()
		marker.name = "Page%d" % index
		marker.color = _color("l" if active else "z")
		marker.position = Vector2(cursor, 136)
		marker.size = Vector2(14 if active else 6, 3)
		marker.mouse_filter = Control.MOUSE_FILTER_IGNORE
		pages.add_child(marker)
		if not active:
			_rectangle(Rect2(cursor + 1, 137, 4, 1), "v" if app.lab.available(index) else "x")
		cursor += int(marker.size.x) + 4
	_chapter_arrow("left", -1, 160 - total / 2 - 20)
	_chapter_arrow("right", 1, 160 + total / 2 + 7)

func _chapter_arrow(animation: String, amount: int, x: int) -> void:
	var arrow := TextureButton.new()
	arrow.texture_normal = PortitorUI.atlas("art:ui.keycap", animation)
	arrow.position = Vector2(x, 131)
	arrow.focus_mode = Control.FOCUS_NONE
	arrow.disabled = (amount < 0 and app.lab.group_index == 0) or (amount > 0 and app.lab.group_index + 1 == app.lab.groups.size())
	arrow.pressed.connect(func() -> void: app.change_chapter(amount))
	add_child(arrow)

func _prepare_thumbnails() -> void:
	if DisplayServer.get_name() == "headless":
		return
	for preview: Dictionary in _card_previews:
		await preview.node.prepare_reference()

func prepare_reference() -> void:
	if DisplayServer.get_name() == "headless":
		return
	if screen_name == "chapters":
		await _prepare_thumbnails()
	elif _rule_preview != null:
		await _rule_preview.prepare_reference()

func _draw_cards(focus: float) -> void:
	for preview: Dictionary in _card_previews:
		if is_instance_valid(preview.node) and preview.node.get_parent() != null:
			preview.node.get_parent().remove_child(preview.node)
	_card_previews.clear()
	for child: Node in _chapter_cards.get_children():
		_chapter_cards.remove_child(child)
		child.queue_free()
	var order: Array[int] = []
	for index: int in app.lab.groups.size():
		order.append(index)
	order.sort_custom(func(a: int, b: int) -> bool: return absf(a - focus) > absf(b - focus))
	for index: int in order:
		var distance: float = index - focus
		if absf(distance) > 2.4:
			continue
		var d: float = minf(2, absf(distance))
		var start: int = int(d)
		var end: int = mini(2, start + 1)
		var fraction: float = d - start
		var widths: Array[float] = [116, 64, 40]
		var heights: Array[float] = [96, 74, 54]
		var offsets: Array[float] = [0, 94, 140]
		var card_size := Vector2(roundf(lerpf(widths[start], widths[end], fraction)), roundf(lerpf(heights[start], heights[end], fraction)))
		var cx: float = 160 + signf(distance) * roundf(lerpf(offsets[start], offsets[end], fraction))
		var center: bool = d < 0.5
		var panel: NinePatchRect = _panel(Rect2(Vector2(cx - floorf(card_size.x / 2), 66 - floorf(card_size.y / 2)), card_size), 1 if center else 0, _chapter_cards)
		panel.name = "ChapterCard%d" % index
		var group: Dictionary = app.lab.groups[index]
		# A free-layout face keeps PanelContainer from resizing every overlay
		# to the full card. Only the outer ninepatch participates in layout.
		var face := Control.new()
		face.size = card_size
		face.mouse_filter = Control.MOUSE_FILTER_IGNORE
		panel.add_child(face)
		var thumbnail_slot: int = 0 if center else 1 if d < 1.5 else 2
		var key: String = "art:" + str(group.theme) + "|" + str(thumbnail_slot)
		var miniature: Variant = _preview_pool.get(key)
		var fresh: bool = miniature == null
		if fresh:
			miniature = ILLUSTRATION.new()
			_preview_pool[key] = miniature
		miniature.name = "ThemeThumbnail%d" % index
		miniature.set_meta("theme_uid", "art:" + str(group.theme))
		face.add_child(miniature)
		if fresh:
			var sizes: Array[Vector2i] = [Vector2i(108, 68), Vector2i(56, 56), Vector2i(32, 36)]
			miniature.configure_chapter("art:" + str(group.theme), sizes[thumbnail_slot], _visual_tick() + index * 97, center)
		miniature.position = Vector2(4, 4)
		miniature.size = Vector2(card_size.x - 8, card_size.y - (28 if center else 18))
		_card_previews.append({"node": miniature, "index": index})
		if center and not app.lab.available(index):
			_dim_item(miniature, 1)
		_rectangle(Rect2(3, 3, card_size.x - 6, 1), "z", face)
		_rectangle(Rect2(3, 4 + miniature.size.y, card_size.x - 6, 1), "z", face)
		var number: String = str(int(group.order)) if int(group.order) <= 5 else "+"
		if center:
			_sprite("art:ui.theme_emblem", str(group.theme).trim_prefix("theme."), Vector2(7, 7), face)
			_text2x(number, Vector2(8, card_size.y - 25), "l" if app.lab.available(index) else "w", "z", face)
		elif app.lab.available(index):
			_label(number, Vector2(floorf(card_size.x / 2) - floorf(_measure(number) / 2.0), card_size.y - 16), _measure(number), "u", "", face)
		if center and app.lab.available(index):
			var done: int = 0
			for level: Dictionary in group.get("levels", []):
				if Save.level_data("level:" + str(level.id)).get("cleared", false):
					done += 1
			var progress_text: String = t("progress", {"a": done, "b": group.get("levels", []).size()})
			var progress: Label = _label(progress_text, Vector2(card_size.x - 8 - _measure(progress_text), card_size.y - 21), _measure(progress_text), "k", "", face)
			progress.name = "ChapterProgress%d" % index
		var click := Button.new()
		click.size = card_size
		click.focus_mode = Control.FOCUS_NONE
		for state: String in ["normal", "hover", "pressed", "focus", "disabled"]:
			click.add_theme_stylebox_override(state, StyleBoxEmpty.new())
		face.add_child(click)
		click.pressed.connect(func() -> void:
			if index == app.lab.group_index: app.activate_menu(0)
			else: app.change_chapter(index - app.lab.group_index))
		if not app.lab.available(index):
			_sprite("art:ui.icons", "lock", Vector2(card_size.x - 20, card_size.y - 20) if center else Vector2(floorf(card_size.x / 2) - 6, card_size.y - 15), face)
		if d >= 1.5:
			_dim_item(panel, 1)

func slide_chapter(old: int, target: int) -> void:
	if _tween != null:
		_tween.kill()
	_tween = create_tween().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	_tween.tween_method(_draw_cards, float(old), float(target), 1.0)
	_tween.finished.connect(func() -> void: app.show_screen("chapters"))

func _levels() -> void:
	var group: Dictionary = app.lab.current_group()
	focus_index = clampi(app.lab.level_index, 0, maxi(0, app.lab.levels().size() - 1))
	var done: int = 0
	for item: Dictionary in app.lab.levels():
		if Save.level_data("level:" + str(item.id)).get("cleared", false):
			done += 1
	var cleared: String = t("levels.cleared", {"a": done, "b": app.lab.levels().size()})
	var cleared_width: int = _measure(cleared)
	_label(t("levels.title", {"chapter": _chapter_name(int(group.order)), "theme": t(group.theme)}), Vector2(10, 4), 290 - cleared_width, "l", "z")
	_label(cleared, Vector2(310 - cleared_width, 4), cleared_width, "k", "z")
	var row_height: int = mini(17, int(136 / maxi(1, app.lab.levels().size())))
	for index: int in app.lab.levels().size():
		var item: Dictionary = app.lab.levels()[index]
		var y: int = 22 + index * row_height
		var progress: Dictionary = Save.level_data("level:" + str(item.id))
		_row(Rect2(8, y, 176, 15), index, Rect2(), true)
		_row_label(index, str(item.id), Vector2(14, y), 28, "k")
		var status_width: int = 16 if progress.get("cleared", false) or progress.get("skipped", false) or index == focus_index else 0
		var title_key: String = "level." + str(item.id) + ".title"
		var title: String = t(title_key)
		if title == title_key: title = str(item.get("title", t("chapter.preview")))
		_row_label(index, title, Vector2(42, y), 136 - status_width)
		if progress.get("cleared", false):
			_sprite("art:ui.icons", "check", Vector2(169, y + 1))
		elif progress.get("skipped", false):
			_sprite("art:ui.icons", "skip", Vector2(169, y + 1))
		elif index == focus_index:
			_sprite("art:ui.menu_icons", "continue", Vector2(169, y + 1))
	_panel(Rect2(190, 22, 122, 136))
	_details = Control.new()
	add_child(_details)
	_update_level_details()
	_keybar([{"keys": ["up", "down"], "label": "keys.select"}, {"keys": ["Enter"], "label": "keys.play"}, {"keys": ["Esc"], "label": "keys.back"}])

func _update_level_details() -> void:
	if _details == null:
		return
	for child: Node in _details.get_children():
		_details.remove_child(child)
		child.queue_free()
	var uid: String = app.lab.level_uid()
	var has_spec: bool = app.lab.has_spec()
	var spec: Dictionary = Registry.level_spec(uid) if not uid.is_empty() and has_spec else {}
	if spec.is_empty():
		_paragraph(t("chapter.preview"), Vector2(195, 32), 112, 8, "u", _details)
	if not spec.is_empty():
		var rows: Array = spec.map
		var cell: int = maxi(2, mini(6, floori(minf(112.0 / str(rows[0]).length(), 54.0 / rows.size()))))
		var map_width: int = str(rows[0]).length() * cell
		var map_height: int = rows.size() * cell
		var origin := Vector2(190 + (122 - map_width) / 2, 28)
		var colors: Dictionary = {"#": "w", "%": "F", "e": "e", "s": "c", "~": "r", "|": "v", "H": "f", "o": "k", "b": "b", "X": "l", "_": "s", "P": "i", "h": "i", "B": "b", "I": "u", ".": "y"}
		for y: int in rows.size():
			for x: int in str(rows[y]).length():
				_rectangle(Rect2(origin + Vector2(x * cell, y * cell), Vector2(cell, cell)), colors.get(str(rows[y]).substr(x, 1), "y"), _details)
		# Keep the full discovery available when a taller map leaves less room.
		# This region scrolls independently; keyboard focus stays on the level row.
		var description := ScrollContainer.new()
		description.name = "LevelDiscoveryScroll"
		description.position = Vector2(195, 32 + map_height)
		description.size = Vector2(112, maxi(26, 154 - (32 + map_height)))
		description.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
		description.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
		description.focus_mode = Control.FOCUS_NONE
		_details.add_child(description)
		description.get_v_scroll_bar().focus_mode = Control.FOCUS_NONE
		var text_width: int = maxi(60, 110 - ceili(description.get_v_scroll_bar().get_combined_minimum_size().x))
		var discovery: String = _level_text(spec, "discovery")
		_paragraph(discovery, Vector2.ZERO, text_width, _wrapped(discovery, text_width).size(), "u", description)

func _level_text(spec: Dictionary, field: String) -> String:
	var key: String = "level." + str(spec.get("id", "")) + "." + field
	var translated: String = t(key)
	if translated != key:
		return translated
	if field.begins_with("hint."):
		var hints: Array = spec.get("hints", [])
		var index: int = int(field.trim_prefix("hint.")) - 1
		return str(hints[index]) if index >= 0 and index < hints.size() else ""
	return str(spec.get(field, ""))

func _hud() -> void:
	if app.session == null:
		return
	var spec: Dictionary = app.session.spec
	var state: Dictionary = app.session.state()
	var background := ColorRect.new()
	background.color = PortitorUI.DARK
	background.size = Vector2(320, 20)
	add_child(background)
	var goals: Array = app.session.goal_lights()
	var actions_start: int = 251 if screen_name == "play" else 264
	var lamps_left: int = actions_start - 8 - goals.size() * 10
	var count_left: int = lamps_left - 34
	var bag_available: bool = int(state.bag.sand) > 0 or int(spec.get("bag", {}).get("sand", 0)) > 0
	for row: String in spec.map:
		bag_available = bag_available or row.contains("e") or row.contains("s")
	var bomb_available: bool = int(state.bag.get("bomb", 0)) > 0 or int(spec.get("bag", {}).get("bomb", 0)) > 0
	var bag_left: int = count_left - (39 if bag_available else 0)
	var bomb_left: int = bag_left - (35 if bomb_available else 0)
	_flow_label(_level_text(spec, "title"), Vector2(35, 3), maxi(30, bomb_left - 41))
	_label(str(spec.id), Vector2(5, 3), 28)
	var sand: Label = _flow_label(str(int(state.bag.sand)), Vector2(bag_left + 16, 3), 24)
	sand.name = "SandCount"
	sand.visible = bag_available
	var bag := TextureRect.new()
	bag.name = "SandBagIcon"
	bag.visible = bag_available
	bag.texture = PortitorUI.atlas("art:item.sandbag")
	bag.position = Vector2(bag_left, 2)
	bag.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(bag)
	var bomb_count: Label = _flow_label(str(int(state.bag.get("bomb", 0))), Vector2(bomb_left + 17, 3), 18)
	bomb_count.name = "BombCount"
	bomb_count.visible = bomb_available
	var bomb := TextureRect.new()
	bomb.name = "BombIcon"
	bomb.visible = bomb_available
	bomb.texture = PortitorUI.atlas("art:item.bomb")
	bomb.position = Vector2(bomb_left, 2)
	bomb.size = Vector2(16, 16)
	bomb.tooltip_text = t("extra.controls.bomb")
	bomb.gui_input.connect(_bomb_source_input)
	add_child(bomb)
	var bomb_preview := TextureRect.new()
	bomb_preview.name = "BombDragPreview"
	bomb_preview.texture = bomb.texture
	bomb_preview.size = Vector2(16, 16)
	bomb_preview.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bomb_preview.z_index = 100
	bomb_preview.visible = false
	add_child(bomb_preview)
	var lit: int = 0
	var lamps := HBoxContainer.new()
	lamps.name = "GoalLamps"
	lamps.position = Vector2(lamps_left, 5)
	lamps.add_theme_constant_override("separation", 1)
	lamps.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(lamps)
	for goal: Dictionary in goals:
		var lamp := TextureRect.new()
		lamp.texture = PortitorUI.atlas("art:ui.goal_lamp", "on" if goal.get("lit", false) else "off")
		lamp.custom_minimum_size = Vector2(9, 9)
		lamp.mouse_filter = Control.MOUSE_FILTER_IGNORE
		lamps.add_child(lamp)
		if goal.get("lit", false):
			lit += 1
	var counter: Label = _flow_label(t("progress", {"a": lit, "b": goals.size()}), Vector2(count_left, 3), 32)
	counter.name = "GoalCount"
	var actions: Array[String] = ["undo", "restart", "hint", "pause"]
	if screen_name == "play":
		actions.append("observe")
	for index: int in actions.size():
		var button: Button = PortitorUI.button("", func() -> void: _hud_action(actions[index]), 13, "art:ui.icons", actions[index])
		button.position = Vector2(actions_start + index * 13, 3)
		button.focus_mode = Control.FOCUS_NONE
		for style: String in ["normal", "hover", "pressed", "focus", "disabled"]:
			button.add_theme_stylebox_override(style, StyleBoxEmpty.new())
		if actions[index] == "observe":
			button.name = "ObserveButton"
			button.button_down.connect(_observe_hold.bind(true))
			button.button_up.connect(_observe_hold.bind(false))
		add_child(button)

func _observe_hold(enabled: bool) -> void:
	if app.world_view != null:
		app.world_view.set_meta("observe_toggle", enabled)
		app.world_view.observe = enabled or Input.is_physical_key_pressed(KEY_TAB)

func _bomb_source_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		var mouse: InputEventMouseButton = event as InputEventMouseButton
		if mouse.pressed and mouse.button_index == MOUSE_BUTTON_LEFT:
			app.begin_bomb_drag()
			if app.bomb_dragging():
				accept_event()

func refresh_session() -> void:
	if app.session == null:
		return
	var state: Dictionary = app.session.state()
	var bomb_count: Label = find_child("BombCount", true, false) as Label
	if bomb_count != null:
		bomb_count.text = str(int(state.bag.get("bomb", 0)))
		if int(state.bag.get("bomb", 0)) > 0:
			bomb_count.visible = true
			var bomb: Control = get_node_or_null("BombIcon") as Control
			if bomb != null:
				bomb.visible = true
	var sand: Label = find_child("SandCount", true, false) as Label
	if sand != null:
		sand.text = str(int(state.bag.sand))
		if int(state.bag.sand) > 0:
			sand.visible = true
			var bag: Control = find_child("SandBagIcon", true, false) as Control
			if bag != null:
				bag.visible = true
	var goals: Array = app.session.goal_lights()
	var lamps: HBoxContainer = find_child("GoalLamps", true, false) as HBoxContainer
	var lit: int = 0
	for index: int in goals.size():
		if goals[index].get("lit", false):
			lit += 1
		if lamps != null and index < lamps.get_child_count():
			(lamps.get_child(index) as TextureRect).texture = PortitorUI.atlas("art:ui.goal_lamp", "on" if goals[index].get("lit", false) else "off")
	var count: Label = find_child("GoalCount", true, false) as Label
	if count != null:
		count.text = t("progress", {"a": lit, "b": goals.size()})

func _hud_action(action: String) -> void:
	match action:
		"undo": app.undo()
		"restart": app.restart()
		"hint": app.hint_level = 1; app.show_screen("hint")
		"pause": app.show_screen("pause")

func _pause() -> void:
	_dimmed_hud()
	var keys: Array[String] = ["pause.resume", "pause.hint", "pause.restart", "pause.skip", "pause.levels", "pause.settings", "pause.menu"]
	var width: int = maxi(120, mini(220, _measure(t("pause.title")) + 36))
	for key: String in keys:
		width = maxi(width, mini(220, _measure(t(key)) + 36))
	var height: int = 22 + keys.size() * 15
	var x: int = (320 - width) / 2
	var y: int = (180 - height) / 2
	_panel(Rect2(x, y, width, height), 2)
	_centered(t("pause.title"), 160, y + 3, width - 12, "l", "g")
	for index: int in keys.size():
		var line_y: int = y + 19 + index * 15
		_row(Rect2(x + 5, line_y - 1, width - 10, 15), index)
		var mark: ColorRect = _rectangle(Rect2(x + 10, line_y + 5, 2, 4), "k")
		mark.visible = index == focus_index
		_row_records.back()["pointer"] = mark
		_row_label(index, t(keys[index]), Vector2(x + 17, line_y), width - 26, "c")

func _settings() -> void:
	var keys: Array[String] = ["settings.language", "settings.music", "settings.sfx", "settings.scale", "settings.env", "settings.grid", "settings.unlock", "settings.tutorial"]
	var fields: Array[String] = ["language", "music", "sfx", "window_scale", "ambience", "show_grid", "open_all_levels", "tutorial"]
	_panel(Rect2(20, 14, 280, 22 + keys.size() * 17))
	_label(t("settings.title"), Vector2(28, 17), 264, "l")
	for index: int in keys.size():
		var y: int = 35 + index * 17
		var selection: Callable = (func() -> void: set_focus(index)) if fields[index] in ["music", "sfx"] else (func() -> void: app.activate_menu(index))
		_row(Rect2(24, y - 2, 272, 16), index, Rect2(), false, selection)
		_row_label(index, t(keys[index]), Vector2(32, y), 170)
		var value: Variant = Settings.values.get(fields[index], false)
		var display: String = str(value)
		match fields[index]:
			"language": display = "English" if Locale.language == "en" else "简体中文"
			"music", "sfx":
				var bars: Array[ColorRect] = []
				for bar: int in 10:
					bars.append(_rectangle(Rect2(218 + bar * 7, y + 4, 5, 6), ("k" if index == focus_index else "d") if bar < roundi(float(value) * 10) else "x"))
				var slider := HSlider.new()
				slider.position = Vector2(218, y - 2)
				slider.size = Vector2(70, 16)
				slider.min_value = 0
				slider.max_value = 1
				slider.step = 0.1
				slider.set_value_no_signal(float(value))
				# Keep the approved ten-bar artwork; native slider owns GUI drag/capture.
				slider.modulate.a = 0
				var field: String = fields[index]
				slider.value_changed.connect(func(volume: float) -> void: app.set_volume(field, volume))
				slider.focus_entered.connect(func() -> void: focus_index = index; _sync_rows())
				add_child(slider)
				_volume_rows[field] = {"slider": slider, "bars": bars, "index": index}
				continue
			"show_grid", "open_all_levels": display = t("on" if value else "off")
			"ambience": display = t("env.full" if value == "full" else "env.lite" if value == "lights" else "env.off")
			"window_scale": display = t("settings.scale.auto") if str(value) == "auto" else str(int(value)) + "×"
			"tutorial": display = t("settings.run")
		if fields[index] in ["show_grid", "open_all_levels"]:
			var toggle_width: int = mini(86, _measure(display) + 12)
			_panel(Rect2(288 - toggle_width, y - 1, toggle_width, 13), 1 if value else 0)
			_label(display, Vector2(294 - toggle_width, y - 1), toggle_width - 12, "l" if value else "v")
		else:
			_label(display, Vector2(288 - _measure(display), y), mini(86, _measure(display)), "c")

func refresh_volume(key: String) -> void:
	if not _volume_rows.has(key): return
	var row: Dictionary = _volume_rows[key]
	var value: float = float(Settings.values[key])
	(row.slider as HSlider).set_value_no_signal(value)
	for bar: int in row.bars.size():
		(row.bars[bar] as ColorRect).color = _color(("k" if int(row.index) == focus_index else "d") if bar < roundi(value * 10) else "x")

func _hint() -> void:
	_hud()
	var spec: Dictionary = app.session.spec if app.session != null else Registry.level_spec("level:M01")
	var player: Dictionary = app.session.state().player if app.session != null else {"x":2,"y":3}
	var width: int = spec.map[0].length()
	var height: int = spec.map.size()
	var speaker := Vector2((320 - width * 16) / 2 + player.x * 16 + 8, 20 + (160 - height * 16) / 2 + player.y * 16 + 2)
	var bubble := PortitorBubble.new()
	add_child(bubble)
	bubble.configure(_level_text(spec, "hint." + str(app.hint_level)), speaker, t("hint.title", {"n":app.hint_level}), t("dev.placeholder"))
	_issues.append_array(bubble.issues)
	_panel(Rect2(6, 156, 308, 21))
	_sprite("art:ui.icons", "hint", Vector2(12, 160))
	if app.hint_level < 3:
		_sprite("art:ui.keycap", "H", Vector2(28, 159))
		_label(t("hint.more"), Vector2(44, 159), 258, "v")
		_row(Rect2(26, 158, 280, 17), 0)
		_row_records.back()["never_highlight"] = true
		_row_records.back().active.visible = false
	else:
		if app.session == null or app.lab.route_index(app.session.state()) < 0:
			var only_rewind_width: int = mini(278, _measure(t("hint.rewind")) + 14)
			_plain_button(t("hint.rewind"), Vector2(310 - only_rewind_width, 159), only_rewind_width, 0)
			return
		var demo_width: int = mini(139, _measure(t("hint.demo")) + 14)
		var rewind_width: int = mini(278 - demo_width - 4, _measure(t("hint.rewind")) + 14)
		var rewind_x: int = 310 - rewind_width
		var demo_x: int = 306 - rewind_width - demo_width
		_plain_button(t("hint.demo"), Vector2(demo_x, 159), demo_width, 0)
		_plain_button(t("hint.rewind"), Vector2(rewind_x, 159), rewind_width, 1)

func _plain_button(text: String, position: Vector2, width: int, index: int) -> Button:
	var button: Button = _row(Rect2(position, Vector2(width, 15)), index, Rect2(), true)
	_row_label(index, text, position + Vector2(7, 0), width - 14)
	return button

func _complete() -> void:
	_hud()
	var title: String = t("complete.title")
	var moves: String = t("complete.moves", {"n": int(app.session.state().moves) if app.session != null else 4})
	var width: int = maxi(140, mini(240, _measure(moves) + 24))
	var x: int = (320 - width) / 2
	_panel(Rect2(x, 34, width, 54), 2)
	if _measure(title) * 2 <= width - 16:
		_text2x(title, Vector2(x + (width - _measure(title) * 2) / 2, 38), "l", "g")
	else:
		_centered(title, 160, 44, width - 16, "l", "g")
	_centered(moves, 160, 70, width - 16, "c")
	var first_width: int = mini(140, _measure(t("complete.next")) + 14)
	var second_width: int = mini(140, _measure(t("complete.levels")) + 14)
	var left: int = (320 - first_width - 6 - second_width) / 2
	_plain_button(t("complete.next"), Vector2(left, 92), first_width, 0)
	_plain_button(t("complete.levels"), Vector2(left + first_width + 6, 92), second_width, 1)

func _rulecard() -> void:
	_dimmed_hud()
	var info: Dictionary = app.rule_card_text() if app.has_method("rule_card_text") else {"name": "rule.earth.name", "text": "rule.earth.text", "icon": "art:ui.class_icon", "animation": "earth"}
	_panel(Rect2(42, 36, 236, 104))
	_label(t("rule.title", {"name": t(str(info.name))}), Vector2(50, 39), 220, "l")
	_paragraph(t(str(info.text)), Vector2(114, 58), 156, 5)
	var width: int = mini(120, _measure(t("rule.close")) + 14)
	_plain_button(t("rule.close"), Vector2(270 - width, 121), width, 0)
	_wide_key("Esc", Vector2(264 - width - _measure("Esc") - 8, 122))
	if str(info.name) == "rule.earth.name":
		_rule_preview = ILLUSTRATION.new()
		add_child(_rule_preview)
		var theme_uid: String = "art:" + str(app.lab.current_group().get("theme", "theme.dungeon"))
		_rule_preview.configure_rulecard(theme_uid, _visual_tick())
		_rule_preview.position = Vector2(50, 58)
		_rule_bag = _sprite("art:item.sandbag", "full", Vector2(70, 94))
		_rule_bag.visible = bool(_rule_preview.dug)
	else:
		_rule_icon_uid = str(info.icon)
		_rule_icon_animation = str(info.animation)
		var icon: Dictionary = Registry.art(_rule_icon_uid)
		var dimensions: Array = icon.get("size", [16, 16])
		var anchor: Array = icon.get("anchor", [0, 0])
		_rule_icon = _sprite(_rule_icon_uid, _rule_icon_animation, Vector2(50 + (56 - int(dimensions[0])) / 2 + int(anchor[0]), 58 + (32 - int(dimensions[1])) / 2 + int(anchor[1])))
	_rectangle(Rect2(49, 57, 58, 1), "z")
	_rectangle(Rect2(49, 90, 58, 1), "z")

func _dimmed_hud() -> void:
	var before: Array[Node] = get_children()
	_hud()
	for child: Node in get_children():
		if not before.has(child):
			_dim_item(child, 2)

func _dialogue() -> void:
	_text("status.later", Vector2(110, 80), 100)

func move_focus(amount: int) -> void:
	if not is_inside_tree() or buttons.is_empty():
		return
	focus_index = posmod(focus_index + amount, buttons.size())
	if is_instance_valid(buttons[focus_index]) and buttons[focus_index].is_inside_tree():
		buttons[focus_index].grab_focus()
	if screen_name == "levels":
		app.lab.level_index = focus_index

func _focus_first() -> void:
	if is_inside_tree() and not buttons.is_empty():
		set_focus(focus_index)

func set_focus(index: int) -> void:
	if buttons.is_empty() or not is_inside_tree():
		return
	focus_index = clampi(index, 0, buttons.size() - 1)
	if buttons[focus_index].is_inside_tree():
		buttons[focus_index].grab_focus()
	_sync_rows()

func layout_issues() -> Array:
	var result: Array = _issues.duplicate()
	_scan(self, result)
	return result

func _report_layout_issues() -> void:
	if not is_inside_tree():
		return
	for issue: String in layout_issues():
		push_warning(screen_name + ": " + issue)

func _scan(parent: Node, result: Array) -> void:
	for child: Node in parent.get_children():
		if child is Control and not (child as Control).is_visible_in_tree():
			continue
		if child is Label:
			var label: Label = child as Label
			var face: Font = label.get_theme_font("font")
			var font_size: int = label.get_theme_font_size("font_size")
			var wrap_width: float = label.size.x if label.autowrap_mode != TextServer.AUTOWRAP_OFF else -1.0
			var flags: int = TextServer.BREAK_MANDATORY
			if label.autowrap_mode == TextServer.AUTOWRAP_ARBITRARY:
				flags |= TextServer.BREAK_GRAPHEME_BOUND
			elif label.autowrap_mode != TextServer.AUTOWRAP_OFF:
				flags |= TextServer.BREAK_WORD_BOUND
				if label.autowrap_mode == TextServer.AUTOWRAP_WORD_SMART:
					flags |= TextServer.BREAK_ADAPTIVE
			var full_size: Vector2 = face.get_multiline_string_size(label.text, HORIZONTAL_ALIGNMENT_LEFT, wrap_width, font_size, -1, flags)
			if label.autowrap_mode == TextServer.AUTOWRAP_OFF and full_size.x > label.size.x + 1:
				result.append("label horizontal overflow: " + label.text)
			var full_lines: int = maxi(label.get_line_count(), ceili(full_size.y / maxf(1, face.get_height(font_size))))
			if label.max_lines_visible >= 0 and full_lines > label.max_lines_visible:
				result.append("label hidden lines: " + label.text)
			var required_height: float = full_size.y + maxi(0, full_lines - 1) * label.get_theme_constant("line_spacing")
			if required_height > label.size.y + 1:
				result.append("label vertical overflow: " + label.text)
		elif child is Button:
			var button: Button = child as Button
			var face: Font = button.get_theme_font("font")
			var font_size: int = button.get_theme_font_size("font_size")
			var style: StyleBox = button.get_theme_stylebox("normal")
			var usable: Vector2 = button.size - style.get_minimum_size()
			if button.icon != null and not button.text.is_empty():
				usable.x -= button.icon.get_width() + button.get_theme_constant("h_separation")
			if not button.text.is_empty():
				var measured: Vector2 = face.get_string_size(button.text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size)
				if measured.x > usable.x + 1 or measured.y > usable.y + 1:
					result.append("button text overflow: " + button.text)
			elif button.icon != null and (button.icon.get_width() > usable.x + 1 or button.icon.get_height() > usable.y + 1):
				result.append("button icon overflow: " + str(button.name))
		if child is Label or child is Button:
			var control: Control = child as Control
			var bounds: Rect2 = control.get_global_rect()
			var viewport_rect := Rect2(Vector2.ZERO, get_viewport_rect().size)
			var discovery_scroll: ScrollContainer = _discovery_scroll_for(control)
			var outside: bool = not viewport_rect.grow(1).encloses(bounds)
			if discovery_scroll != null:
				outside = bounds.position.x < -1 or bounds.end.x > viewport_rect.end.x + 1
			if outside:
				result.append("text outside viewport: %s %s rect=%s" % [control.name, control.get("text"), bounds])
			var ancestor: Node = control.get_parent()
			while ancestor != self and ancestor != null:
				if ancestor is Control and (ancestor as Control).clip_contents:
					var clip: Rect2 = (ancestor as Control).get_global_rect().grow(1)
					var clipped: bool = not clip.encloses(bounds)
					if ancestor == discovery_scroll:
						clipped = bounds.position.x < clip.position.x or bounds.end.x > clip.end.x
					if clipped:
						result.append("text clipped by parent: " + str(control.name))
				ancestor = ancestor.get_parent()
		_scan(child, result)

func _discovery_scroll_for(control: Control) -> ScrollContainer:
	var ancestor: Node = control.get_parent()
	while ancestor != null and ancestor != self:
		if ancestor is ScrollContainer and ancestor.name == "LevelDiscoveryScroll":
			return ancestor as ScrollContainer
		ancestor = ancestor.get_parent()
	return null

func _level_has_placeholder() -> bool:
	if app.session == null:
		return false
	for device: Dictionary in app.session.spec.get("devices", []):
		if str(device.get("type", "")) in ["mine_cart", "lantern_reveal", "nested_box", "bounce", "seesaw", "gust"]:
			return true
	return false
