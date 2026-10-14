extends RefCounted
## Shared gate presentation: fixed emitters or repeating mechanical slats.
const Style := preload("res://pushbox/scripts/ui/pixel_style.gd")
const Art := preload("res://pushbox/scripts/art/art_registry.gd")

static func tile(canvas: CanvasItem, at: Vector2, theme_id: String, i: int, count: int, openness: float) -> void:
	if Art.theme(theme_id).gate_mode == "energy":
		var accent: Color = Art.theme(theme_id).colors.accent
		if i == 0:
			canvas.draw_rect(Rect2(at,Vector2(16,3)),Style.INK)
			canvas.draw_rect(Rect2(at+Vector2(2,1),Vector2(12,1)),accent)
		if i == count-1:
			canvas.draw_rect(Rect2(at+Vector2(0,13),Vector2(16,3)),Style.INK)
			canvas.draw_rect(Rect2(at+Vector2(2,14),Vector2(12,1)),accent)
		var remaining: float = 1.0-openness
		if remaining > 0.0:
			var width: int = maxi(1,roundi(6*remaining))
			var top: int = 3 if i == 0 else 0
			var bottom: int = 13 if i == count-1 else 16
			canvas.draw_rect(Rect2(at+Vector2(floori((16-width)/2.0),top),Vector2(width,bottom-top)),Color(accent,remaining))
	else:
		var height: int = int(openness*16)
		if height < 16:
			canvas.draw_texture_rect_region(Style.themed_texture("gate_closed_0",theme_id),Rect2(at,Vector2(16,16-height)),Rect2(0,(i%2)*16+height,16,16-height))
