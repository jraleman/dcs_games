extends Control

## Studio sting: the DeskCanSaw Games logo fades up, holds, fades out.
## Any input skips straight to the next scene.

@export var fade_time := 0.7
@export var hold_time := 1.6
## Where to go when the sting ends. A standalone build overrides this with its
## game's own opening through [method GameCatalog.intro_scene_path]; the
## placeholder intro is what a collection build sees.
@export_file("*.tscn") var next_scene := "res://scenes/boot/intro.tscn"

## Share of the shorter viewport axis kept as empty space around the logo.
@export_range(0.0, 0.4) var padding_ratio := 0.14

@onready var _frame: MarginContainer = %Frame
@onready var _logo: TextureRect = %Logo
@onready var _motion: SplashMotion = %Motion

var _tween: Tween
var _advanced := false
var _reduced_motion := false


func _ready() -> void:
	_reduced_motion = Settings.reduced_motion_enabled()
	get_viewport().size_changed.connect(_refresh_layout)
	_logo.resized.connect(_center_pivot)
	_refresh_layout()
	_center_pivot()

	AudioManager.play_splash()
	_motion.modulate.a = 0.0
	_logo.modulate.a = 0.0
	_logo.scale = Vector2.ONE if _reduced_motion else Vector2(0.84, 0.84)
	_logo.rotation = 0.0 if _reduced_motion else deg_to_rad(-4.0)

	_tween = create_tween().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	_tween.tween_property(_logo, "modulate:a", 1.0, fade_time)
	_tween.parallel().tween_property(_motion, "modulate:a", 1.0, fade_time + 0.15)
	if not _reduced_motion:
		_tween.parallel().tween_property(
			_logo,
			"scale",
			Vector2.ONE * 1.045,
			fade_time + 0.25
		)
		_tween.parallel().tween_property(_logo, "rotation", 0.0, fade_time + 0.2)
		_tween.tween_property(_logo, "scale", Vector2.ONE, 0.28).set_trans(
			Tween.TRANS_BACK
		).set_ease(Tween.EASE_OUT)
	_tween.tween_interval(hold_time)
	_tween.tween_property(_logo, "modulate:a", 0.0, fade_time)
	_tween.parallel().tween_property(_motion, "modulate:a", 0.0, fade_time)
	if not _reduced_motion:
		_tween.parallel().tween_property(
			_logo,
			"scale",
			Vector2.ONE * 1.035,
			fade_time
		)
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
	Router.goto(GameCatalog.intro_scene_path(next_scene))
