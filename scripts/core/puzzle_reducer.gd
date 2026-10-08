class_name PuzzleReducer
extends RefCounted
## Deterministic model. Definitions and input states are never mutated.
## Every accepted tap includes its entire cascade before returning to presentation.

const RULES = preload("res://content/rulesets/classic_sort_v1.tres")
const COLORS: Array = ["red", "blue", "green", "yellow", "purple", "teal"]
const RULES_HASH: String = "classic_sort_v1:1:slots=2:box=3:buffer=5:eligible_fifo"

static func create_initial_state(level: Dictionary) -> Dictionary:
	var state: Dictionary = {
		"level_id": level.get("level_id", level.get("fixture_id", "")),
		"revision": int(level.get("revision", 1)) if _nonnegative_integer(level.get("revision", 1)) else 0,
		"content_hash": _content_hash(level), "ruleset_id": "classic_sort_v1",
		"ruleset_hash": RULES_HASH, "remaining_screw_ids": [],
		"removed_plate_ids": [], "active_box_slots": [null, null],
		"buffer_screw_ids": [], "completed_boxes": [],
		"next_queue_index": 0, "move_count": 0, "status": "ACTIVE"
	}
	var errors: Array = validate_definition(level)
	if not errors.is_empty():
		state.status = "CONTENT_ERROR"
		state.validation_errors = errors
		return state
	for screw: Dictionary in level.screws:
		state.remaining_screw_ids.append(screw.id)
	state.remaining_screw_ids.sort()
	for slot: int in range(RULES.active_box_slots):
		_activate_box(level, state, slot, [])
	_evaluate(level, state, [])
	return state

static func apply_select(level: Dictionary, state: Dictionary, screw_id: String) -> Dictionary:
	var screw: Dictionary = _find_screw(level, screw_id)
	if screw.is_empty():
		return _reject(state, "UNKNOWN_SCREW")
	if state.get("status", "CONTENT_ERROR") != "ACTIVE":
		return _reject(state, "PUZZLE_FINISHED" if state.get("status") == "WON" else "NO_LEGAL_MOVE")
	if not state.get("remaining_screw_ids", []).has(screw_id):
		return _reject(state, "ALREADY_REMOVED")
	if not is_exposed(level, state, screw_id):
		return _reject(state, "COVERED")
	var slot: int = _matching_slot(state, screw.color_id)
	if slot < 0 and state.buffer_screw_ids.size() >= RULES.buffer_capacity:
		return _reject(state, "NO_DESTINATION")
	var next: Dictionary = state.duplicate(true)
	var events: Array = []
	next.remaining_screw_ids.erase(screw_id)
	next.move_count = int(next.move_count) + 1
	events.append({"type": "ScrewRemoved", "screw_id": screw_id, "plate_id": screw.plate_id})
	if slot >= 0:
		next.active_box_slots[slot].screw_ids.append(screw_id)
		events.append({"type": "ScrewRouted", "screw_id": screw_id, "destination": "box", "slot_index": slot, "box_id": next.active_box_slots[slot].box_id})
	else:
		next.buffer_screw_ids.append(screw_id)
		events.append({"type": "ScrewRouted", "screw_id": screw_id, "destination": "buffer", "slot_index": next.buffer_screw_ids.size() - 1})
	for plate: Dictionary in level.plates:
		if not next.removed_plate_ids.has(plate.id) and not _plate_has_screws(plate, next):
			next.removed_plate_ids.append(plate.id)
			events.append({"type": "PlateCleared", "plate_id": plate.id})
	next.removed_plate_ids.sort()
	_settle(level, next, events)
	_evaluate(level, next, events)
	return {"accepted": true, "rejection_reason": "", "next_state": next, "events": events}

static func get_legal_moves(level: Dictionary, state: Dictionary) -> Array:
	var result: Array = []
	if state.get("status", "ACTIVE") in ["WON", "CONTENT_ERROR"]:
		return result
	for screw_id: String in state.get("remaining_screw_ids", []):
		if not is_exposed(level, state, screw_id):
			continue
		var screw: Dictionary = _find_screw(level, screw_id)
		if state.buffer_screw_ids.size() < RULES.buffer_capacity or _matching_slot(state, screw.color_id) >= 0:
			result.append(screw_id)
	result.sort()
	return result

static func is_exposed(level: Dictionary, state: Dictionary, screw_id: String) -> bool:
	if not state.get("remaining_screw_ids", []).has(screw_id):
		return false
	var screw: Dictionary = _find_screw(level, screw_id)
	if screw.is_empty():
		return false
	for blocker: String in screw.get("blocker_plate_ids", []):
		if not state.get("removed_plate_ids", []).has(blocker):
			return false
	return true

static func canonical_hash(state: Dictionary) -> String:
	var canonical: Dictionary = {}
	for key: String in ["level_id", "revision", "content_hash", "ruleset_id", "ruleset_hash", "remaining_screw_ids", "removed_plate_ids", "active_box_slots", "buffer_screw_ids", "completed_boxes", "next_queue_index", "move_count", "status"]:
		canonical[key] = state.get(key)
	for key: String in ["remaining_screw_ids", "removed_plate_ids"]:
		if canonical[key] is Array:
			canonical[key] = canonical[key].duplicate()
			canonical[key].sort()
	return JSON.stringify(_normalize_numbers(canonical), "", true).sha256_text()

static func solve(level: Dictionary, state: Dictionary, node_limit: int = 2500, time_budget_ms: int = 120) -> Dictionary:
	# Search uses exactly apply_select. Budgets never become impossibility claims.
	if not validate_definition(level).is_empty() or not validate_state(level, state).is_empty():
		return {"outcome": "UNKNOWN_LIMIT", "solution": [], "expanded_states": 0, "reason": "INVALID_CONTENT_OR_STATE"}
	var stack: Array = [{"state": state.duplicate(true), "path": []}]
	var seen: Dictionary = {}
	var expanded: int = 0
	var search_started: int = Time.get_ticks_msec()
	while not stack.is_empty():
		var entry: Dictionary = stack.pop_back()
		var current: Dictionary = entry.state
		if current.status == "WON":
			return {"outcome": "SOLVED", "solution": entry.path, "expanded_states": expanded}
		var key: String = canonical_hash(current)
		if seen.has(key):
			continue
		if expanded >= maxi(0, node_limit) or (time_budget_ms > 0 and Time.get_ticks_msec() - search_started >= time_budget_ms):
			return {"outcome": "UNKNOWN_LIMIT", "solution": [], "expanded_states": expanded}
		seen[key] = true
		expanded += 1
		var moves: Array = get_legal_moves(level, current)
		# Direct matches and releases are explored first, ties use stable screw IDs.
		moves.sort_custom(func(a: String, b: String) -> bool:
			var score_a: int = _move_score(level, current, a)
			var score_b: int = _move_score(level, current, b)
			return score_a > score_b if score_a != score_b else a < b)
		moves.reverse()
		for screw_id: String in moves:
			var transition: Dictionary = apply_select(level, current, screw_id)
			if not transition.accepted:
				continue
			var path: Array = entry.path.duplicate()
			path.append(screw_id)
			stack.append({"state": transition.next_state, "path": path})
	return {"outcome": "UNSOLVABLE", "solution": [], "expanded_states": expanded}

static func validate_definition(level: Dictionary) -> Array:
	var errors: Array = []
	if not _nonnegative_integer(level.get("schema_version")) or int(level.get("schema_version", 0)) != 1:
		errors.append("Unsupported schema_version; expected 1")
	if level.get("ruleset_id", "") != "classic_sort_v1":
		errors.append("Unknown ruleset_id")
	if level.has("rules"):
		if not level.rules is Dictionary:
			errors.append("rules must be a dictionary when supplied")
		else:
			for key: String in ["active_box_slots", "box_capacity", "buffer_capacity", "queue_preview_count"]:
				if level.rules.has(key) and level.rules[key] != RULES.get(key):
					errors.append("Level overrides fixed classic rules: %s" % key)
	for key: String in ["plates", "screws", "boxes_in_activation_order"]:
		if not level.get(key) is Array or level[key].is_empty():
			errors.append("%s must be a nonempty array" % key)
	if not errors.is_empty():
		return errors
	var plates: Dictionary = {}
	var screws: Dictionary = {}
	var box_ids: Dictionary = {}
	var supply: Dictionary = {}
	var demand: Dictionary = {}
	for item: Variant in level.plates:
		if not item is Dictionary or not _valid_id(item.get("id")):
			errors.append("Plate requires a nonempty string ID")
			continue
		var plate: Dictionary = item
		if plates.has(plate.id):
			errors.append("Duplicate plate ID: %s" % plate.id)
		plates[plate.id] = plate
		if not _nonnegative_integer(plate.get("layer")):
			errors.append("Plate %s requires a nonnegative integer layer" % plate.id)
		if not plate.get("screw_ids") is Array or plate.get("screw_ids", []).is_empty():
			errors.append("Plate %s requires owned screws" % plate.id)
	for item: Variant in level.screws:
		if not item is Dictionary or not _valid_id(item.get("id")):
			errors.append("Screw requires a nonempty string ID")
			continue
		var screw: Dictionary = item
		if screws.has(screw.id):
			errors.append("Duplicate screw ID: %s" % screw.id)
		screws[screw.id] = screw
		var color: String = str(screw.get("color_id", ""))
		if not COLORS.has(color):
			errors.append("Screw %s has unknown color %s" % [screw.id, color])
		supply[color] = int(supply.get(color, 0)) + 1
		if not screw.get("blocker_plate_ids") is Array:
			errors.append("Screw %s requires blocker_plate_ids array" % screw.id)
		if not _valid_id(screw.get("plate_id")) or not plates.has(screw.get("plate_id")):
			errors.append("Screw %s has missing owner plate" % screw.id)
	for item: Variant in level.boxes_in_activation_order:
		if not item is Dictionary or not _valid_id(item.get("id")):
			errors.append("Box requires a nonempty string ID")
			continue
		var box: Dictionary = item
		if box_ids.has(box.id):
			errors.append("Duplicate box ID: %s" % box.id)
		box_ids[box.id] = true
		var color: String = str(box.get("color_id", ""))
		if not COLORS.has(color):
			errors.append("Box %s has unknown color %s" % [box.id, color])
		demand[color] = int(demand.get(color, 0)) + RULES.box_capacity
	for color: String in COLORS:
		if int(supply.get(color, 0)) != int(demand.get(color, 0)):
			errors.append("Color %s quota mismatch: %s screws for %s capacity" % [color, supply.get(color, 0), demand.get(color, 0)])
	var owners: Dictionary = {}
	for plate_id: String in plates:
		var plate: Dictionary = plates[plate_id]
		if not plate.get("screw_ids") is Array:
			continue
		for screw_id: Variant in plate.screw_ids:
			if not screw_id is String or not screws.has(screw_id):
				errors.append("Plate %s references unknown screw %s" % [plate_id, screw_id])
				continue
			if owners.has(screw_id):
				errors.append("Screw %s appears in multiple ownership entries" % screw_id)
			owners[screw_id] = plate_id
			if screws[screw_id].get("plate_id") != plate_id:
				errors.append("Screw %s ownership disagrees with plate %s" % [screw_id, plate_id])
	for screw_id: String in screws:
		var screw: Dictionary = screws[screw_id]
		if not owners.has(screw_id):
			errors.append("Screw %s is absent from owner screw_ids" % screw_id)
		if not screw.get("blocker_plate_ids") is Array or not plates.has(screw.get("plate_id")):
			continue
		var blockers: Dictionary = {}
		for blocker: Variant in screw.blocker_plate_ids:
			if not blocker is String or not plates.has(blocker):
				errors.append("Screw %s has unknown blocker %s" % [screw_id, blocker])
				continue
			if blockers.has(blocker):
				errors.append("Screw %s repeats blocker %s" % [screw_id, blocker])
			blockers[blocker] = true
			if _nonnegative_integer(plates[blocker].get("layer")) and _nonnegative_integer(plates[screw.plate_id].get("layer")) and float(plates[blocker].layer) <= float(plates[screw.plate_id].layer):
				errors.append("Blocker %s must be strictly above owner of %s (cycles/self-blocks forbidden)" % [blocker, screw_id])
	# The bundled abstract fixture intentionally has no geometry.
	if level.get("schema_kind", "") != "abstract_rule_fixture":
		if not _valid_id(level.get("level_id")):
			errors.append("Level requires stable level_id")
		if not _nonnegative_integer(level.get("revision")) or int(level.get("revision", 0)) < 1:
			errors.append("Level revision must be a positive integer")
		if not _valid_point(level.get("board_reference_size")) or float(level.get("board_reference_size", [0, 0])[0]) <= 0 or float(level.get("board_reference_size", [0, 0])[1]) <= 0:
			errors.append("Level requires positive board_reference_size [width,height]")
		if not level.get("reference_solution") is Array:
			errors.append("Level requires reference_solution array")
		else:
			var witness_ids: Dictionary = {}
			for screw_id: Variant in level.reference_solution:
				if not screw_id is String or not screws.has(screw_id) or witness_ids.has(screw_id):
					errors.append("reference_solution has unknown or repeated screw %s" % screw_id)
				witness_ids[screw_id] = true
			if witness_ids.size() != screws.size():
				errors.append("reference_solution must contain every screw exactly once")
		for screw_id: String in screws:
			if not _valid_point(screws[screw_id].get("position")):
				errors.append("Screw %s requires a finite [x,y] position" % screw_id)
		for plate_id: String in plates:
			var polygon: Variant = plates[plate_id].get("polygon")
			if not polygon is Array or polygon.size() < 3:
				errors.append("Plate %s requires polygon with at least three vertices" % plate_id)
				continue
			for point: Variant in polygon:
				if not _valid_point(point):
					errors.append("Plate %s contains invalid polygon coordinates" % plate_id)
	return errors

static func validate_state(level: Dictionary, state: Dictionary) -> Array:
	var errors: Array = validate_definition(level)
	if not errors.is_empty():
		return errors
	for key: String in ["remaining_screw_ids", "removed_plate_ids", "active_box_slots", "buffer_screw_ids", "completed_boxes"]:
		if not state.get(key) is Array:
			errors.append("State %s must be an array" % key)
	if not errors.is_empty():
		return errors
	if state.get("level_id") != level.get("level_id", level.get("fixture_id", "")) or state.get("content_hash") != _content_hash(level) or state.get("revision") != level.get("revision", 1):
		errors.append("State content identity mismatch")
	if state.get("ruleset_id") != "classic_sort_v1" or state.get("ruleset_hash") != RULES_HASH:
		errors.append("State ruleset identity mismatch")
	var queue_cursor: int = int(state.next_queue_index) if _nonnegative_integer(state.get("next_queue_index")) else -1
	var move_count: int = int(state.move_count) if _nonnegative_integer(state.get("move_count")) else -1
	if queue_cursor < 0 or queue_cursor > level.boxes_in_activation_order.size():
		errors.append("Invalid queue cursor")
	if move_count < 0:
		errors.append("Invalid move_count")
	if state.active_box_slots.size() != RULES.active_box_slots:
		errors.append("Wrong active slot count")
	if state.buffer_screw_ids.size() > RULES.buffer_capacity:
		errors.append("Buffer exceeds capacity")
	var definitions: Dictionary = {}
	for screw: Dictionary in level.screws:
		definitions[screw.id] = screw
	var locations: Dictionary = {}
	for key: String in ["remaining_screw_ids", "buffer_screw_ids"]:
		for screw_id: Variant in state[key]:
			_record_location(screw_id, key, definitions, locations, errors)
	var boxes: Dictionary = {}
	for box: Dictionary in level.boxes_in_activation_order:
		boxes[box.id] = box
	var seen_boxes: Dictionary = {}
	for key: String in ["active_box_slots", "completed_boxes"]:
		for item: Variant in state[key]:
			if item == null and key == "active_box_slots":
				if queue_cursor < level.boxes_in_activation_order.size():
					errors.append("Inactive slot while queue still contains orders")
				continue
			if not item is Dictionary or not item.get("screw_ids") is Array:
				errors.append("Malformed box record in %s" % key)
				continue
			var box: Dictionary = item
			var box_id: String = str(box.get("box_id", ""))
			if not boxes.has(box_id) or seen_boxes.has(box_id):
				errors.append("Unknown or repeated box %s" % box_id)
				continue
			seen_boxes[box_id] = true
			var activation: Variant = box.get("activation_index")
			if not _nonnegative_integer(activation) or int(activation) >= level.boxes_in_activation_order.size():
				errors.append("Invalid activation index on %s" % box_id)
			elif level.boxes_in_activation_order[int(activation)].id != box_id or int(activation) >= queue_cursor:
				errors.append("Box %s disagrees with fixed queue" % box_id)
			if box.get("color_id") != boxes[box_id].color_id:
				errors.append("Wrong box color on %s" % box_id)
			var count: int = box.screw_ids.size()
			if count != RULES.box_capacity if key == "completed_boxes" else count >= RULES.box_capacity:
				errors.append("Unsettled or wrong box capacity on %s" % box_id)
			for screw_id: Variant in box.screw_ids:
				_record_location(screw_id, box_id, definitions, locations, errors)
				if definitions.has(screw_id) and definitions[screw_id].color_id != box.get("color_id"):
					errors.append("Screw %s has wrong color for box %s" % [screw_id, box_id])
	if seen_boxes.size() != queue_cursor:
		errors.append("Activated box conservation failed")
	if locations.size() != definitions.size():
		errors.append("Screw conservation failed: missing screws")
	if move_count != definitions.size() - state.remaining_screw_ids.size():
		errors.append("Move count disagrees with board removals")
	var removed: Dictionary = {}
	for plate_id: Variant in state.removed_plate_ids:
		if not plate_id is String or removed.has(plate_id):
			errors.append("Invalid or duplicate removed plate")
		removed[plate_id] = true
	for plate: Dictionary in level.plates:
		if removed.has(plate.id) == _plate_has_screws(plate, state):
			errors.append("Plate %s clear status disagrees with remaining screws" % plate.id)
		removed.erase(plate.id)
	if not removed.is_empty():
		errors.append("Unknown removed plate IDs")
	if not errors.is_empty():
		return errors
	for screw_id: String in state.buffer_screw_ids:
		if _matching_slot(state, definitions[screw_id].color_id) >= 0:
			errors.append("State is unsettled: eligible buffer screw %s" % screw_id)
	var expected: Dictionary = state.duplicate(true)
	_evaluate(level, expected, [])
	if state.get("status") != expected.status:
		errors.append("Status should be %s" % expected.status)
	return errors

static func _settle(level: Dictionary, state: Dictionary, events: Array) -> void:
	while true:
		var completed_slot: int = -1
		for slot: int in range(state.active_box_slots.size()):
			var box: Variant = state.active_box_slots[slot]
			if box != null and box.screw_ids.size() == RULES.box_capacity:
				if completed_slot < 0 or _older_box(box, state.active_box_slots[completed_slot]):
					completed_slot = slot
		if completed_slot >= 0:
			var box: Dictionary = state.active_box_slots[completed_slot]
			state.completed_boxes.append(box)
			events.append({"type": "BoxCompleted", "box_id": box.box_id, "slot_index": completed_slot, "screw_ids": box.screw_ids.duplicate()})
			state.active_box_slots[completed_slot] = null
			_activate_box(level, state, completed_slot, events)
			continue
		var transferred: bool = false
		for buffer_index: int in range(state.buffer_screw_ids.size()):
			var screw_id: String = state.buffer_screw_ids[buffer_index]
			var slot: int = _matching_slot(state, _find_screw(level, screw_id).color_id)
			if slot >= 0:
				state.buffer_screw_ids.remove_at(buffer_index)
				state.active_box_slots[slot].screw_ids.append(screw_id)
				events.append({"type": "BufferTransferred", "screw_id": screw_id, "box_id": state.active_box_slots[slot].box_id, "slot_index": slot, "buffer_index": buffer_index})
				transferred = true
				break
		if not transferred:
			break

static func _activate_box(level: Dictionary, state: Dictionary, slot: int, events: Array) -> void:
	var cursor: int = int(state.next_queue_index)
	if cursor >= level.boxes_in_activation_order.size():
		return
	var definition: Dictionary = level.boxes_in_activation_order[cursor]
	state.active_box_slots[slot] = {"box_id": definition.id, "color_id": definition.color_id, "activation_index": cursor, "screw_ids": []}
	state.next_queue_index = cursor + 1
	events.append({"type": "BoxActivated", "box_id": definition.id, "color_id": definition.color_id, "slot_index": slot, "activation_index": cursor})

static func _evaluate(level: Dictionary, state: Dictionary, events: Array) -> void:
	if state.remaining_screw_ids.is_empty():
		if state.buffer_screw_ids.is_empty() and state.completed_boxes.size() == level.boxes_in_activation_order.size():
			state.status = "WON"
			events.append({"type": "PuzzleWon"})
		else:
			state.status = "CONTENT_ERROR"
		return
	state.status = "ACTIVE"
	if get_legal_moves(level, state).is_empty():
		state.status = "STUCK"
		events.append({"type": "PuzzleStuck"})

static func _matching_slot(state: Dictionary, color: String) -> int:
	var best: int = -1
	for slot: int in range(state.active_box_slots.size()):
		var box: Variant = state.active_box_slots[slot]
		if box != null and box.color_id == color and box.screw_ids.size() < RULES.box_capacity:
			if best < 0 or _older_box(box, state.active_box_slots[best]):
				best = slot
	return best

static func _older_box(a: Dictionary, b: Dictionary) -> bool:
	return int(a.activation_index) < int(b.activation_index) if int(a.activation_index) != int(b.activation_index) else str(a.box_id) < str(b.box_id)

static func _find_screw(level: Dictionary, screw_id: String) -> Dictionary:
	for screw: Dictionary in level.get("screws", []):
		if screw.get("id") == screw_id:
			return screw
	return {}

static func _plate_has_screws(plate: Dictionary, state: Dictionary) -> bool:
	for screw_id: String in plate.screw_ids:
		if state.remaining_screw_ids.has(screw_id):
			return true
	return false

static func _reject(state: Dictionary, reason: String) -> Dictionary:
	return {"accepted": false, "rejection_reason": reason, "next_state": state.duplicate(true), "events": []}

static func _content_hash(level: Dictionary) -> String:
	var definition: Dictionary = level.duplicate(true)
	definition.erase("content_hash")
	return JSON.stringify(_normalize_numbers(definition), "", true).sha256_text()

static func _normalize_numbers(value: Variant) -> Variant:
	if value is float and is_finite(value) and value == floor(value):
		return int(value)
	if value is Dictionary:
		var result: Dictionary = {}
		for key: Variant in value:
			result[key] = _normalize_numbers(value[key])
		return result
	if value is Array:
		var result: Array = []
		for item: Variant in value:
			result.append(_normalize_numbers(item))
		return result
	return value

static func _valid_id(value: Variant) -> bool:
	return value is String and not value.is_empty()

static func _nonnegative_integer(value: Variant) -> bool:
	return (value is int or value is float) and is_finite(float(value)) and float(value) >= 0 and float(value) == floor(float(value))

static func _valid_point(value: Variant) -> bool:
	return value is Array and value.size() == 2 and (value[0] is float or value[0] is int) and (value[1] is float or value[1] is int) and is_finite(float(value[0])) and is_finite(float(value[1]))

static func _record_location(screw_id: Variant, location: String, definitions: Dictionary, seen: Dictionary, errors: Array) -> void:
	if not screw_id is String or not definitions.has(screw_id):
		errors.append("Unknown screw %s in %s" % [screw_id, location])
		return
	if seen.has(screw_id):
		errors.append("Screw %s appears in both %s and %s" % [screw_id, seen[screw_id], location])
	seen[screw_id] = location

static func _move_score(level: Dictionary, state: Dictionary, screw_id: String) -> int:
	var screw: Dictionary = _find_screw(level, screw_id)
	var score: int = 100 if _matching_slot(state, screw.color_id) >= 0 else 0
	for plate: Dictionary in level.plates:
		if plate.id != screw.plate_id:
			continue
		var remaining: int = 0
		for owned_id: String in plate.screw_ids:
			if state.remaining_screw_ids.has(owned_id):
				remaining += 1
		if remaining == 1:
			score += 10
	return score
