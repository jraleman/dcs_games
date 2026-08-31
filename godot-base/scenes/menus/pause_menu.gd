extends MenuScreen

## Pause overlay. Instantiate it into a CanvasLayer above the game; it pauses
## the tree on entry and unpauses on resume.
##
## It opens the settings screen as a nested overlay, so there is exactly one
## settings scene in the project.

@export_file("*.tscn") var settings_scene := "res://scenes/menus/settings_menu.tscn"
@export_file("*.tscn") var main_menu_scene := "res://scenes/menus/main_menu.tscn"

var _settings_overlay: MenuScreen


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	get_tree().paused = true
	super()


func _input(event: InputEvent) -> void:
	if event.is_action_pressed("pause"):
		get_viewport().set_input_as_handled()
		if is_instance_valid(_settings_overlay):
			_settings_overlay.go_back()
		else:
			resume()


## ui_cancel resumes instead of "going back" to anywhere.
func go_back() -> void:
	resume()


func resume() -> void:
	if is_instance_valid(_settings_overlay):
		return
	AudioManager.play_back()
	get_tree().paused = false
	closed.emit()
	queue_free()


func _on_resume_pressed() -> void:
	resume()


func _on_settings_pressed() -> void:
	var packed: PackedScene = load(settings_scene)
	if packed == null:
		return
	_settings_overlay = packed.instantiate()
	# The tree is paused while this overlay is up.
	_settings_overlay.process_mode = Node.PROCESS_MODE_ALWAYS
	_settings_overlay.z_index = z_index
	_settings_overlay.closed.connect(_on_settings_closed)
	get_parent().add_child(_settings_overlay)
	hide()


func _on_settings_closed() -> void:
	_settings_overlay = null
	show()
	_focus_first()


func _on_exit_to_main_menu_pressed() -> void:
	get_tree().paused = false
	Router.goto(main_menu_scene)
