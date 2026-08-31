class_name SplashMotion
extends Control

## Lightweight animated geometry for splash screens. Keep this behind the
## game's logo and change the exported colors to reuse it in another project.

@export var primary_color := Color("afddea")
@export var secondary_color := Color("4da3ff")
@export_range(4, 24, 1) var shape_count := 12
@export_range(0.05, 2.0, 0.05) var speed := 0.45

var _time := 0.0


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	if Settings.reduced_motion_enabled():
		set_process(false)
		queue_redraw()


func _process(delta: float) -> void:
	_time += delta * speed
	queue_redraw()


func _draw() -> void:
	if size.x <= 0.0 or size.y <= 0.0:
		return

	var center := size * 0.5
	var short_axis := minf(size.x, size.y)
	var pulse := (sin(_time * 2.2) + 1.0) * 0.5
	draw_circle(center, short_axis * (0.2 + pulse * 0.015), _alpha(primary_color, 0.045))
	draw_arc(
		center,
		short_axis * 0.31,
		_time * 0.7,
		_time * 0.7 + PI * 1.45,
		72,
		_alpha(primary_color, 0.22),
		3.0,
		true
	)
	draw_arc(
		center,
		short_axis * 0.39,
		-_time * 0.45,
		-_time * 0.45 + PI * 1.15,
		72,
		_alpha(secondary_color, 0.14),
		2.0,
		true
	)

	for index in range(shape_count):
		var ratio := float(index) / float(maxi(shape_count, 1))
		var lane := 0.22 + fmod(float(index) * 0.137, 0.72)
		var drift := Vector2(
			sin(_time * (0.8 + ratio) + index * 1.7) * short_axis * 0.025,
			cos(_time * (0.55 + ratio) + index * 1.3) * short_axis * 0.02
		)
		var shape_center := Vector2(
			size.x * lane,
			size.y * (0.16 + fmod(float(index) * 0.193, 0.7))
		) + drift
		var radius := short_axis * (0.018 + float(index % 3) * 0.008)
		var color := primary_color if index % 2 == 0 else secondary_color
		draw_polyline(
			_triangle(shape_center, radius, _time * (-0.4 if index % 2 else 0.4) + index),
			_alpha(color, 0.11 + ratio * 0.07),
			1.5,
			true
		)


func _triangle(center: Vector2, radius: float, rotation: float) -> PackedVector2Array:
	var points := PackedVector2Array()
	for index in range(3):
		points.append(center + Vector2.UP.rotated(rotation + TAU * float(index) / 3.0) * radius)
	points.append(points[0])
	return points


func _alpha(color: Color, value: float) -> Color:
	var result := color
	result.a = value
	return result
