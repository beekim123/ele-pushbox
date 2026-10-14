extends RefCounted
## Compatibility facade for earlier callers of the procedural image API.
const Registry := preload("res://pushbox/scripts/art/art_registry.gd")

static func names() -> Array:
	return Registry.names()

static func image(name: String) -> Image:
	return Registry.image(name)
