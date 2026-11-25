extends Control

## One owned touch contact steers while other fingers remain free for UI actions.
## The menu forwards touch events before mouse emulation can merge those fingers.

signal direction_changed(direction: Vector2)

var _finger := -1
var _direction := Vector2.ZERO


## Returns true only for the contact this pad owns, including its release outside.
func handle_touch(event: InputEvent) -> bool:
	if not is_visible_in_tree():
		return false
	if event is InputEventScreenTouch:
		if event.pressed and _finger < 0 and get_global_rect().has_point(event.position):
			_finger = event.index
			_steer(event.position)
			return true
		if not event.pressed and event.index == _finger:
			reset()
			return true
	elif event is InputEventScreenDrag and event.index == _finger:
		_steer(event.position)
		return true
	return false


## Focus loss, menus and resizing must never leave the avatar walking unattended.
func reset() -> void:
	_finger = -1
	_direction = Vector2.ZERO
	direction_changed.emit(_direction)
	queue_redraw()


func _steer(at: Vector2) -> void:
	var local := get_global_transform_with_canvas().affine_inverse() * at
	var radius := minf(size.x, size.y) * 0.36
	var raw := ((local - size * 0.5) / maxf(radius, 1.0)).limit_length()
	_direction = Vector2.ZERO if raw.length() < 0.18 else raw
	direction_changed.emit(_direction)
	queue_redraw()


func _draw() -> void:
	var center := size * 0.5
	var radius := minf(size.x, size.y) * 0.42
	draw_circle(center, radius, Color(0.071, 0.082, 0.153, 0.94), true)
	draw_arc(center, radius, 0, TAU, 48, Color("7687ad"), 2.0, true)
	draw_arc(center, radius * 0.93, 0, TAU, 48, Color("374463"), 2.0, true)
	for direction: Vector2 in [Vector2.UP, Vector2.RIGHT, Vector2.DOWN, Vector2.LEFT]:
		var tip: Vector2 = center + direction * radius * 0.72
		var side: Vector2 = direction.orthogonal() * radius * 0.12
		draw_polyline(PackedVector2Array([
			tip - direction * radius * 0.14 + side, tip,
			tip - direction * radius * 0.14 - side,
		]), Color("dce5fc"), maxf(2.0, radius * 0.025), true)
	var thumb := center + _direction * radius * 0.43
	draw_circle(thumb, radius * 0.29, Color("3c667f"), true)
	draw_circle(thumb, radius * 0.24, Color("82f2df"), true)
