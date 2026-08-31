class_name ChainsawCursor
extends Node2D

const DARK_METAL := Color("182126")
const MID_METAL := Color("52636a")
const LIGHT_METAL := Color("c7d1d3")
const RUBBER := Color("17191a")
const ELECTRIC_YELLOW := Color("ffd34e")
const REDUCED_MOTION_SETTING := "accessibility/reduced_motion"

var player_index := -1
var body_size := Vector2(164.0, 54.0)
var saw_color := GameInfo.SKY
var _motor_stream: AudioStream
var _motor_player: AudioStreamPlayer
var _motor_level := 0.0
var _chain_phase := 0.0
var _impact := 0.0
var _powered := false
var _last_position := Vector2.ZERO
var _player_label: Label
var _show_player_label := true
var _reduced_motion := false


func _ready() -> void:
	_last_position = position
	_motor_player = AudioStreamPlayer.new()
	_motor_player.bus = "SFX"
	_motor_player.stream = _motor_stream
	_motor_player.volume_db = -60.0
	_motor_player.pitch_scale = 0.9 + float(maxi(player_index, 0)) * 0.045
	add_child(_motor_player)
	_create_player_label()
	var settings := get_node_or_null("/root/Settings")
	if settings != null:
		set_reduced_motion(bool(settings.call("reduced_motion_enabled")))
		settings.connect("changed", _on_setting_changed)


func _process(delta: float) -> void:
	var movement_speed := (
		position.distance_to(_last_position) / maxf(delta, 0.001)
	)
	_last_position = position

	var target_motor_level := 0.0
	if _powered:
		target_motor_level = clampf(0.32 + movement_speed / 780.0, 0.32, 1.0)
		if _motor_player.stream != null and not _motor_player.playing:
			_motor_player.play()
	_motor_level = lerpf(
		_motor_level,
		target_motor_level,
		1.0 - exp(-9.0 * delta)
	)
	if _reduced_motion:
		_chain_phase = 0.0
		_impact = 0.0
	else:
		_chain_phase = fmod(
			_chain_phase + delta * lerpf(7.0, 31.0, _motor_level),
			1.0
		)
		_impact = move_toward(_impact, 0.0, delta * 4.8)

	if _motor_player.playing:
		_motor_player.volume_db = lerpf(-34.0, -10.0, _motor_level)
		_motor_player.pitch_scale = (
			0.88
			+ float(maxi(player_index, 0)) * 0.045
			+ _motor_level * 0.22
		)
		if not _powered and _motor_level <= 0.01:
			_motor_player.stop()
	queue_redraw()


func configure(owner_index: int, color: Color, size: Vector2 = Vector2(164.0, 54.0)) -> void:
	player_index = owner_index
	saw_color = color
	body_size = size
	_update_player_label()
	queue_redraw()


func set_player_label_visible(value: bool) -> void:
	_show_player_label = value
	_update_player_label()


func set_reduced_motion(value: bool) -> void:
	_reduced_motion = value
	if value:
		_chain_phase = 0.0
		_impact = 0.0
	queue_redraw()


func set_powered(powered: bool) -> void:
	_powered = powered


func set_motor_stream(stream: AudioStream) -> void:
	_motor_stream = stream
	if _motor_player != null:
		_motor_player.stream = stream


func trigger_cut() -> void:
	if not _reduced_motion:
		_impact = 1.0


func collision_rect() -> Rect2:
	return Rect2(position - body_size * 0.5, body_size)


func clamp_to(play_bounds: Rect2) -> void:
	var half_size := body_size * 0.5
	var minimum := play_bounds.position + half_size
	var maximum := play_bounds.end - half_size
	if maximum.x < minimum.x:
		position.x = play_bounds.get_center().x
	else:
		position.x = clampf(position.x, minimum.x, maximum.x)
	if maximum.y < minimum.y:
		position.y = play_bounds.get_center().y
	else:
		position.y = clampf(position.y, minimum.y, maximum.y)


func _create_player_label() -> void:
	_player_label = Label.new()
	_player_label.name = "PlayerLabel"
	_player_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_player_label.z_index = 8
	_player_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_player_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_player_label.add_theme_color_override("font_color", Color.WHITE)
	_player_label.add_theme_color_override(
		"font_outline_color",
		Color(0.01, 0.02, 0.025, 0.96)
	)
	_player_label.add_theme_constant_override("outline_size", 6)
	_player_label.add_theme_font_size_override("font_size", 17)
	add_child(_player_label)
	_update_player_label()


func _update_player_label() -> void:
	if _player_label == null:
		return
	_player_label.text = "P%d" % (player_index + 1)
	_player_label.position = Vector2(
		-body_size.x * 0.5 + 22.0,
		-body_size.y * 0.5 + 7.0
	)
	_player_label.size = Vector2(44.0, 28.0)
	_player_label.visible = _show_player_label and player_index >= 0


func _on_setting_changed(key: String, value: Variant) -> void:
	if key == REDUCED_MOTION_SETTING:
		set_reduced_motion(bool(value))


func _draw() -> void:
	var half_size := body_size * 0.5
	var blade_start := -body_size.x * 0.08
	var blade_end := half_size.x - 8.0
	var blade_half_height := body_size.y * 0.22
	var motor_center := Vector2(-body_size.x * 0.24, 0.0)

	draw_rect(
		Rect2(-half_size + Vector2(7.0, 9.0), body_size),
		Color(0.0, 0.0, 0.0, 0.3)
	)
	_draw_power_cord(half_size)

	var blade_rect := Rect2(
		Vector2(blade_start, -blade_half_height),
		Vector2(blade_end - blade_start, blade_half_height * 2.0)
	)
	draw_rect(blade_rect, DARK_METAL)
	draw_circle(Vector2(blade_end, 0.0), blade_half_height, DARK_METAL)
	draw_circle(Vector2(blade_start, 0.0), blade_half_height, DARK_METAL)
	draw_rect(blade_rect.grow(-4.0), MID_METAL)
	draw_circle(
		Vector2(blade_end, 0.0),
		maxf(blade_half_height - 4.0, 2.0),
		MID_METAL
	)
	draw_line(
		Vector2(blade_start + 4.0, 0.0),
		Vector2(blade_end - 2.0, 0.0),
		LIGHT_METAL,
		2.0,
		true
	)
	_draw_chain_teeth(blade_start, blade_end, blade_half_height)

	var housing := PackedVector2Array([
		Vector2(-half_size.x + 20.0, -half_size.y + 4.0),
		Vector2(blade_start + 16.0, -half_size.y + 7.0),
		Vector2(blade_start + 22.0, -half_size.y * 0.3),
		Vector2(blade_start + 18.0, half_size.y - 6.0),
		Vector2(-half_size.x + 13.0, half_size.y - 4.0),
		Vector2(-half_size.x + 5.0, 8.0),
	])
	draw_colored_polygon(housing, saw_color.darkened(0.2))
	draw_polyline(
		PackedVector2Array([
			housing[0],
			housing[1],
			housing[2],
			housing[3],
			housing[4],
			housing[5],
			housing[0],
		]),
		saw_color.lightened(0.4),
		3.0,
		true
	)
	draw_circle(
		motor_center,
		body_size.y * 0.28,
		saw_color.lightened(0.08)
	)
	draw_circle(
		motor_center,
		body_size.y * 0.2,
		DARK_METAL.lightened(0.04)
	)
	for vent_index in range(4):
		var vent_x := motor_center.x - 11.0 + float(vent_index) * 7.0
		draw_line(
			Vector2(vent_x, -8.0),
			Vector2(vent_x - 3.0, 8.0),
			MID_METAL,
			2.0,
			true
		)
	_draw_electric_mark(motor_center + Vector2(3.0, 0.0))

	var rear_grip := Rect2(
		Vector2(-half_size.x - 3.0, -11.0),
		Vector2(24.0, 22.0)
	)
	draw_rect(rear_grip, RUBBER)
	draw_rect(rear_grip.grow(-4.0), saw_color.darkened(0.35))

	var top_handle := PackedVector2Array([
		Vector2(-half_size.x + 23.0, -half_size.y + 5.0),
		Vector2(-half_size.x + 29.0, -half_size.y - 18.0),
		Vector2(-body_size.x * 0.08, -half_size.y - 18.0),
		Vector2(-body_size.x * 0.02, -half_size.y + 2.0),
		Vector2(-body_size.x * 0.13, -half_size.y + 5.0),
		Vector2(-body_size.x * 0.18, -half_size.y - 8.0),
		Vector2(-half_size.x + 39.0, -half_size.y - 8.0),
		Vector2(-half_size.x + 36.0, -half_size.y + 5.0),
	])
	draw_colored_polygon(top_handle, RUBBER)
	draw_polyline(
		PackedVector2Array([
			top_handle[0],
			top_handle[1],
			top_handle[2],
			top_handle[3],
			top_handle[4],
			top_handle[5],
			top_handle[6],
			top_handle[7],
			top_handle[0],
		]),
		saw_color.lightened(0.3),
		2.0,
		true
	)

	var motor_glow := saw_color
	motor_glow.a = 0.08 + _motor_level * 0.08 + _impact * 0.16
	draw_circle(
		motor_center,
		body_size.y * (0.34 + _impact * 0.12),
		motor_glow
	)
	_draw_tip_sparks(Vector2(blade_end + blade_half_height, 0.0))


func _draw_chain_teeth(
	blade_start: float,
	blade_end: float,
	blade_half_height: float
) -> void:
	var tooth_spacing := 13.0
	var offset := fmod(_chain_phase * tooth_spacing, tooth_spacing)
	var chain_color := LIGHT_METAL.lerp(ELECTRIC_YELLOW, _motor_level * 0.22)
	for tooth_index in range(9):
		var tooth_x := blade_start - tooth_spacing + float(tooth_index) * tooth_spacing + offset
		if tooth_x < blade_start or tooth_x > blade_end + 2.0:
			continue
		draw_line(
			Vector2(tooth_x, -blade_half_height - 1.0),
			Vector2(tooth_x + 5.0, -blade_half_height - 6.0),
			chain_color,
			3.0,
			true
		)
		draw_line(
			Vector2(tooth_x + 5.0, blade_half_height + 1.0),
			Vector2(tooth_x, blade_half_height + 6.0),
			chain_color,
			3.0,
			true
		)
	draw_arc(
		Vector2(blade_end, 0.0),
		blade_half_height + 3.0,
		-PI * 0.5,
		PI * 0.5,
		12,
		chain_color,
		3.0,
		true
	)


func _draw_power_cord(half_size: Vector2) -> void:
	var points := PackedVector2Array()
	for point_index in range(9):
		var ratio := float(point_index) / 8.0
		points.append(Vector2(
			lerpf(-half_size.x + 8.0, -half_size.x - 36.0, ratio),
			8.0 + sin(ratio * PI * 2.0 + _chain_phase * TAU) * 3.0
		))
	draw_polyline(points, Color(0.02, 0.025, 0.025, 0.95), 7.0, true)
	draw_polyline(points, Color(0.24, 0.29, 0.3, 0.8), 2.0, true)
	var plug_position := points[points.size() - 1]
	draw_rect(
		Rect2(plug_position - Vector2(8.0, 6.0), Vector2(13.0, 12.0)),
		RUBBER
	)
	draw_line(
		plug_position + Vector2(5.0, -3.0),
		plug_position + Vector2(11.0, -3.0),
		LIGHT_METAL,
		2.0
	)
	draw_line(
		plug_position + Vector2(5.0, 3.0),
		plug_position + Vector2(11.0, 3.0),
		LIGHT_METAL,
		2.0
	)


func _draw_electric_mark(center: Vector2) -> void:
	draw_colored_polygon(
		PackedVector2Array([
			center + Vector2(-2.0, -11.0),
			center + Vector2(8.0, -11.0),
			center + Vector2(2.0, -2.0),
			center + Vector2(9.0, -2.0),
			center + Vector2(-6.0, 12.0),
			center + Vector2(-1.0, 3.0),
			center + Vector2(-8.0, 3.0),
		]),
		ELECTRIC_YELLOW
	)


func _draw_tip_sparks(tip: Vector2) -> void:
	var spark_strength := maxf(_impact, (_motor_level - 0.72) * 0.45)
	if spark_strength <= 0.01:
		return
	for spark_index in range(4):
		var pulse := (
			sin((_chain_phase + float(spark_index) * 0.21) * TAU) + 1.0
		) * 0.5
		var direction := Vector2.RIGHT.rotated(
			lerpf(-0.8, 0.8, float(spark_index) / 3.0)
		)
		var spark_color := Color(
			ELECTRIC_YELLOW,
			clampf(spark_strength * (0.45 + pulse * 0.55), 0.0, 1.0)
		)
		draw_line(
			tip,
			tip + direction * (8.0 + pulse * 20.0),
			spark_color,
			2.0 + _impact * 2.0,
			true
		)
