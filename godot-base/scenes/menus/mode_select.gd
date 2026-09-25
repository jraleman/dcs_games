extends MenuScreen

## Pick a player count, then set up the round: any declared level, each seat
## and its character, solo choices and who plays Player 2.
## All game-specific wording comes from the active [GameManifest] and every
## accent from its [GameTheme], so this screen never names a game.

@export_file("*.tscn") var instructions_scene := "res://scenes/menus/instructions.tscn"

## Where Back returns to when the build stopped to ask which game to play. The
## scene's authored `back_scene` covers the other case, where the player came
## straight from the title screen because there was nothing to pick.
@export_file("*.tscn") var game_select_scene := "res://scenes/menus/game_select.tscn"

enum Step { PLAYER_COUNT, CONFIRM }

## Mode names an unlock rule may gate, matching
## [method GameUnlockRule.unlocked_modes].
const MODE_SINGLE_PLAYER := "Single Player"
const MODE_MULTIPLAYER := "Local Multiplayer"

## Portrait tints, matching the P1/P2 colours the gameplay HUD and the
## instructions screen already use, so a seat looks the same at every step.
const PLAYER_ONE_COLOR := Color("4da3ff")
const PLAYER_TWO_COLOR := Color("ff5c6c")
const Identity = preload("res://scripts/player_identity.gd")
const PLAYERS_ICON = preload("res://assets/images/icon_players.svg")
const SOLO_SETUP_BUTTON_MIN_WIDTH := 220.0
## Setup row heights at the desktop scale. A row that shows item art is taller,
## so a level thumbnail or a character badge stays legible.
const SETUP_ROW_HEIGHT := 76.0
const SETUP_ICON_ROW_HEIGHT := 96.0
## The smallest height any setup button may have, before scaling.
const TOUCH_HEIGHT := 66.0
## The armed Player 2 option carries a tick in its own words, not just a colour.
const ARMED_MARK := "✔  "
const HUMAN_OPPONENT_TEXT := "A Second Player"
const CPU_OPPONENT_TEXT := "The CPU"
## The Details toggle names what pressing it will do next.
const DETAILS_LABEL := "Details"
const LESS_LABEL := "Less"
## The stepper marks the current step by length as well as by colour.
const STEP_BAR_CURRENT := Vector2(56, 4)
const STEP_BAR_OTHER := Vector2(18, 4)
const STEP_BAR_IDLE := Color(1, 1, 1, 0.22)
const HEADER_RULE_SIZE := Vector2(76, 4)
## Portrait caps in physical pixels, so long labels still fit across a phone.
const COMPACT_BUTTON_FONT := 26.0
const COMPACT_TITLE_FONT := 34.0
const COMPACT_ROW_ART := 52.0
## Dropdown rows show item art no wider than this, before scaling.
const POPUP_ICON_WIDTH := 96.0
## The least room a dropdown leaves beside and between its rows, so art never
## touches its title or the next row's.
const POPUP_ITEM_GAP := Vector2(16, 10)
## The least and most of a portrait body the setup rows may take; the stage
## below them keeps the rest, so the pick is always on show.
const PORTRAIT_SETUP_SHARE := Vector2(0.5, 0.8)
const LABEL_STYLES: Array[StringName] = [&"normal"]
const PANEL_STYLES: Array[StringName] = [&"panel"]
const BUTTON_STYLES: Array[StringName] = [
	&"normal", &"hover", &"pressed", &"hover_pressed", &"focus", &"disabled",
]
const POPUP_CONSTANTS: Array[StringName] = [
	&"v_separation", &"h_separation", &"item_start_padding", &"item_end_padding",
]

@onready var _margins: MarginContainer = %Margins
@onready var _background: Control = $Background
@onready var _screen_title: Label = $Margins/Layout/Header/Title
@onready var _back_button: Button = $Margins/Layout/Header/BackButton
@onready var _details_button: Button = %DetailsButton
@onready var _stepper: HBoxContainer = $Margins/Layout/Stepper
@onready var _step_one_bar: ColorRect = %StepOneBar
@onready var _step_two_bar: ColorRect = %StepTwoBar
@onready var _header_rule: ColorRect = %HeaderRule
@onready var _mode_grid: GridContainer = %ModeGrid
@onready var _controller_grid: GridContainer = %ControllerGrid
@onready var _selection_step: Control = %SelectionStep
@onready var _confirm_step: Control = %ConfirmStep
@onready var _step_title: Label = %StepTitle
@onready var _selection_intro: Label = %Intro
@onready var _single_player_card: PanelContainer = (
	$Margins/Layout/Stage/SelectionStep/Layout/ModeGrid/SinglePlayer
)
@onready var _single_player_button: Button = %SinglePlayerButton
@onready var _single_player_title: Label = (
	$Margins/Layout/Stage/SelectionStep/Layout/ModeGrid/SinglePlayer/Content/Row/Text/Title
)
@onready var _single_player_description: Label = %SinglePlayerDescription
@onready var _single_player_controls: Label = %SinglePlayerControls
@onready var _single_player_roster: Label = %SinglePlayerRoster
@onready var _single_player_chip: Label = %SinglePlayerChip
@onready var _single_player_status: Label = %SinglePlayerStatus
@onready var _multiplayer_card: PanelContainer = %Multiplayer
@onready var _multiplayer_button: Button = %MultiplayerButton
@onready var _multiplayer_title: Label = (
	$Margins/Layout/Stage/SelectionStep/Layout/ModeGrid/Multiplayer/Content/Row/Text/Title
)
@onready var _multiplayer_description: Label = %MultiplayerDescription
@onready var _multiplayer_controls: Label = %MultiplayerControls
@onready var _multiplayer_roster: Label = %MultiplayerRoster
@onready var _multiplayer_chip: Label = %MultiplayerChip
@onready var _multiplayer_status: Label = %MultiplayerStatus
@onready var _selection_summary: Label = %SelectionSummary
@onready var _selection_hint: Label = %SelectionHint
@onready var _confirm_body: BoxContainer = %Body
@onready var _setup_panel: VBoxContainer = %Setup
@onready var _confirm_title: Label = %ConfirmTitle
@onready var _confirm_subtitle: Label = %ConfirmSubtitle
@onready var _confirm_description: Label = %ConfirmDescription
@onready var _setup_scroll: ScrollContainer = %SetupScroll
@onready var _setup_column: VBoxContainer = %SetupColumn
@onready var _solo_setup_choices_box: VBoxContainer = %SoloSetupChoices
@onready var _players_label: Label = %PlayersLabel
@onready var _player_one_control: VBoxContainer = %PlayerOneControl
@onready var _opponent_control: VBoxContainer = %OpponentControl
@onready var _player_one_control_keys: Label = %PlayerOneControlKeys
@onready var _player_one_role: Label = %PlayerOneRole
@onready var _player_one_control_description: Label = %PlayerOneControlDescription
@onready var _opponent_control_title: Label = %OpponentControlTitle
@onready var _opponent_avatar: PlayerAvatar = %OpponentAvatar
@onready var _player_one_avatar: PlayerAvatar = %PlayerOneAvatar
@onready var _opponent_role: Label = %OpponentRole
@onready var _opponent_control_keys: Label = %OpponentControlKeys
@onready var _opponent_control_description: Label = %OpponentControlDescription
@onready var _opponent_selector: VBoxContainer = %OpponentSelector
@onready var _opponent_options: BoxContainer = %OpponentOptions
@onready var _human_option_button: Button = %HumanOptionButton
@onready var _cpu_option_button: Button = %CpuOptionButton
@onready var _opponent_choice_hint: Label = %OpponentChoiceHint
@onready var _cpu_difficulty_panel: VBoxContainer = %CpuDifficultyPanel
@onready var _cpu_difficulty: OptionButton = %CpuDifficulty
@onready var _confirm_hint: Label = %ConfirmHint
@onready var _setup_stage: SetupStage = %SetupStage
@onready var _actions: HBoxContainer = %Actions
@onready var _confirm_button: Button = %ConfirmButton

var _step := Step.PLAYER_COUNT
var _pending_mode := GameSession.GameMode.SINGLE_PLAYER
## True once the player has actually picked a card, so step one can show which
## mode is armed instead of pretending the default was a decision.
var _mode_chosen := false
var _page_tween: Tween
var _single_player_available := true
var _multiplayer_available := true
## False when the player count is not a question this game can answer two ways,
## which turns the screen into the control confirmation on its own.
var _player_count_offered := true
var _reduced_motion := false
var _solo_setup_options: Array[Dictionary] = []
var _setup_readability_ready := false
var _pending_player_count := 2
var _player_count_choice: OptionButton
var _player_setup_cards: Array[Dictionary] = []
var _level_choice: OptionButton
## The seat whose character stands on the stage: the one last chosen or focused.
var _featured_seat := 0
## Authored sizes, recorded once, so every rescale starts from the design.
var _setup_metrics: Dictionary[Control, Dictionary] = {}
## The readability factor last applied; the stepper and column widths use it.
var _layout_scale := 1.0
var _readability_key := Vector3(-1.0, -1.0, -1.0)
var _scaled_textures: Dictionary[String, Texture2D] = {}
## The header buttons' words, kept while a narrow header shows only their icons.
var _details_label := DETAILS_LABEL
var _back_label := ""


func _ready() -> void:
	_reduced_motion = Settings.reduced_motion_enabled()
	_back_label = _back_button.text
	_back_button.accessibility_name = _back_label
	_pending_player_count = clampi(
		GameSession.multiplayer_player_count, 2, GameSession.maximum_local_players()
	)
	first_focus = _single_player_button
	margins = _margins
	if GameCatalog.offers_a_choice():
		back_scene = game_select_scene
	_select_default_opponent()
	_populate_cpu_difficulties()
	_cpu_difficulty.item_selected.connect(_on_cpu_difficulty_selected)
	_configure_solo_setup_choices()
	_configure_level_setup()
	_configure_player_setup()
	_configure_game_copy()
	_configure_platform_options()
	_update_control_copy()
	_update_stepper()
	_update_confirmation()
	_update_selection_state()
	GameSession.gamepad_availability_changed.connect(_on_gamepad_availability_changed)
	GameSession.controller_assignments_changed.connect(_on_controller_assignments_changed)
	Settings.changed.connect(_on_setting_changed)
	AchievementManager.unlocked.connect(_on_setup_unlocked)
	super()
	_apply_heading_face()
	_setup_readability_ready = true
	_setup_scroll.resized.connect(_keep_focus_visible, CONNECT_DEFERRED)
	_confirm_body.resized.connect(_share_portrait_body, CONNECT_DEFERRED)
	_setup_column.minimum_size_changed.connect(_share_portrait_body, CONNECT_DEFERRED)
	_setup_stage.visibility_changed.connect(_share_portrait_body, CONNECT_DEFERRED)
	_screen_title.get_parent().resized.connect(_fit_header, CONNECT_DEFERRED)
	_opponent_options.resized.connect(_fit_opponent_options, CONNECT_DEFERRED)
	get_viewport().gui_focus_changed.connect(_on_focus_changed)
	refresh_layout()


## Adding or removing the last pad rewrites every control line on the screen.
func _on_gamepad_availability_changed(_available: bool) -> void:
	_update_control_copy()
	_update_confirmation()


func _on_controller_assignments_changed() -> void:
	_update_control_copy()
	_update_confirmation()


func _on_setting_changed(key: String, _value: Variant) -> void:
	if _is_solo_setup_key(key):
		_refresh_solo_setup_choices()
		_single_player_description.text = _single_player_description_copy()
		_update_selection_state()
		_update_confirmation()
		return
	if not _uses_custom_keys():
		return
	for binding: Dictionary in Settings.control_bindings_for_game(GameCatalog.current_id()):
		if str(binding["key"]) == key:
			_update_confirmation()
			return


func _on_layout_changed(size: Vector2) -> void:
	var portrait := Responsive.is_portrait(size)
	_mode_grid.columns = (
		1
		if portrait or not (_single_player_available and _multiplayer_available)
		else 2
	)
	# Seats are rows, one under another, so a third seat never squeezes the rest.
	_controller_grid.columns = 1
	_apply_setup_readability(size)
	_layout_confirmation(size, portrait)
	_update_stepper()
	# Fonts may have just been rescaled, and the rows fit their words at that size.
	_fit_header.call_deferred()
	_fit_opponent_options.call_deferred()


## A narrow header keeps the game's name whole: Details and Back fold down to
## their icons, and keep their words as their accessible names. The fit is
## measured with the longer Details word, so toggling it never refolds the row.
func _fit_header() -> void:
	var header := _screen_title.get_parent() as BoxContainer
	_details_button.text = DETAILS_LABEL
	_back_button.text = _back_label
	var fits := true
	if header.size.x > 0.0:
		var title := (
			_screen_title.text.to_upper() if _screen_title.uppercase else _screen_title.text
		)
		var style := _screen_title.get_theme_stylebox(&"normal")
		fits = (
			_text_width(_screen_title, title)
			+ (style.get_minimum_size().x if style != null else 0.0)
			+ _details_button.get_combined_minimum_size().x
			+ _back_button.get_combined_minimum_size().x
			+ 2.0 * header.get_theme_constant(&"separation")
			<= header.size.x
		)
	_details_button.text = _details_label if fits else ""
	_back_button.text = _back_label if fits else ""


## Both Player 2 options share a row only while each reads in full with its
## tick, so arming one never reflows the pair; a phone stacks them instead.
func _fit_opponent_options() -> void:
	var width := _opponent_options.size.x
	if width <= 0.0:
		return
	var widest := 0.0
	for entry: Array in [
		[_human_option_button, HUMAN_OPPONENT_TEXT], [_cpu_option_button, CPU_OPPONENT_TEXT],
	]:
		var button := entry[0] as Button
		var armed := _text_width(button, ARMED_MARK + str(entry[1]))
		widest = maxf(widest, button.get_combined_minimum_size().x + armed)
	var separation := _opponent_options.get_theme_constant(&"separation")
	_opponent_options.vertical = widest * 2.0 + separation > width


## How wide [param text] sets in [param control]'s own font, at its current size.
func _text_width(control: Control, text: String) -> float:
	var font := control.get_theme_font(&"font")
	var font_size := control.get_theme_font_size(&"font_size")
	return font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1.0, font_size).x


## Landscape stands the setup column beside the stage; portrait stacks them so
## neither is squeezed into a sliver. Without a stage the column still keeps a
## readable measure instead of stretching across an ultrawide screen.
func _layout_confirmation(size: Vector2, portrait: bool) -> void:
	var usable := maxf(
		size.x
		- _margins.get_theme_constant("margin_left")
		- _margins.get_theme_constant("margin_right"),
		0.0
	)
	var factor := _layout_scale
	_confirm_body.vertical = portrait
	_setup_panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	if portrait:
		_setup_panel.custom_minimum_size.x = 0.0
		_setup_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	else:
		_setup_panel.custom_minimum_size.x = (
			minf(clampf(usable * 0.46, 620.0 * factor, 880.0 * factor), usable * 0.62)
			if _setup_stage.has_previews()
			else minf(clampf(usable * 0.62, 620.0 * factor, 1100.0 * factor), usable)
		)
		_setup_panel.size_flags_horizontal = Control.SIZE_FILL
		_setup_panel.size_flags_stretch_ratio = 1.0
		_setup_stage.size_flags_stretch_ratio = 1.0
	_share_portrait_body.call_deferred()
	_actions.alignment = (
		BoxContainer.ALIGNMENT_CENTER if portrait else BoxContainer.ALIGNMENT_END
	)
	_confirm_button.size_flags_horizontal = (
		Control.SIZE_EXPAND_FILL if portrait else Control.SIZE_FILL
	)
	# In a wide column each seat reads as one line: who plays, then their pick.
	var inline := not portrait and _pending_mode == GameSession.GameMode.MULTIPLAYER
	for card: Dictionary in _player_setup_cards:
		(card["line"] as BoxContainer).vertical = not inline
		var picker := card.get("picker") as Control
		if picker != null:
			picker.size_flags_stretch_ratio = 1.1


## Portrait gives the setup rows the height they need, up to most of the body,
## and the stage the rest: the rows are the task, the stage only shows the pick.
## Only stretch ratios change, so no size fed back into the layout can loop.
func _share_portrait_body() -> void:
	if not _confirm_body.vertical or not _setup_stage.visible:
		return
	var total := _confirm_body.size.y - _confirm_body.get_theme_constant(&"separation")
	if total <= 0.0:
		return
	var wanted := 0.0
	var shown := 0
	for child in _setup_panel.get_children():
		var control := child as Control
		if control == null or not control.visible:
			continue
		shown += 1
		wanted += (
			_setup_column.get_combined_minimum_size().y
			if control == _setup_scroll
			else control.get_combined_minimum_size().y
		)
	wanted += maxi(shown - 1, 0) * _setup_panel.get_theme_constant(&"separation")
	var setup := clampf(
		wanted, total * PORTRAIT_SETUP_SHARE.x, total * PORTRAIT_SETUP_SHARE.y
	)
	_setup_panel.size_flags_stretch_ratio = setup
	_setup_stage.size_flags_stretch_ratio = maxf(total - setup, 1.0)


## Scales the whole screen for the expanded portrait canvas and for large UI
## preferences, so phone targets keep their physical size and icons stay sharp.
func _apply_setup_readability(size: Vector2) -> void:
	if not _setup_readability_ready:
		return
	# The expanded portrait canvas must not turn setup buttons into tiny targets.
	var preference := float(Settings.get_value("ui/scale", 1.0))
	var factor := maxf(1.0, size.x * preference / maxf(get_window().size.x, 1.0) / 1.5)
	var pixel_scale := maxf(float(get_window().size.x) / size.x, 0.01)
	var compact := Responsive.is_portrait(size)
	if _setup_metrics.is_empty():
		_record_setup_metrics()
	var key := Vector3(factor, pixel_scale, 1.0 if compact else 0.0)
	if key.is_equal_approx(_readability_key):
		return
	_readability_key = key
	_layout_scale = factor
	for node: Variant in _setup_metrics.keys():
		if is_instance_valid(node):
			var control := node as Control
			_scale_control(control, _setup_metrics[control], factor, pixel_scale, compact)


## Remembers every size the scene and the setup builders authored. The
## background and a game's preview are left alone: each frames itself.
func _record_setup_metrics() -> void:
	var caption := _setup_stage.get_node_or_null("Caption")
	for node in find_children("*", "Control", true, false):
		var control := node as Control
		if control == _background or _background.is_ancestor_of(control):
			continue
		if _setup_stage.is_ancestor_of(control) and control != caption:
			continue
		var metrics := _control_metrics(control)
		if not metrics.is_empty():
			_setup_metrics[control] = metrics
		var label := control as Label
		if (
			label != null
			and label.autowrap_mode == TextServer.AUTOWRAP_OFF
			and label.text_overrun_behavior == TextServer.OVERRUN_NO_TRIMMING
			and (
				label.get_parent() is VBoxContainer
				or (label.size_flags_horizontal & Control.SIZE_EXPAND) != 0
			)
		):
			label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART


func _control_metrics(control: Control) -> Dictionary:
	var metrics := {}
	if control is Label or control is Button:
		metrics["font"] = control.get_theme_font_size(&"font_size")
	if control is Button or control.is_in_group(&"setup_scaled"):
		metrics["min"] = control.custom_minimum_size
	var constants := {}
	for constant: StringName in _scaled_constants(control):
		constants[constant] = control.get_theme_constant(constant)
	if not constants.is_empty():
		metrics["constants"] = constants
	# Only this screen's own roles are rescaled; plain types keep the theme's.
	if not String(control.theme_type_variation).is_empty():
		var styles := {}
		for style: StringName in _scaled_styles(control):
			var box := control.get_theme_stylebox(style)
			if box != null:
				styles[style] = [box, control.has_theme_stylebox_override(style)]
		if not styles.is_empty():
			metrics["styles"] = styles
	var texture_rect := control as TextureRect
	if texture_rect != null and texture_rect.texture != null:
		metrics["texture"] = texture_rect.texture
	var picker := control as OptionButton
	if picker != null:
		metrics["arrow"] = picker.get_theme_icon(&"arrow")
		var icons: Array[Texture2D] = []
		for index in picker.item_count:
			icons.append(picker.get_item_icon(index))
		metrics["item_icons"] = icons
		metrics["popup"] = _popup_metrics(picker.get_popup())
	elif control is Button and (control as Button).icon != null:
		metrics["icon"] = (control as Button).icon
	return metrics


func _scaled_constants(control: Control) -> Array[StringName]:
	if control is BoxContainer:
		return [&"separation"]
	if control is GridContainer or control is FlowContainer:
		return [&"h_separation", &"v_separation"]
	if control is MarginContainer and control != _margins:
		return [&"margin_left", &"margin_top", &"margin_right", &"margin_bottom"]
	if control is OptionButton:
		return [&"h_separation", &"icon_max_width", &"arrow_margin"]
	if control is Button:
		return [&"h_separation", &"icon_max_width"]
	return []


func _scaled_styles(control: Control) -> Array[StringName]:
	if control is Label:
		return LABEL_STYLES
	if control is PanelContainer:
		return PANEL_STYLES
	if control is Button:
		return BUTTON_STYLES
	return []


func _popup_metrics(popup: PopupMenu) -> Dictionary:
	var constants := {}
	for constant: StringName in POPUP_CONSTANTS:
		constants[constant] = popup.get_theme_constant(constant)
	var styles := {}
	for style: StringName in [&"panel", &"hover"]:
		var box := popup.get_theme_stylebox(style)
		if box != null:
			styles[style] = box
	return {"constants": constants, "styles": styles}


func _scale_control(
	control: Control, metrics: Dictionary, factor: float, pixel_scale: float, compact: bool
) -> void:
	var authored := is_equal_approx(factor, 1.0)
	if metrics.has("font"):
		var font_size := roundi(int(metrics["font"]) * factor)
		if compact and control is Button:
			font_size = mini(font_size, roundi(COMPACT_BUTTON_FONT / pixel_scale))
		elif compact and (control == _step_title or control == _confirm_title):
			font_size = mini(font_size, roundi(COMPACT_TITLE_FONT / pixel_scale))
		control.add_theme_font_size_override(&"font_size", font_size)
	if metrics.has("min"):
		var original: Vector2 = metrics["min"]
		control.custom_minimum_size = (
			Vector2(original.x, maxf(original.y, TOUCH_HEIGHT) * factor)
			if control is Button
			else original * factor
		)
	var constants: Dictionary = metrics.get("constants", {})
	for constant: StringName in constants:
		control.add_theme_constant_override(constant, roundi(int(constants[constant]) * factor))
	var styles: Dictionary = metrics.get("styles", {})
	for style: StringName in styles:
		var entry: Array = styles[style]
		if not authored:
			control.add_theme_stylebox_override(style, _scaled_style(entry[0], factor))
		elif entry[1]:
			control.add_theme_stylebox_override(style, entry[0])
		else:
			control.remove_theme_stylebox_override(style)
	if metrics.has("texture"):
		(control as TextureRect).texture = _scaled_texture(metrics["texture"], factor)
	if metrics.has("icon"):
		(control as Button).icon = _scaled_texture(metrics["icon"], factor)
	if control is OptionButton:
		_scale_picker(control as OptionButton, metrics, factor)
		if compact:
			_cap_picker_art(control as OptionButton, pixel_scale)


## On a phone a row's art gives way before its title does, in the row and in
## the list it opens alike.
func _cap_picker_art(picker: OptionButton, pixel_scale: float) -> void:
	var width := roundi(COMPACT_ROW_ART / pixel_scale)
	var row := picker.get_theme_constant(&"icon_max_width")
	if row <= 0 or row > width:
		picker.add_theme_constant_override(&"icon_max_width", width)
	var popup := picker.get_popup()
	if popup.get_theme_constant(&"icon_max_width") > width:
		popup.add_theme_constant_override(&"icon_max_width", width)


## An [OptionButton] draws its arrow at the texture's own size and its list in
## a separate popup, so both need scaling on top of the row itself.
func _scale_picker(picker: OptionButton, metrics: Dictionary, factor: float) -> void:
	var authored := is_equal_approx(factor, 1.0)
	var arrow := metrics.get("arrow") as Texture2D
	if arrow != null and authored:
		picker.remove_theme_icon_override(&"arrow")
	elif arrow != null:
		picker.add_theme_icon_override(&"arrow", _scaled_texture(arrow, factor))
	var icons: Array = metrics.get("item_icons", [])
	for index in mini(icons.size(), picker.item_count):
		var icon := icons[index] as Texture2D
		if icon != null:
			picker.set_item_icon(index, _scaled_texture(icon, factor))
	var popup := picker.get_popup()
	var popup_metrics: Dictionary = metrics.get("popup", {})
	# The list matches the row it opens from rather than the theme's smaller menus.
	popup.add_theme_font_size_override(&"font_size", roundi(int(metrics["font"]) * factor))
	var constants: Dictionary = popup_metrics.get("constants", {})
	for constant: StringName in constants:
		popup.add_theme_constant_override(constant, roundi(int(constants[constant]) * factor))
	popup.add_theme_constant_override(&"icon_max_width", roundi(POPUP_ICON_WIDTH * factor))
	var gaps := {&"h_separation": POPUP_ITEM_GAP.x, &"v_separation": POPUP_ITEM_GAP.y}
	for constant: StringName in gaps:
		var gap := maxf(float(constants.get(constant, 0)), float(gaps[constant]))
		popup.add_theme_constant_override(constant, roundi(gap * factor))
	var styles: Dictionary = popup_metrics.get("styles", {})
	for style: StringName in styles:
		if authored:
			popup.remove_theme_stylebox_override(style)
		else:
			popup.add_theme_stylebox_override(style, _scaled_style(styles[style], factor))


func _scaled_style(box: StyleBox, factor: float) -> StyleBox:
	var scaled := box.duplicate() as StyleBox
	for side: Side in [SIDE_LEFT, SIDE_TOP, SIDE_RIGHT, SIDE_BOTTOM]:
		var margin := box.get_content_margin(side)
		if margin >= 0.0:
			scaled.set_content_margin(side, margin * factor)
	var flat := scaled as StyleBoxFlat
	if flat == null:
		return scaled
	for side: Side in [SIDE_LEFT, SIDE_TOP, SIDE_RIGHT, SIDE_BOTTOM]:
		flat.set_border_width(side, roundi(flat.get_border_width(side) * factor))
		flat.set_expand_margin(side, flat.get_expand_margin(side) * factor)
	for corner: Corner in [
		CORNER_TOP_LEFT, CORNER_TOP_RIGHT, CORNER_BOTTOM_RIGHT, CORNER_BOTTOM_LEFT,
	]:
		flat.set_corner_radius(corner, roundi(flat.get_corner_radius(corner) * factor))
	flat.shadow_size = roundi(flat.shadow_size * factor)
	flat.shadow_offset *= factor
	return flat


## A [DPITexture] rasterizes at its own size times the canvas oversampling, so
## an icon drawn larger than authored needs a matching base scale to stay sharp.
## Bitmaps are returned as they are: they already carry their own pixels.
func _scaled_texture(texture: Texture2D, factor: float) -> Texture2D:
	var vector := texture as DPITexture
	if vector == null or is_equal_approx(factor, 1.0):
		return texture
	var key := "%d:%.3f" % [texture.get_instance_id(), factor]
	if not _scaled_textures.has(key):
		var scaled := vector.duplicate() as DPITexture
		scaled.base_scale = vector.base_scale * factor
		_scaled_textures[key] = scaled
	return _scaled_textures[key]


## Follows keyboard and controller focus through the setup column.
func _keep_focus_visible() -> void:
	var focused := get_viewport().gui_get_focus_owner()
	if focused == null or not _setup_column.is_ancestor_of(focused):
		return
	# Bring the row's heading along when both fit, so no row shows unlabelled.
	var section := focused.get_parent() as Control
	if section != null and section != _setup_column and section.size.y <= _setup_scroll.size.y:
		_setup_scroll.ensure_control_visible(section)
	_setup_scroll.ensure_control_visible(focused)


func _on_focus_changed(control: Control) -> void:
	if _setup_column.is_ancestor_of(control):
		_keep_focus_visible.call_deferred()


func _on_single_player_pressed() -> void:
	if not _single_player_available:
		return
	_pending_mode = GameSession.GameMode.SINGLE_PLAYER
	_mode_chosen = true
	_update_confirmation()
	_update_selection_state()
	_show_step(Step.CONFIRM)


func _on_multiplayer_pressed() -> void:
	if not _multiplayer_available:
		return
	_pending_mode = GameSession.GameMode.MULTIPLAYER
	_mode_chosen = true
	_select_default_opponent()
	_update_confirmation()
	_update_selection_state()
	_show_step(Step.CONFIRM)


## Direct movement keeps its two-human setup. Other styles offer a CPU only
## when the game declares one, defaulting to it so a lone player can start.
func _select_default_opponent() -> void:
	var cpu_default := _cpu_opponent_offered()
	_cpu_option_button.set_pressed_no_signal(cpu_default)
	_human_option_button.set_pressed_no_signal(not cpu_default)


func _cpu_opponent_offered() -> bool:
	return (
		_pending_player_count == 2
		and
		not _uses_direct_movement()
		and GameSession.multiplayer_offered()
		and GameSession.cpu_opponent_available()
	)


func _cpu_selected() -> bool:
	return _cpu_option_button.button_pressed and _cpu_opponent_offered()


func _on_opponent_option_pressed() -> void:
	if _pending_mode == GameSession.GameMode.MULTIPLAYER:
		_update_confirmation()
		_update_selection_state()


func _on_cpu_difficulty_selected(_index: int) -> void:
	if _pending_mode == GameSession.GameMode.MULTIPLAYER and _cpu_selected():
		_update_confirmation()
		_update_selection_state()


## Keeps step one honest about the current choice: which card is armed, who is
## on the roster, and what pressing Start would actually launch. Step two can
## be reached and left again, so the screen must never look neutral.
func _update_selection_state() -> void:
	var single_player := _pending_mode == GameSession.GameMode.SINGLE_PLAYER
	_single_player_status.visible = (
		_mode_chosen and single_player and _single_player_available
	)
	_multiplayer_status.visible = (
		_mode_chosen and not single_player and _multiplayer_available
	)
	if not _player_count_offered:
		first_focus = _preferred_confirm_focus()
	elif single_player and _single_player_available:
		first_focus = _single_player_button
	elif not single_player and _multiplayer_available:
		first_focus = _multiplayer_button

	_single_player_roster.text = _single_player_roster_copy()
	_multiplayer_roster.text = (
		"Player 2 is a human or the CPU"
		if _cpu_opponent_offered()
		else "Player 1 vs Player 2"
	)
	if _turn_based_setup() or _pending_player_count > 2:
		_multiplayer_roster.text = _local_roster()
	_describe_mode_cards()
	_selection_summary.visible = _mode_chosen
	if not _mode_chosen:
		return
	if not _pending_mode_is_available():
		_selection_summary.text = "This mode is not available yet."
		return
	_selection_summary.text = (
		_single_player_selection_summary()
		if single_player
		else "Selected: Multiplayer - Player 1 vs %s." % _player_two_long_name()
	)
	if not single_player and (_turn_based_setup() or _pending_player_count > 2):
		_selection_summary.text = "Selected: %s." % _local_roster()


## Details hides a card's longer notes, never its meaning: hover and assistive
## technology always get the whole story of what the card would launch.
func _describe_mode_cards() -> void:
	_describe_card(_single_player_button, [
		_single_player_description.text, _single_player_roster.text,
		_single_player_controls.text,
	])
	_describe_card(_multiplayer_button, [
		_multiplayer_description.text, _multiplayer_roster.text,
		_multiplayer_controls.text,
	])


func _describe_card(button: Button, parts: Array) -> void:
	var lines := PackedStringArray()
	var sentences := PackedStringArray()
	for part: Variant in parts:
		var text := str(part).strip_edges()
		if text.is_empty():
			continue
		lines.append(text)
		sentences.append(text if text.right(1) in [".", "!", "?"] else text + ".")
	button.tooltip_text = "\n".join(lines)
	button.accessibility_description = " ".join(sentences)


func _player_two_long_name() -> String:
	if _cpu_selected() and _uses_custom_keys():
		return "the CPU"
	return (
		"a %s CPU" % GameSession.cpu_difficulty_title(_selected_cpu_difficulty()).to_lower()
		if _cpu_selected()
		else "a second human player"
	)


func _on_previous_pressed() -> void:
	_show_step(Step.PLAYER_COUNT)


func _on_confirm_pressed() -> void:
	if not _pending_mode_is_available():
		push_warning("The selected game mode is not available.")
		return
	if not GameSession.level_options().is_empty() and GameSession.selected_level().is_empty():
		push_warning("Select an unlocked level before starting.")
		return
	if _pending_mode == GameSession.GameMode.SINGLE_PLAYER:
		GameSession.configure_single_player()
	else:
		var controller := (
			GameSession.PlayerTwoController.CPU
			if _cpu_selected()
			else GameSession.PlayerTwoController.HUMAN
		)
		GameSession.configure_multiplayer(
			controller, _selected_cpu_difficulty(), _pending_player_count
		)
	Router.goto(_next_scene())


func _update_confirmation() -> void:
	var single_player := _pending_mode == GameSession.GameMode.SINGLE_PLAYER
	var direct_movement := _uses_direct_movement()
	_update_control_copy()
	_solo_setup_choices_box.visible = single_player and not _solo_setup_options.is_empty()
	_opponent_control.visible = not single_player
	_opponent_selector.visible = not single_player and _cpu_opponent_offered()
	_cpu_option_button.disabled = not _cpu_opponent_offered()
	var cpu_selected := not single_player and _cpu_selected()
	_cpu_difficulty_panel.visible = cpu_selected and not _uses_custom_keys()
	# Both seats are named and labelled, so the roster never depends on colour.
	_player_one_role.text = "HUMAN"
	_player_one_avatar.configure(
		"P1", PLAYER_ONE_COLOR, "Player 1 portrait placeholder."
	)
	_opponent_avatar.configure(
		"CPU" if cpu_selected else "P2",
		PLAYER_TWO_COLOR,
		(
			"CPU opponent portrait placeholder."
			if cpu_selected
			else "Player 2 portrait placeholder."
		)
	)
	_opponent_role.text = "CPU" if cpu_selected else "HUMAN"
	# The role chip only answers a question when Player 2 could be either.
	_player_one_role.visible = not single_player and _cpu_opponent_offered()
	_opponent_role.visible = _player_one_role.visible
	_players_label.text = "Player" if single_player else "Players"

	if direct_movement:
		_update_direct_movement_confirmation(single_player)
	elif _uses_custom_keys():
		_update_custom_keys_confirmation(single_player)
	elif single_player:
		_confirm_title.text = "Ready for a solo run?"
		_confirm_description.text = (
			"Only Player 1 enters the arena. Follow the highlighted target and "
			+ "set a high score."
		)
		_confirm_hint.text = (
			"Player 1 uses %s or Controller 1 %s." % [
				Settings.control_summary(0),
				_target_pad_copy(),
			]
			if GameSession.gamepad_connected()
			else "Player 1 uses %s." % Settings.control_summary(0)
		)
		_confirm_button.text = "Start Single Player"
	else:
		var difficulty := _selected_cpu_difficulty()
		var profile := GameSession.cpu_profile(difficulty)
		var gamepad := GameSession.gamepad_connected()
		_confirm_title.text = (
			"Choose Player 2" if _cpu_opponent_offered() else "Two players, one screen"
		)
		_confirm_description.text = (
			(
				"Race the CPU by default, or switch to a human player using the keyboard"
				+ (" or a second controller." if gamepad else ".")
			)
			if _cpu_opponent_offered()
			else "Both players play together using their own bindings."
		)
		_opponent_control_title.text = (
			"CPU OPPONENT · %s" % GameSession.cpu_difficulty_title(difficulty).to_upper()
			if cpu_selected
			else "PLAYER 2"
		)
		var player_two_keys := "KEYS %s" % Settings.control_summary(1, " · ")
		if gamepad:
			player_two_keys += " · PAD 2 %s" % Settings.controller_target_summary(" · ")
		_opponent_control_keys.text = (
			"AUTO · %s" % GameSession.cpu_preset_title(difficulty).to_upper()
			if cpu_selected
			else player_two_keys
		)
		_opponent_control_description.text = (
			str(profile.get("description", "Player 2 plays automatically."))
			if cpu_selected
			else "Follow Player 2's highlighted target with the Player 2 bindings."
		)
		var human_hint := (
			"Player 2 uses %s or Controller 2 %s." % [
				Settings.control_summary(1),
				_target_pad_copy(),
			]
			if gamepad
			else "Player 2 uses %s." % Settings.control_summary(1)
		)
		_confirm_hint.text = (
			"%s CPU · %s" % [
				GameSession.cpu_difficulty_title(difficulty),
				GameSession.cpu_preset_title(difficulty),
			]
			if cpu_selected
			else human_hint
		)
		_confirm_button.text = "Start vs CPU" if cpu_selected else "Start Local Multiplayer"

	if single_player:
		_confirm_title.text = _solo_setup_text(_confirm_title.text)
		_confirm_description.text = _solo_setup_text(_confirm_description.text)
	elif not _uses_custom_keys() and (_turn_based_setup() or _pending_player_count > 2):
		_confirm_title.text = _game_text("versus_confirm_title", "%d players, one screen" % _pending_player_count)
		_confirm_description.text = _game_text("versus_confirm_description",
			"Take turns using the shared controls." if _turn_based_setup()
			else "Everyone plays with their own bindings.")
		_confirm_hint.text = _local_roster()
		_confirm_button.text = "Start Hot Seat" if _turn_based_setup() else "Start Local Multiplayer"
	if not direct_movement:
		_update_opponent_options()
	_refresh_level_setup()
	_refresh_player_setup()
	_update_details_visibility(_details_button.button_pressed)
	_on_layout_changed(viewport_size())


func _update_details_visibility(expanded: bool) -> void:
	_details_label = LESS_LABEL if expanded else DETAILS_LABEL
	_details_button.accessibility_name = _details_label
	_fit_header()
	_details_button.tooltip_text = (
		"Hide additional notes." if expanded else "Show game tips and setup notes."
	)
	_details_button.accessibility_description = _details_button.tooltip_text
	# A card's one-line description is its identity and always shows; Details
	# adds the roster, the controls and the longer setup notes.
	var details: Array[Control] = [
		_single_player_roster, _multiplayer_roster,
		_single_player_controls, _multiplayer_controls, _confirm_description,
		_player_one_control_description, _opponent_control_description,
		_opponent_choice_hint, _confirm_hint,
	]
	for card: Dictionary in _player_setup_cards.slice(2):
		details.append(card["description"] as Control)
	for detail: Control in details:
		detail.visible = expanded
	_selection_hint.visible = expanded or not (
		_single_player_available or _multiplayer_available
	)
	_describe_mode_cards()


func _update_custom_keys_confirmation(single_player: bool) -> void:
	var cpu := not single_player and _cpu_selected()
	_confirm_title.text = _game_text(
		"solo_confirm_title" if single_player or cpu else "versus_confirm_title",
		"Ready to play?" if single_player or cpu
		else "Two players, one screen" if _pending_player_count == 2
		else "%d players, one screen" % _pending_player_count
	)
	_confirm_description.text = _game_text(
		"solo_confirm_description" if single_player or cpu else "versus_confirm_description",
		"Use your action keys to play. Each player has their own bindings."
	)
	_confirm_hint.text = "Player 1: %s" % _custom_key_summary(0)
	if single_player:
		_confirm_button.text = "Start Single Player"
		return

	_opponent_control_title.text = "CPU OPPONENT" if cpu else "PLAYER 2"
	_opponent_control_keys.text = (
		"AUTOMATIC" if cpu else "KEYS %s" % _custom_key_summary(1)
	)
	_opponent_control_description.text = (
		_custom_cpu_description()
		if cpu
		else _game_text("player_two_control_description", "Use Player 2's action keys.")
	)
	_confirm_hint.text += (
		"  |  Player 2: automatic" if cpu else "  |  Player 2: %s" % _custom_key_summary(1)
	)
	_confirm_button.text = "Start vs CPU" if cpu else "Start Local Multiplayer"
	if not cpu and (_turn_based_setup() or _pending_player_count > 2):
		_confirm_hint.text = _local_roster()
		if _turn_based_setup():
			_confirm_hint.text += ". Shared keys: " + _custom_key_summary(0)
			_confirm_button.text = "Start Hot Seat"
		else:
			for player in _pending_player_count:
				_confirm_hint.text += "  |  P%d: %s" % [player + 1, _custom_key_summary(player)]


func _custom_cpu_description() -> String:
	return _game_text(
		"cpu_opponent_description",
		"Player 2 plays automatically using this game's CPU opponent."
	)


func _update_direct_movement_confirmation(single_player: bool) -> void:
	var manifest := GameCatalog.current()
	if single_player:
		_confirm_title.text = _game_text("solo_confirm_title", "Ready to play?")
		_confirm_description.text = _game_text(
			"solo_confirm_description",
			"Play a solo round and score as much as you can before time runs out."
		)
		_confirm_hint.text = (
			"Use the mouse, arrow keys or Controller 1 with %s."
			% Settings.controller_movement_scheme_label()
			if GameSession.gamepad_connected()
			else "Use the mouse or the arrow keys."
		)
		_confirm_button.text = "Start Solo %s" % manifest.title if manifest else "Start"
	else:
		_confirm_title.text = _game_text("versus_confirm_title", "Two players, one screen")
		_confirm_description.text = _game_text(
			"versus_confirm_description",
			"Share the screen. Player 1 uses the mouse and Player 2 uses the "
			+ "arrow keys by default."
		)
		_opponent_control_title.text = "PLAYER 2"
		_opponent_control_keys.text = (
			"ARROW KEYS · PAD 2 %s" % (
				Settings.controller_movement_scheme_label().to_upper()
			)
			if GameSession.gamepad_connected()
			else "ARROW KEYS"
		)
		_opponent_control_description.text = _game_text(
			"player_two_control_description",
			"These controls move Player 2 only."
		)
		_confirm_hint.text = (
			"P1: mouse or Pad 1   |   P2: arrows or Pad 2"
			if GameSession.gamepad_connected()
			else "P1: mouse   |   P2: arrow keys"
		)
		_confirm_button.text = (
			"Start Local %s" % manifest.title if manifest else "Start Local Multiplayer"
		)


## Screen copy for the active game, falling back to neutral framework wording.
func _game_text(key: String, fallback: String) -> String:
	var manifest := GameCatalog.current()
	return manifest.text(key, fallback) if manifest else fallback


func _populate_cpu_difficulties() -> void:
	_cpu_difficulty.clear()
	if _uses_custom_keys():
		return
	for difficulty: int in GameSession.CPU_DIFFICULTIES:
		_cpu_difficulty.add_item(GameSession.cpu_option_title(difficulty), difficulty)
	var selected_index := _cpu_difficulty.get_item_index(GameSession.cpu_difficulty)
	_cpu_difficulty.selected = selected_index if selected_index >= 0 else 0


func _configure_platform_options() -> void:
	# The platform flag and the offer are separate questions: the platform one
	# is what the "mobile" copy below is about, while the offer also honours a
	# manifest that declares the game single-player only.
	var platform_multiplayer_available := GameSession.multiplayer_available()
	_single_player_available = GameSession.single_player_offered()
	_multiplayer_available = GameSession.multiplayer_offered()

	# A gated game may have unlocked only some of its modes.
	var unlocked_modes := AchievementManager.game_unlocked_modes(
		GameCatalog.current_id()
	)
	var mode_gated := not unlocked_modes.is_empty()
	if mode_gated:
		_single_player_available = (
			_single_player_available
			and unlocked_modes.has(MODE_SINGLE_PLAYER)
		)
		_multiplayer_available = (
			_multiplayer_available
			and unlocked_modes.has(MODE_MULTIPLAYER)
		)

	_single_player_card.visible = _single_player_available
	_multiplayer_card.visible = _multiplayer_available
	_select_default_mode()
	_configure_player_count_step()

	if mode_gated:
		_update_gated_availability_copy(
			platform_multiplayer_available,
			unlocked_modes
		)
		return
	if platform_multiplayer_available:
		return
	_selection_intro.text = "Mobile play is available in single-player mode."
	if _uses_custom_keys():
		_selection_hint.text = "Use your action keys. Rebind them in Settings → Controls."
		return
	_selection_hint.text = (
		"Use touch, your remapped keys or a connected controller."
		if GameSession.gamepad_connected()
		else "Use touch or your remapped keys."
	)


## True when the selected game is steered directly rather than by target keys.
func _uses_direct_movement() -> bool:
	var manifest := GameCatalog.current()
	return (
		manifest != null
		and manifest.control_style == GameManifest.CONTROL_STYLE_DIRECT_MOVEMENT
	)


func _uses_custom_keys() -> bool:
	var manifest := GameCatalog.current()
	return (
		manifest != null
		and manifest.control_style == GameManifest.CONTROL_STYLE_CUSTOM_KEYS
	)


func _select_default_mode() -> void:
	if _single_player_available:
		_pending_mode = GameSession.GameMode.SINGLE_PLAYER
		first_focus = _single_player_button
	elif _multiplayer_available:
		_pending_mode = GameSession.GameMode.MULTIPLAYER
		first_focus = _multiplayer_button
	else:
		first_focus = _back_button


## Collapses the screen to its second step when the player count is not a real
## choice: a solo-only game, a game that always seats two, or a gated game with
## only one mode unlocked. A card that is the only card is not a decision, and
## leaving it on screen would cost the player a click to agree with themselves.
##
## The step is kept when *nothing* is available, so a fully locked game can
## still explain itself through the selection copy instead of showing a
## confirmation for a mode it will refuse to start.
func _configure_player_count_step() -> void:
	_player_count_offered = [_single_player_available, _multiplayer_available].count(true) != 1
	_stepper.visible = _player_count_offered
	if _player_count_offered:
		return
	_pending_mode = (
		GameSession.GameMode.SINGLE_PLAYER
		if _single_player_available
		else GameSession.GameMode.MULTIPLAYER
	)
	_mode_chosen = true
	_step = Step.CONFIRM
	_selection_step.hide()
	_confirm_step.show()
	first_focus = _preferred_confirm_focus()


func _update_gated_availability_copy(
	platform_multiplayer_available: bool,
	unlocked_modes: PackedStringArray
) -> void:
	var manifest := GameCatalog.current()
	if _single_player_available and _multiplayer_available:
		_selection_intro.text = manifest.text(
			"mode_select_intro", "Choose how you want to play."
		) if manifest else "Choose how you want to play."
		_selection_hint.text = manifest.text(
			"mode_select_hint", "You will confirm the player controls next."
		) if manifest else "You will confirm the player controls next."
	elif _single_player_available:
		_selection_intro.text = "Your unlocked single-player mode is ready."
		_selection_hint.text = "Select Single Player to continue."
	elif _multiplayer_available:
		_selection_intro.text = "Your unlocked local multiplayer mode is ready."
		_selection_hint.text = "Select Multiplayer to continue."
	elif (
		not platform_multiplayer_available
		and unlocked_modes.has(MODE_MULTIPLAYER)
	):
		_selection_intro.text = (
			"Your unlocked local multiplayer mode is unavailable on this device."
		)
		_selection_hint.text = "Return to the main menu to choose another game."
	else:
		_selection_intro.text = "No %s modes are available." % (
			manifest.title if manifest else "game"
		)
		_selection_hint.text = "Return to the main menu to choose another game."


func _configure_game_copy() -> void:
	var manifest := GameCatalog.current()
	if manifest == null:
		return
	_screen_title.text = manifest.title
	_step_title.text = manifest.text("mode_select_title", _step_title.text)
	_selection_intro.text = manifest.text("mode_select_intro", _selection_intro.text)
	if _uses_custom_keys():
		_single_player_description.text = "Play using Player 1's action keys."
		_multiplayer_description.text = (
			"Face the CPU or share this device using each player's action keys."
			if _cpu_opponent_offered()
			else "Share this device using each player's action keys."
		)
		_player_one_control_description.text = "Use Player 1's action keys."
		_selection_hint.text = "You will confirm each player's action keys next."
	elif not _uses_direct_movement() and not _cpu_opponent_offered():
		_multiplayer_description.text = "Share this device with Player 2."
	_selection_hint.text = manifest.text("mode_select_hint", _selection_hint.text)
	_single_player_description.text = _single_player_description_copy()
	_multiplayer_description.text = manifest.text(
		"multiplayer_description", _multiplayer_description.text
	)
	_player_one_control_description.text = manifest.text(
		"player_one_control_description", _player_one_control_description.text
	)
	# The chips say how many can play, so the cards never rely on icons alone.
	var most := GameSession.maximum_local_players()
	_single_player_chip.text = "1 PLAYER"
	_multiplayer_chip.text = "2 PLAYERS" if most <= 2 else "2–%d PLAYERS" % most


func _single_player_description_copy() -> String:
	return _solo_setup_text(
		_game_text("single_player_description", _single_player_description.text)
	)


func _update_control_copy() -> void:
	var gamepad := GameSession.gamepad_connected()
	if _uses_custom_keys():
		var custom_one_keys := _custom_key_summary(0, "  ")
		var custom_two_keys := _custom_key_summary(1, "  ")
		_single_player_controls.text = "PLAYER 1 · KEYS %s" % custom_one_keys
		_multiplayer_controls.text = "P1 · %s     P2 · %s" % [
			custom_one_keys, custom_two_keys,
		]
		if _turn_based_setup():
			_multiplayer_controls.text = "TAKE TURNS · SHARED KEYS %s" % custom_one_keys
		_player_one_control_keys.text = "KEYS %s" % _custom_key_summary(0)
		return
	if _uses_direct_movement():
		var movement_copy := Settings.controller_movement_scheme_label().to_upper()
		# Truthful after a rebind: the game's own movement keys when it has
		# them, and the shipped wording while they are untouched.
		var keys_copy := Settings.movement_summary_for_game(
			GameCatalog.current_id(), " ", "ARROW KEYS"
		).to_upper()
		_single_player_controls.text = (
			"MOUSE · %s · PAD 1 %s" % [keys_copy, movement_copy]
			if gamepad
			else "MOUSE · %s" % keys_copy
		)
		_multiplayer_controls.text = (
			"P1 · MOUSE / PAD 1     P2 · %s / PAD 2" % keys_copy
			if gamepad
			else "P1 · MOUSE     P2 · %s" % keys_copy
		)
		var multiplayer := _pending_mode == GameSession.GameMode.MULTIPLAYER
		if gamepad:
			_player_one_control_keys.text = (
				"MOUSE · PAD 1 %s" % movement_copy
				if multiplayer
				else "MOUSE · %s · PAD 1 %s" % [keys_copy, movement_copy]
			)
		else:
			_player_one_control_keys.text = (
				"MOUSE" if multiplayer else "MOUSE · %s" % keys_copy
			)
		return

	var player_one_keys := Settings.control_summary(0, "  ")
	var player_two_keys := Settings.control_summary(1, "  ")
	var mapped_buttons := Settings.controller_target_summary(" ")
	var pad_copy := (
		"ANY %s" % mapped_buttons
		if Settings.one_button_targets_enabled()
		else mapped_buttons
	)
	_single_player_controls.text = (
		"PLAYER 1 · KEYS %s · PAD %s" % [player_one_keys, pad_copy]
		if gamepad
		else "PLAYER 1 · KEYS %s" % player_one_keys
	)
	_multiplayer_controls.text = (
		"P1 · %s / PAD 1     P2 · %s / PAD 2" % [player_one_keys, player_two_keys]
		if gamepad
		else "P1 · %s     P2 · %s" % [player_one_keys, player_two_keys]
	)
	_player_one_control_keys.text = (
		"KEYS %s · PAD 1 %s" % [Settings.control_summary(0, " · "), pad_copy]
		if gamepad
		else "KEYS %s" % Settings.control_summary(0, " · ")
	)


## Includes shared bindings on both cards, without assuming an InputMap action
## or a movement flag: custom games can declare any kind of keyboard action.
func _custom_key_summary(player_index: int, separator := " · ") -> String:
	if _turn_based_setup():
		player_index = 0
	var labels := PackedStringArray()
	for binding: Dictionary in Settings.control_bindings_for_game(GameCatalog.current_id()):
		var player := int(binding.get("player", -1))
		if player >= 0 and player != player_index:
			continue
		labels.append(Settings.binding_key_label(str(binding["key"])))
	return separator.join(labels) if not labels.is_empty() else "No action keys declared"


func _turn_based_setup() -> bool:
	var game := GameCatalog.current()
	return game != null and game.local_multiplayer_turns


func _local_roster() -> String:
	var names := PackedStringArray()
	for player in _pending_player_count:
		names.append(Identity.tag(player))
	return (" -> " if _turn_based_setup() else " vs ").join(names)


func _configure_level_setup() -> void:
	var options := GameSession.level_options()
	if options.is_empty():
		return
	var layout := VBoxContainer.new()
	layout.name = "LevelSetup"
	layout.add_theme_constant_override("separation", 10)
	layout.add_child(_setup_section_label(_game_text("level_label", "Level")))
	_level_choice = _setup_picker("LevelChoice", options)
	layout.add_child(_level_choice)
	# The level frames every other choice, so it heads the column.
	_setup_column.add_child(layout)
	_setup_column.move_child(layout, 0)
	_level_choice.item_selected.connect(_on_level_selected)


func _on_level_selected(index: int) -> void:
	GameSession.set_level(str(GameSession.level_options()[index]["id"]))
	_refresh_level_setup()


func _refresh_level_setup() -> void:
	if _level_choice == null:
		return
	var selected := GameSession.selected_level()
	_refresh_setup_picker(_level_choice, GameSession.level_options(), selected)
	var description := str(selected.get("description", "No unlocked levels."))
	_confirm_subtitle.text = description
	_confirm_subtitle.visible = not description.is_empty()
	_level_choice.tooltip_text = description
	_level_choice.accessibility_description = "%s: %s. %s" % [
		_game_text("level_label", "Level"), str(selected.get("title", "")), description,
	]


## The small spaced caption that heads each group of setup rows.
func _setup_section_label(text: String) -> Label:
	var label := Label.new()
	label.theme_type_variation = &"SetupSectionLabel"
	label.uppercase = true
	label.text = text
	return label


## A full-width row that opens a list, dressed like the scene's own rows. Any
## option that declares art shows it beside its title, and the row grows to fit.
func _setup_picker(picker_name: String, options: Array[Dictionary]) -> OptionButton:
	var picker := OptionButton.new()
	picker.name = picker_name
	picker.theme_type_variation = &"SetupRow"
	picker.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	picker.fit_to_longest_item = false
	picker.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	var iconic := false
	for index in options.size():
		var icon := _option_icon(options[index])
		if icon != null:
			picker.add_icon_item(icon, str(options[index]["title"]), index)
			iconic = true
		else:
			picker.add_item(str(options[index]["title"]), index)
	picker.expand_icon = iconic
	picker.custom_minimum_size.y = SETUP_ICON_ROW_HEIGHT if iconic else SETUP_ROW_HEIGHT
	return picker


## Option art is optional manifest data: a wrong path warns and leaves a text
## row rather than taking the setup screen down with it.
func _option_icon(option: Dictionary) -> Texture2D:
	var path := str(option.get("icon", ""))
	if path.is_empty():
		return null
	if not ResourceLoader.exists(path):
		push_warning("ModeSelect: setup option icon not found: " + path)
		return null
	return load(path) as Texture2D


func _on_setup_unlocked(_id: String, _achievement: Dictionary) -> void:
	_refresh_level_setup()
	_refresh_player_setup()


func _refresh_setup_picker(
	picker: OptionButton, options: Array[Dictionary], selection: Dictionary
) -> void:
	picker.select(-1)
	for index in options.size():
		var option := options[index]
		var locked := not GameSession.setup_option_is_unlocked(option)
		picker.set_item_text(index, str(option["title"]) + (" (Locked)" if locked else ""))
		picker.set_item_disabled(index, locked)
		picker.get_popup().set_item_tooltip(index, GameSession.setup_option_requirement(option)
			if locked else str(option.get("description", "")))
		if str(option["id"]) == str(selection.get("id", "")) and not locked:
			picker.select(index)


func _configure_player_setup() -> void:
	_player_setup_cards = [
		_seat_card(_player_one_control, _player_one_control_description),
		_seat_card(_opponent_control, _opponent_control_description),
	]
	_player_count_choice = OptionButton.new()
	_player_count_choice.name = "PlayerCountChoice"
	_player_count_choice.theme_type_variation = &"SetupRow"
	_player_count_choice.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_player_count_choice.fit_to_longest_item = false
	_player_count_choice.expand_icon = true
	_player_count_choice.custom_minimum_size.y = SETUP_ROW_HEIGHT
	for count in range(2, GameSession.maximum_local_players() + 1):
		_player_count_choice.add_icon_item(PLAYERS_ICON, "%d players" % count, count)
	_player_count_choice.select(_player_count_choice.get_item_index(_pending_player_count))
	_player_count_choice.accessibility_description = "Number of local players"
	_setup_column.add_child(_player_count_choice)
	_setup_column.move_child(_player_count_choice, _controller_grid.get_index())
	_player_count_choice.item_selected.connect(_on_player_count_selected)
	for player in range(2, GameSession.maximum_local_players()):
		_player_setup_cards.append(_build_extra_seat(player))
	var options := GameSession.character_options()
	if options.is_empty():
		return
	var game := GameCatalog.current()
	var character_label := _game_text("character_label", "Character")
	for player in _player_setup_cards.size():
		var card := _player_setup_cards[player]
		var line := card["line"] as BoxContainer
		var caption := _setup_section_label(character_label)
		caption.name = "CharacterLabel"
		line.add_child(caption)
		card["character_label"] = caption
		var picker := _setup_picker("Player%dCharacter" % (player + 1), options)
		line.add_child(picker)
		picker.item_selected.connect(_on_character_selected.bind(player))
		picker.focus_entered.connect(_feature_seat.bind(player))
		card["picker"] = picker
		if not game.character_preview_scene_path.is_empty():
			var packed := load(game.character_preview_scene_path) as PackedScene
			if packed == null:
				push_error("Character preview scene could not be loaded: " + game.character_preview_scene_path)
				continue
			var instance := packed.instantiate()
			if instance is not Control:
				push_error("Character preview must be a Control: " + game.character_preview_scene_path)
				instance.free()
				continue
			var preview := instance as Control
			if not preview.has_method("configure"):
				push_error("Character preview must implement configure(Dictionary).")
				preview.free()
				continue
			# Every seat keeps a live preview; the stage shows the featured one.
			preview.name = "Player%dPreview" % (player + 1)
			preview.mouse_filter = Control.MOUSE_FILTER_IGNORE
			_setup_stage.add_preview(preview)
			card["preview"] = preview


## A seat authored in the scene, described in the same shape as a built one.
func _seat_card(panel: Control, description: Label) -> Dictionary:
	var line := panel.get_child(0) as BoxContainer
	return {
		"panel": panel,
		"line": line,
		"row": line.get_child(0),
		"description": description,
	}


## Player 3 and beyond get the scene's own seat shape, so an extra driver reads
## exactly like the first two: identity row first, their choices beneath.
func _build_extra_seat(player: int) -> Dictionary:
	var panel := VBoxContainer.new()
	panel.name = "Player%dControl" % (player + 1)
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	panel.add_theme_constant_override("separation", 10)
	var line := BoxContainer.new()
	line.name = "Line"
	line.vertical = true
	line.add_theme_constant_override("separation", 10)
	panel.add_child(line)
	var row := PanelContainer.new()
	row.name = "Row"
	row.theme_type_variation = &"SetupRowPanel"
	row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	line.add_child(row)
	var identity := HBoxContainer.new()
	identity.name = "Identity"
	identity.add_theme_constant_override("separation", 20)
	row.add_child(identity)
	var avatar := PlayerAvatar.new()
	avatar.name = "Avatar"
	avatar.custom_minimum_size = _player_one_avatar.custom_minimum_size
	avatar.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	avatar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	avatar.add_to_group(&"setup_scaled")
	avatar.configure(Identity.tag(player), Identity.color(player), Identity.name_for(player))
	identity.add_child(avatar)
	var names := VBoxContainer.new()
	names.name = "Names"
	names.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	names.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	names.add_theme_constant_override("separation", 2)
	identity.add_child(names)
	var title := Label.new()
	title.name = "Title"
	title.text = Identity.name_for(player).to_upper()
	title.add_theme_font_size_override("font_size", 26)
	names.add_child(title)
	var keys := Label.new()
	keys.name = "Keys"
	keys.theme_type_variation = &"SetupBody"
	keys.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	keys.add_theme_font_size_override("font_size", 22)
	names.add_child(keys)
	var description := Label.new()
	description.name = "Description"
	description.visible = false
	description.theme_type_variation = &"SetupBody"
	description.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	description.add_theme_font_size_override("font_size", 20)
	panel.add_child(description)
	_controller_grid.add_child(panel)
	return {
		"panel": panel, "line": line, "row": row, "keys": keys, "description": description,
	}


func _on_player_count_selected(index: int) -> void:
	_pending_player_count = _player_count_choice.get_item_id(index)
	_select_default_opponent()
	_update_confirmation()
	_update_selection_state()


func _on_character_selected(index: int, player: int) -> void:
	var options := GameSession.character_options()
	GameSession.set_character_for_player(player, str(options[index]["id"]))
	_featured_seat = player
	_refresh_player_setup()


## Focusing a seat's picker brings that seat's character onto the stage.
func _feature_seat(player: int) -> void:
	if player == _featured_seat:
		return
	_featured_seat = player
	_update_stage()


func _refresh_player_setup() -> void:
	var versus := _pending_mode == GameSession.GameMode.MULTIPLAYER
	var count := _pending_player_count if versus else 1
	_player_count_choice.visible = versus and GameSession.maximum_local_players() > 2
	_player_count_choice.select(_player_count_choice.get_item_index(_pending_player_count))
	var character_label := _game_text("character_label", "Character")
	for player in _player_setup_cards.size():
		var card := _player_setup_cards[player]
		var panel := card["panel"] as Control
		panel.visible = player < count
		if player >= count:
			continue
		if card.has("keys"):
			(card["keys"] as Label).text = "KEYS " + _custom_key_summary(player)
			(card["description"] as Label).text = _game_text(
				"player_three_control_description",
				"Take your turn using the shared controls." if _turn_based_setup()
				else "Use this player's declared controls."
			)
		# A seat row already says whose pick sits beside it; solo gets a heading.
		if card.has("character_label"):
			(card["character_label"] as Control).visible = not versus
		var selection := GameSession.character_for_player(player)
		if selection.is_empty() or not card.has("picker"):
			continue
		var picker := card["picker"] as OptionButton
		_refresh_setup_picker(picker, GameSession.character_options(), selection)
		picker.tooltip_text = str(selection.get("description", selection["title"]))
		picker.accessibility_description = "%s %s: %s" % [
			Identity.name_for(player), character_label.to_lower(), str(selection["title"]),
		]
		var preview := card.get("preview") as Control
		if preview != null:
			selection["player_index"] = player
			selection["player_color"] = Identity.color(player)
			selection["multiplayer"] = versus
			preview.call("configure", selection)
	_update_stage()


## Stands the featured seat's character on the plinth. The ring wears that
## seat's identity colour, and multiplayer also names the seat in words, so
## colour is never the only thing saying whose choice is on show.
func _update_stage() -> void:
	var versus := _pending_mode == GameSession.GameMode.MULTIPLAYER
	var count := _pending_player_count if versus else 1
	if _featured_seat >= mini(count, _player_setup_cards.size()):
		_featured_seat = 0
	var preview: Control = null
	if not _player_setup_cards.is_empty():
		preview = _player_setup_cards[_featured_seat].get("preview") as Control
	_setup_stage.visible = preview != null
	if preview == null:
		return
	_setup_stage.show_preview(preview)
	_setup_stage.set_surface_color(GameCatalog.theme().background_top)
	_setup_stage.set_ring_color(Identity.color(_featured_seat))
	var selection := GameSession.character_for_player(_featured_seat)
	_setup_stage.set_caption(
		"%s · %s" % [
			Identity.name_for(_featured_seat).to_upper(),
			str(selection.get("title", "")).to_upper(),
		]
		if versus
		else ""
	)


func _target_pad_copy() -> String:
	return (
		"any mapped button (%s)" % Settings.controller_target_summary(", ")
		if Settings.one_button_targets_enabled()
		else "buttons %s" % Settings.controller_target_summary(", ")
	)


func _selected_cpu_difficulty() -> int:
	# This style's opponent belongs to the game, not the shared target presets.
	if _uses_custom_keys():
		return GameSession.cpu_difficulty
	return _cpu_difficulty.get_selected_id()


func _configure_solo_setup_choices() -> void:
	_solo_setup_options.clear()
	for child: Node in _solo_setup_choices_box.get_children():
		child.queue_free()
	var manifest := GameCatalog.current()
	if manifest == null:
		return
	var seen := {}
	for key: String in manifest.solo_setup_choices:
		if key.is_empty():
			push_warning(
				"ModeSelect: %s declared an empty solo_setup_choices entry." % manifest.id
			)
			continue
		if seen.has(key):
			push_warning(
				"ModeSelect: %s repeated solo_setup_choices key '%s'." % [manifest.id, key]
			)
			continue
		seen[key] = true
		var definition := _solo_setup_definition(manifest, key)
		if definition.is_empty():
			push_warning(
				"ModeSelect: %s solo_setup_choices references missing tunable '%s'."
				% [manifest.id, key]
			)
			continue
		if str(definition.get("type", GameManifest.OPTION_SLIDER)) != GameManifest.OPTION_CHOICE:
			push_warning(
				"ModeSelect: %s solo_setup_choices key '%s' is not a choice option."
				% [manifest.id, key]
			)
			continue
		var choices: Array[Dictionary] = Settings.option_choices(key)
		if choices.is_empty():
			push_warning(
				"ModeSelect: %s solo_setup_choices key '%s' declares no choices."
				% [manifest.id, key]
			)
			continue
		var option_panel := VBoxContainer.new()
		option_panel.name = "SoloSetup_%s" % key.replace("/", "_")
		option_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		option_panel.add_theme_constant_override("separation", 10)
		var layout := option_panel

		layout.add_child(_setup_section_label(str(definition.get("title", key))))

		var description := str(definition.get("description", "")).strip_edges()
		if not description.is_empty():
			var description_label := Label.new()
			description_label.theme_type_variation = &"SetupBody"
			description_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			description_label.add_theme_font_size_override("font_size", 20)
			description_label.text = description
			layout.add_child(description_label)

		var options := HFlowContainer.new()
		options.add_theme_constant_override("h_separation", 12)
		options.add_theme_constant_override("v_separation", 12)
		layout.add_child(options)

		var group := ButtonGroup.new()
		var buttons: Array[Button] = []
		for choice: Dictionary in choices:
			var value := int(choice.get("value", 0))
			var button := Button.new()
			button.name = "%s_%s" % [key.replace("/", "_"), value]
			button.theme_type_variation = &"SetupChoice"
			button.custom_minimum_size = Vector2(SOLO_SETUP_BUTTON_MIN_WIDTH, TOUCH_HEIGHT)
			button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			button.clip_text = true
			button.toggle_mode = true
			button.button_group = group
			button.set_meta("setting_key", key)
			button.set_meta("choice_value", value)
			button.pressed.connect(_on_solo_setup_choice_pressed.bind(key, value))
			options.add_child(button)
			buttons.append(button)
		_solo_setup_choices_box.add_child(option_panel)
		_solo_setup_options.append({
			"key": key,
			"definition": definition,
			"buttons": buttons,
		})
	_refresh_solo_setup_choices()


func _solo_setup_definition(manifest: GameManifest, key: String) -> Dictionary:
	for definition: Dictionary in manifest.tunables:
		if str(definition.get("key", "")) == key:
			return definition
	return {}


func _on_solo_setup_choice_pressed(setting_key: String, value: int) -> void:
	if Settings.tunable_choice(setting_key) == value:
		_refresh_solo_setup_choices()
		return
	Settings.set_value(setting_key, value)


func _refresh_solo_setup_choices() -> void:
	for option: Dictionary in _solo_setup_options:
		var key := str(option.get("key", ""))
		var definition: Dictionary = option.get("definition", {})
		var description := str(definition.get("description", "")).strip_edges()
		var selected := Settings.tunable_choice(key)
		for button: Button in option.get("buttons", []):
			var value := int(button.get_meta("choice_value", 0))
			var title := _solo_setup_choice_button_title(definition, value)
			var active := value == selected
			button.set_pressed_no_signal(active)
			button.text = "✔  %s" % title if active else title
			var details := "%s: %s" % [str(definition.get("title", key)), title]
			if not description.is_empty():
				details += ". " + description
			if active:
				details += " Selected."
			button.tooltip_text = details
			button.accessibility_description = details


func _is_solo_setup_key(key: String) -> bool:
	for option: Dictionary in _solo_setup_options:
		if str(option.get("key", "")) == key:
			return true
	return false


func _single_player_roster_copy() -> String:
	return _solo_setup_text(
		_game_text("single_player_roster",
			"Player 1 plays alone" if _solo_setup_options.is_empty() else "Single player · %s")
	)


func _single_player_selection_summary() -> String:
	return _solo_setup_text(
		_game_text(
			"single_player_selection_summary",
			"Selected: Single Player - only Player 1 takes part."
			if _solo_setup_options.is_empty() else "Selected: Single Player - %s."
		)
	)


func _solo_setup_text(text: String) -> String:
	return Settings.solo_setup_text(GameCatalog.current_id(), text)


func _solo_setup_choice_button_title(definition: Dictionary, value: int) -> String:
	for choice: Dictionary in Settings.option_choices(str(definition.get("key", ""))):
		if int(choice.get("value", 0)) == value:
			var title := str(choice.get("summary_title", choice.get("title", value))).strip_edges()
			return title if not title.is_empty() else str(value)
	return str(value)


## Marks the armed opponent with a tick and spells the choice out underneath, so
## the selection never rests on the pressed-button styling alone.
func _update_opponent_options() -> void:
	var cpu_selected := _cpu_selected()
	_human_option_button.text = (
		HUMAN_OPPONENT_TEXT if cpu_selected else ARMED_MARK + HUMAN_OPPONENT_TEXT
	)
	_cpu_option_button.text = (
		ARMED_MARK + CPU_OPPONENT_TEXT if cpu_selected else CPU_OPPONENT_TEXT
	)
	_human_option_button.tooltip_text = (
		"Player 2 shares this device and plays with the Player 2 bindings."
	)
	_cpu_option_button.tooltip_text = (
		_custom_cpu_description()
		if _uses_custom_keys()
		else "Player 2 is played automatically at the difficulty chosen below."
	)
	_human_option_button.accessibility_description = _human_option_button.tooltip_text
	_cpu_option_button.accessibility_description = _cpu_option_button.tooltip_text
	_opponent_choice_hint.text = (
		(
			_custom_cpu_description()
			if _uses_custom_keys()
			else "Player 2 is driven by the CPU. Pick its difficulty below."
		)
		if cpu_selected
		else "Player 2 is a person sharing this device with you."
	)


func _show_step(next_step: int) -> void:
	if next_step == _step:
		return

	var outgoing := _page_for_step(_step)
	var incoming := _page_for_step(next_step)
	_step = next_step
	_update_stepper()

	if _page_tween and _page_tween.is_valid():
		_page_tween.kill()

	if _reduced_motion:
		outgoing.hide()
		outgoing.modulate = Color.WHITE
		outgoing.scale = Vector2.ONE
		incoming.show()
		incoming.modulate = Color.WHITE
		incoming.scale = Vector2.ONE
		_focus_current_step.call_deferred()
		return

	_center_page_pivot(outgoing)
	_center_page_pivot(incoming)
	incoming.modulate.a = 0.0
	incoming.scale = Vector2(0.98, 0.98)
	incoming.show()

	_page_tween = create_tween().set_trans(Tween.TRANS_QUART).set_ease(Tween.EASE_OUT)
	_page_tween.tween_property(outgoing, "modulate:a", 0.0, 0.12)
	_page_tween.parallel().tween_property(outgoing, "scale", Vector2(0.985, 0.985), 0.12)
	_page_tween.tween_callback(outgoing.hide)
	_page_tween.tween_property(incoming, "modulate:a", 1.0, 0.2)
	_page_tween.parallel().tween_property(incoming, "scale", Vector2.ONE, 0.24)
	_page_tween.tween_callback(_focus_current_step)


func _page_for_step(step: int) -> Control:
	return _selection_step if step == Step.PLAYER_COUNT else _confirm_step


func _center_page_pivot(page: Control) -> void:
	page.pivot_offset = page.size * 0.5


func _focus_current_step() -> void:
	if _step == Step.PLAYER_COUNT:
		if first_focus and first_focus.is_visible_in_tree():
			first_focus.grab_focus()
		return
	_preferred_confirm_focus().grab_focus()


## Where the confirmation step should land: the armed opponent option when
## there is one, so the current answer is obvious before the player starts
## arrowing between them, and the start button otherwise.
func _preferred_confirm_focus() -> Button:
	if _level_choice != null:
		return _level_choice
	if not _player_setup_cards.is_empty() and _player_setup_cards[0].has("picker"):
		return _player_setup_cards[0]["picker"] as OptionButton
	if _pending_mode == GameSession.GameMode.SINGLE_PLAYER:
		var solo_button := _preferred_solo_setup_button()
		if solo_button != null:
			return solo_button
	if (
		_pending_mode != GameSession.GameMode.MULTIPLAYER
		or not _cpu_opponent_offered()
	):
		return _confirm_button
	return (
		_cpu_option_button
		if _cpu_option_button.button_pressed
		else _human_option_button
	)


func _preferred_solo_setup_button() -> Button:
	for option: Dictionary in _solo_setup_options:
		for button: Button in option.get("buttons", []):
			if button.button_pressed:
				return button
		for button: Button in option.get("buttons", []):
			return button
	return null


func _pending_mode_is_available() -> bool:
	return (
		_single_player_available
		if _pending_mode == GameSession.GameMode.SINGLE_PLAYER
		else _multiplayer_available
	)


## Two bars mark the step: the current one is longer as well as accent-lit, so
## where the player stands never rests on colour alone. A screen without the
## player-count step shows one short accent rule instead of a one-step stepper.
func _update_stepper() -> void:
	var confirming := _step == Step.CONFIRM
	var accent := GameCatalog.theme().accent
	_step_one_bar.color = STEP_BAR_IDLE if confirming else accent
	_step_two_bar.color = accent if confirming else STEP_BAR_IDLE
	_step_one_bar.custom_minimum_size = (
		(STEP_BAR_OTHER if confirming else STEP_BAR_CURRENT) * _layout_scale
	)
	_step_two_bar.custom_minimum_size = (
		(STEP_BAR_CURRENT if confirming else STEP_BAR_OTHER) * _layout_scale
	)
	_header_rule.visible = not _stepper.visible
	_header_rule.color = accent
	_header_rule.custom_minimum_size = HEADER_RULE_SIZE * _layout_scale
	var progress := (
		"Step 2 of 2: set up the players." if confirming else "Step 1 of 2: choose a mode."
	)
	_stepper.tooltip_text = progress
	_stepper.accessibility_name = progress
	if confirming:
		_screen_title.add_theme_color_override(&"font_color", accent)
	else:
		_screen_title.remove_theme_color_override(&"font_color")
	_back_button.tooltip_text = (
		"Return to mode selection." if confirming and _player_count_offered else ""
	)


## The setup headings use the display face unless the game's skin brings a
## heading font of its own; then they wear the game's face like its other menus.
func _apply_heading_face() -> void:
	var skin := GameCatalog.theme().ui_theme
	if skin == null or not skin.has_font(&"font", &"MenuHeading"):
		return
	var face := skin.get_font(&"font", &"MenuHeading")
	for heading: Label in [
		_step_title, _confirm_title, _single_player_title, _multiplayer_title,
	]:
		heading.add_theme_font_override(&"font", face)


func _next_scene() -> String:
	var show_instructions := bool(Settings.get_value("game/show_instructions", true))
	return instructions_scene if show_instructions else GameCatalog.current_gameplay_scene_path()


func go_back() -> void:
	# Without a player-count step there is nothing behind the confirmation, so
	# Back has to leave rather than reveal a card the screen never offered.
	if _step == Step.CONFIRM and _player_count_offered:
		if GameCatalog.theme().ui_sounds != null:
			AudioManager.play_back()
		_show_step(Step.PLAYER_COUNT)
	else:
		super()


func _on_back_pressed() -> void:
	go_back()
