class_name SdkMaterialMechanic
extends "res://gameplay/mechanics/mechanic.gd"
## An implemented SDK-owned material rule. The shared material/profile layer
## configures the real solver; this adapter exposes its actual state to observe.

func material_names() -> Array[String]:
	return []

func observe() -> Array[Dictionary]:
	var context = session()
	var result: Array[Dictionary] = []
	for material: String in material_names():
		if context.world.material_ids.has(material):
			result.append({"kind": "material", "material": material, "count": context.material_count(Rect2i(0, 0, context.width * 16, context.height * 16), material)})
	return result
