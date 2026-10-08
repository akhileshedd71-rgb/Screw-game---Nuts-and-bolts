class_name SaveService
extends RefCounted
## Single synchronous writer. Never replaces the newest valid recovery slot.
## payload_json is hashed as stored, avoiding JSON number/order round-trip drift.

const SCHEMA_VERSION := 1
const MAX_SAVE_BYTES := 8 * 1024 * 1024
const SETTINGS := ["sound", "music", "haptics", "reduced_motion"]

var directory: String
var read_only_future_schema := false
var last_error := ""
var load_status := "new"
var save_sequence := 0
var _loaded := false
var _writing := false
var _newest_slot := ""

func _init(save_directory: String = "user://screwcraft") -> void:
	directory = save_directory.trim_suffix("/")

func default_profile() -> Dictionary:
	return {
		"settings": {"sound": true, "music": true, "haptics": true, "reduced_motion": false},
		"completed_levels": [], "reward_grant_ledger": [], "coins": 0,
		"owned_skins": ["beech"], "skin": "beech", "current_level": 1,
		"tutorial_progress": {}, "attempt": {},
	}

func load_profile() -> Dictionary:
	_loaded = true
	last_error = ""
	read_only_future_schema = false
	save_sequence = 0
	_newest_slot = ""
	var best: Dictionary = {}
	var saw_file := false
	for slot: String in ["a", "b"]:
		var path := _slot_path(slot)
		if FileAccess.file_exists(path):
			saw_file = true
		var result := _read_slot(path)
		if result.get("future", false):
			read_only_future_schema = true
		if result.get("valid", false) and int(result["sequence"]) > save_sequence:
			save_sequence = int(result["sequence"])
			best = result["profile"]
			_newest_slot = slot
	if read_only_future_schema:
		load_status = "future_schema"
		last_error = "This save belongs to a newer game version. It is protected; update the game to save progress."
	elif not best.is_empty():
		load_status = "loaded"
	elif saw_file:
		load_status = "recovery_failed"
		last_error = "Neither saved copy could be read. A fresh local profile is in use."
	else:
		load_status = "new"
	return default_profile() if best.is_empty() else best.duplicate(true)

func save_profile(profile: Dictionary) -> bool:
	if not _loaded:
		load_profile()
	if _writing:
		last_error = "A save is already being written."
		return false
	# Check again before any mutation: another game version may have run since load.
	var observed_sequence := 0
	var observed_slot := ""
	for slot: String in ["a", "b"]:
		var observation := _read_slot(_slot_path(slot))
		if observation.get("future", false):
			read_only_future_schema = true
		if observation.get("valid", false) and int(observation["sequence"]) > observed_sequence:
			observed_sequence = int(observation["sequence"])
			observed_slot = slot
	if read_only_future_schema:
		last_error = "This save belongs to a newer game version. Update the game to save progress."
		return false
	if observed_sequence > save_sequence:
		last_error = "A newer session has saved progress. Reopen the game before saving from this older session."
		return false
	if not observed_slot.is_empty():
		_newest_slot = observed_slot
	var clean := _validate_profile(profile)
	if clean.is_empty():
		last_error = "The profile did not pass validation; the previous save is safe."
		return false
	_writing = true
	var ok := _write_snapshot(clean)
	_writing = false
	return ok

func _write_snapshot(profile: Dictionary) -> bool:
	var absolute_directory := ProjectSettings.globalize_path(directory)
	if DirAccess.make_dir_recursive_absolute(absolute_directory) != OK:
		last_error = "Could not create the save folder."
		return false
	var next_sequence := save_sequence + 1
	var slot := "b" if _newest_slot == "a" else "a"
	var destination := _slot_path(slot)
	var temporary := destination + ".tmp"
	var payload := JSON.stringify(profile, "", true, true)
	var envelope := {
		"save_schema_version": SCHEMA_VERSION, "save_sequence": next_sequence,
		"payload_json": payload, "checksum": payload.sha256_text(),
	}
	var file := FileAccess.open(temporary, FileAccess.WRITE)
	if file == null:
		last_error = "Could not open a new save. The previous save is safe."
		return false
	file.store_string(JSON.stringify(envelope, "", true, true))
	file.flush()
	var write_error := file.get_error()
	file.close()
	if write_error != OK:
		last_error = "The save could not be written. Check available storage."
		return false
	var checked := _read_slot(temporary)
	if not checked.get("valid", false) or int(checked.get("sequence", 0)) != next_sequence:
		last_error = "The new save failed its checksum check. The previous save is safe."
		return false
	# POSIX/Android rename replaces only the older slot; the other slot survives.
	var renamed := DirAccess.rename_absolute(ProjectSettings.globalize_path(temporary), ProjectSettings.globalize_path(destination))
	if renamed != OK:
		last_error = "Could not commit the new save. The previous save is safe."
		return false
	save_sequence = next_sequence
	_newest_slot = slot
	last_error = ""
	return true

func _slot_path(slot: String) -> String:
	return directory.path_join("profile_" + slot + ".json")

func _read_slot(path: String) -> Dictionary:
	if not FileAccess.file_exists(path):
		return {}
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		return {}
	if file.get_length() > MAX_SAVE_BYTES:
		file.close()
		return {}
	var source := file.get_as_text()
	file.close()
	var parser := JSON.new()
	if parser.parse(source) != OK:
		return {}
	var parsed: Variant = parser.data
	if not parsed is Dictionary:
		return {}
	var version: Variant = parsed.get("save_schema_version")
	if not _whole_number(version, 1, 2147483647):
		return {}
	if int(version) > SCHEMA_VERSION:
		return {"future": true}
	if int(version) != SCHEMA_VERSION:
		return {}
	var sequence: Variant = parsed.get("save_sequence")
	var payload: Variant = parsed.get("payload_json")
	var checksum: Variant = parsed.get("checksum")
	if not _whole_number(sequence, 1, 9007199254740991) or not payload is String or not checksum is String:
		return {}
	if payload.sha256_text() != checksum:
		return {}
	if parser.parse(payload) != OK:
		return {}
	var body: Variant = parser.data
	if not body is Dictionary:
		return {}
	var profile := _validate_profile(body)
	if profile.is_empty():
		return {}
	return {"valid": true, "sequence": int(sequence), "profile": profile}

func _validate_profile(raw: Dictionary) -> Dictionary:
	var clean := default_profile()
	if not _whole_number(raw.get("coins"), 0, 1000000000) or not _whole_number(raw.get("current_level"), 1, 1000000):
		return {}
	if not _string_list(raw.get("completed_levels")) or not _string_list(raw.get("owned_skins")):
		return {}
	var selected: Variant = raw.get("skin")
	if not selected is String or not selected in raw["owned_skins"] or not "beech" in raw["owned_skins"]:
		return {}
	var settings: Variant = raw.get("settings")
	if not settings is Dictionary:
		return {}
	for key: String in SETTINGS:
		if settings.has(key):
			if not settings[key] is bool:
				return {}
			clean["settings"][key] = settings[key]
	var ledger: Variant = raw.get("reward_grant_ledger", [])
	if not _string_list(ledger):
		return {}
	clean["reward_grant_ledger"] = ledger.duplicate()
	for id: String in raw["completed_levels"]:
		var key := "first_clear:" + id
		if not key in clean["reward_grant_ledger"]:
			clean["reward_grant_ledger"].append(key)
	clean["coins"] = int(raw["coins"])
	clean["current_level"] = int(raw["current_level"])
	clean["completed_levels"] = raw["completed_levels"].duplicate()
	clean["owned_skins"] = raw["owned_skins"].duplicate()
	clean["skin"] = selected
	# Invalid attempts are disposable; permanent progress must remain recoverable.
	if raw.get("attempt", {}) is Dictionary:
		clean["attempt"] = raw.get("attempt", {}).duplicate(true)
	if raw.get("tutorial_progress", {}) is Dictionary:
		clean["tutorial_progress"] = raw.get("tutorial_progress", {}).duplicate(true)
	return clean

func _string_list(value: Variant) -> bool:
	if not value is Array or value.size() > 100000:
		return false
	var seen := {}
	for entry: Variant in value:
		if not entry is String or entry.is_empty() or entry.length() > 160 or seen.has(entry):
			return false
		seen[entry] = true
	return true

func _whole_number(value: Variant, minimum: int, maximum: int) -> bool:
	if not (value is int or value is float):
		return false
	return is_finite(float(value)) and float(value) == floor(float(value)) and value >= minimum and value <= maximum
