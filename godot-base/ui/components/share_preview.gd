class_name ShareImagePreview
extends Control

## Modal preview for an image result returned by ShareManager.

signal closed

@onready var _panel: PanelContainer = %Panel
@onready var _preview: TextureRect = %Preview
@onready var _filename: Label = %Filename
@onready var _status: Label = %Status
@onready var _open_button: Button = %OpenOriginalButton
@onready var _close_button: Button = %CloseButton

var _texture: ImageTexture
var _global_path := ""
var _tween: Tween
var _closing := false


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	get_viewport().size_changed.connect(_refresh_layout)
	_refresh_layout()
	AudioManager.attach_ui_sounds(self)


func present(result: Dictionary) -> void:
	var png: PackedByteArray = result.get("png", PackedByteArray())
	_global_path = str(result.get("global_path", ""))
	_filename.text = _path_description(result)
	_status.text = ""

	var can_open := bool(result.get("can_open_original", false)) and not _global_path.is_empty()
	_open_button.visible = can_open

	if png.is_empty():
		_show_error("The generated image data is unavailable.")
	else:
		var image := Image.new()
		var load_error := image.load_png_from_buffer(png)
		if load_error != OK:
			_show_error("The generated image preview could not be loaded.")
			push_warning("Share preview PNG load failed with error %d." % load_error)
		else:
			_texture = ImageTexture.create_from_image(image)
			_preview.texture = _texture

	_animate_open.call_deferred()
	if _open_button.visible:
		_open_button.grab_focus.call_deferred()
	else:
		_close_button.grab_focus.call_deferred()


func dismiss() -> void:
	if _closing:
		return
	_closing = true
	if _tween and _tween.is_valid():
		_tween.kill()

	_tween = create_tween().set_parallel(true)
	_tween.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	_tween.tween_property(self, "modulate:a", 0.0, 0.18)
	if not Settings.reduced_motion_enabled():
		_tween.tween_property(_panel, "scale", Vector2.ONE * 0.96, 0.18)
	_tween.chain().tween_callback(_finish_close)


func _input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		AudioManager.play_back()
		dismiss()


func _refresh_layout() -> void:
	var viewport_size := get_viewport_rect().size
	var width_from_height := viewport_size.y * 0.52 / (630.0 / 1200.0) + 76.0
	var panel_width := clampf(
		minf(viewport_size.x * 0.74, width_from_height),
		700.0,
		1120.0
	)
	var preview_width := panel_width - 76.0
	_panel.custom_minimum_size.x = panel_width
	_preview.custom_minimum_size = Vector2(preview_width, preview_width * 630.0 / 1200.0)
	_panel.pivot_offset = _panel.size * 0.5


func _animate_open() -> void:
	_panel.pivot_offset = _panel.size * 0.5
	modulate = Color(1.0, 1.0, 1.0, 0.0)
	_panel.scale = (
		Vector2.ONE
		if Settings.reduced_motion_enabled()
		else Vector2.ONE * 0.9
	)
	_tween = create_tween().set_parallel(true)
	_tween.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_tween.tween_property(self, "modulate:a", 1.0, 0.18)
	if not Settings.reduced_motion_enabled():
		_tween.tween_property(_panel, "scale", Vector2.ONE, 0.28)


func _path_description(result: Dictionary) -> String:
	var filename := str(result.get("filename", result.get("path", "share-image.png")))
	if OS.has_feature("web"):
		return "Downloaded as %s" % filename
	return "Original file: %s" % str(result.get("global_path", filename))


func _show_error(message: String) -> void:
	_preview.texture = null
	_open_button.visible = false
	_status.text = message
	_status.add_theme_color_override("font_color", Color("ff5c6c"))


func _on_open_original_pressed() -> void:
	var error := ShareManager.open_original_image(_global_path)
	if error != OK:
		var message := "The original image could not be opened."
		_status.text = message
		_status.add_theme_color_override("font_color", Color("ff5c6c"))
		push_warning("%s Error %d." % [message, error])
		return
	_status.text = "Opened in your default image viewer."
	_status.add_theme_color_override("font_color", GameInfo.SKY)


func _on_close_pressed() -> void:
	dismiss()


func _finish_close() -> void:
	closed.emit()
	queue_free()
