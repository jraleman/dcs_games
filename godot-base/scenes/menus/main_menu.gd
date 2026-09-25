extends MenuScreen

## A quiet title screen with one way into play. Branding belongs to the catalog;
## the cartridge seats in shared, game-neutral hardware before the usual route.

@export_file("*.tscn") var game_select_scene := "res://scenes/menus/game_select.tscn"
@export_file("*.tscn") var play_scene := "res://scenes/menus/mode_select.tscn"
@export_file("*.tscn") var instructions_scene := "res://scenes/menus/instructions.tscn"
@export_file("*.tscn") var settings_scene := "res://scenes/menus/settings_menu.tscn"
@export_file("*.tscn") var store_scene := "res://scenes/menus/store.tscn"
@export_file("*.tscn") var gallery_scene := "res://scenes/menus/gallery.tscn"
@export_file("*.tscn") var saves_scene := "res://scenes/menus/saves.tscn"
@export_file("*.tscn") var credits_scene := "res://scenes/menus/credits.tscn"
@export var music: AudioStream

const ConsoleModel = preload("res://ui/components/cartridge_console.gd")
const LOGO_FACE_SPAN := 2.08
const INSERT_TIME := 0.58

@onready var _title: Label = %Title
@onready var _tagline: Label = %Tagline
@onready var _rule: ColorRect = %Rule
@onready var _header: VBoxContainer = %Header
@onready var _margins: MarginContainer = %Margins
@onready var _showcase_space: Control = %ShowcaseSpace
@onready var _spacer_top: Control = %SpacerTop
@onready var _menu_scroll: ScrollContainer = %MenuScroll
@onready var _button_row: HBoxContainer = %ButtonRow
@onready var _buttons: VBoxContainer = %Buttons
@onready var _play_button: Button = %PlayButton
@onready var _store_button: Button = %StoreButton
@onready var _gallery_button: Button = %GalleryButton
@onready var _saves_button: Button = %SavesButton
@onready var _quit_button: Button = %QuitButton
@onready var _footer_left: Label = %FooterLeft
@onready var _footer_right: Label = %FooterRight
@onready var _logo_showcase: SubViewportContainer = %LogoShowcase
@onready var _logo_viewport: SubViewport = %LogoViewport
@onready var _camera: Camera3D = %ShowcaseCamera
@onready var _console: ConsoleModel = %Console
@onready var _logo_rig: Node3D = %LogoRig
@onready var _logo_body: MeshInstance3D = %Body
@onready var _logo_face: Sprite3D = %Face
@onready var _key_light: DirectionalLight3D = %KeyLight
@onready var _fill_light: OmniLight3D = %FillLight
@onready var _focus_accent: ColorRect = %FocusAccent

var _menu_buttons: Array[Button] = []
var _navigation_styles: Dictionary[StringName, StyleBox] = {}
var _scaled_styles: Dictionary[StringName, StyleBox] = {}
var _logo_time := 0.0
var _logo_focus_bias := 0.0
var _logo_focus_target := 0.0
var _launching_game := false
var _launch_routed := false
var _launch_game_id := ""
var _launch_to_picker := false
var _reduced_motion := false
var _firm_menu_motion := false
var _logo_intro_tween: Tween
var _launch_tween: Tween


func _ready() -> void:
	_reduced_motion = Settings.reduced_motion_enabled()
	_firm_menu_motion = GameCatalog.theme().menu_motion == GameTheme.MenuMotion.FIRM
	Settings.changed.connect(_on_setting_changed)
	_title.text = GameCatalog.product_title()
	_tagline.text = GameCatalog.product_tagline()
	_title.tooltip_text = _tagline.text
	_title.accessibility_description = _tagline.text
	_footer_left.text = StudioInfo.copyright_line()
	_footer_right.text = "v%s" % StudioInfo.version()
	_refresh_play_button()
	_refresh_store_button()
	_refresh_gallery_button()
	_refresh_saves_button()
	AchievementManager.progression_changed.connect(_on_progression_changed)
	_quit_button.visible = not (OS.has_feature("web") or OS.has_feature("mobile"))
	if music:
		AudioManager.play_music(music)

	first_focus = _play_button
	margins = _margins
	for child in _buttons.get_children():
		var button := child as Button
		if button == null:
			continue
		var index := _menu_buttons.size()
		_menu_buttons.append(button)
		button.expand_icon = true
		button.focus_entered.connect(_on_button_focused.bind(button, index))
		button.focus_exited.connect(_on_button_focus_exited.bind(button))
		button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	_logo_showcase.resized.connect(_fit_showcase)
	_showcase_space.item_rect_changed.connect(_sync_showcase_layout.call_deferred)
	_menu_scroll.get_v_scroll_bar().value_changed.connect(
		func(_value: float) -> void: _sync_focus_accent.call_deferred()
	)
	_apply_theme()
	_logo_showcase.modulate.a = 0.0
	_logo_intro_tween = create_tween()
	_logo_intro_tween.tween_property(_logo_showcase, "modulate:a", 1.0, 0.45)
	set_process(not _reduced_motion)
	super()


func _process(delta: float) -> void:
	_logo_time += delta
	_logo_focus_bias = lerpf(_logo_focus_bias, _logo_focus_target, 1.0 - exp(-5.0 * delta))
	_console.idle_pose(_logo_time, _logo_focus_bias)


func _on_layout_changed(size: Vector2) -> void:
	var portrait := Responsive.is_portrait(size)
	var preference := float(Settings.get_value("ui/scale", 1.0))
	var unit := maxf(1.0, size.x * preference / maxf(get_window().size.x, 1.0) / 1.5)
	var usable := size.x - _margins.get_theme_constant("margin_left") \
		- _margins.get_theme_constant("margin_right")
	var column_width := minf(
		520.0 * unit, usable if portrait
		else size.x * 0.42 - _margins.get_theme_constant("margin_left")
	)
	var alignment := HORIZONTAL_ALIGNMENT_CENTER if portrait else HORIZONTAL_ALIGNMENT_LEFT
	_title.horizontal_alignment = alignment
	_header.custom_minimum_size.x = column_width
	_header.size_flags_horizontal = (
		Control.SIZE_SHRINK_CENTER if portrait else Control.SIZE_SHRINK_BEGIN
	)
	_header.add_theme_constant_override("separation", roundi(16.0 * unit))
	_title.add_theme_font_size_override("font_size", roundi((42.0 if portrait else 60.0) * unit))
	_rule.custom_minimum_size = Vector2(92.0 * unit, 3.0 * unit)
	_rule.size_flags_horizontal = (
		Control.SIZE_SHRINK_CENTER if portrait else Control.SIZE_SHRINK_BEGIN
	)
	_showcase_space.visible = portrait
	_showcase_space.custom_minimum_size.y = minf(size.y * 0.29, size.x * 0.72)
	_spacer_top.custom_minimum_size.y = (16.0 if portrait else 44.0) * unit
	_button_row.alignment = (
		BoxContainer.ALIGNMENT_CENTER if portrait else BoxContainer.ALIGNMENT_BEGIN
	)
	_menu_scroll.size_flags_horizontal = (
		Control.SIZE_SHRINK_CENTER if portrait else Control.SIZE_SHRINK_BEGIN
	)
	_menu_scroll.custom_minimum_size.x = column_width
	_buttons.custom_minimum_size.x = column_width
	_buttons.add_theme_constant_override("separation", roundi(12.0 * unit))
	_scale_navigation_styles(unit)
	for button in _menu_buttons:
		button.custom_minimum_size.y = 72.0 * unit
		button.add_theme_font_size_override("font_size", roundi(24.0 * unit))
		button.add_theme_constant_override("icon_max_width", roundi(18.0 * unit))
	for footer in [_footer_left, _footer_right]:
		footer.add_theme_font_size_override("font_size", roundi(16.0 * unit))
	_sync_showcase_layout.call_deferred()
	_sync_focus_accent.call_deferred()


func _scale_navigation_styles(unit: float) -> void:
	if _navigation_styles.is_empty():
		for state: StringName in [&"normal", &"hover", &"pressed", &"disabled", &"focus"]:
			_navigation_styles[state] = _play_button.get_theme_stylebox(state)
	for state: StringName in _navigation_styles:
		var original := _navigation_styles[state]
		var scaled := original.duplicate() as StyleBox
		for side in [SIDE_LEFT, SIDE_TOP, SIDE_RIGHT, SIDE_BOTTOM]:
			scaled.set_content_margin(side, original.get_content_margin(side) * unit)
		_scaled_styles[state] = scaled
		for button in _menu_buttons:
			button.add_theme_stylebox_override(state, scaled)
	for button in _menu_buttons:
		if button.has_focus():
			button.add_theme_stylebox_override("normal", _scaled_styles[&"hover"])


func _sync_showcase_layout() -> void:
	if is_portrait():
		var top := (_showcase_space.global_position.y - global_position.y) / size.y
		_set_logo_anchors(0.03, top, 0.97, top + _showcase_space.size.y / size.y)
	else:
		_set_logo_anchors(0.44, 0.055, 1.0, 0.96)
	_fit_showcase()


func _fit_showcase() -> void:
	_logo_showcase.pivot_offset = _logo_showcase.size * 0.5
	# Portrait uses an expanded logical canvas; don't render a desktop-sized
	# texture for a phone-sized illustration.
	_logo_showcase.stretch_shrink = maxi(
		1, floori(viewport_size().x / maxf(get_window().size.x, 1.0))
	)
	var aspect := _logo_showcase.size.x / maxf(_logo_showcase.size.y, 1.0)
	_camera.size = maxf(6.6, 8.3 / aspect)
	_camera.look_at(Vector3(0.1, 1.95, 0.35))
	_logo_viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS


func _set_logo_anchors(left: float, top: float, right: float, bottom: float) -> void:
	_logo_showcase.anchor_left = left
	_logo_showcase.anchor_top = top
	_logo_showcase.anchor_right = right
	_logo_showcase.anchor_bottom = bottom
	_logo_showcase.offset_left = 0
	_logo_showcase.offset_top = 0
	_logo_showcase.offset_right = 0
	_logo_showcase.offset_bottom = 0


func _on_button_focused(button: Button, index: int) -> void:
	button.add_theme_stylebox_override("normal", button.get_theme_stylebox("hover"))
	_logo_focus_target = deg_to_rad(
		lerpf(-1.0, 1.0, float(index) / maxi(_menu_buttons.size() - 1, 1))
		* (0.5 if _firm_menu_motion else 1.0)
	)
	_menu_scroll.ensure_control_visible(button)
	_sync_focus_accent.call_deferred()


func _on_button_focus_exited(button: Button) -> void:
	button.add_theme_stylebox_override("normal", _scaled_styles[&"normal"])
	_sync_focus_accent.call_deferred()


func _sync_focus_accent() -> void:
	_focus_accent.hide()
	if _launching_game:
		return
	for button in _menu_buttons:
		if not button.has_focus() or not button.is_visible_in_tree():
			continue
		if _focus_accent.get_parent() != button:
			_focus_accent.reparent(button, false)
		_focus_accent.set_anchors_and_offsets_preset(Control.PRESET_LEFT_WIDE)
		_focus_accent.offset_right = button.custom_minimum_size.y / 18.0
		_focus_accent.show()
		return


func _apply_theme() -> void:
	var presentation := GameCatalog.theme()
	var mesh := _logo_body.mesh.duplicate(true) as PrimitiveMesh
	if presentation.plaque_material != null:
		mesh.material = presentation.plaque_material.duplicate(true) as Material
	var material := mesh.material as StandardMaterial3D
	if material != null:
		material.albedo_color = presentation.plaque_color
	_logo_body.mesh = mesh
	var logo := presentation.logo_texture()
	if logo != null:
		_logo_face.texture = logo
	_logo_face.modulate = presentation.logo_color
	var longest := maxf(_logo_face.texture.get_width(), _logo_face.texture.get_height())
	_logo_face.pixel_size = LOGO_FACE_SPAN / maxf(longest, 1.0)
	_key_light.light_color = presentation.light
	_fill_light.light_color = presentation.accent
	_focus_accent.color = presentation.accent
	_console.configure(presentation)


func _on_setting_changed(key: String, value: Variant) -> void:
	if key != "accessibility/reduced_motion":
		return
	_reduced_motion = bool(value)
	set_process(not _reduced_motion and not _launching_game)
	if not _reduced_motion:
		return
	if _launching_game and not _launch_routed:
		# Killing a tween does not emit finished. Replace the pending route with
		# an opacity-only completion so a live accessibility change cannot trap Play.
		_play_reduced_launch()
	else:
		_console.park()


func _on_play_pressed() -> void:
	if _launching_game or _closing or Router.is_transitioning():
		return
	var games := GameCatalog.available()
	if games.is_empty():
		return
	_launch_to_picker = GameCatalog.offers_a_choice()
	_launch_game_id = games[0].id
	_launching_game = true
	_closing = true
	for button in _menu_buttons:
		button.disabled = true
	_focus_accent.hide()
	set_process(false)
	if _logo_intro_tween and _logo_intro_tween.is_valid():
		_logo_intro_tween.kill()
	_logo_showcase.modulate.a = 1.0
	if _reduced_motion:
		_play_reduced_launch()
		return
	_launch_tween = create_tween()
	_launch_tween.tween_property(_logo_rig, "rotation", Vector3.ZERO, 0.12)
	_launch_tween.tween_property(_console, "insertion", 1.0, INSERT_TIME) \
		.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN_OUT)
	_launch_tween.tween_interval(0.12)
	_launch_tween.tween_callback(_complete_launch)


func _play_reduced_launch() -> void:
	if _launch_tween and _launch_tween.is_valid():
		_launch_tween.kill()
	_launch_tween = create_tween()
	_launch_tween.tween_property(_logo_showcase, "modulate:a", 0.0, 0.16)
	_launch_tween.tween_callback(_complete_launch)


func _complete_launch() -> void:
	if _launch_routed:
		return
	_launch_routed = true
	if _launch_to_picker:
		Router.goto(game_select_scene)
	elif GameCatalog.select(_launch_game_id):
		Router.start_selected_game(play_scene, instructions_scene)
	else:
		push_error("MainMenu: the selected game is no longer available.")
		_launching_game = false
		_launch_routed = false
		_closing = false
		_console.insertion = 0.0
		_console.park()
		_logo_showcase.modulate.a = 1.0
		for button in _menu_buttons:
			button.disabled = false
		_refresh_play_button()
		set_process(not _reduced_motion)
		_focus_first()


func _leave_menu(path: String) -> void:
	if _closing or Router.is_transitioning():
		return
	_closing = true
	Router.goto(path)


func _on_settings_pressed() -> void:
	_leave_menu(settings_scene)


func _on_store_pressed() -> void:
	_leave_menu(store_scene)


func _on_gallery_pressed() -> void:
	_leave_menu(gallery_scene)


func _on_saves_pressed() -> void:
	_leave_menu(saves_scene)


func _on_credits_pressed() -> void:
	_leave_menu(credits_scene)


func _on_quit_pressed() -> void:
	if not _closing:
		_closing = true
		Router.quit_game()


func _refresh_play_button() -> void:
	var games := GameCatalog.available()
	_play_button.disabled = games.is_empty() or _launching_game
	if games.is_empty():
		_play_button.tooltip_text = "This build ships no games yet."
	elif GameCatalog.offers_a_choice():
		_play_button.tooltip_text = "Choose from %d games." % games.size()
	else:
		_play_button.tooltip_text = "Play %s." % games[0].title
	_play_button.accessibility_description = _play_button.tooltip_text


func _on_progression_changed(_key: String, _value: bool) -> void:
	if not _launching_game:
		_refresh_play_button()


func _refresh_store_button() -> void:
	_store_button.visible = (
		GameCatalog.is_single_game_build()
		and Store.has_store(GameCatalog.current_id())
	)
	if _store_button.visible:
		_store_button.tooltip_text = "Spend %s on cosmetics." % Store.currency_name(
			GameCatalog.current_id()
		).to_lower()
		_store_button.accessibility_description = _store_button.tooltip_text


func _refresh_gallery_button() -> void:
	var manifest := GameCatalog.get_manifest(GameCatalog.current_id())
	_gallery_button.visible = (
		GameCatalog.is_single_game_build() and manifest != null and manifest.has_gallery()
	)
	if _gallery_button.visible:
		_gallery_button.tooltip_text = "Explore %s models." % manifest.title
		_gallery_button.accessibility_description = _gallery_button.tooltip_text


## Unlike the store and the gallery, saves are managed per game on one screen,
## so a collection offers it too. [GameSaves] decides what is listed; with
## nothing saved and no backup to go back to there is nothing to manage.
func _refresh_saves_button() -> void:
	var games := GameSaves.managed_games()
	_saves_button.visible = not games.is_empty()
	if not _saves_button.visible:
		return
	if games.size() == 1:
		_saves_button.tooltip_text = (
			"Back up, restore or delete your %s progress." % games[0].title
		)
	else:
		_saves_button.tooltip_text = "Back up, restore or delete saved progress."
	_saves_button.accessibility_description = _saves_button.tooltip_text
