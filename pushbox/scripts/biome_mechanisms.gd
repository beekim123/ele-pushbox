extends RefCounted
## Deterministic round rules. Persistent data is JSON-safe, in level coordinates.
## No SDK calls: commands are submitted through Board and replayed by Session.

static func tile(b: RefCounted, at: Array) -> Vector2i:
	return b.origin + Vector2i(at[0], at[1])

static func local_at(b: RefCounted, at: Vector2i) -> Array:
	return [at.x - b.origin.x, at.y - b.origin.y]

static func active(b: RefCounted, item: Dictionary) -> bool:
	return b.condition(item.active_when) if item.has("active_when") else true

static func contains(b: RefCounted, rect: Array, at: Vector2i) -> bool:
	return Rect2i(tile(b, [rect[0], rect[1]]), Vector2i(rect[2], rect[3])).has_point(at)

static func gravity(b: RefCounted, box: Dictionary) -> int:
	if box.kind == "iron":
		return 1
	for zone in b.mechanisms.get("gravity_zones", []):
		if active(b, zone) and contains(b, zone.rect, box.at):
			return -1
	return 1

static func cloud(b: RefCounted, at: Vector2i) -> bool:
	return local_at(b, at) in b.mechanisms.get("cloud_pads", [])

static func platform(b: RefCounted, at: Vector2i) -> bool:
	for scale in b.mechanisms.get("scales", []):
		var offset: int = int(scale.get("offset", 0))
		if at == tile(b, scale.right) + Vector2i.UP * offset or at == tile(b, scale.left) + Vector2i.DOWN * offset:
			return true
	return false

static func wind(b: RefCounted, at: Vector2i) -> Vector2i:
	for zone in b.mechanisms.get("wind_zones", []):
		if active(b, zone) and contains(b, zone.rect, at):
			return Vector2i.LEFT if zone.direction == "L" else Vector2i.RIGHT
	return Vector2i.ZERO

static func poured_at(b: RefCounted, at: Vector2i) -> Vector2i:
	var target: Vector2i = at + wind(b, at)
	return target if b.inside(target) else at

static func weight(b: RefCounted, at: Vector2i) -> int:
	var index: int = b.box_at(at)
	if index >= 0:
		return 512 if b.boxes[index].kind == "iron" else 256
	return int(b.counts(at).loose)

static func _selected(b: RefCounted, kind: String, selected_kind: String, selected_item: Dictionary) -> Array:
	if selected_kind.is_empty():
		return b.mechanisms.get(kind,[])
	return [selected_item] if kind == selected_kind else []

static func resolve(b: RefCounted, selected_kind: String = "", selected_item: Dictionary = {}) -> bool:
	var changed: bool = false
	for seed in _selected(b,"vine_seeds",selected_kind,selected_item):
		var at: Vector2i = tile(b, seed.at)
		if seed.has("support") and b.tag_count(tile(b, seed.support), "breakable") == 0:
			if seed.get("grown", false) and not seed.get("cut", false):
				seed.cut = true
				for y in int(seed.height):
					b.ladders.erase(at + Vector2i.UP * y)
				changed = true
			continue
		if seed.get("grown", false):
			continue
		for direction in [Vector2i.ZERO, Vector2i.LEFT, Vector2i.RIGHT, Vector2i.UP, Vector2i.DOWN]:
			if material_count(b, at + direction, "water") > 0:
				seed.grown = true
				for y in int(seed.height):
					var rung: Vector2i = at + Vector2i.UP * y
					if b.inside(rung) and b.category(rung) != "SOLID" and not rung in b.ladders:
						b.ladders.append(rung)
				changed = true
				break
	for glass in _selected(b,"hourglasses",selected_kind,selected_item):
		if glass.has("release_move") and b.moves >= int(glass.release_move) and not glass.get("released",false):
			glass.released = true
			for at in glass.get("delayed_tiles",[]):
				changed = convert_material(b,tile(b,at),"levitated_sand","sand") or changed
		if not glass.get("opened", false) and b.condition(glass.open_when):
			glass.opened = true
			if glass.has("delayed_tiles"):
				glass.release_move = b.moves+1
				for at in glass.delayed_tiles:
					convert_material(b,tile(b,at),"sand","levitated_sand")
			for at in glass.tiles:
				b._paint(tile(b, at), "empty")
			changed = true
	for scale in _selected(b,"scales",selected_kind,selected_item):
		var old: int = int(scale.get("offset", 0))
		var left: Vector2i = tile(b, scale.left) + Vector2i.DOWN * old
		var right: Vector2i = tile(b, scale.right) + Vector2i.UP * old
		var lw: int = 0
		var rw: int = 0
		for y in int(scale.get("weight_height",1)):
			lw += weight(b,left + Vector2i.UP*y)
			rw += weight(b,right + Vector2i.UP*y)
		var target: int = int(scale.get("lift", 2)) if lw >= int(scale.get("threshold", 2))*256 and lw > rw else 0
		# Move one tile per round, atomically carrying both pans and actors.
		var step: int = signi(target - old)
		if step == 0:
			continue
		var floors: Array = [left+Vector2i.DOWN,right+Vector2i.DOWN]
		var arms: Array = ["left","right"]
		var removed: Array = []
		for i in 2:
			if material_count(b,floors[i],"scale_platform") == 256:
				restore_tile(b,floors[i],scale.get("under_"+arms[i],{"name":"empty"}))
				removed.append(floors[i])
		var pairs: Array = [[left,Vector2i.DOWN*step],[right,Vector2i.UP*step]]
		var carries: Array[bool] = []
		var movable: bool = true
		for pair in pairs:
			var cargo_tiles: Array = []
			if b.box_at(pair[0]) >= 0:
				cargo_tiles.append(pair[0])
			for y in int(scale.get("weight_height",1)):
				var cargo: Vector2i = pair[0]+Vector2i.UP*y
				if b.counts(cargo).loose > 0:
					cargo_tiles.append(cargo)
			var carry: bool = b.player == pair[0] or (b.box_at(pair[0]) >= 0 and b.player == pair[0]+Vector2i.UP)
			carries.append(carry)
			for cargo in cargo_tiles:
				var dest: Vector2i = cargo+pair[1]
				if not dest in cargo_tiles and not (carry and dest == b.player) and not b.enterable(dest,true):
					movable = false
			if carry and not (b.player+pair[1] in cargo_tiles) and not b.enterable(b.player+pair[1]):
				movable = false
			# Empty pans also stop before entering fixed terrain.
			if cargo_tiles.is_empty() and not b.enterable(pair[0]+pair[1]):
				movable = false
		if not movable:
			for floor_at in removed:
				b._paint(floor_at,"scale_platform")
			continue
		for i in 2:
			var pair: Array = pairs[i]
			var index: int = b.box_at(pair[0])
			if index >= 0:
				b._swap_box(index, pair[0] + pair[1])
			var height: int = int(scale.get("weight_height",1))
			var slots: Array = range(height-1,-1,-1) if pair[1].y < 0 else range(height)
			for y in slots:
				var cargo: Vector2i = pair[0] + Vector2i.UP*y
				if b.counts(cargo).loose > 0:
					move_loose(b, cargo, cargo + pair[1])
			if carries[i]:
				b.player += pair[1]
			var floor_at: Vector2i = pair[0]+pair[1]+Vector2i.DOWN
			scale["under_"+arms[i]] = tile_data(b,floor_at)
			b._paint(floor_at,"scale_platform")
		scale.offset = old + step
		changed = true
	for rock in _selected(b,"stalactites",selected_kind,selected_item):
		if rock.get("fallen", false) or b.tag_count(tile(b, rock.support), "breakable") > 0:
			continue
		var at: Vector2i = tile(b, rock.at)
		var old_at: Vector2i = at
		b._paint(at, "empty")
		while b.inside(at + Vector2i.DOWN):
			var dest: Vector2i = at + Vector2i.DOWN
			if b.tag_count(dest, "breakable") > 0:
				b._paint(dest, "empty")
			if not b.enterable(dest, true):
				break
			at = dest
		swap_tile(b,old_at,at,"bedrock")
		rock.at = local_at(b, at)
		rock.fallen = true
		changed = true
	for jet in _selected(b,"geysers",selected_kind,selected_item):
		if b.moves == 0 or b.moves % int(jet.every) != 0 or int(jet.get("last_move", -1)) == b.moves:
			continue
		jet.last_move = b.moves
		var at: Vector2i = tile(b, jet.at)
		if b.box_at(at) < 0 and b.category(at) == "OPEN" and at != b.player and active(b, jet):
			b._paint(at, jet.get("material", "water"))
			changed = true
	for freezer in _selected(b,"freezers",selected_kind,selected_item):
		var on: bool = active(b, freezer)
		if on == freezer.get("was_on", false):
			continue
		freezer.was_on = on
		if on:
			freezer.frozen = []
			for at in freezer.tiles:
				var point: Vector2i = tile(b, at)
				if b.category(point) == "WATER":
					convert_material(b, point, "water", "ice")
					freezer.frozen.append(at)
		else:
			for at in freezer.get("frozen", []):
				convert_material(b, tile(b, at), "ice", "water")
		changed = true
	for portal in _selected(b,"teleporters",selected_kind,selected_item):
		var source: Vector2i = tile(b, portal.from)
		var dest: Vector2i = tile(b, portal.to)
		if int(portal.get("last_move", -1)) == b.moves or not active(b, portal) or b.box_at(dest) >= 0 or b.player == dest or b.counts(dest).empty != 256:
			continue
		var index: int = b.box_at(source)
		if index >= 0:
			b._swap_box(index, dest)
			portal.last_move = b.moves
			changed = true
		elif b.counts(source).loose > 0:
			move_loose(b, source, dest)
			portal.last_move = b.moves
			changed = true
	for zone in _selected(b,"gravity_zones",selected_kind,selected_item):
		var on: bool = active(b, zone)
		var rect: Array = zone.rect
		for y in range(rect[1], rect[1] + rect[3]):
			for x in range(rect[0], rect[0] + rect[2]):
				var at: Vector2i = tile(b, [x, y])
				if b.counts(at).loose == 0:
					continue
				if on:
					changed = convert_material(b, at, "sand", "levitated_sand") or changed
					changed = convert_material(b, at, "pumice", "levitated_pumice") or changed
					var dest: Vector2i = at
					while dest.y > b.origin.y + int(rect[1]) and b.counts(dest + Vector2i.UP).empty == 256 and dest + Vector2i.UP != b.player:
						dest += Vector2i.UP
					if dest != at:
						move_loose(b, at, dest)
						changed = true
				else:
					changed = convert_material(b, at, "levitated_sand", "sand") or changed
					changed = convert_material(b, at, "levitated_pumice", "pumice") or changed
	return changed

static func convert_material(b: RefCounted, at: Vector2i, source: String, dest: String) -> bool:
	var full: bool = true
	for row in range(at.y * 16, (at.y + 1) * 16):
		var start: int = row * 320 + at.x * 16
		if b.ids.slice(start, start + 16).count(b.name_ids[source]) != 16:
			full = false
			break
	if full:
		b._paint(at, dest)
		return true
	var changed: bool = false
	for y in range(at.y * 16, (at.y + 1) * 16):
		for x in range(at.x * 16, (at.x + 1) * 16):
			if b.ids[y * 320 + x] == b.name_ids[source]:
				b._write_cell(x, y, dest)
				changed = true
	if changed:
		b._dirty_tile(at)
	return changed

static func move_loose(b: RefCounted, source: Vector2i, dest: Vector2i, suspend: bool = false) -> void:
	var first: String = b.names[b.ids[source.y * 16 * 320 + source.x * 16]]
	if b.name_ids[first] in b.tag_material_ids.get("loose", []):
		var full: bool = true
		for row in range(source.y * 16, (source.y + 1) * 16):
			var start: int = row * 320 + source.x * 16
			if b.ids.slice(start, start + 16).count(b.name_ids[first]) != 16:
				full = false
				break
		if full:
			swap_tile(b,source,dest,"levitated_" + first if suspend and first in ["sand", "pumice"] else first)
			return
	for y in 16:
		for x in 16:
			var name: String = b.names[b.ids[(source.y * 16 + y) * 320 + source.x * 16 + x]]
			if not b.name_ids[name] in b.tag_material_ids.get("loose", []):
				continue
			var displaced: String = b.names[b.ids[(dest.y*16+y)*320+dest.x*16+x]]
			b._write_cell(source.x * 16 + x, source.y * 16 + y, displaced)
			if suspend and name in ["sand", "pumice"]:
				name = "levitated_" + name
			b._write_cell(dest.x * 16 + x, dest.y * 16 + y, name)
	b._dirty_tile(source)
	b._dirty_tile(dest)

static func props(b: RefCounted) -> Array:
	var result: Array = []
	for seed in b.mechanisms.get("vine_seeds", []):
		result.append({"at":tile(b, seed.at),"sprite":"vine_ladder_0","label":"遇水向上生藤"})
	for glass in b.mechanisms.get("hourglasses", []):
		result.append({"at":tile(b, glass.tiles[0]),"sprite":"sand_funnel_0","label":"定量流沙漏斗"})
	for scale in b.mechanisms.get("scales", []):
		var offset: int = int(scale.get("offset", 0))
		for pair in [[scale.left, Vector2i.DOWN], [scale.right, Vector2i.UP]]:
			result.append({"at":tile(b, pair[0]) + pair[1] * offset,"sprite":"scale_pan_0","label":"左重右升托箱"})
	for rock in b.mechanisms.get("stalactites", []):
		result.append({"at":tile(b, rock.at),"sprite":"stalactite_0","label":"断根直落重锤"})
	for jet in b.mechanisms.get("geysers", []):
		result.append({"at":tile(b, jet.at),"sprite":"geyser_0","label":"重物镇压泉眼"})
	for at in b.mechanisms.get("cloud_pads", []):
		result.append({"at":tile(b, at),"sprite":"cloud_pad_0","label":"托木箱沉铁箱"})
	for zone in b.mechanisms.get("wind_zones", []):
		result.append({"at":tile(b, [zone.rect[0], zone.rect[1]]),"sprite":"wind_emitter_0","label":"顺风扬沙滑箱"})
	for zone in b.mechanisms.get("gravity_zones", []):
		result.append({"at":tile(b, [zone.rect[0], zone.rect[1]]),"sprite":"gravity_console_0","label":"轻箱沙吸舱顶"})
	for portal in b.mechanisms.get("teleporters", []):
		for key in ["from", "to"]:
			result.append({"at":tile(b, portal[key]),"sprite":"quantum_pad_0","label":"发射量子传送" if key == "from" else "接收保持空位"})
	return result

static func canonical(value: Variant) -> Variant:
	# JSON parses numbers as floats. Normalize both author data and restored state
	# so Array/Dictionary equality and hint keys match live integer mutations.
	if value is float:
		return int(value)
	if value is Array:
		return value.map(canonical)
	if value is Dictionary:
		var result: Dictionary = {}
		for key in value:
			result[str(key)] = canonical(value[key])
		return result
	return value

static func material_count(b: RefCounted, at: Vector2i, name: String) -> int:
	if not b.inside(at):
		return 0
	var total: int = 0
	for y in range(at.y*16,(at.y+1)*16):
		var start: int = y*320+at.x*16
		total += b.ids.slice(start,start+16).count(b.name_ids[name])
	return total


static func swap_tile(b: RefCounted, source: Vector2i, dest: Vector2i, material: String) -> void:
	var contents := PackedInt32Array()
	for y in range(dest.y*16,(dest.y+1)*16):
		contents.append_array(b.ids.slice(y*320+dest.x*16,y*320+(dest.x+1)*16))
	b._paint(source,"empty")
	b._paint(dest,material)
	if source != dest:
		for i in contents.size():
			if contents[i] != 0:
				b._write_cell(source.x*16+i%16,source.y*16+i/16,b.names[contents[i]])
		if contents.count(0) != contents.size():
			b._dirty_tile(source)

static func tile_data(b: RefCounted, at: Vector2i) -> Dictionary:
	var contents := PackedInt32Array()
	for y in range(at.y*16,(at.y+1)*16):
		contents.append_array(b.ids.slice(y*320+at.x*16,y*320+(at.x+1)*16))
	if contents.count(contents[0]) == 256:
		return {"name":b.names[contents[0]]}
	return {"cells":Array(contents)}

static func restore_tile(b: RefCounted, at: Vector2i, data: Dictionary) -> void:
	if data.has("name"):
		b._paint(at,data.name)
	else:
		b._paint(at,"empty")
		for i in 256:
			if int(data.cells[i]) != 0:
				b._write_cell(at.x*16+i%16,at.y*16+i/16,b.names[int(data.cells[i])])
		b._dirty_tile(at)
