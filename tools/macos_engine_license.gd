extends Node

func _ready() -> void:
	print(Engine.get_license_text())
	print(JSON.stringify(Engine.get_copyright_info(), "  "))
	var licenses: Dictionary = Engine.get_license_info()
	for name in licenses:
		print("\n" + str(name) + "\n" + str(licenses[name]))
	get_tree().quit(0)
