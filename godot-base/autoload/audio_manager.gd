extends Node

## Music playback with crossfades, a small pool of SFX voices, and the glue
## that keeps the audio buses in sync with the player's settings.

signal caption_requested(text: String)

const BUS_MASTER := "Master"
const BUS_MUSIC := "Music"
const BUS_SFX := "SFX"

const SFX_VOICES := 8
const MIN_DB := -60.0
const PROCEDURAL_MIX_RATE := 22050

enum ProceduralSound {
	CHAINSAW_LOOP,
	CHAINSAW_START,
	CAN_SLICE,
	CAN_CLATTER,
}

## Placeholder UI sounds — swap these for your own.
const SFX_CLICK: AudioStream = preload("res://assets/audio/ui_click.wav")
const SFX_FOCUS: AudioStream = preload("res://assets/audio/ui_focus.wav")
const SFX_BACK: AudioStream = preload("res://assets/audio/ui_back.wav")

var _music: AudioStreamPlayer
var _music_next: AudioStreamPlayer
var _sfx_pool: Array[AudioStreamPlayer] = []
var _sfx_index := 0
var _music_tween: Tween
var _procedural_streams: Dictionary = {}
var _focus_bank: GameUISoundBank
var _last_focus_msec := -1


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
	if _music_tween and _music_tween.is_running():
		_music_tween.kill()
	_music_tween = null
	# During startup/crossfade the incoming voice has not become _music yet.
	if fade_time <= 0.0:
		_music.stop()
		_music_next.stop()
		return
	if not is_music_playing():
		return
	_music_tween = create_tween().set_parallel(true)
	for player: AudioStreamPlayer in [_music, _music_next]:
		if player.playing:
			_music_tween.tween_property(player, "volume_db", MIN_DB, fade_time)
	_music_tween.chain().tween_callback(_music.stop)
	_music_tween.tween_callback(_music_next.stop)


func is_music_playing() -> bool:
	return _music.playing or _music_next.playing


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
	var bank := GameCatalog.theme().ui_sounds
	if bank != null and bank.click != null:
		play_sfx(bank.click, bank.click_volume_db)
	else:
		play_sfx(SFX_CLICK)


func play_focus() -> void:
	var bank := GameCatalog.theme().ui_sounds
	if bank != _focus_bank:
		_focus_bank = bank
		_last_focus_msec = -1
	if bank == null or bank.focus == null:
		play_sfx(SFX_FOCUS, -4.0)
		return
	var now := Time.get_ticks_msec()
	if _last_focus_msec >= 0 and now - _last_focus_msec < bank.focus_cooldown_ms:
		return
	_last_focus_msec = now
	play_sfx(bank.focus, bank.focus_volume_db)


func play_back() -> void:
	var bank := GameCatalog.theme().ui_sounds
	if bank != null and bank.back != null:
		play_sfx(bank.back, bank.back_volume_db)
	else:
		play_sfx(SFX_BACK)


func play_game_hit(streak := 1) -> void:
	var pitch := clampf(0.98 + float(mini(streak, 10)) * 0.028, 0.98, 1.28)
	play_sfx(SFX_CLICK, -1.0, pitch)


func play_game_miss() -> void:
	play_sfx(SFX_BACK, -1.0, 0.78)


func chainsaw_motor_stream() -> AudioStreamWAV:
	return _procedural_stream(ProceduralSound.CHAINSAW_LOOP)


func play_chainsaw_start() -> void:
	play_sfx(_procedural_stream(ProceduralSound.CHAINSAW_START), -5.0)


func play_can_slice(streak := 1) -> void:
	var pitch := clampf(0.94 + float(mini(streak, 10)) * 0.026, 0.94, 1.2)
	play_sfx(_procedural_stream(ProceduralSound.CAN_SLICE), -1.0, pitch)
	_play_delayed_sfx(SFX_FOCUS, 0.025, -8.0, pitch * 1.18)


func play_can_clatter() -> void:
	play_sfx(_procedural_stream(ProceduralSound.CAN_CLATTER), -7.0, 0.94)


func play_achievement() -> void:
	play_sfx(SFX_FOCUS, -2.0, 1.16)
	_play_delayed_sfx(SFX_CLICK, 0.1, -1.0, 1.42)


func play_level_unlock() -> void:
	play_sfx(SFX_FOCUS, -1.0, 1.08)
	_play_delayed_sfx(SFX_CLICK, 0.08, -0.5, 1.28)
	_play_delayed_sfx(SFX_FOCUS, 0.18, -1.0, 1.42)
	_play_delayed_sfx(SFX_CLICK, 0.3, 0.0, 1.56)


func play_share() -> void:
	play_sfx(SFX_FOCUS, -2.0, 1.28)
	_play_delayed_sfx(SFX_CLICK, 0.08, -2.0, 1.12)


func play_splash() -> void:
	play_sfx(SFX_FOCUS, -7.0, 0.72)
	_play_delayed_sfx(SFX_CLICK, 0.16, -6.0, 0.92)


func request_caption(text: String) -> void:
	if Settings.audio_captions_enabled() and not text.is_empty():
		caption_requested.emit(text)


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


func _procedural_stream(kind: int) -> AudioStreamWAV:
	if _procedural_streams.has(kind):
		return _procedural_streams[kind] as AudioStreamWAV

	var duration := 0.3
	var looping := false
	match kind:
		ProceduralSound.CHAINSAW_LOOP:
			duration = 0.5
			looping = true
		ProceduralSound.CHAINSAW_START:
			duration = 0.7
		ProceduralSound.CAN_SLICE:
			duration = 0.24
		ProceduralSound.CAN_CLATTER:
			duration = 0.38

	var sample_count := maxi(int(PROCEDURAL_MIX_RATE * duration), 1)
	var data := PackedByteArray()
	data.resize(sample_count * 2)
	for sample_index in range(sample_count):
		var time := float(sample_index) / float(PROCEDURAL_MIX_RATE)
		var progress := float(sample_index) / float(maxi(sample_count - 1, 1))
		var sample := clampf(
			_procedural_sample(kind, time, progress, sample_index),
			-1.0,
			1.0
		)
		data.encode_s16(sample_index * 2, roundi(sample * 32767.0))

	var stream := AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_16_BITS
	stream.mix_rate = PROCEDURAL_MIX_RATE
	stream.stereo = false
	stream.data = data
	if looping:
		stream.loop_mode = AudioStreamWAV.LOOP_FORWARD
		stream.loop_begin = 0
		stream.loop_end = sample_count
	_procedural_streams[kind] = stream
	return stream


func _procedural_sample(
	kind: int,
	time: float,
	progress: float,
	sample_index: int
) -> float:
	match kind:
		ProceduralSound.CHAINSAW_LOOP:
			var motor_pulse := 0.9 + sin(TAU * 12.0 * time) * 0.08
			return (
				sin(TAU * 72.0 * time) * 0.3
				+ sin(TAU * 144.0 * time + 0.35) * 0.22
				+ sin(TAU * 432.0 * time) * 0.13
				+ sin(TAU * 936.0 * time + 0.8) * 0.07
			) * motor_pulse
		ProceduralSound.CHAINSAW_START:
			var start_envelope := sin(progress * PI)
			var sweep := lerpf(42.0, 126.0, pow(progress, 0.72))
			return (
				sin(TAU * sweep * time) * 0.38
				+ sin(TAU * sweep * 2.03 * time) * 0.2
				+ _procedural_noise(sample_index) * 0.08
			) * start_envelope
		ProceduralSound.CAN_SLICE:
			var cut_attack := minf(progress * 24.0, 1.0)
			var cut_decay := exp(-progress * 7.5)
			return (
				_procedural_noise(sample_index) * 0.46
				+ sin(TAU * (880.0 + progress * 720.0) * time) * 0.34
				+ sin(TAU * 118.0 * time) * 0.18
			) * cut_attack * cut_decay
		ProceduralSound.CAN_CLATTER:
			var clatter_attack := minf(progress * 30.0, 1.0)
			var clatter_decay := exp(-progress * 4.8)
			var second_impact := (
				sin(TAU * 168.0 * (time - 0.09)) * 0.28
				if time >= 0.09
				else 0.0
			)
			return (
				sin(TAU * 84.0 * time) * 0.34
				+ second_impact
				+ _procedural_noise(sample_index) * 0.2
			) * clatter_attack * clatter_decay
	return 0.0


func _procedural_noise(sample_index: int) -> float:
	var value := sin(float(sample_index) * 12.9898 + 78.233) * 43758.5453
	return (value - floor(value)) * 2.0 - 1.0


## Wires click/focus sounds into every button under [param root], and makes
## hovering move the focus so mouse and gamepad highlight the same control.
func attach_ui_sounds(root: Node) -> void:
	var custom_bank := GameCatalog.theme().ui_sounds != null
	for node in root.find_children("*", "BaseButton", true, false):
		var button := node as BaseButton
		if button.has_meta("ui_sounds"):
			continue
		button.set_meta("ui_sounds", true)
		# Custom cues must not layer a confirm over a handler-owned back cue.
		# Unskinned games retain their existing sound wiring.
		if not (custom_bank and bool(button.get_meta("ui_sound_handled", false))):
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
