extends Node2D

## Placeholder gameplay scene — delete the bouncing shape and build your game
## here. What is worth keeping is the wiring: a HUD layer, a pause overlay and
## bounds taken from the live viewport rather than hardcoded numbers.

@export_file("*.tscn") var pause_scene := "res://scenes/menus/pause_menu.tscn"
@export var speed := 320.0
@export var spin := 0.7

## Drop a gameplay track here to have it fade in when the scene starts.
@export var music: AudioStream

@onready var _shape: Polygon2D = %Shape
@onready var _hud: CanvasLayer = %HUD
@onready var _hint: Label = %Hint

var _velocity := Vector2(1.0, 0.62).normalized()
var _radius := 80.0
var _pause_menu: MenuScreen


func _ready() -> void:
	_shape.position = get_viewport_rect().size * 0.5
	_hint.text = (
		"Tap the pause button to pause"
		if DisplayServer.is_touchscreen_available()
		else "Esc or the Start button pauses"
	)
	if music:
		AudioManager.play_music(music)


func _process(delta: float) -> void:
	var bounds := get_viewport_rect().size
	_shape.position += _velocity * speed * delta
	_shape.rotation += spin * delta

	# Bounce off the viewport edges, whatever shape the window happens to be.
	if _shape.position.x < _radius:
		_shape.position.x = _radius
		_velocity.x = absf(_velocity.x)
	elif _shape.position.x > bounds.x - _radius:
		_shape.position.x = bounds.x - _radius
		_velocity.x = -absf(_velocity.x)

	if _shape.position.y < _radius:
		_shape.position.y = _radius
		_velocity.y = absf(_velocity.y)
	elif _shape.position.y > bounds.y - _radius:
		_shape.position.y = bounds.y - _radius
		_velocity.y = -absf(_velocity.y)


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("pause"):
		get_viewport().set_input_as_handled()
		open_pause_menu()


func open_pause_menu() -> void:
	if is_instance_valid(_pause_menu):
		return
	var packed: PackedScene = load(pause_scene)
	if packed == null:
		return
	_pause_menu = packed.instantiate()
	_pause_menu.closed.connect(_on_pause_closed)
	_hud.add_child(_pause_menu)


func _on_pause_closed() -> void:
	_pause_menu = null


func _on_pause_button_pressed() -> void:
	open_pause_menu()
