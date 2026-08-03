extends Control

## Studio sting: the DeskCanSaw Games logo fades up, holds, fades out.
## Any input skips straight to the next scene.

@export var fade_time := 0.7
@export var hold_time := 1.6
@export_file("*.tscn") var next_scene := "res://scenes/boot/intro.tscn"

## Share of the shorter viewport axis kept as empty space around the logo.
@export_range(0.0, 0.4) var padding_ratio := 0.14

@onready var _frame: MarginContainer = %Frame
@onready var _logo: TextureRect = %Logo

var _tween: Tween
var _advanced := false


func _ready() -> void:
	get_viewport().size_changed.connect(_refresh_layout)
	_logo.resized.connect(_center_pivot)
	_refresh_layout()
	_center_pivot()

	_logo.modulate.a = 0.0
	_logo.scale = Vector2(0.94, 0.94)

	_tween = create_tween().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	_tween.tween_property(_logo, "modulate:a", 1.0, fade_time)
	_tween.parallel().tween_property(_logo, "scale", Vector2.ONE, fade_time + 0.8)
	_tween.tween_interval(hold_time)
	_tween.tween_property(_logo, "modulate:a", 0.0, fade_time)
	_tween.tween_callback(_advance)


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("skip") or event.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		_advance()


func _refresh_layout() -> void:
	# Pad relative to the shorter axis so the logo keeps the same presence
	# on a phone in portrait and on an ultrawide monitor.
	Responsive.apply_uniform_margins(_frame, get_viewport_rect().size, padding_ratio)


func _center_pivot() -> void:
	_logo.pivot_offset = _logo.size * 0.5


func _advance() -> void:
	if _advanced:
		return
	_advanced = true
	if _tween and _tween.is_running():
		_tween.kill()
	Router.goto(next_scene)
