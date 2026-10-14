extends SceneTree
var game: Node
var last_state := ""
var last_size := Vector2.ZERO
var capture_pending := false
var captures: int = 0
func _initialize() -> void:
    game = load("res://pushbox/scenes/main.tscn").instantiate()
    root.add_child.call_deferred(game)
    game.call_deferred("select_level", 1)
    RenderingServer.frame_post_draw.connect(_capture)
func _process(_delta: float) -> bool:
    if game == null or game.get("session") == null:
        return false
    var size: Vector2 = root.get_visible_rect().size
    if size != last_size:
        last_size = size
        print("MANUAL_LAYOUT ", JSON.stringify({"physical": [root.size.x, root.size.y], "logical": [size.x, size.y], "board": [game.view.position.x, game.view.position.y], "bag": [game.hud.bag_position().x, game.hud.bag_position().y]}))
        capture_pending = true
    if game._opening or game.session.running or game.animation_left > 0:
        return false
    var board = game.session.board
    var boxes := []
    for box in board.boxes:
        boxes.append({"id": box.id, "at": [box.at.x, box.at.y]})
    var state := JSON.stringify({"level": game.level_index + 1, "moves": board.moves, "player": [board.player.x, board.player.y], "boxes": boxes, "bag": board.total_bag(), "bombs": board.bombs, "message": game.view.message})
    if state != last_state:
        last_state = state
        print("MANUAL_STATE ", state)
        capture_pending = true
    return false
func _capture() -> void:
    if not capture_pending:
        return
    capture_pending = false
    captures += 1
    DirAccess.make_dir_recursive_absolute("res://manual-captures")
    root.get_texture().get_image().save_png("res://manual-captures/%03d.png" % captures)
