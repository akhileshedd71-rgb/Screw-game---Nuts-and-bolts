extends SceneTree
## Run: godot --headless --path . --script tests/test_persistence.gd
## Uses a unique user:// subtree and never touches the player's save files.

const Storage = preload("res://scripts/services/save_service.gd")
const Session = preload("res://scripts/session/game_session.gd")
const Reducer = preload("res://scripts/core/puzzle_reducer.gd")

var checks := 0
var failures: Array[String] = []
var test_root := ""

func _initialize() -> void:
	test_root = "user://test_persistence_" + str(OS.get_process_id()) + "_" + str(Time.get_ticks_usec())
	call_deferred("_run")

func _run() -> void:
	_test_slots_and_corruption()
	_test_future_schema()
	_test_stale_writer()
	_test_failed_writes()
	_test_transactions_and_resume()
	_test_campaign_resume_and_mismatch()
	_test_rewards_and_cosmetics()
	if failures.is_empty():
		print("PERSISTENCE PASS: %d checks; A/B recovery, future schema, lifecycle, undo, hints, rewards, cosmetics." % checks)
	else:
		for failure: String in failures:
			push_error(failure)
		print("PERSISTENCE FAILED: %d / %d checks" % [failures.size(), checks])
	_remove_test_directory(test_root)
	quit(0 if failures.is_empty() else 1)

func _check(condition: bool, description: String) -> void:
	checks += 1
	if not condition:
		failures.append(description)

func _storage(name: String) -> Storage:
	return Storage.new(test_root.path_join(name))

func _write_text(path: String, value: String) -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(path.get_base_dir()))
	var file := FileAccess.open(path, FileAccess.WRITE)
	file.store_string(value)
	file.close()

func _test_slots_and_corruption() -> void:
	var store := _storage("slots")
	var profile := store.load_profile()
	_check(profile.coins == 0 and profile.settings.sound and profile.skin == "beech", "New profile has usable defaults")
	profile.coins = 20
	_check(store.save_profile(profile), "First save succeeds")
	profile.coins = 40
	_check(store.save_profile(profile), "Second save succeeds")
	profile.coins = 60
	_check(store.save_profile(profile), "Third save replaces oldest slot")
	_check(store.save_sequence == 3, "Write sequences increase monotonically")
	_check(_storage("slots").load_profile().coins == 60, "Highest valid sequence wins")
	# An incomplete temp file must never count as a committed save.
	_write_text(store.directory.path_join("profile_b.json.tmp"), "{truncated")
	_check(_storage("slots").load_profile().coins == 60, "Interrupted temporary write is ignored")
	_write_text(store.directory.path_join("profile_a.json"), "{truncated")
	var recovered := _storage("slots")
	_check(recovered.load_profile().coins == 40, "Truncated newest slot recovers older valid profile")
	profile.coins = 80
	_check(recovered.save_profile(profile), "Recovered profile can save again")
	var envelope: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(store.directory.path_join("profile_a.json")))
	envelope.payload_json = str(envelope.payload_json).replace('"coins":80', '"coins":800')
	_write_text(store.directory.path_join("profile_a.json"), JSON.stringify(envelope))
	_check(_storage("slots").load_profile().coins == 40, "Checksum rejects altered payload")
	var malformed := profile.duplicate(true)
	malformed.coins = -1
	_check(not recovered.save_profile(malformed), "Invalid wallet cannot replace a valid save")
	_check(_storage("slots").load_profile().coins == 40, "Invalid write leaves the recovery copy intact")

func _test_future_schema() -> void:
	var store := _storage("future")
	var profile := store.load_profile()
	profile.coins = 100
	_check(store.save_profile(profile), "Known profile saved before future-version simulation")
	var future := JSON.stringify({"save_schema_version": 2, "save_sequence": 999, "future_format": "opaque"})
	var future_path := store.directory.path_join("profile_b.json")
	_write_text(future_path, future)
	var newer := _storage("future")
	var fallback := newer.load_profile()
	_check(newer.read_only_future_schema, "Unknown future version enters read-only protection")
	_check(fallback.coins == 100, "Known older profile remains readable alongside future version")
	_check(not newer.save_profile(fallback), "Future-version data cannot be overwritten")
	_check(FileAccess.get_file_as_string(future_path) == future, "Future envelope bytes are preserved")
	_check(not store.save_profile(profile), "Already-loaded writer also detects a newly appeared future save")

func _test_failed_writes() -> void:
	var blocking_path := test_root.path_join("regular_file")
	_write_text(blocking_path, "not a directory")
	var store := Storage.new(blocking_path)
	_check(not store.save_profile(store.default_profile()), "Unwritable save directory reports failure")
	_check(not store.last_error.is_empty(), "Save failure exposes a useful error")

func _test_stale_writer() -> void:
	var older := _storage("stale_writer")
	var old_profile := older.load_profile()
	_check(older.save_profile(old_profile), "Initial writer commits")
	var newer := _storage("stale_writer")
	var new_profile := newer.load_profile()
	new_profile.coins = 180
	_check(newer.save_profile(new_profile), "Replacement writer commits newer progress")
	_check(not older.save_profile(old_profile), "Late stale writer cannot replace newer progress")
	_check(_storage("stale_writer").load_profile().coins == 180, "Newer progress survives late stale write")

func _fixture() -> Dictionary:
	var fixture: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://docs/reference/fixture_12_screws.json"))
	fixture["level_id"] = "persistence_fixture"
	fixture["revision"] = 1
	fixture["reference_solution"] = fixture.traces.straightforward.actions.duplicate()
	return fixture

func _fixture_session(name: String) -> Session:
	var game := Session.new(_storage(name))
	game.level = _fixture()
	game.state = Reducer.create_initial_state(game.level)
	return game

func _play(game: Session, moves: Array) -> void:
	for id: String in moves:
		_check(game.select_screw(id).accepted, "Expected accepted transaction: " + id)

func _test_transactions_and_resume() -> void:
	var game := _fixture_session("transactions")
	var initial_hash := Reducer.canonical_hash(game.state)
	var first_epoch := game.epoch
	_check(not game.select_screw("B1").accepted, "Covered screw rejected")
	_check(game.history.is_empty() and game.epoch == first_epoch and game.storage.save_sequence == 0, "Rejection creates no history, epoch, or save")
	_play(game, game.level.traces.fork_prefix.actions)
	var prefix_hash := Reducer.canonical_hash(game.state)
	var prefix_epoch := game.epoch
	var hinted := game.hint()
	_check(hinted.outcome == "SOLVED" and not hinted.solution.is_empty(), "Off-reference-route hint has a verified continuation")
	_check(Reducer.canonical_hash(game.state) == prefix_hash and game.epoch == prefix_epoch, "Hint does not change the puzzle")
	_play(game, ["Y3"])
	_check(game.state.status == "STUCK", "Wrong fork settles as stuck")
	_check(game.hint().outcome == "UNSOLVABLE", "Stuck hint honestly reports exhaustive impossibility")
	_check(game.undo(), "Stuck transaction can be undone")
	_check(Reducer.canonical_hash(game.state) == prefix_hash and game.epoch > prefix_epoch, "Undo restores exact full snapshot with fresh epoch")
	_play(game, ["G2"])
	_check(game.state.buffer_screw_ids.size() == 5 and game.state.status == "ACTIVE", "Full buffer still permits direct match")
	var pre_cascade_hash := Reducer.canonical_hash(game.state)
	var cascade := game.select_screw("R3")
	_check(cascade.accepted and game.state.completed_boxes.size() == 2, "Direct match commits two-box cascade")
	_check(game.undo() and Reducer.canonical_hash(game.state) == pre_cascade_hash, "One undo reverses the entire cascade")
	_check(game.last_save_ok, "Every accepted transaction and undo was persisted")
	var reloaded := _fixture_session("transactions")
	_check(reloaded._restore_attempt(reloaded.profile.attempt), "Actual disk reload validates and restores transaction journal")
	_check(Reducer.canonical_hash(reloaded.state) == pre_cascade_hash and reloaded.history.size() == game.history.size(), "Suspension restores puzzle and undo depth exactly")
	while not reloaded.history.is_empty():
		_check(reloaded.undo(), "Restored history remains undoable")
	_check(Reducer.canonical_hash(reloaded.state) == initial_hash, "Restored complete history leads to the initial state")
	var broken: Dictionary = game.profile.attempt.duplicate(true)
	broken.history_moves[0] = "B1"
	var fresh := _fixture_session("invalid_journal")
	_check(not fresh._restore_attempt(broken), "Valid-looking snapshots with invalid command journal are rejected")
	_check(Reducer.canonical_hash(fresh.state) == initial_hash, "Failed restore has no partial state mutation")

func _test_campaign_resume_and_mismatch() -> void:
	var game := Session.new(_storage("campaign"))
	game.start_level(1)
	_check(not game.level.is_empty() and game.state.status == "ACTIVE", "Public 1-based start_level loads campaign")
	if game.level.is_empty() or game.state.get("status") != "ACTIVE":
		return
	var id: String = Reducer.get_legal_moves(game.level, game.state)[0]
	_check(game.select_screw(id).accepted, "Campaign transaction accepts legal tap")
	var saved_hash := Reducer.canonical_hash(game.state)
	var restored := Session.new(_storage("campaign"))
	restored.start_level(1)
	_check(Reducer.canonical_hash(restored.state) == saved_hash and restored.history.size() == 1, "Public startup resumes both state and history")
	restored.restart()
	_check(restored.state.move_count == 0 and restored.history.is_empty(), "Restart deterministically resets the attempt")
	restored.profile.coins = 160
	restored.profile.completed_levels = ["campaign_0042"]
	restored.profile.attempt.content_hash = "an obsolete content revision"
	_check(restored.storage.save_profile(restored.profile), "Mismatched attempt can exist in a valid envelope")
	var changed := Session.new(_storage("campaign"))
	changed.start_level(1)
	_check(changed.profile.coins == 160 and "campaign_0042" in changed.profile.completed_levels, "Content mismatch preserves wallet and collection")
	_check(changed.state.move_count == 0 and not changed.restore_message.is_empty(), "Content mismatch restarts only the attempt with explanation")

func _test_rewards_and_cosmetics() -> void:
	var game := _fixture_session("rewards")
	_play(game, game.level.reference_solution)
	_check(game.state.status == "WON" and game.profile.coins == 20, "First win awards 20 coins")
	_check(game.history.is_empty() and not game.undo(), "Committed victory disables undo")
	var reloaded := _fixture_session("rewards")
	_check(reloaded._restore_attempt(reloaded.profile.attempt), "Won result screen survives disk resume")
	_check(reloaded._award_completion() == 0 and reloaded.profile.coins == 20, "Repeated completion callback cannot duplicate reward")
	reloaded.level.revision = 2
	reloaded.state = Reducer.create_initial_state(reloaded.level)
	_play(reloaded, reloaded.level.reference_solution)
	_check(reloaded.profile.coins == 20 and reloaded.profile.completed_levels.size() == 1, "Ordinary content revision cannot grant first-clear reward again")
	_check(not reloaded.purchase_skin("walnut"), "Unaffordable cosmetic does not spend coins")
	reloaded.profile.coins = 120
	_check(reloaded.purchase_skin("walnut") and reloaded.profile.coins == 20, "New cosmetic costs exactly 100 coins")
	_check(reloaded.purchase_skin("walnut") and reloaded.profile.coins == 20, "Owned cosmetic is free to select")
	_check(not reloaded.purchase_skin("unknown_skin"), "Unknown cosmetic ID is rejected")
	reloaded.set_setting("reduced_motion", true)
	var loaded := _storage("rewards").load_profile()
	_check(loaded.skin == "walnut" and loaded.settings.reduced_motion and loaded.coins == 20, "Settings, cosmetics, wallet, and reward ledger persist together")

func _remove_test_directory(path: String) -> void:
	var directory := DirAccess.open(path)
	if directory == null:
		return
	for subdirectory: String in directory.get_directories():
		_remove_test_directory(path.path_join(subdirectory))
	for filename: String in directory.get_files():
		DirAccess.remove_absolute(ProjectSettings.globalize_path(path.path_join(filename)))
	DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
