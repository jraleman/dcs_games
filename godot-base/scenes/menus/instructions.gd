extends MenuScreen

## A video-first briefing with an on-demand, scrollable guide. Both presentations
## come from the manifest; a game without footage opens its written guide instead.

## The screen a solo-only game came from, since it reaches this screen without
## passing through mode select.
@export_file("*.tscn") var main_menu_scene := "res://scenes/menus/main_menu.tscn"
@export_file("*.tscn") var game_select_scene := "res://scenes/menus/game_select.tscn"

const VIDEO_ASPECT := 16.0 / 9.0
const GUIDE_MAX_WIDTH := 1080.0

## Portrait tints, matching the P1/P2 colours the gameplay HUD already uses so a
## player is recognisable from the instructions through to the round itself.
const PLAYER_ONE_COLOR := Color("4da3ff")
const PLAYER_TWO_COLOR := Color("ff5c6c")
const Identity = preload("res://scripts/player_identity.gd")

@onready var _margins: MarginContainer = %Margins
@onready var _layout: VBoxContainer = %Layout
@onready var _header: BoxContainer = %Header
@onready var _title: Label = %Title
@onready var _back_button: Button = %BackButton
@onready var _mode_label: Label = %ModeLabel
@onready var _setup_label: Label = %SetupLabel
@onready var _card: Control = %Card
@onready var _headline: Label = %Headline
@onready var _summary: Label = %Summary
@onready var _body: CenterContainer = %Body
@onready var _video_card: VBoxContainer = %VideoCard
@onready var _video_frame: AspectRatioContainer = %VideoFrame
@onready var _video_title: Label = %VideoTitle
@onready var _video_actions: HBoxContainer = %VideoActions
@onready var _restart_button: Button = %RestartButton
@onready var _video: VideoStreamPlayer = %Video
@onready var _poster_image: TextureRect = %PosterImage
@onready var _video_scrim: ColorRect = %Scrim
@onready var _poster: CenterContainer = %Poster
@onready var _poster_label: Label = %PosterLabel
@onready var _time_label: Label = %TimeLabel
@onready var _video_focus: Control = %VideoFocus
@onready var _video_border: Control = %VideoBorder
@onready var _guide: ScrollContainer = %Guide
@onready var _guide_button: Button = %GuideButton
@onready var _demo_prompt: Label = %DemoPrompt
@onready var _control_grid: GridContainer = %ControlGrid
@onready var _player_one_card: PanelContainer = %PlayerOneCard
@onready var _player_one_avatar: PlayerAvatar = %PlayerOneAvatar
@onready var _player_one_controls: Label = %PlayerOneControls
@onready var _opponent_card: PanelContainer = %OpponentCard
@onready var _opponent_avatar: PlayerAvatar = %OpponentAvatar
@onready var _opponent_title: Label = %OpponentTitle
@onready var _opponent_controls: Label = %OpponentControls
@onready var _rules: Label = %Rules
@onready var _actions: BoxContainer = %Actions
@onready var _action_spacer: Control = %ActionSpacer
@onready var _show_again: CheckButton = %ShowAgainToggle
@onready var _start_button: Button = %StartButton

var _entrance_tween: Tween
var _reduced_motion := false
var _video_ready := false
var _guide_open := false
var _resume_after_guide := false
var _roster_text := ""
var _ui_unit := 1.0
var _font_sizes: Dictionary[Control, int] = {}
var _minimum_sizes: Dictionary[Control, Vector2] = {}
var _separations: Dictionary[Control, Dictionary] = {}
var _panel_styles: Dictionary[Control, StyleBox] = {}
var _toggle_icons: Dictionary[StringName, ImageTexture] = {}
var _toggle_icon_sizes: Dictionary[StringName, Vector2] = {}
var _extra_control_cards: Array[Dictionary] = []


func _ready() -> void:
	_reduced_motion = Settings.reduced_motion_enabled()
	first_focus = _start_button
	margins = _margins
	# Back has to undo however the player got here. A solo-only game skips mode
	# select entirely (see `main_menu.gd`), so returning to it would bounce
	# straight back and trap the player in a loop. What is left depends on
	# whether the build stopped to ask which game: the picker if it did, the
	# title screen if there was nothing to pick.
	var game := GameCatalog.current()
	if not GameSession.multiplayer_offered() and (
		game == null or (game.characters.is_empty() and game.solo_setup_choices.is_empty()
			and game.levels.is_empty())
	):
		back_scene = (
			game_select_scene if GameCatalog.offers_a_choice() else main_menu_scene
		)
	_populate_instructions()
	_setup_video()
	_guide.visible = not _video_ready
	_guide_button.visible = _video_ready
	_update_guide_help()
	_show_again.button_pressed = bool(Settings.get_value("game/show_instructions", true))
	_show_again.toggled.connect(_on_show_again_toggled)
	GameSession.gamepad_availability_changed.connect(_on_gamepad_availability_changed)
	GameSession.controller_assignments_changed.connect(_populate_instructions)
	Settings.changed.connect(_on_setting_changed)
	_card.resized.connect(_fit_content)
	_remember_layout(_margins)
	super()
	_refresh_focus_order()
	_play_entrance.call_deferred()


## The control cards only list pad bindings while a pad is attached.
func _on_gamepad_availability_changed(_available: bool) -> void:
	_populate_instructions()


func _on_setting_changed(key: String, value: Variant) -> void:
	if key == "ui/scale":
		refresh_layout()
		return
	if key == "game/show_instructions":
		_show_again.set_pressed_no_signal(bool(value))
		return
	if key == Settings.REDUCED_MOTION_KEY:
		_reduced_motion = bool(value)
		if _video_ready:
			_video.loop = not _reduced_motion
			if _reduced_motion:
				_resume_after_guide = false
				_pause_video()
		return
	if _is_solo_setup_key(key):
		_populate_instructions()
		return
	if not _uses_custom_keys():
		return
	for binding: Dictionary in Settings.control_bindings_for_game(GameCatalog.current_id()):
		if str(binding["key"]) == key:
			_populate_instructions()
			return


func _process(_delta: float) -> void:
	_update_video_time()


func _exit_tree() -> void:
	if _video_ready:
		_video.stop()


func _on_layout_changed(size: Vector2) -> void:
	# Work in physical UI units, not the phone's expanded 1920-wide canvas.
	# Scale font sizes, not Controls, so rasterized text stays sharp after stretching.
	var preference := float(Settings.get_value("ui/scale", 1.0))
	_ui_unit = size.x / maxf(get_window().size.x, 1.0) * preference
	var canvas := size / _ui_unit
	_scale_layout()
	var horizontal := roundi(clampf(canvas.x * 0.025, 12.0, 40.0))
	var vertical := 12 if canvas.y < 500 else 20
	Responsive.set_margins(_margins,
		roundi(horizontal * _ui_unit), roundi(vertical * _ui_unit),
		roundi(horizontal * _ui_unit), roundi(vertical * _ui_unit))
	var usable := canvas.x - horizontal * 2
	_header.vertical = usable < 330.0
	_title.add_theme_font_size_override("font_size",
		roundi((24 if usable < 600 else 30) * _ui_unit))
	_actions.vertical = usable < 480.0
	_action_spacer.visible = not _actions.vertical
	_show_again.size_flags_horizontal = (
		Control.SIZE_EXPAND_FILL if _actions.vertical else Control.SIZE_SHRINK_BEGIN
	)
	_start_button.size_flags_horizontal = (
		Control.SIZE_EXPAND_FILL if _actions.vertical else Control.SIZE_FILL
	)
	_layout.add_theme_constant_override("separation",
		roundi((8 if canvas.y < 500 else 12) * _ui_unit))
	_margins.size = size
	_fit_content.call_deferred()


func _fit_content() -> void:
	if not is_inside_tree():
		return
	var available := _card.size
	var video_height := maxf(
		available.y - _video_actions.get_combined_minimum_size().y - 8.0 * _ui_unit, 1.0
	)
	var width := minf(available.x, video_height * VIDEO_ASPECT)
	_video_frame.custom_minimum_size = Vector2(width, width / VIDEO_ASPECT)
	_guide.custom_minimum_size = Vector2(
		minf(available.x, GUIDE_MAX_WIDTH * _ui_unit), available.y
	)
	_control_grid.columns = mini(
		GameSession.player_count(),
		maxi(1, floori(_guide.custom_minimum_size.x / (300.0 * _ui_unit)))
	)
	_body.size = available


func _remember_layout(node: Node) -> void:
	var control := node as Control
	if control != null:
		if control.has_theme_font_size_override("font_size"):
			_font_sizes[control] = control.get_theme_font_size("font_size")
		if control.custom_minimum_size != Vector2.ZERO:
			_minimum_sizes[control] = control.custom_minimum_size
		var constants := {}
		for key: StringName in [&"separation", &"h_separation", &"v_separation", &"outline_size"]:
			if control.has_theme_constant_override(key):
				constants[key] = control.get_theme_constant(key)
		if not constants.is_empty():
			_separations[control] = constants
	for child in node.get_children():
		_remember_layout(child)


func _scale_layout() -> void:
	for control in _font_sizes:
		control.add_theme_font_size_override("font_size", roundi(_font_sizes[control] * _ui_unit))
	for control in _minimum_sizes:
		control.custom_minimum_size = _minimum_sizes[control] * _ui_unit
	for control in _separations:
		for key: StringName in _separations[control]:
			control.add_theme_constant_override(key, roundi(_separations[control][key] * _ui_unit))
	var panels: Array[Control] = [
		_video_border, _video_focus, _player_one_card, _opponent_card,
	]
	for card in _extra_control_cards:
		panels.append(card["panel"])
	for panel in panels:
		if not _panel_styles.has(panel):
			_panel_styles[panel] = panel.get_theme_stylebox("panel")
		var original := _panel_styles[panel]
		var box := original.duplicate() as StyleBox
		for side in [SIDE_LEFT, SIDE_TOP, SIDE_RIGHT, SIDE_BOTTOM]:
			box.set_content_margin(side, original.get_content_margin(side) * _ui_unit)
			if box is StyleBoxFlat:
				box.set_border_width(side,
					roundi((original as StyleBoxFlat).get_border_width(side) * _ui_unit))
		panel.add_theme_stylebox_override("panel", box)
	_style_navigation()


func _style_navigation() -> void:
	for button: BaseButton in [
		_back_button, _guide_button, _restart_button, _start_button, _show_again,
	]:
		for state: StringName in [&"normal", &"hover", &"pressed", &"disabled", &"focus"]:
			var box := get_theme_stylebox(state, button.theme_type_variation).duplicate() as StyleBox
			var padding := (4.0 if button == _show_again else 16.0) * _ui_unit
			box.set_content_margin(SIDE_LEFT, padding)
			box.set_content_margin(SIDE_RIGHT, padding)
			box.set_content_margin(SIDE_TOP, 8.0 * _ui_unit)
			box.set_content_margin(SIDE_BOTTOM, 8.0 * _ui_unit)
			if box is StyleBoxFlat:
				for side in [SIDE_LEFT, SIDE_TOP, SIDE_RIGHT, SIDE_BOTTOM]:
					box.set_border_width(side, roundi(box.get_border_width(side) * _ui_unit))
				if state == &"focus":
					box.set_border_width_all(maxi(2, roundi(2.0 * _ui_unit)))
			button.add_theme_stylebox_override(state, box)
		button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	_start_button.add_theme_constant_override("icon_max_width", roundi(14.0 * _ui_unit))
	_show_again.add_theme_constant_override("h_separation", roundi(8.0 * _ui_unit))
	for key: StringName in [
		&"checked", &"unchecked", &"checked_disabled", &"unchecked_disabled",
		&"checked_mirrored", &"unchecked_mirrored",
		&"checked_disabled_mirrored", &"unchecked_disabled_mirrored",
	]:
		if not _toggle_icons.has(key):
			var original := get_theme_icon(key, &"MenuToggle")
			_toggle_icons[key] = ImageTexture.create_from_image(original.get_image())
			_toggle_icon_sizes[key] = original.get_size()
		_toggle_icons[key].set_size_override(Vector2i(_toggle_icon_sizes[key] * _ui_unit))
		_show_again.add_theme_icon_override(key, _toggle_icons[key])


func _on_guide_toggled(expanded: bool) -> void:
	_guide_open = expanded
	_guide_button.set_pressed_no_signal(expanded)
	if expanded:
		_resume_after_guide = _video.is_playing() and not _video.paused
		if _resume_after_guide:
			_pause_video()
	elif _resume_after_guide:
		_resume_after_guide = false
		if not _reduced_motion:
			_play_video()
	_video_card.visible = _video_ready and not expanded
	_guide.visible = expanded or not _video_ready
	_update_guide_help()
	_guide_button.grab_focus()
	_refresh_focus_order()
	_fit_content.call_deferred()


func _update_guide_help() -> void:
	_guide_button.text = "Watch" if _guide_open else "Guide"
	_guide_button.tooltip_text = (
		"Return to the walkthrough." if _guide_open else "Show controls and rules."
	)
	_guide_button.accessibility_description = _guide_button.tooltip_text


func _refresh_focus_order() -> void:
	var controls: Array[Control] = []
	if _video_ready:
		controls.append(_guide_button)
	controls.append(_back_button)
	if _guide.visible:
		controls.append(_guide)
	else:
		controls.append_array([_video, _restart_button])
	controls.append_array([_show_again, _start_button])
	for index in controls.size():
		controls[index].focus_next = controls[(index + 1) % controls.size()].get_path()
		var previous := controls[(index - 1 + controls.size()) % controls.size()]
		controls[index].focus_previous = previous.get_path()


func _populate_instructions() -> void:
	_configure_avatars()
	_opponent_card.visible = GameSession.player_two_enabled()
	if _uses_custom_keys():
		_populate_custom_keys_instructions()
	elif _uses_direct_movement():
		_populate_direct_movement_instructions()
	else:
		_populate_target_instructions()
	_summary.text = _solo_setup_text(_summary.text)
	var level := GameSession.selected_level()
	if not level.is_empty():
		_summary.text += "\n" + str(level["title"])
	_refresh_player_roster()
	_append_round_mode_note()
	_populate_setup_label()
	_mode_label.tooltip_text = _mode_label.text
	_mode_label.accessibility_description = _mode_label.text
	if is_node_ready():
		_scale_layout()
		_fit_content.call_deferred()


func _populate_setup_label() -> void:
	var parts := PackedStringArray()
	var game := GameCatalog.current()
	if game != null and not game.solo_setup_choices.is_empty() and GameSession.is_single_player():
		parts.append("P1: " + _solo_setup_text("%s"))
	var level := GameSession.selected_level()
	if not level.is_empty():
		parts.append(str(level["title"]))
	if not _roster_text.is_empty():
		parts.append(_roster_text)
	_setup_label.text = "  |  ".join(parts)
	_setup_label.visible = not parts.is_empty()
	_setup_label.tooltip_text = _setup_label.text
	_setup_label.accessibility_description = _setup_label.text


func _refresh_player_roster() -> void:
	var count := GameSession.player_count()
	while _extra_control_cards.size() < maxi(count - 2, 0):
		var player := _extra_control_cards.size() + 2
		var panel := PanelContainer.new()
		panel.name = "Player%dCard" % (player + 1)
		panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		panel.add_theme_stylebox_override("panel", _panel_styles.get(
			_player_one_card, _player_one_card.get_theme_stylebox("panel")
		))
		var layout := VBoxContainer.new()
		layout.add_theme_constant_override("separation", 12)
		panel.add_child(layout)
		var header := HBoxContainer.new()
		header.add_theme_constant_override("separation", 12)
		layout.add_child(header)
		var avatar := PlayerAvatar.new()
		avatar.custom_minimum_size = Vector2(48, 48)
		avatar.configure(Identity.tag(player), Identity.color(player), Identity.name_for(player))
		header.add_child(avatar)
		var title := Label.new()
		title.text = Identity.name_for(player).to_upper()
		title.add_theme_color_override("font_color", Identity.color(player))
		title.add_theme_font_size_override("font_size", 16)
		title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		header.add_child(title)
		var controls := Label.new()
		controls.add_theme_font_size_override("font_size", 16)
		controls.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		layout.add_child(controls)
		_control_grid.add_child(panel)
		_extra_control_cards.append({"panel": panel, "controls": controls})
		if is_node_ready():
			_remember_layout(panel)
	for index in _extra_control_cards.size():
		var card := _extra_control_cards[index]
		(card["panel"] as Control).visible = index + 2 < count
		(card["controls"] as Label).text = _custom_key_controls(index + 2)
	_roster_text = ""
	if GameSession.character_options().is_empty():
		return
	var roster := PackedStringArray()
	for player in count:
		var selected := GameSession.character_for_player(player)
		roster.append("%s: %s" % [Identity.tag(player), str(selected["title"])])
	_roster_text = (" -> " if GameSession.takes_turns() else " | ").join(roster)
	var roster_line := "\n" + _roster_text
	if not _summary.text.ends_with(roster_line):
		_summary.text += roster_line


## Copy for games whose players select numbered targets
## ([constant GameManifest.CONTROL_STYLE_TARGETS]). Like the other two style
## branches, every string is routed through [method _game_text] so a second
## `targets` game can describe its own scoring instead of inheriting the first
## one's, and the framework wording is only the fallback.
func _populate_target_instructions() -> void:
	_mode_label.text = "%s · %s" % [
		_current_game_title().to_upper(), GameSession.mode_title().to_upper(),
	]
	_headline.text = _game_text(
		"instructions_headline", "Follow your highlighted target"
	)
	_rules.text = _game_text(
		"instructions_rules",
		"Bright target = correct  ·  Correct hit +1  ·  Wrong target -1  ·  Esc pauses"
	)
	_player_one_controls.text = _target_controls(0, 1)
	if GameSession.is_single_player():
		_summary.text = _game_text(
			"instructions_solo_summary",
			"Only Player 1 is active. Score as many correct hits as possible "
			+ "%s." % _round_goal_phrase()
		)
		_demo_prompt.text = _game_text(
			"instructions_demo_prompt", "WATCH PLAYER 1'S HIGHLIGHTED TARGET"
		)
		_opponent_card.hide()
	elif GameSession.player_two_is_cpu():
		_summary.text = _game_text(
			"instructions_cpu_summary",
			(
				"Race the %s CPU for the highest score. You control P1 targets; "
				% GameSession.cpu_difficulty_title().to_lower()
			)
			+ "the CPU controls P2 targets."
		)
		_demo_prompt.text = _game_text(
			"instructions_demo_prompt", "PLAYER 1 FOLLOWS THE HIGHLIGHT"
		)
		_opponent_title.text = "CPU OPPONENT"
		_opponent_controls.text = _game_text(
			"instructions_cpu_controls",
			(
				"%s · %s\n" % [
					GameSession.cpu_difficulty_title(),
					GameSession.cpu_preset_title(),
				]
			)
			+ "The CPU plays automatically.\n"
			+ "Follow Player 1's highlighted target and beat the CPU's score."
		)
	else:
		_summary.text = _game_text(
			"instructions_versus_summary",
			"Both players act at the same time. Each player must follow their "
			+ "own highlighted target."
		)
		_demo_prompt.text = _game_text(
			"instructions_demo_prompt", "EACH PLAYER FOLLOWS THEIR OWN HIGHLIGHT"
		)
		_opponent_title.text = "PLAYER 2"
		_opponent_controls.text = _target_controls(1, 2)


## How the round the player is about to start will end, so the briefing
## promises the countdown or the lives pool that is actually configured.
func _round_goal_phrase() -> String:
	if not Settings.lives_mode_enabled():
		return "before the timer reaches zero"
	var lives := Settings.starting_lives()
	return "without spending all %d %s" % [
		lives,
		"life" if lives == 1 else "lives",
	]


## Adds what a mistake costs to the rules line. The scoring rules themselves
## belong to the game; only the round mode decides whether a mistake also ends
## the round, so the note is appended rather than baked into a game's copy.
func _append_round_mode_note() -> void:
	var game := GameCatalog.current()
	if game != null and not game.uses_shell_round_rules:
		return
	if not Settings.lives_mode_enabled():
		return
	var lives := Settings.starting_lives()
	_rules.text += "  ·  %d %s per round" % [
		lives,
		"life" if lives == 1 else "lives",
	]


## Each control card carries a portrait placeholder so the roster is readable at
## a glance. The tag tracks who actually holds the slot, so a CPU opponent is
## never presented as a second human player.
func _configure_avatars() -> void:
	_player_one_avatar.configure(
		"P1", PLAYER_ONE_COLOR, "Player 1 portrait placeholder."
	)
	if GameSession.is_single_player():
		return
	var cpu := GameSession.player_two_is_cpu()
	_opponent_avatar.configure(
		"CPU" if cpu else "P2",
		PLAYER_TWO_COLOR,
		(
			"CPU opponent portrait placeholder."
			if cpu
			else "Player 2 portrait placeholder."
		)
	)


## Copy for games whose players steer a cursor directly
## ([constant GameManifest.CONTROL_STYLE_DIRECT_MOVEMENT]).
func _populate_direct_movement_instructions() -> void:
	_mode_label.text = "%s · %s" % [
		_current_game_title().to_upper(),
		GameSession.mode_title().to_upper(),
	]
	_headline.text = _game_text(
		"instructions_headline", "Reach every target before it disappears"
	)
	_rules.text = _game_text(
		"instructions_rules",
		"Touch a target to score  ·  Each target scores once  ·  Esc pauses"
	)
	_demo_prompt.text = _game_text(
		"instructions_demo_prompt", "MOVE YOUR CURSOR ONTO A TARGET"
	)
	if GameSession.is_single_player():
		_summary.text = _game_text(
			"instructions_solo_summary",
			"Steer Player 1 around the board and clear every target you reach."
		)
		# A game that describes its own controls describes all of them. The
		# framework cannot know whether a connected pad does anything in a game
		# it knows nothing about, and offering a controller to someone holding
		# a guitar is worse than saying nothing.
		var solo_controls := _game_text("instructions_player_one_controls", "")
		_player_one_controls.text = (
			solo_controls
			if not solo_controls.is_empty()
			else _direct_movement_controls("Mouse or arrow keys", 1)
		)
		_opponent_card.hide()
	else:
		_summary.text = _game_text(
			"instructions_versus_summary",
			"Both players share one board. The first player to reach a target "
			+ "earns its point."
		)
		_player_one_controls.text = _direct_movement_controls("Player 1: mouse", 1)
		_opponent_title.text = "PLAYER 2"
		_opponent_controls.text = _direct_movement_controls(
			"Player 2: arrow keys", 2
		)


## Action descriptions come from the game; key names always come from the
## current bindings. A custom-key style implies no mouse or controller actions.
func _populate_custom_keys_instructions() -> void:
	var single_player := GameSession.is_single_player()
	var cpu := GameSession.player_two_is_cpu()
	var mode := (
		"Single Player" if single_player
		else "Multiplayer vs CPU" if cpu
		else GameSession.mode_title() if GameSession.takes_turns() or GameSession.player_count() > 2
		else "Local Multiplayer"
	)
	_mode_label.text = "%s · %s" % [_current_game_title().to_upper(), mode.to_upper()]
	_headline.text = _game_text("instructions_headline", "Play using your action keys")
	_rules.text = _game_text(
		"instructions_rules", "Rebind action keys in Settings → Controls  ·  Esc pauses"
	)
	_demo_prompt.text = _game_text("instructions_demo_prompt", "USE YOUR ACTION KEYS")
	_player_one_controls.text = _custom_key_controls(0)
	_opponent_card.visible = not single_player
	if single_player:
		_summary.text = _game_text(
			"instructions_solo_summary", "Play using Player 1's action keys."
		)
	elif cpu:
		_summary.text = _game_text(
			"instructions_cpu_summary",
			_game_text(
				"instructions_solo_summary",
				"You control Player 1. The CPU plays as Player 2."
			)
		)
		_opponent_title.text = "CPU OPPONENT"
		_opponent_controls.text = _game_text(
			"instructions_cpu_controls",
			_game_text(
				"cpu_opponent_description",
				"Player 2 plays automatically using this game's CPU opponent."
			)
		)
	else:
		_summary.text = _game_text(
			"instructions_versus_summary",
			"Both players share this device using their own action keys."
		)
		_opponent_title.text = "PLAYER 2"
		_opponent_controls.text = _custom_key_controls(1)


func _custom_key_controls(player_index: int) -> String:
	var player: String = ["one", "two", "three"][player_index]
	var game := GameCatalog.current()
	var shared := game != null and game.local_multiplayer_turns
	var lines := PackedStringArray([_game_text(
		"instructions_player_%s_controls" % player,
		_game_text(
			"player_%s_control_description" % player,
			"Take your turn using the shared controls." if shared else "Use the action keys below."
		)
	)])
	var binding_seat := 0 if shared else player_index
	for binding: Dictionary in Settings.control_bindings_for_game(GameCatalog.current_id()):
		var binding_player := int(binding.get("player", -1))
		if binding_player >= 0 and binding_player != binding_seat:
			continue
		var key := str(binding["key"])
		lines.append("%s: %s" % [Settings.binding_title(key), Settings.binding_key_label(key)])
	return "\n".join(lines)


## One control card for a direct-movement game: the keyboard/mouse line, plus
## a pad line only while a pad is actually connected.
func _direct_movement_controls(keyboard_line: String, controller_number: int) -> String:
	if not GameSession.gamepad_connected():
		return keyboard_line
	return "%s\nController %d: %s" % [
		keyboard_line,
		controller_number,
		Settings.controller_movement_scheme_label(),
	]


## Screen copy for the active game, falling back to neutral framework wording.
func _game_text(key: String, fallback: String) -> String:
	var manifest := GameCatalog.current()
	return manifest.text(key, fallback) if manifest else fallback


# --- Tutorial video ---------------------------------------------------------


## Loads the walkthrough clip for the active game. When the file is missing the
## card is removed and the screen keeps its original single-column layout.
func _setup_video() -> void:
	var path := _selected_tutorial_video_path()
	if path.is_empty() or not ResourceLoader.exists(path):
		_video_card.hide()
		set_process(false)
		return
	var stream := load(path) as VideoStream
	if stream == null:
		_video_card.hide()
		set_process(false)
		return

	_video_ready = true
	_video.stream = stream
	# The walkthrough repeats so a player can keep watching without hunting for
	# a replay control. Reduced motion opts out: an endlessly restarting clip is
	# exactly the kind of unrequested repeated movement that setting exists for,
	# so it keeps the explicit "Watch again" prompt instead.
	_video.loop = not _reduced_motion
	_video.volume_db = -80.0
	_video_title.text = "Walkthrough"
	_video_title.tooltip_text = "Silent gameplay recording. Captions explain each step."
	_video_title.accessibility_description = _video_title.tooltip_text
	_video.accessibility_name = "%s walkthrough" % _current_game_title()
	_video.gui_input.connect(_on_video_gui_input)
	_video.focus_entered.connect(_on_video_focus_changed)
	_video.focus_exited.connect(_on_video_focus_changed)
	var poster_path := _selected_tutorial_poster_path()
	if not poster_path.is_empty() and ResourceLoader.exists(poster_path):
		_poster_image.texture = load(poster_path)
	_update_video_time()
	if _reduced_motion:
		_set_video_idle("Watch walkthrough")
	else:
		_play_video()


func _selected_tutorial_video_path() -> String:
	var manifest := GameCatalog.current()
	if manifest == null:
		return ""
	if _uses_local_tutorial_media() and not manifest.local_tutorial_video_path.is_empty():
		return manifest.local_tutorial_video_path
	return manifest.tutorial_video_path


func _selected_tutorial_poster_path() -> String:
	var manifest := GameCatalog.current()
	if manifest == null:
		return ""
	if _uses_local_tutorial_media() and not manifest.local_tutorial_poster_path.is_empty():
		return manifest.local_tutorial_poster_path
	return manifest.tutorial_poster_path


func _uses_local_tutorial_media() -> bool:
	return GameSession.player_two_enabled() and not GameSession.player_two_is_cpu()


func _current_game_id() -> String:
	return GameCatalog.current_id()


func _current_game_title() -> String:
	return GameCatalog.current_title()


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


func _is_solo_setup_key(key: String) -> bool:
	var manifest := GameCatalog.current()
	if manifest == null:
		return false
	for choice_key: String in manifest.solo_setup_choices:
		if choice_key == key:
			return true
	return false


func _solo_setup_text(text: String) -> String:
	return Settings.solo_setup_text(GameCatalog.current_id(), text)


func _play_video() -> void:
	if not _video_ready:
		return
	if not _video.is_playing():
		_video.play()
	_video.paused = false
	_video_scrim.hide()
	_poster.hide()
	_poster_image.hide()
	_update_video_help()
	set_process(true)


func _pause_video() -> void:
	if not _video_ready or not _video.is_playing():
		return
	_video.paused = true
	_set_video_idle("Paused")


## Parks the player and shows the poster scrim with the supplied prompt.
func _set_video_idle(prompt: String) -> void:
	_poster_label.text = prompt
	_poster_image.visible = not _video.is_playing()
	_video_scrim.show()
	_poster.show()
	_update_video_help()
	set_process(false)
	_update_video_time()


func _toggle_video() -> void:
	if not _video_ready:
		return
	if _video.is_playing() and not _video.paused:
		_pause_video()
	else:
		_play_video()


func _update_video_time() -> void:
	if not _video_ready:
		return
	var length := _video.get_stream_length()
	if length <= 0.0:
		_time_label.text = _format_time(_video.stream_position)
		return
	_time_label.text = "%s / %s" % [
		_format_time(minf(_video.stream_position, length)),
		_format_time(length),
	]


func _format_time(seconds: float) -> String:
	var total := int(round(maxf(seconds, 0.0)))
	return "%d:%02d" % [total / 60, total % 60]


func _on_video_gui_input(event: InputEvent) -> void:
	var activate := false
	if event is InputEventMouseButton:
		activate = event.pressed and event.button_index == MOUSE_BUTTON_LEFT \
			and event.device != InputEvent.DEVICE_ID_EMULATION
	elif event is InputEventScreenTouch:
		activate = event.pressed and not event.canceled and event.index == 0
	elif event is InputEventJoypadButton and event.button_index == JOY_BUTTON_A:
		activate = event.pressed
	elif event.is_action_pressed("ui_accept") and not event.is_echo():
		activate = true
	if activate:
		_video.grab_focus()
		_toggle_video()
		_video.accept_event()


func _on_video_focus_changed() -> void:
	_video_focus.visible = _video.has_focus()


func _update_video_help() -> void:
	var playing := _video.is_playing() and not _video.paused
	var action := "pause" if playing else "resume" if _video.paused else "play"
	_video.tooltip_text = (
		"Click, tap, or press Enter / Space / controller confirm to %s." % action
	)
	_video.accessibility_description = "%s. %s" % [
		"Playing" if playing else _poster_label.text, _video.tooltip_text,
	]


func _on_restart_pressed() -> void:
	if not _video_ready:
		return
	_video.stop()
	_play_video()


## Only reached when looping is off, which today means Reduced motion is on.
## The clip parks on its poster so replaying stays an explicit choice.
func _on_video_finished() -> void:
	if not _video_ready:
		return
	_set_video_idle("Watch again")


# --- Static explanation ------------------------------------------------------


## One control card for a target-selection game. Named for the control style,
## not for the first game that used it.
func _target_controls(player_index: int, controller_number: int) -> String:
	var keyboard_summary := Settings.control_summary(player_index)
	var target_summary := "P%d targets" % (player_index + 1)
	var lines := PackedStringArray(["Keyboard: %s" % keyboard_summary])
	if GameSession.gamepad_connected():
		var controller_summary := (
			"any mapped button (%s)" % Settings.controller_target_summary(", ")
			if Settings.one_button_targets_enabled()
			else Settings.controller_target_summary(", ")
		)
		lines.append("Controller %d: %s" % [controller_number, controller_summary])
	lines.append("Mouse/touch: select %s" % target_summary)
	return "\n".join(lines)


func _play_entrance() -> void:
	if _reduced_motion:
		_card.modulate.a = 1.0
		return
	_card.modulate.a = 0.0
	_entrance_tween = create_tween()
	_entrance_tween.tween_property(_card, "modulate:a", 1.0, 0.22)


func _on_show_again_toggled(pressed: bool) -> void:
	Settings.set_value("game/show_instructions", pressed)


func _on_start_pressed() -> void:
	Router.goto(GameCatalog.current_gameplay_scene_path())


func _on_back_pressed() -> void:
	go_back()
