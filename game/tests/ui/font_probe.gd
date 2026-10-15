extends SceneTree
func _initialize() -> void:
	call_deferred("_run")
func _run() -> void:
	print(ClassDB.class_get_property_list("FontVariation").filter(func(item: Dictionary) -> bool: return str(item.name).contains("spacing")))
	var variation := FontVariation.new()
	variation.base_font = PortitorUI.font()
	variation.spacing_top = -2
	print("VARIATION_METRICS=", variation.get_ascent(12), ",", variation.get_height(12))
	for small: bool in [false, true]:
		var font: Font = PortitorUI.font(small)
		var size: int = 10 if small else 12
		var label: Label = PortitorUI.label("界面候选，待确认", 210, small)
		root.add_child(label)
		await process_frame
		print(JSON.stringify({"small":small,"height":font.get_height(size),"ascent":font.get_ascent(size),"descent":font.get_descent(size),"label_font_size":label.get_theme_font_size("font_size"),"label_height":label.get_minimum_size().y,"resource_path":font.resource_path}))
	var app: Node = load("res://app/boot.tscn").instantiate()
	root.add_child(app)
	await process_frame
	for child: Node in app.screen.get_children():
		if child is Label and child.text.contains("候选"):
			print(JSON.stringify({"marker":child.text,"font_size":child.get_theme_font_size("font_size"),"font":child.get_theme_font("font").resource_path,"size":str(child.size),"minimum":str(child.get_minimum_size()),"ascent":child.get_theme_font("font").get_ascent(10),"coverage":child.get_theme_font("font").has_char("候".unicode_at(0)),"lines":child.get_line_count()}))
	app.dispose()
	quit()
