extends Node

## Runtime game configuration shared by mode selection, instructions and play.

enum GameMode { SINGLE_PLAYER, MULTIPLAYER }
enum PlayerTwoController { HUMAN, CPU }
enum CpuDifficulty { EASY, MEDIUM, HARD }

const CPU_DIFFICULTIES := [
	CpuDifficulty.EASY,
	CpuDifficulty.MEDIUM,
	CpuDifficulty.HARD,
]
const CPU_PROFILES := {
	CpuDifficulty.EASY: {
		"title": "Easy",
		"preset": "Baby seed",
		"reaction_min": 1.05,
		"reaction_max": 1.55,
		"accuracy": 0.62,
		"description": "A forgiving rival with slower reactions and frequent mistakes.",
	},
	CpuDifficulty.MEDIUM: {
		"title": "Medium",
		"preset": "Hard seed",
		"reaction_min": 0.55,
		"reaction_max": 1.05,
		"accuracy": 0.82,
		"description": "A balanced rival using the original reaction speed and accuracy.",
	},
	CpuDifficulty.HARD: {
		"title": "Hard",
		"preset": "Impossible seed",
		"reaction_min": 0.18,
		"reaction_max": 0.38,
		"accuracy": 0.98,
		"description": "A near-perfect rival that reacts almost immediately.",
	},
}

var game_mode := GameMode.SINGLE_PLAYER
var player_two_controller := PlayerTwoController.HUMAN
var cpu_difficulty := CpuDifficulty.MEDIUM


func configure_single_player() -> void:
	game_mode = GameMode.SINGLE_PLAYER
	player_two_controller = PlayerTwoController.HUMAN


func configure_multiplayer(
	controller: int,
	difficulty: int = CpuDifficulty.MEDIUM
) -> void:
	if not multiplayer_available():
		push_warning("Multiplayer is unavailable on mobile; using single player.")
		configure_single_player()
		return
	if controller != PlayerTwoController.HUMAN and controller != PlayerTwoController.CPU:
		push_warning("Unknown Player 2 controller %d; using a human player." % controller)
		controller = PlayerTwoController.HUMAN
	game_mode = GameMode.MULTIPLAYER
	player_two_controller = controller
	if controller == PlayerTwoController.CPU:
		cpu_difficulty = _validated_cpu_difficulty(difficulty)


func multiplayer_available() -> bool:
	return not OS.has_feature("mobile")


func is_single_player() -> bool:
	return not player_two_enabled()


func player_two_enabled() -> bool:
	return game_mode == GameMode.MULTIPLAYER and multiplayer_available()


func player_two_is_cpu() -> bool:
	return player_two_enabled() and player_two_controller == PlayerTwoController.CPU


func mode_title() -> String:
	if is_single_player():
		return "Single Player"
	if player_two_is_cpu():
		return "Multiplayer vs CPU (%s)" % cpu_difficulty_title()
	return "Local Multiplayer"


func player_two_name() -> String:
	return "CPU" if player_two_is_cpu() else "Player 2"


func cpu_profile(difficulty: int = -1) -> Dictionary:
	var resolved_difficulty := (
		cpu_difficulty if difficulty < 0 else _validated_cpu_difficulty(difficulty)
	)
	return CPU_PROFILES[resolved_difficulty].duplicate(true)


func cpu_difficulty_title(difficulty: int = -1) -> String:
	return str(cpu_profile(difficulty).get("title", "Medium"))


func cpu_preset_title(difficulty: int = -1) -> String:
	return str(cpu_profile(difficulty).get("preset", "Hard seed"))


func cpu_option_title(difficulty: int) -> String:
	return "%s · %s" % [cpu_difficulty_title(difficulty), cpu_preset_title(difficulty)]


func _validated_cpu_difficulty(difficulty: int) -> int:
	if CPU_PROFILES.has(difficulty):
		return difficulty
	push_warning("Unknown CPU difficulty %d; using Medium." % difficulty)
	return CpuDifficulty.MEDIUM
