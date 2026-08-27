extends MenuScreen

@export_file("*.tscn") var instructions_scene := "res://scenes/menus/instructions.tscn"
@export_file("*.tscn") var gameplay_scene := "res://scenes/game/gameplay.tscn"

@onready var _margins: MarginContainer = %Margins
@onready var _mode_grid: GridContainer = %ModeGrid
@onready var _single_player_button: Button = %SinglePlayerButton
@onready var _opponent: OptionButton = %Opponent


func _ready() -> void:
	first_focus = _single_player_button
	margins = _margins
	_populate_opponents()
	super()


func _on_layout_changed(size: Vector2) -> void:
	_mode_grid.columns = 1 if Responsive.is_portrait(size) else 2


func _populate_opponents() -> void:
	_opponent.clear()
	_opponent.add_item("Human player", GameSession.PlayerTwoController.HUMAN)
	_opponent.add_item("CPU opponent", GameSession.PlayerTwoController.CPU)
	var selected_index := _opponent.get_item_index(GameSession.player_two_controller)
	_opponent.selected = selected_index if selected_index >= 0 else 0


func _on_single_player_pressed() -> void:
	GameSession.configure_single_player()
	_continue_to_game()


func _on_multiplayer_pressed() -> void:
	GameSession.configure_multiplayer(_opponent.get_selected_id())
	_continue_to_game()


func _continue_to_game() -> void:
	Router.goto(_next_scene())


func _next_scene() -> String:
	var show_instructions := bool(Settings.get_value("game/show_instructions", true))
	return instructions_scene if show_instructions else gameplay_scene


func _on_back_pressed() -> void:
	go_back()
