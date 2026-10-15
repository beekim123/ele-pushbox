class_name AmbientLife
extends RefCounted
## Placement and integer motion from ambient.js. Returns sprite commands so the
## renderer can share the same approved asset path for world and menu scenes.
const Raster = preload("res://presentation/render/palette_raster.gd")
const MOVERS: Array[String] = ["walker", "percher", "flyer", "hanger"]

static func tri(tick: int, period: int, amplitude: int) -> int:
	var p: int = posmod(tick, period)
	return floori(float((p if p < (period >> 1) else period - p) * 4 * amplitude) / period) - amplitude

static func seed_of(value: String) -> int:
	var hash: int = 0
	for i: int in range(value.length()):
		hash = Raster.h32(hash, value.unicode_at(i), 907)
	return hash

static func at(map: Dictionary, x: int, y: int) -> int:
	if x < 0 or y < 0 or x >= int(map.w) or y >= int(map.h):
		return 0
	return mini(5, int(map.terrain[y * int(map.w) + x])) if int(map.terrain[y * int(map.w) + x]) <= 5 else 0

static func solid(material: int) -> bool:
	return material == 1 or material == 2 or material == 3

static func candidates(map: Dictionary, occupied: Callable, kind: String, salt: int) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for y: int in range(map.h):
		for x: int in range(map.w):
			if at(map, x, y) != 0 or (occupied.is_valid() and occupied.call(x, y)):
				continue
			if solid(at(map, x, y + 1 if kind == "floor" else y - 1)):
				result.append({"tx": x, "ty": y, "hash": Raster.h32(x, y, 771 + salt)})
	result.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return int(a.hash) < int(b.hash))
	return result

static func _opening_candidates(map: Dictionary, occupied: Callable, kind: String, salt: int, opts: Dictionary) -> Array[Dictionary]:
	# Opt-in cache owned by one WorldView opening. Occupancy is the immutable
	# opening layout; dynamic "alive" filtering is still evaluated every frame.
	var cache: Variant = opts.get("candidate_cache")
	if not cache is Dictionary:
		return candidates(map, occupied, kind, salt)
	var key: String = "%s:%d" % [kind, salt]
	if not cache.has(key):
		if cache.size() >= 16:
			cache.erase(cache.keys()[0])
		cache[key] = candidates(map, occupied, kind, salt)
	return cache[key]

static func longest_run(cands: Array[Dictionary]) -> Dictionary:
	var rows: Dictionary = {}
	for c: Dictionary in cands:
		if not rows.has(c.ty):
			rows[c.ty] = []
		rows[c.ty].append(c.tx)
	var best: Dictionary = {}
	for y: int in rows:
		var xs: Array = rows[y]
		xs.sort()
		var start: int = xs[0]
		var previous: int = xs[0]
		for i: int in range(1, xs.size() + 1):
			if i < xs.size() and int(xs[i]) == previous + 1:
				previous = xs[i]
				continue
			var length: int = previous - start + 1
			if best.is_empty() or length > int(best.len) or (length == int(best.len) and y > int(best.ty)):
				best = {"ty": y, "x0": start, "len": length}
			if i < xs.size():
				start = xs[i]
				previous = xs[i]
	return best

static func pick_mover(list: Array, mode: String, seed: int) -> Array[int]:
	var ordered: Array[Dictionary] = []
	var ordinal: int = 0
	var result: Array[int] = []
	for i: int in range(list.size()):
		if MOVERS.has(list[i].type):
			ordered.append({"index": i, "hash": Raster.h32(seed, ordinal, 901)})
			ordinal += 1
	ordered.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return int(a.hash) < int(b.hash))
	if mode == "full":
		for item: Dictionary in ordered:
			result.append(item.index)
	elif not ordered.is_empty():
		if mode == "one":
			result.append(ordered[0].index)
		else:
			for item: Dictionary in ordered:
				if int(item.hash) % 100 < floori(float(list[item.index].get("chance", 0.3)) * 100 + 0.5):
					result.append(item.index)
					break
	return result

static func plan(theme: Dictionary, map: Dictionary, origin: Vector2i, tick: int, layer: String, occupied: Callable, area: Rect2i, alive: Callable, opts: Dictionary = {}) -> Array[Dictionary]:
	var list: Array = theme.get("ambient", [])
	var movers: Array[int] = pick_mover(list, opts.get("mode", "sparse"), int(opts.get("seed", 0)))
	var used: Dictionary = {}
	var commands: Array[Dictionary] = []
	var flyer_index: int = 0
	var has_asset: Callable = opts.get("has", Callable())
	for index: int in range(list.size()):
		var a: Dictionary = list[index]
		if has_asset.is_valid() and not has_asset.call("art:" + str(a.id)):
			continue
		if MOVERS.has(a.type) and not movers.has(index):
			continue
		var back: bool = ["wall", "hanger", "flyer"].has(a.type)
		if (layer == "back") != back:
			if a.type == "flyer":
				flyer_index += int(a.get("count", 1))
			continue
		match str(a.type):
			"floor", "hang":
				var cands: Array[Dictionary] = _opening_candidates(map, occupied, "floor" if a.type == "floor" else "ceiling", int(a.get("salt", 0)), opts)
				cands = cands.filter(func(c: Dictionary) -> bool: return not used.has(Vector2i(c.tx, c.ty)))
				var count: int = mini(int(a.get("max", 2)), ceili(float(cands.size()) / int(a.get("every", 4))))
				for c: Dictionary in cands.slice(0, count):
					used[Vector2i(c.tx, c.ty)] = true
					if alive.is_valid() and not alive.call(c.tx, c.ty):
						continue
					var x: int = origin.x + int(c.tx) * 16 + 5 + int(c.hash) % 7
					var y: int = origin.y + int(c.ty) * 16 + (16 if a.type == "floor" else 0)
					commands.append(_command(a.id, a.get("anim", "default"), tick + int(c.hash) % 97, x, y, (int(c.hash) >> 3) & 1 != 0))
					_light(opts, a.id, x, y)
			"walker":
				var run: Dictionary = longest_run(_opening_candidates(map, occupied, "floor", 5, opts))
				if run.is_empty() or int(run.len) < 2:
					continue
				var span: int = int(run.len) * 16 - 12
				var p: int = (tick >> 2) % (2 * (span + 30))
				var x: int = 0
				var facing: int = -1
				var moving: bool = true
				if p < span:
					x = p
					facing = 1
				elif p < span + 30:
					x = span
					facing = 1
					moving = false
				elif p < 2 * span + 30:
					x = 2 * span + 30 - p
				else:
					moving = false
				commands.append(_command(a.id, "walk" if moving else 0, tick if moving else 0, origin.x + int(run.x0) * 16 + 6 + x, origin.y + int(run.ty) * 16 + 16, facing < 0))
			"percher":
				var cands: Array[Dictionary] = _opening_candidates(map, occupied, "floor", 9, opts)
				cands = cands.filter(func(c: Dictionary) -> bool: return not used.has(Vector2i(c.tx, c.ty)))
				if cands.is_empty():
					continue
				var edge: Dictionary = cands[0]
				for c: Dictionary in cands:
					if at(map, int(c.tx) + 1, c.ty) == 0 and not solid(at(map, int(c.tx) + 1, int(c.ty) + 1)):
						edge = c
						break
				used[Vector2i(edge.tx, edge.ty)] = true
				if alive.is_valid() and not alive.call(edge.tx, edge.ty):
					continue
				var phase: int = floori(float(tick) / 60) % 6
				commands.append(_command(a.id, "peck" if phase == 2 or phase == 3 else "idle", tick, origin.x + int(edge.tx) * 16 + 8, origin.y + int(edge.ty) * 16 + 16, floori(float(tick) / 360) % 2 == 1))
			"wall":
				for x: int in range(area.position.x + (int(a.spacing) >> 1), area.end.x, a.spacing):
					commands.append(_command(a.id, a.get("anim", "default"), tick + x, x, area.position.y + int(a.y), false))
					_light(opts, a.id, x, area.position.y + int(a.y))
			"hanger":
				var cands: Array[Dictionary] = _opening_candidates(map, occupied, "ceiling", 3, opts)
				if cands.is_empty():
					continue
				var c: Dictionary = cands[0]
				var hx: int = origin.x + int(c.tx) * 16 + 8
				var hy: int = origin.y + int(c.ty) * 16
				var p: int = tick % 720
				commands.append(_command(a.id, "hang" if p < 600 else "fly", tick, hx if p < 600 else hx + tri(p - 600, 120, 20), hy if p < 600 else hy + 10 + tri(p - 570, 60, 6), false))
			"flyer":
				var count: int = a.get("count", 1)
				for _i: int in range(count):
					var k: int = flyer_index
					flyer_index += 1
					var cx: int = area.position.x + int(float(area.size.x * (k + 1)) / (count + 1))
					var cy: int = area.position.y + (area.size.y >> 1)
					var x: int
					var y: int
					match str(a.get("path", "")):
						"cross":
							x = area.position.x + ((tick >> 1) + k * 97) % (area.size.x + 40) - 20
							y = area.position.y + 16 + k * 18 + tri(tick, 80, 3)
						"drift":
							x = area.position.x + ((tick >> 3) + k * 131) % (area.size.x + 40) - 20
							y = area.position.y + 30 + tri(tick, 240, 4)
						"hover":
							x = cx + tri(tick + k * 50, 900, mini(60, area.size.x >> 3))
							y = cy - 20 + tri(tick, 120, 3)
						_:
							x = cx + tri(tick + k * 133, 420, mini(48, area.size.x >> 3))
							y = cy + tri(tick + k * 71, 260, mini(24, area.size.y >> 3))
					commands.append(_command(a.id, a.get("anim", "fly"), tick, x, y, false if a.get("path") == "cross" else tri(tick + k * 133, 420, 1) < 0))
	return commands

static func _command(id: String, animation: Variant, tick: int, x: int, y: int, flip: bool) -> Dictionary:
	return {"uid": "art:" + id, "anim": animation, "tick": tick, "x": x, "y": y, "flip": flip}

static func _light(opts: Dictionary, id: String, x: int, y: int) -> void:
	if opts.get("out") is Array:
		opts.out.append({"id": id, "x": x, "y": y})
