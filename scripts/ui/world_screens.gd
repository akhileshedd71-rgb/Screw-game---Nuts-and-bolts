extends RefCounted
## Illustrated toybox destinations. Presentation only: the session owns all progress.

const Craft = preload("res://scripts/ui/craft_draw.gd")
const INK = Color("36235f")
const MUTED = Color("756095")
const PINK = Color("ed4f9a")
const AQUA = Color("28c9d4")
const PURPLE = Color("8452db")
const YELLOW = Color("ffce57")
const WHITE = Color("fff9ff")
const LAVENDER = Color("eee8ff")
const CHAPTERS = ["Spoolwood Springs", "Bubble Bay", "Ribbonwood Lane", "Starlight Station", "Candy Cloud Cove", "Moonbeam Market", "Rainbow Workshop", "Pip's Parade"]
const TOYS = ["Daisy spinner", "Bubble boat", "Tweet treat", "Whirly twirl", "Tea party", "Tiny toyhouse", "Rocket pop", "Rainbow kite"]
const SKINS = ["beech", "walnut", "rose", "sage"]
const FINISHES = ["Honey Pop", "Berry Jam", "Strawberry Fizz", "Aqua Splash"]
const PAINTS = [YELLOW, PURPLE, PINK, AQUA]
static var _textures: Dictionary = {}


static func draw_home(app, canvas: CanvasItem) -> void:
	_background(app, canvas, true)
	_coin_pill(app, canvas, Rect2(36, 36, 175, 64))
	# A hand-lettered toy-box wordmark sits above the illustrated world.
	_title(app, canvas, "SCREWCRAFT", Vector2(30, 192), 73, 660, WHITE, PURPLE)
	_ribbon(app, canvas, Rect2(185, 215, 350, 47), "TOYBOX WORKSHOP", PINK, 21)
	var world_ready: bool = ResourceLoader.exists("res://assets/illustrations/toy_world.png")
	if not world_ready:
		_toyhouse(app, canvas, Vector2(542, 587), 1.8)
		_toyhouse(app, canvas, Vector2(147, 410), 0.65)
	# Pip and the dialogue belong to the world, not a dashboard hero card.
	app._round(canvas, Rect2(307, 340, 335, 153), Color("b6a0db"), 38)
	app._round(canvas, Rect2(302, 332, 335, 153), WHITE, 38)
	canvas.draw_colored_polygon(PackedVector2Array([Vector2(338, 465), Vector2(337, 521), Vector2(393, 474)]), WHITE)
	app._text(canvas, "Hello, maker!", Vector2(329, 377), 32, INK, 282, HORIZONTAL_ALIGNMENT_CENTER, true)
	app._text(canvas, "A little twist.", Vector2(327, 416), 25, MUTED, 284, HORIZONTAL_ALIGNMENT_CENTER)
	app._text(canvas, "A lot of happy.", Vector2(327, 451), 25, MUTED, 284, HORIZONTAL_ALIGNMENT_CENTER)
	_mascot(canvas, Rect2(2, 345, 398, 398))
	_sparkle(canvas, Vector2(575, 533), 16, YELLOW)
	_sparkle(canvas, Vector2(413, 614), 11, WHITE)
	# Curved foreground keeps buttons quiet and strongly separated from scenery.
	canvas.draw_circle(Vector2(360, 1195), 459, Color("d8c8f7"), true, -1, true)
	canvas.draw_circle(Vector2(360, 1181), 453, LAVENDER, true, -1, true)
	app._text(canvas, "READY, SET, UNSCREW!", Vector2(55, 784), 26, INK, 610, HORIZONTAL_ALIGNMENT_CENTER, true)
	var made: int = app.session.profile.get("completed_levels", []).size()
	app._text(canvas, "%d / 1,000 puzzles packed" % made, Vector2(60, 1229), 19, MUTED, 600, HORIZONTAL_ALIGNMENT_CENTER, false, true)
	# Tiny screws anchor the otherwise illustration-led composition to the genre.
	Craft.screw(canvas, Vector2(64, 779), "blue", 20)
	Craft.screw(canvas, Vector2(656, 779), "red", 20)


static func build_home(app) -> void:
	app._icon_button("settings", Rect2(624, 40, 56, 56), func(): app._open_modal("settings"), "Settings")
	var play: Button = app._button("Continue your craft   ›", Rect2(91, 814, 538, 118), func(): app._navigate("game"), "primary", false, 27)
	_hide_button_text(play)
	play.draw.connect(func():
		var dy: float = 5.0 if play.button_pressed else 0.0
		app._text(play, "PLAY", Vector2(0, 55 + dy), 45, WHITE, 538, HORIZONTAL_ALIGNMENT_CENTER, true)
		app._text(play, "LEVEL %02d   •   LET'S GO!" % int(app.session.level.get("index", 1)), Vector2(0, 88 + dy), 18, WHITE, 538, HORIZONTAL_ALIGNMENT_CENTER, false, true)
		Craft.icon(play, Vector2(467, 57 + dy), "next", 22, WHITE))
	var explore: Button = app._button("Explore 1,000 puzzles", Rect2(91, 956, 538, 88), func():
		app.level_page = int((int(app.session.profile.get("current_level", 1)) - 1) / 25)
		app._navigate("levels"), "aqua", false, 25)
	explore.tooltip_text = "Choose any of the 1,000 puzzles on the Toybox Trail"
	_nav_toy_button(app, "My collection", "Collection", Rect2(91, 1068, 258, 116), func(): app._navigate("album"), "album", YELLOW)
	_nav_toy_button(app, "Wood finishes", "Paint shop", Rect2(371, 1068, 258, 116), func(): app._navigate("shop"), "paint", PURPLE)
	# A separate help destination remains available through Settings on every screen.


static func draw_levels(app, canvas: CanvasItem) -> void:
	_background(app, canvas)
	_heading(app, canvas, "Toybox Trail", "Every twist is a new adventure.")
	var chapter: String = CHAPTERS[int(app.level_page) % CHAPTERS.size()]
	_ribbon(app, canvas, Rect2(153, 230, 414, 49), chapter, PURPLE, 23)
	# A ribbon winds through 25 touch-sized nodes; all pages stay freely available.
	var curve := Curve2D.new()
	curve.bake_interval = 8.0
	for i in range(25):
		var tangent: Vector2 = (_level_position(mini(i + 1, 24)) - _level_position(maxi(i - 1, 0))) * 0.20
		curve.add_point(_level_position(i), -tangent, tangent)
	var path: PackedVector2Array = curve.get_baked_points()
	canvas.draw_polyline(path, Color("d6c2ed"), 63, true)
	canvas.draw_polyline(path, WHITE, 52, true)
	canvas.draw_polyline(path, Color("f5c9e8"), 36, true)
	for i in range(25):
		canvas.draw_circle(_level_position(i), 25, Color("f5c9e8"), true, -1, true)
	# Landscape at the edges makes this a miniature place rather than a grid.
	_sparkle(canvas, Vector2(39, 558), 10, PINK)
	_sparkle(canvas, Vector2(678, 809), 12, AQUA)
	_sparkle(canvas, Vector2(50, 318), 11, YELLOW)
	_sparkle(canvas, Vector2(669, 322), 15, YELLOW)
	app._text(canvas, "CHAPTER %02d / %02d" % [int(app.level_page) + 1, ceili(app.catalogue.size() / 25.0)], Vector2(236, 1096), 18, MUTED, 248, HORIZONTAL_ALIGNMENT_CENTER, false, true)
	app._text(canvas, "Pick any puzzle. Your free tools come too!", Vector2(40, 1246), 18, MUTED, 640, HORIZONTAL_ALIGNMENT_CENTER)


static func build_levels(app) -> void:
	_back(app)
	for i in range(25):
		var index: int = int(app.level_page) * 25 + i + 1
		if index > app.catalogue.size():
			break
		var complete: bool = app.session.profile.get("completed_levels", []).has("campaign_%04d" % index)
		var current: bool = int(app.session.level.get("index", 1)) == index
		var at: Vector2 = _level_position(i)
		var node: Button = app._button("%02d" % index, Rect2(at - Vector2(48, 48), Vector2(96, 96)), app._start_level.bind(index), "level", false, 29 if index < 1000 else 24)
		var fill: Color = AQUA if complete else (PINK if current else PAINTS[int(i / 5) % 4].lightened(0.50))
		_level_style(node, fill, complete or current)
		node.tooltip_text = "Level %d%s" % [index, " • complete" if complete else ""]
		if complete:
			node.draw.connect(func():
				Craft.symbol(node, Vector2(76, 15), "yellow", 17, YELLOW))
		elif current:
			node.draw.connect(func():
				_sparkle(node, Vector2(80, 9), 12, YELLOW))
	app._button("‹  Previous", Rect2(39, 1043, 193, 94), func():
		app.level_page = maxi(0, int(app.level_page) - 1)
		app._rebuild_controls(), "light", app.level_page == 0, 21)
	app._button("Next  ›", Rect2(488, 1043, 193, 94), func():
		app.level_page = mini(39, int(app.level_page) + 1)
		app._rebuild_controls(), "aqua", (int(app.level_page) + 1) * 25 >= app.catalogue.size(), 22)
	app._button("First", Rect2(219, 1158, 128, 64), func():
		app.level_page = 0
		app._rebuild_controls(), "quiet", false, 20)
	app._button("Last", Rect2(373, 1158, 128, 64), func():
		app.level_page = int((app.catalogue.size() - 1) / 25)
		app._rebuild_controls(), "quiet", false, 20)


static func draw_album(app, canvas: CanvasItem) -> void:
	_background(app, canvas)
	_heading(app, canvas, "Happy little treasures", "Five puzzles. One new toy. All yours.", 44)
	# The album is a toy cabinet, with dimensional shelves and collectible stickers.
	app._round(canvas, Rect2(32, 263, 656, 795), Color("c5aae9"), 36)
	app._round(canvas, Rect2(44, 270, 632, 776), Color("e2d4f9"), 26)
	for row in range(4):
		var y: float = 290 + row * 190
		for col in range(2):
			var i: int = row * 2 + col
			var group: int = int(app.album_page) * 8 + i
			var count: int = _collection_count(app, group)
			var x: float = 204 + col * 312
			var earned: bool = count == 5
			# A white sticker scallop and color halo read clearly as a collectible.
			canvas.draw_circle(Vector2(x, y + 60), 68, Color("ccb6e8"), true, -1, true)
			canvas.draw_circle(Vector2(x, y + 54), 68, WHITE, true, -1, true)
			canvas.draw_circle(Vector2(x, y + 54), 59, PAINTS[group % 4].lightened(0.75), true, -1, true)
			_sticker(canvas, Vector2(x, y + 53), group % 8, 0.70, earned)
			if earned:
				canvas.draw_circle(Vector2(x + 57, y + 16), 19, AQUA, true, -1, true)
				Craft.icon(canvas, Vector2(x + 57, y + 16), "check", 14, WHITE)
			app._text(canvas, TOYS[group % 8], Vector2(x - 145, y + 144), 22, INK, 290, HORIZONTAL_ALIGNMENT_CENTER, true)
			for j in range(5):
				var dot := Vector2(x - 38 + j * 19, y + 164)
				canvas.draw_circle(dot, 5, PINK if j < count else Color("b79ad8"), true, -1, true)
			app._text(canvas, "%d/5" % count, Vector2(x + 63, y + 170), 15, MUTED, 40, HORIZONTAL_ALIGNMENT_CENTER, false, true)
		# Shelf front and lip cast a soft shadow into the compartment below.
		app._round(canvas, Rect2(43, y + 180, 635, 13), Color("b495d6"), 5)
		app._round(canvas, Rect2(36, y + 172, 648, 13), PURPLE.lightened(0.38), 5)
		app._round(canvas, Rect2(42, y + 172, 636, 4), Color("f5e9ff"), 2)
	app._text(canvas, "TOYS %d–%d OF 200" % [int(app.album_page) * 8 + 1, int(app.album_page) * 8 + 8], Vector2(145, 1137), 19, MUTED, 430, HORIZONTAL_ALIGNMENT_CENTER, false, true)
	app._text(canvas, "Made with a little patience and a lot of play.", Vector2(40, 1230), 18, MUTED, 640, HORIZONTAL_ALIGNMENT_CENTER)


static func build_album(app) -> void:
	_back(app)
	app._button("‹", Rect2(40, 1075, 96, 96), func():
		app.album_page = maxi(0, int(app.album_page) - 1)
		app._rebuild_controls(), "light", app.album_page == 0, 34)
	app._button("›", Rect2(584, 1075, 96, 96), func():
		app.album_page = mini(24, int(app.album_page) + 1)
		app._rebuild_controls(), "aqua", app.album_page == 24, 34)


static func draw_shop(app, canvas: CanvasItem) -> void:
	_background(app, canvas)
	_heading(app, canvas, "Pip's paint shop", "A fresh splash for your next masterpiece.", 49)
	_coin_pill(app, canvas, Rect2(495, 40, 186, 62))
	for i in range(4):
		var x: float = 199 + (i % 2) * 322
		var y: float = 351 + int(i / 2) * 424
		var color: Color = PAINTS[i]
		var selected: bool = str(app.session.profile.get("skin", "beech")) == SKINS[i]
		# Each paint sits on its own little workbench, not in a repeated text card.
		canvas.draw_circle(Vector2(x, y + 33), 124, color.lightened(0.81), true, -1, true)
		_sparkle(canvas, Vector2(x - 108, y - 37), 12, color)
		_sparkle(canvas, Vector2(x + 102, y + 40), 8, YELLOW)
		_paint_bottle(canvas, Vector2(x, y), color, i)
		app._round(canvas, Rect2(x - 136, y + 129, 272, 16), Color("c3a6e4"), 7)
		app._round(canvas, Rect2(x - 144, y + 117, 288, 19), WHITE, 7)
		app._text(canvas, FINISHES[i], Vector2(x - 149, y + 183), 26 if i != 2 else 23, INK, 298, HORIZONTAL_ALIGNMENT_CENTER, true)
		if selected:
			_ribbon(app, canvas, Rect2(x - 75, y - 127, 150, 36), "YOUR FINISH", PURPLE, 16)
	app._round(canvas, Rect2(77, 1132, 566, 69), Color("fff1c7"), 25)
	Craft.icon(canvas, Vector2(111, 1166), "coin", 23)
	app._text(canvas, "Earn 20 coins with every new puzzle.", Vector2(136, 1174), 21, INK, 480, HORIZONTAL_ALIGNMENT_CENTER, false, true)
	app._text(canvas, "Fun finishes. Always the same fair puzzle.", Vector2(40, 1245), 18, MUTED, 640, HORIZONTAL_ALIGNMENT_CENTER)


static func build_shop(app) -> void:
	_back(app)
	for i in range(4):
		var skin_id: String = SKINS[i]
		var owned: bool = app.session.profile.get("owned_skins", []).has(skin_id)
		var selected: bool = app.session.profile.get("skin", "beech") == skin_id
		var x: float = 69 + (i % 2) * 322
		var y: float = 557 + int(i / 2) * 424
		app._button("In use" if selected else ("Use finish" if owned else "100 coins"), Rect2(x, y, 260, 96), app._purchase.bind(skin_id), "quiet" if selected else ("primary" if i % 2 == 0 else "aqua"), selected, 25)


static func _background(app, canvas: CanvasItem, scenic: bool = false) -> void:
	canvas.draw_rect(Rect2(0, 0, 720, 1280), LAVENDER)
	if scenic and ResourceLoader.exists("res://assets/illustrations/toy_world.png"):
		var texture: Texture2D = _texture("res://assets/illustrations/toy_world.png")
		canvas.draw_texture_rect(texture, Rect2(0, 0, 720, 1080), false)
		# Calm a small part of the sky for the outlined wordmark.
		canvas.draw_rect(Rect2(0, 0, 720, 282), Color(0.90, 0.82, 1.0, 0.12))
	else:
		canvas.draw_circle(Vector2(-60, 263), 296, Color("e4d7fc"), true, -1, true)
		canvas.draw_circle(Vector2(776, 651), 302, Color("e1f4f6"), true, -1, true)
		canvas.draw_circle(Vector2(207, 1303), 268, Color("e5dafa"), true, -1, true)
		for i in range(21):
			var at := Vector2(fmod(i * 167.0 + 28, 720), fmod(i * 173.0 + 93, 1280))
			canvas.draw_circle(at, 3.0, Color("c9b5e9"), true, -1, true)
		if scenic:
			canvas.draw_circle(Vector2(178, 928), 430, Color("c2d9f5"), true, -1, true)
			canvas.draw_circle(Vector2(657, 942), 436, Color("c2edf0"), true, -1, true)
			_cloud(canvas, Vector2(81, 311), 0.7)
			_cloud(canvas, Vector2(584, 251), 0.8)
	# Decorative bunting continues the same toy-world language on every destination.
	if not scenic:
		canvas.draw_line(Vector2(261, 34), Vector2(459, 34), Color("baa1dc"), 3, true)
		for i in range(5):
			var x: float = 275 + i * 34
			canvas.draw_colored_polygon(PackedVector2Array([Vector2(x, 34), Vector2(x + 24, 34), Vector2(x + 12, 58 + (i % 2) * 6)]), PAINTS[i % 4])


static func _heading(app, canvas: CanvasItem, title: String, subtitle: String, font_size: int = 53) -> void:
	app._text(canvas, title, Vector2(34, 168), font_size, INK, 652, HORIZONTAL_ALIGNMENT_CENTER, true)
	app._text(canvas, subtitle, Vector2(40, 210), 22, MUTED, 640, HORIZONTAL_ALIGNMENT_CENTER)


static func _back(app) -> void:
	app._button("‹  Workshop", Rect2(35, 29, 215, 84), func(): app._navigate("home"), "light", false, 21)


static func _coin_pill(app, canvas: CanvasItem, rect: Rect2) -> void:
	app._round(canvas, Rect2(rect.position + Vector2(0, 5), rect.size), Color("bf9cd8"), 30)
	app._round(canvas, rect, WHITE, 30)
	Craft.icon(canvas, rect.position + Vector2(32, rect.size.y / 2.0), "coin", 26)
	app._text(canvas, str(int(app.session.profile.get("coins", 0))), rect.position + Vector2(60, 42), 27, INK, rect.size.x - 71, HORIZONTAL_ALIGNMENT_CENTER, true)


static func _title(app, canvas: CanvasItem, value: String, at: Vector2, font_size: int, width: float, color: Color, outline: Color) -> void:
	for i in range(12):
		var offset := Vector2.from_angle(i * TAU / 12.0) * 5.5
		app._text(canvas, value, at + offset + Vector2(0, 6), font_size, outline, width, HORIZONTAL_ALIGNMENT_CENTER, true)
	app._text(canvas, value, at, font_size, color, width, HORIZONTAL_ALIGNMENT_CENTER, true)


static func _ribbon(app, canvas: CanvasItem, rect: Rect2, value: String, color: Color, font_size: int) -> void:
	var tail_left := PackedVector2Array([rect.position + Vector2(14, 6), rect.position + Vector2(-16, 6), rect.position + Vector2(-6, rect.size.y / 2), rect.position + Vector2(-16, rect.size.y - 1), rect.position + Vector2(19, rect.size.y - 1)])
	var tail_right := PackedVector2Array()
	for point in tail_left:
		tail_right.append(Vector2(rect.end.x - (point.x - rect.position.x), point.y))
	canvas.draw_colored_polygon(tail_left, color.darkened(0.15))
	canvas.draw_colored_polygon(tail_right, color.darkened(0.15))
	app._round(canvas, Rect2(rect.position + Vector2(0, 4), rect.size), color.darkened(0.17), 12)
	app._round(canvas, rect, color, 12)
	app._text(canvas, value, rect.position + Vector2(0, rect.size.y * 0.73), font_size, WHITE, rect.size.x, HORIZONTAL_ALIGNMENT_CENTER, false, true)


static func _hide_button_text(button: Button) -> void:
	for theme_color in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color", "font_disabled_color"]:
		button.add_theme_color_override(theme_color, Color.TRANSPARENT)
	button.add_theme_color_override("font_shadow_color", Color.TRANSPARENT)


static func _nav_toy_button(app, internal_text: String, caption: String, rect: Rect2, callback: Callable, kind: String, color: Color) -> void:
	var button: Button = app._button(internal_text, rect, callback, "light", false, 22)
	_hide_button_text(button)
	button.draw.connect(func():
		var dy: float = 5.0 if button.button_pressed else 0.0
		if kind == "paint":
			_paint_bottle(button, Vector2(50, 46 + dy), color, 2, 0.28)
		else:
			button.draw_circle(Vector2(51, 52 + dy), 28, color.lightened(0.45), true, -1, true)
			_sticker(button, Vector2(51, 52 + dy), 3, 0.36, true)
		app._text(button, caption, Vector2(87, 66 + dy), 25, INK, rect.size.x - 103, HORIZONTAL_ALIGNMENT_CENTER, true))


static func _level_position(index: int) -> Vector2:
	var row: int = int(index / 5)
	var col: int = index % 5
	if row % 2 == 1:
		col = 4 - col
	return Vector2(101 + col * 129.5, 951 - row * 147 + sin(col * PI * 0.5) * 13)


static func _level_style(button: Button, color: Color, filled: bool) -> void:
	for key in ["normal", "hover", "pressed", "disabled", "focus"]:
		var box := StyleBoxFlat.new()
		box.set_corner_radius_all(48)
		box.bg_color = color.lightened(0.07) if key == "hover" else color
		box.border_color = WHITE if filled else Color("d8c5ee")
		box.set_border_width_all(4)
		box.shadow_color = color.darkened(0.26) if filled else Color("b89bd6")
		box.shadow_offset = Vector2(0, 7 if key != "pressed" else 2)
		box.shadow_size = 2
		if key == "focus":
			box.bg_color = Color.TRANSPARENT
			box.border_color = YELLOW
			box.set_border_width_all(5)
			box.shadow_color = Color.TRANSPARENT
		button.add_theme_stylebox_override(key, box)
	for key in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color"]:
		button.add_theme_color_override(key, INK)


static func _collection_count(app, group: int) -> int:
	var count: int = 0
	for j in range(5):
		if app.session.profile.get("completed_levels", []).has("campaign_%04d" % (group * 5 + j + 1)):
			count += 1
	return count


static func _mascot(canvas: CanvasItem, rect: Rect2) -> void:
	if ResourceLoader.exists("res://assets/illustrations/pip.png"):
		var texture: Texture2D = _texture("res://assets/illustrations/pip.png")
		canvas.draw_texture_rect(texture, rect, false)
	else:
		# Resource-safe fallback while an import is in progress.
		var at: Vector2 = rect.get_center()
		canvas.draw_circle(at + Vector2(0, 70), 80, AQUA, true, -1, true)
		canvas.draw_circle(at, 95, YELLOW, true, -1, true)
		canvas.draw_circle(at + Vector2(-31, -4), 14, INK, true, -1, true)
		canvas.draw_circle(at + Vector2(31, -4), 14, INK, true, -1, true)
		canvas.draw_arc(at + Vector2(0, 18), 25, 0, PI, 20, INK, 5, true)


static func _texture(path: String) -> Texture2D:
	# Canvas draw commands retain a texture RID, so keep a strong resource reference
	# past the draw callback instead of letting a local load disappear before render.
	if not _textures.has(path):
		_textures[path] = load(path)
	return _textures[path]


static func _sparkle(canvas: CanvasItem, center: Vector2, radius: float, color: Color) -> void:
	var points := PackedVector2Array()
	for i in range(8):
		points.append(center + Vector2.from_angle(i * TAU / 8.0) * radius * (1.0 if i % 2 == 0 else 0.3))
	canvas.draw_colored_polygon(points, color)


static func _cloud(canvas: CanvasItem, at: Vector2, zoom: float) -> void:
	for spec in [Vector3(-51, 5, 29), Vector3(-20, -17, 39), Vector3(25, -9, 34), Vector3(58, 8, 27)]:
		canvas.draw_circle(at + Vector2(spec.x, spec.y) * zoom, spec.z * zoom, WHITE, true, -1, true)


static func _toyhouse(app, canvas: CanvasItem, at: Vector2, zoom: float) -> void:
	canvas.draw_set_transform(at, -0.06, Vector2.ONE * zoom)
	app._round(canvas, Rect2(-59, -15, 118, 111), Color("ffc781"), 22)
	canvas.draw_colored_polygon(PackedVector2Array([Vector2(-75, -8), Vector2(0, -81), Vector2(76, -8)]), PINK)
	app._round(canvas, Rect2(-19, 26, 39, 70), PURPLE, 18)
	canvas.draw_circle(Vector2(0, -8), 18, AQUA, true, -1, true)
	canvas.draw_circle(Vector2(0, -8), 20, WHITE, false, 4, true)
	canvas.draw_set_transform(Vector2.ZERO)


static func _paint_bottle(canvas: CanvasItem, at: Vector2, color: Color, variant: int, zoom: float = 1.0) -> void:
	canvas.draw_set_transform(at, -0.045 if variant % 2 == 0 else 0.045, Vector2.ONE * zoom)
	Craft.rounded(canvas, Rect2(-78, -57, 160, 178), color.darkened(0.25), 32)
	Craft.rounded(canvas, Rect2(-81, -65, 160, 177), color, 32, WHITE, 4)
	Craft.rounded(canvas, Rect2(-60, -46, 13, 105), color.lightened(0.58), 8)
	Craft.rounded(canvas, Rect2(-47, -96, 94, 41), INK, 12)
	Craft.rounded(canvas, Rect2(-43, -97, 86, 25), PURPLE, 9)
	for i in range(5):
		canvas.draw_line(Vector2(-31 + i * 15, -89), Vector2(-31 + i * 15, -77), Color("aa80e8"), 4, true)
	Craft.rounded(canvas, Rect2(-60, -7, 120, 87), WHITE, 20)
	canvas.draw_circle(Vector2(0, 35), 31, color.lightened(0.63), true, -1, true)
	Craft.symbol(canvas, Vector2(0, 35), "yellow", 25, color.darkened(0.12))
	canvas.draw_arc(Vector2(3, -15), 67, -PI * 0.10, PI * 0.20, 14, color.lightened(0.2), 3, true)
	canvas.draw_set_transform(Vector2.ZERO)


static func _sticker(canvas: CanvasItem, at: Vector2, family: int, zoom: float, earned: bool) -> void:
	canvas.draw_set_transform(at, -0.045 if family % 2 == 0 else 0.045, Vector2.ONE * zoom)
	var pink: Color = PINK if earned else PINK.lightened(0.19)
	var aqua: Color = AQUA if earned else AQUA.lightened(0.20)
	var purple: Color = PURPLE if earned else PURPLE.lightened(0.20)
	var yellow: Color = YELLOW if earned else YELLOW.lightened(0.15)
	match family:
		0:
			for i in range(6):
				var petal := Vector2.from_angle(TAU * i / 6.0) * 33
				canvas.draw_circle(petal + Vector2(0, 4), 22, pink.darkened(0.19), true, -1, true)
				canvas.draw_circle(petal, 22, pink, true, -1, true)
			canvas.draw_circle(Vector2.ZERO, 25, yellow, true, -1, true)
			_face(canvas, Vector2(0, 1), 0.7)
		1:
			canvas.draw_colored_polygon(PackedVector2Array([Vector2(-62, 15), Vector2(60, 15), Vector2(35, 54), Vector2(-40, 54)]), aqua.darkened(0.16))
			canvas.draw_colored_polygon(PackedVector2Array([Vector2(-62, 11), Vector2(60, 11), Vector2(35, 45), Vector2(-40, 45)]), aqua)
			canvas.draw_line(Vector2(-4, -63), Vector2(-4, 12), purple, 7, true)
			canvas.draw_colored_polygon(PackedVector2Array([Vector2(4, -59), Vector2(4, 4), Vector2(59, 4)]), pink)
			canvas.draw_colored_polygon(PackedVector2Array([Vector2(-11, -46), Vector2(-11, 4), Vector2(-54, 4)]), yellow)
			_face(canvas, Vector2(0, 26), 0.65)
		2:
			canvas.draw_circle(Vector2(-4, 11), 44, aqua.darkened(0.12), true, -1, true)
			canvas.draw_circle(Vector2(-7, 6), 42, aqua, true, -1, true)
			canvas.draw_circle(Vector2(21, -24), 27, aqua, true, -1, true)
			canvas.draw_colored_polygon(PackedVector2Array([Vector2(43, -24), Vector2(69, -14), Vector2(42, -6)]), yellow)
			canvas.draw_circle(Vector2(24, -28), 6, INK, true, -1, true)
			canvas.draw_circle(Vector2(25, -30), 2, WHITE, true, -1, true)
			canvas.draw_circle(Vector2(-18, 11), 22, purple, true, -1, true)
			canvas.draw_arc(Vector2(-19, 8), 15, 0.2, 2.7, 20, purple.lightened(0.35), 4, true)
			canvas.draw_line(Vector2(-19, 43), Vector2(-24, 55), yellow.darkened(0.13), 7, true)
			canvas.draw_line(Vector2(9, 44), Vector2(15, 56), yellow.darkened(0.13), 7, true)
		3:
			canvas.draw_line(Vector2.ZERO, Vector2(0, 69), purple.darkened(0.12), 10, true)
			for i in range(4):
				var points := PackedVector2Array()
				for point in [Vector2.ZERO, Vector2(-14, -59), Vector2(38, -40), Vector2(24, -6)]:
					points.append(point.rotated(i * PI * 0.5))
				canvas.draw_colored_polygon(points, [pink, aqua, purple, yellow][i])
			Craft.screw(canvas, Vector2.ZERO, "yellow", 16)
		4:
			canvas.draw_arc(Vector2(40, 0), 26, -PI * 0.65, PI * 0.72, 24, purple, 11, true)
			canvas.draw_colored_polygon(PackedVector2Array([Vector2(-37, -11), Vector2(-64, -24), Vector2(-53, 9), Vector2(-24, 27)]), pink)
			canvas.draw_circle(Vector2(0, 5), 43, pink.darkened(0.13), true, -1, true)
			canvas.draw_circle(Vector2(-3, 0), 42, pink, true, -1, true)
			Craft.rounded(canvas, Rect2(-36, -43, 70, 15), purple, 7)
			canvas.draw_circle(Vector2(0, -49), 10, yellow, true, -1, true)
			_face(canvas, Vector2(-3, 0), 1.0)
			canvas.draw_arc(Vector2(-2, 1), 31, PI, PI * 1.43, 16, pink.lightened(0.5), 5, true)
		5:
			Craft.rounded(canvas, Rect2(-43, -11, 89, 67), aqua.darkened(0.1), 12)
			Craft.rounded(canvas, Rect2(-46, -16, 89, 67), aqua, 12)
			canvas.draw_colored_polygon(PackedVector2Array([Vector2(-60, -10), Vector2(0, -63), Vector2(61, -10)]), pink)
			Craft.rounded(canvas, Rect2(-13, 10, 28, 42), purple, 12)
			canvas.draw_circle(Vector2(0, -18), 15, yellow, true, -1, true)
			canvas.draw_line(Vector2(0, -28), Vector2(0, -8), WHITE, 3, true)
			canvas.draw_line(Vector2(-10, -18), Vector2(10, -18), WHITE, 3, true)
		6:
			canvas.draw_colored_polygon(PackedVector2Array([Vector2(-20, 39), Vector2(0, 76), Vector2(23, 38)]), yellow)
			canvas.draw_colored_polygon(PackedVector2Array([Vector2(-20, 3), Vector2(-48, 47), Vector2(-16, 41)]), purple)
			canvas.draw_colored_polygon(PackedVector2Array([Vector2(20, 3), Vector2(48, 47), Vector2(16, 41)]), purple)
			Craft.rounded(canvas, Rect2(-26, -44, 52, 92), pink, 26)
			canvas.draw_colored_polygon(PackedVector2Array([Vector2(-25, -25), Vector2(0, -69), Vector2(25, -25)]), aqua)
			canvas.draw_circle(Vector2(0, -9), 18, WHITE, true, -1, true)
			canvas.draw_circle(Vector2(0, -9), 12, purple, true, -1, true)
			canvas.draw_circle(Vector2(-4, -13), 4, WHITE, true, -1, true)
		7:
			canvas.draw_colored_polygon(PackedVector2Array([Vector2(0, -66), Vector2(52, -6), Vector2(0, 53), Vector2(-49, -6)]), yellow)
			canvas.draw_colored_polygon(PackedVector2Array([Vector2(0, -66), Vector2(0, -6), Vector2(-49, -6)]), pink)
			canvas.draw_colored_polygon(PackedVector2Array([Vector2(0, -6), Vector2(52, -6), Vector2(0, 53)]), aqua)
			canvas.draw_line(Vector2(0, -66), Vector2(0, 53), WHITE, 4, true)
			canvas.draw_line(Vector2(-49, -6), Vector2(52, -6), WHITE, 4, true)
			canvas.draw_polyline(PackedVector2Array([Vector2(0, 53), Vector2(18, 69), Vector2(8, 80)]), purple, 4, true)
			_sparkle(canvas, Vector2(13, 68), 12, pink)
	canvas.draw_set_transform(Vector2.ZERO)


static func _face(canvas: CanvasItem, at: Vector2, zoom: float) -> void:
	for side in [-1, 1]:
		canvas.draw_circle(at + Vector2(side * 13, -6) * zoom, 4.3 * zoom, INK, true, -1, true)
		canvas.draw_circle(at + Vector2(side * 17, 4) * zoom, 4.5 * zoom, Color("ffc0d2"), true, -1, true)
	canvas.draw_arc(at + Vector2(0, 2) * zoom, 7 * zoom, 0, PI, 12, INK, 2.6 * zoom, true)
