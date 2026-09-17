extends MenuScreen

## Settings screen. Every control reads and writes through the Settings
## autoload, which persists and applies the values — nothing is stored here.
##
## Works both as a standalone scene (from the main menu) and as an overlay
## (from the pause menu); MenuScreen.go_back() handles the difference.
##
## The Controls and Game tabs configure one game. In a collection build they
## only exist while a game is running: the pause menu sets
## [member game_context_id] before adding this screen to the tree, and the main
## menu does not, because until a game is picked there is nothing to configure.
## A build that ships one game has no such ambiguity, so the screen adopts that
## game and shows both tabs everywhere. Their rows are built from the active
## [GameManifest], so adding a game never means editing this file.
##
## Signals are connected in code rather than in the scene so adding a setting
## means touching one file.

const FPS_OPTIONS := [0, 30, 60, 90, 120, 144]

## Metrics copied from the authored rows so a generated row lines up with them.
const ROW_LABEL_WIDTH := 340.0
const ROW_VALUE_WIDTH := 110.0
const ROW_CONTROL_WIDTH := 280.0
const ROW_SLIDER_SIZE := Vector2(260, 40)
const ROW_SEPARATION := 24
const HEADING_FONT_SIZE := 22
const HEADING_COLOR := Color(0.301961, 0.639216, 1, 1)
const PLAYER_TWO_HEADING_COLOR := Color(1, 0.360784, 0.423529, 1)
const VALUE_COLOR := Color(0.686275, 0.866667, 0.917647, 1)
const REBIND_HELP := "Select, then press a key. Reusing a key swaps the bindings."

## Game whose Controls and Game tabs this screen configures. Empty means the
## screen was opened outside a game, where per-game options are meaningless —
## which a standalone build resolves for itself in [method _resolve_game_context].
var game_context_id := ""

@onready var _master: HSlider = %MasterSlider
@onready var _master_value: Label = %MasterValue
@onready var _music: HSlider = %MusicSlider
@onready var _music_value: Label = %MusicValue
@onready var _sfx: HSlider = %SfxSlider
@onready var _sfx_value: Label = %SfxValue
@onready var _mute: CheckButton = %MuteToggle
@onready var _window_mode: OptionButton = %WindowMode
@onready var _vsync: CheckButton = %VSyncToggle
@onready var _max_fps: OptionButton = %MaxFps
@onready var _ui_scale: HSlider = %UiScaleSlider
@onready var _ui_scale_value: Label = %UiScaleValue
@onready var _show_fps: CheckButton = %ShowFpsToggle
@onready var _visual_effects: CheckButton = %VisualEffectsToggle
@onready var _reduced_motion: CheckButton = %ReducedMotionToggle
@onready var _audio_captions: CheckButton = %AudioCaptionsToggle
@onready var _player_labels: CheckButton = %PlayerLabelsToggle
@onready var _one_button_triangle_rush: CheckButton = %OneButtonTriangleRushToggle
@onready var _gameplay_speed: HSlider = %GameplaySpeedSlider
@onready var _gameplay_speed_value: Label = %GameplaySpeedValue
@onready var _target_size: HSlider = %TargetSizeSlider
@onready var _target_size_value: Label = %TargetSizeValue
@onready var _extra_round_time: HSlider = %ExtraRoundTimeSlider
@onready var _extra_round_time_value: Label = %ExtraRoundTimeValue
@onready var _round_mode: OptionButton = %RoundModeOption
@onready var _starting_lives: HSlider = %StartingLivesSlider
@onready var _starting_lives_value: Label = %StartingLivesValue
@onready var _game_options: VBoxContainer = %GameOptions
@onready var _keyboard_bindings: VBoxContainer = %KeyboardBindings
@onready var _controller_speed: HSlider = %ControllerSpeedSlider
@onready var _controller_speed_value: Label = %ControllerSpeedValue
@onready var _controller_deadzone: HSlider = %ControllerDeadzoneSlider
@onready var _controller_deadzone_value: Label = %ControllerDeadzoneValue
@onready var _show_instructions: CheckButton = %ShowInstructionsToggle
@onready var _controller_target_one: OptionButton = %ControllerTargetOne
@onready var _controller_target_two: OptionButton = %ControllerTargetTwo
@onready var _controller_target_three: OptionButton = %ControllerTargetThree
@onready var _controller_pause: OptionButton = %ControllerPause
@onready var _controller_movement_scheme: OptionButton = %ControllerMovementScheme
@onready var _controller_hint: Label = %ControllerHint
@onready var _binding_status: Label = %BindingStatus
@onready var _reset_controls_button: Button = %ResetControlsButton
@onready var _reset_all_button: Button = %ResetButton
@onready var _back_button: Button = %BackButton
@onready var _hint: Label = %Hint
@onready var _margins: MarginContainer = %Margins
@onready var _tabs: TabContainer = %Tabs

var _syncing := false
var _writing_settings := false
## Generated rebind buttons and option widgets, keyed by their setting key.
var _binding_buttons: Dictionary = {}
var _option_controls: Dictionary = {}
var _option_values: Dictionary = {}
var _controller_buttons: Dictionary = {}
var _listening_binding := ""
var _default_hint := ""


func _ready() -> void:
	first_focus = _back_button
	margins = _margins
	_default_hint = _hint.text
	_controller_buttons = {
		Settings.CONTROLLER_TARGET_KEYS[0]: _controller_target_one,
		Settings.CONTROLLER_TARGET_KEYS[1]: _controller_target_two,
		Settings.CONTROLLER_TARGET_KEYS[2]: _controller_target_three,
		Settings.CONTROLLER_PAUSE_KEY: _controller_pause,
	}
	_populate_options()
	_resolve_game_context()
	_build_game_tabs()
	_connect_ui()
	_configure_setting_help()
	_sync_from_settings()
	_configure_gamepad_rows(GameSession.gamepad_connected())
	Settings.changed.connect(_on_setting_changed)
	GameSession.gamepad_availability_changed.connect(_on_gamepad_availability_changed)
	super()


## Adopts the only game in a standalone build, so its Controls and Game tabs
## are reachable from the main menu instead of only from a paused round.
##
## The catalog decides, not a game name: one game in the build means that game
## *is* the product, and its options are the product's options. A collection
## leaves this empty until the pause menu names the running game, because
## configuring one of several games nobody has chosen yet would be a guess.
func _resolve_game_context() -> void:
	if not game_context_id.is_empty():
		return
	if GameCatalog.is_single_game_build():
		game_context_id = GameCatalog.current_id()


## Builds the two per-game tabs, or removes them when this screen was not
## opened from inside a game. Everything here comes from the active manifest,
## so a new game appears without this file changing.
func _build_game_tabs() -> void:
	var manifest := (
		GameCatalog.get_manifest(game_context_id)
		if not game_context_id.is_empty()
		else null
	)
	var in_game := manifest != null
	_set_tab_visible(_tab_page(_game_options), in_game)
	_set_tab_visible(_tab_page(_keyboard_bindings), in_game)
	if not in_game:
		return

	_build_option_rows(manifest)
	_build_binding_rows(manifest)
	_configure_style_rows(manifest)


## The tab page owning a list entry: `Tabs/<Page>/Pad/List/<node>`.
func _tab_page(node: Node) -> Control:
	return node.get_parent().get_parent().get_parent() as Control


## TabContainer keeps a hidden child in the tab bar, so the tab itself has to be
## hidden by index rather than by hiding the page.
func _set_tab_visible(page: Node, visible_tab: bool) -> void:
	var index := _tabs.get_tab_idx_from_control(page as Control)
	if index >= 0:
		_tabs.set_tab_hidden(index, not visible_tab)


func _build_option_rows(manifest: GameManifest) -> void:
	var heading := ""
	for definition: Dictionary in Settings.options_for_game(manifest.id):
		var declared := str(definition.get("heading", "")).strip_edges()
		if not declared.is_empty() and declared != heading:
			heading = declared
			_game_options.add_child(_make_heading(declared, HEADING_COLOR))
		_game_options.add_child(_make_option_row(definition))


func _build_binding_rows(manifest: GameManifest) -> void:
	var heading := ""
	for definition: Dictionary in Settings.control_bindings_for_game(manifest.id):
		var declared := str(definition.get("heading", "")).strip_edges()
		if not declared.is_empty() and declared != heading:
			heading = declared
			_keyboard_bindings.add_child(
				_make_heading(
					declared, _heading_color(definition),
					int(definition.get("player", -1)) < 0
				)
			)
		_keyboard_bindings.add_child(_make_binding_row(definition))


## Player 2's heading keeps its own colour so the two blocks stay
## distinguishable without relying on reading the words.
func _heading_color(definition: Dictionary) -> Color:
	return (
		PLAYER_TWO_HEADING_COLOR
		if int(definition.get("player", -1)) == 1
		else HEADING_COLOR
	)


func _make_heading(text: String, color: Color, section := true) -> Label:
	var label := Label.new()
	label.text = text.to_upper()
	if section:
		label.theme_type_variation = &"MenuSectionHeading"
	label.add_theme_color_override(
		"font_color", GameCatalog.theme().widget_color("font_color", label.theme_type_variation, color)
	)
	label.add_theme_font_size_override("font_size", HEADING_FONT_SIZE)
	return label


func _make_row(title: String) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", ROW_SEPARATION)
	var label := Label.new()
	label.text = title
	label.custom_minimum_size = Vector2(ROW_LABEL_WIDTH, 0.0)
	label.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	row.add_child(label)
	return row


func _make_option_row(definition: Dictionary) -> HBoxContainer:
	var key := str(definition["key"])
	var row := _make_row(_option_title(definition))
	match Settings.option_type(key):
		GameManifest.OPTION_TOGGLE:
			var toggle := CheckButton.new()
			toggle.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
			toggle.toggled.connect(_on_option_toggled.bind(key))
			row.add_child(toggle)
			_option_controls[key] = toggle
		GameManifest.OPTION_CHOICE:
			var option := OptionButton.new()
			option.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			for choice: Dictionary in Settings.option_choices(key):
				option.add_item(
					str(choice.get("title", choice.get("value", ""))),
					int(choice.get("value", 0))
				)
			option.item_selected.connect(_on_option_choice_selected.bind(key))
			row.add_child(option)
			_option_controls[key] = option
		_:
			var slider := HSlider.new()
			slider.custom_minimum_size = ROW_SLIDER_SIZE
			slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			slider.size_flags_vertical = Control.SIZE_SHRINK_CENTER
			# Set before connecting: changing a Range's bounds re-emits
			# `value_changed`, which would write the pre-sync value to disk.
			slider.min_value = Settings.tunable_min(key)
			slider.max_value = Settings.tunable_max(key)
			slider.step = Settings.tunable_step(key)
			slider.value = Settings.tunable(key)
			slider.value_changed.connect(_on_option_slider_changed.bind(key))
			row.add_child(slider)

			var value := Label.new()
			value.custom_minimum_size = Vector2(ROW_VALUE_WIDTH, 0.0)
			value.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
			value.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
			value.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
			value.add_theme_color_override("font_color", VALUE_COLOR)
			row.add_child(value)
			_option_controls[key] = slider
			_option_values[key] = value
	return row


func _make_binding_row(definition: Dictionary) -> HBoxContainer:
	var key := str(definition["key"])
	var row := _make_row(str(definition.get("title", "Control")))
	var button := Button.new()
	button.custom_minimum_size = Vector2(ROW_CONTROL_WIDTH, 0.0)
	button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	button.pressed.connect(_on_binding_pressed.bind(key))
	row.add_child(button)
	_binding_buttons[key] = button
	return row


func _option_title(definition: Dictionary) -> String:
	var title := str(definition.get("title", "")).strip_edges()
	if not title.is_empty():
		return title
	# A key like `game/triangle_size` reads as "Triangle size" unaided.
	var name := str(definition.get("key", "")).split("/")[-1]
	return name.replace("_", " ").capitalize()


## Rows outside the per-game tabs that still only make sense for one control
## style. One-button play is about pressing target keys, so it is noise in a
## game you steer — and in a standalone build of one, it would be the only
## thing on screen naming another game.
##
## Only reached once a game is known. Without one the rows stay as authored,
## because a collection's main menu is configuring all of them at once.
func _configure_style_rows(manifest: GameManifest) -> void:
	var targets := manifest.control_style == GameManifest.CONTROL_STYLE_TARGETS
	var row := _one_button_triangle_rush.get_parent() as Control
	if row != null:
		row.visible = targets
	for control: Control in [
		_round_mode, _starting_lives, _extra_round_time,
		_gameplay_speed, _target_size,
	]:
		(control.get_parent() as Control).visible = manifest.uses_shell_round_rules
	(_game_options.get_parent().get_node("RoundHeading") as Control).visible = (
		manifest.uses_shell_round_rules
	)
	(_gameplay_speed.get_parent().get_parent().get_node("GameplayHeading") as Control).visible = (
		manifest.uses_shell_round_rules
	)


## Controller rows describe one control style at a time: target buttons mean
## nothing to a game you steer, and a movement scheme means nothing to a game
## played by pressing target keys. Custom action keys imply neither.
func _configure_controller_rows(manifest: GameManifest, connected: bool) -> void:
	var targets := manifest.control_style == GameManifest.CONTROL_STYLE_TARGETS
	for setting_key: String in Settings.CONTROLLER_TARGET_KEYS:
		var row := (_controller_buttons[setting_key] as Control).get_parent() as Control
		if row != null:
			row.visible = connected and targets
	var movement_row := _controller_movement_scheme.get_parent() as Control
	if movement_row != null:
		movement_row.visible = (
			connected and manifest.control_style == GameManifest.CONTROL_STYLE_DIRECT_MOVEMENT
		)
	if manifest.control_style == GameManifest.CONTROL_STYLE_CUSTOM_KEYS:
		(_controller_speed.get_parent() as Control).hide()
		(_controller_deadzone.get_parent() as Control).hide()


func _populate_options() -> void:
	_window_mode.clear()
	_window_mode.add_item("Windowed", Settings.WindowMode.WINDOWED)
	_window_mode.add_item("Fullscreen", Settings.WindowMode.FULLSCREEN)
	_window_mode.add_item("Borderless window", Settings.WindowMode.BORDERLESS)
	# The browser and mobile OSes own the window; don't pretend otherwise.
	_window_mode.disabled = OS.has_feature("web") or OS.has_feature("mobile")

	_max_fps.clear()
	for fps: int in FPS_OPTIONS:
		_max_fps.add_item("Unlimited" if fps == 0 else str(fps), fps)

	_round_mode.clear()
	for mode in [Settings.RoundMode.TIMER, Settings.RoundMode.LIVES]:
		_round_mode.add_item(Settings.round_mode_label(mode), mode)

	# Bounds come from Settings so the slider can never offer a value the
	# stored setting would clamp away. Safe here because `_connect_ui()` has
	# not run yet, so the re-emitted `value_changed` reaches nothing.
	_starting_lives.min_value = Settings.MIN_STARTING_LIVES
	_starting_lives.max_value = Settings.MAX_STARTING_LIVES

	for setting_key: String in _controller_buttons:
		var option := _controller_buttons[setting_key] as OptionButton
		option.clear()
		for button: int in Settings.controller_button_ids_for_setting(
			setting_key
		):
			option.add_item(Settings.controller_button_label(button), button)

	_controller_movement_scheme.clear()
	for scheme in range(
		Settings.ControllerMovementScheme.LEFT_STICK_AND_DPAD,
		Settings.ControllerMovementScheme.RIGHT_STICK_ONLY + 1
	):
		_controller_movement_scheme.add_item(
			Settings.controller_movement_scheme_label(scheme),
			scheme
		)


func _connect_ui() -> void:
	_master.value_changed.connect(_on_volume_changed.bind("audio/master"))
	_music.value_changed.connect(_on_volume_changed.bind("audio/music"))
	_sfx.value_changed.connect(_on_volume_changed.bind("audio/sfx"))
	_mute.toggled.connect(_on_bool_toggled.bind("audio/muted"))
	_vsync.toggled.connect(_on_bool_toggled.bind("display/vsync"))
	_show_fps.toggled.connect(_on_bool_toggled.bind("ui/show_fps"))
	_visual_effects.toggled.connect(
		_on_bool_toggled.bind(Settings.VISUAL_EFFECTS_KEY)
	)
	_reduced_motion.toggled.connect(
		_on_bool_toggled.bind(Settings.REDUCED_MOTION_KEY)
	)
	_audio_captions.toggled.connect(
		_on_bool_toggled.bind(Settings.AUDIO_CAPTIONS_KEY)
	)
	_player_labels.toggled.connect(
		_on_bool_toggled.bind(Settings.PLAYER_LABELS_KEY)
	)
	_one_button_triangle_rush.toggled.connect(
		_on_bool_toggled.bind(Settings.ONE_BUTTON_TRIANGLE_RUSH_KEY)
	)
	_gameplay_speed.value_changed.connect(
		_on_setting_slider_changed.bind(Settings.GAMEPLAY_SPEED_KEY)
	)
	_target_size.value_changed.connect(
		_on_setting_slider_changed.bind(Settings.TARGET_SIZE_KEY)
	)
	_extra_round_time.value_changed.connect(
		_on_setting_slider_changed.bind(Settings.EXTRA_ROUND_TIME_KEY)
	)
	_round_mode.item_selected.connect(_on_round_mode_selected)
	_starting_lives.value_changed.connect(_on_starting_lives_changed)
	_controller_speed.value_changed.connect(
		_on_setting_slider_changed.bind(Settings.CONTROLLER_SPEED_KEY)
	)
	_controller_deadzone.value_changed.connect(
		_on_setting_slider_changed.bind(Settings.CONTROLLER_DEADZONE_KEY)
	)
	_show_instructions.toggled.connect(_on_bool_toggled.bind("game/show_instructions"))
	_window_mode.item_selected.connect(_on_window_mode_selected)
	_max_fps.item_selected.connect(_on_max_fps_selected)
	_ui_scale.value_changed.connect(_on_ui_scale_changed)
	for setting_key: String in _controller_buttons:
		var option := _controller_buttons[setting_key] as OptionButton
		option.item_selected.connect(
			_on_controller_button_selected.bind(setting_key)
		)
	_controller_movement_scheme.item_selected.connect(
		_on_controller_movement_scheme_selected
	)
	_reset_controls_button.pressed.connect(_on_reset_controls_pressed)
	_tabs.tab_changed.connect(_on_tab_changed)
	_back_button.focus_entered.connect(_restore_default_hint)
	_back_button.mouse_entered.connect(_restore_default_hint)


func _configure_setting_help() -> void:
	var descriptions: Dictionary = {
		_master: "Controls the overall level for all game audio.",
		_music: "Controls music without changing sound effects.",
		_sfx: "Controls menu feedback and gameplay sounds.",
		_mute: "Silences all audio without changing individual volume levels.",
		_window_mode: "Choose windowed, borderless or fullscreen display.",
		_vsync: "Synchronizes frames with the display to reduce tearing.",
		_max_fps: "Caps rendering at the selected frame rate.",
		_show_fps: "Shows the current frame rate in menus and gameplay.",
		_ui_scale: "Changes the size of menus and the gameplay HUD.",
		_visual_effects: (
			"Turn off to remove full-screen flashes and screen shake. "
			+ "Other animation stays under Reduced motion."
		),
		_reduced_motion: "Stops decorative motion, trails and animated backgrounds.",
		_player_labels: "Shows P1/P2 markers so color is not the only player cue.",
		_audio_captions: "Shows text for scoring, misses, saws and countdown cues.",
		_gameplay_speed: "Slows moving targets and falling cans next round.",
		_target_size: "Makes targets and cans larger next round.",
		_extra_round_time: "Adds time to each round starting next round.",
		_round_mode: (
			"Choose whether a round ends on the countdown or on running "
			+ "out of lives."
		),
		_starting_lives: "Lives each player gets per round in Lives mode.",
		_one_button_triangle_rush: "Any target input activates the highlighted target.",
		_controller_speed: "Changes controller cursor speed in direct-movement games.",
		_controller_deadzone: "Sets how far a stick moves before input begins.",
		_controller_pause: (
			"Sets pause for all controllers; D-pad stays available for movement."
		),
		_controller_movement_scheme: "Chooses the stick and optional D-pad movement.",
		_reset_controls_button: "Restores only this game's keyboard and controller bindings.",
		_show_instructions: "Shows controls and rules before gameplay.",
		_reset_all_button: "Restores settings without erasing progress.",
	}
	for setting_key: String in _binding_buttons:
		descriptions[_binding_buttons[setting_key]] = _binding_help(setting_key)
	for setting_key: String in _option_controls:
		descriptions[_option_controls[setting_key]] = _option_help(setting_key)
	for setting_key: String in Settings.CONTROLLER_TARGET_KEYS:
		descriptions[_controller_buttons[setting_key]] = (
			"Shared by all controllers. Reusing a button swaps the bindings."
		)
	for control: Control in descriptions:
		_register_setting_help(control, descriptions[control])


## Games are not obliged to describe every option, so an undescribed row still
## gets a usable line for the hint bar and for assistive technology.
func _option_help(setting_key: String) -> String:
	var definition: Dictionary = Settings.tunables().get(setting_key, {})
	var description := str(definition.get("description", "")).strip_edges()
	return (
		description
		if not description.is_empty()
		else "Changes %s for this game." % _option_title(definition).to_lower()
	)


func _binding_help(setting_key: String) -> String:
	var description := Settings.binding_description(setting_key)
	return description if not description.is_empty() else REBIND_HELP


func _register_setting_help(control: Control, description: String) -> void:
	control.tooltip_text = description
	control.accessibility_description = description
	control.focus_entered.connect(_show_setting_help.bind(description))
	control.mouse_entered.connect(_show_setting_help.bind(description))

	var row := control.get_parent() as Control
	if row == null:
		return
	row.tooltip_text = description
	row.mouse_entered.connect(_show_setting_help.bind(description))
	for child: Node in row.get_children():
		var row_control := child as Control
		if row_control != null:
			row_control.tooltip_text = description


func _show_setting_help(description: String) -> void:
	_hint.text = description


func _on_tab_changed(_tab: int) -> void:
	_restore_default_hint()


func _restore_default_hint() -> void:
	_hint.text = _default_hint


## Ranges and visibility for the Game tab come from the options the active game
## declares, so this screen never hardcodes a game's numbers.
##
## Must run while [member _syncing] is set: changing a slider's bounds re-emits
## `value_changed`, which would otherwise write the pre-sync value back to disk.
func _sync_game_options() -> void:
	for key: String in _option_controls:
		var control: Control = _option_controls[key]
		match Settings.option_type(key):
			GameManifest.OPTION_TOGGLE:
				(control as CheckButton).button_pressed = Settings.tunable_bool(key)
			GameManifest.OPTION_CHOICE:
				_select_id(control as OptionButton, Settings.tunable_choice(key))
			_:
				var slider := control as HSlider
				slider.min_value = Settings.tunable_min(key)
				slider.max_value = Settings.tunable_max(key)
				slider.value = Settings.tunable(key)


## Controller bindings and pad-only assists are meaningless without a pad, so
## the whole section collapses to a single note until one is connected. This
## re-runs on hot-plug, so a controller can be attached without leaving the
## screen.
func _configure_gamepad_rows(connected: bool) -> void:
	var pad_controls: Array[Control] = [
		_controller_movement_scheme,
		_controller_speed,
		_controller_deadzone,
	]
	for setting_key: String in _controller_buttons:
		pad_controls.append(_controller_buttons[setting_key] as Control)
	for control in pad_controls:
		var row := control.get_parent() as Control
		if row != null:
			row.visible = connected

	var manifest := (
		GameCatalog.get_manifest(game_context_id)
		if not game_context_id.is_empty()
		else null
	)
	if manifest != null:
		_configure_controller_rows(manifest, connected)
	var custom_keys := (
		manifest != null
		and manifest.control_style == GameManifest.CONTROL_STYLE_CUSTOM_KEYS
	)
	_controller_hint.visible = not connected
	_binding_status.text = (
		"Controller 1 controls Player 1 and Controller 2 controls Player 2."
		if connected and not custom_keys
		else "Rebind a key by selecting it and pressing the new key."
	)


func _on_gamepad_availability_changed(available: bool) -> void:
	_configure_gamepad_rows(available)


## Pushes the stored values into the widgets without echoing them back.
func _sync_from_settings() -> void:
	_syncing = true
	_sync_game_options()
	_master.value = float(Settings.get_value("audio/master"))
	_music.value = float(Settings.get_value("audio/music"))
	_sfx.value = float(Settings.get_value("audio/sfx"))
	_mute.button_pressed = bool(Settings.get_value("audio/muted"))
	_vsync.button_pressed = bool(Settings.get_value("display/vsync"))
	_show_fps.button_pressed = bool(Settings.get_value("ui/show_fps"))
	_visual_effects.button_pressed = Settings.visual_effects_enabled()
	_reduced_motion.button_pressed = Settings.reduced_motion_enabled()
	_audio_captions.button_pressed = Settings.audio_captions_enabled()
	_player_labels.button_pressed = Settings.player_labels_enabled()
	_one_button_triangle_rush.button_pressed = Settings.one_button_triangle_rush_enabled()
	_gameplay_speed.value = Settings.gameplay_speed_scale()
	_target_size.value = Settings.target_size_scale()
	_extra_round_time.value = Settings.extra_round_time()
	_starting_lives.value = Settings.starting_lives()
	_select_id(_round_mode, Settings.round_mode(game_context_id))
	_controller_speed.value = Settings.controller_movement_scale()
	_controller_deadzone.value = Settings.controller_deadzone()
	_show_instructions.button_pressed = bool(Settings.get_value("game/show_instructions"))
	_ui_scale.value = float(Settings.get_value("ui/scale"))
	_select_id(_window_mode, int(Settings.get_value("display/window_mode")))
	_select_id(_max_fps, int(Settings.get_value("display/max_fps")))
	for setting_key: String in _controller_buttons:
		var option := _controller_buttons[setting_key] as OptionButton
		_select_id(option, int(Settings.get_value(setting_key)))
	_select_id(
		_controller_movement_scheme,
		Settings.controller_movement_scheme()
	)
	_syncing = false
	_refresh_value_labels()
	_refresh_control_buttons()
	_refresh_round_mode_controls()


## The lives pool only means anything in lives mode, so the slider greys out
## under the countdown instead of the row disappearing and shifting the tab.
func _refresh_round_mode_controls() -> void:
	_starting_lives.editable = Settings.lives_mode_enabled(game_context_id)


func _select_id(option: OptionButton, id: int) -> void:
	var index := option.get_item_index(id)
	option.selected = index if index >= 0 else 0


func _refresh_value_labels() -> void:
	_master_value.text = "%d%%" % roundi(_master.value * 100.0)
	_music_value.text = "%d%%" % roundi(_music.value * 100.0)
	_sfx_value.text = "%d%%" % roundi(_sfx.value * 100.0)
	_ui_scale_value.text = "%d%%" % roundi(_ui_scale.value * 100.0)
	_gameplay_speed_value.text = "%d%%" % roundi(_gameplay_speed.value * 100.0)
	_target_size_value.text = "%d%%" % roundi(_target_size.value * 100.0)
	_extra_round_time_value.text = (
		"Off"
		if is_zero_approx(_extra_round_time.value)
		else "+%d sec" % roundi(_extra_round_time.value)
	)
	var lives := roundi(_starting_lives.value)
	_starting_lives_value.text = "%d %s" % [lives, "life" if lives == 1 else "lives"]
	_controller_speed_value.text = "%d%%" % roundi(_controller_speed.value * 100.0)
	_controller_deadzone_value.text = "%d%%" % roundi(
		_controller_deadzone.value * 100.0
	)
	for key: String in _option_values:
		var slider := _option_controls[key] as HSlider
		(_option_values[key] as Label).text = Settings.format_option(
			key, slider.value
		)


func _refresh_control_buttons() -> void:
	for setting_key: String in _binding_buttons:
		var button := _binding_buttons[setting_key] as Button
		button.text = (
			"Press a key..."
			if setting_key == _listening_binding
			else Settings.binding_key_label(setting_key)
		)


# --- Widget handlers --------------------------------------------------------

func _on_volume_changed(value: float, key: String) -> void:
	_refresh_value_labels()
	if _syncing:
		return
	_set_setting(key, value)


func _on_bool_toggled(pressed: bool, key: String) -> void:
	if _syncing:
		return
	_set_setting(key, pressed)


func _on_window_mode_selected(index: int) -> void:
	if _syncing:
		return
	_set_setting("display/window_mode", _window_mode.get_item_id(index))


func _on_max_fps_selected(index: int) -> void:
	if _syncing:
		return
	_set_setting("display/max_fps", _max_fps.get_item_id(index))


func _on_round_mode_selected(index: int) -> void:
	if _syncing:
		return
	_set_setting(Settings.ROUND_MODE_KEY, _round_mode.get_item_id(index))
	_refresh_round_mode_controls()


## Lives are stored as a whole count, so the slider's float is rounded before
## it reaches [Settings] and the stored type stays stable across saves.
func _on_starting_lives_changed(value: float) -> void:
	_refresh_value_labels()
	if _syncing:
		return
	_set_setting(Settings.STARTING_LIVES_KEY, roundi(value))


func _on_ui_scale_changed(value: float) -> void:
	_refresh_value_labels()
	if _syncing:
		return
	_set_setting("ui/scale", value)


func _on_setting_slider_changed(value: float, key: String) -> void:
	_refresh_value_labels()
	if _syncing:
		return
	_set_setting(key, value)


## A game-declared slider. Whole-numbered options are stored as ints so the
## saved type matches the declared default and survives a reload.
func _on_option_slider_changed(value: float, key: String) -> void:
	_refresh_value_labels()
	if _syncing:
		return
	var definition: Dictionary = Settings.tunables().get(key, {})
	_set_setting(
		key,
		roundi(value) if typeof(definition.get("default")) == TYPE_INT else value
	)


func _on_option_toggled(pressed: bool, key: String) -> void:
	if _syncing:
		return
	_set_setting(key, pressed)


func _on_option_choice_selected(index: int, key: String) -> void:
	if _syncing:
		return
	var option := _option_controls[key] as OptionButton
	_set_setting(key, option.get_item_id(index))


func _on_controller_button_selected(index: int, setting_key: String) -> void:
	if _syncing:
		return
	var option := _controller_buttons[setting_key] as OptionButton
	var button := option.get_item_id(index)
	_writing_settings = true
	var assigned := Settings.set_controller_button(setting_key, button)
	_writing_settings = false
	if assigned:
		_binding_status.text = "%s now uses %s." % [
			_controller_binding_title(setting_key),
			Settings.controller_button_label(button),
		]
	else:
		_binding_status.text = "That controller button could not be assigned."
	_sync_controller_controls()


func _on_controller_movement_scheme_selected(index: int) -> void:
	if _syncing:
		return
	var scheme := _controller_movement_scheme.get_item_id(index)
	_set_setting(Settings.CONTROLLER_MOVEMENT_SCHEME_KEY, scheme)
	_binding_status.text = "Movement uses %s." % (
		Settings.controller_movement_scheme_label(scheme)
	)


func _set_setting(key: String, value: Variant) -> void:
	_writing_settings = true
	Settings.set_value(key, value)
	_writing_settings = false


func _on_binding_pressed(setting_key: String) -> void:
	_listening_binding = setting_key
	_binding_status.text = (
		"Press a key for %s. Esc cancels." % Settings.binding_title(setting_key)
	)
	_refresh_control_buttons()


func _input(event: InputEvent) -> void:
	if _listening_binding.is_empty() or not event is InputEventKey:
		return

	var key_event := event as InputEventKey
	if not key_event.pressed or key_event.echo:
		return
	get_viewport().set_input_as_handled()

	var keycode := (
		key_event.physical_keycode
		if key_event.physical_keycode != KEY_NONE
		else key_event.keycode
	)
	if keycode == KEY_ESCAPE or key_event.keycode == KEY_ESCAPE:
		_cancel_binding("Binding cancelled.")
		return
	if not Settings.is_control_key_allowed(keycode):
		_binding_status.text = "Esc and F11 are reserved. Press another key."
		return

	var setting_key := _listening_binding
	_listening_binding = ""
	_writing_settings = true
	# Scoped to the running game: a key it shares with another game is not a
	# conflict, because only one of them is ever on screen.
	var assigned := Settings.set_binding_key(setting_key, keycode, game_context_id)
	_writing_settings = false
	if assigned:
		_binding_status.text = "%s now uses %s." % [
			Settings.binding_title(setting_key),
			Settings.binding_key_label(setting_key),
		]
	else:
		_binding_status.text = "That key could not be assigned."
	_refresh_control_buttons()


func _cancel_binding(message: String) -> void:
	_listening_binding = ""
	_binding_status.text = message
	_refresh_control_buttons()


func _on_reset_controls_pressed() -> void:
	_listening_binding = ""
	_writing_settings = true
	Settings.reset_controls_to_defaults(game_context_id)
	_writing_settings = false
	_binding_status.text = "Gameplay controls restored to their defaults."
	_refresh_control_buttons()
	_sync_controller_controls()


func _sync_controller_controls() -> void:
	_syncing = true
	for setting_key: String in _controller_buttons:
		var option := _controller_buttons[setting_key] as OptionButton
		_select_id(option, int(Settings.get_value(setting_key)))
	_select_id(
		_controller_movement_scheme,
		Settings.controller_movement_scheme()
	)
	_syncing = false


func _controller_binding_title(setting_key: String) -> String:
	var target_index := Settings.CONTROLLER_TARGET_KEYS.find(setting_key)
	if target_index >= 0:
		return "Controller target %d" % (target_index + 1)
	return "Pause" if setting_key == Settings.CONTROLLER_PAUSE_KEY else "Controller"


func _on_reset_pressed() -> void:
	_listening_binding = ""
	_writing_settings = true
	Settings.reset_to_defaults()
	_writing_settings = false
	_sync_from_settings()


func _on_back_pressed() -> void:
	go_back()


## Keeps the widgets honest when something else changes a setting
## (F11 for fullscreen, for instance).
func _on_setting_changed(_key: String, _value: Variant) -> void:
	if not _syncing and not _writing_settings:
		_sync_from_settings()
