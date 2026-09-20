extends GameShell

## Fast score-chasing game for solo play, local multiplayer or a CPU opponent.
##
## The HUD, countdown, pause overlay, results panels and share card all come
## from `GameShell`; this script only owns the triangles, the input matching
## and the Triangle Rush scoring rules.

@export var target_scene: PackedScene
@export var player_one_inactive_color := Color("31556f")
@export var player_two_inactive_color := Color("6b343d")
@export_range(100.0, 800.0, 10.0) var target_speed := 320.0
# Design-time default for the end-of-round speed rush; players override it
# under Settings -> Game.
@export_range(0.0, 1.0, 0.05) var final_speed_boost := 0.35
@export_range(1, 100, 1) var points_per_match := 1
@export_range(1, 100, 1) var miss_penalty := 1

## Matches the folder name and `games/triangle_rush/game.gd`, so this scene can
## look up its own manifest without the framework naming it.
const GAME_ID := "triangle_rush"
const SPAWN_ATTEMPTS := 20
const BACKGROUND_TRIANGLE_COUNT := 12
const BURST_SHARDS := 9
const MISS_COLOR := Color("ffc857")

var _targets: Array[TriangleTarget] = []
var _targets_by_action: Dictionary = {}
var _active_targets := [null, null]
var _correct_hits := [0, 0]
var _misses := [0, 0]
var _score_tweens: Array = [null, null]
var _streak_tweens: Array = [null, null]
var _cpu_action_time := -1.0
var _cpu_reaction_min := 0.55
var _cpu_reaction_max := 1.05
var _cpu_accuracy := 0.82
var _round_length := 30.0
var _round_triangle_speed := 1.0
var _round_triangle_size := 1.0
var _round_speed_rush := 0.35


func game_id() -> String:
	return GAME_ID


func _prepare_session() -> void:
	super()
	_configure_cpu_profile()


func _build_playfield() -> void:
	_create_targets()


func _begin_first_round() -> void:
	if not _has_targets_for_every_player():
		return
	_update_hint()
	_start_round_after_transition()


func _update_round(delta: float, time_left: float) -> void:
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


func _handle_gameplay_input(event: InputEvent) -> void:
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


func _draw() -> void:
	var viewport_size := get_viewport_rect().size
	if viewport_size.x <= 0.0 or viewport_size.y <= 0.0:
		return

	var multiplayer := GameSession.player_two_enabled()
	var left_glow := _with_alpha(player_one_color, 0.035)
	var glow_radius := viewport_size.y * 0.36
	draw_circle(
		Vector2(viewport_size.x * (0.18 if multiplayer else 0.5), viewport_size.y * 0.57),
		glow_radius + sin(_ambient_time * 0.8) * 18.0,
		left_glow
	)
	if multiplayer:
		var right_glow := _with_alpha(player_two_color, 0.035)
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
			_with_alpha(player_one_color, 0.085)
			if on_left
			else _with_alpha(player_two_color, 0.085)
		)
		draw_polyline(_triangle_outline(center, radius, rotation), color, 1.5, true)


func _target_for_keyboard_event(event: InputEventKey) -> TriangleTarget:
	for action: StringName in _targets_by_action:
		if event.is_action_pressed(action):
			var target := _targets_by_action[action] as TriangleTarget
			if Settings.one_button_targets_enabled() and target != null:
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
	if Settings.one_button_targets_enabled():
		return _active_targets[player_index] as TriangleTarget

	var actions := Settings.control_actions_for_player(player_index)
	if target_index >= actions.size():
		return null
	return _targets_by_action.get(actions[target_index]) as TriangleTarget


func _controller_player_index(device: int) -> int:
	return GameSession.controller_player_index(device)


func _configure_mode_ui() -> void:
	super()
	var player_two_enabled := GameSession.player_two_enabled()
	var player_two_title := GameSession.player_two_name().to_upper()
	var player_one_keys := Settings.control_summary(PLAYER_ONE, "  ")
	var player_two_keys := Settings.control_summary(PLAYER_TWO, "  ")
	var mapped_buttons := Settings.controller_target_summary(" / ")
	var controller_keys := (
		"ANY %s" % mapped_buttons
		if Settings.one_button_targets_enabled()
		else mapped_buttons
	)
	var gamepad := GameSession.gamepad_connected()
	var player_one_pad := " · PAD %s" % controller_keys if gamepad else ""

	_player_one_caption.text = (
		"PLAYER 1 · KEYS %s%s" % [player_one_keys, player_one_pad]
		if player_two_enabled
		else "PLAYER 1 · SOLO · KEYS %s%s" % [player_one_keys, player_one_pad]
	)
	_player_two_caption.text = (
		"%s · %s · AUTO" % [player_two_title, GameSession.cpu_difficulty_title().to_upper()]
		if GameSession.player_two_is_cpu()
		else "%s · KEYS %s%s" % [
			player_two_title,
			player_two_keys,
			" · PAD 2 %s" % controller_keys if gamepad else "",
		]
	)
	_update_callout()
	_update_hint()


func _on_player_labels_changed() -> void:
	for target in _targets:
		target.set_player_label_visible(Settings.player_labels_enabled())
	_update_hint()


func _on_controls_changed() -> void:
	for action: StringName in _targets_by_action:
		var target := _targets_by_action[action] as TriangleTarget
		if is_instance_valid(target):
			target.set_display_letter(Settings.control_key_label(action).to_upper())
	_configure_mode_ui()


func _on_game_setting_changed(key: String, _value: Variant) -> void:
	if key == Settings.ONE_BUTTON_TARGETS_KEY:
		_configure_mode_ui()


func _set_reduced_motion_enabled(value: bool) -> void:
	for target in _targets:
		target.set_reduced_motion(value)
	super(value)
	_update_callout()


## Reads this game's own options and the shared next-round assists together, so
## both only take effect when a round starts.
func _load_round_settings() -> void:
	super()
	_round_length = Settings.tunable(TriangleRushOptions.ROUND_LENGTH_KEY)
	_round_triangle_speed = Settings.tunable(TriangleRushOptions.SPEED_KEY)
	_round_triangle_size = Settings.tunable(TriangleRushOptions.SIZE_KEY)
	_round_speed_rush = Settings.tunable(TriangleRushOptions.SPEED_RUSH_KEY)
	_active_round_duration = _round_length + Settings.extra_round_time()


## Scene speed combined with the triangle-speed option, the assist and the
## optional end-of-round rush.
func _target_move_speed(rush_multiplier := 1.0) -> float:
	return target_speed * _round_triangle_speed * _round_gameplay_speed * rush_multiplier


## Triangle-size option combined with the handicap assist.
func _target_size_scale() -> float:
	return _round_triangle_size * _round_target_size


func _player_accepts_human_input(player_index: int) -> bool:
	# A player who has spent their last life is out for the rest of the round,
	# but the others keep playing until everybody is out.
	if _player_is_out(player_index):
		return false
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
	if _player_is_out(PLAYER_TWO):
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
	elif Settings.one_button_targets_enabled():
		var mapped_buttons := Settings.controller_target_summary("/")
		var gamepad := GameSession.gamepad_connected()
		if GameSession.is_single_player():
			_hint.text = (
				(
					"Press any P1 key or %s   |   " % mapped_buttons
					if gamepad
					else "Press any P1 key   |   "
				)
				+ "Follow the highlighted target   |   Correct +%d"
				% points_per_match
			)
		elif GameSession.player_two_is_cpu():
			_hint.text = (
				(
					"Any P1 key or %s   |   " % mapped_buttons
					if gamepad
					else "Any P1 key   |   "
				)
				+ "Follow your highlighted target   |   CPU controls P2"
			)
		elif gamepad:
			_hint.text = (
				"Any assigned key or mapped controller button activates "
				+ "each player's highlighted target"
			)
		else:
			_hint.text = (
				"Any assigned key activates each player's highlighted target"
			)
	else:
		var controller_keys := Settings.controller_target_summary(" ")
		var gamepad := GameSession.gamepad_connected()
		if GameSession.is_single_player():
			_hint.text = (
				"P1 keys: %s   |   Pad: %s   |   Follow the highlighted target"
				% [_letters_hint(PLAYER_ONE), controller_keys]
				if gamepad
				else "P1 keys: %s   |   Follow the highlighted target"
				% _letters_hint(PLAYER_ONE)
			)
		elif GameSession.player_two_is_cpu():
			_hint.text = (
				"P1: %s / pad %s   |   %s CPU controls P2" % [
					_letters_hint(PLAYER_ONE),
					controller_keys,
					GameSession.cpu_difficulty_title(),
				]
				if gamepad
				else "P1: %s   |   %s CPU controls P2" % [
					_letters_hint(PLAYER_ONE),
					GameSession.cpu_difficulty_title(),
				]
			)
		else:
			_hint.text = (
				"P1: %s / pad 1   |   P2: %s / pad 2   |   %s" % [
					_letters_hint(PLAYER_ONE),
					_letters_hint(PLAYER_TWO),
					controller_keys,
				]
				if gamepad
				else "P1: %s   |   P2: %s" % [
					_letters_hint(PLAYER_ONE),
					_letters_hint(PLAYER_TWO),
				]
			)
	if Settings.one_button_targets_enabled():
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
	var lives_note := _lives_rule_note()
	if not lives_note.is_empty():
		_hint.text += "   |   %s" % lives_note
		_round_instructions.text += " | %s" % lives_note


func _update_callout() -> void:
	var cue := "HIGHLIGHT" if _reduced_motion_enabled else "PULSE"
	var control := (
		"ANY ASSIGNED CONTROL"
		if Settings.one_button_targets_enabled()
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

		_playfield.add_child(target)
		target.configure(
			Settings.control_key_label(action).to_upper(),
			player_index,
			_player_inactive_color(player_index),
			_player_color(player_index),
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


func _reset_round_state() -> void:
	_correct_hits = [0, 0]
	_misses = [0, 0]
	_active_targets = [null, null]
	_cpu_action_time = -1.0

	for target in _targets:
		target.move_speed = _target_move_speed()
		target.set_size_scale(_target_size_scale())
		target.set_target_enabled(true)
		target.set_highlighted(false)
		_place_target(target)
		target.play_spawn()

	for player_index in _active_player_indices():
		_select_next_target(player_index)


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
			_player_color(player_index),
			true,
			"+%d" % points_per_match
		)
		_flash_screen(_player_color(player_index), 0.12)
		_add_screen_shake(4.0)
		_place_target(target)
		target.play_spawn()
		_select_next_target(player_index)

		if _streaks[player_index] >= 3 and (
			_streaks[player_index] == 3 or _streaks[player_index] % 5 == 0
		):
			_show_announcement(
				"%d HIT STREAK!" % _streaks[player_index],
				_player_color(player_index)
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
		# A wrong key or triangle is this game's mistake, so it is what the
		# shared lives round mode charges for. No-op under the countdown.
		_lose_life(player_index)

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


func _reset_reduced_motion_state() -> void:
	super()
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


func _round_totals() -> Dictionary:
	var total_hits := 0
	var total_attempts := 0
	for player_index in _active_player_indices():
		total_hits += int(_correct_hits[player_index])
		total_attempts += int(_correct_hits[player_index]) + int(_misses[player_index])
	return {"hits": total_hits, "attempts": total_attempts}


func _player_stats(player_index: int) -> Dictionary:
	return {
		"score": _scores[player_index],
		"hits": _correct_hits[player_index],
		"misses": _misses[player_index],
		"accuracy": _player_accuracy(player_index),
		"streak": _best_streaks[player_index],
	}


func _player_accuracy(player_index: int) -> int:
	var attempts: int = _correct_hits[player_index] + _misses[player_index]
	return _accuracy_percent(_correct_hits[player_index], attempts)


func _player_inactive_color(player_index: int) -> Color:
	return player_one_inactive_color if player_index == PLAYER_ONE else player_two_inactive_color


func _triangle_outline(center: Vector2, radius: float, rotation: float) -> PackedVector2Array:
	var points := PackedVector2Array()
	for point_index in range(3):
		points.append(
			center + Vector2.UP.rotated(rotation + TAU * float(point_index) / 3.0) * radius
		)
	points.append(points[0])
	return points


func _on_target_activated(target: TriangleTarget) -> void:
	_attempt_target(target)


func _finish_round() -> void:
	_cpu_action_time = -1.0
	for target in _targets:
		target.set_highlighted(false)
		target.set_target_enabled(false)
	_active_targets = [null, null]


func _award_round_achievements(player_one_total: int, player_two_total: int) -> void:
	if GameSession.is_single_player():
		_unlock_round_achievement("first_single_player_game")
		return
	if player_one_total > player_two_total:
		_unlock_round_achievement("first_win")
		return
	# A draw is not a loss, so Race condition needs a decisive Player 2 win.
	if (
		player_two_total > player_one_total
		and player_two_total >= TriangleRushOptions.RACE_CONDITION_SCORE
	):
		_unlock_round_achievement("race_condition")
