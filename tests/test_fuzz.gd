extends SceneTree
const Reducer = preload("res://scripts/core/puzzle_reducer.gd")
func _init() -> void:
	var fixture: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://docs/reference/fixture_12_screws.json"))
	var rng := RandomNumberGenerator.new()
	rng.seed = 881933
	var transitions: int = 0
	var won: int = 0
	var stuck: int = 0
	for attempt: int in range(500):
		var state: Dictionary = Reducer.create_initial_state(fixture)
		while state.status == "ACTIVE":
			var before: String = Reducer.canonical_hash(state)
			var moves: Array = Reducer.get_legal_moves(fixture, state)
			var result: Dictionary = Reducer.apply_select(fixture, state, moves[rng.randi_range(0, moves.size()-1)])
			assert(result.accepted)
			assert(Reducer.canonical_hash(state) == before)
			state = result.next_state
			var errors: Array = Reducer.validate_state(fixture, state)
			assert(errors.is_empty(), str(errors))
			transitions += 1
		won += int(state.status == "WON")
		stuck += int(state.status == "STUCK")
	var bad: Dictionary = fixture.duplicate(true)
	bad.plates[0].layer = {"garbage": true}
	assert(not Reducer.validate_definition(bad).is_empty())
	bad = fixture.duplicate(true)
	bad.plates[1].layer = -1
	assert(not Reducer.validate_definition(bad).is_empty())
	bad = fixture.duplicate(true)
	bad.screws[0].blocker_plate_ids = null
	assert(not Reducer.validate_definition(bad).is_empty())
	bad = fixture.duplicate(true)
	bad.screws[0].plate_id = "absent"
	assert(not Reducer.validate_definition(bad).is_empty())
	bad = fixture.duplicate(true)
	bad.rules.buffer_capacity = 6
	assert(not Reducer.validate_definition(bad).is_empty())
	print("RANDOM FIXTURE PASS transitions=",transitions," won=",won," stuck=",stuck," malformed definition checks=5")
	quit(0)
