extends SceneTree
## Run against the shipped reducer, including the supplied independent golden fixture.
const Reducer = preload("res://scripts/core/puzzle_reducer.gd")
const Repository = preload("res://scripts/data/level_repository.gd")
var failures: Array[String] = []
var assertions := 0
var cases := 0
var transitions := 0
var trace_peak_buffer := 0

func _initialize() -> void:
	call_deferred("_run")

func check(condition: bool, label: String) -> void:
	assertions += 1
	if not condition:
		failures.append(label)
		printerr("FAIL: ", label)

func fixture() -> Dictionary:
	var data: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://docs/reference/fixture_12_screws.json"))
	data["level_id"] = "test_two_green_caps"
	data["revision"] = 1
	data["ruleset_revision"] = 1
	return data

func apply_trace(level: Dictionary, initial: Dictionary, actions: Array, label: String) -> Dictionary:
	var state := initial.duplicate(true)
	trace_peak_buffer = state.buffer_screw_ids.size()
	for id in actions:
		var previous := state.duplicate(true)
		var result: Dictionary = Reducer.apply_select(level, state, str(id))
		check(result.get("accepted", false), label + " accepts " + str(id))
		check(state == previous, label + " input remains immutable " + str(id))
		if not result.get("accepted", false):
			return state
		state = result.next_state
		transitions += 1
		trace_peak_buffer = maxi(trace_peak_buffer, state.buffer_screw_ids.size())
		check(Reducer.validate_state(level, state).is_empty(), label + " conserved settled state " + str(id))
	return state

func sorted_copy(value: Array) -> Array:
	var result := value.duplicate()
	result.sort()
	return result

func compare_golden(level: Dictionary, state: Dictionary, expected: Dictionary, label: String) -> void:
	cases += 1
	for key in ["active_box_slots", "buffer_screw_ids", "next_queue_index", "completed_boxes", "status"]:
		check(JSON.parse_string(JSON.stringify(state.get(key))) == expected[key], label + " golden " + key)
	for key in ["remaining_screw_ids", "removed_plate_ids"]:
		check(sorted_copy(state.get(key, [])) == sorted_copy(expected[key]), label + " golden " + key)
	var exposed: Array = []
	for id in state.remaining_screw_ids:
		if Reducer.is_exposed(level, state, id):
			exposed.append(id)
	check(sorted_copy(exposed) == sorted_copy(expected.exposed_screw_ids), label + " exposed set")
	check(sorted_copy(Reducer.get_legal_moves(level, state)) == sorted_copy(expected.legal_screw_ids), label + " legal set")
	var queue: Array = []
	for i in range(int(state.next_queue_index), level.boxes_in_activation_order.size()):
		queue.append(level.boxes_in_activation_order[i].id)
	check(queue == expected.remaining_queue_box_ids, label + " queue")

func test_fixture() -> void:
	var level := fixture()
	check(Reducer.validate_definition(level).is_empty(), "independent fixture definition accepted")
	var untouched := level.duplicate(true)
	var initial: Dictionary = Reducer.create_initial_state(level)
	var straight := apply_trace(level, initial, level.traces.straightforward.actions, "straight")
	compare_golden(level, straight, level.expected_states.won_straightforward, "straight win")
	var fork := apply_trace(level, initial, level.traces.fork_prefix.actions, "fork")
	compare_golden(level, fork, level.expected_states.fork_prefix, "fork prefix")
	var wrong := apply_trace(level, fork, ["Y3"], "wrong fork")
	compare_golden(level, wrong, level.expected_states.wrong_y3_stuck, "wrong fork stuck")
	var full := apply_trace(level, fork, ["G2"], "recover full")
	compare_golden(level, full, level.expected_states.g2_full_buffer_active, "full buffer active")
	var rejected: Dictionary = Reducer.apply_select(level, full, "Y3")
	check(not rejected.accepted, "full buffer rejects nonmatch")
	check(rejected.next_state == full, "full-buffer rejection is a no-op")
	var before_hash: String = Reducer.canonical_hash(full)
	var cascade_result: Dictionary = Reducer.apply_select(level, full, "R3")
	check(cascade_result.accepted, "full buffer accepts direct match")
	var cascade: Dictionary = cascade_result.next_state
	compare_golden(level, cascade, level.expected_states.r3_double_cascade, "double cascade")
	var completions: Array = []
	var transfers: Array = []
	for event in cascade_result.events:
		if event.type == "BoxCompleted": completions.append(event.box_id)
		if event.type == "BufferTransferred": transfers.append(event.screw_id)
	check(completions == ["box_red_01", "box_green_01"], "double completion event order")
	check(transfers == ["G3", "G1", "G2", "Y1", "Y2"], "oldest eligible skips unmatched and cascades")
	check(Reducer.canonical_hash(full) == before_hash, "cascade preserves undo snapshot hash")
	var won := apply_trace(level, cascade, ["Y3", "B1", "B2", "B3"], "recovery")
	compare_golden(level, won, level.expected_states.won_recovered, "recovery win")
	check(level == untouched, "entire fixture definition stays immutable")
	var blocked: Dictionary = Reducer.apply_select(level, initial, "B1")
	check(not blocked.accepted and blocked.next_state == initial, "covered tap is rejected without mutation")
	var unknown: Dictionary = Reducer.apply_select(level, initial, "missing")
	check(not unknown.accepted and unknown.next_state == initial, "unknown tap is rejected without mutation")
	var first: Dictionary = Reducer.apply_select(level, initial, "G1")
	var duplicate: Dictionary = Reducer.apply_select(level, first.next_state, "G1")
	check(not duplicate.accepted and duplicate.next_state == first.next_state, "duplicate command commits once")
	var corrupt := initial.duplicate(true)
	corrupt.buffer_screw_ids.append("R1")
	check(not Reducer.validate_state(level, corrupt).is_empty(), "duplicate inventory detected")
	var invalid := level.duplicate(true)
	invalid.screws[0].color_id = "blue"
	check(not Reducer.validate_definition(invalid).is_empty(), "per-color supply mismatch detected")
	var snapshot := fork.duplicate(true)
	var ordered := fork.duplicate(true)
	ordered.buffer_screw_ids.reverse()
	check(Reducer.canonical_hash(snapshot) != Reducer.canonical_hash(ordered), "canonical key preserves FIFO order")
	var visual := fork.duplicate(true)
	visual["epoch"] = 999
	visual["timestamp"] = 12345
	check(Reducer.canonical_hash(snapshot) == Reducer.canonical_hash(visual), "canonical key excludes operational fields")
	var limited: Dictionary = Reducer.solve(level, initial, 0)
	check(limited.outcome == "UNKNOWN_LIMIT", "zero-budget solver reports UNKNOWN_LIMIT")
	var impossible: Dictionary = Reducer.solve(level, wrong, 1000)
	check(impossible.outcome == "UNSOLVABLE", "exhausted stuck search reports UNSOLVABLE")
	var solve_before := fork.duplicate(true)
	var solved: Dictionary = Reducer.solve(level, fork, 20000)
	check(solved.outcome == "SOLVED", "solver finds continuation from actual alternate state")
	check(fork == solve_before, "solver keeps input state immutable")
	if solved.outcome == "SOLVED":
		var replay := apply_trace(level, fork, solved.solution, "solver witness")
		check(replay.status == "WON", "solver witness replay actually wins")

func test_same_color_priority() -> void:
	cases += 1
	var level := {"schema_version":1, "schema_kind":"abstract_rule_fixture", "level_id":"same_color", "revision":1, "ruleset_id":"classic_sort_v1", "boxes_in_activation_order":[{"id":"older", "color_id":"red"}, {"id":"newer", "color_id":"red"}], "plates":[], "screws":[]}
	for i in range(6):
		var id := "R" + str(i)
		level.plates.append({"id":"P" + str(i), "layer":0, "screw_ids":[id]})
		level.screws.append({"id":id,"color_id":"red","plate_id":"P" + str(i),"blocker_plate_ids":[]})
	var state: Dictionary = Reducer.create_initial_state(level)
	state = apply_trace(level, state, ["R0", "R1"], "matching priority")
	check(state.active_box_slots[0].screw_ids == ["R0", "R1"], "same-color older activation receives screws")
	check(state.active_box_slots[1].screw_ids.is_empty(), "newer same-color box remains empty")
	state = apply_trace(level, state, ["R2"], "queue exhaustion")
	check(state.active_box_slots[0] == null, "exhausted queue leaves inactive slot")

func test_campaign() -> void:
	var catalog: Array = Repository.get_catalog()
	check(catalog.size() >= 1000, "at least 1000 campaign levels packaged")
	var ids: Dictionary = {}
	for index in range(1, catalog.size() + 1):
		var level: Dictionary = Repository.load_level(index)
		var label := "campaign " + str(index)
		check(not ids.has(level.level_id), label + " unique stable ID")
		ids[level.level_id] = true
		check(Reducer.validate_definition(level).is_empty(), label + " valid definition")
		var state: Dictionary = Reducer.create_initial_state(level)
		check(state.status == "ACTIVE", label + " begins active")
		state = apply_trace(level, state, level.reference_solution, label)
		check(state.status == "WON", label + " witnessed win via production reducer")
		check(trace_peak_buffer == int(level.witness_peak_buffer), label + " measured witness peak buffer matches metadata")
		check(state.remaining_screw_ids.is_empty() and state.buffer_screw_ids.is_empty(), label + " win leaves no loose screws")
		cases += 1
		if index % 100 == 0: print("Campaign replay ", index, "/", catalog.size())

func _run() -> void:
	var started := Time.get_ticks_msec()
	test_fixture()
	test_same_color_priority()
	test_campaign()
	var report := {"suite":"production_reducer", "cases":cases,"assertions":assertions,"transitions":transitions,"failures":failures,"duration_ms":Time.get_ticks_msec()-started,"engine":Engine.get_version_info().string}
	DirAccess.make_dir_recursive_absolute("res://builds/reports")
	var output := FileAccess.open("res://builds/reports/reducer.json", FileAccess.WRITE)
	if output != null: output.store_string(JSON.stringify(report, "  "))
	print(JSON.stringify(report))
	quit(0 if failures.is_empty() else 1)
