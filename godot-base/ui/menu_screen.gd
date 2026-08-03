class_name MenuScreen
extends Control

## Base class for every full-screen menu.
##
## It gives subclasses four things for free:
##   * UI sounds and hover-follows-focus on all buttons,
##   * keyboard/gamepad focus on a sensible control when the screen opens,
##   * "back" on ui_cancel, working both as a standalone scene and as an
##     overlay (a pause menu instantiating the settings screen, say),
##   * margins that follow the viewport, plus an _on_layout_changed() hook
##     for per-screen portrait/landscape tweaks.

signal closed

## Control that receives focus when the screen opens.
@export var first_focus: Control
## Scene to return to with ui_cancel / the Back button when used standalone.
@export_file("*.tscn") var back_scene: String = ""
## MarginContainer wrapping the screen content; its margins follow the viewport.
@export var margins: MarginContainer

## Fractions of the viewport used for the outer margins, and their limits.
@export var margin_ratio := Vector2(0.07, 0.05)
@export var margin_min := Vector2(28, 20)
@export var margin_max := Vector2(240, 120)

var _closing := false


func _ready() -> void:
	get_viewport().size_changed.connect(refresh_layout)
	refresh_layout()
	# Focus first, then attach sounds, so opening a screen is silent.
	_focus_first.call_deferred()
	_attach_sounds.call_deferred()


func _attach_sounds() -> void:
	AudioManager.attach_ui_sounds(self)


func _focus_first() -> void:
	if first_focus and is_instance_valid(first_focus) and first_focus.is_visible_in_tree():
		first_focus.grab_focus()


# --- Layout -----------------------------------------------------------------

func viewport_size() -> Vector2:
	return get_viewport_rect().size


func is_portrait() -> bool:
	var size := viewport_size()
	return size.y > size.x


func refresh_layout() -> void:
	var size := viewport_size()
	Responsive.apply_margins(margins, size, margin_ratio, margin_min, margin_max)
	_on_layout_changed(size)


## Override to react to viewport changes (orientation, aspect ratio, size).
func _on_layout_changed(_size: Vector2) -> void:
	pass


# --- Navigation -------------------------------------------------------------

## True when this screen was instantiated on top of another scene rather than
## being the current scene itself.
func is_overlay() -> bool:
	return get_tree().current_scene != self


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		go_back()


func go_back() -> void:
	if _closing:
		return
	_closing = true
	AudioManager.play_back()
	if is_overlay():
		closed.emit()
		queue_free()
	elif not back_scene.is_empty():
		Router.goto(back_scene)
	else:
		_closing = false
