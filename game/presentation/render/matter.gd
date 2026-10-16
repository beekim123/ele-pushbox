class_name MatterPresentation
extends RefCounted
## Approved matter.js device composition, driven by live game state.
## Magenta blocks with a question mark are explicitly unfinished device art.

const LadderTops = preload("res://presentation/render/ladder_tops.gd")
const Sprites = preload("res://presentation/render/sprites/sprite_assets.gd")
const RULE_ICONS: Dictionary = {8: "slow", 9: "burn", 11: "etch", 12: "etch", 14: "rise", 15: "sink", 17: "burn", 18: "freeze"}
const CLASS_ICONS: Dictionary = {7: "solid", 8: "sand", 9: "solid", 10: "water", 11: "solid", 12: "solid", 13: "solid", 16: "solid", 17: "solid", 18: "solid"}

static func anchor(origin: Vector2i, x: int, y: int) -> Vector2i:
	return origin + Vector2i(x * 16 + 8, y * 16 + 16)

static func floating(state: Dictionary, crate: Dictionary) -> bool:
	var x: int = int(crate.x)
	var y: int = int(crate.y)
	var width: int = int(state.w)
	return str(crate.kind) == "wood" and y + 1 < int(state.h) and int(state.terrain[y * width + x]) != 5 and int(state.terrain[(y + 1) * width + x]) == 5

static func draw_devices(raster: RefCounted, state: Dictionary, origin: Vector2i, tick: int, opening_spec: Dictionary = {}) -> void:
	var devices: Array = state.get("devices", [])
	for device: Dictionary in devices:
		if str(device.get("type", "")) != "lift" or device.get("stops", []).size() != 2:
			continue
		var a: Array = device.stops[0]
		var b: Array = device.stops[1]
		var span: int = maxi(1, int(device.get("width", 1)))
		for y: int in range(mini(int(a[1]), int(b[1])), maxi(int(a[1]), int(b[1])) + 1):
			asset(raster, "art:mech.lift", "rail", 0, anchor(origin, int(a[0]), y))
			asset(raster, "art:mech.lift", "rail", 0, anchor(origin, int(a[0]) + span - 1, y), true)
	for device_index: int in range(devices.size()):
		var device: Dictionary = devices[device_index]
		var kind: String = str(device.get("type", ""))
		var at: Array = device.get("at", [])
		match kind:
			"lift":
				var stops: Array = device.get("stops", [])
				if stops.size() != 2:
					continue
				var stop: Array = stops[clampi(int(device.get("stop", 0)), 0, 1)]
				for x: int in range(maxi(1, int(device.get("width", 1)))):
					asset(raster, "art:mech.lift", "deck", 0, anchor(origin, int(stop[0]) + x, int(stop[1])))
				var button: Array = device.get("button", [])
				if button.size() == 2:
					asset(raster, "art:mech.button", "down" if occupied(state, int(button[0]), int(button[1])) else "up", 0, anchor(origin, int(button[0]), int(button[1])))
			"portal":
				var symbol: String = str(device.get("symbol", ["circle", "triangle", "square"][device_index % 3]))
				for pad: Array in device.get("pads", []):
					var tile: int = int(pad[1]) * int(state.w) + int(pad[0])
					var lit: bool = false
					for lock: Dictionary in device.get("blocked", []):
						lit = lit or int(lock.get("pad", -1)) == tile
					var point: Vector2i = anchor(origin, int(pad[0]), int(pad[1]))
					asset(raster, "art:mech.portal", "glow" if lit else "idle", tick, point)
					if not occupied(state, int(pad[0]), int(pad[1])):
						asset(raster, "art:mech.link_symbol", symbol, 0, point - Vector2i(0, 7))
			"bridge":
				if bool(device.get("broken", false)):
					continue
				var cells: Array = device.get("cells", [])
				var capacity: int = maxi(1, int(device.get("capacity", 1)))
				var load: int = maxi(0, int(device.get("load", 0)))
				for cell: Array in cells:
					asset(raster, "art:mech.bridge", "strained" if load >= capacity else "intact", 0, anchor(origin, int(cell[0]), int(cell[1])))
				if not cells.is_empty():
					var start: Array = cells[0]
					var x0: int = origin.x + int(start[0]) * 16 + ((cells.size() * 16 - (capacity * 3 - 2)) >> 1)
					for weight: int in range(capacity):
						raster.rect(x0 + weight * 3, origin.y + int(start[1]) * 16 + 1, 1, 3, ("i" if load >= capacity else "l") if weight < load else "F")
			"bin":
				var rect: Array = device.get("rect", [])
				if rect.size() != 4:
					continue
				for y: int in range(int(rect[1]), int(rect[1]) + int(rect[3])):
					asset(raster, "art:mech.bin", "left", 0, anchor(origin, int(rect[0]), y))
					asset(raster, "art:mech.bin", "right", 0, anchor(origin, int(rect[0]) + int(rect[2]) - 1, y))
				for x: int in range(int(rect[0]), int(rect[0]) + int(rect[2])):
					asset(raster, "art:mech.bin", "bottom", 0, anchor(origin, x, int(rect[1]) + int(rect[3]) - 1))
				var need: int = maxi(1, int(device.get("need", 256)))
				var count: int = maxi(0, int(device.get("count", 0)))
				var level: String = "full" if bool(device.get("latched", false)) or count >= need else str(clampi(int(count * 4 / need), 0, 4))
				asset(raster, "art:mech.bin_gauge", level, 0, Vector2i(origin.x + (int(rect[0]) + int(rect[2])) * 16 + 3, origin.y + (int(rect[1]) + int(rect[3])) * 16))
			"lever", "torch", "frost_vent", "heat_vent":
				if at.size() != 2:
					continue
				var on: bool = bool(device.get("on", false))
				var animation: String = ("on" if on else "off") if kind == "lever" else ("lit" if on else "off") if kind == "torch" else ("active" if on else "idle")
				asset(raster, "art:mech." + kind, animation, tick, anchor(origin, int(at[0]), int(at[1])))
				if kind == "lever":
					asset(raster, "art:mech.link_symbol", str(device.get("symbol", "circle")), 0, anchor(origin, int(at[0]), int(at[1])) - Vector2i(0, 7))
			"vine":
				var root: Array = device.get("root", [])
				if root.size() != 2:
					continue
				if bool(device.get("grown", false)):
					var height: int = maxi(0, int(device.get("height", 1)))
					for row: int in range(height):
						var x: int = int(root[0])
						var y: int = int(root[1]) - row
						# Actual grown cells, rather than a second wooden ladder layer.
						if device.has("ladder_cells") and not LadderTops.vine_cells(state).has(y * int(state.w) + x): continue
						var rows: int = LadderTops.KEEP_ROWS if LadderTops.is_top(opening_spec, state.get("markers", []), x, y) else -1
						Sprites.blit(raster, "art:mech.vine", "top" if row == height - 1 else "stem", 0, anchor(origin, x, y), false, rows)
				asset(raster, "art:mech.vine", "root", 0, anchor(origin, int(root[0]), int(root[1])))
			"release", "nested_box":
				pass # Release material is already visible; nested crates draw in entity order.
			"lantern_reveal":
				for cell: Array in device.get("cells", []):
					placeholder(raster, anchor(origin, int(cell[0]), int(cell[1])), cell in device.get("lit_cells", []))
			"seesaw":
				for cell: Array in device.get("ends", []):
					placeholder(raster, anchor(origin, int(cell[0]), int(cell[1])))
			"mine_cart":
				# Track art is also missing; hollow question-mark tiles make that
				# limitation visible along the entire route, including after rolling.
				for cell: Array in device.get("track", []):
					placeholder(raster, anchor(origin, int(cell[0]), int(cell[1])), false)
				if at.size() == 2:
					for x: int in range(maxi(1, int(device.get("width", 1)))):
						placeholder(raster, anchor(origin, int(at[0]) + x, int(at[1])))
			_:
				if at.size() == 2:
					for x: int in range(maxi(1, int(device.get("width", 1)))):
						placeholder(raster, anchor(origin, int(at[0]) + x, int(at[1])))
				elif device.get("area", []).size() == 4:
					var area: Array = device.area
					placeholder(raster, anchor(origin, int(area[0]), int(area[1])))

static func occupied(state: Dictionary, x: int, y: int) -> bool:
	if int(state.player.x) == x and int(state.player.y) == y:
		return true
	for crate: Dictionary in state.crates:
		if int(crate.x) == x and int(crate.y) == y:
			return true
	return false

static func asset(raster: RefCounted, uid: String, animation: Variant, tick: int, point: Vector2i, flip: bool = false) -> void:
	if Sprites.has(uid):
		Sprites.blit(raster, uid, animation, tick, point, flip)
	else:
		placeholder(raster, point)

static func placeholder(raster: RefCounted, point: Vector2i, solid: bool = true, size: int = 14) -> void:
	var start: Vector2i = point - Vector2i(size >> 1, size)
	if solid:
		raster.rect(start.x, start.y, size, size, "B")
	else:
		dashed_rect(raster, Rect2i(start, Vector2i(size, size)), "B")
	# A magenta question mark labels every placeholder independently of colour.
	var glyph: Array[String] = ["111", "001", "010", "000", "010"]
	for y: int in range(glyph.size()):
		for x: int in range(3):
			if glyph[y].substr(x, 1) == "1":
				raster.set_code(point.x - 1 + x, start.y + 2 + y, "D")

static func draw_observe(raster: RefCounted, state: Dictionary, origin: Vector2i, groups: Array, observations: Array) -> void:
	var width: int = int(state.w)
	for index: int in range(state.terrain.size()):
		var material: int = int(state.terrain[index])
		if material < 7:
			continue
		var point: Vector2i = anchor(origin, index % width, int(index / width)) - Vector2i(0, 8)
		var class_icon: String = str(CLASS_ICONS.get(material, ""))
		var rule_icon: String = str(RULE_ICONS.get(material, ""))
		if not class_icon.is_empty():
			asset(raster, "art:ui.class_icon", class_icon, 0, point - Vector2i(3, 0))
		if not rule_icon.is_empty():
			asset(raster, "art:ui.rule_icon", rule_icon, 0, point + Vector2i(3 if not class_icon.is_empty() else 0, 0))
	var devices: Array = state.get("devices", [])
	for device: Dictionary in devices:
		var kind: String = str(device.get("type", ""))
		var from: Vector2i = device_centre(device, origin)
		if kind == "torch" and device.get("area", []).size() == 4:
			var area: Array = device.area
			var center: Vector2i = origin + Vector2i(int(area[0]) * 16 + int(area[2]) * 8, int(area[1]) * 16 + int(area[3]) * 8)
			dashed_circle(raster, center, mini(int(area[2]), int(area[3])) * 8, "j")
		elif kind in ["frost_vent", "heat_vent", "gust"] and device.get("area", []).size() == 4:
			dashed_rect(raster, tile_rect(device.area, origin), {"frost_vent": "s", "heat_vent": "k", "gust": "D"}[kind])
		if kind == "release":
			for cell: Array in device.get("cells", []):
				dashed_rect(raster, Rect2i(origin + Vector2i(int(cell[0]), int(cell[1])) * 16 + Vector2i.ONE, Vector2i(14, 14)), "C")
		if kind == "bin" and device.get("rect", []).size() == 4:
			dashed_rect(raster, tile_rect(device.rect, origin), "l")
		if kind == "lift" and device.get("button", []).size() == 2:
			var button: Array = device.button
			dotted(raster, anchor(origin, int(button[0]), int(button[1])) - Vector2i(0, 4), from, "s")
		if kind == "portal" and device.get("pads", []).size() == 2:
			var a: Array = device.pads[0]
			var b: Array = device.pads[1]
			dotted(raster, anchor(origin, int(a[0]), int(a[1])) - Vector2i(0, 8), anchor(origin, int(b[0]), int(b[1])) - Vector2i(0, 8), "s")
		var link: Dictionary = device.get("action", {}) if kind == "lever" else device.get("trigger", {})
		if link.has("link"):
			var group: int = int(link.link)
			if group >= 0 and group < groups.size():
				for door: int in groups[group].get("doors", []):
					dotted(raster, from, anchor(origin, door % width, int(door / width)) - Vector2i(0, 8), "s")
		var destination: int = int(link.get("device", link.get("release", -1)))
		if destination >= 0 and destination < devices.size():
			dotted(raster, from, device_centre(devices[destination], origin), "s")
	for info: Dictionary in observations:
		# Seesaw paths describe the real swept route: rise, then cross at the
		# apex. Show both routes before activation, including their landings.
		for path: Array in info.get("paths", []):
			draw_path(raster, path, origin, "s")
		for landing: Array in info.get("landings", []):
			if landing.size() == 2:
				dashed_rect(raster, Rect2i(origin + Vector2i(int(landing[0]), int(landing[1])) * 16 + Vector2i.ONE, Vector2i(14, 14)), "s")
		var launch: Dictionary = info.get("last_launch", info.get("last_slide", info.get("last_roll", {})))
		var own_launch: bool = not launch.has("device") or int(launch.device) == int(info.get("device", -1))
		if own_launch and launch.get("from", []).size() == 2 and launch.get("to", []).size() == 2:
			var a: Array = launch.from
			var b: Array = launch.to
			var trace: Array = launch.get("path", [])
			if trace.is_empty():
				for path: Array in info.get("paths", []):
					if not path.is_empty() and path[0] == a and path[path.size() - 1] == b:
						trace = path
						break
			if trace.is_empty():
				trace = [a, [int(a[0]), int(b[1])], b] if str(info.get("type", info.get("kind", ""))) == "seesaw" else [a, b]
			draw_path(raster, trace, origin, "D")
		for blow: Dictionary in info.get("last_blow", []):
			var a: Array = blow.get("from", [])
			var b: Array = blow.get("to", [])
			if a.size() == 2 and b.size() == 2:
				dotted(raster, anchor(origin, int(a[0]), int(a[1])) - Vector2i(0, 8), anchor(origin, int(b[0]), int(b[1])) - Vector2i(0, 8), "D")

static func device_centre(device: Dictionary, origin: Vector2i) -> Vector2i:
	var point: Array = device.get("at", device.get("root", []))
	if str(device.get("type", "")) == "lift" and device.get("stops", []).size() == 2:
		point = device.stops[clampi(int(device.get("stop", 0)), 0, 1)]
	elif device.get("rect", []).size() == 4:
		point = device.rect.slice(0, 2)
	elif point.is_empty():
		for key: String in ["cells", "pads", "ends", "area"]:
			var values: Array = device.get(key, [])
			if values.is_empty():
				continue
			point = values[0] if values[0] is Array else values.slice(0, 2)
			break
	return anchor(origin, int(point[0]), int(point[1])) - Vector2i(0, 8) if point.size() == 2 else origin

static func tile_rect(values: Array, origin: Vector2i) -> Rect2i:
	return Rect2i(origin + Vector2i(int(values[0]), int(values[1])) * 16, Vector2i(int(values[2]), int(values[3])) * 16)

static func draw_path(raster: RefCounted, path: Array, origin: Vector2i, code: String) -> void:
	var previous: Vector2i = Vector2i.ZERO
	var found: bool = false
	var last_tile: Vector2i = Vector2i.ZERO
	for cell: Array in path:
		if cell.size() != 2:
			continue
		last_tile = Vector2i(int(cell[0]), int(cell[1]))
		var point: Vector2i = anchor(origin, last_tile.x, last_tile.y) - Vector2i(0, 8)
		if found:
			dotted(raster, previous, point, code)
		previous = point
		found = true
	if found:
		dashed_rect(raster, Rect2i(origin + last_tile * 16 + Vector2i.ONE, Vector2i(14, 14)), code)

static func dashed_rect(raster: RefCounted, rect: Rect2i, code: String) -> void:
	for x: int in range(rect.size.x):
		if ((x >> 1) & 1) == 0:
			raster.set_code(rect.position.x + x, rect.position.y, code)
			raster.set_code(rect.position.x + x, rect.end.y - 1, code)
	for y: int in range(rect.size.y):
		if ((y >> 1) & 1) == 0:
			raster.set_code(rect.position.x, rect.position.y + y, code)
			raster.set_code(rect.end.x - 1, rect.position.y + y, code)

static func dotted(raster: RefCounted, a: Vector2i, b: Vector2i, code: String) -> void:
	var count: int = maxi(1, maxi(absi(a.x - b.x), absi(a.y - b.y)))
	for index: int in range(0, count + 1, 2):
		var point: Vector2 = Vector2(a).lerp(Vector2(b), float(index) / count)
		raster.set_code(roundi(point.x), roundi(point.y), code)

static func dashed_circle(raster: RefCounted, center: Vector2i, radius: int, code: String) -> void:
	for y: int in range(-radius, radius + 1):
		for x: int in range(-radius, radius + 1):
			var distance: int = x * x + y * y
			if distance <= radius * radius and distance >= (radius - 1) * (radius - 1) and posmod(x + y, 3) != 0:
				raster.set_code(center.x + x, center.y + y, code)
