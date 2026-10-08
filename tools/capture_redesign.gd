extends SceneTree
## Capture actual rendered App screens, with an isolated disposable player profile.
## DISPLAY=:91 XDG_DATA_HOME=/tmp/screwcraft-capture-.../data ./tools/godot.sh \
##   --path . --script tools/capture_redesign.gd -- --size=720x1280
const MainScene = preload("res://scenes/main.tscn")
var app: Node
var output := "res://builds/reports/redesign"
var viewport_size := Vector2i(720, 1280)
var manifest: Dictionary = {}

func _initialize() -> void:
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--size="):
			var parts := arg.trim_prefix("--size=").split("x")
			viewport_size = Vector2i(int(parts[0]), int(parts[1]))
	if not OS.get_environment("XDG_DATA_HOME").begins_with("/tmp/screwcraft-capture-"):
		printerr("Capture refuses to use a non-isolated profile directory.")
		quit(2)
		return
	call_deferred("_run")

func _capture(label: String) -> void:
	await create_timer(0.55).timeout
	await RenderingServer.frame_post_draw
	# Canvas-items stretching may render a larger logical texture on a phone-sized
	# window. Capture the presented X11 window for honest physical-pixel screenshots.
	var desktop_image: Image = DisplayServer.screen_get_image(DisplayServer.window_get_current_screen())
	var window_rect := Rect2i(DisplayServer.window_get_position(), DisplayServer.window_get_size())
	var image: Image = desktop_image.get_region(window_rect)
	assert(image.get_size() == viewport_size, "Capture must use the requested physical viewport size")
	var file_name := "%s-%dx%d.png" % [label, viewport_size.x, viewport_size.y]
	var code := image.save_png(output.path_join(file_name))
	assert(code == OK, "Screenshot must save: " + file_name)
	var buttons: Array = []
	for child: Node in app.controls.get_children():
		if child is Button:
			buttons.append({"text": child.text.strip_edges(), "name": child.name,
				"tooltip": child.tooltip_text, "disabled": child.disabled,
				"rect": [child.position.x, child.position.y, child.size.x, child.size.y]})
	manifest[label] = {"image": file_name, "width": image.get_width(), "height": image.get_height(),
		"screen": app.screen, "modal": app.modal, "buttons": buttons,
		"stage_rect": [app.stage.position.x, app.stage.position.y, app.stage.scale.x * 720, app.stage.scale.y * 1280]}
	print("CAPTURE ", file_name)

func _run() -> void:
	DirAccess.make_dir_recursive_absolute(output)
	root.size = viewport_size
	root.position = Vector2i(0, 0)
	await process_frame
	app = MainScene.instantiate()
	root.add_child(app)
	await process_frame
	app.session.profile.settings.sound = false
	app.session.profile.settings.music = false
	app.session.profile.settings.haptics = false
	app._apply_settings()
	app._start_level(1)
	await _capture("game-01")
	app._start_level(8)
	await _capture("game-08")
	app._open_modal("queue")
	await _capture("queue")
	app._open_modal("")
	app._open_modal("settings")
	await _capture("settings")
	app._open_modal("help")
	await _capture("help")
	app._open_modal("")
	app._start_level(1000)
	await _capture("game-1000")
	app._set_inspection(true)
	await _capture("blueprint-1000")
	app._set_inspection(false)
	app._start_level(1)
	var route: Array = app.session.level.reference_solution
	for i: int in range(route.size() - 1):
		var result: Dictionary = app.session.select_screw(str(route[i]))
		assert(result.accepted)
	app._sync_board(true)
	app._select_screw(str(route.back()))
	await _capture("victory")
	assert(app.session.state.status == "WON")
	app._navigate("home")
	await _capture("home")
	app.level_page = 0
	app._navigate("levels")
	await _capture("levels-01")
	app.level_page = 39
	app._rebuild_controls()
	await _capture("levels-40")
	app._navigate("album")
	await _capture("collection")
	app._navigate("shop")
	await _capture("shop")
	app._start_level(8)
	for id: String in ["G3", "Y1", "Y2", "G1", "R1", "R2"]:
		assert(app.session.select_screw(id).accepted)
	app._sync_board(true)
	app._select_screw("Y3")
	await _capture("stuck")
	assert(app.session.state.status == "STUCK")
	if manifest.size() != 14:
		printerr("Capture failed: expected 14 screens, recorded ", manifest.size())
		quit(1)
		return
	var file := FileAccess.open(output.path_join("capture-%dx%d.json" % [viewport_size.x, viewport_size.y]), FileAccess.WRITE)
	file.store_string(JSON.stringify(manifest, "  "))
	print("CAPTURE PASS: ", manifest.size(), " actual App views")
	quit(0)
