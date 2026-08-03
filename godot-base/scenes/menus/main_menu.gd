extends MenuScreen

## Title screen. Everything it displays comes from GameInfo, so renaming the
## game is a one-file change.

@export_file("*.tscn") var play_scene := "res://scenes/game/gameplay.tscn"
@export_file("*.tscn") var settings_scene := "res://scenes/menus/settings_menu.tscn"
@export_file("*.tscn") var credits_scene := "res://scenes/menus/credits.tscn"

## Drop a menu track here to have it fade in on this screen.
@export var music: AudioStream

## Below this viewport height the screen tightens up its spacing.
const COMPACT_HEIGHT := 720.0

@onready var _title: Label = %Title
@onready var _tagline: Label = %Tagline
@onready var _rule: ColorRect = %Rule
@onready var _header: VBoxContainer = %Header
@onready var _spacer_head: Control = %SpacerHead
@onready var _spacer_top: Control = %SpacerTop
@onready var _button_row: HBoxContainer = %ButtonRow
@onready var _buttons: VBoxContainer = %Buttons
@onready var _quit_button: Button = %QuitButton
@onready var _footer_left: Label = %FooterLeft
@onready var _footer_right: Label = %FooterRight


func _ready() -> void:
	_title.text = GameInfo.TITLE
	_tagline.text = GameInfo.TAGLINE
	_footer_left.text = "%s  ·  %s" % [GameInfo.STUDIO, GameInfo.copyright_line()]
	_footer_right.text = "v%s" % GameInfo.version()
	# Quitting is meaningless in a browser tab and unusual on mobile.
	_quit_button.visible = not (OS.has_feature("web") or OS.has_feature("mobile"))

	if music:
		AudioManager.play_music(music)

	super()


func _on_layout_changed(size: Vector2) -> void:
	var portrait := Responsive.is_portrait(size)
	var compact := size.y < COMPACT_HEIGHT

	# Centred stack in portrait, left-aligned poster layout in landscape.
	var alignment := HORIZONTAL_ALIGNMENT_CENTER if portrait else HORIZONTAL_ALIGNMENT_LEFT
	_title.horizontal_alignment = alignment
	_tagline.horizontal_alignment = alignment
	_rule.size_flags_horizontal = Control.SIZE_SHRINK_CENTER if portrait else Control.SIZE_SHRINK_BEGIN
	_button_row.alignment = BoxContainer.ALIGNMENT_CENTER if portrait else BoxContainer.ALIGNMENT_BEGIN

	# Landscape pins the title to the top; portrait floats the whole block
	# towards the middle so it doesn't strand the buttons in empty space.
	_spacer_head.size_flags_vertical = (
		Control.SIZE_EXPAND_FILL if portrait else Control.SIZE_SHRINK_BEGIN
	)
	_spacer_top.size_flags_stretch_ratio = 0.35 if portrait else 0.7

	_buttons.custom_minimum_size.x = (
		Responsive.content_width(size, 0.62, 420.0, 980.0)
		if portrait
		else Responsive.content_width(size, 0.32, 420.0, 620.0)
	)
	_buttons.add_theme_constant_override("separation", 8 if compact else 16)
	_header.add_theme_constant_override("separation", 10 if compact else 18)
	for button in _buttons.get_children():
		if button is Button:
			button.add_theme_font_size_override("font_size", 22 if compact else 28)

	_title.add_theme_font_size_override(
		"font_size", int(clampf(minf(size.x, size.y) * 0.08, 40.0, 112.0))
	)
	_tagline.add_theme_font_size_override("font_size", 24 if compact else 28)


func _on_play_pressed() -> void:
	Router.goto(play_scene)


func _on_settings_pressed() -> void:
	Router.goto(settings_scene)


func _on_credits_pressed() -> void:
	Router.goto(credits_scene)


func _on_quit_pressed() -> void:
	Router.quit_game()
