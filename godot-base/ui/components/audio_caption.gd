class_name AudioCaption
extends PanelContainer

@export_range(0.5, 5.0, 0.1) var hold_time := 1.4

@onready var _label: Label = %CaptionLabel

var _tween: Tween


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	hide()
	AudioManager.caption_requested.connect(present)
	Settings.changed.connect(_on_setting_changed)


func present(text: String) -> void:
	if not Settings.audio_captions_enabled() or text.is_empty():
		return
	if _tween and _tween.is_valid():
		_tween.kill()

	_label.text = text
	modulate.a = 1.0
	show()
	_tween = create_tween()
	_tween.tween_interval(hold_time)
	_tween.tween_property(self, "modulate:a", 0.0, 0.2)
	_tween.finished.connect(hide)


func clear() -> void:
	if _tween and _tween.is_valid():
		_tween.kill()
	_tween = null
	hide()
	modulate.a = 1.0


func caption_text() -> String:
	return _label.text


func _on_setting_changed(key: String, value: Variant) -> void:
	if key == Settings.AUDIO_CAPTIONS_KEY and not bool(value):
		clear()
