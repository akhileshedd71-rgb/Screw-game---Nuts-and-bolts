extends SceneTree
const Board = preload("res://scripts/ui/board_view.gd")
const Repository = preload("res://scripts/data/level_repository.gd")
const Reducer = preload("res://scripts/core/puzzle_reducer.gd")
func _initialize() -> void:
	call_deferred("verify")
func verify() -> void:
	var board = Board.new()
	root.add_child(board)
	var count = 0
	for index in range(1,1001):
		var level = Repository.load_level(index)
		var state = Reducer.create_initial_state(level)
		var old_hash = Reducer.canonical_hash(state)
		board.configure(level,state)
		board.set_blueprint(true)
		if Reducer.canonical_hash(state) != old_hash:
			push_error("Presentation changed model at %s" % index)
			quit(1)
			return
		var positions = board._blueprint_positions.values()
		for i in range(positions.size()):
			if positions[i].x<42 or positions[i].x>598 or positions[i].y<42 or positions[i].y>550:
				push_error("Blueprint outside bounds %s" % index)
				quit(1)
				return
			for j in range(i+1,positions.size()):
				if positions[i].distance_to(positions[j])<48.9:
					push_error("Blueprint overlap %s" % index)
					quit(1)
					return
		count += positions.size()
	print("Verified all 1000 board blueprints: %s visible nonoverlapping identities; immutable model." % count)
	board.free()
	quit()
