extends Node
const Game := preload("res://pushbox/scripts/game.gd")
const Smoke := preload("res://verification/package_smoke.gd")
const License := preload("res://verification/engine_license.gd")

func _ready() -> void:
	var arguments: PackedStringArray = OS.get_cmdline_user_args()
	if arguments.has("--package-smoke"):
		add_child(Smoke.new())
	elif arguments.has("--package-license"):
		add_child(License.new())
	else:
		get_tree().root.add_child.call_deferred(Game.new())
		queue_free()
