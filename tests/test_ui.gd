extends SceneTree
## Actual App regression suite. The launcher always isolates its profile in /tmp.
## Run: ./tools/godot.sh --headless --path . --script tests/test_ui.gd
const Reducer = preload("res://scripts/core/puzzle_reducer.gd")
const MainScene = preload("res://scenes/main.tscn")
var app: Node
var failures: Array[String] = []
var assertions: int = 0
var cases: int = 0

func _initialize() -> void:
	if not "--ui-child" in OS.get_cmdline_user_args():
		call_deferred("_launch_isolated")
	else:
		if not OS.get_environment("XDG_DATA_HOME").begins_with("/tmp/screwcraft-ui-tests-"):
			printerr("UI child refuses to use a non-isolated profile directory")
			quit(2)
			return
		call_deferred("_run")

func _launch_isolated() -> void:
	var temporary: String = "/tmp/screwcraft-ui-tests-%d-%d" % [OS.get_process_id(), Time.get_ticks_usec()]
	var arguments := PackedStringArray([
		"XDG_DATA_HOME=" + temporary + "/data",
		"XDG_CONFIG_HOME=" + temporary + "/config",
		"XDG_CACHE_HOME=" + temporary + "/cache",
		OS.get_executable_path(), "--headless", "--path", ProjectSettings.globalize_path("res://"),
		"--script", "res://tests/test_ui.gd", "--", "--ui-child"
	])
	var output: Array = []
	var code: int = OS.execute("/usr/bin/env", arguments, output, true)
	for line: Variant in output:
		print(str(line).strip_edges())
	quit(code)

func check(condition: bool, label: String) -> void:
	assertions += 1
	if not condition:
		failures.append(label)
		printerr("FAIL: ", label)

func _button(text: String) -> Button:
	for child: Node in app.controls.get_children():
		if child is Button and child.text.strip_edges() == text:
			return child
	return null

func _press(text: String) -> void:
	var button: Button = _button(text)
	check(button != null, "button exists: " + text)
	if button == null:
		return
	check(not button.disabled, "button is enabled: " + text)
	if not button.disabled:
		button.pressed.emit()

func _quiet() -> void:
	app.session.profile.settings.sound = false
	app.session.profile.settings.music = false
	app.session.profile.settings.haptics = false
	app._apply_settings()

func _prepare_last_move(index: int = 1) -> String:
	app._start_level(index)
	var route: Array = app.session.level.reference_solution
	for i: int in range(route.size() - 1):
		var result: Dictionary = app.session.select_screw(route[i])
		check(result.accepted, "last-move setup accepts " + str(route[i]))
	app._sync_board(true)
	app._rebuild_controls()
	return str(route.back())

func _settle_presentation() -> void:
	await create_timer(0.47).timeout

func _test_gate_and_restart() -> void:
	cases += 1
	app._start_level(1)
	var initial: String = Reducer.canonical_hash(app.session.state)
	var route: Array = app.session.level.reference_solution
	app.board.screw_pressed.emit(str(route[0]))
	check(app.busy and not app.board.input_enabled, "accepted tap gates board immediately")
	check(app.session.state.move_count == 1, "first tap commits synchronously")
	app.board.screw_pressed.emit(str(route[1]))
	check(app.session.state.move_count == 1, "rapid distinct second tap cannot commit during presentation")
	app._restart()
	check(Reducer.canonical_hash(app.session.state) == initial, "restart restores full initial state during animation")
	await _settle_presentation()
	check(app.modal.is_empty() and not app.busy and app.board.input_enabled, "stale animation callback cannot alter restarted board")
	check(app.travel.is_empty(), "restart clears flight presentation")

func _test_undo_and_navigation() -> void:
	cases += 1
	app._start_level(1)
	var before: String = Reducer.canonical_hash(app.session.state)
	app.board.screw_pressed.emit("s01")
	app._undo()
	await _settle_presentation()
	check(Reducer.canonical_hash(app.session.state) == before, "undo during animation restores canonical state")
	check(app.session.history.is_empty() and not app.busy and app.board.input_enabled, "undo restores available interaction")
	app.board.screw_pressed.emit("s01")
	app._navigate("home")
	await _settle_presentation()
	check(app.screen == "home" and not app.board.visible, "navigation remains home after stale presentation callback")
	_press("Continue your craft   ›")
	check(app.screen == "game" and app.session.state.move_count == 1, "Continue preserves active attempt")
	check(app.modal.is_empty() and app.board.input_enabled, "Continue re-enables active board")
	app._open_modal("queue")
	var modal_hash: String = Reducer.canonical_hash(app.session.state)
	app.board.screw_pressed.emit("s02")
	check(Reducer.canonical_hash(app.session.state) == modal_hash, "queue modal owns board input")
	app._notification(Node.NOTIFICATION_WM_GO_BACK_REQUEST)
	check(app.modal.is_empty() and app.board.input_enabled, "Android Back closes queue overlay")

func _test_win_modal_and_replay() -> void:
	cases += 1
	var final_id: String = _prepare_last_move()
	var coins_before: int = int(app.session.profile.coins)
	app.board.screw_pressed.emit(final_id)
	check(app.session.state.status == "WON", "victory commits before presentation completes")
	check(int(app.session.profile.coins) == coins_before + 20, "first victory atomically awards 20 coins")
	app._open_modal("settings")
	await _settle_presentation()
	check(app.modal == "settings" and not app.busy, "opened settings survives delayed victory callback")
	check(not app.board.input_enabled and app.travel.is_empty(), "settings cancels obsolete flight and owns input")
	app._open_modal("")
	check(app.modal == "won", "closing settings reconciles committed victory")
	_press("My collection")
	check(app.screen == "album", "result collection button opens album")
	_press("‹  Workshop")
	_press("Continue your craft   ›")
	check(app.modal == "won" and app.session.state.status == "WON", "collection to home to Continue restores victory actions")
	app._notification(Node.NOTIFICATION_WM_GO_BACK_REQUEST)
	check(app.screen == "home", "Android Back leaves terminal modal for home")
	var awarded: int = int(app.session.profile.coins)
	app._start_level(1)
	check(app.session.state.status == "ACTIVE" and app.session.state.move_count == 0, "selecting completed level starts playable replay")
	check(app.modal.is_empty() and app.board.input_enabled, "replay has active board and no stale victory modal")
	final_id = _prepare_last_move()
	app.board.screw_pressed.emit(final_id)
	await _settle_presentation()
	check(app.modal == "won" and not app.first_clear, "replayed victory is labelled as replay")
	check(int(app.session.profile.coins) == awarded, "replay does not duplicate first-clear reward")

func _test_lifecycle() -> void:
	cases += 1
	var final_id: String = _prepare_last_move()
	app.board.screw_pressed.emit(final_id)
	var committed: String = Reducer.canonical_hash(app.session.state)
	app._notification(Node.NOTIFICATION_APPLICATION_PAUSED)
	app._notification(Node.NOTIFICATION_APPLICATION_RESUMED)
	await _settle_presentation()
	check(app.modal == "won" and not app.busy, "resume during final animation restores victory actions")
	check(Reducer.canonical_hash(app.session.state) == committed, "pause/resume preserves committed winning state")
	check(not app.board.input_enabled, "restored victory modal owns input")
	app._start_level(1)
	app.board.screw_pressed.emit("s01")
	app._notification(Node.NOTIFICATION_APPLICATION_PAUSED)
	app._notification(Node.NOTIFICATION_APPLICATION_RESUMED)
	await _settle_presentation()
	check(app.session.state.move_count == 1 and app.board.input_enabled, "resume active move restores settled playable board")
	var hint_button: Button = _button("Hint")
	check(hint_button != null and not hint_button.disabled, "resume rebuilds previously disabled hint control")

func _test_blueprint_and_stuck() -> void:
	cases += 1
	app._start_level(1)
	var initial: String = Reducer.canonical_hash(app.session.state)
	_press("Blueprint")
	check(app.inspection and not app.board.input_enabled, "Blueprint is read-only")
	app.board.screw_pressed.emit("s01")
	check(Reducer.canonical_hash(app.session.state) == initial, "Blueprint cannot commit board commands")
	app._notification(Node.NOTIFICATION_WM_GO_BACK_REQUEST)
	check(not app.inspection and app.board.input_enabled, "Android Back closes active Blueprint")
	app._start_level(8)
	for id: String in ["G3", "Y1", "Y2", "G1", "R1", "R2"]:
		var result: Dictionary = app.session.select_screw(id)
		check(result.accepted, "STUCK setup accepts " + id)
	app._sync_board(true)
	app.board.screw_pressed.emit("Y3")
	await _settle_presentation()
	check(app.session.state.status == "STUCK" and app.modal == "stuck", "documented wrong fork opens recovery modal")
	var stuck_hash: String = Reducer.canonical_hash(app.session.state)
	_press("Inspect the board")
	check(app.inspection and app.modal.is_empty() and not app.board.input_enabled, "STUCK inspection intentionally allows read-only board")
	app.board.screw_pressed.emit("G2")
	check(Reducer.canonical_hash(app.session.state) == stuck_hash, "STUCK inspection preserves puzzle state")
	app._notification(Node.NOTIFICATION_APPLICATION_PAUSED)
	app._notification(Node.NOTIFICATION_APPLICATION_RESUMED)
	check(app.inspection and app.modal.is_empty(), "resume preserves intentional STUCK Blueprint inspection")
	_press("Back to puzzle")
	check(not app.inspection and app.modal == "stuck", "leaving STUCK Blueprint restores recovery controls")
	_press("Undo last move")
	check(app.session.state.status == "ACTIVE" and app.modal.is_empty() and app.board.input_enabled, "STUCK undo recovers an active board")
	app._hint()
	check(not app.hint_id.is_empty() and Reducer.get_legal_moves(app.session.level, app.session.state).has(app.hint_id), "hint after undo names a legal verified continuation")
	app._restart()
	check(app.hint_id.is_empty(), "restart clears hint from old attempt")

func _run() -> void:
	var started: int = Time.get_ticks_msec()
	app = MainScene.instantiate()
	root.add_child(app)
	await process_frame
	if app.session == null:
		printerr("FAIL: App did not initialize")
		quit(1)
		return
	_quiet()
	check(app.catalogue.size() >= 1000, "actual App loads full campaign")
	check(app.session.state.status == "ACTIVE" and app.board.input_enabled, "fresh isolated App starts playable")
	await _test_gate_and_restart()
	await _test_undo_and_navigation()
	await _test_win_modal_and_replay()
	await _test_lifecycle()
	await _test_blueprint_and_stuck()
	var report: Dictionary = {"suite": "app_ui", "cases": cases, "assertions": assertions, "failures": failures,
		"duration_ms": Time.get_ticks_msec() - started, "engine": Engine.get_version_info().string,
		"profile_directory": OS.get_user_data_dir(), "scope": "Headless actual App; lifecycle notifications and UI callbacks, no physical-device input/performance claim"}
	DirAccess.make_dir_recursive_absolute("res://builds/reports")
	var file := FileAccess.open("res://builds/reports/ui.json", FileAccess.WRITE)
	if file != null:
		file.store_string(JSON.stringify(report, "  "))
	print(JSON.stringify(report))
	quit(0 if failures.is_empty() else 1)
