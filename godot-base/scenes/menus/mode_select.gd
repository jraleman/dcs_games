extends MenuScreen

## Two-step setup shared by every game: pick a player count, then confirm the
## controls. All game-specific wording comes from the active [GameManifest].

@export_file("*.tscn") var instructions_scene := "res://scenes/menus/instructions.tscn"

enum Step { PLAYER_COUNT, CONFIRM }

## Mode names an unlock rule may gate, matching
## [method GameUnlockRule.unlocked_modes].
const MODE_SINGLE_PLAYER := "Single Player"
const MODE_MULTIPLAYER := "Local Multiplayer"

## Portrait tints, matching the P1/P2 colours the gameplay HUD and the
## instructions screen already use, so a seat looks the same at every step.
const PLAYER_ONE_COLOR := Color("4da3ff")
const PLAYER_TWO_COLOR := Color("ff5c6c")

@onready var _margins: MarginContainer = %Margins
@onready var _screen_title: Label = $Margins/Layout/Header/Title
@onready var _back_button: Button = $Margins/Layout/Header/BackButton
@onready var _mode_grid: GridContainer = %ModeGrid
@onready var _controller_grid: GridContainer = %ControllerGrid
@onready var _selection_step: Control = %SelectionStep
@onready var _confirm_step: Control = %ConfirmStep
@onready var _selection_intro: Label = %Intro
@onready var _single_player_card: PanelContainer = (
	$Margins/Layout/Stage/SelectionStep/Layout/ModeGrid/SinglePlayer
)
@onready var _single_player_button: Button = %SinglePlayerButton
@onready var _single_player_description: Label = (
	$Margins/Layout/Stage/SelectionStep/Layout/ModeGrid/SinglePlayer/Layout/Description
)
@onready var _single_player_controls: Label = %SinglePlayerControls
@onready var _single_player_roster: Label = %SinglePlayerRoster
@onready var _single_player_status: Label = %SinglePlayerStatus
@onready var _multiplayer_card: PanelContainer = %Multiplayer
@onready var _multiplayer_button: Button = %MultiplayerButton
@onready var _multiplayer_description: Label = (
	$Margins/Layout/Stage/SelectionStep/Layout/ModeGrid/Multiplayer/Layout/Description
)
@onready var _multiplayer_controls: Label = %MultiplayerControls
@onready var _multiplayer_roster: Label = %MultiplayerRoster
@onready var _multiplayer_player_two_chip: Label = %MultiplayerPlayerTwoChip
@onready var _multiplayer_status: Label = %MultiplayerStatus
@onready var _selection_summary: Label = %SelectionSummary
@onready var _selection_hint: Label = %SelectionHint
@onready var _step_one_indicator: Label = %StepOneIndicator
@onready var _step_two_indicator: Label = %StepTwoIndicator
@onready var _connector: ColorRect = %Connector
@onready var _mode_eyebrow: Label = %ModeEyebrow
@onready var _confirm_title: Label = %ConfirmTitle
@onready var _confirm_description: Label = %ConfirmDescription
@onready var _opponent_control: PanelContainer = %OpponentControl
@onready var _player_one_control_keys: Label = %PlayerOneControlKeys
@onready var _player_one_role: Label = %PlayerOneRole
@onready var _player_one_control_description: Label = (
	$Margins/Layout/Stage/ConfirmStep/Layout/ConfirmPanel/Body/Scroll/Layout/ControllerGrid/PlayerOneControl/Layout/Description
)
@onready var _opponent_control_title: Label = %OpponentControlTitle
@onready var _opponent_avatar: PlayerAvatar = %OpponentAvatar
@onready var _player_one_avatar: PlayerAvatar = %PlayerOneAvatar
@onready var _opponent_role: Label = %OpponentRole
@onready var _opponent_control_keys: Label = %OpponentControlKeys
@onready var _opponent_control_description: Label = %OpponentControlDescription
@onready var _opponent_selector: PanelContainer = %OpponentSelector
@onready var _human_option_button: Button = %HumanOptionButton
@onready var _cpu_option_button: Button = %CpuOptionButton
@onready var _opponent_choice_hint: Label = %OpponentChoiceHint
@onready var _cpu_difficulty_panel: HBoxContainer = %CpuDifficultyPanel
@onready var _cpu_difficulty: OptionButton = %CpuDifficulty
@onready var _confirm_hint: Label = %ConfirmHint
@onready var _confirm_button: Button = %ConfirmButton

var _step := Step.PLAYER_COUNT
var _pending_mode := GameSession.GameMode.SINGLE_PLAYER
## True once the player has actually picked a card, so step one can show which
## mode is armed instead of pretending the default was a decision.
var _mode_chosen := false
var _page_tween: Tween
var _single_player_available := true
var _multiplayer_available := true
var _reduced_motion := false


func _ready() -> void:
	_reduced_motion = Settings.reduced_motion_enabled()
	first_focus = _single_player_button
	margins = _margins
	_select_default_opponent()
	_populate_cpu_difficulties()
	_cpu_difficulty.item_selected.connect(_on_cpu_difficulty_selected)
	_configure_game_copy()
	_configure_platform_options()
	_update_control_copy()
	_update_stepper()
	_update_confirmation()
	_update_selection_state()
	GameSession.gamepad_availability_changed.connect(_on_gamepad_availability_changed)
	super()


## Adding or removing the last pad rewrites every control line on the screen.
func _on_gamepad_availability_changed(_available: bool) -> void:
	_update_control_copy()
	_update_confirmation()


func _on_layout_changed(size: Vector2) -> void:
	var portrait := Responsive.is_portrait(size)
	_mode_grid.columns = (
		1
		if portrait or not (_single_player_available and _multiplayer_available)
		else 2
	)
	_controller_grid.columns = (
		1
		if portrait or _pending_mode == GameSession.GameMode.SINGLE_PLAYER
		else 2
	)


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


## Games steered directly share one screen between two humans, so they have no
## CPU rival to offer; everything else defaults to the CPU so a lone player can
## start a match without finding a second person first.
func _select_default_opponent() -> void:
	var cpu_default := not _uses_direct_movement()
	_cpu_option_button.set_pressed_no_signal(cpu_default)
	_human_option_button.set_pressed_no_signal(not cpu_default)


func _cpu_selected() -> bool:
	return _cpu_option_button.button_pressed and not _uses_direct_movement()


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
	_single_player_card.modulate.a = 1.0 if single_player or not _mode_chosen else 0.72
	_multiplayer_card.modulate.a = 0.72 if _mode_chosen and single_player else 1.0
	if single_player and _single_player_available:
		first_focus = _single_player_button
	elif not single_player and _multiplayer_available:
		first_focus = _multiplayer_button

	_single_player_roster.text = "Player 1 plays alone"
	_multiplayer_roster.text = (
		"Player 1 vs Player 2"
		if _uses_direct_movement()
		else "Player 2 is a human or the CPU"
	)
	_multiplayer_player_two_chip.text = _player_two_short_name()
	_selection_summary.visible = _mode_chosen
	if not _mode_chosen:
		return
	if not _pending_mode_is_available():
		_selection_summary.text = "This mode is not available yet."
		return
	_selection_summary.text = (
		"Selected: Single Player - only Player 1 takes part."
		if single_player
		else "Selected: Multiplayer - Player 1 vs %s." % _player_two_long_name()
	)


## Short roster badge for the second seat: "P2" for a human, "CPU" otherwise.
func _player_two_short_name() -> String:
	return (
		"CPU"
		if _cpu_selected()
		else "P2"
	)


func _player_two_long_name() -> String:
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
	if _pending_mode == GameSession.GameMode.SINGLE_PLAYER:
		GameSession.configure_single_player()
	else:
		var controller := (
			GameSession.PlayerTwoController.CPU
			if _cpu_selected()
			else GameSession.PlayerTwoController.HUMAN
		)
		GameSession.configure_multiplayer(controller, _selected_cpu_difficulty())
	Router.goto(_next_scene())


func _update_confirmation() -> void:
	var single_player := _pending_mode == GameSession.GameMode.SINGLE_PLAYER
	var direct_movement := _uses_direct_movement()
	_update_control_copy()
	_opponent_control.visible = not single_player
	_opponent_selector.visible = not single_player and not direct_movement
	var cpu_selected := (
		not single_player
		and not direct_movement
		and _cpu_option_button.button_pressed
	)
	_cpu_difficulty_panel.visible = cpu_selected
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

	if direct_movement:
		_update_direct_movement_confirmation(single_player)
	elif single_player:
		_mode_eyebrow.text = "SINGLE PLAYER"
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
		_mode_eyebrow.text = "MULTIPLAYER"
		_confirm_title.text = "Choose Player 2"
		_confirm_description.text = (
			"Race the CPU by default, or switch to a human player using the keyboard"
			+ (" or a second controller." if gamepad else ".")
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

	if not direct_movement:
		_update_opponent_options()
	_on_layout_changed(viewport_size())


func _update_direct_movement_confirmation(single_player: bool) -> void:
	var manifest := GameCatalog.current()
	var title := manifest.title.to_upper() if manifest else ""
	if single_player:
		_mode_eyebrow.text = "%s · SINGLE PLAYER" % title
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
		_mode_eyebrow.text = "%s · LOCAL MULTIPLAYER" % title
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
	for difficulty: int in GameSession.CPU_DIFFICULTIES:
		_cpu_difficulty.add_item(GameSession.cpu_option_title(difficulty), difficulty)
	var selected_index := _cpu_difficulty.get_item_index(GameSession.cpu_difficulty)
	_cpu_difficulty.selected = selected_index if selected_index >= 0 else 0


func _configure_platform_options() -> void:
	# The platform flag and the offer are separate questions: the platform one
	# is what the "mobile" copy below is about, while the offer also honours a
	# manifest that declares the game single-player only.
	var platform_multiplayer_available := GameSession.multiplayer_available()
	_single_player_available = true
	_multiplayer_available = GameSession.multiplayer_offered()

	# A gated game may have unlocked only some of its modes.
	var unlocked_modes := AchievementManager.game_unlocked_modes(
		GameCatalog.current_id()
	)
	var mode_gated := not unlocked_modes.is_empty()
	if mode_gated:
		_single_player_available = unlocked_modes.has(MODE_SINGLE_PLAYER)
		_multiplayer_available = (
			_multiplayer_available
			and unlocked_modes.has(MODE_MULTIPLAYER)
		)

	_single_player_card.visible = _single_player_available
	_multiplayer_card.visible = _multiplayer_available
	_select_default_mode()

	if mode_gated:
		_update_gated_availability_copy(
			platform_multiplayer_available,
			unlocked_modes
		)
		return
	if platform_multiplayer_available:
		return
	_selection_intro.text = "Mobile play is available in single-player mode."
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


func _select_default_mode() -> void:
	if _single_player_available:
		_pending_mode = GameSession.GameMode.SINGLE_PLAYER
		first_focus = _single_player_button
	elif _multiplayer_available:
		_pending_mode = GameSession.GameMode.MULTIPLAYER
		first_focus = _multiplayer_button
	else:
		first_focus = _back_button


func _update_gated_availability_copy(
	platform_multiplayer_available: bool,
	unlocked_modes: PackedStringArray
) -> void:
	var manifest := GameCatalog.current()
	if _single_player_available and _multiplayer_available:
		_selection_intro.text = manifest.text(
			"mode_select_intro", "Choose how many players are taking part."
		) if manifest else "Choose how many players are taking part."
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
	_single_player_description.text = manifest.text(
		"single_player_description", _single_player_description.text
	)
	_multiplayer_description.text = manifest.text(
		"multiplayer_description", _multiplayer_description.text
	)
	_player_one_control_description.text = manifest.text(
		"player_one_control_description", _player_one_control_description.text
	)


func _update_control_copy() -> void:
	var gamepad := GameSession.gamepad_connected()
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
		if Settings.one_button_triangle_rush_enabled()
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


func _target_pad_copy() -> String:
	return (
		"any mapped button (%s)" % Settings.controller_target_summary(", ")
		if Settings.one_button_triangle_rush_enabled()
		else "buttons %s" % Settings.controller_target_summary(", ")
	)


func _selected_cpu_difficulty() -> int:
	return _cpu_difficulty.get_selected_id()


## Marks the armed opponent with a tick and spells the choice out underneath, so
## the selection never rests on the pressed-button styling alone.
func _update_opponent_options() -> void:
	var cpu_selected := _cpu_option_button.button_pressed
	_human_option_button.text = (
		"A Second Player" if cpu_selected else "✔  A Second Player"
	)
	_cpu_option_button.text = "✔  The CPU" if cpu_selected else "The CPU"
	_human_option_button.tooltip_text = (
		"Player 2 shares this device and plays with the Player 2 bindings."
	)
	_cpu_option_button.tooltip_text = (
		"Player 2 is played automatically at the difficulty chosen below."
	)
	_human_option_button.accessibility_description = _human_option_button.tooltip_text
	_cpu_option_button.accessibility_description = _cpu_option_button.tooltip_text
	_opponent_choice_hint.text = (
		"Player 2 is driven by the CPU. Pick its difficulty below."
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
	elif (
		_pending_mode == GameSession.GameMode.MULTIPLAYER
		and not _uses_direct_movement()
	):
		# Land on the armed option so the current answer is obvious before the
		# player starts arrowing between them.
		if _cpu_option_button.button_pressed:
			_cpu_option_button.grab_focus()
		else:
			_human_option_button.grab_focus()
	else:
		_confirm_button.grab_focus()


func _pending_mode_is_available() -> bool:
	return (
		_single_player_available
		if _pending_mode == GameSession.GameMode.SINGLE_PLAYER
		else _multiplayer_available
	)


func _update_stepper() -> void:
	var confirming := _step == Step.CONFIRM
	_step_one_indicator.add_theme_color_override(
		"font_color",
		StudioInfo.MUTED if confirming else StudioInfo.SKY
	)
	_step_two_indicator.add_theme_color_override(
		"font_color",
		StudioInfo.SKY if confirming else StudioInfo.SLATE
	)
	_connector.color = _with_alpha(StudioInfo.SKY, 0.8 if confirming else 0.22)


func _next_scene() -> String:
	var show_instructions := bool(Settings.get_value("game/show_instructions", true))
	return instructions_scene if show_instructions else GameCatalog.current_gameplay_scene_path()


func go_back() -> void:
	if _step == Step.CONFIRM:
		_show_step(Step.PLAYER_COUNT)
	else:
		super()


func _on_back_pressed() -> void:
	go_back()


func _with_alpha(color: Color, alpha: float) -> Color:
	var result := color
	result.a = alpha
	return result
