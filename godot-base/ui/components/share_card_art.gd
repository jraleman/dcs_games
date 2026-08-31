class_name ShareCardArt
extends Control

## Static promotional artwork rendered inside a share card. It echoes the
## procedural game visuals without instantiating gameplay nodes or audio.

const ELECTRIC_YELLOW := Color("ffd34e")
const METAL := Color("b8c7cb")
const DARK_METAL := Color("1b252b")

var _game_id := GameInfo.TARGET_RUSH_ID
var _accent := GameInfo.SKY
var _secondary := Color("4da3ff")


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	queue_redraw()


func configure(data: Dictionary) -> void:
	_game_id = str(data.get("game_id", GameInfo.TARGET_RUSH_ID))
	_accent = data.get("accent_color", GameInfo.SKY)
	_secondary = data.get("secondary_color", Color("4da3ff"))
	queue_redraw()


func _notification(what: int) -> void:
	if what == NOTIFICATION_RESIZED:
		queue_redraw()


func _draw() -> void:
	if size.x <= 0.0 or size.y <= 0.0:
		return
	draw_circle(
		Vector2(size.x * 0.52, size.y * 0.5),
		minf(size.x, size.y) * 0.44,
		_alpha(_accent, 0.08)
	)
	if _game_id == GameInfo.SLICE_AND_SLASH_ID:
		_draw_desk_can_saw()
	else:
		_draw_target_rush()


func _draw_target_rush() -> void:
	var centers := [
		Vector2(size.x * 0.28, size.y * 0.28),
		Vector2(size.x * 0.68, size.y * 0.24),
		Vector2(size.x * 0.6, size.y * 0.7),
		Vector2(size.x * 0.28, size.y * 0.78),
	]
	for index in range(centers.size()):
		var center: Vector2 = centers[index]
		var color := _accent if index % 2 == 0 else _secondary
		var radius := 28.0 if index != 2 else 43.0
		var trail_length := 62.0 + float(index) * 13.0
		draw_line(
			center - Vector2(trail_length, 12.0 + float(index) * 4.0),
			center - Vector2(radius * 0.45, 2.0),
			_alpha(color, 0.18),
			8.0 if index == 2 else 5.0,
			true
		)
		draw_circle(center, radius * 1.35, _alpha(color, 0.1))
		var triangle := _triangle(center, radius, -0.2 + float(index) * 0.7)
		draw_colored_polygon(triangle, color.darkened(0.2))
		draw_polyline(
			_closed(triangle),
			color.lightened(0.35),
			4.0 if index == 2 else 3.0,
			true
		)
		var inset := _triangle(
			center,
			radius * 0.53,
			-0.2 + float(index) * 0.7
		)
		draw_colored_polygon(inset, _alpha(Color.WHITE, 0.16))

	for spark_index in range(8):
		var angle := -1.0 + float(spark_index) * 0.42
		var start := Vector2(size.x * 0.54, size.y * 0.48)
		var direction := Vector2.RIGHT.rotated(angle)
		draw_line(
			start + direction * 58.0,
			start + direction * (72.0 + float(spark_index % 3) * 8.0),
			_alpha(ELECTRIC_YELLOW, 0.72),
			2.5,
			true
		)


func _draw_desk_can_saw() -> void:
	draw_set_transform(
		Vector2(size.x * 0.66, size.y * 0.33),
		0.18,
		Vector2.ONE
	)
	_draw_can(37.0, _secondary)

	draw_set_transform(
		Vector2(size.x * 0.7, size.y * 0.76),
		-0.24,
		Vector2.ONE * 0.82
	)
	_draw_can(34.0, _accent)

	draw_set_transform(
		Vector2(size.x * 0.1, size.y * 0.56),
		-0.18,
		Vector2.ONE
	)
	_draw_chainsaw()
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)

	var impact := Vector2(size.x * 0.68, size.y * 0.53)
	draw_circle(impact, 30.0, _alpha(ELECTRIC_YELLOW, 0.12))
	for spark_index in range(11):
		var angle := -1.45 + float(spark_index) * 0.29
		var direction := Vector2.RIGHT.rotated(angle)
		var inner := 18.0 + float(spark_index % 2) * 7.0
		var outer := 42.0 + float(spark_index % 4) * 9.0
		draw_line(
			impact + direction * inner,
			impact + direction * outer,
			_alpha(ELECTRIC_YELLOW, 0.88),
			3.0 if spark_index % 3 == 0 else 2.0,
			true
		)


func _draw_chainsaw() -> void:
	var blade_start := 68.0
	var blade_end := 210.0
	var blade_half_height := 17.0
	var blade_rect := Rect2(
		Vector2(blade_start, -blade_half_height),
		Vector2(blade_end - blade_start, blade_half_height * 2.0)
	)
	draw_rect(blade_rect, DARK_METAL)
	draw_circle(Vector2(blade_end, 0.0), blade_half_height, DARK_METAL)
	draw_rect(blade_rect.grow(-4.0), METAL.darkened(0.25))
	draw_circle(
		Vector2(blade_end, 0.0),
		blade_half_height - 4.0,
		METAL.darkened(0.25)
	)
	draw_line(
		Vector2(blade_start + 6.0, 0.0),
		Vector2(blade_end - 2.0, 0.0),
		METAL.lightened(0.28),
		2.0,
		true
	)
	for tooth_index in range(11):
		var tooth_x := blade_start + float(tooth_index) * 13.0
		draw_line(
			Vector2(tooth_x, -blade_half_height),
			Vector2(tooth_x + 5.0, -blade_half_height - 7.0),
			ELECTRIC_YELLOW,
			2.5,
			true
		)
		draw_line(
			Vector2(tooth_x + 5.0, blade_half_height),
			Vector2(tooth_x, blade_half_height + 7.0),
			ELECTRIC_YELLOW,
			2.5,
			true
		)

	var housing := PackedVector2Array([
		Vector2(0.0, -34.0),
		Vector2(78.0, -29.0),
		Vector2(92.0, -8.0),
		Vector2(84.0, 32.0),
		Vector2(4.0, 36.0),
		Vector2(-13.0, 10.0),
	])
	draw_colored_polygon(housing, _accent.darkened(0.22))
	draw_polyline(
		_closed(housing),
		_accent.lightened(0.35),
		3.0,
		true
	)
	draw_circle(Vector2(37.0, 2.0), 22.0, DARK_METAL)
	draw_circle(Vector2(37.0, 2.0), 13.0, _accent.lightened(0.08))
	draw_colored_polygon(
		PackedVector2Array([
			Vector2(31.0, -9.0),
			Vector2(43.0, -9.0),
			Vector2(37.0, 0.0),
			Vector2(47.0, 0.0),
			Vector2(29.0, 15.0),
			Vector2(34.0, 5.0),
			Vector2(25.0, 5.0),
		]),
		ELECTRIC_YELLOW
	)


func _draw_can(radius: float, color: Color) -> void:
	var half_width := radius * 0.67
	var half_height := radius * 0.86
	var body := PackedVector2Array([
		Vector2(-half_width * 0.9, -half_height + 5.0),
		Vector2(half_width * 0.9, -half_height + 5.0),
		Vector2(half_width, half_height - 5.0),
		Vector2(-half_width, half_height - 5.0),
	])
	draw_colored_polygon(body, color.darkened(0.2))
	draw_rect(
		Rect2(
			Vector2(-half_width * 0.98, -radius * 0.2),
			Vector2(half_width * 1.96, radius * 0.45)
		),
		DARK_METAL
	)
	draw_colored_polygon(
		PackedVector2Array([
			Vector2(-4.0, -11.0),
			Vector2(7.0, -11.0),
			Vector2(1.0, -1.0),
			Vector2(10.0, -1.0),
			Vector2(-8.0, 13.0),
			Vector2(-3.0, 4.0),
			Vector2(-11.0, 4.0),
		]),
		ELECTRIC_YELLOW
	)
	var top := _ellipse_points(
		Vector2(0.0, -half_height + 5.0),
		Vector2(half_width * 0.9, 7.0),
		24
	)
	draw_colored_polygon(top, METAL)
	draw_polyline(_closed(top), METAL.lightened(0.2), 2.0, true)
	draw_polyline(
		_closed(
			_ellipse_points(
				Vector2(0.0, half_height - 5.0),
				Vector2(half_width, 7.0),
				24
			)
		),
		METAL.darkened(0.16),
		3.0,
		true
	)


func _triangle(center: Vector2, radius: float, rotation: float) -> PackedVector2Array:
	var points := PackedVector2Array()
	for index in range(3):
		points.append(
			center
			+ Vector2.UP.rotated(rotation + TAU * float(index) / 3.0) * radius
		)
	return points


func _ellipse_points(
	center: Vector2,
	radii: Vector2,
	segments: int
) -> PackedVector2Array:
	var points := PackedVector2Array()
	for index in range(segments):
		var angle := TAU * float(index) / float(segments)
		points.append(
			center
			+ Vector2(cos(angle) * radii.x, sin(angle) * radii.y)
		)
	return points


func _closed(points: PackedVector2Array) -> PackedVector2Array:
	var result := points.duplicate()
	if not result.is_empty():
		result.append(result[0])
	return result


func _alpha(color: Color, value: float) -> Color:
	var result := color
	result.a = value
	return result
