class_name LocaleService
extends Node

signal changed
signal language_changed(language: String)

var language: String = "zh-Hans":
	set(value):
		var next := value if value in ["zh-Hans", "en"] else "zh-Hans"
		if next == language:
			return
		language = next
		TranslationServer.set_locale("zh_CN" if language == "zh-Hans" else "en")
		changed.emit()
		language_changed.emit(language)

var _translations: Array[Translation] = []

func _ready() -> void:
	load_translations()
	TranslationServer.set_locale("zh_CN" if language == "zh-Hans" else "en")

func load_translations() -> void:
	for old in _translations:
		TranslationServer.remove_translation(old)
	_translations.clear()
	for locale in ["zh-Hans", "en"]:
		var location := "res://generated/content/i18n/%s.json" % locale
		if not FileAccess.file_exists(location):
			continue
		var data: Variant = JSON.parse_string(FileAccess.get_file_as_string(location))
		if not data is Dictionary:
			continue
		var translation := Translation.new()
		translation.locale = "zh_CN" if locale == "zh-Hans" else "en"
		for key in data:
			if data[key] is String:
				translation.add_message(key, data[key])
		TranslationServer.add_translation(translation)
		_translations.append(translation)

func text(uid: String, params: Dictionary = {}) -> String:
	var key := uid.trim_prefix("text:")
	var result := str(TranslationServer.translate(key))
	for name in params:
		result = result.replace("{" + str(name) + "}", str(params[name]))
	return result

func set_language(value: String) -> void:
	language = value
