extends GameShell

## Electric chainsaw score chase staged over a procedural workshop desk.
##
## The HUD, countdown, pause overlay, results panels and share card all come
## from `GameShell`; this script only owns the workshop art, the chainsaws,
## the cans and the slicing rules.

@export_range(1, 100, 1) var points_per_can := 1
@export_range(0.1, 2.0, 0.05) var minimum_spawn_interval := 0.28
@export_range(0.1, 2.0, 0.05) var maximum_spawn_interval := 0.48
@export_range(1, 100, 1) var maximum_cans := 24
@export_range(100.0, 1600.0, 10.0) var chainsaw_speed := 920.0
@export_range(10.0, 100.0, 1.0) var can_radius := 34.0
@export_range(0.1, 5.0, 0.1) var combo_window := 1.25

## Matches the folder name and `games/slice_and_slash/game.gd`.
const GAME_ID := "slice_and_slash"
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

var _cans: Array[SliceCan] = []
var _chainsaws := [null, null]
var _last_slice_times := [-1000.0, -1000.0]
var _spawned_cans := 0
var _escaped_cans := 0
var _spawn_time := 0.0


func game_id() -> String:
	return GAME_ID


## Desk-Can-Saw is a two-human game; a CPU opponent never drives a chainsaw.
func _prepare_session() -> void:
	if GameSession.player_two_is_cpu():
		GameSession.configure_multiplayer(GameSession.PlayerTwoController.HUMAN)
		return
	super()


func _build_playfield() -> void:
	_create_chainsaws()


func _update_round(delta: float, _time_left: float) -> void:
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


func _handle_gameplay_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion:
		_move_player_one_to((event as InputEventMouseMotion).position)
	elif event is InputEventMouseButton:
		_move_player_one_to((event as InputEventMouseButton).position)
	elif event is InputEventScreenTouch:
		_move_player_one_to((event as InputEventScreenTouch).position)
	elif event is InputEventScreenDrag:
		_move_player_one_to((event as InputEventScreenDrag).position)


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
	var bounds := _playfield_bounds()
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
	var bounds := _playfield_bounds()
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
	chainsaw.clamp_to(_playfield_bounds())


func _spawn_can() -> void:
	var bounds := _playfield_bounds()
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
	var bounds := _playfield_bounds()
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
			# A can that reaches the bench is this game's mistake, so it is
			# what the shared lives round mode charges for. No-op under the
			# countdown.
			_lose_life(_closest_player_to(impact_position))
			continue

		for player_index in _active_player_indices():
			if _player_is_out(player_index):
				continue
			var chainsaw := _chainsaws[player_index] as ChainsawCursor
			if can.try_slice(chainsaw.collision_rect()):
				_score_slice(player_index, can)
				break


## The saw that had the best chance at a can, so an escape is charged to the
## player who came closest to catching it. Both saws roam the whole bench, so
## the side a can fell on says nothing about whose miss it was.
##
## Returns -1 when nobody is left to charge, which [method _lose_life] ignores.
func _closest_player_to(target_position: Vector2) -> int:
	var closest := -1
	var best_distance := INF
	for player_index in _active_player_indices():
		if _player_is_out(player_index):
			continue
		var chainsaw := _chainsaws[player_index] as ChainsawCursor
		if not is_instance_valid(chainsaw):
			continue
		var distance := chainsaw.position.distance_to(target_position)
		if distance < best_distance:
			best_distance = distance
			closest = player_index
	return closest


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


func _configure_mode_ui() -> void:
	super()
	var multiplayer := GameSession.player_two_enabled()
	var controller_movement := Settings.controller_movement_scheme_label()
	var gamepad := GameSession.gamepad_connected()
	_callout.text = "DRIVE THE CHAIN THROUGH EACH CAN"
	if gamepad:
		_player_one_caption.text = (
			"PLAYER 1 · MOUSE / PAD 1"
			if multiplayer
			else "PLAYER 1 · SOLO · MOUSE / ARROWS / PAD 1"
		)
		_player_two_caption.text = "PLAYER 2 · ARROWS / PAD 2"
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
	else:
		_player_one_caption.text = (
			"PLAYER 1 · MOUSE"
			if multiplayer
			else "PLAYER 1 · SOLO · MOUSE / ARROWS"
		)
		_player_two_caption.text = "PLAYER 2 · ARROWS"
		_hint.text = (
			"P1: mouse   |   P2: arrow keys"
			if multiplayer
			else (
				"Mouse or arrow keys   |   "
				+ "Drive the moving chain through each can"
			)
		)
	_round_instructions.text = (
		"Each can awards +%d once. Keep every powered saw on the wood workbench."
		% points_per_can
	)
	var lives_note := _lives_rule_note()
	if not lives_note.is_empty():
		_hint.text += "   |   %s" % lives_note
		_round_instructions.text += " %s." % lives_note


func _reset_round_state() -> void:
	_clear_cans()
	_clear_world_fx()
	_last_slice_times = [-1000.0, -1000.0]
	_spawned_cans = 0
	_escaped_cans = 0
	_spawn_time = 0.0
	_reset_chainsaws()
	_set_chainsaws_powered(true)


func _activate_round() -> void:
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


func _finish_round() -> void:
	_set_chainsaws_powered(false)
	_clear_cans()


func _describe_round_outcome(
	player_one_total: int,
	player_two_total: int
) -> Dictionary:
	if GameSession.is_single_player():
		return {
			"result": "ROUND COMPLETE",
			"subtitle": (
				"Player 1 shredded %d cans across the workbench in %s."
				% [player_one_total, _round_length_phrase()]
			),
			"color": _player_color(PLAYER_ONE),
		}
	if player_one_total > player_two_total:
		return {
			"result": "PLAYER 1 WINS!",
			"subtitle": "Player 1's electric chainsaw wins by %d cans." % (
				player_one_total - player_two_total
			),
			"color": _player_color(PLAYER_ONE),
		}
	if player_two_total > player_one_total:
		return {
			"result": "PLAYER 2 WINS!",
			"subtitle": "Player 2's electric chainsaw wins by %d cans." % (
				player_two_total - player_one_total
			),
			"color": _player_color(PLAYER_TWO),
		}
	return {
		"result": "DRAW!",
		"subtitle": "Both saws left the desk even after %s." % (
			_round_length_phrase()
		),
		"color": StudioInfo.CREAM,
	}


func _round_highlight_summary() -> String:
	return "%s  |  %d cans escaped" % [super(), _escaped_cans]


func _round_totals() -> Dictionary:
	return {"hits": _total_slice_count(), "attempts": _spawned_cans}


func _player_stats(player_index: int) -> Dictionary:
	var slices := _player_slice_count(player_index)
	return {
		"score": _scores[player_index],
		"hits": slices,
		"misses": maxi(_spawned_cans - slices, 0),
		"accuracy": _accuracy_percent(slices, _spawned_cans),
		"streak": _best_streaks[player_index],
	}


func _player_slice_count(player_index: int) -> int:
	return floori(float(_scores[player_index]) / float(maxi(points_per_can, 1)))


func _total_slice_count() -> int:
	return (
		_player_slice_count(PLAYER_ONE)
		+ _player_slice_count(PLAYER_TWO)
	)


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


func _set_chainsaws_powered(powered: bool) -> void:
	for player_index in _active_player_indices():
		var chainsaw := _chainsaws[player_index] as ChainsawCursor
		if chainsaw != null:
			chainsaw.set_powered(powered)


func _set_reduced_motion_enabled(value: bool) -> void:
	for entry in _chainsaws:
		var chainsaw := entry as ChainsawCursor
		if chainsaw != null:
			chainsaw.set_reduced_motion(value)
	for entry in _cans:
		var can := entry as SliceCan
		if can != null:
			can.set_reduced_motion(value)
	super(value)


func _on_player_labels_changed() -> void:
	for entry in _chainsaws:
		var chainsaw := entry as ChainsawCursor
		if chainsaw != null:
			chainsaw.set_player_label_visible(Settings.player_labels_enabled())


func _effective_can_radius() -> float:
	return can_radius * _round_target_size
