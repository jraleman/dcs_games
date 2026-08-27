extends Node

## Runtime game configuration shared by mode selection, instructions and play.

enum GameMode { SINGLE_PLAYER, MULTIPLAYER }
enum PlayerTwoController { HUMAN, CPU }
enum CpuDifficulty { EASY, MEDIUM, HARD }
enum GameKind { TARGET_RUSH, SLICE_AND_SLASH }

const TARGET_RUSH_GAMEPLAY_SCENE := "res://scenes/game/gameplay.tscn"
const SLICE_AND_SLASH_GAMEPLAY_SCENE := "res://scenes/game/slice_and_slash.tscn"

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
var game_kind := GameKind.TARGET_RUSH
var _controller_devices: Array[int] = [-1, -1]
var _controllers_assigned := false


func select_target_rush() -> void:
	game_kind = GameKind.TARGET_RUSH


func select_slice_and_slash() -> void:
	game_kind = GameKind.SLICE_AND_SLASH


func is_slice_and_slash() -> bool:
	return game_kind == GameKind.SLICE_AND_SLASH


func game_title() -> String:
	return (
		GameInfo.DESK_CAN_SAW_TITLE
		if is_slice_and_slash()
		else GameInfo.TARGET_RUSH_TITLE
	)


func gameplay_scene_path() -> String:
	return (
		SLICE_AND_SLASH_GAMEPLAY_SCENE
		if is_slice_and_slash()
		else TARGET_RUSH_GAMEPLAY_SCENE
	)


func configure_single_player() -> void:
	game_mode = GameMode.SINGLE_PLAYER
	player_two_controller = PlayerTwoController.HUMAN
	assign_connected_controllers()


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
	assign_connected_controllers()


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


func slice_unlock_multiplayer_eligible() -> bool:
	return (
		player_two_enabled()
		and multiplayer_result_is_unlock_eligible(
			player_two_is_cpu(),
			cpu_difficulty
		)
	)


static func multiplayer_result_is_unlock_eligible(
	cpu_controlled: bool,
	difficulty: int
) -> bool:
	return not cpu_controlled or difficulty == CpuDifficulty.MEDIUM


func controller_device_for_player(player_index: int) -> int:
	ensure_controller_assignments()
	if player_index < 0 or player_index >= _controller_devices.size():
		return -1
	var device := _controller_devices[player_index]
	return device if Input.get_connected_joypads().has(device) else -1


func controller_player_index(device: int) -> int:
	ensure_controller_assignments()
	return controller_player_index_from_assignments(device, _controller_devices)


func assign_connected_controllers() -> void:
	for player_index in range(_controller_devices.size()):
		_controller_devices[player_index] = controller_device_for_player_from_devices(
			player_index,
			Input.get_connected_joypads()
		)
	_controllers_assigned = true


func ensure_controller_assignments() -> void:
	if not _controllers_assigned:
		assign_connected_controllers()


static func controller_device_for_player_from_devices(
	player_index: int,
	devices: Array[int]
) -> int:
	var ordered_devices: Array[int] = devices.duplicate()
	ordered_devices.sort()
	if player_index < 0 or player_index >= ordered_devices.size():
		return -1
	return ordered_devices[player_index]


static func controller_player_index_from_devices(
	device: int,
	devices: Array[int]
) -> int:
	var ordered_devices: Array[int] = devices.duplicate()
	ordered_devices.sort()
	return controller_player_index_from_assignments(device, ordered_devices)


static func controller_player_index_from_assignments(
	device: int,
	assignments: Array[int]
) -> int:
	var assignment := assignments.find(device)
	return assignment if assignment == 0 or assignment == 1 else -1


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
