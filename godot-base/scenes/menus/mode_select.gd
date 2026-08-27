extends MenuScreen

@export_file("*.tscn") var instructions_scene := "res://scenes/menus/instructions.tscn"
@export_file("*.tscn") var gameplay_scene := "res://scenes/game/gameplay.tscn"

enum Step { PLAYER_COUNT, CONFIRM }

@onready var _margins: MarginContainer = %Margins
@onready var _mode_grid: GridContainer = %ModeGrid
@onready var _controller_grid: GridContainer = %ControllerGrid
@onready var _selection_step: Control = %SelectionStep
@onready var _confirm_step: Control = %ConfirmStep
@onready var _selection_intro: Label = %Intro
@onready var _single_player_button: Button = %SinglePlayerButton
@onready var _single_player_controls: Label = %SinglePlayerControls
@onready var _multiplayer_card: PanelContainer = %Multiplayer
@onready var _multiplayer_controls: Label = %MultiplayerControls
@onready var _selection_hint: Label = %SelectionHint
@onready var _step_one_indicator: Label = %StepOneIndicator
@onready var _step_two_indicator: Label = %StepTwoIndicator
@onready var _connector: ColorRect = %Connector
@onready var _mode_eyebrow: Label = %ModeEyebrow
@onready var _confirm_title: Label = %ConfirmTitle
@onready var _confirm_description: Label = %ConfirmDescription
@onready var _opponent_control: PanelContainer = %OpponentControl
@onready var _player_one_control_keys: Label = %PlayerOneControlKeys
@onready var _opponent_control_title: Label = %OpponentControlTitle
@onready var _opponent_control_keys: Label = %OpponentControlKeys
@onready var _opponent_control_description: Label = %OpponentControlDescription
@onready var _opponent_selector: PanelContainer = %OpponentSelector
@onready var _opponent_toggle: CheckButton = %OpponentToggle
@onready var _human_option_label: Label = %HumanOptionLabel
@onready var _cpu_option_label: Label = %CpuOptionLabel
@onready var _cpu_difficulty_panel: PanelContainer = %CpuDifficultyPanel
@onready var _cpu_difficulty: OptionButton = %CpuDifficulty
@onready var _confirm_hint: Label = %ConfirmHint
@onready var _confirm_button: Button = %ConfirmButton

var _step := Step.PLAYER_COUNT
var _pending_mode := GameSession.GameMode.SINGLE_PLAYER
var _page_tween: Tween


func _ready() -> void:
	first_focus = _single_player_button
	margins = _margins
	_opponent_toggle.set_pressed_no_signal(true)
	_populate_cpu_difficulties()
	_cpu_difficulty.item_selected.connect(_on_cpu_difficulty_selected)
	_configure_platform_options()
	_update_control_copy()
	_update_stepper()
	_update_confirmation()
	super()


func _on_layout_changed(size: Vector2) -> void:
	var portrait := Responsive.is_portrait(size)
	_mode_grid.columns = 1 if portrait or not GameSession.multiplayer_available() else 2
	_controller_grid.columns = (
		1
		if portrait or _pending_mode == GameSession.GameMode.SINGLE_PLAYER
		else 2
	)


func _on_single_player_pressed() -> void:
	_pending_mode = GameSession.GameMode.SINGLE_PLAYER
	_update_confirmation()
	_show_step(Step.CONFIRM)


func _on_multiplayer_pressed() -> void:
	if not GameSession.multiplayer_available():
		return
	_pending_mode = GameSession.GameMode.MULTIPLAYER
	_opponent_toggle.set_pressed_no_signal(true)
	_update_confirmation()
	_show_step(Step.CONFIRM)


func _on_opponent_toggled(_cpu_selected: bool) -> void:
	if _pending_mode == GameSession.GameMode.MULTIPLAYER:
		_update_confirmation()


func _on_cpu_difficulty_selected(_index: int) -> void:
	if (
		_pending_mode == GameSession.GameMode.MULTIPLAYER
		and _opponent_toggle.button_pressed
	):
		_update_confirmation()


func _on_previous_pressed() -> void:
	_show_step(Step.PLAYER_COUNT)


func _on_confirm_pressed() -> void:
	if _pending_mode == GameSession.GameMode.SINGLE_PLAYER:
		GameSession.configure_single_player()
	else:
		var controller := (
			GameSession.PlayerTwoController.CPU
			if _opponent_toggle.button_pressed
			else GameSession.PlayerTwoController.HUMAN
		)
		GameSession.configure_multiplayer(controller, _selected_cpu_difficulty())
	Router.goto(_next_scene())


func _update_confirmation() -> void:
	var single_player := _pending_mode == GameSession.GameMode.SINGLE_PLAYER
	_opponent_control.visible = not single_player
	_opponent_selector.visible = not single_player
	var cpu_selected := not single_player and _opponent_toggle.button_pressed
	_cpu_difficulty_panel.visible = cpu_selected

	if single_player:
		_mode_eyebrow.text = "SINGLE PLAYER"
		_confirm_title.text = "Ready for a solo run?"
		_confirm_description.text = (
			"Only Player 1 enters the arena. Chase the blue glow and set a high score."
		)
		_confirm_hint.text = "Player 1 uses %s or Controller 1 buttons A, B and X." % (
			Settings.control_summary(0)
		)
		_confirm_button.text = "Start Single Player"
	else:
		var difficulty := _selected_cpu_difficulty()
		var profile := GameSession.cpu_profile(difficulty)
		_mode_eyebrow.text = "MULTIPLAYER"
		_confirm_title.text = "Choose Player 2"
		_confirm_description.text = (
			"Race the CPU by default, or switch to a human player using the keyboard "
			+ "or a second controller."
		)
		_opponent_control_title.text = (
			"CPU OPPONENT · %s" % GameSession.cpu_difficulty_title(difficulty).to_upper()
			if cpu_selected
			else "PLAYER 2"
		)
		_opponent_control_keys.text = (
			"AUTO · %s" % GameSession.cpu_preset_title(difficulty).to_upper()
			if cpu_selected
			else "KEYS %s · PAD 2 A B X" % Settings.control_summary(1, " · ")
		)
		_opponent_control_description.text = (
			str(profile.get("description", "The red side plays automatically."))
			if cpu_selected
			else "Follow the red glow with the Player 2 bindings."
		)
		_confirm_hint.text = (
			"%s CPU · %s" % [
				GameSession.cpu_difficulty_title(difficulty),
				GameSession.cpu_preset_title(difficulty),
			]
			if cpu_selected
			else "Player 2 uses %s or Controller 2 buttons A, B and X." % (
				Settings.control_summary(1)
			)
		)
		_confirm_button.text = "Start vs CPU" if cpu_selected else "Start Local Multiplayer"

	_update_toggle_labels()
	_on_layout_changed(viewport_size())


func _populate_cpu_difficulties() -> void:
	_cpu_difficulty.clear()
	for difficulty: int in GameSession.CPU_DIFFICULTIES:
		_cpu_difficulty.add_item(GameSession.cpu_option_title(difficulty), difficulty)
	var selected_index := _cpu_difficulty.get_item_index(GameSession.cpu_difficulty)
	_cpu_difficulty.selected = selected_index if selected_index >= 0 else 0


func _configure_platform_options() -> void:
	var multiplayer_available := GameSession.multiplayer_available()
	_multiplayer_card.visible = multiplayer_available
	if multiplayer_available:
		return
	_selection_intro.text = "Mobile play is available in single-player mode."
	_selection_hint.text = "Use touch, your remapped keys or a connected controller."


func _update_control_copy() -> void:
	var player_one_keys := Settings.control_summary(0, "  ")
	var player_two_keys := Settings.control_summary(1, "  ")
	_single_player_controls.text = "PLAYER 1 · KEYS %s · PAD A B X" % player_one_keys
	_multiplayer_controls.text = "P1 · %s / PAD 1     P2 · %s / PAD 2" % [
		player_one_keys,
		player_two_keys,
	]
	_player_one_control_keys.text = "KEYS %s · PAD 1 A B X" % (
		Settings.control_summary(0, " · ")
	)


func _selected_cpu_difficulty() -> int:
	return _cpu_difficulty.get_selected_id()


func _update_toggle_labels() -> void:
	var cpu_selected := _opponent_toggle.button_pressed
	_human_option_label.add_theme_color_override(
		"font_color",
		GameInfo.MUTED if cpu_selected else GameInfo.CREAM
	)
	_cpu_option_label.add_theme_color_override(
		"font_color",
		GameInfo.SKY if cpu_selected else GameInfo.MUTED
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
		_single_player_button.grab_focus()
	elif _pending_mode == GameSession.GameMode.MULTIPLAYER:
		_opponent_toggle.grab_focus()
	else:
		_confirm_button.grab_focus()


func _update_stepper() -> void:
	var confirming := _step == Step.CONFIRM
	_step_one_indicator.add_theme_color_override(
		"font_color",
		GameInfo.MUTED if confirming else GameInfo.SKY
	)
	_step_two_indicator.add_theme_color_override(
		"font_color",
		GameInfo.SKY if confirming else GameInfo.SLATE
	)
	_connector.color = _with_alpha(GameInfo.SKY, 0.8 if confirming else 0.22)


func _next_scene() -> String:
	var show_instructions := bool(Settings.get_value("game/show_instructions", true))
	return instructions_scene if show_instructions else gameplay_scene


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
