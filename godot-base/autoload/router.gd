extends Node

## Scene changes with a fade, plus ownership of the always-on-top overlay
## layer (fade rectangle and FPS counter).
##
## Use `Router.goto("res://scenes/...")` instead of `change_scene_to_file()` so
## every transition looks the same and the tree is never swapped mid-fade.

signal scene_changed(path: String)
signal transition_finished(path: String)

const FADE_TIME := 0.3
const OVERLAY_LAYER := 128

var current_scene_path := ""

var _layer: CanvasLayer
var _fade: ColorRect
var _fps: Label
var _busy := false


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_apply_game_theme()
	_build_overlay()
	Settings.changed.connect(_on_setting_changed)
	_fps.visible = bool(Settings.get_value("ui/show_fps"))
	set_process(_fps.visible)

	var scene := get_tree().current_scene
	if scene:
		current_scene_path = scene.scene_file_path


## Dresses the whole tree in the current game's accent, once, at boot.
##
## A theme set on the root window is inherited by every Control under it, so
## this reaches screens the router never loaded — overlays, toasts, in-game
## HUDs — without any of them asking. A collection build gets the project theme
## back unchanged, so nothing moves unless a standalone build wants it to.
func _apply_game_theme() -> void:
	var base := ThemeDB.get_project_theme()
	if base == null:
		return
	get_tree().root.theme = GameCatalog.theme().restyle(base)


func _build_overlay() -> void:
	_layer = CanvasLayer.new()
	_layer.layer = OVERLAY_LAYER
	add_child(_layer)

	_fade = ColorRect.new()
	_fade.color = Color(0, 0, 0, 0)
	_fade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_fade.set_anchors_preset(Control.PRESET_FULL_RECT)
	_layer.add_child(_fade)

	_fps = Label.new()
	_fps.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	_fps.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	_fps.offset_left = -180.0
	_fps.offset_top = 12.0
	_fps.offset_right = -16.0
	_fps.offset_bottom = 52.0
	_fps.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_fps.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_fps.add_theme_font_size_override("font_size", 22)
	_fps.add_theme_color_override("font_color", GameCatalog.theme().accent)
	_fps.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.8))
	_fps.add_theme_constant_override("outline_size", 6)
	_fps.visible = false
	_layer.add_child(_fps)


func _process(_delta: float) -> void:
	_fps.text = "%d FPS" % Engine.get_frames_per_second()


func _input(_event: InputEvent) -> void:
	if _busy:
		get_viewport().set_input_as_handled()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("toggle_fullscreen"):
		Settings.toggle_fullscreen()
		get_viewport().set_input_as_handled()


## Fades out, swaps to [param path], then fades back in.
func goto(path: String, fade := true) -> void:
	if _busy or path.is_empty():
		return
	if not ResourceLoader.exists(path):
		push_error("Router.goto(): no scene at %s" % path)
		return

	_busy = true
	_fade.mouse_filter = Control.MOUSE_FILTER_STOP
	if fade:
		await _fade_to(1.0)

	# A paused tree would freeze the incoming scene as well.
	get_tree().paused = false
	var err := get_tree().change_scene_to_file(path)
	if err != OK:
		push_error("Router.goto(): could not load %s (error %d)" % [path, err])
	else:
		current_scene_path = path
		scene_changed.emit(path)

	# Give the new scene one frame to build before revealing it.
	await get_tree().process_frame
	if fade:
		await _fade_to(0.0)
	_busy = false
	_fade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	transition_finished.emit(current_scene_path)


func is_transitioning() -> bool:
	return _busy


## Starts the game [GameCatalog] currently has selected, stopping at whichever
## setup screen still has a question to ask: the mode picker while more than one
## seat arrangement is possible, then the instructions while the player still
## wants them, and otherwise the game itself.
##
## It lives here rather than on a menu because more than one screen starts a
## game — the main menu does it directly in a build with only one game to
## offer, and the game picker does it in every other build — and they must not
## drift into two different ideas of what "start" means. Both pass their own
## exported scene paths, so neither the router nor a game hardcodes the flow.
func start_selected_game(mode_scene: String, instructions_scene: String) -> void:
	if GameSession.multiplayer_offered():
		goto(mode_scene)
		return
	GameSession.configure_single_player()
	if bool(Settings.get_value("game/show_instructions", true)):
		goto(instructions_scene)
		return
	goto(GameCatalog.current_gameplay_scene_path())



func quit_game() -> void:
	if OS.has_feature("web"):
		return
	if _busy:
		return
	_busy = true
	_fade.mouse_filter = Control.MOUSE_FILTER_STOP
	await _fade_to(1.0)
	get_tree().paused = false
	get_tree().quit()


func _fade_to(alpha: float) -> void:
	var tween := create_tween()
	tween.tween_property(_fade, "color:a", alpha, FADE_TIME)
	await tween.finished


func _on_setting_changed(key: String, value: Variant) -> void:
	if key == "ui/show_fps":
		_fps.visible = bool(value)
		set_process(_fps.visible)
