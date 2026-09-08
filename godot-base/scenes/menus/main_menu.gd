extends MenuScreen

## Title screen. Studio identity comes from StudioInfo and the game list comes
## from GameCatalog, so neither rebranding the project nor adding a game
## requires editing this screen.

@export_file("*.tscn") var game_select_scene := "res://scenes/menus/game_select.tscn"
@export_file("*.tscn") var play_scene := "res://scenes/menus/mode_select.tscn"
@export_file("*.tscn") var instructions_scene := "res://scenes/menus/instructions.tscn"
@export_file("*.tscn") var settings_scene := "res://scenes/menus/settings_menu.tscn"
@export_file("*.tscn") var credits_scene := "res://scenes/menus/credits.tscn"

## Drop a menu track here to have it fade in on this screen.
@export var music: AudioStream

## Below this viewport height the screen tightens up its spacing.
const COMPACT_HEIGHT := 720.0
const BUTTON_FOCUS_SCALE := Vector2(1.035, 1.035)
const BUTTON_PRESS_SCALE := Vector2(0.985, 0.985)

## How much of the plaque the logo spans on its longest side, in metres. Kept
## as a span rather than a pixel size so a logo of any resolution or aspect
## sits on the slab the same way.
const LOGO_FACE_SPAN := 3.04

@onready var _title: Label = %Title
@onready var _tagline: Label = %Tagline
@onready var _rule: ColorRect = %Rule
@onready var _header: VBoxContainer = %Header
@onready var _margins: MarginContainer = $Margins
@onready var _spacer_head: Control = %SpacerHead
@onready var _spacer_top: Control = %SpacerTop
@onready var _button_row: HBoxContainer = %ButtonRow
@onready var _buttons: VBoxContainer = %Buttons
@onready var _play_button: Button = %PlayButton
@onready var _quit_button: Button = %QuitButton
@onready var _footer_left: Label = %FooterLeft
@onready var _footer_right: Label = %FooterRight
@onready var _logo_showcase: SubViewportContainer = %LogoShowcase
@onready var _logo_rig: Node3D = %LogoRig
@onready var _logo_body: MeshInstance3D = %Body
@onready var _logo_face: Sprite3D = %Face
@onready var _key_light: DirectionalLight3D = %KeyLight
@onready var _fill_light: OmniLight3D = %FillLight
@onready var _focus_accent: ColorRect = %FocusAccent

var _menu_buttons: Array[Button] = []

var _focus_tween: Tween
var _focused_button_index := -1
var _logo_time := 0.0
var _logo_focus_bias := 0.0
var _logo_focus_target := 0.0
var _logo_kick := 0.0
var _logo_kick_velocity := 0.0
var _logo_scale_pulse := 0.0
var _launching_game := false
var _reduced_motion := false
var _firm_menu_motion := false
var _logo_intro_tween: Tween

func _ready() -> void:
	_reduced_motion = Settings.reduced_motion_enabled()
	_firm_menu_motion = GameCatalog.theme().menu_motion == GameTheme.MenuMotion.FIRM
	Settings.changed.connect(_on_setting_changed)
	_title.text = GameCatalog.product_title()
	_tagline.text = GameCatalog.product_tagline()
	_footer_left.text = "%s  ·  %s" % [StudioInfo.STUDIO, StudioInfo.copyright_line()]
	_footer_right.text = "v%s" % StudioInfo.version()
	_refresh_play_button()
	AchievementManager.progression_changed.connect(_on_progression_changed)
	# Quitting is meaningless in a browser tab and unusual on mobile.
	_quit_button.visible = not (OS.has_feature("web") or OS.has_feature("mobile"))

	if music:
		AudioManager.play_music(music)

	first_focus = _play_button
	margins = _margins
	_setup_button_motion()
	_apply_theme()
	_logo_showcase.resized.connect(_center_logo_pivot)
	_logo_showcase.modulate.a = 1.0 if _reduced_motion else 0.0
	_logo_showcase.scale = Vector2.ONE if _reduced_motion else Vector2(0.88, 0.88)
	_center_logo_pivot.call_deferred()
	if not _reduced_motion:
		_play_logo_intro.call_deferred()
	set_process(not _reduced_motion)

	super()


func _process(delta: float) -> void:
	_logo_time += delta

	_logo_kick_velocity += (-_logo_kick * 22.0 - _logo_kick_velocity * 7.0) * delta
	_logo_kick += _logo_kick_velocity * delta
	_logo_focus_bias = lerpf(
		_logo_focus_bias,
		_logo_focus_target,
		1.0 - exp(-5.0 * delta)
	)
	_logo_scale_pulse = lerpf(_logo_scale_pulse, 0.0, 1.0 - exp(-6.5 * delta))

	_logo_rig.rotation = Vector3(
		deg_to_rad(-4.0) + sin(_logo_time * 0.63) * deg_to_rad(3.5),
		sin(_logo_time * 0.52) * deg_to_rad(13.0) + _logo_focus_bias + _logo_kick,
		sin(_logo_time * 0.37) * deg_to_rad(1.8)
	)
	var breathing_scale := 1.0 + sin(_logo_time * 0.8) * 0.008 + _logo_scale_pulse
	_logo_rig.scale = Vector3.ONE * breathing_scale


func _on_layout_changed(size: Vector2) -> void:
	var portrait := Responsive.is_portrait(size)
	var compact := size.y < COMPACT_HEIGHT

	# Centred stack in portrait, left-aligned poster layout in landscape.
	var alignment := HORIZONTAL_ALIGNMENT_CENTER if portrait else HORIZONTAL_ALIGNMENT_LEFT
	_title.horizontal_alignment = alignment
	_tagline.horizontal_alignment = alignment
	_rule.size_flags_horizontal = Control.SIZE_SHRINK_CENTER if portrait else Control.SIZE_SHRINK_BEGIN
	_header.size_flags_horizontal = (
		Control.SIZE_SHRINK_CENTER if portrait else Control.SIZE_SHRINK_BEGIN
	)
	_header.custom_minimum_size.x = (
		Responsive.content_width(size, 0.84, 340.0, 860.0)
		if portrait
		else Responsive.content_width(size, 0.43, 420.0, 780.0)
	)
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

	if portrait:
		if compact:
			_set_logo_anchors(0.34, 0.015, 0.66, 0.19)
		else:
			_set_logo_anchors(0.30, 0.025, 0.70, 0.245)
	else:
		_set_logo_anchors(0.53, 0.08, 0.98, 0.92)

	_center_logo_pivot.call_deferred()
	_sync_focus_accent.call_deferred()


func _setup_button_motion() -> void:
	for child in _buttons.get_children():
		if child is not Button:
			continue
		var button := child as Button
		var index := _menu_buttons.size()
		_menu_buttons.append(button)
		button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		button.focus_entered.connect(_on_button_focused.bind(button, index))
		button.focus_exited.connect(_on_button_focus_exited.bind(button))
		button.button_down.connect(_on_button_down.bind(button))
		button.button_up.connect(_on_button_up.bind(button))
		button.resized.connect(_center_button_pivot.bind(button))
		_center_button_pivot(button)


func _on_button_focused(button: Button, index: int) -> void:
	_animate_button(
		button, _button_focus_scale(), _button_focus_tint(), 0.11 if _firm_menu_motion else 0.16
	)
	_move_focus_accent(button)
	if _reduced_motion:
		_focused_button_index = index
		return

	var direction := 1.0
	if _focused_button_index >= 0:
		direction = signf(float(index - _focused_button_index))
		if is_zero_approx(direction):
			direction = 1.0
	_logo_kick_velocity += direction * (0.22 if _firm_menu_motion else 1.35)
	_logo_scale_pulse = 0.006 if _firm_menu_motion else 0.045
	_focused_button_index = index

	var last_index := maxi(_menu_buttons.size() - 1, 1)
	var tilt := 1.0 if _firm_menu_motion else 3.0
	_logo_focus_target = deg_to_rad(lerpf(-tilt, tilt, float(index) / float(last_index)))


func _on_button_focus_exited(button: Button) -> void:
	_animate_button(button, Vector2.ONE, Color.WHITE, 0.2)


func _on_button_down(button: Button) -> void:
	_animate_button(
		button,
		Vector2(0.992, 0.992) if _firm_menu_motion else BUTTON_PRESS_SCALE,
		Color(0.92, 0.92, 0.92) if _firm_menu_motion else Color(0.9, 0.98, 1.0, 1.0),
		0.08
	)


func _on_button_up(button: Button) -> void:
	var target_scale := _button_focus_scale() if button.has_focus() else Vector2.ONE
	var target_tint := _button_focus_tint() if button.has_focus() else Color.WHITE
	_animate_button(button, target_scale, target_tint, 0.12)


func _button_focus_scale() -> Vector2:
	return Vector2.ONE if _firm_menu_motion else BUTTON_FOCUS_SCALE


func _button_focus_tint() -> Color:
	return Color.WHITE if _firm_menu_motion else Color(1.04, 1.08, 1.1, 1.0)


func _animate_button(
	button: Button,
	target_scale: Vector2,
	target_tint: Color,
	duration: float
) -> void:
	var previous: Tween
	if button.has_meta("motion_tween"):
		previous = button.get_meta("motion_tween") as Tween
	if previous and previous.is_valid():
		previous.kill()

	if _reduced_motion:
		button.scale = Vector2.ONE
		button.self_modulate = target_tint
		return

	var tween := button.create_tween().set_parallel(true)
	tween.set_trans(
		Tween.TRANS_CUBIC if _firm_menu_motion else Tween.TRANS_BACK
	).set_ease(Tween.EASE_OUT)
	tween.tween_property(button, "scale", target_scale, duration)
	tween.tween_property(button, "self_modulate", target_tint, duration)
	button.set_meta("motion_tween", tween)


func _move_focus_accent(button: Button) -> void:
	if _focus_tween and _focus_tween.is_valid():
		_focus_tween.kill()

	var target_size := Vector2(5.0, maxf(24.0, button.size.y * 0.58))
	var target_position := button.global_position + Vector2(
		-14.0,
		(button.size.y - target_size.y) * 0.5
	)
	if _focus_accent.modulate.a < 0.01:
		_focus_accent.global_position = target_position
		_focus_accent.size = target_size

	if _reduced_motion:
		_focus_accent.global_position = target_position
		_focus_accent.size = target_size
		_focus_accent.modulate.a = 1.0
		return

	_focus_tween = create_tween().set_parallel(true)
	_focus_tween.set_trans(Tween.TRANS_QUART).set_ease(Tween.EASE_OUT)
	var duration := 0.1 if _firm_menu_motion else 0.2
	_focus_tween.tween_property(_focus_accent, "global_position", target_position, duration)
	_focus_tween.tween_property(_focus_accent, "size", target_size, duration)
	_focus_tween.tween_property(_focus_accent, "modulate:a", 1.0, 0.12)


func _sync_focus_accent() -> void:
	for button in _menu_buttons:
		_center_button_pivot(button)
		if button.has_focus():
			_move_focus_accent(button)
			return


func _center_button_pivot(button: Button) -> void:
	button.pivot_offset = button.size * 0.5


func _center_logo_pivot() -> void:
	_logo_showcase.pivot_offset = _logo_showcase.size * 0.5


## Dresses the plaque, its lights and the focus bar in the current game's
## colours and optional material, without modifying the authored scene.
##
## The mesh is duplicated first: it is a sub-resource shared by every instance
## of this scene, and tinting it in place would outlive the screen.
func _apply_theme() -> void:
	var theme := GameCatalog.theme()

	var mesh := _logo_body.mesh
	if mesh != null:
		var tinted := mesh.duplicate(true) as PrimitiveMesh
		if theme.plaque_material != null:
			tinted.material = theme.plaque_material.duplicate(true) as Material
		var material := tinted.material as StandardMaterial3D
		if material != null:
			material.albedo_color = theme.plaque_color
		_logo_body.mesh = tinted

	var logo := theme.logo_texture()
	if logo != null:
		_logo_face.texture = logo
	_logo_face.modulate = theme.logo_color
	_fit_logo_to_plaque()

	_key_light.light_color = theme.light
	_fill_light.light_color = theme.accent
	_focus_accent.color = theme.accent


## Scales the logo so its longest side spans the plaque, whatever the texture's
## resolution and aspect happen to be.
func _fit_logo_to_plaque() -> void:
	var texture := _logo_face.texture
	if texture == null:
		return
	var longest := maxf(texture.get_width(), texture.get_height())
	if longest <= 0.0:
		return
	_logo_face.pixel_size = LOGO_FACE_SPAN / longest


func _set_logo_anchors(left: float, top: float, right: float, bottom: float) -> void:
	_logo_showcase.anchor_left = left
	_logo_showcase.anchor_top = top
	_logo_showcase.anchor_right = right
	_logo_showcase.anchor_bottom = bottom
	_logo_showcase.offset_left = 0.0
	_logo_showcase.offset_top = 0.0
	_logo_showcase.offset_right = 0.0
	_logo_showcase.offset_bottom = 0.0


func _play_logo_intro() -> void:
	if _reduced_motion:
		_logo_showcase.modulate.a = 1.0
		_logo_showcase.scale = Vector2.ONE
		return
	_logo_intro_tween = create_tween().set_parallel(true)
	_logo_intro_tween.set_trans(Tween.TRANS_QUART).set_ease(Tween.EASE_OUT)
	_logo_intro_tween.tween_property(_logo_showcase, "modulate:a", 1.0, 0.7).set_delay(0.08)
	_logo_intro_tween.tween_property(_logo_showcase, "scale", Vector2.ONE, 0.9).set_delay(0.04)


func _on_setting_changed(key: String, value: Variant) -> void:
	if key != "accessibility/reduced_motion":
		return
	_reduced_motion = bool(value)
	set_process(not _reduced_motion)
	if _reduced_motion:
		if _logo_intro_tween and _logo_intro_tween.is_valid():
			_logo_intro_tween.kill()
		_logo_showcase.modulate.a = 1.0
		_logo_showcase.scale = Vector2.ONE
		_logo_rig.rotation = Vector3(deg_to_rad(-4.0), 0.0, 0.0)
		_logo_rig.scale = Vector3.ONE
		_logo_kick = 0.0
		_logo_kick_velocity = 0.0
		_logo_scale_pulse = 0.0
	for button in _menu_buttons:
		_animate_button(
			button,
			_button_focus_scale() if button.has_focus() else Vector2.ONE,
			_button_focus_tint() if button.has_focus() else Color.WHITE,
			0.12
		)
	_sync_focus_accent()


## Play is the screen's only route into a game.
##
## With a choice to make it opens the picker, where every game is shown with a
## preview of how it plays. With one game available — a standalone build, or a
## collection whose other games are still locked — a picker would be a screen
## with a single card on it, so the game starts directly instead. Same reasoning
## as [method Router.start_selected_game] skipping mode select: do not ask a
## question that has only one answer.
func _on_play_pressed() -> void:
	if _launching_game:
		return
	var games := GameCatalog.available()
	if games.is_empty():
		return
	_launching_game = true
	for button in _menu_buttons:
		button.disabled = true

	if GameCatalog.offers_a_choice():
		Router.goto(game_select_scene)
		return
	GameCatalog.select(games[0].id)
	Router.start_selected_game(play_scene, instructions_scene)


func _on_settings_pressed() -> void:
	Router.goto(settings_scene)


func _on_credits_pressed() -> void:
	Router.goto(credits_scene)


func _on_quit_pressed() -> void:
	Router.quit_game()


## Play stays the screen's focus anchor even in the degenerate case of a build
## with no games at all, so it is disabled rather than hidden. The label stays
## "Play" either way — both routes end in a round — and the tooltip carries the
## difference, so the button never promises a picker a standalone build will not
## show, nor names a game a collection has not chosen yet.
func _refresh_play_button() -> void:
	var games := GameCatalog.available()
	_play_button.disabled = games.is_empty()
	if games.is_empty():
		_play_button.tooltip_text = "This build ships no games yet."
	elif GameCatalog.offers_a_choice():
		_play_button.tooltip_text = "Choose from %d games." % games.size()
	else:
		_play_button.tooltip_text = "Play %s." % games[0].title
	_play_button.accessibility_description = _play_button.tooltip_text


## Unlocking a game turns a direct launch into a choice, so the button's promise
## has to be rewritten without a scene reload.
func _on_progression_changed(_key: String, _value: bool) -> void:
	_refresh_play_button()
