extends Control
## Application shell. The session commits game state; this layer only presents it.

const Session = preload("res://scripts/session/game_session.gd")
const Repository = preload("res://scripts/data/level_repository.gd")
const Reducer = preload("res://scripts/core/puzzle_reducer.gd")
const Board = preload("res://scripts/ui/board_view.gd")
const Craft = preload("res://scripts/ui/craft_draw.gd")
const Audio = preload("res://scripts/services/audio_service.gd")
const SANS = preload("res://assets/fonts/OpenSans-Regular.ttf")
const BOLD = preload("res://assets/fonts/OpenSans-Semibold.ttf")
const SERIF = preload("res://assets/fonts/LMRoman10-Regular.otf")
const PAPER = Color("f7f5ee")
const INK = Color("2e4238")
const MUTED = Color("788477")
const GREEN = Color("426b54")
const PALE = Color("e8ecdf")
const LINE = Color("d9ded0")
const GOLD = Color("bc8c41")

var session: RefCounted
var audio_service: Node
var stage: Control
var board: Control
var overlay: Control
var controls: Control
var screen: String = "game"
var modal: String = ""
var inspection: bool = false
var busy: bool = false
var generation: int = 0
var level_page: int = 0
var album_page: int = 0
var queue_page: int = 0
var message: String = ""
var hint_id: String = ""
var message_expiry: float = 0.0
var first_clear: bool = false
var last_size: Vector2 = Vector2.ZERO
var catalogue: Array = []
var travel: Dictionary = {}
var travel_time: float = 1.0


func _ready() -> void:
	RenderingServer.set_default_clear_color(PAPER)
	stage = Control.new()
	stage.name = "PortraitCanvas"
	stage.size = Vector2(720, 1280)
	stage.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(stage)
	stage.draw.connect(_draw_stage)
	board = Board.new()
	board.name = "CraftBoard"
	board.position = Vector2(40, 444)
	board.size = Vector2(640, 600)
	stage.add_child(board)
	board.external_screw_flights = true
	board.screw_pressed.connect(_select_screw)
	overlay = Control.new()
	overlay.size = Vector2(720, 1280)
	overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	stage.add_child(overlay)
	overlay.draw.connect(_draw_overlay)
	controls = Control.new()
	controls.size = Vector2(720, 1280)
	controls.mouse_filter = Control.MOUSE_FILTER_IGNORE
	stage.add_child(controls)
	audio_service = Audio.new()
	add_child(audio_service)
	session = Session.new()
	catalogue = Repository.get_catalog()
	if catalogue.is_empty():
		message = "The campaign could not be loaded."
		return
	session.start_level(int(session.profile.get("current_level", 1)), true)
	_apply_settings()
	_sync_board(true)
	if not str(session.restore_message).is_empty():
		_toast(str(session.restore_message), 9.0)
	if session.state.get("status") == "WON":
		modal = "won"
	_rebuild_controls()
	_fit()
	get_viewport().size_changed.connect(_fit)
	get_tree().auto_accept_quit = false
	set_process(true)


func _notification(what: int) -> void:
	if session == null:
		return
	if what == NOTIFICATION_APPLICATION_PAUSED or what == NOTIFICATION_WM_CLOSE_REQUEST:
		session.save()
		generation += 1
		busy = false
		travel.clear()
		if what == NOTIFICATION_WM_CLOSE_REQUEST:
			get_tree().quit()
	elif what == NOTIFICATION_APPLICATION_RESUMED:
		generation += 1
		busy = false
		_reconcile_terminal_modal()
		_sync_board(true)
		_rebuild_controls()
	elif what == NOTIFICATION_WM_GO_BACK_REQUEST:
		if not modal.is_empty():
			if modal in ["won", "stuck"]:
				_navigate("home")
			else:
				_open_modal("")
		elif inspection:
			_set_inspection(false)
		elif screen != "home":
			_navigate("home")
		else:
			session.save()
			get_tree().quit()


func _process(delta: float) -> void:
	if not travel.is_empty():
		travel_time += delta
		if travel_time >= 0.36:
			travel.clear()
		overlay.queue_redraw()
	if not message.is_empty() and Time.get_ticks_msec() / 1000.0 > message_expiry:
		message = ""
		stage.queue_redraw()


func _unhandled_key_input(event: InputEvent) -> void:
	if not event is InputEventKey or not event.pressed or event.echo:
		return
	if event.keycode == KEY_ESCAPE:
		if not modal.is_empty():
			_open_modal("")
		elif screen == "game":
			_open_modal("settings")
		else:
			_navigate("home")
	elif screen == "game" and modal.is_empty():
		match event.keycode:
			KEY_U: _undo()
			KEY_H: _hint()
			KEY_B:
				_set_inspection(not inspection)


func _fit() -> void:
	var available: Vector2 = get_viewport_rect().size
	var inset: Vector2 = Vector2.ZERO
	if OS.has_feature("mobile"):
		var safe: Rect2i = DisplayServer.get_display_safe_area()
		var window_pixels := Vector2(DisplayServer.window_get_size())
		if safe.size.x > 0 and safe.size.y > 0 and window_pixels.x > 0 and window_pixels.y > 0:
			var factor: Vector2 = available / window_pixels
			inset = Vector2(safe.position - DisplayServer.window_get_position()) * factor
			available = Vector2(safe.size) * factor
	var ratio: float = minf(available.x / 720.0, available.y / 1280.0)
	stage.scale = Vector2.ONE * ratio
	stage.position = inset + (available - Vector2(720, 1280) * ratio) * 0.5
	last_size = available
	stage.queue_redraw()


func _apply_settings() -> void:
	var settings: Dictionary = session.profile.get("settings", {})
	board.reduced_motion = bool(settings.get("reduced_motion", false))
	board.skin = str(session.profile.get("skin", "beech"))
	audio_service.set_enabled(bool(settings.get("sound", true)), bool(settings.get("music", true)))


func _sync_board(reset: bool = false) -> void:
	board.visible = screen == "game"
	board.input_enabled = screen == "game" and modal.is_empty() and not busy and not inspection
	if reset:
		board.configure(session.level, session.state)
	else:
		board.update_state(session.state)
	board.set_blueprint(inspection)
	board.set_hint(hint_id)
	stage.queue_redraw()
	overlay.queue_redraw()


func _select_screw(screw_id: String) -> void:
	if busy or not modal.is_empty() or inspection or screen != "game":
		return
	var result: Dictionary = session.select_screw(screw_id)
	if not result.get("accepted", false):
		var reason: String = str(result.get("rejection_reason", ""))
		_toast("Remove the piece above first" if reason == "COVERED" else "Buffer full. Match a ready box or Undo.")
		return
	if session.state.get("status") == "WON":
		first_clear = bool(result.get("first_clear", false))
	hint_id = ""
	busy = true
	if not board.reduced_motion:
		_begin_travel(screw_id, result.get("events", []))
	audio_service.play("tap")
	var released: bool = false
	var completed: bool = false
	for event in result.get("events", []):
		released = released or event.get("type") == "PlateCleared"
		completed = completed or event.get("type") == "BoxCompleted"
	if completed:
		audio_service.play("complete")
	elif released:
		audio_service.play("release")
	if bool(session.profile.get("settings", {}).get("haptics", true)) and OS.has_feature("mobile"):
		Input.vibrate_handheld(18)
	_sync_board()
	_rebuild_controls()
	var captured: int = generation
	await get_tree().create_timer(0.12 if board.reduced_motion else 0.40).timeout
	if captured != generation:
		return
	busy = false
	if session.state.get("status") == "WON":
		modal = "won"
		audio_service.play("win")
	elif session.state.get("status") == "STUCK":
		modal = "stuck"
	elif session.state.get("status") == "CONTENT_ERROR":
		_toast("This puzzle needs a content repair. Choose another level.", 10.0)
	elif session.state.get("buffer_screw_ids", []).size() == 5:
		_toast("Buffer full. Ready box matches still work.", 5.0)
	if not session.last_save_ok:
		_toast("Progress could not be saved. Please keep this game open.", 10.0)
	_sync_board()
	_rebuild_controls()


func _undo() -> void:
	if session.undo():
		generation += 1
		busy = false
		travel.clear()
		modal = ""
		hint_id = ""
		audio_service.play("undo")
		_sync_board(true)
		_rebuild_controls()
		_toast("One whole move restored")
	else:
		_toast("No moves to undo yet")


func _restart() -> void:
	generation += 1
	busy = false
	travel.clear()
	modal = ""
	inspection = false
	hint_id = ""
	session.restart()
	_sync_board(true)
	_rebuild_controls()


func _hint() -> void:
	if busy:
		return
	var result: Dictionary = session.hint()
	if result.get("outcome") == "SOLVED" and not result.get("solution", []).is_empty():
		hint_id = str(result.solution[0])
		board.set_hint(hint_id)
		_toast("Try the glowing screw — a winning route starts here.", 6.0)
	elif result.get("outcome") == "UNSOLVABLE":
		_toast("An earlier move needs undoing. You can always start again.", 6.0)
	else:
		_toast("Hint unavailable right now. Blueprint and Undo are free.", 5.0)


func _start_level(index: int) -> void:
	generation += 1
	busy = false
	travel.clear()
	modal = ""
	inspection = false
	hint_id = ""
	message = ""
	first_clear = false
	screen = "game"
	# Choosing a level starts a fresh attempt. The workshop's Continue action
	# resumes the committed in-memory attempt, and launch restores from disk.
	session.start_level(clampi(index, 1, catalogue.size()), false)
	_sync_board(true)
	if session.state.get("status") == "WON":
		modal = "won"
	_rebuild_controls()


func _navigate(destination: String) -> void:
	generation += 1
	busy = false
	travel.clear()
	modal = ""
	inspection = false
	hint_id = ""
	screen = destination
	_reconcile_terminal_modal()
	session.save()
	_sync_board(true)
	_rebuild_controls()


func _open_modal(value: String) -> void:
	# Navigation cancels a presentation timer, never the already committed move.
	generation += 1
	busy = false
	travel.clear()
	modal = value
	if value.is_empty():
		_reconcile_terminal_modal()
	queue_page = 0
	_sync_board(true)
	_rebuild_controls()


func _reconcile_terminal_modal() -> void:
	if screen != "game" or not modal.is_empty() or inspection:
		return
	if session.state.get("status") == "WON":
		modal = "won"
	elif session.state.get("status") == "STUCK":
		modal = "stuck"


func _set_inspection(enabled: bool) -> void:
	generation += 1
	busy = false
	travel.clear()
	inspection = enabled
	modal = ""
	_reconcile_terminal_modal()
	_sync_board(true)
	_rebuild_controls()


func _begin_travel(screw_id: String, events: Array) -> void:
	var source: Vector2 = Vector2.ZERO
	for screw in session.level.get("screws", []):
		if str(screw.id) == screw_id:
			source = Vector2(float(screw.position[0]), float(screw.position[1])) + board.position
	for event in events:
		if event.get("type") == "ScrewRouted" and event.get("screw_id") == screw_id:
			var slot: int = int(event.get("slot_index", 0))
			var target := Vector2(142 + slot * 222, 272)
			if event.get("destination") == "buffer":
				target = Vector2(216 + slot * 96, 388)
			travel = {"from": source, "to": target, "color": _color_of(screw_id)}
			travel_time = 0.0
			return


func _toggle_setting(key: String) -> void:
	var next_value: bool = not bool(session.profile.get("settings", {}).get(key, false))
	session.set_setting(key, next_value)
	_apply_settings()
	_rebuild_controls()


func _purchase(skin_id: String) -> void:
	if session.profile.get("owned_skins", []).has(skin_id):
		session.profile["skin"] = skin_id
		session.save()
	elif not session.purchase_skin(skin_id):
		_toast("Collect 100 coins by completing five new puzzles.", 5.0)
		return
	else:
		session.profile["skin"] = skin_id
		session.save()
	_apply_settings()
	_rebuild_controls()
	_toast("Your workshop has a new finish")


func _toast(value: String, duration: float = 3.5) -> void:
	message = value
	message_expiry = Time.get_ticks_msec() / 1000.0 + duration
	stage.queue_redraw()


func _rebuild_controls() -> void:
	for child in controls.get_children():
		controls.remove_child(child)
		child.queue_free()
	if not modal.is_empty():
		var blocker := Control.new()
		blocker.size = Vector2(720, 1280)
		blocker.mouse_filter = Control.MOUSE_FILTER_STOP
		controls.add_child(blocker)
		_build_modal_controls()
	else:
		match screen:
			"game": _build_game_controls()
			"home": _build_home_controls()
			"levels": _build_level_controls()
			"album": _build_album_controls()
			"shop": _build_shop_controls()
	stage.queue_redraw()
	overlay.queue_redraw()


func _button(label: String, rect: Rect2, callback: Callable, style: String = "light", disabled: bool = false, font_size: int = 22) -> Button:
	var button := Button.new()
	button.text = label
	button.position = rect.position
	button.size = rect.size
	button.disabled = disabled
	button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	button.add_theme_font_override("font", BOLD)
	button.add_theme_font_size_override("font_size", font_size)
	var fill: Color = GREEN if style == "primary" else Color("fffef9")
	if style == "quiet":
		fill = PALE
	if style == "clear":
		fill = Color(0, 0, 0, 0)
	for state_name in ["normal", "hover", "pressed", "disabled", "focus"]:
		var box := StyleBoxFlat.new()
		box.bg_color = fill
		box.corner_radius_top_left = 18
		box.corner_radius_top_right = 18
		box.corner_radius_bottom_left = 18
		box.corner_radius_bottom_right = 18
		box.border_color = LINE if style != "primary" else GREEN
		if state_name == "hover":
			box.bg_color = fill.lightened(0.055) if style == "primary" else Color("edf0e4")
		if state_name == "pressed":
			box.bg_color = fill.darkened(0.08)
		if state_name == "disabled":
			box.bg_color = Color("eeeee6")
		if state_name == "focus":
			box.bg_color = Color.TRANSPARENT
			box.border_color = GOLD
			box.set_border_width_all(3)
		elif style != "clear":
			box.set_border_width_all(1)
		button.add_theme_stylebox_override(state_name, box)
	button.add_theme_color_override("font_color", Color("fffdf4") if style == "primary" else INK)
	button.add_theme_color_override("font_hover_color", Color("fffdf4") if style == "primary" else INK)
	button.add_theme_color_override("font_pressed_color", Color("fffdf4") if style == "primary" else INK)
	button.add_theme_color_override("font_disabled_color", MUTED.lightened(0.28))
	button.pressed.connect(callback)
	controls.add_child(button)
	return button


func _icon_button(kind: String, rect: Rect2, callback: Callable, tip: String) -> Button:
	# Preserve a compact icon while giving it a 48dp hit area on 360dp phones.
	var touch_rect: Rect2 = rect.grow(20)
	var button: Button = _button("", touch_rect, callback, "clear")
	button.tooltip_text = tip
	button.name = tip.replace(" ", "")
	button.draw.connect(func():
		Craft.rounded(button, Rect2(Vector2(20, 20), rect.size), PALE, 18)
		Craft.icon(button, touch_rect.size * 0.5, kind, 25.0, GREEN))
	return button


func _build_game_controls() -> void:
	_icon_button("home", Rect2(40, 35, 56, 56), func(): _navigate("home"), "Workshop home")
	_icon_button("settings", Rect2(624, 35, 56, 56), func(): _open_modal("settings"), "Settings")
	_button("View queue  ›", Rect2(480, 272, 194, 96), func(): _open_modal("queue"), "clear", false, 17)
	if inspection:
		_button("Back to puzzle", Rect2(160, 1106, 400, 96), _set_inspection.bind(false), "primary")
	else:
		_tool_button("undo", "Undo", Rect2(40, 1106, 202, 96), _undo, session.history.is_empty() or session.state.get("status") == "WON")
		_tool_button("hint", "Hint", Rect2(259, 1106, 202, 96), _hint, busy or session.state.get("status") == "WON")
		_tool_button("blueprint", "Blueprint", Rect2(478, 1106, 202, 96), _set_inspection.bind(true))


func _tool_button(kind: String, label: String, rect: Rect2, action: Callable, disabled: bool = false) -> void:
	var button: Button = _button("      " + label, rect, action, "light", disabled, 20)
	button.name = label
	button.draw.connect(func(): Craft.icon(button, Vector2(38, rect.size.y * 0.5), kind, 24.0, MUTED if disabled else GREEN))


func _build_home_controls() -> void:
	_icon_button("settings", Rect2(624, 35, 56, 56), func(): _open_modal("settings"), "Settings")
	_button("Continue your craft   ›", Rect2(80, 817, 560, 78), func(): _navigate("game"), "primary", false, 25)
	_button("Explore 1,000 puzzles", Rect2(80, 912, 560, 68), func(): level_page = int((int(session.profile.get("current_level", 1)) - 1) / 25); _navigate("levels"))
	_button("My collection", Rect2(80, 1000, 270, 68), func(): _navigate("album"))
	_button("Wood finishes", Rect2(370, 1000, 270, 68), func(): _navigate("shop"))
	_button("How to play", Rect2(250, 1120, 220, 44), func(): _open_modal("help"), "clear", false, 19)


func _back_button() -> void:
	_button("‹  Workshop", Rect2(40, 35, 185, 52), func(): _navigate("home"), "quiet", false, 19)


func _build_level_controls() -> void:
	_back_button()
	for i in range(25):
		var index: int = level_page * 25 + i + 1
		if index > catalogue.size():
			break
		var x: float = 40 + (i % 5) * 132
		var y: float = 268 + (i / 5) * 139
		var complete: bool = session.profile.get("completed_levels", []).has("campaign_%04d" % index)
		var label: String = "%02d" % index
		if complete:
			label += "  ✓"
		_button(label, Rect2(x, y, 112, 109), _start_level.bind(index), "quiet" if complete else "light", false, 26)
	_button("‹  Previous", Rect2(40, 1010, 190, 64), func(): level_page = maxi(0, level_page - 1); _rebuild_controls(), "quiet", level_page == 0, 19)
	_button("Next  ›", Rect2(490, 1010, 190, 64), func(): level_page = mini(39, level_page + 1); _rebuild_controls(), "quiet", (level_page + 1) * 25 >= catalogue.size(), 19)
	_button("First", Rect2(250, 1110, 95, 48), func(): level_page = 0; _rebuild_controls(), "clear", false, 18)
	_button("Last", Rect2(375, 1110, 95, 48), func(): level_page = int((catalogue.size() - 1) / 25); _rebuild_controls(), "clear", false, 18)


func _build_album_controls() -> void:
	_back_button()
	_button("‹", Rect2(40, 1090, 95, 64), func(): album_page = maxi(0, album_page - 1); _rebuild_controls(), "quiet", album_page == 0, 28)
	_button("›", Rect2(585, 1090, 95, 64), func(): album_page = mini(24, album_page + 1); _rebuild_controls(), "quiet", album_page == 24, 28)


func _build_shop_controls() -> void:
	_back_button()
	var skins: Array = ["beech", "walnut", "rose", "sage"]
	for i in range(4):
		var skin_id: String = skins[i]
		var owned: bool = session.profile.get("owned_skins", []).has(skin_id)
		var selected: bool = session.profile.get("skin", "beech") == skin_id
		_button("In use" if selected else ("Use finish" if owned else "100 coins"), Rect2(414, 291 + i * 185, 225, 61), _purchase.bind(skin_id), "quiet" if selected else "primary", selected, 20)


func _build_modal_controls() -> void:
	match modal:
		"settings":
			_button("×", Rect2(588, 210, 50, 50), func(): _open_modal(""), "clear", false, 30)
			var keys: Array = ["sound", "music", "haptics", "reduced_motion"]
			for i in range(keys.size()):
				var key: String = keys[i]
				var enabled: bool = bool(session.profile.get("settings", {}).get(key, false))
				_button("On" if enabled else "Off", Rect2(500, 368 + 91 * i, 120, 56), _toggle_setting.bind(key), "primary" if enabled else "quiet", false, 20)
			_button("How to play", Rect2(100, 780, 520, 62), func(): _open_modal("help"))
			_button("Restart this puzzle", Rect2(100, 858, 520, 62), func(): _open_modal("restart"), "quiet")
			_button("Back to crafting", Rect2(100, 959, 520, 70), func(): _open_modal(""), "primary")
		"help":
			_button("Let's craft", Rect2(110, 980, 500, 72), func(): _open_modal(""), "primary")
		"queue":
			_button("Back to puzzle", Rect2(110, 994, 500, 68), func(): _open_modal(""), "primary")
			var left: int = session.level.get("boxes_in_activation_order", []).size() - int(session.state.get("next_queue_index", 2))
			if left > 10:
				_button("‹", Rect2(115, 915, 85, 52), func(): queue_page = maxi(0, queue_page - 1); _rebuild_controls(), "quiet", queue_page == 0)
				_button("›", Rect2(520, 915, 85, 52), func(): queue_page += 1; _rebuild_controls(), "quiet", (queue_page + 1) * 10 >= left)
		"stuck":
			_button("Undo last move", Rect2(110, 725, 500, 74), _undo, "primary", session.history.is_empty())
			_button("Start this puzzle again", Rect2(110, 817, 500, 64), _restart, "quiet")
			_button("Inspect the board", Rect2(190, 909, 340, 48), _set_inspection.bind(true), "clear", false, 18)
		"restart":
			_button("Start again", Rect2(110, 724, 500, 74), _restart, "primary")
			_button("Keep crafting", Rect2(110, 818, 500, 64), func(): _open_modal(""), "quiet")
		"won":
			var next: int = int(session.level.get("index", 1)) + 1
			_button("Next little masterpiece   ›" if next <= catalogue.size() else "Explore your collection", Rect2(94, 855, 532, 76), _start_level.bind(next) if next <= catalogue.size() else _navigate.bind("album"), "primary", false, 23)
			_button("My collection", Rect2(195, 955, 330, 54), func(): _navigate("album"), "clear", false, 20)


func _draw_stage() -> void:
	stage.draw_rect(Rect2(0, 0, 720, 1280), PAPER)
	# Small, deterministic paper flecks provide warmth without distracting from targets.
	for i in range(160):
		stage.draw_circle(Vector2(fmod(i * 137.31, 720), fmod(i * 83.71, 1280)), 0.65, Color(0.35, 0.38, 0.29, 0.035))
	if session == null:
		return
	match screen:
		"game": _draw_game()
		"home": _draw_home()
		"levels": _draw_levels()
		"album": _draw_album()
		"shop": _draw_shop()
	if not message.is_empty() and screen != "game":
		_round(stage, Rect2(40, 1185, 640, 58), INK, 18)
		_text(stage, message, Vector2(56, 1222), 17, PAPER, 608, HORIZONTAL_ALIGNMENT_CENTER)


func _text(canvas: CanvasItem, value: String, at: Vector2, size_px: int = 22, color: Color = INK, width: float = -1.0, alignment: HorizontalAlignment = HORIZONTAL_ALIGNMENT_LEFT, serif: bool = false, bold: bool = false) -> void:
	canvas.draw_string(SERIF if serif else (BOLD if bold else SANS), at, value, alignment, width, size_px, color)


func _round(canvas: CanvasItem, rect: Rect2, color: Color, radius: int = 20, border: Color = Color.TRANSPARENT) -> void:
	var style := StyleBoxFlat.new()
	style.bg_color = color
	style.corner_radius_top_left = radius
	style.corner_radius_top_right = radius
	style.corner_radius_bottom_left = radius
	style.corner_radius_bottom_right = radius
	style.border_color = border
	style.set_border_width_all(1 if border.a > 0 else 0)
	canvas.draw_style_box(style, rect)


func _line(canvas: CanvasItem, from: Vector2, to: Vector2, color: Color = LINE) -> void:
	canvas.draw_line(from, to, color, 1.0, true)


func _paragraph(canvas: CanvasItem, value: String, at: Vector2, width: float, size_px: int = 21, color: Color = MUTED, line_height: float = 33.0, centered: bool = false) -> float:
	var lines: Array[String] = []
	var current: String = ""
	for word in value.split(" "):
		if SANS.get_string_size(current + " " + word, HORIZONTAL_ALIGNMENT_LEFT, -1, size_px).x > width and not current.is_empty():
			lines.append(current)
			current = word
		else:
			current += (" " if not current.is_empty() else "") + word
	lines.append(current)
	for i in range(lines.size()):
		_text(canvas, lines[i], at + Vector2(0, i * line_height), size_px, color, width, HORIZONTAL_ALIGNMENT_CENTER if centered else HORIZONTAL_ALIGNMENT_LEFT)
	return lines.size() * line_height


func _brand(canvas: CanvasItem, y: float = 70) -> void:
	_text(canvas, "S C R E W C R A F T", Vector2(130, y), 21, GREEN, 460, HORIZONTAL_ALIGNMENT_CENTER, false, true)


func _draw_game() -> void:
	_brand(stage)
	var index: int = int(session.level.get("index", 1))
	_text(stage, "Level %02d" % index, Vector2(40, 143), 43, INK, -1, HORIZONTAL_ALIGNMENT_LEFT, true)
	_text(stage, str(session.level.get("name", "Little beginnings")), Vector2(265, 137), 20, MUTED, 415, HORIZONTAL_ALIGNMENT_RIGHT)
	_text(stage, "ACTIVE ORDERS", Vector2(42, 177), 15, MUTED, -1, HORIZONTAL_ALIGNMENT_LEFT, false, true)
	_text(stage, "UP NEXT", Vector2(484, 177), 15, MUTED, 192, HORIZONTAL_ALIGNMENT_CENTER, false, true)
	var boxes: Array = session.state.get("active_box_slots", [])
	for i in range(2):
		_draw_box(stage, Rect2(40 + i * 222, 191, 204, 119), boxes[i] if boxes.size() > i else null)
	var queue: Array = session.level.get("boxes_in_activation_order", [])
	var cursor: int = int(session.state.get("next_queue_index", 2))
	for i in range(2):
		var rect := Rect2(485 + i * 100, 193, 93, 103)
		_round(stage, rect, Color("f0f1e7"), 18, LINE)
		if cursor + i < queue.size():
			var color_id: String = str(queue[cursor + i].color_id)
			Craft.symbol(stage, rect.position + Vector2(46, 40), color_id, 13.0, Craft.color_for(color_id))
			_text(stage, color_id.capitalize(), rect.position + Vector2(0, 79), 17, INK, rect.size.x, HORIZONTAL_ALIGNMENT_CENTER, false, true)
		else:
			_text(stage, "—", rect.position + Vector2(0, 62), 24, MUTED, rect.size.x, HORIZONTAL_ALIGNMENT_CENTER)
	_round(stage, Rect2(40, 349, 640, 77), Color("e9ecdf"), 22)
	_text(stage, "BUFFER", Vector2(63, 379), 13, MUTED, -1, HORIZONTAL_ALIGNMENT_LEFT, false, true)
	var buffer: Array = session.state.get("buffer_screw_ids", [])
	_text(stage, "%d / 5" % buffer.size(), Vector2(65, 405), 18, GREEN, -1, HORIZONTAL_ALIGNMENT_LEFT, false, true)
	for i in range(5):
		var center := Vector2(216 + i * 96, 388)
		stage.draw_circle(center + Vector2(0, 2), 28, Color("d5d9c9"))
		stage.draw_circle(center, 25, Color("c4cbba"))
		stage.draw_arc(center, 24, PI, TAU, 24, Color("aeb7a4"), 2, true)
		if i < buffer.size():
			Craft.screw(stage, center, _color_of(str(buffer[i])), 24.0)
	var caption: String = message
	if caption.is_empty():
		caption = "BLUEPRINT · Read-only layer inspection" if inspection else str(session.level.get("lesson", "Match a screw. Make a little room."))
		if not inspection and index == 1:
			caption = "Tap a colored screw. Match three to pack a box."
		elif not inspection and index == 2:
			caption = "Clear the front piece to reveal the screws beneath."
		elif not inspection and index == 3:
			caption = "Green waits in the buffer until its box arrives."
	_paragraph(stage, caption, Vector2(46, 1068), 628, 16, GREEN if not message.is_empty() else MUTED, 22, true)
	_text(stage, "TAKE YOUR TIME. MAKE SOMETHING LOVELY.", Vector2(40, 1230), 13, MUTED, 640, HORIZONTAL_ALIGNMENT_CENTER)
	_line(stage, Vector2(292, 1250), Vector2(428, 1250), Color("ced4c5"))


func _color_of(id: String) -> String:
	for screw in session.level.get("screws", []):
		if str(screw.id) == id:
			return str(screw.color_id)
	return "red"


func _draw_box(canvas: CanvasItem, rect: Rect2, value: Variant) -> void:
	_round(canvas, rect.grow_individual(0, 4, 0, 4), Color("daddcf"), 20)
	_round(canvas, rect, Color("fffdf4"), 20, LINE)
	if value == null:
		_text(canvas, "All packed", rect.position + Vector2(0, 67), 21, MUTED, rect.size.x, HORIZONTAL_ALIGNMENT_CENTER, true)
		return
	var color_id: String = str(value.get("color_id", "red"))
	var color: Color = Craft.color_for(color_id)
	_round(canvas, Rect2(rect.position, Vector2(rect.size.x, 43)), color, 19)
	canvas.draw_rect(Rect2(rect.position + Vector2(1, 23), Vector2(rect.size.x - 2, 20)), color)
	var fill: int = value.get("screw_ids", []).size()
	_text(canvas, "%s  %d/3" % [color_id.capitalize(), fill], rect.position + Vector2(0, 30), 21, INK if color_id == "yellow" else Color("fffaf0"), rect.size.x, HORIZONTAL_ALIGNMENT_CENTER, false, true)
	for j in range(3):
		var center: Vector2 = rect.position + Vector2(41 + j * 61, 81)
		canvas.draw_circle(center + Vector2(0, 2), 22, Color("ececdf"))
		canvas.draw_circle(center, 19, Color("c7ccbd"))
		if j < fill:
			Craft.screw(canvas, center, color_id, 22.0)


func _draw_home() -> void:
	_brand(stage, 76)
	_text(stage, "A little pause.", Vector2(40, 196), 63, INK, 640, HORIZONTAL_ALIGNMENT_CENTER, true)
	_text(stage, "A clever little puzzle.", Vector2(40, 263), 53, INK, 640, HORIZONTAL_ALIGNMENT_CENTER, true)
	_text(stage, "Unwind, one screw at a time.", Vector2(40, 320), 22, MUTED, 640, HORIZONTAL_ALIGNMENT_CENTER)
	_round(stage, Rect2(80, 366, 560, 371), Color("e8dec8"), 145)
	_draw_keepsake(stage, Vector2(360, 543), 1.75, "flower", true)
	_round(stage, Rect2(208, 706, 304, 46), Color("fffdf7"), 23, LINE)
	_text(stage, "YOUR POCKET WORKSHOP", Vector2(208, 736), 14, GREEN, 304, HORIZONTAL_ALIGNMENT_CENTER, false, true)
	_text(stage, "%d keepsakes made  ·  %d coins" % [session.profile.get("completed_levels", []).size(), int(session.profile.get("coins", 0))], Vector2(40, 792), 19, MUTED, 640, HORIZONTAL_ALIGNMENT_CENTER)
	_text(stage, "1,000 puzzles. Free tools. All yours.", Vector2(40, 1220), 17, MUTED, 640, HORIZONTAL_ALIGNMENT_CENTER)


func _page_heading(title: String, subtitle: String) -> void:
	_text(stage, title, Vector2(40, 160), 53, INK, -1, HORIZONTAL_ALIGNMENT_LEFT, true)
	_text(stage, subtitle, Vector2(42, 204), 20, MUTED)
	_line(stage, Vector2(40, 230), Vector2(680, 230))


func _draw_levels() -> void:
	_page_heading("The puzzle shelf", "1,000 small moments of discovery. Pick any puzzle.")
	for i in range(25):
		var index: int = level_page * 25 + i + 1
		if index > catalogue.size():
			break
		var x: float = 40 + (i % 5) * 132
		var y: float = 268 + (i / 5) * 139
		var meta: Dictionary = catalogue[index - 1]
		var difficulty: String = str(meta.get("difficulty", "gentle")).capitalize()
		_text(stage, difficulty, Vector2(x, y + 130), 13, MUTED, 112, HORIZONTAL_ALIGNMENT_CENTER)
	_text(stage, "%02d / %02d" % [level_page + 1, ceili(catalogue.size() / 25.0)], Vector2(240, 1051), 23, GREEN, 240, HORIZONTAL_ALIGNMENT_CENTER)
	_text(stage, "Every puzzle has a verified solution. Every tool is free.", Vector2(40, 1230), 16, MUTED, 640, HORIZONTAL_ALIGNMENT_CENTER)


func _draw_album() -> void:
	_page_heading("Little things, collected", "Five puzzles make a chapter. A workshop full of stories.")
	var names: Array = ["Garden moments", "By the water", "Little aviary", "Wind & wonder", "Tea for two", "Home sweet home", "Woodland walk", "Playful things"]
	var families: Array = ["flower", "boat", "bird", "windmill", "teapot", "house", "leaf", "kite"]
	for i in range(8):
		var group: int = album_page * 8 + i
		var rect := Rect2(40 + (i % 2) * 330, 263 + (i / 2) * 199, 310, 181)
		var count: int = 0
		for j in range(5):
			if session.profile.get("completed_levels", []).has("campaign_%04d" % (group * 5 + j + 1)):
				count += 1
		_round(stage, rect, Color("ecebdc") if count < 5 else Color("e1ead7"), 24, LINE)
		_draw_keepsake(stage, rect.position + Vector2(62, 68), 0.48, families[group % 8], count == 5)
		_text(stage, names[group % 8], rect.position + Vector2(115, 60), 21, INK, -1, HORIZONTAL_ALIGNMENT_LEFT, true)
		_text(stage, "Chapter %d" % (group + 1), rect.position + Vector2(115, 91), 15, MUTED)
		for j in range(5):
			stage.draw_circle(rect.position + Vector2(71 + j * 42, 144), 9, GREEN if j < count else Color("cfd5c7"))
	_text(stage, "CHAPTERS %d–%d OF 200" % [album_page * 8 + 1, album_page * 8 + 8], Vector2(140, 1130), 18, MUTED, 440, HORIZONTAL_ALIGNMENT_CENTER)


func _draw_shop() -> void:
	_page_heading("A finish of your own", "Cosmetic touches, earned through little achievements.")
	_text(stage, "%d coins" % int(session.profile.get("coins", 0)), Vector2(440, 72), 22, GOLD, 230, HORIZONTAL_ALIGNMENT_RIGHT, false, true)
	var labels: Array = ["Natural beech", "Warm walnut", "Rosewood blush", "Sage workshop"]
	var colors: Array = [Color("e0bf86"), Color("86604a"), Color("c48d81"), Color("97ab8b")]
	for i in range(4):
		var y: float = 261 + i * 185
		_round(stage, Rect2(40, y, 640, 150), Color("fffdf7"), 24, LINE)
		_round(stage, Rect2(63, y + 24, 126, 102), colors[i], 25)
		for j in range(4):
			stage.draw_line(Vector2(78, y + 41 + j * 19), Vector2(170, y + 44 + j * 19), colors[i].darkened(0.1), 1.0, true)
		Craft.screw(stage, Vector2(125, y + 76), ["red", "yellow", "blue", "green"][i], 24.0)
		_text(stage, labels[i], Vector2(211, y + 55), 23, INK, -1, HORIZONTAL_ALIGNMENT_LEFT, true)
		_text(stage, "A new board mood", Vector2(211, y + 90), 15, MUTED)
	_text(stage, "20 coins for each first clear. No purchases, ever required.", Vector2(40, 1086), 18, MUTED, 640, HORIZONTAL_ALIGNMENT_CENTER)
	_text(stage, "Same clear colors. Same clever puzzles.", Vector2(40, 1130), 18, MUTED, 640, HORIZONTAL_ALIGNMENT_CENTER)


func _draw_keepsake(canvas: CanvasItem, center: Vector2, zoom: float, family: String, earned: bool) -> void:
	var wood: Color = Color("d1aa6c") if earned else Color("ccd0be")
	var light: Color = Color("edcf94") if earned else Color("d8dbc9")
	canvas.draw_set_transform(center, 0, Vector2.ONE * zoom)
	if family not in ["flower", "leaf", "house", "teapot", "sailboat", "boat"]:
		canvas.draw_circle(Vector2(2, 4), 91, wood.darkened(0.15))
		canvas.draw_circle(Vector2.ZERO, 91, light)
		canvas.draw_arc(Vector2.ZERO, 83, 0, TAU, 70, wood, 2, true)
		Craft.motif(canvas, Vector2.ZERO, family, 65, GREEN if earned else wood.darkened(0.2))
	elif family in ["flower", "leaf"]:
		_round(canvas, Rect2(-9, 0, 18, 98), Color("809875") if earned else wood, 9)
		for i in range(5 if family == "flower" else 4):
			var a: float = i * TAU / (5.0 if family == "flower" else 4.0) - PI * 0.5
			var p := Vector2(cos(a), sin(a)) * 45
			canvas.draw_circle(p + Vector2(2, 5), 34, wood.darkened(0.12))
			canvas.draw_circle(p, 34, light if i % 2 == 0 else wood)
			canvas.draw_arc(p, 29, PI, TAU, 20, Color(1, 1, 0.9, 0.35), 2, true)
		Craft.screw(canvas, Vector2.ZERO, "yellow" if earned else "green", 24.0)
	elif family in ["house", "teapot"]:
		_round(canvas, Rect2(-55, -18, 110, 92), light, 18)
		canvas.draw_colored_polygon(PackedVector2Array([Vector2(-70, -14), Vector2(0, -79), Vector2(70, -14)]), wood)
		_round(canvas, Rect2(-13, 30, 26, 44), wood.darkened(0.17), 7)
		Craft.screw(canvas, Vector2(0, -29), "red", 17.0)
	else:
		canvas.draw_colored_polygon(PackedVector2Array([Vector2(-83, 20), Vector2(78, 20), Vector2(46, 62), Vector2(-45, 62)]), wood)
		canvas.draw_colored_polygon(PackedVector2Array([Vector2(-8, 10), Vector2(-8, -91), Vector2(70, 10)]), light)
		_round(canvas, Rect2(-16, -89, 11, 115), wood.darkened(0.1), 5)
		Craft.screw(canvas, Vector2(-9, 31), "blue", 19.0)
	canvas.draw_set_transform(Vector2.ZERO)


func _draw_overlay() -> void:
	if not travel.is_empty() and modal.is_empty():
		var progress: float = clampf(travel_time / 0.36, 0.0, 1.0)
		var eased: float = smoothstep(0.06, 1.0, progress)
		var start: Vector2 = travel["from"]
		var end: Vector2 = travel["to"]
		var at: Vector2 = start.lerp(end, eased) + Vector2(sin(progress * PI) * 25, -sin(progress * PI) * 58)
		Craft.screw(overlay, at, str(travel.color), 24.0 + sin(progress * PI) * 5.0, 1.0, progress * TAU)
	if modal.is_empty() or session == null:
		return
	overlay.draw_rect(Rect2(0, 0, 720, 1280), Color(0.13, 0.2, 0.15, 0.45))
	var card := Rect2(70, 195, 580, 890)
	if modal in ["stuck", "restart"]:
		card = Rect2(70, 325, 580, 660)
	_round(overlay, card.grow_individual(0, 6, 0, 5), Color(0.12, 0.18, 0.13, 0.15), 34)
	_round(overlay, card, PAPER, 32)
	match modal:
		"settings": _draw_settings()
		"help": _draw_help()
		"queue": _draw_queue()
		"stuck":
			Craft.icon(overlay, Vector2(360, 423), "undo", 48.0, GREEN)
			_text(overlay, "A little room to rethink", Vector2(95, 516), 37, INK, 530, HORIZONTAL_ALIGNMENT_CENTER, true)
			_paragraph(overlay, "No moves are available. Undo a move to make room, or begin this same puzzle again.", Vector2(127, 579), 466, 23, MUTED, 35, true)
		"restart":
			Craft.icon(overlay, Vector2(360, 429), "undo", 44.0, GREEN)
			_text(overlay, "A fresh beginning?", Vector2(95, 523), 42, INK, 530, HORIZONTAL_ALIGNMENT_CENTER, true)
			_paragraph(overlay, "This puzzle will return to its starting arrangement. Your collection and coins stay safe.", Vector2(125, 586), 470, 22, MUTED, 35, true)
		"won": _draw_won()


func _draw_settings() -> void:
	_text(overlay, "Make yourself at home", Vector2(100, 282), 37, INK, -1, HORIZONTAL_ALIGNMENT_LEFT, true)
	_text(overlay, "YOUR WORKSHOP, YOUR PACE", Vector2(102, 324), 14, MUTED)
	var labels: Array = ["Sound effects", "Quiet music", "Gentle vibration", "Reduced motion"]
	for i in range(labels.size()):
		_text(overlay, labels[i], Vector2(104, 405 + 91 * i), 24, INK)
		_line(overlay, Vector2(100, 447 + 91 * i), Vector2(620, 447 + 91 * i))
	_text(overlay, "Color symbols are always on.", Vector2(100, 752), 18, MUTED)


func _draw_help() -> void:
	_text(overlay, "A few little things", Vector2(100, 289), 44, INK, 520, HORIZONTAL_ALIGNMENT_CENTER, true)
	_text(overlay, "THEN IT'S ALL YOURS", Vector2(100, 335), 14, MUTED, 520, HORIZONTAL_ALIGNMENT_CENTER)
	var headings: Array = ["Match three. Pack a box.", "Make room for what's next.", "Lift a layer. Find a way.", "Take all the time you need."]
	var copy: Array = ["Tap an exposed screw. It goes straight to a matching active box.", "Other colors wait in five buffer spaces, then move when their box arrives.", "Remove every screw from a piece to reveal the layer underneath.", "Undo, Hint and Blueprint are always free. A full buffer still allows direct matches."]
	for i in range(4):
		var y: float = 407 + i * 136
		overlay.draw_circle(Vector2(127, y), 21, PALE)
		_text(overlay, str(i + 1), Vector2(107, y + 7), 22, GREEN, 40, HORIZONTAL_ALIGNMENT_CENTER, false, true)
		_text(overlay, headings[i], Vector2(165, y + 7), 24, INK, -1, HORIZONTAL_ALIGNMENT_LEFT, true)
		_paragraph(overlay, copy[i], Vector2(165, y + 41), 425, 19, MUTED, 28)


func _draw_queue() -> void:
	_text(overlay, "A peek ahead", Vector2(100, 274), 43, INK, 520, HORIZONTAL_ALIGNMENT_CENTER, true)
	_text(overlay, "The order is fixed. Plan at your own pace.", Vector2(100, 315), 18, MUTED, 520, HORIZONTAL_ALIGNMENT_CENTER)
	var boxes: Array = session.state.get("active_box_slots", [])
	for i in range(2):
		_draw_box(overlay, Rect2(120 + i * 249, 346, 231, 119), boxes[i] if i < boxes.size() else null)
	_text(overlay, "COMING NEXT", Vector2(120, 510), 14, MUTED, -1, HORIZONTAL_ALIGNMENT_LEFT, false, true)
	var queue: Array = session.level.get("boxes_in_activation_order", [])
	var cursor: int = int(session.state.get("next_queue_index", 2))
	var remaining: int = queue.size() - cursor
	if remaining <= 0:
		_paragraph(overlay, "These are your final boxes. Every little piece has a place.", Vector2(150, 637), 420, 25, MUTED, 40, true)
	for i in range(mini(10, remaining - queue_page * 10)):
		var j: int = cursor + queue_page * 10 + i
		var x: float = 120 + (i % 2) * 250
		var y: float = 536 + (i / 2) * 72
		_round(overlay, Rect2(x, y, 230, 58), PALE, 16)
		var color_id: String = str(queue[j].color_id)
		Craft.symbol(overlay, Vector2(x + 34, y + 28), color_id, 12.0, Craft.color_for(color_id))
		_text(overlay, "%d. %s" % [j - cursor + 1, color_id.capitalize()], Vector2(x + 60, y + 37), 19, INK)


func _draw_won() -> void:
	_text(overlay, "BEAUTIFULLY DONE", Vector2(100, 277), 16, GREEN, 520, HORIZONTAL_ALIGNMENT_CENTER, false, true)
	_round(overlay, Rect2(223, 324, 274, 274), Color("e8ecdd"), 137)
	_draw_keepsake(overlay, Vector2(360, 446), 1.13, str(session.level.get("family", "flower")), true)
	for i in range(12):
		var a: float = i * TAU / 12.0
		overlay.draw_circle(Vector2(360, 461) + Vector2(cos(a), sin(a)) * 164, 3.0 if i % 2 == 0 else 2.0, GOLD if i % 3 == 0 else Color("9caf8b"))
	_text(overlay, "A little masterpiece.", Vector2(92, 660), 45, INK, 536, HORIZONTAL_ALIGNMENT_CENTER, true)
	_text(overlay, str(session.level.get("name", "Craft complete")), Vector2(100, 703), 23, MUTED, 520, HORIZONTAL_ALIGNMENT_CENTER)
	_round(overlay, Rect2(233, 738, 254, 52), Color("f0e6cc"), 26)
	_text(overlay, "+20 first-clear coins" if first_clear else "Reward already collected", Vector2(223, 772), 18, Color("977238"), 274, HORIZONTAL_ALIGNMENT_CENTER, false, true)
	var group: int = int((int(session.level.get("index", 1)) - 1) / 5)
	var earned: int = 0
	for i in range(5):
		if session.profile.get("completed_levels", []).has("campaign_%04d" % (group * 5 + i + 1)):
			earned += 1
	_text(overlay, "%d of 5 keepsakes in this chapter" % earned, Vector2(100, 825), 18, MUTED, 520, HORIZONTAL_ALIGNMENT_CENTER)
