extends SceneTree

func _initialize() -> void:
	if not ClassDB.class_exists("EleWorld"):
		print("FAIL M0: EleWorld extension is unavailable")
		quit(1)
		return
	var world: Node = ClassDB.instantiate("EleWorld")
	root.add_child(world)
	world.world_size = Vector2i(320, 192)
	world.seed = 1
	world.threads = 1
	world.auto_step = false
	world.render_enabled = false
	world.collision_enabled = false
	world.materials_path = "res://pushbox/content/default/materials.json"
	world.profile_path = "res://pushbox/content/default/profile.json"
	world.reactions_path = "res://pushbox/content/default/reactions.json"
	var error: int = world.start()
	if error != 0:
		print("FAIL M0: start=%s %s" % [error, world.get_last_error()])
		world.free()
		quit(1)
		return
	assert(world.get_material_ids(0, 0, 320, 192).size() == 61440)
	assert(world.material_id("sand") > 0)
	assert(world.step(1) == 0)
	print("PASS M0: locked content loads; 320x192 world starts; tick=%d" % world.get_tick())
	world.stop()
	world.free()
	quit(0)
