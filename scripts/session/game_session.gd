class_name GameSession
extends RefCounted
## Owns settled transactions. Presentation never changes this authoritative state.

const Reducer = preload("res://scripts/core/puzzle_reducer.gd")
const Levels = preload("res://scripts/data/level_repository.gd")
const Storage = preload("res://scripts/services/save_service.gd")
const SKINS := ["beech", "walnut", "rose", "sage"]
const SKIN_COST := 100
const FIRST_CLEAR_COINS := 20

var level: Dictionary = {}
var state: Dictionary = {}
var history: Array = []
var epoch := 0
var profile: Dictionary
var last_save_ok := true
var restore_message := ""
var storage: Storage
var _history_moves: Array = []

func _init(save_storage: Storage = null) -> void:
	storage = Storage.new() if save_storage == null else save_storage
	profile = storage.load_profile()
	if storage.load_status in ["future_schema", "recovery_failed"]:
		restore_message = storage.last_error
	last_save_ok = not storage.read_only_future_schema

func start_level(index: int, resume: bool = true) -> void:
	epoch += 1
	level = Levels.load_level(index)
	history = []
	_history_moves = []
	if level.is_empty():
		state = {"status": "CONTENT_ERROR"}
		restore_message = "This puzzle could not be loaded. Please choose another level."
		return
	state = Reducer.create_initial_state(level)
	if state.get("status") == "CONTENT_ERROR":
		restore_message = "This puzzle needs an update before it can be played."
		return
	var attempt: Dictionary = profile.get("attempt", {})
	if resume and not attempt.is_empty() and attempt.get("level_id") == level.get("level_id"):
		if not _restore_attempt(attempt):
			restore_message = "Progress is safe. This puzzle has been restarted because its saved attempt no longer matches."
		elif not storage.read_only_future_schema:
			restore_message = ""
	profile["current_level"] = index
	if state.get("status") == "WON":
		_award_completion()
	save()

func select_screw(id: String) -> Dictionary:
	if level.is_empty() or state.is_empty():
		return {"accepted": false, "rejection_reason": "NO_LEVEL", "next_state": state.duplicate(true), "events": []}
	var result: Dictionary = Reducer.apply_select(level, state, id)
	if not result.get("accepted", false):
		return result
	history.append(state.duplicate(true))
	_history_moves.append(id)
	state = result["next_state"].duplicate(true)
	epoch += 1
	var earned := 0
	if state.get("status") == "WON":
		earned = _award_completion()
		history.clear()
		_history_moves.clear()
	save()
	result["first_clear"] = earned > 0
	result["coins_earned"] = earned
	result["epoch"] = epoch
	result["save_ok"] = last_save_ok
	return result

func undo() -> bool:
	if history.is_empty() or state.get("status") in ["WON", "CONTENT_ERROR"]:
		return false
	state = history.pop_back().duplicate(true)
	_history_moves.pop_back()
	epoch += 1
	save()
	return true

func restart() -> void:
	start_level(int(profile.get("current_level", 1)), false)

func save() -> bool:
	if not level.is_empty() and not state.is_empty() and state.get("status") != "CONTENT_ERROR":
		profile["attempt"] = {
			"attempt_schema_version": 1,
			"level_id": level.get("level_id"),
			"content_hash": state.get("content_hash", ""),
			"ruleset_id": state.get("ruleset_id", ""),
			"state": state.duplicate(true),
			"state_hash": Reducer.canonical_hash(state),
			"history": history.duplicate(true),
			"history_moves": _history_moves.duplicate(),
		}
	last_save_ok = storage.save_profile(profile)
	return last_save_ok

func hint() -> Dictionary:
	var query_hash := Reducer.canonical_hash(state)
	var response := {"outcome": "UNKNOWN_LIMIT", "solution": [], "screw_id": "", "epoch": epoch, "state_hash": query_hash, "expanded_states": 0}
	if level.is_empty() or state.get("status") in ["WON", "CONTENT_ERROR"]:
		return response
	# A reference route is only a proposal. Replay its entire remaining suffix
	# from this exact state before promising that its first tap leads to a win.
	var candidate: Array = []
	for id: Variant in level.get("reference_solution", []):
		if id in state.get("remaining_screw_ids", []):
			candidate.append(id)
	if not candidate.is_empty() and _is_winning_continuation(candidate):
		response["outcome"] = "SOLVED"
		response["solution"] = candidate
		response["screw_id"] = candidate[0]
		response["source"] = "verified_replay"
		return response
	var searched: Dictionary = Reducer.solve(level, state, 1200)
	response["expanded_states"] = searched.get("expanded_states", 0)
	response["outcome"] = searched.get("outcome", "UNKNOWN_LIMIT")
	if response["outcome"] == "SOLVED":
		var solution: Array = searched.get("solution", [])
		if solution.is_empty() or not _is_winning_continuation(solution):
			response["outcome"] = "UNKNOWN_LIMIT"
		else:
			response["solution"] = solution.duplicate()
			response["screw_id"] = solution[0]
	return response

func purchase_skin(id: String) -> bool:
	if not id in SKINS:
		return false
	var before := profile.duplicate(true)
	if not id in profile["owned_skins"]:
		if int(profile["coins"]) < SKIN_COST:
			return false
		profile["coins"] = int(profile["coins"]) - SKIN_COST
		profile["owned_skins"].append(id)
	profile["skin"] = id
	if not save():
		profile = before
		return false
	return true

func set_setting(key: String, value: bool) -> void:
	if not key in Storage.SETTINGS:
		return
	profile["settings"][key] = value
	save()

func _award_completion() -> int:
	var id: String = level["level_id"]
	var grant := "first_clear:" + id
	var already_earned: bool = grant in profile["reward_grant_ledger"] or id in profile["completed_levels"]
	if not id in profile["completed_levels"]:
		profile["completed_levels"].append(id)
	if not grant in profile["reward_grant_ledger"]:
		profile["reward_grant_ledger"].append(grant)
	if already_earned:
		return 0
	profile["coins"] = int(profile["coins"]) + FIRST_CLEAR_COINS
	return FIRST_CLEAR_COINS

func _restore_attempt(attempt: Dictionary) -> bool:
	if attempt.get("attempt_schema_version") != 1:
		return false
	if attempt.get("content_hash") != state.get("content_hash") or attempt.get("ruleset_id") != state.get("ruleset_id"):
		return false
	var restored: Variant = attempt.get("state")
	var snapshots: Variant = attempt.get("history")
	var moves: Variant = attempt.get("history_moves")
	if not restored is Dictionary or not snapshots is Array or not moves is Array or snapshots.size() != moves.size():
		return false
	if not Reducer.validate_state(level, restored).is_empty() or Reducer.canonical_hash(restored) != attempt.get("state_hash"):
		return false
	if snapshots.size() > level.get("screws", []).size():
		return false
	if restored.get("status") == "WON":
		if not snapshots.is_empty():
			return false
	else:
		# Undo is a verified journal from the initial state, not arbitrary valid
		# snapshots that could skip moves or restore a different puzzle branch.
		var expected := state.duplicate(true)
		for i: int in snapshots.size():
			if not snapshots[i] is Dictionary or not moves[i] is String:
				return false
			if not Reducer.validate_state(level, snapshots[i]).is_empty() or Reducer.canonical_hash(snapshots[i]) != Reducer.canonical_hash(expected):
				return false
			var transition: Dictionary = Reducer.apply_select(level, snapshots[i], moves[i])
			if not transition.get("accepted", false):
				return false
			expected = transition["next_state"]
		if Reducer.canonical_hash(expected) != Reducer.canonical_hash(restored):
			return false
	state = restored.duplicate(true)
	history = snapshots.duplicate(true)
	_history_moves = moves.duplicate()
	return true

func _is_winning_continuation(solution: Array) -> bool:
	var replay := state.duplicate(true)
	for id: Variant in solution:
		if not id is String:
			return false
		var step: Dictionary = Reducer.apply_select(level, replay, id)
		if not step.get("accepted", false):
			return false
		replay = step["next_state"]
	return replay.get("status") == "WON" and Reducer.validate_state(level, replay).is_empty()
