extends SceneTree

const Session := preload("res://pushbox/scripts/session.gd")
var errors: int = 0
var observations: Array = []
var snapshots: Array = []

func inspect(session: RefCounted, room: int, step: int) -> void:
	var board: RefCounted = session.board
	var band: Array = board.rules.classify.warn_band
	for y in 12:
		for x in 20:
			var at := Vector2i(x, y)
			var counts: Dictionary = board.counts(at)
			if counts.solid > 0 and counts.solid < 128:
				errors += 1
				print("FAIL static invariant D%d step=%d tile=%s" % [room, step, at - board.origin])
			for entry in board.rules.classify.order:
				var count: int = board.tag_count(at, entry.tag)
				if count >= int(band[0]) and count <= int(band[1]):
					observations.append({"room": room, "step": step, "tile": [x - board.origin.x, y - board.origin.y], "tag": entry.tag, "cells": count, "category": board.category(at)})

func _initialize() -> void:
	for room in 5:
		var session := Session.new()
		if session.load_level("res://pushbox/levels/d%d.json" % (room + 1), root) != "":
			errors += 1
			continue
		session.settle_sync()
		inspect(session, room + 1, 0)
		var saved: Dictionary = session.snapshot("inspection")
		if not saved.is_empty():
			var file := FileAccess.open(saved.path, FileAccess.READ)
			snapshots.append({"room": room + 1, "sdk_bytes": file.get_length()})
		for step in session.level.solution.size():
			session.perform(session.level.solution[step])
			session.settle_sync()
			inspect(session, room + 1, step + 1)
		session.dispose()
	var output := FileAccess.open("res://artifacts/logs/level-inspection.json", FileAccess.WRITE)
	output.store_string(JSON.stringify({"warn_band": [96, 160], "observations": observations, "snapshots": snapshots, "static_invariant_errors": errors}, "  ") + "\n")
	for item in observations:
		print("WARN BAND " + JSON.stringify(item))
	print("Snapshots " + JSON.stringify(snapshots))
	print("Inspection: %d errors" % errors)
	quit(1 if errors else 0)
