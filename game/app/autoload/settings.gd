class_name SettingsService
extends Node

signal changed
signal value_changed(key: String, value: Variant)

const DEFAULTS: Dictionary = {"language": "zh-Hans", "music": 0.8, "sfx": 0.8, "window_scale": "auto", "ambience": "full", "show_grid": false, "open_all_levels": false, "typewriter": true}
var values: Dictionary = DEFAULTS.duplicate(true)

func _ready() -> void:
	var save := get_node_or_null("/root/Save")
	if save != null:
		var stored: Dictionary = save.data.get("settings", {})
		for key in stored:
			if DEFAULTS.has(key):
				_set_normalized(key, stored[key])
	var locale := get_node_or_null("/root/Locale")
	if locale != null:
		locale.language = str(values.language)

func set_value(key: String, value: Variant) -> void:
	if not DEFAULTS.has(key):
		return
	var previous: Variant = values.get(key)
	_set_normalized(key, value)
	if values.get(key) == previous:
		return
	if is_inside_tree():
		var save := get_node_or_null("/root/Save")
		if save != null:
			save.data["settings"] = values.duplicate(true)
			save.save_progress()
		if key == "language":
			var locale := get_node_or_null("/root/Locale")
			if locale != null:
				locale.language = str(values.language)
	changed.emit()
	value_changed.emit(key, values[key])
	if is_inside_tree():
		var events := get_node_or_null("/root/Events")
		if events != null:
			events.settings_changed.emit(key, values[key])

func _set_normalized(key: String, value: Variant) -> void:
	match key:
		"music", "sfx":
			values[key] = clampf(float(value), 0.0, 1.0)
		"window_scale":
			if str(value) == "auto":
				values[key] = "auto"
			else:
				values[key] = clampi(int(value), 1, 6)
		"ambience":
			if str(value) in ["full", "lights", "off"]:
				values[key] = str(value)
		"language":
			if str(value) in ["zh-Hans", "en"]:
				values[key] = str(value)
		_:
			values[key] = bool(value)
