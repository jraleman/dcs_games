class_name TriangleTarget
extends Area2D

## Moving triangle target with a compact silhouette, readable active state,
## motion trail, and lightweight squash/pulse feedback.

signal activated(target: TriangleTarget)

const HIT_RADIUS := 78.0
const ACTIVE_TEXT_COLOR := Color("0b1117")
const INACTIVE_TEXT_COLOR := Color("f2f7f9")
const TRAIL_POINT_LIMIT := 14
const TRAIL_SAMPLE_INTERVAL := 0.035

@onready var _trail: Line2D = %Trail
@onready var _visual: Node2D = %Visual
@onready var _body: Node2D = %Body
@onready var _glow: Polygon2D = %Glow
@onready var _outline: Polygon2D = %Outline
@onready var _shape: Polygon2D = %Shape
@onready var _shine: Polygon2D = %Shine
@onready var _edge: Line2D = %Edge
@onready var _letter_label: Label = %Letter

var letter := ""
var player_index := -1
var highlighted := false
var velocity := Vector2.RIGHT
var move_speed := 320.0

var _enabled := true
var _activation_locked := false
var _inactive_color := Color("4a5a66")
var _highlight_color := Color("afddea")
var _display_color := Color("4a5a66")
var _visual_time := 0.0
var _phase := 0.0
var _feedback_scale := 1.0
var _bounce_amount := 0.0
var _shake_strength := 0.0
var _trail_sample_time := 0.0
var _last_trail_position := Vector2.ZERO
var _has_trail_point := false
var _feedback_tween: Tween


func _ready() -> void:
	_phase = randf() * TAU
	_visual_time = _phase
	_trail.clear_points()


func _process(delta: float) -> void:
	_visual_time += delta
	_bounce_amount = move_toward(_bounce_amount, 0.0, delta * 5.5)
	_shake_strength = move_toward(_shake_strength, 0.0, delta * 42.0)

	var target_color := _highlight_color if highlighted else _inactive_color
	if not _display_color.is_equal_approx(target_color):
		_display_color = _display_color.lerp(
			target_color,
			clampf(delta * 10.0, 0.0, 1.0)
		)
		if _display_color.is_equal_approx(target_color):
			_display_color = target_color
		_update_palette()

	var base_scale := 1.13 if highlighted else 0.88
	var pulse_speed := 6.2 if highlighted else 2.4
	var pulse_amount := 0.055 if highlighted else 0.018
	var pulse := 1.0 + sin(_visual_time * pulse_speed + _phase) * pulse_amount
	var scaled := base_scale * pulse * _feedback_scale
	_visual.scale = Vector2(
		scaled * (1.0 + _bounce_amount * 0.13),
		scaled * (1.0 - _bounce_amount * 0.1)
	)
	_visual.position.y = sin(_visual_time * 2.2 + _phase) * 2.5

	var lean := clampf(velocity.x / maxf(move_speed, 1.0), -1.0, 1.0) * 0.1
	lean += sin(_visual_time * 2.8 + _phase) * 0.025
	_body.rotation = lerp_angle(_body.rotation, lean, clampf(delta * 7.0, 0.0, 1.0))
	_body.position.x = sin(_visual_time * 48.0) * _shake_strength
	_body.position.y = cos(_visual_time * 39.0) * _shake_strength * 0.35

	var glow_pulse := 1.3 + sin(_visual_time * 5.4 + _phase) * (0.09 if highlighted else 0.025)
	_glow.scale = Vector2.ONE * glow_pulse
	_update_trail(delta)


func configure(
	display_letter: String,
	owner_index: int,
	inactive_color: Color,
	highlight_color: Color,
	speed: float
) -> void:
	player_index = owner_index
	_inactive_color = inactive_color
	_highlight_color = highlight_color
	_display_color = inactive_color
	move_speed = speed
	set_display_letter(display_letter)
	set_highlighted(false)
	_update_palette()


func set_display_letter(display_letter: String) -> void:
	letter = display_letter
	_letter_label.text = letter
	_letter_label.add_theme_font_size_override(
		"font_size",
		38 if letter.length() <= 2 else 25 if letter.length() <= 5 else 18
	)


func set_highlighted(value: bool) -> void:
	var became_highlighted := value and not highlighted
	highlighted = value
	_letter_label.add_theme_color_override(
		"font_color",
		ACTIVE_TEXT_COLOR if value else INACTIVE_TEXT_COLOR
	)
	z_index = 2 if value else 0

	if became_highlighted:
		_feedback_scale = 0.72
		_play_scale_tween(1.12, 0.16)


func move_and_bounce(delta: float, center_bounds: Rect2) -> void:
	position += velocity * move_speed * delta

	var minimum := center_bounds.position
	var maximum := center_bounds.position + center_bounds.size
	var bounced := false

	if position.x < minimum.x:
		position.x = minimum.x
		velocity.x = absf(velocity.x)
		bounced = true
	elif position.x > maximum.x:
		position.x = maximum.x
		velocity.x = -absf(velocity.x)
		bounced = true

	if position.y < minimum.y:
		position.y = minimum.y
		velocity.y = absf(velocity.y)
		bounced = true
	elif position.y > maximum.y:
		position.y = maximum.y
		velocity.y = -absf(velocity.y)
		bounced = true

	if bounced:
		_bounce_amount = 1.0


func play_spawn() -> void:
	_feedback_scale = 0.52
	_play_scale_tween(1.08, 0.18)


func play_wrong() -> void:
	_shake_strength = 11.0
	_feedback_scale = 0.86
	_play_scale_tween(1.0, 0.16)


func reset_trail() -> void:
	_trail.clear_points()
	_has_trail_point = false
	_trail_sample_time = 0.0


func set_target_enabled(value: bool) -> void:
	_enabled = value
	_activation_locked = false
	input_pickable = value
	modulate = Color.WHITE if value else Color(1.0, 1.0, 1.0, 0.38)
	if not value:
		reset_trail()


func _input_event(viewport: Viewport, event: InputEvent, _shape_idx: int) -> void:
	if not _enabled:
		return

	if event is InputEventMouseButton:
		var mouse_event := event as InputEventMouseButton
		if mouse_event.pressed and mouse_event.button_index == MOUSE_BUTTON_LEFT:
			_activate(viewport)
	elif event is InputEventScreenTouch:
		var touch_event := event as InputEventScreenTouch
		if touch_event.pressed:
			_activate(viewport)


func _activate(viewport: Viewport) -> void:
	if _activation_locked:
		return
	_activation_locked = true
	viewport.set_input_as_handled()
	_unlock_activation.call_deferred()
	activated.emit(self)


func _unlock_activation() -> void:
	_activation_locked = false


func _update_palette() -> void:
	_shape.color = _display_color
	_outline.color = _display_color.lightened(0.32)
	_glow.color = _with_alpha(_display_color, 0.3 if highlighted else 0.08)
	_shine.color = Color(1.0, 1.0, 1.0, 0.16 if highlighted else 0.07)
	_edge.default_color = Color(1.0, 1.0, 1.0, 0.72 if highlighted else 0.22)
	_edge.width = 3.5 if highlighted else 2.0
	_trail.default_color = _with_alpha(_display_color, 0.34 if highlighted else 0.1)
	_trail.width = 8.0 if highlighted else 4.0


func _update_trail(delta: float) -> void:
	if not _enabled:
		return

	_trail_sample_time += delta
	if _trail_sample_time < TRAIL_SAMPLE_INTERVAL:
		return
	_trail_sample_time = 0.0

	var sample_position := global_position
	if _has_trail_point and sample_position.distance_to(_last_trail_position) < 5.0:
		return

	_trail.add_point(sample_position)
	while _trail.get_point_count() > TRAIL_POINT_LIMIT:
		_trail.remove_point(0)
	_last_trail_position = sample_position
	_has_trail_point = true


func _play_scale_tween(peak: float, duration: float) -> void:
	if _feedback_tween and _feedback_tween.is_valid():
		_feedback_tween.kill()
	_feedback_tween = create_tween().set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_feedback_tween.tween_property(self, "_feedback_scale", peak, duration)
	_feedback_tween.tween_property(self, "_feedback_scale", 1.0, 0.1).set_trans(Tween.TRANS_SINE)


func _with_alpha(color: Color, alpha: float) -> Color:
	var result := color
	result.a = alpha
	return result
