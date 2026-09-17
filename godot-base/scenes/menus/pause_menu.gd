extends MenuScreen

## Pause overlay. Instantiate it into a CanvasLayer above the game; it pauses
## the tree on entry and unpauses on resume.
##
## It opens the settings, store and gallery screens as nested overlays, so there
## is exactly one of each scene in the project.

@export_file("*.tscn") var settings_scene := "res://scenes/menus/settings_menu.tscn"
@export_file("*.tscn") var store_scene := "res://scenes/menus/store.tscn"
@export_file("*.tscn") var gallery_scene := "res://scenes/menus/gallery.tscn"
@export_file("*.tscn") var main_menu_scene := "res://scenes/menus/main_menu.tscn"

@onready var _store_button: Button = %StoreButton
@onready var _gallery_button: Button = %GalleryButton

var _settings_overlay: MenuScreen
var _store_overlay: MenuScreen
var _gallery_overlay: MenuScreen


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	get_tree().paused = true
	# The running game is the one with a store and a gallery worth opening, so a
	# game that sells or exhibits nothing simply has no entry here.
	_store_button.visible = Store.has_store(GameCatalog.current_id())
	var manifest := GameCatalog.get_manifest(GameCatalog.current_id())
	_gallery_button.visible = manifest != null and manifest.has_gallery()
	super()


func _input(event: InputEvent) -> void:
	if event.is_action_pressed("pause"):
		get_viewport().set_input_as_handled()
		var overlay := _active_overlay()
		if overlay != null:
			overlay.go_back()
		else:
			resume()


## ui_cancel resumes instead of "going back" to anywhere.
func go_back() -> void:
	resume()


func resume() -> void:
	if _active_overlay() != null:
		return
	AudioManager.play_back()
	get_tree().paused = false
	closed.emit()
	queue_free()


func _on_resume_pressed() -> void:
	resume()


## The nested screen currently covering the pause panel, if any.
func _active_overlay() -> MenuScreen:
	if is_instance_valid(_settings_overlay):
		return _settings_overlay
	if is_instance_valid(_store_overlay):
		return _store_overlay
	if is_instance_valid(_gallery_overlay):
		return _gallery_overlay
	return null


func _on_settings_pressed() -> void:
	_settings_overlay = _open_overlay(settings_scene)


func _on_store_pressed() -> void:
	_store_overlay = _open_overlay(store_scene)


func _on_gallery_pressed() -> void:
	_gallery_overlay = _open_overlay(gallery_scene)


## Every nested screen is configured the same way: it is told which game is
## running, because the pause overlay only exists during a round, and that game
## is the one whose controls, options, cosmetics and models are worth showing.
func _open_overlay(scene_path: String) -> MenuScreen:
	var packed: PackedScene = load(scene_path)
	if packed == null:
		return null
	var overlay := packed.instantiate() as MenuScreen
	if overlay == null:
		push_error("PauseMenu: %s is not a MenuScreen." % scene_path)
		return null
	overlay.set("game_context_id", GameCatalog.current_id())
	# The tree is paused while this overlay is up.
	overlay.process_mode = Node.PROCESS_MODE_ALWAYS
	overlay.z_index = z_index
	overlay.closed.connect(_on_overlay_closed)
	get_parent().add_child(overlay)
	hide()
	return overlay


func _on_overlay_closed() -> void:
	_settings_overlay = null
	_store_overlay = null
	_gallery_overlay = null
	show()
	_focus_first()


func _on_exit_to_main_menu_pressed() -> void:
	get_tree().paused = false
	Router.goto(main_menu_scene)
