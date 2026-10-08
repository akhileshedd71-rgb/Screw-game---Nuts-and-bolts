extends Control
## Application shell. The session commits game state; this layer only presents it.

const Session = preload("res://scripts/session/game_session.gd")
const Repository = preload("res://scripts/data/level_repository.gd")
const Reducer = preload("res://scripts/core/puzzle_reducer.gd")
const Board = preload("res://scripts/ui/board_view.gd")
const Craft = preload("res://scripts/ui/craft_draw.gd")
const Audio = preload("res://scripts/services/audio_service.gd")
const World = preload("res://scripts/ui/world_screens.gd")
const SANS = preload("res://assets/fonts/Nunito-Regular.ttf")
const BOLD = preload("res://assets/fonts/Nunito-ExtraBold.ttf")
const SERIF = preload("res://assets/fonts/LilitaOne-Regular.ttf")
const PAPER = Color("eee8ff")
const INK = Color("36235f")
const MUTED = Color("75658e")
const GREEN = Color("8452db") # Legacy helper name; the world accent is now purple.
const PALE = Color("e4d8fb")
const LINE = Color("c4b0e6")
const GOLD = Color("ffce57")
const PINK = Color("ed4f9a")
const AQUA = Color("28c9d4")
const WHITE = Color("fff9ff")

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
var celebration_time: float = 9.0
var texture_cache: Dictionary = {}
var presented_hud: Dictionary = {}
var order_flash: float = 0.0


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
	if order_flash > 0.0:
		order_flash = maxf(0.0, order_flash - delta)
		stage.queue_redraw()
	if celebration_time < 2.4 and modal == "won":
		celebration_time += delta
		overlay.queue_redraw()
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
		presented_hud.clear()
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
	var before_state: Dictionary = session.state.duplicate(true)
	var result: Dictionary = session.select_screw(screw_id)
	if not result.get("accepted", false):
		var reason: String = str(result.get("rejection_reason", ""))
		_toast("Remove the piece above first" if reason == "COVERED" else "Buffer full. Match a ready box or Undo.")
		return
	if session.state.get("status") == "WON":
		first_clear = bool(result.get("first_clear", false))
	hint_id = ""
	busy = true
	presented_hud = before_state if not board.reduced_motion else {}
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
	presented_hud.clear()
	order_flash = 0.45 if completed and not board.reduced_motion else 0.0
	if session.state.get("status") == "WON":
		modal = "won"
		celebration_time = 0.0
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
	var fill: Color = {"primary": PINK, "aqua": AQUA, "yellow": GOLD, "quiet": PALE, "light": WHITE, "clear": Color.TRANSPARENT, "level": GREEN}.get(style, WHITE)
	var vivid: bool = style in ["primary", "level"]
	var radius: int = int(minf(rect.size.x, rect.size.y) * 0.5) if style == "level" else 26
	for state_name in ["normal", "hover", "pressed", "disabled", "focus"]:
		var box := StyleBoxFlat.new()
		box.bg_color = fill
		box.set_corner_radius_all(radius)
		box.border_color = fill.lightened(0.35)
		box.shadow_color = fill.darkened(0.31) if style != "clear" else Color.TRANSPARENT
		box.shadow_size = 2
		box.shadow_offset = Vector2(0, 7)
		box.content_margin_top = 0
		if state_name == "hover":
			box.bg_color = fill.lightened(0.08)
		if state_name == "pressed":
			box.bg_color = fill.darkened(0.04)
			box.shadow_offset = Vector2(0, 2)
			box.content_margin_top = 7
		if state_name == "disabled":
			box.bg_color = Color("d8d4e9")
			box.border_color = Color("eeeafa")
			box.shadow_color = Color("b9b3ce")
		if state_name == "focus":
			box.bg_color = Color.TRANSPARENT
			box.border_color = Color("6a369e")
			box.shadow_size = 0
			box.shadow_color = Color.TRANSPARENT
			box.set_border_width_all(2)
		elif style != "clear":
			box.set_border_width_all(2)
		else:
			box.shadow_size = 0
		button.add_theme_stylebox_override(state_name, box)
	button.add_theme_color_override("font_color", WHITE if vivid else INK)
	button.add_theme_color_override("font_hover_color", WHITE if vivid else INK)
	button.add_theme_color_override("font_pressed_color", WHITE if vivid else INK)
	button.add_theme_color_override("font_disabled_color", Color("978ba9"))
	button.pressed.connect(func():
		if is_instance_valid(audio_service): audio_service.play("click")
		callback.call())
	if style != "clear":
		button.draw.connect(func():
			var offset: float = 5.0 if button.button_pressed else 0.0
			_round(button, Rect2(15, 7 + offset, maxf(0, rect.size.x - 30), 8), Color(1, 1, 1, 0.26), 4))
	controls.add_child(button)
	return button


func _icon_button(kind: String, rect: Rect2, callback: Callable, tip: String) -> Button:
	# Preserve a compact icon while giving it a 48dp hit area on 360dp phones.
	var touch_rect: Rect2 = rect.grow(20)
	var button: Button = _button("", touch_rect, callback, "clear")
	button.tooltip_text = tip
	button.name = tip.replace(" ", "")
	button.draw.connect(func():
		Craft.rounded(button, Rect2(Vector2(20, 25), rect.size), Color("6431ab"), 20)
		Craft.rounded(button, Rect2(Vector2(20, 20), rect.size), GREEN, 20, Color("b18aee"), 2)
		Craft.icon(button, touch_rect.size * 0.5, kind, 24.0, WHITE))
	return button


func _build_game_controls() -> void:
	_icon_button("home", Rect2(40, 35, 56, 56), func(): _navigate("home"), "Workshop home")
	_icon_button("settings", Rect2(624, 35, 56, 56), func(): _open_modal("settings"), "Settings")
	_button("View queue  ›", Rect2(480, 272, 194, 96), func(): _open_modal("queue"), "clear", false, 19)
	if inspection:
		_button("Back to puzzle", Rect2(160, 1106, 400, 96), _set_inspection.bind(false), "primary")
	else:
		_tool_button("undo", "Undo", Rect2(40, 1106, 202, 96), _undo, session.history.is_empty() or session.state.get("status") == "WON")
		_tool_button("hint", "Hint", Rect2(259, 1106, 202, 96), _hint, busy or session.state.get("status") == "WON")
		_tool_button("blueprint", "Blueprint", Rect2(478, 1106, 202, 96), _set_inspection.bind(true))


func _tool_button(kind: String, label: String, rect: Rect2, action: Callable, disabled: bool = false) -> void:
	var button: Button = _button("      " + label, rect, action, {"undo": "aqua", "hint": "yellow", "blueprint": "light"}.get(kind, "light"), disabled, 22)
	button.name = label
	button.draw.connect(func(): Craft.icon(button, Vector2(38, rect.size.y * 0.5), kind, 25.0, MUTED if disabled else INK))


func _build_home_controls() -> void:
	World.build_home(self)


func _back_button() -> void:
	_button("‹  Workshop", Rect2(40, 35, 185, 52), func(): _navigate("home"), "quiet", false, 19)


func _build_level_controls() -> void:
	World.build_levels(self)


func _build_album_controls() -> void:
	World.build_album(self)


func _build_shop_controls() -> void:
	World.build_shop(self)


func _build_modal_controls() -> void:
	match modal:
		"settings":
			_button("×", Rect2(588, 210, 50, 50), func(): _open_modal(""), "clear", false, 30)
			var keys: Array = ["sound", "music", "haptics", "reduced_motion"]
			for i in range(keys.size()):
				var key: String = keys[i]
				var enabled: bool = bool(session.profile.get("settings", {}).get(key, false))
				_button("On" if enabled else "Off", Rect2(500, 368 + 91 * i, 120, 60), _toggle_setting.bind(key), "aqua" if enabled else "quiet", false, 22)
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
			var next_button: Button = _button("Next level   ›" if next <= catalogue.size() else "Explore your collection", Rect2(104, 943, 512, 88), _start_level.bind(next) if next <= catalogue.size() else _navigate.bind("album"), "primary", false, 30)
			next_button.add_theme_font_override("font", SERIF)
			_button("My collection", Rect2(195, 1050, 330, 58), func(): _navigate("album"), "clear", false, 22)


func _draw_stage() -> void:
	# The central play surface stays quiet; toy-world details frame the action.
	stage.draw_polygon(PackedVector2Array([Vector2.ZERO, Vector2(720,0), Vector2(720,1280), Vector2(0,1280)]), PackedColorArray([Color("ded1fb"),Color("eaddff"),Color("d9effa"),Color("ede5ff")]))
	for i in range(14):
		var x: float = 10.0 if i % 2 == 0 else 708.0
		var y: float = 112 + i * 88
		_star(stage, Vector2(x, y), 8.0 + i % 3 * 2, Color(1,1,1,0.45), float(i))
	if session == null:
		return
	match screen:
		"game": _draw_game()
		"home": _draw_home()
		"levels": _draw_levels()
		"album": _draw_album()
		"shop": _draw_shop()
	if not message.is_empty() and screen != "game":
		_round(stage, Rect2(35, 1198, 650, 58), INK, 24)
		_text(stage, message, Vector2(50, 1236), 20, WHITE, 620, HORIZONTAL_ALIGNMENT_CENTER)


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
	var at := Vector2(120, y + 6)
	canvas.draw_string_outline(SERIF, at + Vector2(0,3), "SCREWCRAFT", HORIZONTAL_ALIGNMENT_CENTER, 480, 40, 7, Color("624094"))
	canvas.draw_string_outline(SERIF, at, "SCREWCRAFT", HORIZONTAL_ALIGNMENT_CENTER, 480, 40, 5, WHITE)
	_text(canvas, "SCREWCRAFT", at, 40, PINK, 480, HORIZONTAL_ALIGNMENT_CENTER, true)


func _draw_game() -> void:
	_brand(stage)
	var index: int = int(session.level.get("index", 1))
	_round(stage, Rect2(34, 110, 652, 49), Color("b895e7"), 22)
	_round(stage, Rect2(34, 104, 652, 49), GREEN, 22, Color("b996ed"))
	_star(stage, Vector2(65, 128), 15, GOLD, -0.2)
	_text(stage, "LEVEL %02d" % index, Vector2(88, 140), 29, WHITE, -1, HORIZONTAL_ALIGNMENT_LEFT, true)
	var friendly_name: String = {1: "Welcome to the toybox!", 2: "A hidden surprise", 3: "Make a little room"}.get(index, str(session.level.get("name", "Toybox magic")))
	_text(stage, friendly_name, Vector2(280, 138), 20, WHITE, 376, HORIZONTAL_ALIGNMENT_RIGHT, false, true)
	_text(stage, "FILL THESE BOXES", Vector2(43, 185), 18, INK, -1, HORIZONTAL_ALIGNMENT_LEFT, false, true)
	_text(stage, "NEXT UP", Vector2(485, 185), 18, INK, 191, HORIZONTAL_ALIGNMENT_CENTER, false, true)
	var hud: Dictionary = presented_hud if not presented_hud.is_empty() else session.state
	var boxes: Array = hud.get("active_box_slots", [])
	for i in range(2):
		_draw_box(stage, Rect2(40 + i * 222, 204, 204, 116), boxes[i] if boxes.size() > i else null)
		if order_flash > 0.0:
			for j in range(5):
				var center := Vector2(61 + i*222 + j*37, 202 - sin(j*1.7)*7)
				_star(stage, center, 5 + order_flash*14, Color(1,0.8,0.25,order_flash*2), order_flash*2+j)
	var queue: Array = session.level.get("boxes_in_activation_order", [])
	var cursor: int = int(hud.get("next_queue_index", 2))
	for i in range(2):
		var rect := Rect2(485 + i * 100, 204, 93, 91)
		_round(stage, Rect2(rect.position + Vector2(0,4), rect.size), Color("aa8ace"), 21)
		_round(stage, rect, WHITE, 21, Color("c9b2e9"))
		if cursor + i < queue.size():
			var color_id: String = str(queue[cursor + i].color_id)
			Craft.screw(stage, rect.position + Vector2(46, 32), color_id, 21.0)
			_text(stage, color_id.capitalize(), rect.position + Vector2(0, 76), 18, INK, rect.size.x, HORIZONTAL_ALIGNMENT_CENTER, false, true)
		else:
			Craft.icon(stage, rect.position + Vector2(46, 36), "check", 20, Color("b5a2ca"))
			_text(stage, "Done!", rect.position + Vector2(0, 76), 18, MUTED, rect.size.x, HORIZONTAL_ALIGNMENT_CENTER, false, true)
	_round(stage, Rect2(40, 355, 640, 76), Color("66419e"), 25)
	_round(stage, Rect2(40, 348, 640, 76), GREEN, 25, Color("b497ea"))
	_round(stage, Rect2(52, 355, 616, 9), Color(1,1,1,0.18), 4)
	_text(stage, "HOLDING", Vector2(62, 379), 16, WHITE, -1, HORIZONTAL_ALIGNMENT_LEFT, false, true)
	var buffer: Array = hud.get("buffer_screw_ids", [])
	_text(stage, "%d / 5" % buffer.size(), Vector2(85, 408), 26, GOLD, -1, HORIZONTAL_ALIGNMENT_LEFT, true)
	for i in range(5):
		var center := Vector2(216 + i * 96, 388)
		Craft.socket(stage, center, 26, Color("cdb8ec"))
		if i < buffer.size():
			Craft.screw(stage, center, _color_of(str(buffer[i])), 24.0)
	var caption: String = message
	if caption.is_empty():
		caption = "BLUEPRINT: peek at every hidden layer!" if inspection else "Pop a screw. Uncover a surprise!"
		if not inspection and index == 1:
			caption = "Hi, I'm Pip! Tap a screw. Match three to pack a box!"
		elif not inspection and index == 2:
			caption = "Clear the top piece. There's more fun underneath!"
		elif not inspection and index == 3:
			caption = "Green can wait here until its matching box arrives."
		elif not inspection and index == 8:
			caption = "Holding spaces full? A matching screw can still move!"
		elif not inspection:
			var tips: Array = ["Peek at the queue before you pop!", "Clear a piece to open a new path.", "A little space can make a big difference.", "Stuck on a twist? Try a free Hint!", "See every hidden screw with Blueprint."]
			caption = tips[index % tips.size()]
	_round(stage, Rect2(112, 1047, 563, 53), WHITE, 20, Color("d5c3ee"))
	stage.draw_colored_polygon(PackedVector2Array([Vector2(115,1063),Vector2(98,1077),Vector2(117,1085)]), WHITE)
	_pip(stage, Rect2(32,1032,80,80))
	_paragraph(stage, caption, Vector2(123, 1069), 542, 18, INK, 22, true)
	_text(stage, "FREE TOOLS", Vector2(43, 1239), 16, GREEN, 632, HORIZONTAL_ALIGNMENT_CENTER, false, true)
	for x in [285,435]: _star(stage, Vector2(x,1232), 6, PINK)


func _color_of(id: String) -> String:
	for screw in session.level.get("screws", []):
		if str(screw.id) == id:
			return str(screw.color_id)
	return "red"


func _draw_box(canvas: CanvasItem, rect: Rect2, value: Variant) -> void:
	var color: Color = Color("b7a2d3") if value == null else Craft.color_for(str(value.get("color_id", "red")))
	# A proper little carry case: handle, thick rim, inset tray and molded sockets.
	_round(canvas, Rect2(rect.position + Vector2(rect.size.x*0.31,-12), Vector2(rect.size.x*0.38,25)), color.darkened(0.25), 12)
	_round(canvas, Rect2(rect.position + Vector2(rect.size.x*0.34,-8), Vector2(rect.size.x*0.32,17)), color.lightened(0.38), 7)
	_round(canvas, Rect2(rect.position + Vector2(0,7), rect.size), color.darkened(0.32), 23)
	_round(canvas, rect, color, 23, color.lightened(0.5))
	_round(canvas, Rect2(rect.position+Vector2(8,43), rect.size-Vector2(16,51)), WHITE, 16)
	_round(canvas, Rect2(rect.position+Vector2(13,6),Vector2(rect.size.x-26,7)), Color(1,1,1,0.3),4)
	if value == null:
		_text(canvas, "PACKED!", rect.position+Vector2(0,31), 23, WHITE, rect.size.x, HORIZONTAL_ALIGNMENT_CENTER, true)
		Craft.icon(canvas,rect.position+Vector2(rect.size.x*0.5,80),"check",22,GREEN)
		return
	var color_id: String = str(value.get("color_id", "red"))
	var fill: int = value.get("screw_ids", []).size()
	var label_color: Color = INK if color_id in ["yellow","green","teal"] else WHITE
	_text(canvas, "%s  %d/3" % [color_id.capitalize(), fill], rect.position + Vector2(0, 32), 23, label_color, rect.size.x, HORIZONTAL_ALIGNMENT_CENTER, false, true)
	for j in range(3):
		var center: Vector2 = rect.position + Vector2(rect.size.x * (0.20 + j * 0.30), 80)
		Craft.socket(canvas, center, 20, Color("d5cce8"))
		if j < fill:
			Craft.screw(canvas, center, color_id, 23.0)


func _draw_home() -> void:
	World.draw_home(self, stage)


func _page_heading(title: String, subtitle: String) -> void:
	_text(stage, title, Vector2(40, 160), 53, INK, -1, HORIZONTAL_ALIGNMENT_LEFT, true)
	_text(stage, subtitle, Vector2(42, 204), 20, MUTED)
	_line(stage, Vector2(40, 230), Vector2(680, 230))


func _draw_levels() -> void:
	World.draw_levels(self, stage)


func _draw_album() -> void:
	World.draw_album(self, stage)


func _draw_shop() -> void:
	World.draw_shop(self, stage)


func _draw_keepsake(canvas: CanvasItem, center: Vector2, zoom: float, family: String, earned: bool) -> void:
	_sticker(canvas,center,family,88*zoom,AQUA if earned else PALE)


func _draw_overlay() -> void:
	if not travel.is_empty() and modal.is_empty():
		var progress: float = clampf(travel_time / 0.36, 0.0, 1.0)
		var eased: float = smoothstep(0.06, 1.0, progress)
		var start: Vector2 = travel["from"]
		var end: Vector2 = travel["to"]
		var at: Vector2 = start.lerp(end, eased) + Vector2(sin(progress * PI) * 25, -sin(progress * PI) * 58)
		for i in range(4):
			var tail: Vector2 = at + Vector2(-12 + i*7,25+i*8)
			_star(overlay,tail,5-i,Color(1,0.83,0.33,(1-progress)*0.6),progress*2)
		Craft.screw(overlay, at, str(travel.color), 24.0 + sin(progress * PI) * 5.0, 1.0, progress * TAU)
	if modal.is_empty() or session == null:
		return
	overlay.draw_rect(Rect2(0, 0, 720, 1280), Color(0.16, 0.06, 0.28, 0.62))
	var card := Rect2(70, 195, 580, 890)
	if modal in ["stuck", "restart"]:
		card = Rect2(70, 325, 580, 660)
	elif modal == "won":
		card = Rect2(52,177,616,962)
	_round(overlay, Rect2(card.position + Vector2(0,13), card.size), Color("613487"), 40)
	_round(overlay, card.grow(4), Color("bc89e4"), 39)
	_round(overlay, card, WHITE, 35, Color("ffffff"))
	_round(overlay,Rect2(card.position+Vector2(15,8),Vector2(card.size.x-30,8)),Color("ffffff"),4)
	if modal == "won":
		_draw_confetti()
	match modal:
		"settings": _draw_settings()
		"help": _draw_help()
		"queue": _draw_queue()
		"stuck":
			_pip(overlay,Rect2(267,346,186,186))
			_text(overlay,"Let's untangle this!",Vector2(94,566),39,INK,532,HORIZONTAL_ALIGNMENT_CENTER,true)
			_paragraph(overlay,"No room? No worries! Undo a move to free a space, or give this puzzle a fresh start.",Vector2(126,612),468,23,MUTED,32,true)
		"restart":
			_pip(overlay,Rect2(283,355,154,154))
			_text(overlay,"Ready for a redo?",Vector2(94,555),42,INK,532,HORIZONTAL_ALIGNMENT_CENTER,true)
			_paragraph(overlay,"Put every piece back and try a new route. Your coins and collection are safe!",Vector2(130,610),460,23,MUTED,34,true)
		"won": _draw_won()


func _draw_settings() -> void:
	_text(overlay,"Workshop settings",Vector2(102,285),41,INK,-1,HORIZONTAL_ALIGNMENT_LEFT,true)
	_text(overlay,"JUST THE WAY YOU LIKE IT",Vector2(105,326),18,GREEN,-1,HORIZONTAL_ALIGNMENT_LEFT,false,true)
	var labels: Array = ["Sound effects", "Playful music", "Vibration", "Reduced motion"]
	var icons: Array = ["sound", "hint", "settings", "star"]
	for i in range(labels.size()):
		var y: float = 403 + i*91
		_round(overlay,Rect2(99,y-40,61,61),[Color("d6f6f7"),Color("fff0c7"),Color("f6d5ea"),Color("e8ddfa")][i],20)
		Craft.icon(overlay,Vector2(130,y-9),icons[i],20,GREEN)
		_text(overlay, labels[i], Vector2(178, y), 25, INK,-1,HORIZONTAL_ALIGNMENT_LEFT,false,true)
	_text(overlay,"Color + shape symbols are always on.",Vector2(100,752),20,MUTED,520,HORIZONTAL_ALIGNMENT_CENTER)


func _draw_help() -> void:
	_text(overlay,"Let's make some magic!",Vector2(98,285),39,INK,524,HORIZONTAL_ALIGNMENT_CENTER,true)
	_text(overlay,"PIP'S POCKET GUIDE",Vector2(100,328),18,GREEN,520,HORIZONTAL_ALIGNMENT_CENTER,false,true)
	var headings: Array = ["Match three. Pack a box!", "Save a screw for later.", "Pop a piece. Peek below!", "Your tools are always free."]
	var copy: Array = ["Tap an exposed screw. Matching colors go straight into a ready box.", "Five holding spaces keep other colors until their box arrives.", "Remove every screw from a piece to uncover the next layer.", "Undo, Hint and Blueprint help you out. Full holding spaces still allow direct matches!"]
	for i in range(4):
		var y: float = 404 + i*138
		var col: Color = [PINK,AQUA,GOLD,GREEN][i]
		overlay.draw_circle(Vector2(129,y+2),27,col.darkened(0.22),true,-1,true)
		overlay.draw_circle(Vector2(129,y-3),27,col,true,-1,true)
		_text(overlay,str(i+1),Vector2(107,y+6),30,WHITE if i in [0,3] else INK,44,HORIZONTAL_ALIGNMENT_CENTER,true)
		_text(overlay,headings[i],Vector2(173,y+5),25,INK,-1,HORIZONTAL_ALIGNMENT_LEFT,true)
		_paragraph(overlay,copy[i],Vector2(173,y+40),421,21,MUTED,29)


func _draw_queue() -> void:
	_text(overlay,"Your next boxes",Vector2(100,274),45,INK,520,HORIZONTAL_ALIGNMENT_CENTER,true)
	_text(overlay,"A little peek. A clever next move!",Vector2(100,315),21,MUTED,520,HORIZONTAL_ALIGNMENT_CENTER)
	var boxes: Array = session.state.get("active_box_slots", [])
	for i in range(2):
		_draw_box(overlay,Rect2(120+i*249,354,231,119),boxes[i] if i<boxes.size() else null)
	_text(overlay,"ON THEIR WAY",Vector2(120,517),18,GREEN,-1,HORIZONTAL_ALIGNMENT_LEFT,false,true)
	var queue: Array = session.level.get("boxes_in_activation_order", [])
	var cursor: int = int(session.state.get("next_queue_index",2))
	var remaining: int = queue.size()-cursor
	if remaining <= 0:
		_pip(overlay,Rect2(274,552,172,172))
		_paragraph(overlay,"Last boxes! Every screw has a home.",Vector2(140,769),440,27,INK,38,true)
	elif remaining <= 4:
		_pip(overlay,Rect2(268,680,184,184))
		_paragraph(overlay,"Fill a ready box to bring in the next one!",Vector2(131,902),458,24,INK,31,true)
	for i in range(mini(10,remaining-queue_page*10)):
		var j: int = cursor+queue_page*10+i
		var x: float = 120+(i%2)*250
		var y: float = 539+(i/2)*72
		_round(overlay,Rect2(x,y+3,230,58),Color("c4aadf"),20)
		_round(overlay,Rect2(x,y,230,58),Color("eee3fc"),20)
		var color_id: String = str(queue[j].color_id)
		Craft.screw(overlay,Vector2(x+34,y+28),color_id,20)
		_text(overlay,"%d. %s" % [j-cursor+1,color_id.capitalize()],Vector2(x+64,y+38),22,INK,-1,HORIZONTAL_ALIGNMENT_LEFT,false,true)


func _draw_won() -> void:
	# Illustrated celebration, one reward ledger, one clear next action.
	_round(overlay,Rect2(91,204,538,88),Color("d63388"),35)
	_round(overlay,Rect2(91,197,538,88),PINK,35,Color("ff94c7"))
	_text(overlay,"TOY-TASTIC!",Vector2(99,262),60,WHITE,522,HORIZONTAL_ALIGNMENT_CENTER,true)
	for i in range(10):
		var a: float = TAU*i/10.0
		var from := Vector2(360,458)+Vector2.from_angle(a)*105
		var to := Vector2(360,458)+Vector2.from_angle(a)*200
		overlay.draw_line(from,to,Color(1,0.82,0.38,0.3),10,true)
	_pip(overlay,Rect2(206,302,310,310),true)
	_sticker(overlay,Vector2(528,545),str(session.level.get("family","flower")),51,AQUA)
	_text(overlay,"Level %02d complete!" % int(session.level.get("index",1)),Vector2(84,662),40,INK,552,HORIZONTAL_ALIGNMENT_CENTER,true)
	_text(overlay,"Another toybox treasure!",Vector2(100,700),23,MUTED,520,HORIZONTAL_ALIGNMENT_CENTER,false,true)
	_round(overlay,Rect2(179,727,362,76),Color("e7a728"),28)
	_round(overlay,Rect2(179,721,362,76),GOLD,28,Color("ffe9a4"))
	Craft.icon(overlay,Vector2(220,758),"coin",25,INK)
	_text(overlay,"+20 coins!" if first_clear else "Already collected",Vector2(252,770),30,INK,265,HORIZONTAL_ALIGNMENT_CENTER,true)
	var group: int = int((int(session.level.get("index",1))-1)/5)
	var earned: int = 0
	for i in range(5):
		if session.profile.get("completed_levels",[]).has("campaign_%04d" % (group*5+i+1)): earned += 1
	for i in range(5):
		var center := Vector2(264+i*48,842)
		overlay.draw_circle(center,15,AQUA if i<earned else PALE,true,-1,true)
		if i<earned: Craft.icon(overlay,center,"check",10,INK)
	_text(overlay,"%d / 5 toys in this collection" % earned,Vector2(100,893),23,MUTED,520,HORIZONTAL_ALIGNMENT_CENTER,false,true)


func _texture(path: String) -> Texture2D:
	if not texture_cache.has(path):
		texture_cache[path] = load(path) if ResourceLoader.exists(path) else null
	return texture_cache[path] as Texture2D


func _pip(canvas: CanvasItem, rect: Rect2, celebrating: bool = false) -> void:
	var path: String = "res://assets/illustrations/pip_victory.png" if celebrating else "res://assets/illustrations/pip.png"
	var texture: Texture2D = _texture(path)
	if texture == null:
		texture = _texture("res://assets/illustrations/pip.png")
	if texture != null:
		canvas.draw_texture_rect(texture, rect, false)


func _star(canvas: CanvasItem, center: Vector2, radius: float, color: Color, angle: float = 0.0) -> void:
	var points := PackedVector2Array()
	for i in range(10):
		points.append(center + Vector2.from_angle(-PI*0.5 + angle + i*PI/5.0) * radius * (1.0 if i%2==0 else 0.47))
	canvas.draw_colored_polygon(points,color)


func _sticker(canvas: CanvasItem, center: Vector2, family: String, radius: float, color: Color) -> void:
	canvas.draw_circle(center+Vector2(0,5),radius+4,Color("b093d2"),true,-1,true)
	canvas.draw_circle(center,radius+4,WHITE,true,-1,true)
	canvas.draw_circle(center,radius,color,true,-1,true)
	canvas.draw_arc(center,radius-6,PI*1.13,PI*1.85,32,Color(1,1,1,0.45),4,true)
	Craft.motif(canvas,center,family,radius*0.62,INK)

func _draw_confetti() -> void:
	if board.reduced_motion or celebration_time >= 2.4:
		for i in range(10):
			_star(overlay,Vector2(92+fmod(i*157,541),305+fmod(i*83,500)),6+float(i%3),[PINK,AQUA,GOLD,GREEN][i%4],float(i))
		return
	var t: float = celebration_time
	for i in range(52):
		var side: float = -1.0 if i%2==0 else 1.0
		var initial := Vector2(360+side*90,390+float(i%4)*15)
		var velocity := Vector2(side*(65+fmod(i*53,200)),-140-fmod(i*37,190))
		var point: Vector2 = initial + velocity*t + Vector2(0,230*t*t)
		var col: Color = [PINK,AQUA,GOLD,GREEN,Color("ff976b")][i%5]
		col.a = clampf((2.4-t)*1.4,0,1)
		if i%4==0:
			_star(overlay,point,8,col,t*2+i)
		else:
			overlay.draw_set_transform(point,t*3+i)
			overlay.draw_rect(Rect2(-3,-7,6,14),col)
			overlay.draw_set_transform(Vector2.ZERO)
