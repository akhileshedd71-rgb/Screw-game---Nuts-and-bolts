class_name AudioService
extends Node
## Presentation-only audio. Missing audio devices never affect puzzle outcomes.
## Own one instance under the app; all WAVs are small preloaded PCM masters.

const MAX_VOICES: int = 6
const SOUNDS: Dictionary = {
	"click": [preload("res://assets/audio/click_1.wav"), preload("res://assets/audio/click_2.wav"), preload("res://assets/audio/click_3.wav")],
	"tap": [preload("res://assets/audio/extract_1.wav"), preload("res://assets/audio/extract_2.wav"), preload("res://assets/audio/extract_3.wav")],
	"release": [preload("res://assets/audio/wood_1.wav"), preload("res://assets/audio/wood_2.wav"), preload("res://assets/audio/wood_3.wav")],
	"complete": [preload("res://assets/audio/complete_1.wav"), preload("res://assets/audio/complete_2.wav"), preload("res://assets/audio/complete_3.wav")],
	"undo": [preload("res://assets/audio/undo_1.wav"), preload("res://assets/audio/undo_2.wav"), preload("res://assets/audio/undo_3.wav")],
	"win": [preload("res://assets/audio/victory.wav")],
}
const AMBIENCE: AudioStreamWAV = preload("res://assets/audio/workshop_ambience.wav")

var sound_enabled: bool = true
var music_enabled: bool = true
var _voices: Array[AudioStreamPlayer] = []
var _music: AudioStreamPlayer
var _next_voice: int = 0
var _variants: Dictionary = {}
var _last_play: Dictionary = {}
var _suspended: bool = false


func _ready() -> void:
	_make_bus("SFX", -4.0)
	_make_bus("UI", -7.0)
	_make_bus("Music", -24.0)
	for _i in range(MAX_VOICES):
		var voice := AudioStreamPlayer.new()
		voice.bus = "SFX"
		add_child(voice)
		_voices.append(voice)
	_music = AudioStreamPlayer.new()
	_music.bus = "Music"
	# Duplicate the imported resource so editor playback settings stay unchanged.
	var loop := AMBIENCE.duplicate() as AudioStreamWAV
	loop.loop_mode = AudioStreamWAV.LOOP_FORWARD
	loop.loop_begin = 0
	loop.loop_end = int(loop.get_length() * loop.mix_rate)
	_music.stream = loop
	add_child(_music)
	_apply_settings()


func play(event: String) -> void:
	if not sound_enabled or _suspended or _voices.is_empty():
		return
	var key: String = {
		"extract": "tap", "wood": "release", "victory": "win",
		"seat": "click", "button": "click", "ui": "click",
	}.get(event, event)
	if not SOUNDS.has(key):
		return
	var now: int = Time.get_ticks_msec()
	# A large cascade still sounds like one restrained completion gesture.
	if now - int(_last_play.get(key, -1000)) < 70:
		return
	_last_play[key] = now
	var options: Array = SOUNDS[key]
	var next_variant: int = int(_variants.get(key, 0))
	_variants[key] = next_variant + 1
	var voice: AudioStreamPlayer = _voices[_next_voice]
	_next_voice = (_next_voice + 1) % MAX_VOICES
	# Prefer an idle player; round-robin stealing bounds even rapid input to 6.
	for candidate in _voices:
		if not candidate.playing:
			voice = candidate
			break
	voice.stop()
	voice.bus = "UI" if key in ["click", "undo"] else "SFX"
	voice.stream = options[next_variant % options.size()] as AudioStream
	voice.play()


func set_enabled(sound: bool, music: bool) -> void:
	sound_enabled = sound
	music_enabled = music
	_apply_settings()


func _apply_settings() -> void:
	if not sound_enabled:
		for voice in _voices:
			voice.stop()
	if not is_instance_valid(_music):
		return
	if music_enabled:
		if not _music.playing:
			_music.play()
		_music.stream_paused = _suspended
	else:
		_music.stop()


func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_PAUSED:
		_suspended = true
		for voice in _voices:
			voice.stop()
		_apply_settings()
	elif what == NOTIFICATION_APPLICATION_RESUMED:
		_suspended = false
		_apply_settings()


func _make_bus(bus_name: String, volume: float) -> void:
	if AudioServer.get_bus_index(bus_name) >= 0:
		return
	AudioServer.add_bus()
	var index: int = AudioServer.bus_count - 1
	AudioServer.set_bus_name(index, bus_name)
	AudioServer.set_bus_send(index, "Master")
	AudioServer.set_bus_volume_db(index, volume)
