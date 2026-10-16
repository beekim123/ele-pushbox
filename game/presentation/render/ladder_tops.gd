class_name LadderTopPresentation
extends RefCounted
## Platform heads retain their logical climb cell and only four visible rows.
## Use the authored opening for landings so moving boxes never toggle the cap.
const KEEP_ROWS: int = 4
static func is_top(spec: Dictionary, markers: Array, x: int, y: int) -> bool:
	var rows: Array = spec.get("map", [])
	if rows.is_empty(): return false
	var width: int = str(rows[0]).length()
	if y <= 0 or y + 1 >= rows.size() or x < 0 or x >= width: return false
	if markers.size() != width * rows.size(): return false
	if int(markers[y * width + x]) != 1 or int(markers[(y - 1) * width + x]) == 1 or int(markers[(y + 1) * width + x]) != 1: return false
	for dx: int in [-1, 1]:
		if x + dx < 0 or x + dx >= width: continue
		var landing: String = str(rows[y]).substr(x + dx, 1)
		var below: String = str(rows[y + 1]).substr(x + dx, 1)
		if landing in ".HhoXP_BIb~a^v" and below not in ".HhoXP_~a^v|": return true
	return false
static func vine_cells(state: Dictionary) -> Dictionary:
	var result: Dictionary = {}
	var width: int = int(state.w)
	for device: Dictionary in state.get("devices", []):
		if str(device.get("type", "")) == "vine" and bool(device.get("grown", false)):
			for cell: Array in device.get("ladder_cells", []):
				result[int(cell[1]) * width + int(cell[0])] = true
	return result
