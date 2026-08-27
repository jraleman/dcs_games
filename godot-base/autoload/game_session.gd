extends Node

## Runtime game configuration shared by mode selection, instructions and play.

enum GameMode { SINGLE_PLAYER, MULTIPLAYER }
enum PlayerTwoController { HUMAN, CPU }

var game_mode := GameMode.SINGLE_PLAYER
var player_two_controller := PlayerTwoController.HUMAN


func configure_single_player() -> void:
	game_mode = GameMode.SINGLE_PLAYER


func configure_multiplayer(controller: int) -> void:
	if controller != PlayerTwoController.HUMAN and controller != PlayerTwoController.CPU:
		push_warning("Unknown Player 2 controller %d; using a human player." % controller)
		controller = PlayerTwoController.HUMAN
	game_mode = GameMode.MULTIPLAYER
	player_two_controller = controller


func is_single_player() -> bool:
	return game_mode == GameMode.SINGLE_PLAYER


func player_two_enabled() -> bool:
	return game_mode == GameMode.MULTIPLAYER


func player_two_is_cpu() -> bool:
	return player_two_enabled() and player_two_controller == PlayerTwoController.CPU


func mode_title() -> String:
	if is_single_player():
		return "Single Player"
	return "Multiplayer vs CPU" if player_two_is_cpu() else "Local Multiplayer"


func player_two_name() -> String:
	return "CPU" if player_two_is_cpu() else "Player 2"
