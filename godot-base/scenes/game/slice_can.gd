class_name SliceCan
extends Node2D

const CAN_METAL := Color("aebbc0")
const CAN_DARK := Color("344149")
const CAN_HIGHLIGHT := Color("eef5f5")
const LABEL_INK := Color("172127")
const ELECTRIC_YELLOW := Color("ffd34e")

var radius := 34.0
var velocity := Vector2.ZERO
var gravity := 220.0
var sliced := false
var can_color := GameInfo.SKY
var _spin_speed := 0.0
var _reduced_motion := false


func configure(
	can_radius: float,
	initial_velocity: Vector2,
	fall_gravity: float,
	color: Color,
	spin_speed: float
) -> void:
	radius = can_radius
	velocity = initial_velocity
	gravity = fall_gravity
	can_color = color
	_spin_speed = spin_speed
	sliced = false
	show()
	queue_redraw()


func advance(delta: float, play_bounds: Rect2) -> bool:
	if sliced:
		return false

	velocity.y += gravity * delta
	position += velocity * delta
	if not _reduced_motion:
		rotation += _spin_speed * delta

	var minimum_x := play_bounds.position.x + radius
	var maximum_x := play_bounds.end.x - radius
	if maximum_x < minimum_x:
		position.x = play_bounds.get_center().x
	elif position.x < minimum_x:
		position.x = minimum_x
		velocity.x = absf(velocity.x)
	elif position.x > maximum_x:
		position.x = maximum_x
		velocity.x = -absf(velocity.x)

	return position.y - radius > play_bounds.end.y


func set_reduced_motion(enabled: bool) -> void:
	_reduced_motion = enabled


func try_slice(chainsaw_rect: Rect2) -> bool:
	if sliced:
		return false

	var closest_point := Vector2(
		clampf(position.x, chainsaw_rect.position.x, chainsaw_rect.end.x),
		clampf(position.y, chainsaw_rect.position.y, chainsaw_rect.end.y)
	)
	if position.distance_squared_to(closest_point) > radius * radius:
		return false

	sliced = true
	hide()
	return true


func _draw() -> void:
	var can_width := radius * 1.34
	var can_height := radius * 1.72
	var half_width := can_width * 0.5
	var half_height := can_height * 0.5
	var rim_height := radius * 0.22

	draw_colored_polygon(
		_ellipse_points(
			Vector2(5.0, half_height * 0.78 + 8.0),
			Vector2(half_width * 1.02, rim_height * 1.4),
			24
		),
		Color(0.0, 0.0, 0.0, 0.28)
	)

	var body := PackedVector2Array([
		Vector2(-half_width * 0.9, -half_height + rim_height * 0.45),
		Vector2(half_width * 0.9, -half_height + rim_height * 0.45),
		Vector2(half_width, half_height - rim_height * 0.45),
		Vector2(-half_width, half_height - rim_height * 0.45),
	])
	draw_colored_polygon(body, can_color.darkened(0.18))
	draw_rect(
		Rect2(
			Vector2(-half_width * 0.72, -half_height + rim_height),
			Vector2(half_width * 0.28, can_height - rim_height * 2.0)
		),
		Color(CAN_HIGHLIGHT, 0.34)
	)
	draw_rect(
		Rect2(
			Vector2(half_width * 0.58, -half_height + rim_height),
			Vector2(half_width * 0.18, can_height - rim_height * 2.0)
		),
		Color(CAN_DARK, 0.18)
	)

	var label_rect := Rect2(
		Vector2(-half_width * 0.96, -radius * 0.22),
		Vector2(half_width * 1.92, radius * 0.52)
	)
	draw_rect(label_rect, can_color.darkened(0.42))
	draw_rect(label_rect.grow(-3.0), LABEL_INK)
	draw_line(
		Vector2(-half_width * 0.72, 0.0),
		Vector2(half_width * 0.72, 0.0),
		Color(can_color, 0.48),
		2.0,
		true
	)
	_draw_electric_mark(Vector2.ZERO, radius * 0.34)

	var top_rim := _ellipse_points(
		Vector2(0.0, -half_height + rim_height * 0.45),
		Vector2(half_width * 0.9, rim_height),
		28
	)
	draw_colored_polygon(top_rim, CAN_METAL.lightened(0.08))
	draw_polyline(
		_ellipse_points(
			Vector2(0.0, -half_height + rim_height * 0.45),
			Vector2(half_width * 0.9, rim_height),
			28,
			true
		),
		CAN_HIGHLIGHT,
		2.0,
		true
	)
	draw_colored_polygon(
		_ellipse_points(
			Vector2(0.0, -half_height + rim_height * 0.45),
			Vector2(half_width * 0.63, rim_height * 0.58),
			24
		),
		CAN_DARK.lightened(0.28)
	)
	draw_polyline(
		_ellipse_points(
			Vector2(4.0, -half_height + rim_height * 0.45),
			Vector2(radius * 0.22, rim_height * 0.3),
			18,
			true
		),
		CAN_HIGHLIGHT,
		2.0,
		true
	)

	var bottom_center := Vector2(0.0, half_height - rim_height * 0.45)
	draw_polyline(
		_ellipse_points(
			bottom_center,
			Vector2(half_width, rim_height),
			28,
			true
		),
		CAN_METAL.darkened(0.12),
		3.0,
		true
	)
	draw_line(
		Vector2(-half_width * 0.86, -half_height + rim_height * 1.2),
		Vector2(-half_width * 0.94, half_height - rim_height * 1.1),
		CAN_HIGHLIGHT,
		2.0,
		true
	)
	draw_line(
		Vector2(half_width * 0.84, -half_height + rim_height * 1.2),
		Vector2(half_width * 0.94, half_height - rim_height * 1.1),
		CAN_DARK,
		2.0,
		true
	)


func _ellipse_points(
	center: Vector2,
	radii: Vector2,
	segments: int,
	closed := false
) -> PackedVector2Array:
	var points := PackedVector2Array()
	var point_count := segments + 1 if closed else segments
	for point_index in range(point_count):
		var angle := TAU * float(point_index % segments) / float(segments)
		points.append(center + Vector2(
			cos(angle) * radii.x,
			sin(angle) * radii.y
		))
	return points


func _draw_electric_mark(center: Vector2, size: float) -> void:
	draw_colored_polygon(
		PackedVector2Array([
			center + Vector2(-size * 0.08, -size * 0.52),
			center + Vector2(size * 0.32, -size * 0.52),
			center + Vector2(size * 0.06, -size * 0.08),
			center + Vector2(size * 0.36, -size * 0.08),
			center + Vector2(-size * 0.3, size * 0.54),
			center + Vector2(-size * 0.08, size * 0.12),
			center + Vector2(-size * 0.36, size * 0.12),
		]),
		ELECTRIC_YELLOW
	)
