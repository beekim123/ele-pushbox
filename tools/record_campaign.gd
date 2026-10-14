extends SceneTree
const Session := preload("res://pushbox/scripts/session.gd")
const Catalog := preload("res://pushbox/scripts/campaign_catalog.gd")
func _initialize() -> void:
	var count: int = 0
	DirAccess.make_dir_recursive_absolute("res://artifacts/stage2a/recorded")
	for map in 6:
		for index in 6:
			var id: String = Catalog.id(map,index)
			if not OS.get_environment("PUSHBOX_CAMPAIGN_ID").is_empty() and OS.get_environment("PUSHBOX_CAMPAIGN_ID") != id:
				continue
			var path: String = "res://artifacts/stage2a/drafts/%s.json" % id
			if not FileAccess.file_exists(path):
				continue
			var s := Session.new()
			var reason: String = s.load_level(path,root)
			if not reason.is_empty():
				print("FAIL ",id," load: ",reason)
				quit(1)
				return
			s.settle_sync()
			var hashes: Array = []
			var keys: Array = []
			print(id," OPEN player=",s.board.player-s.board.origin," boxes=",s.board.boxes)
			for action in s.level.solution:
				var result: Dictionary = s.perform(action)
				if not result.legal:
					print("FAIL ",id," step=",hashes.size()," action=",action," player=",s.board.player-s.board.origin," reason=",result.reason)
					for yy in s.level.map.size():
						var row: String = ""
						for xx in s.level.map[0].length():
							row += {"SOLID":"#","SAND":"s","WATER":"w","BOX":"B","OPEN":"."}[s.board.category(s.board.origin+Vector2i(xx,yy))]
						print(row)
					s.dispose()
					quit(1)
					return
				s.settle_sync()
				hashes.append(s.world.get_state_hash())
				keys.append(s.board.position_key())
				if OS.get_environment("PUSHBOX_CAMPAIGN_TRACE") == "1":
					if s.board.mechanisms.has("scales"):
						print("SCALE ",s.board.mechanisms.scales," left=",s.board.counts(s.board.Biome.tile(s.board,s.board.mechanisms.scales[0].left)))
					print(id," ",hashes.size()," ",action," p=",s.board.player-s.board.origin," b=",s.board.boxes," bag=",s.board.bag," err=",s.errors)
			if not s.board.won() or not s.errors.is_empty():
				if OS.get_environment("PUSHBOX_CAMPAIGN_TRACE") == "1":
					for yy in s.level.map.size():
						var row: String = ""
						for xx in s.level.map[0].length():
							row += {"SOLID":"#","SAND":"s","WATER":"w","BOX":"B","OPEN":"."}[s.board.category(s.board.origin+Vector2i(xx,yy))]
						print(row)
				print("FAIL ",id," won=",s.board.won()," errors=",s.errors," boxes=",s.board.boxes," goals=",s.board.targets)
				s.dispose()
				quit(1)
				return
			s.level.solution_hashes = hashes
			s.level.solution_keys = keys
			var output := FileAccess.open("res://artifacts/stage2a/recorded/%s.json" % id,FileAccess.WRITE)
			output.store_string(JSON.stringify(s.level,"  ")+"\n")
			output.close()
			print("RECORDED ",id," actions=",hashes.size())
			s.dispose()
			count += 1
	print("Record campaign: ",count," solved")
	quit(0)
