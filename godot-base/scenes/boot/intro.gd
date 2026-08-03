extends Control

## Placeholder intro: text cards fade in and out, then the main menu opens.
## Replace the cards (or the whole scene) with your own opening — the only
## contract is that it eventually calls Router.goto(next_scene).

@export var cards: Array[String] = []
@export var fade_in := 0.7
@export var hold := 2.2
@export var fade_out := 0.5
@export_file("*.tscn") var next_scene := "res://scenes/menus/main_menu.tscn"

## Drop an intro track here (or set it in the inspector) to play it over the
## cards; AudioManager fades it out again when the menu takes over.
@export var music: AudioStream

@onready var _frame: MarginContainer = %Frame
@onready var _card: Label = %Card
@onready var _hint: Label = %Hint
@onready var _progress: ColorRect = %ProgressFill

var _tween: Tween
var _hint_tween: Tween
var _progress_tween: Tween
var _finished := false


func _ready() -> void:
	if cards.is_empty():
		cards.assign(GameInfo.INTRO_CARDS)

	_hint.text = "Tap to skip" if DisplayServer.is_touchscreen_available() else "Press any key to skip"
	_card.modulate.a = 0.0
	_progress.anchor_right = 0.0

	if music:
		AudioManager.play_music(music)

	get_viewport().size_changed.connect(_refresh_layout)
	_card.resized.connect(_center_pivot)
	_refresh_layout()
	_center_pivot()

	_pulse_hint()
	_start_progress()
	_show_card(0)


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("skip") or event.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		_finish()


func _refresh_layout() -> void:
	var size := get_viewport_rect().size
	Responsive.apply_margins(_frame, size, Vector2(0.09, 0.07), Vector2(32, 24), Vector2(320, 140))
	# Keep the card readable rather than letting it run the full width of an
	# ultrawide screen.
	_card.add_theme_font_size_override("font_size", 44 if Responsive.is_portrait(size) else 52)


## The card is anchored to fill its area, so it is animated with scale around
## its centre — moving `position` would bake in offsets and break the anchors.
func _center_pivot() -> void:
	_card.pivot_offset = _card.size * 0.5


func _show_card(index: int) -> void:
	if index >= cards.size():
		_finish()
		return

	_card.text = cards[index]
	_card.scale = Vector2(0.97, 0.97)

	_tween = create_tween().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	_tween.tween_property(_card, "modulate:a", 1.0, fade_in)
	_tween.parallel().tween_property(_card, "scale", Vector2.ONE, fade_in + 0.5)
	_tween.tween_interval(hold)
	_tween.tween_property(_card, "modulate:a", 0.0, fade_out)
	_tween.tween_callback(_show_card.bind(index + 1))


func _start_progress() -> void:
	var total := cards.size() * (fade_in + hold + fade_out)
	_progress_tween = create_tween()
	_progress_tween.tween_property(_progress, "anchor_right", 1.0, total)


func _pulse_hint() -> void:
	_hint_tween = create_tween().set_loops()
	_hint_tween.tween_property(_hint, "modulate:a", 0.35, 1.1).set_trans(Tween.TRANS_SINE)
	_hint_tween.tween_property(_hint, "modulate:a", 1.0, 1.1).set_trans(Tween.TRANS_SINE)


func _on_skip_pressed() -> void:
	_finish()


func _finish() -> void:
	if _finished:
		return
	_finished = true
	for tween in [_tween, _hint_tween, _progress_tween]:
		if tween and tween.is_running():
			tween.kill()
	Router.goto(next_scene)
