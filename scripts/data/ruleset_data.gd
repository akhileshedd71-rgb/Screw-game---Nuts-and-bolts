class_name RulesetData
extends Resource
## Versioned, inspector-visible puzzle rules. Campaign resolves classic_sort_v1.

@export var ruleset_id: StringName = &"classic_sort_v1"
@export var ruleset_revision: int = 1
@export_range(1, 4, 1) var active_box_slots: int = 2
@export_range(1, 8, 1) var box_capacity: int = 3
@export_range(1, 12, 1) var buffer_capacity: int = 5
@export_range(0, 4, 1) var queue_preview_count: int = 2
