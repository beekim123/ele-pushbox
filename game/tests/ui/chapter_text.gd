extends SceneTree
## Every new chapter hint must fit the existing four-line bubble in both locales.
var issues: Array[Dictionary] = []
var checked: int = 0
func _initialize() -> void: call_deferred("_run")
func _run() -> void:
	var locale: Node = root.get_node("Locale")
	var registry: Node = root.get_node("Registry")
	for language: String in ["zh-Hans","en"]:
		locale.set_language(language)
		for entry: Dictionary in registry.all("level"):
			var spec: Dictionary = registry.level_spec(str(entry.uid))
			if str(spec.get("group","")) not in ["blast","react","thermal","experimental"]: continue
			for index: int in range(1,4):
				var key: String = "text:level." + str(spec.id) + ".hint." + str(index)
				var text: String = locale.text(key)
				var bubble := PortitorBubble.new()
				root.add_child(bubble)
				bubble.configure(text,Vector2(160,100),str(spec.id),"")
				checked += 1
				if not bubble.issues.is_empty() or text == key.trim_prefix("text:"):
					issues.append({"locale":language,"id":spec.id,"hint":index,"text":text,"issues":bubble.issues.duplicate()})
				bubble.free()
	var result: Dictionary = {"suite":"chapter-text","ok":issues.is_empty(),"checked":checked,"issues":issues}
	var file := FileAccess.open("res://tests/results/chapter-text.json",FileAccess.WRITE)
	if file == null: quit(1); return
	file.store_string(JSON.stringify(result,"\t"))
	file.close()
	print(JSON.stringify({"suite":"chapter-text","ok":issues.is_empty(),"checked":checked,"issue_count":issues.size()}))
	quit(0 if issues.is_empty() else 1)
