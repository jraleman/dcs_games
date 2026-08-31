extends Node2D

## Fast score-chasing game for solo play, local multiplayer or a CPU opponent.

@export_file("*.tscn") var pause_scene := "res://scenes/menus/pause_menu.tscn"
@export_file("*.tscn") var main_menu_scene := "res://scenes/menus/main_menu.tscn"
@export var target_scene: PackedScene
@export var player_one_inactive_color := Color("31556f")
@export var player_one_highlight_color := Color("4da3ff")
@export var player_two_inactive_color := Color("6b343d")
@export var player_two_highlight_color := Color("ff5c6c")
@export_range(100.0, 800.0, 10.0) var target_speed := 320.0
# Design-time defaults for the round; players can override the round length
# and the end-of-round speed rush under Settings → Game.
@export_range(0.0, 1.0, 0.05) var final_speed_boost := 0.35
@export_range(5.0, 180.0, 1.0) var round_duration := 30.0
@export_range(1, 100, 1) var points_per_match := 1
@export_range(1, 100, 1) var miss_penalty := 1

## Drop a gameplay track here to have it fade in when the scene starts.
@export var music: AudioStream

const PLAYER_ONE := 0
const PLAYER_TWO := 1
const PLAYER_COUNT := 2
const SIDE_CLEARANCE := 38.0
const TOP_CLEARANCE := 190.0
const BOTTOM_CLEARANCE := 105.0
const SPAWN_ATTEMPTS := 20
const BACKGROUND_TRIANGLE_COUNT := 12
const BURST_SHARDS := 9
const DANGER_SECONDS := 8.0
const SHAKE_DECAY := 30.0
const MISS_COLOR := Color("ffc857")
const DANGER_COLOR := Color("ff4964")

@onready var _targets_root: Node2D = %Targets
@onready var _world_fx: Node2D = %WorldFX
@onready var _hud: CanvasLayer = %HUD
@onready var _screen_flash: ColorRect = %ScreenFlash
@onready var _danger_overlay: ColorRect = %DangerOverlay
@onready var _player_one_card: PanelContainer = %PlayerOneCard
@onready var _player_one_caption: Label = (
	$HUD/Overlay/Margins/Layout/TopBar/PlayerOneCard/Layout/Caption
)
@onready var _player_one_score: Label = %PlayerOneScore
@onready var _player_two_score: Label = %PlayerTwoScore
@onready var _player_one_streak: Label = %PlayerOneStreak
@onready var _player_two_streak: Label = %PlayerTwoStreak
@onready var _player_two_card: PanelContainer = %PlayerTwoCard
@onready var _player_two_caption: Label = (
	$HUD/Overlay/Margins/Layout/TopBar/PlayerTwoCard/Layout/Caption
)
@onready var _time_label: Label = %TimeLabel
@onready var _mode_title: Label = %ModeTitle
@onready var _time_progress: ProgressBar = %TimeProgress
@onready var _callout: Label = %Callout
@onready var _hint: Label = %Hint
@onready var _announcement: Label = %Announcement
@onready var _round_timer: Timer = %RoundTimer
@onready var _round_over: Control = %RoundOver
@onready var _round_panel: PanelContainer = %RoundPanel
@onready var _score_panel: PanelContainer = %ScorePanel
@onready var _result_label: Label = %ResultLabel
@onready var _round_subtitle: Label = %RoundSubtitle
@onready var _round_player_one_score: Label = %RoundPlayerOneScore
@onready var _round_player_two_score: Label = %RoundPlayerTwoScore
@onready var _round_versus: Label = (
	$HUD/RoundOver/Center/RoundPanel/Layout/ScoreShowdown/Versus
)
@onready var _round_player_two_card: PanelContainer = %PlayerTwoScoreCard
@onready var _round_player_two_caption: Label = (
	$HUD/RoundOver/Center/RoundPanel/Layout/ScoreShowdown/PlayerTwoScoreCard/Layout/Caption
)
@onready var _round_highlight: Label = %RoundHighlight
@onready var _round_instructions: Label = %RoundInstructions
@onready var _see_score_button: Button = %SeeScoreButton
@onready var _share_button: Button = %ShareButton
@onready var _play_again_button: Button = %PlayAgainButton
@onready var _score_screen_title: Label = %ScoreScreenTitle
@onready var _score_screen_subtitle: Label = %ScoreScreenSubtitle
@onready var _game_duration_stat: Label = %GameDurationStat
@onready var _game_hits_stat: Label = %GameHitsStat
@onready var _game_accuracy_stat: Label = %GameAccuracyStat
@onready var _player_one_stats_score: Label = %PlayerOneStatsScore
@onready var _player_one_stats_hits: Label = %PlayerOneStatsHits
@onready var _player_one_stats_misses: Label = %PlayerOneStatsMisses
@onready var _player_one_stats_accuracy: Label = %PlayerOneStatsAccuracy
@onready var _player_one_stats_streak: Label = %PlayerOneStatsStreak
@onready var _player_two_stats_score: Label = %PlayerTwoStatsScore
@onready var _player_two_stats_hits: Label = %PlayerTwoStatsHits
@onready var _player_two_stats_misses: Label = %PlayerTwoStatsMisses
@onready var _player_two_stats_accuracy: Label = %PlayerTwoStatsAccuracy
@onready var _player_two_stats_streak: Label = %PlayerTwoStatsStreak
@onready var _stats_versus: Label = $HUD/RoundOver/Center/ScorePanel/Layout/Players/Versus
@onready var _player_two_stats_card: PanelContainer = (
	$HUD/RoundOver/Center/ScorePanel/Layout/Players/PlayerTwo
)
@onready var _player_two_stats_title: Label = (
	$HUD/RoundOver/Center/ScorePanel/Layout/Players/PlayerTwo/Layout/Title
)
@onready var _back_to_results_button: Button = %BackToResultsButton
@onready var _stats_share_button: Button = %StatsShareButton
@onready var _share_status: Label = %ShareStatus

var _targets: Array[TriangleTarget] = []
var _targets_by_action: Dictionary = {}
var _active_targets := [null, null]
var _scores := [0, 0]
var _streaks := [0, 0]
var _correct_hits := [0, 0]
var _misses := [0, 0]
var _best_streaks := [0, 0]
var _rng := RandomNumberGenerator.new()
var _displayed_seconds := -1
var _round_active := false
var _ambient_time := 0.0
var _intense_effects_enabled := true
var _reduced_motion_enabled := false
var _shake_strength := 0.0
var _pause_menu: MenuScreen
var _score_tweens: Array = [null, null]
var _streak_tweens: Array = [null, null]
var _announcement_tween: Tween
var _flash_tween: Tween
var _round_panel_tween: Tween
var _share_status_tween: Tween
var _cpu_action_time := -1.0
var _round_achievements: Array[Dictionary] = []
var _round_result_color := GameInfo.SKY
var _sharing := false
var _cpu_reaction_min := 0.55
var _cpu_reaction_max := 1.05
var _cpu_accuracy := 0.82
var _round_progression_notes := PackedStringArray()
var _round_length := 30.0
var _active_round_duration := 30.0
var _round_gameplay_speed := 1.0
var _round_target_size := 1.0
var _round_triangle_speed := 1.0
var _round_triangle_size := 1.0
var _round_speed_rush := 0.35


func _ready() -> void:
	_rng.randomize()
	GameSession.ensure_controller_assignments()
	_intense_effects_enabled = Settings.visual_effects_enabled()
	_reduced_motion_enabled = Settings.reduced_motion_enabled()
	_load_round_settings()
	Settings.changed.connect(_on_setting_changed)
	_configure_cpu_profile()
	_configure_mode_ui()
	_player_one_score.add_theme_color_override("font_color", player_one_highlight_color)
	_player_two_score.add_theme_color_override("font_color", player_two_highlight_color)
	_player_one_streak.add_theme_color_override("font_color", player_one_highlight_color)
	_player_two_streak.add_theme_color_override("font_color", player_two_highlight_color)
	_time_progress.max_value = _active_round_duration
	_time_progress.value = _active_round_duration
	AudioManager.attach_ui_sounds(_hud)

	if music:
		AudioManager.play_music(music)

	_create_targets()
	if _has_targets_for_every_player():
		_update_hint()
		_start_round()


func _process(delta: float) -> void:
	if not _reduced_motion_enabled:
		_ambient_time += delta
	queue_redraw()
	_update_screen_shake(delta)

	if not _round_active:
		return

	var time_left := _round_timer.time_left
	var time_ratio := clampf(
		time_left / maxf(_active_round_duration, 0.001),
		0.0,
		1.0
	)
	var speed_multiplier := lerpf(1.0, 1.0 + _round_speed_rush, 1.0 - time_ratio)
	var bounds := _target_bounds()
	for target in _targets:
		target.move_speed = _target_move_speed(speed_multiplier)
		target.move_and_bounce(delta, bounds)
	_update_cpu(delta)

	_time_progress.value = time_left
	_update_urgency(time_left)

	var seconds_left := int(ceil(time_left))
	if seconds_left != _displayed_seconds:
		_update_time(seconds_left)


func _draw() -> void:
	var viewport_size := get_viewport_rect().size
	if viewport_size.x <= 0.0 or viewport_size.y <= 0.0:
		return

	var multiplayer := GameSession.player_two_enabled()
	var left_glow := _with_alpha(player_one_highlight_color, 0.035)
	var glow_radius := viewport_size.y * 0.36
	draw_circle(
		Vector2(viewport_size.x * (0.18 if multiplayer else 0.5), viewport_size.y * 0.57),
		glow_radius + sin(_ambient_time * 0.8) * 18.0,
		left_glow
	)
	if multiplayer:
		var right_glow := _with_alpha(player_two_highlight_color, 0.035)
		draw_circle(
			Vector2(viewport_size.x * 0.82, viewport_size.y * 0.57),
			glow_radius + cos(_ambient_time * 0.72) * 18.0,
			right_glow
		)

		var divider_color := Color(0.78, 0.9, 0.96, 0.1)
		var divider_x := viewport_size.x * 0.5
		var divider_end := int(viewport_size.y - BOTTOM_CLEARANCE)
		for y in range(int(TOP_CLEARANCE), divider_end, 34):
			draw_line(
				Vector2(divider_x, y),
				Vector2(divider_x, minf(y + 15.0, divider_end)),
				divider_color,
				2.0,
				true
			)

	for index in range(BACKGROUND_TRIANGLE_COUNT):
		var on_left := not multiplayer or index % 2 == 0
		var lane_start := 0.04 if on_left else 0.54
		var lane_width := 0.4
		if not multiplayer:
			lane_start = 0.08
			lane_width = 0.84
		var normalized_x := lane_start + fmod(float(index) * 0.173, lane_width)
		var normalized_y := 0.23 + fmod(float(index) * 0.217, 0.66)
		var drift := Vector2(
			sin(_ambient_time * 0.32 + index * 1.7) * 16.0,
			cos(_ambient_time * 0.27 + index * 1.3) * 12.0
		)
		var center := Vector2(
			viewport_size.x * normalized_x,
			viewport_size.y * normalized_y
		) + drift
		var radius := 22.0 + float(index % 3) * 12.0
		var rotation := _ambient_time * (0.08 if on_left else -0.08) + index
		var color := (
			_with_alpha(player_one_highlight_color, 0.085)
			if on_left
			else _with_alpha(player_two_highlight_color, 0.085)
		)
		draw_polyline(_triangle_outline(center, radius, rotation), color, 1.5, true)


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("pause"):
		get_viewport().set_input_as_handled()
		if _round_over.visible and _score_panel.visible:
			_show_round_results()
			return
		open_pause_menu()
		return

	if not _round_active:
		return

	var target: TriangleTarget
	if event is InputEventKey:
		var key_event := event as InputEventKey
		if not key_event.pressed or key_event.echo:
			return
		target = _target_for_keyboard_event(key_event)
	elif event is InputEventJoypadButton:
		var joypad_event := event as InputEventJoypadButton
		if not joypad_event.pressed:
			return
		target = _target_for_controller_event(joypad_event)
	else:
		return

	if target == null:
		return
	if not _player_accepts_human_input(target.player_index):
		return

	get_viewport().set_input_as_handled()
	_attempt_target(target)


func _target_for_keyboard_event(event: InputEventKey) -> TriangleTarget:
	for action: StringName in _targets_by_action:
		if event.is_action_pressed(action):
			var target := _targets_by_action[action] as TriangleTarget
			if Settings.one_button_target_rush_enabled() and target != null:
				return _active_targets[target.player_index] as TriangleTarget
			return target
	return null


func _target_for_controller_event(event: InputEventJoypadButton) -> TriangleTarget:
	var target_index := Settings.controller_target_index(event.button_index)
	if target_index < 0:
		return null

	var player_index := _controller_player_index(event.device)
	if not _player_accepts_human_input(player_index):
		return null
	if Settings.one_button_target_rush_enabled():
		return _active_targets[player_index] as TriangleTarget

	var actions := Settings.control_actions_for_player(player_index)
	if target_index >= actions.size():
		return null
	return _targets_by_action.get(actions[target_index]) as TriangleTarget


func _controller_player_index(device: int) -> int:
	return GameSession.controller_player_index(device)


func _configure_mode_ui() -> void:
	var player_two_enabled := GameSession.player_two_enabled()
	var player_two_title := GameSession.player_two_name().to_upper()
	var player_one_keys := Settings.control_summary(PLAYER_ONE, "  ")
	var player_two_keys := Settings.control_summary(PLAYER_TWO, "  ")
	var mapped_buttons := Settings.controller_target_summary(" / ")
	var controller_keys := (
		"ANY %s" % mapped_buttons
		if Settings.one_button_target_rush_enabled()
		else mapped_buttons
	)
	_mode_title.text = "TRIANGLE RUSH"

	_player_one_caption.text = (
		"PLAYER 1 · KEYS %s · PAD %s" % [player_one_keys, controller_keys]
		if player_two_enabled
		else "PLAYER 1 · SOLO · KEYS %s · PAD %s" % [player_one_keys, controller_keys]
	)
	_player_one_card.size_flags_horizontal = (
		Control.SIZE_SHRINK_BEGIN if player_two_enabled else Control.SIZE_EXPAND_FILL
	)
	_player_two_card.visible = player_two_enabled
	_player_two_caption.text = (
		"%s · %s · AUTO" % [player_two_title, GameSession.cpu_difficulty_title().to_upper()]
		if GameSession.player_two_is_cpu()
		else "%s · KEYS %s · PAD 2 %s" % [
			player_two_title,
			player_two_keys,
			controller_keys,
		]
	)
	_round_versus.visible = player_two_enabled
	_round_player_two_card.visible = player_two_enabled
	_round_player_two_caption.text = player_two_title
	_stats_versus.visible = player_two_enabled
	_player_two_stats_card.visible = player_two_enabled
	_player_two_stats_title.text = player_two_title
	_update_callout()


func _on_setting_changed(key: String, _value: Variant) -> void:
	if key == Settings.VISUAL_EFFECTS_KEY:
		_set_intense_effects_enabled(Settings.visual_effects_enabled())
		return
	if key == Settings.REDUCED_MOTION_KEY:
		_set_reduced_motion_enabled(bool(_value))
		return
	if key == Settings.PLAYER_LABELS_KEY:
		for target in _targets:
			target.set_player_label_visible(Settings.player_labels_enabled())
		_update_hint()
		return
	if key == Settings.ONE_BUTTON_TARGET_RUSH_KEY:
		_configure_mode_ui()
		_update_hint()
		return
	if not key.begins_with("controls/"):
		return

	for action: StringName in _targets_by_action:
		var target := _targets_by_action[action] as TriangleTarget
		if is_instance_valid(target):
			target.set_display_letter(Settings.control_key_label(action).to_upper())
	_configure_mode_ui()
	_update_hint()


func _set_intense_effects_enabled(value: bool) -> void:
	_intense_effects_enabled = value
	if not value:
		_reset_intense_effects()


func _set_reduced_motion_enabled(value: bool) -> void:
	_reduced_motion_enabled = value
	for target in _targets:
		target.set_reduced_motion(value)
	if value:
		_ambient_time = 0.0
		_reset_reduced_motion_state()
	_update_callout()
	queue_redraw()


## Reads the base-game triangle options and the next-round assists together, so
## both only take effect when a round starts.
func _load_round_settings() -> void:
	_round_length = Settings.triangle_round_length()
	_round_triangle_speed = Settings.triangle_speed_scale()
	_round_triangle_size = Settings.triangle_size_scale()
	_round_speed_rush = Settings.triangle_speed_rush()
	_active_round_duration = _round_length + Settings.extra_round_time()
	_round_gameplay_speed = Settings.gameplay_speed_scale()
	_round_target_size = Settings.target_size_scale()


## Scene speed combined with the triangle-speed option, the assist and the
## optional end-of-round rush.
func _target_move_speed(rush_multiplier := 1.0) -> float:
	return target_speed * _round_triangle_speed * _round_gameplay_speed * rush_multiplier


## Triangle-size option combined with the handicap assist.
func _target_size_scale() -> float:
	return _round_triangle_size * _round_target_size


func _active_player_indices() -> Array[int]:
	var players: Array[int] = [PLAYER_ONE]
	if GameSession.player_two_enabled():
		players.append(PLAYER_TWO)
	return players


func _player_accepts_human_input(player_index: int) -> bool:
	if player_index == PLAYER_ONE:
		return true
	return player_index == PLAYER_TWO and (
		GameSession.player_two_enabled() and not GameSession.player_two_is_cpu()
	)


func _configure_cpu_profile() -> void:
	var profile := GameSession.cpu_profile()
	_cpu_reaction_min = float(profile.get("reaction_min", _cpu_reaction_min))
	_cpu_reaction_max = float(profile.get("reaction_max", _cpu_reaction_max))
	_cpu_accuracy = float(profile.get("accuracy", _cpu_accuracy))


func _update_cpu(delta: float) -> void:
	if not _round_active or not GameSession.player_two_is_cpu():
		return

	_cpu_action_time -= delta
	if _cpu_action_time > 0.0:
		return

	var active_target := _active_targets[PLAYER_TWO] as TriangleTarget
	if not is_instance_valid(active_target):
		_schedule_cpu_action()
		return

	var chosen_target := active_target
	if _rng.randf() > _cpu_accuracy:
		var alternatives := _targets_for_player(PLAYER_TWO)
		alternatives.erase(active_target)
		if not alternatives.is_empty():
			chosen_target = alternatives[_rng.randi_range(0, alternatives.size() - 1)]

	_attempt_target(chosen_target, true)
	if chosen_target != active_target:
		_schedule_cpu_action()


func _schedule_cpu_action() -> void:
	var minimum := minf(_cpu_reaction_min, _cpu_reaction_max)
	var maximum := maxf(_cpu_reaction_min, _cpu_reaction_max)
	_cpu_action_time = _rng.randf_range(minimum, maximum)


func _update_hint() -> void:
	if DisplayServer.is_touchscreen_available():
		if GameSession.is_single_player():
			_hint.text = "Tap P1's highlighted triangle | Correct +%d | Wrong -%d" % [
				points_per_match,
				miss_penalty,
			]
		elif GameSession.player_two_is_cpu():
			_hint.text = (
				"Tap P1's highlighted triangle | CPU uses P2 | Correct +%d"
				% points_per_match
			)
		else:
			_hint.text = "Tap your glowing triangle | Correct +%d | Wrong -%d" % [
				points_per_match,
				miss_penalty,
			]
	elif Settings.one_button_target_rush_enabled():
		var mapped_buttons := Settings.controller_target_summary("/")
		if GameSession.is_single_player():
			_hint.text = (
				"Press any P1 key or %s   |   " % mapped_buttons
				+ "Follow the highlighted target   |   Correct +%d"
				% points_per_match
			)
		elif GameSession.player_two_is_cpu():
			_hint.text = (
				"Any P1 key or %s   |   Follow your highlighted target   |   "
				% mapped_buttons
				+ "CPU controls P2"
			)
		else:
			_hint.text = (
				"Any assigned key or mapped controller button activates "
				+ "each player's highlighted target"
			)
	else:
		var controller_keys := Settings.controller_target_summary(" ")
		if GameSession.is_single_player():
			_hint.text = (
				"P1 keys: %s   |   Pad: %s   |   Follow the highlighted target"
			) % [
				_letters_hint(PLAYER_ONE),
				controller_keys,
			]
		elif GameSession.player_two_is_cpu():
			_hint.text = "P1: %s / pad %s   |   %s CPU controls P2" % [
				_letters_hint(PLAYER_ONE),
				controller_keys,
				GameSession.cpu_difficulty_title(),
			]
		else:
			_hint.text = "P1: %s / pad 1   |   P2: %s / pad 2   |   %s" % [
				_letters_hint(PLAYER_ONE),
				_letters_hint(PLAYER_TWO),
				Settings.controller_target_summary(" "),
			]
	if Settings.one_button_target_rush_enabled():
		_round_instructions.text = (
			"Any assigned key/button hits your highlighted target: +%d | "
			+ "Wrong triangle: -%d"
		) % [
			points_per_match,
			miss_penalty,
		]
	else:
		_round_instructions.text = (
			"Correct match: +%d | Wrong key or triangle: -%d"
			% [points_per_match, miss_penalty]
		)


func _update_callout() -> void:
	var cue := "HIGHLIGHT" if _reduced_motion_enabled else "PULSE"
	var control := (
		"ANY ASSIGNED CONTROL"
		if Settings.one_button_target_rush_enabled()
		else "THE MATCHING CONTROL"
	)
	_callout.text = "FOLLOW THE %s - PRESS %s" % [cue, control]


func _letters_hint(player_index: int) -> String:
	var display_letters := PackedStringArray()
	for target in _targets_for_player(player_index):
		display_letters.append(target.letter)
	return " ".join(display_letters)


func _create_targets() -> void:
	if target_scene == null:
		push_error("Gameplay needs a TriangleTarget scene.")
		_hint.text = "No target scene is configured."
		return

	if not _create_player_targets(PLAYER_ONE):
		return
	if GameSession.player_two_enabled() and not _create_player_targets(PLAYER_TWO):
		return

	if not _has_targets_for_every_player():
		_hint.text = "Each active player needs three configured target controls."


func _create_player_targets(player_index: int) -> bool:
	var actions := Settings.control_actions_for_player(player_index)
	if actions.is_empty():
		push_error("%s has no configured target actions." % _player_name(player_index))
		return false

	for action: StringName in actions:
		var instance := target_scene.instantiate()
		var target := instance as TriangleTarget
		if target == null:
			instance.free()
			push_error("The configured target scene must use TriangleTarget as its root.")
			_hint.text = "The configured target scene is invalid."
			return false

		_targets_root.add_child(target)
		target.configure(
			Settings.control_key_label(action).to_upper(),
			player_index,
			_player_inactive_color(player_index),
			_player_highlight_color(player_index),
			_target_move_speed()
		)
		target.set_player_label_visible(Settings.player_labels_enabled())
		target.set_reduced_motion(_reduced_motion_enabled)
		target.set_size_scale(_target_size_scale())
		target.activated.connect(_on_target_activated)
		_targets.append(target)
		_targets_by_action[action] = target
	return true


func _has_targets_for_every_player() -> bool:
	for player_index in _active_player_indices():
		if _targets_for_player(player_index).is_empty():
			return false
	return true


func _targets_for_player(player_index: int) -> Array[TriangleTarget]:
	var player_targets: Array[TriangleTarget] = []
	for target in _targets:
		if target.player_index == player_index:
			player_targets.append(target)
	return player_targets


func _start_round() -> void:
	_round_timer.stop()
	_load_round_settings()
	_scores = [0, 0]
	_streaks = [0, 0]
	_correct_hits = [0, 0]
	_misses = [0, 0]
	_best_streaks = [0, 0]
	_round_achievements.clear()
	_round_progression_notes.clear()
	_active_targets = [null, null]
	_cpu_action_time = -1.0
	_round_active = true
	_round_over.hide()
	_score_panel.hide()
	_round_panel.show()
	_round_panel.modulate = Color.WHITE
	_round_panel.scale = Vector2.ONE
	_share_status.hide()
	_reset_motion_fx()
	_update_scores()
	_update_streaks()

	for target in _targets:
		target.move_speed = _target_move_speed()
		target.set_size_scale(_target_size_scale())
		target.set_target_enabled(true)
		target.set_highlighted(false)
		_place_target(target)
		target.play_spawn()

	for player_index in _active_player_indices():
		_select_next_target(player_index)

	_time_progress.max_value = _active_round_duration
	_time_progress.value = _active_round_duration
	_round_timer.start(_active_round_duration)
	_update_time(int(ceil(_active_round_duration)))
	_show_announcement("GO!", GameInfo.CREAM)


func _attempt_target(target: TriangleTarget, automated := false) -> void:
	if not _round_active or not _targets.has(target):
		return

	var player_index := target.player_index
	if player_index < 0 or player_index >= PLAYER_COUNT:
		push_warning("Ignoring a target with an invalid player index.")
		return
	if automated:
		if player_index != PLAYER_TWO or not GameSession.player_two_is_cpu():
			return
	elif not _player_accepts_human_input(player_index):
		return

	var hit_position := target.global_position
	var active_target := _active_targets[player_index] as TriangleTarget
	var successful := target == active_target

	if successful:
		_scores[player_index] += points_per_match
		_streaks[player_index] += 1
		_correct_hits[player_index] += 1
		_best_streaks[player_index] = maxi(
			_best_streaks[player_index],
			_streaks[player_index]
		)
		AudioManager.play_game_hit(_streaks[player_index])
		AudioManager.request_caption(
			"%s: correct target" % _player_name(player_index)
		)
		_spawn_hit_effect(
			hit_position,
			_player_highlight_color(player_index),
			true,
			"+%d" % points_per_match
		)
		_flash_screen(_player_highlight_color(player_index), 0.12)
		_add_screen_shake(4.0)
		_place_target(target)
		target.play_spawn()
		_select_next_target(player_index)

		if _streaks[player_index] >= 3 and (
			_streaks[player_index] == 3 or _streaks[player_index] % 5 == 0
		):
			_show_announcement(
				"%d HIT STREAK!" % _streaks[player_index],
				_player_highlight_color(player_index)
			)
	else:
		_scores[player_index] -= miss_penalty
		_streaks[player_index] = 0
		_misses[player_index] += 1
		AudioManager.play_game_miss()
		AudioManager.request_caption(
			"%s: wrong target" % _player_name(player_index)
		)
		target.play_wrong()
		_spawn_hit_effect(hit_position, MISS_COLOR, false, "-%d" % miss_penalty)
		_flash_screen(DANGER_COLOR, 0.09)
		_add_screen_shake(8.5)

	_update_scores()
	_update_streaks()
	_bump_score(player_index, successful)
	if successful and _streaks[player_index] >= 2:
		_bump_streak(player_index)


func _select_next_target(player_index: int) -> void:
	var player_targets := _targets_for_player(player_index)
	if player_targets.is_empty():
		return

	var previous := _active_targets[player_index] as TriangleTarget
	var selected_index := _rng.randi_range(0, player_targets.size() - 1)
	if player_targets.size() > 1 and player_targets[selected_index] == previous:
		selected_index = (
			selected_index + _rng.randi_range(1, player_targets.size() - 1)
		) % player_targets.size()

	if is_instance_valid(previous):
		previous.set_highlighted(false)

	var selected := player_targets[selected_index]
	selected.set_highlighted(true)
	_active_targets[player_index] = selected
	if player_index == PLAYER_TWO and GameSession.player_two_is_cpu():
		_schedule_cpu_action()


func _place_target(target: TriangleTarget) -> void:
	var bounds := _target_bounds()
	var candidate := bounds.get_center()

	for _attempt in range(SPAWN_ATTEMPTS):
		candidate = Vector2(
			_rng.randf_range(bounds.position.x, bounds.position.x + bounds.size.x),
			_rng.randf_range(bounds.position.y, bounds.position.y + bounds.size.y)
		)
		if _position_is_clear(candidate, target):
			break

	target.position = candidate
	target.reset_trail()
	var angle := _rng.randf_range(0.0, TAU)
	target.velocity = Vector2(cos(angle), sin(angle)).normalized()


func _position_is_clear(candidate: Vector2, moving_target: TriangleTarget) -> bool:
	for target in _targets:
		if target == moving_target:
			continue
		if candidate.distance_to(target.position) < _target_radius() * 2.35:
			return false
	return true


func _target_bounds() -> Rect2:
	var viewport_size := get_viewport_rect().size
	var radius := _target_radius()
	var minimum := Vector2(SIDE_CLEARANCE + radius, TOP_CLEARANCE + radius)
	var maximum := Vector2(
		viewport_size.x - SIDE_CLEARANCE - radius,
		viewport_size.y - BOTTOM_CLEARANCE - radius
	)

	if maximum.x < minimum.x:
		minimum.x = viewport_size.x * 0.5
		maximum.x = minimum.x
	if maximum.y < minimum.y:
		minimum.y = viewport_size.y * 0.5
		maximum.y = minimum.y

	return Rect2(minimum, maximum - minimum)


func _target_radius() -> float:
	return TriangleTarget.HIT_RADIUS * _target_size_scale()


func _update_scores() -> void:
	_player_one_score.text = "%d" % _scores[PLAYER_ONE]
	_player_two_score.text = "%d" % _scores[PLAYER_TWO]


func _update_streaks() -> void:
	for player_index in _active_player_indices():
		var streak_label := _streak_label(player_index)
		var streak: int = _streaks[player_index]
		streak_label.text = "COMBO x%d" % streak if streak >= 2 else " "
	if GameSession.is_single_player():
		_player_two_streak.text = " "


func _update_time(seconds_left: int) -> void:
	_displayed_seconds = maxi(seconds_left, 0)
	_time_label.text = "%02d" % _displayed_seconds
	if _round_active and _displayed_seconds > 0 and _displayed_seconds <= 3:
		_show_announcement(str(_displayed_seconds), DANGER_COLOR)
		AudioManager.request_caption(
			"%d %s remaining" % [
				_displayed_seconds,
				"second" if _displayed_seconds == 1 else "seconds",
			]
		)


func _update_urgency(time_left: float) -> void:
	_time_label.pivot_offset = _time_label.size * 0.5
	if time_left > DANGER_SECONDS:
		_time_label.scale = Vector2.ONE
		_time_label.add_theme_color_override("font_color", GameInfo.CREAM)
		_danger_overlay.color = _with_alpha(DANGER_COLOR, 0.0)
		return

	var urgency := 1.0 - clampf(time_left / DANGER_SECONDS, 0.0, 1.0)
	if _reduced_motion_enabled:
		_time_label.scale = Vector2.ONE
		_time_label.add_theme_color_override(
			"font_color",
			GameInfo.CREAM.lerp(DANGER_COLOR, urgency)
		)
		_danger_overlay.color = _with_alpha(DANGER_COLOR, 0.0)
		return
	var pulse := (sin(_ambient_time * lerpf(6.0, 11.0, urgency)) + 1.0) * 0.5
	_time_label.scale = Vector2.ONE * (1.0 + pulse * lerpf(0.03, 0.09, urgency))
	_time_label.add_theme_color_override(
		"font_color",
		DANGER_COLOR.lerp(Color.WHITE, pulse * 0.22)
	)
	_danger_overlay.color = _with_alpha(DANGER_COLOR, pulse * urgency * 0.045)


func _bump_score(player_index: int, successful: bool) -> void:
	var score_label := _score_label(player_index)
	var old_tween := _score_tweens[player_index] as Tween
	if old_tween and old_tween.is_valid():
		old_tween.kill()

	score_label.pivot_offset = score_label.size * 0.5
	if _reduced_motion_enabled:
		score_label.scale = Vector2.ONE
		score_label.rotation = 0.0
		return
	score_label.scale = Vector2.ONE * (1.28 if successful else 0.84)
	score_label.rotation = deg_to_rad(-3.0 if player_index == PLAYER_ONE else 3.0)
	var tween := create_tween().set_parallel(true)
	tween.tween_property(score_label, "scale", Vector2.ONE, 0.22).set_trans(
		Tween.TRANS_BACK
	).set_ease(Tween.EASE_OUT)
	tween.tween_property(score_label, "rotation", 0.0, 0.18)
	_score_tweens[player_index] = tween


func _bump_streak(player_index: int) -> void:
	var streak_label := _streak_label(player_index)
	var old_tween := _streak_tweens[player_index] as Tween
	if old_tween and old_tween.is_valid():
		old_tween.kill()

	streak_label.pivot_offset = streak_label.size * 0.5
	if _reduced_motion_enabled:
		streak_label.scale = Vector2.ONE
		return
	streak_label.scale = Vector2.ONE * 0.72
	var tween := create_tween()
	tween.tween_property(streak_label, "scale", Vector2.ONE, 0.2).set_trans(
		Tween.TRANS_BACK
	).set_ease(Tween.EASE_OUT)
	_streak_tweens[player_index] = tween


func _spawn_hit_effect(
	world_position: Vector2,
	color: Color,
	successful: bool,
	score_text: String
) -> void:
	if not _reduced_motion_enabled:
		_spawn_triangle_burst(world_position, color, successful)

	var label := Label.new()
	label.text = score_text
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.position = _world_fx.to_local(world_position) + Vector2(-70.0, -54.0)
	label.size = Vector2(140.0, 60.0)
	label.z_index = 30
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.add_theme_color_override("font_color", color)
	label.add_theme_color_override("font_outline_color", Color(0.02, 0.03, 0.04, 0.9))
	label.add_theme_constant_override("outline_size", 6)
	label.add_theme_font_size_override("font_size", 36)
	_world_fx.add_child(label)

	var start_position := label.position
	if _reduced_motion_enabled:
		var reduced_tween := label.create_tween()
		reduced_tween.tween_interval(0.45)
		reduced_tween.tween_property(label, "modulate:a", 0.0, 0.15)
		reduced_tween.finished.connect(label.queue_free)
		return

	label.scale = Vector2.ONE * 0.7
	var tween := label.create_tween().set_parallel(true)
	tween.tween_property(label, "position", start_position + Vector2(0.0, -82.0), 0.55).set_trans(
		Tween.TRANS_QUAD
	).set_ease(Tween.EASE_OUT)
	tween.tween_property(label, "scale", Vector2.ONE * 1.12, 0.24).set_trans(
		Tween.TRANS_BACK
	).set_ease(Tween.EASE_OUT)
	tween.tween_property(label, "modulate:a", 0.0, 0.55).set_delay(0.2)
	tween.finished.connect(label.queue_free)


func _spawn_triangle_burst(
	world_position: Vector2,
	color: Color,
	successful: bool
) -> void:
	if _reduced_motion_enabled:
		return
	var local_position := _world_fx.to_local(world_position)
	var ring := Line2D.new()
	ring.points = PackedVector2Array([
		Vector2(0.0, -46.0),
		Vector2(42.0, 27.0),
		Vector2(-42.0, 27.0),
	])
	ring.closed = true
	ring.width = 6.0 if successful else 4.0
	ring.default_color = color
	ring.position = local_position
	ring.scale = Vector2.ONE * 0.45
	ring.z_index = 20
	ring.joint_mode = Line2D.LINE_JOINT_ROUND
	ring.antialiased = true
	_world_fx.add_child(ring)

	var ring_tween := ring.create_tween().set_parallel(true)
	ring_tween.tween_property(
		ring,
		"scale",
		Vector2.ONE * (2.0 if successful else 1.45),
		0.38
	).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	ring_tween.tween_property(ring, "rotation", 0.45 if successful else -0.25, 0.38)
	ring_tween.tween_property(ring, "modulate:a", 0.0, 0.38)
	ring_tween.finished.connect(ring.queue_free)

	var shard_count := BURST_SHARDS if successful else 5
	for shard_index in range(shard_count):
		var angle := TAU * float(shard_index) / float(shard_count)
		angle += _rng.randf_range(-0.18, 0.18)
		var direction := Vector2.RIGHT.rotated(angle)
		var shard_size := _rng.randf_range(7.0, 13.0)
		var shard := Polygon2D.new()
		shard.polygon = PackedVector2Array([
			Vector2(0.0, -shard_size),
			Vector2(shard_size * 0.72, shard_size * 0.62),
			Vector2(-shard_size * 0.72, shard_size * 0.62),
		])
		shard.color = color.lightened(_rng.randf_range(0.0, 0.28))
		shard.position = local_position
		shard.rotation = angle + PI * 0.5
		shard.z_index = 21
		_world_fx.add_child(shard)

		var distance := _rng.randf_range(76.0, 150.0) if successful else _rng.randf_range(
			45.0,
			86.0
		)
		var duration := _rng.randf_range(0.32, 0.5)
		var end_position := local_position + direction * distance + Vector2(0.0, 28.0)
		var shard_tween := shard.create_tween().set_parallel(true)
		shard_tween.tween_property(shard, "position", end_position, duration).set_trans(
			Tween.TRANS_QUAD
		).set_ease(Tween.EASE_OUT)
		shard_tween.tween_property(
			shard,
			"rotation",
			shard.rotation + _rng.randf_range(-2.4, 2.4),
			duration
		)
		shard_tween.tween_property(shard, "scale", Vector2.ZERO, duration).set_delay(
			duration * 0.45
		)
		shard_tween.tween_property(shard, "modulate:a", 0.0, duration).set_delay(
			duration * 0.45
		)
		shard_tween.finished.connect(shard.queue_free)


func _spawn_round_confetti(color: Color) -> void:
	if _reduced_motion_enabled:
		return
	var viewport_size := get_viewport_rect().size
	for burst_index in range(6):
		var position := Vector2(
			_rng.randf_range(viewport_size.x * 0.16, viewport_size.x * 0.84),
			_rng.randf_range(viewport_size.y * 0.28, viewport_size.y * 0.68)
		)
		_spawn_triangle_burst(to_global(position), color, true)


func _celebrate_level_unlock() -> void:
	AudioManager.play_level_unlock()
	AudioManager.request_caption("%s unlocked" % GameInfo.DESK_CAN_SAW_TITLE)
	_show_announcement(
		"%s UNLOCKED!" % GameInfo.DESK_CAN_SAW_TITLE.to_upper(),
		GameInfo.SKY,
		1.2
	)
	_flash_screen(GameInfo.SKY, 0.24)
	_add_screen_shake(10.0)
	_spawn_round_confetti(GameInfo.SKY)


func _flash_screen(color: Color, alpha: float) -> void:
	if _flash_tween and _flash_tween.is_valid():
		_flash_tween.kill()
	if not _intense_effects_enabled:
		_flash_tween = null
		_screen_flash.color = _with_alpha(color, 0.0)
		return
	_screen_flash.color = _with_alpha(color, alpha)
	_flash_tween = create_tween()
	_flash_tween.tween_property(_screen_flash, "color:a", 0.0, 0.34).set_trans(
		Tween.TRANS_QUAD
	).set_ease(Tween.EASE_OUT)


func _show_announcement(
	text: String,
	color: Color,
	hold_time := 0.28
) -> void:
	if _announcement_tween and _announcement_tween.is_valid():
		_announcement_tween.kill()

	_announcement.show()
	_announcement.text = text
	_announcement.add_theme_color_override("font_color", color)
	_announcement.pivot_offset = _announcement.size * 0.5
	if _reduced_motion_enabled:
		_announcement.scale = Vector2.ONE
		_announcement.modulate = Color.WHITE
		_announcement_tween = create_tween()
		_announcement_tween.tween_interval(hold_time)
		_announcement_tween.tween_property(
			_announcement,
			"modulate:a",
			0.0,
			0.16
		)
		_announcement_tween.finished.connect(_announcement.hide)
		return
	_announcement.scale = Vector2.ONE * 0.68
	_announcement.modulate = Color(1.0, 1.0, 1.0, 0.0)

	_announcement_tween = create_tween()
	_announcement_tween.tween_property(
		_announcement,
		"scale",
		Vector2.ONE,
		0.2
	).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_announcement_tween.parallel().tween_property(
		_announcement,
		"modulate:a",
		1.0,
		0.12
	)
	_announcement_tween.tween_interval(hold_time)
	_announcement_tween.tween_property(_announcement, "modulate:a", 0.0, 0.2)
	_announcement_tween.parallel().tween_property(
		_announcement,
		"scale",
		Vector2.ONE * 1.12,
		0.2
	)
	_announcement_tween.finished.connect(_announcement.hide)


func _add_screen_shake(amount: float) -> void:
	if not _intense_effects_enabled or _reduced_motion_enabled:
		return
	_shake_strength = maxf(_shake_strength, amount)


func _update_screen_shake(delta: float) -> void:
	if (
		not _intense_effects_enabled
		or _reduced_motion_enabled
		or _shake_strength <= 0.05
	):
		_shake_strength = 0.0
		_targets_root.position = Vector2.ZERO
		_world_fx.position = Vector2.ZERO
		return

	var offset := Vector2(
		_rng.randf_range(-_shake_strength, _shake_strength),
		_rng.randf_range(-_shake_strength, _shake_strength)
	)
	_targets_root.position = offset
	_world_fx.position = offset
	_shake_strength = move_toward(_shake_strength, 0.0, delta * SHAKE_DECAY)


func _reset_intense_effects() -> void:
	if _flash_tween and _flash_tween.is_valid():
		_flash_tween.kill()
	_flash_tween = null
	_shake_strength = 0.0
	_targets_root.position = Vector2.ZERO
	_world_fx.position = Vector2.ZERO
	_screen_flash.color = _with_alpha(Color.WHITE, 0.0)


func _reset_motion_fx() -> void:
	_reset_intense_effects()
	_danger_overlay.color = _with_alpha(DANGER_COLOR, 0.0)
	_time_label.scale = Vector2.ONE


func _reset_reduced_motion_state() -> void:
	_shake_strength = 0.0
	_targets_root.position = Vector2.ZERO
	_world_fx.position = Vector2.ZERO
	_danger_overlay.color = _with_alpha(DANGER_COLOR, 0.0)
	_time_label.scale = Vector2.ONE
	for child in _world_fx.get_children():
		child.queue_free()
	for tween in _score_tweens + _streak_tweens:
		if tween and tween.is_valid():
			tween.kill()
	for label in [
		_player_one_score,
		_player_two_score,
		_player_one_streak,
		_player_two_streak,
	]:
		label.scale = Vector2.ONE
		label.rotation = 0.0
	if _announcement_tween and _announcement_tween.is_valid():
		_announcement_tween.kill()
	_announcement.hide()
	if _round_panel_tween and _round_panel_tween.is_valid():
		_round_panel_tween.kill()
	for panel in [_round_panel, _score_panel]:
		panel.scale = Vector2.ONE
		panel.modulate = Color.WHITE


func _animate_round_panel() -> void:
	_animate_modal_panel(_round_panel)


func _animate_score_panel() -> void:
	_animate_modal_panel(_score_panel)


func _animate_modal_panel(panel: Control) -> void:
	if _round_panel_tween and _round_panel_tween.is_valid():
		_round_panel_tween.kill()
	panel.pivot_offset = panel.size * 0.5
	if _reduced_motion_enabled:
		panel.scale = Vector2.ONE
		panel.modulate = Color.WHITE
		return
	panel.scale = Vector2.ONE * 0.78
	panel.modulate = Color(1.0, 1.0, 1.0, 0.0)
	_round_panel_tween = create_tween().set_parallel(true)
	_round_panel_tween.tween_property(
		panel,
		"scale",
		Vector2.ONE,
		0.34
	).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_round_panel_tween.tween_property(panel, "modulate:a", 1.0, 0.18)


func _populate_score_screen(result_text: String, result_color: Color) -> void:
	var total_hits := 0
	var total_attempts := 0
	for player_index in _active_player_indices():
		total_hits += int(_correct_hits[player_index])
		total_attempts += int(_correct_hits[player_index]) + int(_misses[player_index])

	_score_screen_title.text = result_text
	_score_screen_title.add_theme_color_override("font_color", result_color)
	_score_screen_subtitle.text = _round_subtitle.text
	_game_duration_stat.text = "%d SEC" % roundi(_active_round_duration)
	_game_hits_stat.text = "%d" % total_hits
	_game_accuracy_stat.text = "%d%%" % _accuracy_percent(total_hits, total_attempts)

	_player_one_stats_score.text = "%d" % _scores[PLAYER_ONE]
	_player_one_stats_hits.text = "%d" % _correct_hits[PLAYER_ONE]
	_player_one_stats_misses.text = "%d" % _misses[PLAYER_ONE]
	_player_one_stats_accuracy.text = "%d%%" % _player_accuracy(PLAYER_ONE)
	_player_one_stats_streak.text = "x%d" % _best_streaks[PLAYER_ONE]

	_player_two_stats_score.text = "%d" % _scores[PLAYER_TWO]
	_player_two_stats_hits.text = "%d" % _correct_hits[PLAYER_TWO]
	_player_two_stats_misses.text = "%d" % _misses[PLAYER_TWO]
	_player_two_stats_accuracy.text = "%d%%" % _player_accuracy(PLAYER_TWO)
	_player_two_stats_streak.text = "x%d" % _best_streaks[PLAYER_TWO]


func _player_accuracy(player_index: int) -> int:
	var attempts: int = _correct_hits[player_index] + _misses[player_index]
	return _accuracy_percent(_correct_hits[player_index], attempts)


func _accuracy_percent(hits: int, attempts: int) -> int:
	if attempts <= 0:
		return 0
	return roundi(float(hits) / float(attempts) * 100.0)


func _best_combo_summary() -> String:
	var player_one_best: int = _best_streaks[PLAYER_ONE]
	if GameSession.is_single_player():
		if player_one_best == 0:
			return "No combo this round - keep chasing the glow."
		return "Best combo: Player 1 chained x%d" % player_one_best

	var player_two_best: int = _best_streaks[PLAYER_TWO]
	if player_one_best == 0 and player_two_best == 0:
		return "No combos this round - the rematch is wide open."
	if player_one_best == player_two_best:
		return "Shared top combo: x%d" % player_one_best
	if player_one_best > player_two_best:
		return "Top combo: Player 1 chained x%d" % player_one_best
	return "Top combo: %s chained x%d" % [_player_name(PLAYER_TWO), player_two_best]


func _score_label(player_index: int) -> Label:
	return _player_one_score if player_index == PLAYER_ONE else _player_two_score


func _streak_label(player_index: int) -> Label:
	return _player_one_streak if player_index == PLAYER_ONE else _player_two_streak


func _player_name(player_index: int) -> String:
	if player_index == PLAYER_TWO:
		return GameSession.player_two_name()
	return "Player %d" % (player_index + 1)


func _player_inactive_color(player_index: int) -> Color:
	return player_one_inactive_color if player_index == PLAYER_ONE else player_two_inactive_color


func _player_highlight_color(player_index: int) -> Color:
	return (
		player_one_highlight_color
		if player_index == PLAYER_ONE
		else player_two_highlight_color
	)


func _triangle_outline(center: Vector2, radius: float, rotation: float) -> PackedVector2Array:
	var points := PackedVector2Array()
	for point_index in range(3):
		points.append(
			center + Vector2.UP.rotated(rotation + TAU * float(point_index) / 3.0) * radius
		)
	points.append(points[0])
	return points


func _with_alpha(color: Color, alpha: float) -> Color:
	var result := color
	result.a = alpha
	return result


func _on_target_activated(target: TriangleTarget) -> void:
	_attempt_target(target)


func _on_round_timer_timeout() -> void:
	_round_active = false
	_cpu_action_time = -1.0
	_update_time(0)
	_time_progress.value = 0.0
	_update_urgency(_active_round_duration)
	for target in _targets:
		target.set_highlighted(false)
		target.set_target_enabled(false)
	_active_targets = [null, null]

	var player_one_total: int = _scores[PLAYER_ONE]
	var player_two_total: int = _scores[PLAYER_TWO]
	_round_player_one_score.text = "%d" % player_one_total
	_round_player_two_score.text = "%d" % player_two_total

	var celebration_color := GameInfo.CREAM
	var result_text := "DRAW!"
	if GameSession.is_single_player():
		result_text = "ROUND COMPLETE"
		_result_label.text = result_text
		_result_label.add_theme_color_override("font_color", player_one_highlight_color)
		_round_subtitle.text = "Player 1 scored %d points in %d seconds." % [
			player_one_total,
			roundi(_active_round_duration),
		]
		celebration_color = player_one_highlight_color
	elif player_one_total > player_two_total:
		result_text = "PLAYER 1 WINS!"
		_result_label.text = result_text
		_result_label.add_theme_color_override("font_color", player_one_highlight_color)
		_round_subtitle.text = "Player 1 wins by %d points." % (
			player_one_total - player_two_total
		)
		celebration_color = player_one_highlight_color
	elif player_two_total > player_one_total:
		result_text = "%s WINS!" % _player_name(PLAYER_TWO).to_upper()
		_result_label.text = result_text
		_result_label.add_theme_color_override("font_color", player_two_highlight_color)
		_round_subtitle.text = "%s takes it by %d points." % [
			_player_name(PLAYER_TWO),
			player_two_total - player_one_total,
		]
		celebration_color = player_two_highlight_color
	else:
		_result_label.text = result_text
		_result_label.add_theme_color_override("font_color", GameInfo.CREAM)
		_round_subtitle.text = "Dead even after %d seconds. Run it back!" % roundi(
			_active_round_duration
		)

	if GameSession.is_single_player():
		_unlock_round_achievement("first_single_player_game")
	elif player_one_total > player_two_total:
		_unlock_round_achievement("first_win")

	var progression_outcome := AchievementManager.record_slice_and_slash_match(
		GameSession.is_single_player(),
		player_one_total,
		player_two_total,
		GameSession.slice_unlock_multiplayer_eligible()
	)
	var level_unlocked_now := bool(progression_outcome.get("unlocked_now", false))
	if level_unlocked_now:
		_round_progression_notes.append(
			"%s unlocked!" % GameInfo.DESK_CAN_SAW_TITLE
		)
	elif bool(progression_outcome.get("solo_qualified_now", false)):
		_round_progression_notes.append("Solo unlock condition complete")
	elif bool(progression_outcome.get("multiplayer_qualified_now", false)):
		_round_progression_notes.append("Multiplayer unlock condition complete")

	if SliceUnlockRules.earns_race_condition(
		GameSession.is_single_player(),
		player_one_total,
		player_two_total
	):
		_unlock_round_achievement(GameInfo.RACE_CONDITION_ACHIEVEMENT_ID)

	_round_highlight.text = _round_highlight_summary()
	_round_result_color = celebration_color
	_populate_score_screen(result_text, celebration_color)
	_spawn_round_confetti(celebration_color)
	_round_over.show()
	_score_panel.hide()
	_round_panel.show()
	_animate_round_panel.call_deferred()
	if level_unlocked_now:
		_celebrate_level_unlock()
	_play_again_button.grab_focus.call_deferred()


func _on_play_again_pressed() -> void:
	_start_round()


func _on_exit_to_main_menu_pressed() -> void:
	_round_timer.stop()
	Router.goto(main_menu_scene)


func _on_see_score_pressed() -> void:
	_round_panel.hide()
	_score_panel.show()
	_animate_score_panel.call_deferred()
	_back_to_results_button.grab_focus.call_deferred()


func _on_back_to_results_pressed() -> void:
	_show_round_results()


func _on_share_pressed() -> void:
	if _sharing:
		return
	_sharing = true
	_set_share_buttons_disabled(true)
	_show_share_status("Building your share image...", GameInfo.MUTED, false)

	var result: Dictionary = await ShareManager.generate_score_image(_share_payload())
	if not is_inside_tree():
		return

	_sharing = false
	_set_share_buttons_disabled(false)
	if bool(result.get("ok", false)):
		AudioManager.play_share()
		ShareManager.show_preview(result)
		_show_share_status(str(result.get("message", "Share image ready.")), GameInfo.SKY)
	else:
		AudioManager.play_game_miss()
		var message := str(result.get("message", "The share image could not be created."))
		push_warning(message)
		_show_share_status(message, DANGER_COLOR)


func _show_round_results() -> void:
	_score_panel.hide()
	_round_panel.show()
	_animate_round_panel.call_deferred()
	_see_score_button.grab_focus.call_deferred()


func open_pause_menu() -> void:
	if is_instance_valid(_pause_menu):
		return
	var packed: PackedScene = load(pause_scene)
	if packed == null:
		push_error("Could not load pause menu scene '%s'." % pause_scene)
		return
	_pause_menu = packed.instantiate()
	_pause_menu.closed.connect(_on_pause_closed)
	_hud.add_child(_pause_menu)


func _on_pause_closed() -> void:
	_pause_menu = null


func _on_pause_button_pressed() -> void:
	open_pause_menu()


func _unlock_round_achievement(id: String) -> void:
	if AchievementManager.unlock(id):
		_round_achievements.append(AchievementManager.get_achievement(id))


func _round_highlight_summary() -> String:
	var parts := PackedStringArray([_best_combo_summary()])
	parts.append_array(_round_progression_notes)
	if _round_achievements.is_empty():
		return "  |  ".join(parts)
	var titles := PackedStringArray()
	for achievement in _round_achievements:
		titles.append(str(achievement.get("title", "Achievement")))
	parts.append("Unlocked: %s" % ", ".join(titles))
	return "  |  ".join(parts)


func _share_payload() -> Dictionary:
	var total_hits := 0
	var total_attempts := 0
	var best_combo := 0
	for player_index in _active_player_indices():
		total_hits += int(_correct_hits[player_index])
		total_attempts += int(_correct_hits[player_index]) + int(_misses[player_index])
		best_combo = maxi(best_combo, int(_best_streaks[player_index]))

	var achievement_titles := _share_achievement_titles()
	var achievements_are_new := not _round_achievements.is_empty()
	return {
		"game_title": GameInfo.TITLE,
		"studio": GameInfo.STUDIO,
		"mode": GameSession.mode_title(),
		"result": _result_label.text,
		"subtitle": _round_subtitle.text,
		"score_caption": "SOLO SCORE" if GameSession.is_single_player() else "FINAL SCORE",
		"score": (
			str(_scores[PLAYER_ONE])
			if GameSession.is_single_player()
			else "%d - %d" % [_scores[PLAYER_ONE], _scores[PLAYER_TWO]]
		),
		"accuracy": "%d%%" % _accuracy_percent(total_hits, total_attempts),
		"hits": str(total_hits),
		"combo": "x%d" % best_combo,
		"achievements": achievement_titles,
		"achievements_are_new": achievements_are_new,
		"achievement_count": AchievementManager.unlocked_count(),
		"achievement_badge": (
			str(_round_achievements[0].get("badge", "NEW"))
			if achievements_are_new
			else "ACH"
		),
		"accent_color": _round_result_color,
		"secondary_color": (
			player_two_highlight_color
			if GameSession.player_two_enabled()
			else player_one_highlight_color
		),
		"footer": "%s  |  %s" % [GameInfo.TAGLINE, GameInfo.WEBSITE],
	}


func _share_achievement_titles() -> PackedStringArray:
	var titles := PackedStringArray()
	var source := _round_achievements
	if source.is_empty():
		source = AchievementManager.get_unlocked_achievements()
	for achievement in source:
		titles.append(str(achievement.get("title", "Achievement")))
	return titles


func _set_share_buttons_disabled(disabled: bool) -> void:
	_share_button.disabled = disabled
	_stats_share_button.disabled = disabled


func _show_share_status(
	message: String,
	color: Color,
	auto_hide := true
) -> void:
	if _share_status_tween and _share_status_tween.is_valid():
		_share_status_tween.kill()
	_share_status.text = message
	_share_status.add_theme_color_override("font_color", color)
	_share_status.modulate.a = 1.0
	_share_status.show()
	if not auto_hide:
		return
	_share_status_tween = create_tween()
	_share_status_tween.tween_interval(2.8)
	_share_status_tween.tween_property(_share_status, "modulate:a", 0.0, 0.3)
	_share_status_tween.tween_callback(_share_status.hide)
