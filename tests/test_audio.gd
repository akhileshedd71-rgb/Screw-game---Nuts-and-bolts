extends SceneTree

const Audio = preload("res://scripts/services/audio_service.gd")

func _initialize() -> void:
	call_deferred("_check")

func _check() -> void:
	var audio := Audio.new()
	audio.set_enabled(false, false)
	root.add_child(audio)
	assert(audio._voices.size() == 6)
	assert(not audio._music.playing)
	audio.set_enabled(true, false)
	for event in ["tap", "release", "complete", "undo", "click", "win"]:
		audio.play(event)
	assert(audio._voices.size() == 6)
	assert(audio._last_play.size() == 6)
	audio.play("complete")
	assert(audio._variants["complete"] == 1)
	audio.play("unknown-event")
	audio.set_enabled(false, true)
	for voice in audio._voices:
		assert(not voice.playing)
	assert(audio._music.playing)
	assert(audio._music.stream.loop_mode == AudioStreamWAV.LOOP_FORWARD)
	audio._notification(Node.NOTIFICATION_APPLICATION_PAUSED)
	assert(audio._music.stream_paused)
	audio._notification(Node.NOTIFICATION_APPLICATION_RESUMED)
	assert(not audio._music.stream_paused)
	assert(AudioServer.get_bus_index("SFX") > 0)
	assert(AudioServer.get_bus_index("UI") > 0)
	assert(AudioServer.get_bus_volume_db(AudioServer.get_bus_index("Music")) == -24.0)
	for path in ["res://assets/fonts/LilitaOne-Regular.ttf", "res://assets/fonts/Nunito-Regular.ttf", "res://assets/fonts/Nunito-ExtraBold.ttf"]:
		assert(load(path) is FontFile)
	print("AUDIO PASS: preloads, fonts, 6 voices, event coalescing, independent toggles, pause/resume, looping music, buses")
	audio.set_enabled(false, false)
	await create_timer(0.1).timeout
	audio.free()
	await create_timer(0.1).timeout
	quit()
