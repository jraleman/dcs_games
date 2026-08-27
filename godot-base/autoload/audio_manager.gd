extends Node

## Music playback with crossfades, a small pool of SFX voices, and the glue
## that keeps the audio buses in sync with the player's settings.

const BUS_MASTER := "Master"
const BUS_MUSIC := "Music"
const BUS_SFX := "SFX"

const SFX_VOICES := 8
const MIN_DB := -60.0

## Placeholder UI sounds — swap these for your own.
const SFX_CLICK: AudioStream = preload("res://assets/audio/ui_click.wav")
const SFX_FOCUS: AudioStream = preload("res://assets/audio/ui_focus.wav")
const SFX_BACK: AudioStream = preload("res://assets/audio/ui_back.wav")

var _music: AudioStreamPlayer
var _music_next: AudioStreamPlayer
var _sfx_pool: Array[AudioStreamPlayer] = []
var _sfx_index := 0
var _music_tween: Tween


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS

	_music = _make_player(BUS_MUSIC)
	_music_next = _make_player(BUS_MUSIC)
	for i in SFX_VOICES:
		_sfx_pool.append(_make_player(BUS_SFX))

	Settings.changed.connect(_on_setting_changed)
	_apply_all_volumes()


func _make_player(bus: String) -> AudioStreamPlayer:
	var player := AudioStreamPlayer.new()
	player.bus = bus
	player.process_mode = Node.PROCESS_MODE_ALWAYS
	add_child(player)
	return player


# --- Music ------------------------------------------------------------------

## Crossfades to [param stream]. Passing the stream that is already playing
## does nothing, so menus can call this freely on every screen.
func play_music(stream: AudioStream, fade_time := 0.8) -> void:
	if stream == null:
		stop_music(fade_time)
		return
	if _music.stream == stream and _music.playing:
		return

	if _music_tween and _music_tween.is_running():
		_music_tween.kill()

	_music_next.stream = stream
	_music_next.volume_db = MIN_DB
	_music_next.play()

	_music_tween = create_tween().set_parallel(true)
	_music_tween.tween_property(_music_next, "volume_db", 0.0, fade_time)
	if _music.playing:
		_music_tween.tween_property(_music, "volume_db", MIN_DB, fade_time)
	_music_tween.chain().tween_callback(_swap_music_players)


func stop_music(fade_time := 0.8) -> void:
	if not _music.playing:
		return
	if _music_tween and _music_tween.is_running():
		_music_tween.kill()
	_music_tween = create_tween()
	_music_tween.tween_property(_music, "volume_db", MIN_DB, fade_time)
	_music_tween.tween_callback(_music.stop)


func is_music_playing() -> bool:
	return _music.playing


func _swap_music_players() -> void:
	_music.stop()
	var previous := _music
	_music = _music_next
	_music_next = previous


# --- Sound effects ----------------------------------------------------------

func play_sfx(stream: AudioStream, volume_db := 0.0, pitch_scale := 1.0) -> void:
	if stream == null:
		return
	# Round-robin so a burst of sounds never cuts itself off.
	var player := _sfx_pool[_sfx_index]
	_sfx_index = (_sfx_index + 1) % _sfx_pool.size()
	player.stream = stream
	player.volume_db = volume_db
	player.pitch_scale = pitch_scale
	player.play()


func play_click() -> void:
	play_sfx(SFX_CLICK)


func play_focus() -> void:
	play_sfx(SFX_FOCUS, -4.0)


func play_back() -> void:
	play_sfx(SFX_BACK)


func play_game_hit(streak := 1) -> void:
	var pitch := clampf(0.98 + float(mini(streak, 10)) * 0.028, 0.98, 1.28)
	play_sfx(SFX_CLICK, -1.0, pitch)


func play_game_miss() -> void:
	play_sfx(SFX_BACK, -1.0, 0.78)


func play_achievement() -> void:
	play_sfx(SFX_FOCUS, -2.0, 1.16)
	_play_delayed_sfx(SFX_CLICK, 0.1, -1.0, 1.42)


func play_share() -> void:
	play_sfx(SFX_FOCUS, -2.0, 1.28)
	_play_delayed_sfx(SFX_CLICK, 0.08, -2.0, 1.12)


func play_splash() -> void:
	play_sfx(SFX_FOCUS, -7.0, 0.72)
	_play_delayed_sfx(SFX_CLICK, 0.16, -6.0, 0.92)


func _play_delayed_sfx(
	stream: AudioStream,
	delay: float,
	volume_db: float,
	pitch_scale: float
) -> void:
	var tween := create_tween()
	tween.tween_interval(delay)
	tween.tween_callback(
		Callable(self, "play_sfx").bind(stream, volume_db, pitch_scale)
	)


## Wires click/focus sounds into every button under [param root], and makes
## hovering move the focus so mouse and gamepad highlight the same control.
func attach_ui_sounds(root: Node) -> void:
	for node in root.find_children("*", "BaseButton", true, false):
		var button := node as BaseButton
		if button.has_meta("ui_sounds"):
			continue
		button.set_meta("ui_sounds", true)
		button.pressed.connect(play_click)
		button.focus_entered.connect(play_focus)
		button.mouse_entered.connect(_on_button_hovered.bind(button))


func _on_button_hovered(button: BaseButton) -> void:
	if button.focus_mode != Control.FOCUS_NONE and not button.disabled:
		button.grab_focus()


# --- Volume -----------------------------------------------------------------

## [param linear] is 0..1, the scale sliders use.
func set_bus_volume(bus_name: String, linear: float) -> void:
	var idx := AudioServer.get_bus_index(bus_name)
	if idx < 0:
		push_warning("Missing audio bus: %s" % bus_name)
		return
	AudioServer.set_bus_volume_db(idx, linear_to_db(clampf(linear, 0.0, 1.0)))
	AudioServer.set_bus_mute(idx, is_zero_approx(linear))


func _apply_all_volumes() -> void:
	var muted: bool = Settings.get_value("audio/muted")
	set_bus_volume(BUS_MASTER, 0.0 if muted else float(Settings.get_value("audio/master")))
	set_bus_volume(BUS_MUSIC, float(Settings.get_value("audio/music")))
	set_bus_volume(BUS_SFX, float(Settings.get_value("audio/sfx")))


func _on_setting_changed(key: String, _value: Variant) -> void:
	if key.begins_with("audio/"):
		_apply_all_volumes()
