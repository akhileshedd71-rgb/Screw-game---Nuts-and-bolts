class_name LevelRepository
extends RefCounted
## Finite, reproducible campaign. Definitions are copied before leaving this API.

const CAMPAIGN_PATH := "res://content/levels/campaign.json"
static var _levels: Array = []
static var _catalog: Array = []
static var _loaded := false
static var _load_error := ""

static func _ensure_loaded() -> void:
	if _loaded:
		return
	_loaded = true
	if not FileAccess.file_exists(CAMPAIGN_PATH):
		_load_error = "Campaign content is missing."
		push_error(_load_error)
		return
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(CAMPAIGN_PATH))
	if not parsed is Array or parsed.size() != 1000:
		_load_error = "Campaign must contain exactly 1,000 finite level definitions."
		push_error(_load_error)
		return
	_levels = parsed
	for value: Variant in _levels:
		var level: Dictionary = value
		_catalog.append({
			"index": int(level.get("index", 0)),
			"level_id": str(level.get("level_id", "")),
			"name": str(level.get("name", "")),
			"family": str(level.get("family", "keepsake")),
			"chapter": int(level.get("chapter", 1)),
			"difficulty": str(level.get("difficulty", "practice")),
			"lesson": str(level.get("lesson", "")),
			"screw_count": level.get("screws", []).size(),
			"plate_count": level.get("plates", []).size(),
			"content_hash": str(level.get("content_hash", ""))
		})

static func get_catalog() -> Array:
	_ensure_loaded()
	return _catalog.duplicate(true)

static func load_level(index: int) -> Dictionary:
	_ensure_loaded()
	if index < 1 or index > _levels.size():
		return {}
	return _levels[index - 1].duplicate(true)

static func get_load_error() -> String:
	_ensure_loaded()
	return _load_error
