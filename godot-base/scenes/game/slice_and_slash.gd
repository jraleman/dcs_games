extends Node2D

## Electric chainsaw score chase staged over a procedural workshop desk.

@export_file("*.tscn") var pause_scene := "res://scenes/menus/pause_menu.tscn"
@export_file("*.tscn") var main_menu_scene := "res://scenes/menus/main_menu.tscn"
@export_range(5.0, 180.0, 1.0) var round_duration := 30.0
@export_range(1, 100, 1) var points_per_can := 1
@export_range(0.1, 2.0, 0.05) var minimum_spawn_interval := 0.28
@export_range(0.1, 2.0, 0.05) var maximum_spawn_interval := 0.48
@export_range(1, 100, 1) var maximum_cans := 24
@export_range(100.0, 1600.0, 10.0) var chainsaw_speed := 920.0
@export_range(10.0, 100.0, 1.0) var can_radius := 34.0
@export_range(0.1, 5.0, 0.1) var combo_window := 1.25
@export var player_one_color := Color("4da3ff")
@export var player_two_color := Color("ff5c6c")
@export var music: AudioStream

const PLAYER_ONE := 0
const PLAYER_TWO := 1
const SIDE_CLEARANCE := 38.0
const TOP_CLEARANCE := 190.0
const BOTTOM_CLEARANCE := 105.0
const DANGER_SECONDS := 8.0
const DANGER_COLOR := Color("ff4964")
const SHAKE_DECAY := 34.0
const WORKSHOP_WALL := Color("182328")
const WORKSHOP_WALL_DARK := Color("0c1317")
const WOOD_BASE := Color("6d3f22")
const WOOD_LIGHT := Color("a66a38")
const WOOD_DARK := Color("3b2115")
const BENCH_STEEL := Color("536168")
const SAWDUST := Color("e7b96d")
const CAN_COLORS := [
	Color("afddea"),
	Color("f2f7f9"),
	Color("ffc857"),
	Color("8bd3c7"),
]

@onready var _playfield: Node2D = %Targets
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
@onready var _stats_versus: Label = (
	$HUD/RoundOver/Center/ScorePanel/Layout/Players/Versus
)
@onready var _player_two_stats_card: PanelContainer = (
	$HUD/RoundOver/Center/ScorePanel/Layout/Players/PlayerTwo
)
@onready var _player_two_stats_title: Label = (
	$HUD/RoundOver/Center/ScorePanel/Layout/Players/PlayerTwo/Layout/Title
)
@onready var _back_to_results_button: Button = %BackToResultsButton
@onready var _stats_share_button: Button = %StatsShareButton
@onready var _share_status: Label = %ShareStatus

var _cans: Array[SliceCan] = []
var _chainsaws := [null, null]
var _scores := [0, 0]
var _streaks := [0, 0]
var _best_streaks := [0, 0]
var _last_slice_times := [-1000.0, -1000.0]
var _spawned_cans := 0
var _escaped_cans := 0
var _spawn_time := 0.0
var _displayed_seconds := -1
var _round_active := false
var _ambient_time := 0.0
var _pause_menu: MenuScreen
var _rng := RandomNumberGenerator.new()
var _announcement_tween: Tween
var _flash_tween: Tween
var _round_panel_tween: Tween
var _share_status_tween: Tween
var _sharing := false
var _round_id := 0
var _shake_strength := 0.0
var _intense_effects_enabled := true
var _reduced_motion_enabled := false
var _active_round_duration := 30.0
var _round_gameplay_speed := 1.0
var _round_target_size := 1.0


func _ready() -> void:
	_rng.randomize()
	_intense_effects_enabled = Settings.visual_effects_enabled()
	_reduced_motion_enabled = Settings.reduced_motion_enabled()
	_load_round_assists()
	Settings.changed.connect(_on_setting_changed)
	if GameSession.player_two_is_cpu():
		GameSession.configure_multiplayer(GameSession.PlayerTwoController.HUMAN)
	else:
		GameSession.ensure_controller_assignments()

	_configure_mode_ui()
	_player_one_score.add_theme_color_override("font_color", player_one_color)
	_player_two_score.add_theme_color_override("font_color", player_two_color)
	_player_one_streak.add_theme_color_override("font_color", player_one_color)
	_player_two_streak.add_theme_color_override("font_color", player_two_color)
	_time_progress.max_value = _active_round_duration
	_time_progress.value = _active_round_duration
	AudioManager.attach_ui_sounds(_hud)

	if music:
		AudioManager.play_music(music)

	_create_chainsaws()
	_start_round_after_transition()


func _start_round_after_transition() -> void:
	if Router.is_transitioning():
		await Router.transition_finished
	if is_inside_tree():
		_start_round()


func _process(delta: float) -> void:
	if not _reduced_motion_enabled:
		_ambient_time += delta
	queue_redraw()
	_update_screen_shake(delta)
	if not _round_active:
		return

	_update_chainsaws(delta)
	_update_cans(delta)
	_spawn_time -= delta
	if _spawn_time <= 0.0:
		if _cans.size() < maximum_cans:
			_spawn_can()
		_spawn_time = _rng.randf_range(
			minf(minimum_spawn_interval, maximum_spawn_interval),
			maxf(minimum_spawn_interval, maximum_spawn_interval)
		)

	var time_left := _round_timer.time_left
	_time_progress.value = time_left
	_update_urgency(time_left)
	var seconds_left := int(ceil(time_left))
	if seconds_left != _displayed_seconds:
		_update_time(seconds_left)


func _draw() -> void:
	var viewport_size := get_viewport_rect().size
	if viewport_size.x <= 0.0 or viewport_size.y <= 0.0:
		return
	var desk_top := _desk_top(viewport_size)

	draw_rect(Rect2(Vector2.ZERO, viewport_size), WORKSHOP_WALL_DARK)
	draw_rect(
		Rect2(Vector2.ZERO, Vector2(viewport_size.x, desk_top)),
		WORKSHOP_WALL
	)
	draw_circle(
		Vector2(viewport_size.x * 0.5, desk_top * 0.05),
		viewport_size.x * 0.34,
		Color(0.75, 0.9, 0.92, 0.035)
	)
	_draw_pegboard(viewport_size, desk_top)
	_draw_workshop_tools(viewport_size, desk_top)

	draw_rect(
		Rect2(
			Vector2(0.0, desk_top),
			Vector2(viewport_size.x, viewport_size.y - desk_top)
		),
		WOOD_BASE
	)
	draw_rect(
		Rect2(Vector2(0.0, desk_top), Vector2(viewport_size.x, 15.0)),
		WOOD_LIGHT.lightened(0.12)
	)
	draw_line(
		Vector2(0.0, desk_top + 15.0),
		Vector2(viewport_size.x, desk_top + 15.0),
		WOOD_DARK,
		5.0
	)
	_draw_wood_grain(viewport_size, desk_top)
	_draw_bench_hardware(viewport_size)
	_draw_power_cables(viewport_size)
	if not _reduced_motion_enabled:
		_draw_sawdust_motes(viewport_size, desk_top)

	if GameSession.player_two_enabled():
		var divider_x := viewport_size.x * 0.5
		for divider_y in range(int(desk_top + 24.0), int(viewport_size.y - 88.0), 38):
			draw_line(
				Vector2(divider_x, divider_y),
				Vector2(divider_x, divider_y + 18.0),
				Color(0.85, 0.9, 0.88, 0.18),
				2.0,
				true
			)


func _desk_top(viewport_size: Vector2) -> float:
	return clampf(
		TOP_CLEARANCE - 38.0,
		viewport_size.y * 0.14,
		viewport_size.y * 0.3
	)


func _draw_pegboard(viewport_size: Vector2, desk_top: float) -> void:
	draw_rect(
		Rect2(
			Vector2(28.0, 24.0),
			Vector2(viewport_size.x - 56.0, maxf(desk_top - 42.0, 20.0))
		),
		Color(0.08, 0.14, 0.16, 0.72),
		false,
		3.0
	)
	var columns := maxi(int(viewport_size.x / 62.0), 1)
	var rows := maxi(int(desk_top / 42.0), 1)
	for row in range(rows):
		for column in range(columns):
			var peg := Vector2(
				32.0 + float(column) * 62.0,
				28.0 + float(row) * 42.0
			)
			if peg.y >= desk_top - 16.0:
				continue
			draw_circle(peg, 2.2, Color(0.0, 0.0, 0.0, 0.45))
			draw_circle(peg - Vector2.ONE, 0.8, Color(0.7, 0.82, 0.84, 0.16))


func _draw_workshop_tools(viewport_size: Vector2, desk_top: float) -> void:
	var tool_color := Color(0.02, 0.035, 0.04, 0.62)
	var left_anchor := Vector2(viewport_size.x * 0.08, desk_top * 0.42)
	draw_line(
		left_anchor,
		left_anchor + Vector2(0.0, 66.0),
		tool_color,
		10.0,
		true
	)
	draw_rect(
		Rect2(left_anchor + Vector2(-28.0, -8.0), Vector2(56.0, 20.0)),
		tool_color
	)
	var right_anchor := Vector2(viewport_size.x * 0.91, desk_top * 0.46)
	draw_arc(right_anchor, 18.0, 0.3, TAU - 0.3, 24, tool_color, 9.0, true)
	draw_line(
		right_anchor + Vector2(-7.0, 16.0),
		right_anchor + Vector2(-28.0, 66.0),
		tool_color,
		10.0,
		true
	)
	draw_rect(
		Rect2(
			Vector2(viewport_size.x * 0.46, 22.0),
			Vector2(viewport_size.x * 0.08, 9.0)
		),
		Color(0.75, 0.9, 0.92, 0.38)
	)


func _draw_wood_grain(viewport_size: Vector2, desk_top: float) -> void:
	var desk_height := viewport_size.y - desk_top
	var plank_height := maxf(desk_height / 5.0, 64.0)
	for plank_index in range(1, 6):
		var seam_y := desk_top + float(plank_index) * plank_height
		if seam_y >= viewport_size.y - 72.0:
			break
		draw_line(
			Vector2(0.0, seam_y),
			Vector2(viewport_size.x, seam_y),
			Color(WOOD_DARK, 0.62),
			4.0
		)
		draw_line(
			Vector2(0.0, seam_y + 4.0),
			Vector2(viewport_size.x, seam_y + 4.0),
			Color(WOOD_LIGHT, 0.28),
			2.0
		)

	for grain_index in range(32):
		var base_y := desk_top + 26.0 + fmod(
			float(grain_index * 83),
			maxf(desk_height - 112.0, 1.0)
		)
		var points := PackedVector2Array()
		for segment in range(9):
			var ratio := float(segment) / 8.0
			points.append(Vector2(
				ratio * viewport_size.x,
				base_y
				+ sin(
					ratio * TAU * (1.0 + float(grain_index % 3) * 0.35)
					+ float(grain_index)
				) * (3.0 + float(grain_index % 4))
			))
		draw_polyline(
			points,
			Color(
				WOOD_DARK
				if grain_index % 3 != 0
				else WOOD_LIGHT,
				0.16
			),
			1.5,
			true
		)

	for knot_index in range(6):
		var knot := Vector2(
			viewport_size.x * (0.12 + float(knot_index) * 0.155),
			desk_top + 68.0 + fmod(float(knot_index * 97), maxf(desk_height - 170.0, 1.0))
		)
		draw_arc(knot, 13.0, 0.0, TAU, 20, Color(WOOD_DARK, 0.42), 3.0, true)
		draw_arc(
			knot + Vector2(2.0, -1.0),
			6.0,
			0.0,
			TAU,
			16,
			Color(WOOD_LIGHT, 0.28),
			2.0,
			true
		)


func _draw_bench_hardware(viewport_size: Vector2) -> void:
	draw_rect(
		Rect2(
			Vector2(0.0, viewport_size.y - 76.0),
			Vector2(viewport_size.x, 76.0)
		),
		WOOD_DARK.darkened(0.18)
	)
	draw_rect(
		Rect2(
			Vector2(0.0, viewport_size.y - 82.0),
			Vector2(viewport_size.x, 12.0)
		),
		BENCH_STEEL
	)
	for screw_index in range(8):
		var screw := Vector2(
			viewport_size.x * (float(screw_index) + 0.5) / 8.0,
			viewport_size.y - 76.0
		)
		draw_circle(screw, 5.0, BENCH_STEEL.lightened(0.25))
		draw_line(
			screw - Vector2(3.0, 0.0),
			screw + Vector2(3.0, 0.0),
			WORKSHOP_WALL_DARK,
			1.5
		)

	var strip_rect := Rect2(
		Vector2(viewport_size.x * 0.5 - 92.0, viewport_size.y - 60.0),
		Vector2(184.0, 34.0)
	)
	draw_rect(strip_rect, Color("d8dcda"))
	draw_rect(strip_rect, BENCH_STEEL.darkened(0.28), false, 3.0)
	for outlet_index in range(4):
		var outlet := Vector2(
			strip_rect.position.x + 28.0 + float(outlet_index) * 42.0,
			strip_rect.get_center().y
		)
		draw_circle(outlet, 9.0, Color("2a3032"))
		draw_line(outlet + Vector2(-3.0, -4.0), outlet + Vector2(-3.0, 4.0), Color.BLACK, 2.0)
		draw_line(outlet + Vector2(3.0, -4.0), outlet + Vector2(3.0, 4.0), Color.BLACK, 2.0)


func _draw_power_cables(viewport_size: Vector2) -> void:
	for player_index in _active_player_indices():
		var chainsaw := _chainsaws[player_index] as ChainsawCursor
		if chainsaw == null:
			continue
		var anchor := Vector2(
			viewport_size.x * (0.42 if player_index == PLAYER_ONE else 0.58),
			viewport_size.y - 44.0
		)
		var target := (
			chainsaw.position
			+ _playfield.position
			- Vector2(chainsaw.body_size.x * 0.5 + 28.0, -7.0)
		)
		var points := PackedVector2Array()
		for point_index in range(14):
			var ratio := float(point_index) / 13.0
			var point := anchor.lerp(target, ratio)
			point.y += sin(ratio * PI) * (
				34.0 + sin(_ambient_time * 2.2 + float(player_index)) * 5.0
			)
			points.append(point)
		draw_polyline(points, Color(0.015, 0.02, 0.02, 0.96), 9.0, true)
		var cable_highlight := _player_color(player_index)
		cable_highlight.a = 0.26
		draw_polyline(points, cable_highlight, 2.0, true)


func _draw_sawdust_motes(viewport_size: Vector2, desk_top: float) -> void:
	var desk_height := maxf(viewport_size.y - desk_top - 90.0, 1.0)
	for mote_index in range(22):
		var drift_speed := 3.0 + float(mote_index % 5) * 1.3
		var mote := Vector2(
			fmod(
				float(mote_index * 173) + _ambient_time * drift_speed,
				viewport_size.x
			),
			desk_top + 24.0 + fmod(float(mote_index * 67), desk_height)
		)
		mote.y += sin(_ambient_time * 0.9 + float(mote_index)) * 8.0
		draw_circle(
			mote,
			1.2 + float(mote_index % 3) * 0.6,
			Color(SAWDUST, 0.1 + float(mote_index % 4) * 0.025)
		)


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

	if event is InputEventMouseMotion:
		_move_player_one_to((event as InputEventMouseMotion).position)
	elif event is InputEventMouseButton:
		_move_player_one_to((event as InputEventMouseButton).position)
	elif event is InputEventScreenTouch:
		_move_player_one_to((event as InputEventScreenTouch).position)
	elif event is InputEventScreenDrag:
		_move_player_one_to((event as InputEventScreenDrag).position)


func _create_chainsaws() -> void:
	for player_index in _active_player_indices():
		var chainsaw := ChainsawCursor.new()
		chainsaw.configure(player_index, _player_color(player_index))
		chainsaw.set_player_label_visible(Settings.player_labels_enabled())
		chainsaw.set_reduced_motion(_reduced_motion_enabled)
		chainsaw.set_motor_stream(AudioManager.chainsaw_motor_stream())
		chainsaw.set_powered(false)
		chainsaw.z_index = 5
		_playfield.add_child(chainsaw)
		_chainsaws[player_index] = chainsaw


func _reset_chainsaws() -> void:
	var bounds := _play_bounds()
	var center := bounds.get_center()
	var player_one := _chainsaws[PLAYER_ONE] as ChainsawCursor
	player_one.position = (
		Vector2(lerpf(bounds.position.x, bounds.end.x, 0.3), center.y)
		if GameSession.player_two_enabled()
		else center
	)
	player_one.clamp_to(bounds)

	if GameSession.player_two_enabled():
		var player_two := _chainsaws[PLAYER_TWO] as ChainsawCursor
		player_two.position = Vector2(
			lerpf(bounds.position.x, bounds.end.x, 0.7),
			center.y
		)
		player_two.clamp_to(bounds)


func _update_chainsaws(delta: float) -> void:
	var bounds := _play_bounds()
	for player_index in _active_player_indices():
		var chainsaw := _chainsaws[player_index] as ChainsawCursor
		var movement_velocity := combine_movement_velocity(
			_keyboard_direction(player_index),
			_controller_direction(player_index),
			chainsaw_speed,
			_controller_movement_speed()
		)
		if not movement_velocity.is_zero_approx():
			chainsaw.position += movement_velocity * delta
		chainsaw.clamp_to(bounds)


func _keyboard_direction(player_index: int) -> Vector2:
	var keyboard_player := (
		PLAYER_ONE if GameSession.is_single_player() else PLAYER_TWO
	)
	if player_index != keyboard_player:
		return Vector2.ZERO

	return Vector2(
		float(Input.is_physical_key_pressed(KEY_RIGHT))
			- float(Input.is_physical_key_pressed(KEY_LEFT)),
		float(Input.is_physical_key_pressed(KEY_DOWN))
			- float(Input.is_physical_key_pressed(KEY_UP))
	)


func _controller_direction(player_index: int) -> Vector2:
	var device := GameSession.controller_device_for_player(player_index)
	if device < 0:
		return Vector2.ZERO

	var horizontal_axis := (
		JOY_AXIS_RIGHT_X
		if Settings.controller_uses_right_stick()
		else JOY_AXIS_LEFT_X
	)
	var vertical_axis := (
		JOY_AXIS_RIGHT_Y
		if Settings.controller_uses_right_stick()
		else JOY_AXIS_LEFT_Y
	)
	var direction := Vector2(
		Input.get_joy_axis(device, horizontal_axis),
		Input.get_joy_axis(device, vertical_axis)
	)
	direction = apply_controller_deadzone(direction, Settings.controller_deadzone())

	if Settings.controller_dpad_enabled():
		direction.x += (
			float(Input.is_joy_button_pressed(device, JOY_BUTTON_DPAD_RIGHT))
			- float(Input.is_joy_button_pressed(device, JOY_BUTTON_DPAD_LEFT))
		)
		direction.y += (
			float(Input.is_joy_button_pressed(device, JOY_BUTTON_DPAD_DOWN))
			- float(Input.is_joy_button_pressed(device, JOY_BUTTON_DPAD_UP))
		)
	return direction


static func apply_controller_deadzone(direction: Vector2, deadzone: float) -> Vector2:
	var filtered := direction
	if absf(filtered.x) < deadzone:
		filtered.x = 0.0
	if absf(filtered.y) < deadzone:
		filtered.y = 0.0
	return filtered


static func combine_movement_velocity(
	keyboard_direction: Vector2,
	controller_direction: Vector2,
	keyboard_speed: float,
	controller_speed: float
) -> Vector2:
	var keyboard_input := keyboard_direction.limit_length()
	var controller_input := controller_direction.limit_length()
	var maximum_speed := 0.0
	if not keyboard_input.is_zero_approx():
		maximum_speed = maxf(maximum_speed, keyboard_speed)
	if not controller_input.is_zero_approx():
		maximum_speed = maxf(maximum_speed, controller_speed)
	if is_zero_approx(maximum_speed):
		return Vector2.ZERO

	var velocity := (
		keyboard_input * keyboard_speed
		+ controller_input * controller_speed
	)
	return velocity.limit_length(maximum_speed)


func _controller_movement_speed() -> float:
	return chainsaw_speed * Settings.controller_movement_scale()


func _move_player_one_to(viewport_position: Vector2) -> void:
	var chainsaw := _chainsaws[PLAYER_ONE] as ChainsawCursor
	if chainsaw == null:
		return
	chainsaw.position = viewport_position
	chainsaw.clamp_to(_play_bounds())


func _spawn_can() -> void:
	var bounds := _play_bounds()
	var can := SliceCan.new()
	var color: Color = CAN_COLORS[_rng.randi_range(0, CAN_COLORS.size() - 1)]
	var effective_radius := _effective_can_radius()
	can.configure(
		effective_radius,
		Vector2(
			_rng.randf_range(-150.0, 150.0),
			_rng.randf_range(145.0, 245.0)
		),
		_rng.randf_range(165.0, 255.0),
		color,
		_rng.randf_range(-2.8, 2.8)
	)
	can.set_reduced_motion(_reduced_motion_enabled)
	can.position = Vector2(
		_rng.randf_range(
			bounds.position.x + effective_radius,
			bounds.end.x - effective_radius
		),
		bounds.position.y - effective_radius
	)
	_playfield.add_child(can)
	_cans.append(can)
	_spawned_cans += 1


func _update_cans(delta: float) -> void:
	var bounds := _play_bounds()
	for entry in _cans.duplicate():
		var can := entry as SliceCan
		if not is_instance_valid(can):
			_cans.erase(entry)
			continue

		if can.advance(delta * _round_gameplay_speed, bounds):
			var impact_position := Vector2(
				can.position.x,
				bounds.end.y - 8.0
			)
			var impact_color := can.can_color
			_cans.erase(can)
			can.queue_free()
			_escaped_cans += 1
			_streaks = [0, 0]
			_update_streaks()
			_spawn_clatter_effect(impact_position, impact_color)
			if _escaped_cans % 2 == 1:
				AudioManager.play_can_clatter()
			AudioManager.request_caption("Can missed")
			continue

		for player_index in _active_player_indices():
			var chainsaw := _chainsaws[player_index] as ChainsawCursor
			if can.try_slice(chainsaw.collision_rect()):
				_score_slice(player_index, can)
				break


func _score_slice(player_index: int, can: SliceCan) -> void:
	var slice_position := can.position
	var slice_color := can.can_color
	var slice_rotation := can.rotation
	var slice_radius := can.radius
	_cans.erase(can)
	can.queue_free()

	_scores[player_index] += points_per_can
	var now := Time.get_ticks_msec() * 0.001
	if now - float(_last_slice_times[player_index]) <= combo_window:
		_streaks[player_index] += 1
	else:
		_streaks[player_index] = 1
	_last_slice_times[player_index] = now
	_best_streaks[player_index] = maxi(
		_best_streaks[player_index],
		_streaks[player_index]
	)

	var chainsaw := _chainsaws[player_index] as ChainsawCursor
	if chainsaw != null:
		chainsaw.trigger_cut()
	AudioManager.play_can_slice(_streaks[player_index])
	AudioManager.request_caption("Player %d sliced a can" % (player_index + 1))
	_spawn_slice_effect(
		slice_position,
		slice_color,
		player_index,
		slice_rotation,
		slice_radius
	)
	_flash_screen(_player_color(player_index), 0.1)
	_add_screen_shake(minf(4.0 + float(_streaks[player_index]) * 0.55, 9.5))
	_update_scores()
	_update_streaks()


func _play_bounds() -> Rect2:
	var viewport_size := get_viewport_rect().size
	var minimum := Vector2(SIDE_CLEARANCE, TOP_CLEARANCE)
	var maximum := Vector2(
		viewport_size.x - SIDE_CLEARANCE,
		viewport_size.y - BOTTOM_CLEARANCE
	)
	if maximum.x < minimum.x:
		minimum.x = viewport_size.x * 0.5
		maximum.x = minimum.x
	if maximum.y < minimum.y:
		minimum.y = viewport_size.y * 0.5
		maximum.y = minimum.y
	return Rect2(minimum, maximum - minimum)


func _configure_mode_ui() -> void:
	var multiplayer := GameSession.player_two_enabled()
	var controller_movement := Settings.controller_movement_scheme_label()
	_mode_title.text = GameInfo.DESK_CAN_SAW_TITLE.to_upper()
	_callout.text = "DRIVE THE CHAIN THROUGH EACH CAN"
	_player_one_caption.text = (
		"PLAYER 1 · MOUSE / PAD 1"
		if multiplayer
		else "PLAYER 1 · SOLO · MOUSE / ARROWS / PAD 1"
	)
	_player_one_card.size_flags_horizontal = (
		Control.SIZE_SHRINK_BEGIN if multiplayer else Control.SIZE_EXPAND_FILL
	)
	_player_two_card.visible = multiplayer
	_player_two_caption.text = "PLAYER 2 · ARROWS / PAD 2"
	_round_versus.visible = multiplayer
	_round_player_two_card.visible = multiplayer
	_round_player_two_caption.text = "PLAYER 2"
	_stats_versus.visible = multiplayer
	_player_two_stats_card.visible = multiplayer
	_player_two_stats_title.text = "PLAYER 2"
	_hint.text = (
		(
			"P1: mouse or Pad 1   |   P2: arrows or Pad 2   |   "
			+ "Pads: %s" % controller_movement
		)
		if multiplayer
		else (
			"Mouse, arrow keys or Pad 1 (%s)   |   " % controller_movement
			+ "Drive the moving chain through each can"
		)
	)
	_round_instructions.text = (
		"Each can awards +%d once. Keep every powered saw on the wood workbench."
		% points_per_can
	)


func _active_player_indices() -> Array[int]:
	var players: Array[int] = [PLAYER_ONE]
	if GameSession.player_two_enabled():
		players.append(PLAYER_TWO)
	return players


func _player_color(player_index: int) -> Color:
	return player_one_color if player_index == PLAYER_ONE else player_two_color


func _update_scores() -> void:
	_player_one_score.text = "%d" % _scores[PLAYER_ONE]
	_player_two_score.text = "%d" % _scores[PLAYER_TWO]


func _update_streaks() -> void:
	for player_index in _active_player_indices():
		var label := (
			_player_one_streak if player_index == PLAYER_ONE else _player_two_streak
		)
		var streak: int = _streaks[player_index]
		label.text = "COMBO x%d" % streak if streak >= 2 else " "
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


func _start_round() -> void:
	_round_id += 1
	_round_timer.stop()
	_load_round_assists()
	_clear_cans()
	_clear_world_fx()
	_scores = [0, 0]
	_streaks = [0, 0]
	_best_streaks = [0, 0]
	_last_slice_times = [-1000.0, -1000.0]
	_spawned_cans = 0
	_escaped_cans = 0
	_spawn_time = 0.0
	_round_active = true
	_round_over.hide()
	_score_panel.hide()
	_round_panel.show()
	_round_panel.modulate = Color.WHITE
	_round_panel.scale = Vector2.ONE
	_share_status.hide()
	_screen_flash.color = _with_alpha(Color.WHITE, 0.0)
	_danger_overlay.color = _with_alpha(DANGER_COLOR, 0.0)
	_shake_strength = 0.0
	_playfield.position = Vector2.ZERO
	_world_fx.position = Vector2.ZERO
	_reset_chainsaws()
	_set_chainsaws_powered(true)
	_update_scores()
	_update_streaks()
	_time_progress.max_value = _active_round_duration
	_time_progress.value = _active_round_duration
	_round_timer.start(_active_round_duration)
	_update_time(int(ceil(_active_round_duration)))
	AudioManager.play_chainsaw_start()
	AudioManager.request_caption(
		"Chainsaw powered" if GameSession.is_single_player() else "Chainsaws powered"
	)
	_show_announcement("POWER UP!", Color("ffd34e"))


func _clear_cans() -> void:
	for can in _cans:
		if is_instance_valid(can):
			can.queue_free()
	_cans.clear()


func _clear_world_fx() -> void:
	for child in _world_fx.get_children():
		child.queue_free()


func _on_round_timer_timeout() -> void:
	_round_active = false
	_set_chainsaws_powered(false)
	_update_time(0)
	_time_progress.value = 0.0
	_update_urgency(_active_round_duration)
	_clear_cans()

	var player_one_total: int = _scores[PLAYER_ONE]
	var player_two_total: int = _scores[PLAYER_TWO]
	_round_player_one_score.text = "%d" % player_one_total
	_round_player_two_score.text = "%d" % player_two_total

	var result_text := "DRAW!"
	var celebration_color := GameInfo.CREAM
	if GameSession.is_single_player():
		result_text = "ROUND COMPLETE"
		_round_subtitle.text = "Player 1 shredded %d cans across the workbench in %d seconds." % [
			player_one_total,
			roundi(_active_round_duration),
		]
		celebration_color = player_one_color
	elif player_one_total > player_two_total:
		result_text = "PLAYER 1 WINS!"
		_round_subtitle.text = "Player 1's electric chainsaw wins by %d cans." % (
			player_one_total - player_two_total
		)
		celebration_color = player_one_color
	elif player_two_total > player_one_total:
		result_text = "PLAYER 2 WINS!"
		_round_subtitle.text = "Player 2's electric chainsaw wins by %d cans." % (
			player_two_total - player_one_total
		)
		celebration_color = player_two_color
	else:
		_round_subtitle.text = "Both saws left the desk even after %d seconds." % (
			roundi(_active_round_duration)
		)

	_result_label.text = result_text
	_result_label.add_theme_color_override("font_color", celebration_color)
	_round_highlight.text = "%s  |  %d cans escaped" % [
		_best_combo_summary(),
		_escaped_cans,
	]
	_populate_score_screen(result_text, celebration_color)
	_spawn_round_confetti(celebration_color)
	_round_over.show()
	_score_panel.hide()
	_round_panel.show()
	_animate_modal_panel(_round_panel)
	_play_again_button.grab_focus.call_deferred()


func _best_combo_summary() -> String:
	var player_one_best: int = _best_streaks[PLAYER_ONE]
	if GameSession.is_single_player():
		return "Best combo: x%d" % player_one_best
	var player_two_best: int = _best_streaks[PLAYER_TWO]
	if player_one_best == player_two_best:
		return "Shared best combo: x%d" % player_one_best
	if player_one_best > player_two_best:
		return "Best combo: Player 1 x%d" % player_one_best
	return "Best combo: Player 2 x%d" % player_two_best


func _populate_score_screen(result_text: String, result_color: Color) -> void:
	var total_slices: int = _scores[PLAYER_ONE] + _scores[PLAYER_TWO]
	_score_screen_title.text = result_text
	_score_screen_title.add_theme_color_override("font_color", result_color)
	_score_screen_subtitle.text = _round_subtitle.text
	_game_duration_stat.text = "%d SEC" % roundi(_active_round_duration)
	_game_hits_stat.text = "%d" % total_slices
	_game_accuracy_stat.text = "%d%%" % _accuracy_percent(total_slices, _spawned_cans)

	_populate_player_stats(PLAYER_ONE)
	_populate_player_stats(PLAYER_TWO)


func _populate_player_stats(player_index: int) -> void:
	var score: int = _scores[player_index]
	var misses := maxi(_spawned_cans - score, 0)
	var accuracy := _accuracy_percent(score, _spawned_cans)
	if player_index == PLAYER_ONE:
		_player_one_stats_score.text = "%d" % score
		_player_one_stats_hits.text = "%d" % score
		_player_one_stats_misses.text = "%d" % misses
		_player_one_stats_accuracy.text = "%d%%" % accuracy
		_player_one_stats_streak.text = "x%d" % _best_streaks[player_index]
	else:
		_player_two_stats_score.text = "%d" % score
		_player_two_stats_hits.text = "%d" % score
		_player_two_stats_misses.text = "%d" % misses
		_player_two_stats_accuracy.text = "%d%%" % accuracy
		_player_two_stats_streak.text = "x%d" % _best_streaks[player_index]


func _accuracy_percent(hits: int, opportunities: int) -> int:
	if opportunities <= 0:
		return 0
	return roundi(float(hits) / float(opportunities) * 100.0)


func _spawn_slice_effect(
	world_position: Vector2,
	color: Color,
	player_index: int,
	can_rotation: float,
	effect_radius: float
) -> void:
	if _reduced_motion_enabled:
		_spawn_reduced_slice_effect(
			world_position,
			color,
			player_index,
			can_rotation,
			effect_radius
		)
		return
	_spawn_can_halves(world_position, color, can_rotation, effect_radius)
	_spawn_cut_sparks(world_position, color)

	var slash := Line2D.new()
	slash.points = PackedVector2Array([
		Vector2(-effect_radius * 1.6, 0.0),
		Vector2(effect_radius * 1.6, 0.0),
	])
	slash.width = 8.0
	slash.default_color = Color("fff4b0")
	slash.position = world_position
	slash.rotation = can_rotation - 0.22
	slash.z_index = 24
	_world_fx.add_child(slash)
	var slash_tween := slash.create_tween().set_parallel(true)
	slash_tween.tween_property(slash, "scale:x", 1.45, 0.18).set_trans(
		Tween.TRANS_QUAD
	).set_ease(Tween.EASE_OUT)
	slash_tween.tween_property(slash, "width", 1.0, 0.22)
	slash_tween.tween_property(slash, "modulate:a", 0.0, 0.22)
	slash_tween.finished.connect(slash.queue_free)

	var ring := Line2D.new()
	var points := PackedVector2Array()
	for point_index in range(25):
		var angle := TAU * float(point_index) / 24.0
		points.append(Vector2.RIGHT.rotated(angle) * effect_radius)
	ring.points = points
	ring.width = 4.0
	ring.default_color = color.lightened(0.35)
	ring.position = world_position
	ring.z_index = 20
	_world_fx.add_child(ring)

	var ring_tween := ring.create_tween().set_parallel(true)
	ring_tween.tween_property(ring, "scale", Vector2.ONE * 2.2, 0.34).set_trans(
		Tween.TRANS_QUAD
	).set_ease(Tween.EASE_OUT)
	ring_tween.tween_property(ring, "modulate:a", 0.0, 0.34)
	ring_tween.finished.connect(ring.queue_free)

	var label := Label.new()
	label.text = "SAWED  +%d  ·  P%d" % [points_per_can, player_index + 1]
	label.position = world_position + Vector2(-120.0, -72.0)
	label.size = Vector2(240.0, 52.0)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.add_theme_color_override("font_color", _player_color(player_index))
	label.add_theme_color_override("font_outline_color", Color(0.0, 0.0, 0.0, 0.94))
	label.add_theme_constant_override("outline_size", 7)
	label.add_theme_font_size_override("font_size", 28)
	label.z_index = 21
	_world_fx.add_child(label)

	var label_tween := label.create_tween().set_parallel(true)
	label_tween.tween_property(label, "position:y", label.position.y - 72.0, 0.5)
	label_tween.tween_property(label, "modulate:a", 0.0, 0.5).set_delay(0.12)
	label_tween.finished.connect(label.queue_free)


func _spawn_reduced_slice_effect(
	world_position: Vector2,
	color: Color,
	player_index: int,
	can_rotation: float,
	effect_radius: float
) -> void:
	var slash := Line2D.new()
	slash.points = PackedVector2Array([
		Vector2(-effect_radius * 1.5, 0.0),
		Vector2(effect_radius * 1.5, 0.0),
	])
	slash.width = 6.0
	slash.default_color = Color("fff4b0")
	slash.position = world_position
	slash.rotation = can_rotation - 0.22
	slash.z_index = 24
	_world_fx.add_child(slash)

	var label := Label.new()
	label.text = "SAWED  +%d  ·  P%d" % [points_per_can, player_index + 1]
	label.position = world_position + Vector2(-120.0, -72.0)
	label.size = Vector2(240.0, 52.0)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.add_theme_color_override("font_color", color)
	label.add_theme_color_override(
		"font_outline_color",
		Color(0.0, 0.0, 0.0, 0.94)
	)
	label.add_theme_constant_override("outline_size", 7)
	label.add_theme_font_size_override("font_size", 28)
	label.z_index = 25
	_world_fx.add_child(label)

	var tween := create_tween()
	tween.tween_interval(0.45)
	tween.tween_property(slash, "modulate:a", 0.0, 0.15)
	tween.parallel().tween_property(label, "modulate:a", 0.0, 0.15)
	tween.finished.connect(slash.queue_free)
	tween.finished.connect(label.queue_free)


func _spawn_can_halves(
	world_position: Vector2,
	color: Color,
	can_rotation: float,
	effect_radius: float
) -> void:
	for side in [-1.0, 1.0]:
		var half := Polygon2D.new()
		half.polygon = PackedVector2Array([
			Vector2(0.0, -effect_radius * 0.82),
			Vector2(side * effect_radius * 0.62, -effect_radius * 0.68),
			Vector2(side * effect_radius * 0.76, -effect_radius * 0.2),
			Vector2(side * effect_radius * 0.78, effect_radius * 0.62),
			Vector2(0.0, effect_radius * 0.82),
		])
		half.color = (
			color.lightened(0.14)
			if side < 0.0
			else color.darkened(0.18)
		)
		half.position = world_position
		half.rotation = can_rotation
		half.z_index = 18
		_world_fx.add_child(half)

		var cut_edge := Line2D.new()
		cut_edge.points = PackedVector2Array([
			Vector2(0.0, -effect_radius * 0.8),
			Vector2(0.0, effect_radius * 0.8),
		])
		cut_edge.width = 4.0
		cut_edge.default_color = Color("f7ffff")
		half.add_child(cut_edge)

		var end_position := world_position + Vector2(
			side * _rng.randf_range(105.0, 170.0),
			_rng.randf_range(115.0, 210.0)
		)
		var half_tween := half.create_tween().set_parallel(true)
		half_tween.tween_property(half, "position", end_position, 0.58).set_trans(
			Tween.TRANS_QUAD
		).set_ease(Tween.EASE_IN)
		half_tween.tween_property(
			half,
			"rotation",
			can_rotation + side * _rng.randf_range(2.8, 5.4),
			0.58
		)
		half_tween.tween_property(half, "modulate:a", 0.0, 0.58).set_delay(0.28)
		half_tween.finished.connect(half.queue_free)


func _spawn_cut_sparks(world_position: Vector2, can_color: Color) -> void:
	for spark_index in range(18):
		var direction := Vector2.RIGHT.rotated(
			_rng.randf_range(-PI, PI)
		)
		var spark := Line2D.new()
		spark.points = PackedVector2Array([
			Vector2.ZERO,
			direction * _rng.randf_range(10.0, 30.0),
		])
		spark.width = _rng.randf_range(1.5, 3.8)
		spark.default_color = (
			Color("fff09a")
			if spark_index % 3 != 0
			else can_color.lightened(0.3)
		)
		spark.position = world_position
		spark.z_index = 23
		_world_fx.add_child(spark)
		var spark_tween := spark.create_tween().set_parallel(true)
		spark_tween.tween_property(
			spark,
			"position",
			world_position
				+ direction * _rng.randf_range(54.0, 145.0)
				+ Vector2(0.0, _rng.randf_range(18.0, 74.0)),
			0.34
		).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		spark_tween.tween_property(spark, "modulate:a", 0.0, 0.34).set_delay(0.08)
		spark_tween.finished.connect(spark.queue_free)

	for shard_index in range(10):
		var shard := Polygon2D.new()
		var shard_size := _rng.randf_range(3.0, 8.0)
		shard.polygon = PackedVector2Array([
			Vector2(-shard_size, -shard_size * 0.35),
			Vector2(shard_size, 0.0),
			Vector2(-shard_size * 0.5, shard_size * 0.45),
		])
		shard.color = (
			Color("dce6e7")
			if shard_index % 2 == 0
			else SAWDUST
		)
		shard.position = world_position
		shard.rotation = _rng.randf_range(0.0, TAU)
		shard.z_index = 22
		_world_fx.add_child(shard)
		var shard_direction := Vector2.RIGHT.rotated(_rng.randf_range(0.0, TAU))
		var shard_tween := shard.create_tween().set_parallel(true)
		shard_tween.tween_property(
			shard,
			"position",
			world_position
				+ shard_direction * _rng.randf_range(42.0, 110.0)
				+ Vector2(0.0, _rng.randf_range(36.0, 105.0)),
			0.48
		)
		shard_tween.tween_property(
			shard,
			"rotation",
			shard.rotation + _rng.randf_range(-5.0, 5.0),
			0.48
		)
		shard_tween.tween_property(shard, "modulate:a", 0.0, 0.48).set_delay(0.2)
		shard_tween.finished.connect(shard.queue_free)


func _spawn_clatter_effect(world_position: Vector2, can_color: Color) -> void:
	if _reduced_motion_enabled:
		return
	for chip_index in range(9):
		var chip := Polygon2D.new()
		var chip_size := _rng.randf_range(3.0, 7.0)
		chip.polygon = PackedVector2Array([
			Vector2(-chip_size, -chip_size),
			Vector2(chip_size, -chip_size * 0.4),
			Vector2(chip_size * 0.6, chip_size),
			Vector2(-chip_size * 0.7, chip_size * 0.8),
		])
		chip.color = (
			can_color.darkened(0.18)
			if chip_index % 3 == 0
			else SAWDUST.darkened(_rng.randf_range(0.0, 0.25))
		)
		chip.position = world_position
		chip.rotation = _rng.randf_range(0.0, TAU)
		chip.z_index = 14
		_world_fx.add_child(chip)
		var chip_tween := chip.create_tween().set_parallel(true)
		chip_tween.tween_property(
			chip,
			"position",
			world_position + Vector2(
				_rng.randf_range(-65.0, 65.0),
				_rng.randf_range(-28.0, 32.0)
			),
			0.38
		).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		chip_tween.tween_property(chip, "modulate:a", 0.0, 0.38).set_delay(0.12)
		chip_tween.finished.connect(chip.queue_free)


func _spawn_round_confetti(color: Color) -> void:
	if _reduced_motion_enabled:
		return
	var bounds := _play_bounds()
	for index in range(24):
		var piece := Polygon2D.new()
		piece.polygon = PackedVector2Array([
			Vector2(-7.0, -3.0),
			Vector2(9.0, -5.0),
			Vector2(6.0, 4.0),
			Vector2(-8.0, 5.0),
		])
		piece.color = (
			color.lightened(_rng.randf_range(0.0, 0.3))
			if index % 3 == 0
			else Color("d9e2e3")
			if index % 3 == 1
			else Color("ffd34e")
		)
		piece.position = Vector2(
			_rng.randf_range(bounds.position.x, bounds.end.x),
			_rng.randf_range(bounds.position.y, bounds.end.y)
		)
		piece.rotation = _rng.randf_range(0.0, TAU)
		_world_fx.add_child(piece)
		var tween := piece.create_tween().set_parallel(true)
		tween.tween_property(
			piece,
			"position:y",
			piece.position.y + _rng.randf_range(90.0, 210.0),
			0.75
		)
		tween.tween_property(piece, "rotation", piece.rotation + TAU, 0.75)
		tween.tween_property(piece, "modulate:a", 0.0, 0.75).set_delay(0.2)
		tween.finished.connect(piece.queue_free)


func _set_chainsaws_powered(powered: bool) -> void:
	for player_index in _active_player_indices():
		var chainsaw := _chainsaws[player_index] as ChainsawCursor
		if chainsaw != null:
			chainsaw.set_powered(powered)


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
		_playfield.position = Vector2.ZERO
		_world_fx.position = Vector2.ZERO
		return

	var offset := Vector2(
		_rng.randf_range(-_shake_strength, _shake_strength),
		_rng.randf_range(-_shake_strength, _shake_strength)
	)
	_playfield.position = offset
	_world_fx.position = offset
	_shake_strength = move_toward(
		_shake_strength,
		0.0,
		delta * SHAKE_DECAY
	)


func _flash_screen(color: Color, alpha: float) -> void:
	if _flash_tween and _flash_tween.is_valid():
		_flash_tween.kill()
	if not _intense_effects_enabled:
		_flash_tween = null
		_screen_flash.color = _with_alpha(color, 0.0)
		return
	_screen_flash.color = _with_alpha(color, alpha)
	_flash_tween = create_tween()
	_flash_tween.tween_property(_screen_flash, "color:a", 0.0, 0.28)


func _show_announcement(text: String, color: Color) -> void:
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
		_announcement_tween.tween_interval(0.28)
		_announcement_tween.tween_property(
			_announcement,
			"modulate:a",
			0.0,
			0.16
		)
		_announcement_tween.finished.connect(_announcement.hide)
		return
	_announcement.scale = Vector2.ONE * 0.72
	_announcement.modulate.a = 0.0
	_announcement_tween = create_tween()
	_announcement_tween.tween_property(_announcement, "modulate:a", 1.0, 0.1)
	_announcement_tween.parallel().tween_property(
		_announcement,
		"scale",
		Vector2.ONE,
		0.2
	).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_announcement_tween.tween_interval(0.28)
	_announcement_tween.tween_property(_announcement, "modulate:a", 0.0, 0.18)
	_announcement_tween.finished.connect(_announcement.hide)


func _animate_modal_panel(panel: Control) -> void:
	if _round_panel_tween and _round_panel_tween.is_valid():
		_round_panel_tween.kill()
	panel.pivot_offset = panel.size * 0.5
	if _reduced_motion_enabled:
		panel.scale = Vector2.ONE
		panel.modulate = Color.WHITE
		return
	panel.scale = Vector2.ONE * 0.82
	panel.modulate.a = 0.0
	_round_panel_tween = create_tween().set_parallel(true)
	_round_panel_tween.tween_property(panel, "scale", Vector2.ONE, 0.3).set_trans(
		Tween.TRANS_BACK
	).set_ease(Tween.EASE_OUT)
	_round_panel_tween.tween_property(panel, "modulate:a", 1.0, 0.16)


func _on_play_again_pressed() -> void:
	_start_round()


func _on_exit_to_main_menu_pressed() -> void:
	_round_timer.stop()
	_set_chainsaws_powered(false)
	Router.goto(main_menu_scene)


func _on_see_score_pressed() -> void:
	_round_panel.hide()
	_score_panel.show()
	_animate_modal_panel(_score_panel)
	_back_to_results_button.grab_focus.call_deferred()


func _on_back_to_results_pressed() -> void:
	_show_round_results()


func _show_round_results() -> void:
	_score_panel.hide()
	_round_panel.show()
	_animate_modal_panel(_round_panel)
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


func _on_share_pressed() -> void:
	if _sharing:
		return
	_sharing = true
	var shared_round_id := _round_id
	_set_share_buttons_disabled(true)
	_show_share_status("Building your share image...", GameInfo.MUTED, false)

	var result: Dictionary = await ShareManager.generate_score_image(_share_payload())
	if not is_inside_tree():
		return

	_sharing = false
	_set_share_buttons_disabled(false)
	if shared_round_id != _round_id:
		return
	if bool(result.get("ok", false)):
		AudioManager.play_share()
		ShareManager.show_preview(result)
		_show_share_status(str(result.get("message", "Share image ready.")), GameInfo.SKY)
	else:
		AudioManager.play_game_miss()
		var message := str(result.get("message", "The share image could not be created."))
		push_warning(message)
		_show_share_status(message, DANGER_COLOR)


func _share_payload() -> Dictionary:
	var total_slices: int = _scores[PLAYER_ONE] + _scores[PLAYER_TWO]
	var best_combo := maxi(_best_streaks[PLAYER_ONE], _best_streaks[PLAYER_TWO])
	return {
		"game_title": GameInfo.DESK_CAN_SAW_TITLE,
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
		"accuracy": "%d%%" % _accuracy_percent(total_slices, _spawned_cans),
		"hits": str(total_slices),
		"combo": "x%d" % best_combo,
		"achievements": _share_achievement_titles(),
		"achievements_are_new": false,
		"achievement_count": AchievementManager.unlocked_count(),
		"achievement_badge": "ACH",
		"accent_color": (
			player_one_color
			if GameSession.is_single_player() or _scores[PLAYER_ONE] >= _scores[PLAYER_TWO]
			else player_two_color
		),
		"secondary_color": player_two_color if GameSession.player_two_enabled() else player_one_color,
		"footer": "%s  |  %s" % [GameInfo.TAGLINE, GameInfo.WEBSITE],
	}


func _share_achievement_titles() -> PackedStringArray:
	var titles := PackedStringArray()
	for achievement in AchievementManager.get_unlocked_achievements():
		titles.append(str(achievement.get("title", "Achievement")))
	return titles


func _set_share_buttons_disabled(disabled: bool) -> void:
	_share_button.disabled = disabled
	_stats_share_button.disabled = disabled


func _show_share_status(message: String, color: Color, auto_hide := true) -> void:
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


func _on_setting_changed(key: String, value: Variant) -> void:
	if key == Settings.VISUAL_EFFECTS_KEY:
		_set_intense_effects_enabled(bool(value))
		return
	if key == Settings.REDUCED_MOTION_KEY:
		_set_reduced_motion_enabled(bool(value))
		return
	if key == Settings.PLAYER_LABELS_KEY:
		_apply_chainsaw_labels()
		return
	if key.begins_with("controls/"):
		_configure_mode_ui()


func _set_intense_effects_enabled(value: bool) -> void:
	_intense_effects_enabled = value
	if not value:
		_reset_intense_effects()


func _set_reduced_motion_enabled(value: bool) -> void:
	_reduced_motion_enabled = value
	for entry in _chainsaws:
		var chainsaw := entry as ChainsawCursor
		if chainsaw != null:
			chainsaw.set_reduced_motion(value)
	for entry in _cans:
		var can := entry as SliceCan
		if can != null:
			can.set_reduced_motion(value)
	if value:
		_ambient_time = 0.0
		_reset_reduced_motion_state()
	queue_redraw()


func _load_round_assists() -> void:
	_active_round_duration = round_duration + Settings.extra_round_time()
	_round_gameplay_speed = Settings.gameplay_speed_scale()
	_round_target_size = Settings.target_size_scale()


func _effective_can_radius() -> float:
	return can_radius * _round_target_size


func _apply_chainsaw_labels() -> void:
	for entry in _chainsaws:
		var chainsaw := entry as ChainsawCursor
		if chainsaw != null:
			chainsaw.set_player_label_visible(Settings.player_labels_enabled())


func _reset_intense_effects() -> void:
	if _flash_tween and _flash_tween.is_valid():
		_flash_tween.kill()
	_flash_tween = null
	_shake_strength = 0.0
	_playfield.position = Vector2.ZERO
	_world_fx.position = Vector2.ZERO
	_screen_flash.color = _with_alpha(Color.WHITE, 0.0)


func _reset_reduced_motion_state() -> void:
	_shake_strength = 0.0
	_playfield.position = Vector2.ZERO
	_world_fx.position = Vector2.ZERO
	_danger_overlay.color = _with_alpha(DANGER_COLOR, 0.0)
	_time_label.scale = Vector2.ONE
	_clear_world_fx()
	if _announcement_tween and _announcement_tween.is_valid():
		_announcement_tween.kill()
	_announcement.hide()
	if _round_panel_tween and _round_panel_tween.is_valid():
		_round_panel_tween.kill()
	for panel in [_round_panel, _score_panel]:
		panel.scale = Vector2.ONE
		panel.modulate = Color.WHITE


func _with_alpha(color: Color, alpha: float) -> Color:
	var result := color
	result.a = alpha
	return result
