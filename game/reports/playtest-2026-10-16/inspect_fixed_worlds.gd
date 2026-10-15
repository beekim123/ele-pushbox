extends SceneTree
## Read saved real SDK states only. No actions, step(), replay or solving.
const World = preload("res://sim/ele_world.gd")
const Water = preload("res://gameplay/grid/rules/water.gd")
const CASES = [{"id": "W01", "snapshot": "/Users/key_/Desktop/CURRGO/pushbox-demo/game/reports/playtest-2026-10-16/w01-fixed/world.snap", "state": "/Users/key_/Desktop/CURRGO/pushbox-demo/game/reports/playtest-2026-10-16/w01-fixed/state.json", "spec": "/Users/key_/Desktop/CURRGO/pushbox-demo/content/levels/lab/water/W01.json"}, {"id": "W09", "snapshot": "/Users/key_/Desktop/CURRGO/pushbox-demo/game/reports/playtest-2026-10-16/w09-fixed/world.snap", "state": "/Users/key_/Desktop/CURRGO/pushbox-demo/game/reports/playtest-2026-10-16/w09-fixed/state.json", "spec": "/Users/key_/Desktop/CURRGO/pushbox-demo/content/levels/lab/water/W09.json"}, {"id": "G01", "snapshot": "/Users/key_/Desktop/CURRGO/pushbox-demo/game/reports/playtest-2026-10-16/g01-fixed/world.snap", "state": "/Users/key_/Desktop/CURRGO/pushbox-demo/game/reports/playtest-2026-10-16/g01-fixed/state.json", "spec": "/Users/key_/Desktop/CURRGO/pushbox-demo/content/levels/lab/react/G01.json"}]
func _initialize() -> void:
    call_deferred("_inspect")
func _inspect() -> void:
    var report: Array = []
    for row: Dictionary in CASES:
        var spec: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(row.spec))
        var envelope: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(row.state))
        var state: Dictionary = envelope.get("state", envelope)
        var world = World.new()
        if not world.open(1, false, spec):
            push_error(world.last_error)
            quit(1)
            return
        if world.load_snapshot(row.snapshot) != OK:
            push_error(world.last_error)
            quit(1)
            return
        var ids: PackedInt32Array = world.get_material_ids(0, 0, 320, 192)
        var result: Dictionary = {"id": row.id, "player": state.grid.player, "crates": state.grid.crates, "moves": state.grid.moves, "stats": world.get_stats(), "counts": {}, "tiles": []}
        for name: String in ["water", "crate", "iron_crate", "acid", "limestone_a", "limestone_b"]:
            result.counts[name] = world.count_material(name, Rect2i(0,0,320,192))
        var width: int = int(state.grid.w)
        var height: int = int(state.grid.h)
        for y: int in height:
            for x: int in width:
                var tile_counts: Dictionary = {}
                for name: String in ["water", "acid", "limestone_a", "limestone_b"]:
                    var count: int = world.count_material(name, Rect2i(x*16,y*16,16,16))
                    if count > 0:
                        tile_counts[name] = count
                if not tile_counts.is_empty():
                    result.tiles.append({"at":[x,y],"counts":tile_counts})
        if row.id != "G01":
            var crate: Dictionary = state.grid.crates[0]
            var x: int = int(crate.x)
            var y: int = int(crate.y)
            var water: int = int(world.material_ids.water)
            var above: Array[int] = Water.positions(ids, water, Vector2i(x,y-1))
            var seeds: Array[int] = []
            for px: int in range(x*16,(x+1)*16):
                seeds.append((y+1)*16*320+px)
            var body: Array[int] = Water.component(ids,water,seeds,width,height)
            var top: int = 192
            for pixel: int in body:
                top = mini(top,int(pixel/320))
            result.buoyancy = {"above_count":above.size(),"below_component_count":body.size(),"top_y":top,"head_cells":(y+1)*16-top,"above_occupied_by_player":int(state.grid.player.x)==x and int(state.grid.player.y)==y-1}
        else:
            var contacts: int = 0
            var acid: int = int(world.material_ids.acid)
            var soft: int = int(world.material_ids.limestone_a)
            for y: int in range(1,191):
                for x: int in range(1,319):
                    var index: int = y*320+x
                    if ids[index] != acid:
                        continue
                    for other: int in [index-1,index+1,index-320,index+320]:
                        if ids[other] == soft:
                            contacts += 1
            result.acid_soft_contacts = contacts
        report.append(result)
        world.dispose()
        await process_frame
    var out: FileAccess = FileAccess.open("res://reports/playtest-2026-10-16/saved-world-after-fix.json",FileAccess.WRITE)
    out.store_string(JSON.stringify({"kind":"readonly real SDK snapshot measurement; no ticks advanced", "levels":report},"  "))
    out.close()
    print("Saved SDK snapshot measurements for ",report.size()," saved UI cases; no ticks advanced.")
    quit(0)
