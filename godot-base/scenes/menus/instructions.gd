extends MenuScreen

@export_file("*.tscn") var gameplay_scene := "res://scenes/game/gameplay.tscn"

@onready var _margins: MarginContainer = %Margins
@onready var _mode_label: Label = %ModeLabel
@onready var _summary: Label = %Summary
@onready var _control_grid: GridContainer = %ControlGrid
@onready var _opponent_card: PanelContainer = %OpponentCard
@onready var _opponent_title: Label = %OpponentTitle
@onready var _opponent_controls: Label = %OpponentControls
@onready var _show_again: CheckButton = %ShowAgainToggle
@onready var _start_button: Button = %StartButton

var _multiplayer := false


func _ready() -> void:
	first_focus = _start_button
	margins = _margins
	_multiplayer = GameSession.player_two_enabled()
	_populate_instructions()
	_show_again.button_pressed = bool(Settings.get_value("game/show_instructions", true))
	_show_again.toggled.connect(_on_show_again_toggled)
	super()


func _on_layout_changed(size: Vector2) -> void:
	_control_grid.columns = 1 if not _multiplayer or Responsive.is_portrait(size) else 2


func _populate_instructions() -> void:
	_mode_label.text = GameSession.mode_title().to_upper()
	if GameSession.is_single_player():
		_summary.text = (
			"Only Player 1 is active. Score as many correct hits as possible "
			+ "before the timer reaches zero."
		)
		_opponent_card.hide()
	elif GameSession.player_two_is_cpu():
		_summary.text = (
			"Race the CPU for the highest score. You control the blue targets; "
			+ "the CPU controls the red targets."
		)
		_opponent_title.text = "CPU OPPONENT"
		_opponent_controls.text = (
			"The CPU plays automatically.\n"
			+ "Keep your eyes on the blue glow and beat its score."
		)
	else:
		_summary.text = (
			"Both players act at the same time. Each player must follow the glow "
			+ "on their own side."
		)
		_opponent_title.text = "PLAYER 2"
		_opponent_controls.text = (
			"Keyboard: 7, 8, 9\n"
			+ "Mouse/touch: select red triangles"
		)


func _on_show_again_toggled(pressed: bool) -> void:
	Settings.set_value("game/show_instructions", pressed)


func _on_start_pressed() -> void:
	Router.goto(gameplay_scene)


func _on_back_pressed() -> void:
	go_back()
