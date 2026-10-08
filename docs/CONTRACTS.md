# Screwcraft implementation contracts

The user authorizes building a new Godot mobile game in this empty checkout and requests at least 1,000 levels. This supersedes the attachment's 30-level first-release scope. No ads, purchases, timers or lives. The final baseline is official Godot 4.7.2 with matching templates, verified by the platform specialist; the preinstalled 4.6.3 was used only for early component checks.

## Shared runtime API

All paths use `res://`. Pure model classes extend RefCounted; use explicit preloads where helpful. JSON dictionaries are immutable definitions; reducers return independent dictionaries. Colors: red/circle, blue/diamond, green/triangle, yellow/star, purple/square, teal/three bars. Classic constants: 2 active slots, 3 per box, 5 buffer slots, 2 previews.

`scripts/core/puzzle_reducer.gd` class PuzzleReducer:
- static create_initial_state(level: Dictionary) -> Dictionary
- static apply_select(level: Dictionary, state: Dictionary, screw_id: String) -> Dictionary with accepted, rejection_reason, next_state, events.
- static get_legal_moves(level, state) -> Array (IDs)
- static is_exposed(level, state, screw_id) -> bool
- static canonical_hash(state) -> String
- static validate_state(level, state) -> Array (error strings)
- static validate_definition(level) -> Array
- static solve(level, state, node_limit = 2500) -> Dictionary: outcome SOLVED/UNSOLVABLE/UNKNOWN_LIMIT, solution Array, expanded_states.

State keys match fixture: remaining_screw_ids, removed_plate_ids, active_box_slots (null or box_id/color_id/activation_index/screw_ids), buffer_screw_ids, completed_boxes, next_queue_index, status (ACTIVE/STUCK/WON/CONTENT_ERROR), move_count. Include level_id, content_hash, ruleset_id. Events have type (ScrewRemoved, ScrewRouted, PlateCleared, BoxCompleted, BoxActivated, BufferTransferred, PuzzleWon, PuzzleStuck), stable screw_id/plate_id/box_id as applicable. Routing event destination = box or buffer, slot_index.

## Level schema

`content/levels/campaign.json`: array of 1,000 complete immutable levels (or dictionary with levels array, agree with lead). `scripts/data/level_repository.gd` class LevelRepository with static get_catalog() -> Array and static load_level(index: int) -> Dictionary (index 1-based). Required definition keys schema_version:1, level_id:campaign_0001, index, name, family, chapter, difficulty, revision:1, ruleset_id:classic_sort_v1, board_reference_size:[640,600], boxes_in_activation_order [{id,color_id}], plates, screws, reference_solution, tutorial_tags, lesson.

Plate keys id, layer, screw_ids, polygon:[[x,y],...], material (0..3), position:[x,y], rotation:0. Polygon and screw positions use absolute board-local coordinates (polygon authoritative; position is optional metadata). Screw keys id, color_id, plate_id, blocker_plate_ids, position:[x,y]. Centers should stay within x=40..600,y=40..560. Head radius 24; exposed centers >=58 apart. Blockers must visually cover head centers with radius margin. First 30 follow attached briefs where feasible; 1,000 store validated witnessed variations with meaningful topology and layout variety. No claims of human playtesting.

## Board presentation API

`scripts/ui/board_view.gd` extends Control, class BoardView. Root UI positions this control at 640x600 logical dimensions. Signals screw_pressed(screw_id:String). Methods configure(level:Dictionary,state:Dictionary), update_state(state:Dictionary), set_hint(screw_id:String), set_blueprint(enabled:bool). Public input_enabled:bool, reduced_motion:bool, skin:String='beech', external_screw_flights:bool. Render from authoritative state; never modify it. Input targets only exposed screws; select nearest within 48 logical units, with stable disambiguation. A blocked click may emit for explanatory reducer feedback. Parent owns destination flights; BoardView owns cosmetic piece releases. No gameplay dependencies beyond PuzzleReducer.

## Persistence and session API

`scripts/services/save_service.gd` class SaveService extends RefCounted: load_profile()->Dictionary; save_profile(profile)->bool; default_profile()->Dictionary. A/B checksum snapshots in user://; profile includes settings:{sound:true,music:true,haptics:true,reduced_motion:false}, completed_levels:Array stable IDs, coins:int, owned_skins:['beech'], skin:'beech', current_level:1, attempt:Dictionary. Unknown future version must be protected.

`scripts/session/game_session.gd` class GameSession extends RefCounted. Public level:Dictionary,state:Dictionary,history:Array,epoch:int,profile:Dictionary, last_save_ok:bool. _init() loads profile. start_level(index:int, resume:bool=true); select_screw(id:String)->Dictionary; undo()->bool; restart(); save()->bool; hint()->Dictionary; purchase_skin(id:String)->bool; set_setting(key:String,value:bool). Accepted moves synchronously commit and save before UI animation. Attempt snapshot and undo history survive restart; wins grant 20 coins once per level and clear undo; cosmetic costs 100. Root UI gates input and owns view epoch checks. start_level calls LevelRepository. Settings and profile may be updated by root then save().

## Ownership

- Lead: project.godot, scenes/main.tscn, scripts/ui/app.gd, integration, README.
- Gameplay agent: scripts/core, scripts/data/ruleset_data.gd, content/rulesets.
- Level agent: tools/generate_campaign.py, content/levels, scripts/data/level_repository.gd, content/art_catalog.json, tools/validate_geometry.py.
- Art/UI agent: scripts/ui/board_view.gd, scripts/ui/craft_draw.gd, assets/art, scenes/components.
- Persistence agent: scripts/session, scripts/services/save_service.gd, tests/test_persistence.gd.
- Audio/game-design agent: assets/audio, assets/fonts, scripts/services/audio_service.gd, docs/DESIGN.md, assets/ASSET_MANIFEST.md.
- QA/platform agent: tests excluding persistence, tools/test scripts, export_presets.cfg, docs/QA.md, platform tool installation/export investigation. Coordinate project.godot edits with lead.

Keep bounded ownership; communicate API changes. Run actual Godot checks. Report verified versus unrun behavior. Never claim physical-device verification from desktop results.
