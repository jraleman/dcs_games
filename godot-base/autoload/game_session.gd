extends Node

## Runtime session configuration shared by mode selection, instructions and
## play: how many players, who drives Player 2, and which pad belongs to whom.
##
## Which game is being played lives in [GameCatalog]; this node stays
## game-agnostic so every game reuses the same setup flow.

## Emitted when the first pad is plugged in or the last one is unplugged, so
## screens can add or drop their controller copy without polling.
signal gamepad_availability_changed(available: bool)
## Seat assignments can change even while at least one pad remains connected.
signal controller_assignments_changed

const Identity = preload("res://scripts/player_identity.gd")

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
var multiplayer_player_count := 2
var _controller_devices: Array[int] = [-1, -1]
var _controllers_assigned := false
var _gamepad_available := false
var _characters_by_game: Dictionary = {}
var _levels_by_game: Dictionary = {}


func _ready() -> void:
	_gamepad_available = gamepad_connected()
	Input.joy_connection_changed.connect(_on_joy_connection_changed)


## True while at least one gamepad is connected. Screens that describe pad
## buttons hide that copy when this is false, so a player is never told about
## a controller they do not have.
func gamepad_connected() -> bool:
	return not Input.get_connected_joypads().is_empty()


## Plugging a pad in mid-session also re-seats the per-player assignments, so
## Every declared seat keeps the correct controller without restarting the round.
func _on_joy_connection_changed(_device: int, _connected: bool) -> void:
	assign_connected_controllers()
	var available := gamepad_connected()
	if available == _gamepad_available:
		return
	_gamepad_available = available
	gamepad_availability_changed.emit(available)


## True when the selected game offers a CPU opponent at all.
func cpu_opponent_available() -> bool:
	var manifest := GameCatalog.current()
	return manifest != null and manifest.supports_cpu_opponent


## True when a second player should be offered for the selected game.
##
## This is the question the menus ask. It is deliberately narrower than
## [method multiplayer_available], which only reports whether the *platform*
## can seat two players: a game whose manifest declares
## `supports_multiplayer = false` has no two-player rules at all, so offering
## the choice would only lead to a mode it cannot honour.
func multiplayer_offered() -> bool:
	if not multiplayer_available():
		return false
	var manifest := GameCatalog.current()
	return manifest == null or manifest.supports_multiplayer


## True when a solo round is something the selected game can actually run.
##
## The mirror of [method multiplayer_offered]: a game whose rules seat two ends
## of the same rope has no solo mode to describe. It is deliberately checked
## second, because a device that cannot seat a second player leaves solo as the
## only thing left — a manifest preference cannot make a game unplayable.
func single_player_offered() -> bool:
	if not multiplayer_offered():
		return true
	var manifest := GameCatalog.current()
	return manifest == null or manifest.supports_single_player


func configure_single_player() -> void:
	game_mode = GameMode.SINGLE_PLAYER
	player_two_controller = PlayerTwoController.HUMAN
	multiplayer_player_count = 2
	assign_connected_controllers()


func configure_multiplayer(
	controller: int,
	difficulty: int = CpuDifficulty.MEDIUM,
	players: int = 2
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
	multiplayer_player_count = clampi(players, 2, maximum_local_players())
	if multiplayer_player_count != players:
		push_warning("Requested %d players; this game supports up to %d." % [
			players, maximum_local_players(),
		])
	if controller == PlayerTwoController.CPU:
		if multiplayer_player_count != 2:
			push_warning("The CPU opponent occupies a two-player session.")
			multiplayer_player_count = 2
		cpu_difficulty = _validated_cpu_difficulty(difficulty)
	assign_connected_controllers()


## The base's identity palette and the game's declared capability bound setup.
func maximum_local_players() -> int:
	var manifest := GameCatalog.current()
	return clampi(manifest.max_local_players if manifest else 2, 2, Identity.COLORS.size())


## Active seats, while retaining the existing single/multiplayer mode API.
func player_count() -> int:
	return clampi(multiplayer_player_count, 2, maximum_local_players()) \
		if player_two_enabled() else 1


## Games may use the shared setup to describe one-at-a-time local play.
func takes_turns() -> bool:
	var manifest := GameCatalog.current()
	return player_two_enabled() and manifest != null and manifest.local_multiplayer_turns


## Numbered human identity, or the existing CPU label for the second seat.
func player_name(player_index: int) -> String:
	return player_two_name() if player_index == 1 else Identity.name_for(player_index)


## A stable tint for each seat, including the green third player.
func player_color(player_index: int) -> Color:
	return Identity.color(player_index)


## Character entries remain game-owned data, never framework model paths.
func character_options() -> Array[Dictionary]:
	var manifest := GameCatalog.current()
	return manifest.characters if manifest else []


func level_options() -> Array[Dictionary]:
	var manifest := GameCatalog.current()
	return manifest.levels if manifest else []


func setup_option_is_unlocked(option: Dictionary) -> bool:
	var requirement := str(option.get("requires_achievement", ""))
	return requirement.is_empty() or AchievementManager.is_unlocked(requirement)


func setup_option_requirement(option: Dictionary) -> String:
	if setup_option_is_unlocked(option):
		return ""
	var achievement := AchievementManager.get_achievement(str(option["requires_achievement"]))
	return str(option.get("locked_description",
		"Earn %s." % str(achievement.get("title", option["requires_achievement"]))))


func selected_level() -> Dictionary:
	var options := level_options()
	if options.is_empty():
		return {}
	var game := GameCatalog.current_id()
	var selected := str(_levels_by_game.get(game, ""))
	var available: Array[Dictionary] = []
	for option in options:
		if not setup_option_is_unlocked(option):
			continue
		if str(option["id"]) == selected:
			return option.duplicate(true)
		available.append(option)
	if not selected.is_empty():
		push_warning("Previously selected level '%s' is locked or unavailable." % selected)
		_levels_by_game.erase(game)
	if available.is_empty():
		push_error("The selected game has no unlocked level.")
		return {}
	return available[0].duplicate(true)


func set_level(level_id: String) -> void:
	for option in level_options():
		if str(option["id"]) != level_id:
			continue
		if not setup_option_is_unlocked(option):
			push_warning("Level '%s' is locked. %s" % [level_id, setup_option_requirement(option)])
			return
		_levels_by_game[GameCatalog.current_id()] = level_id
		return
	push_warning("Unknown level '%s' for the selected game." % level_id)


## Returns a copy so preview widgets cannot mutate the manifest's catalogue.
func character_for_player(player_index: int) -> Dictionary:
	assert(player_index >= 0 and player_index < maximum_local_players(), "Unknown character seat.")
	var options := character_options()
	if options.is_empty():
		return {}
	var choices: Dictionary = _characters_by_game.get(GameCatalog.current_id(), {})
	var selected := str(choices.get(player_index, ""))
	var available: Array[Dictionary] = []
	for option: Dictionary in options:
		if not setup_option_is_unlocked(option):
			continue
		if str(option["id"]) == selected:
			return option.duplicate(true)
		available.append(option)
	if not selected.is_empty():
		push_warning("Previously selected character '%s' is locked or unavailable." % selected)
		choices.erase(player_index)
	if available.is_empty():
		push_error("The selected game has no unlocked character.")
		return {}
	return available[mini(player_index, available.size() - 1)].duplicate(true)


## Each player may choose any unlocked character, including another player's choice.
func set_character_for_player(player_index: int, character_id: String) -> void:
	if player_index < 0 or player_index >= maximum_local_players():
		push_warning("Unknown character seat %d." % player_index)
		return
	for option: Dictionary in character_options():
		if str(option["id"]) != character_id:
			continue
		if not setup_option_is_unlocked(option):
			push_warning("Character '%s' is locked. %s" % [
				character_id, setup_option_requirement(option),
			])
			return
		var game := GameCatalog.current_id()
		var choices: Dictionary = _characters_by_game.get(game, {})
		choices[player_index] = character_id
		_characters_by_game[game] = choices
		return
	push_warning("Unknown character '%s' for the selected game." % character_id)


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
	if takes_turns():
		return "Hot Seat (%d players)" % player_count()
	if player_count() > 2:
		return "Local Multiplayer (%d players)" % player_count()
	return "Local Multiplayer"


func player_two_name() -> String:
	return "CPU" if player_two_is_cpu() else "Player 2"


## True when the current multiplayer setup produces a result that unlock rules
## are allowed to count (a CPU opponent must be on the default difficulty).
func multiplayer_result_is_eligible() -> bool:
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
	var assignments: Array[int] = []
	var devices := Input.get_connected_joypads()
	for player_index in maximum_local_players():
		assignments.append(controller_device_for_player_from_devices(player_index, devices))
	var changed := assignments != _controller_devices or not _controllers_assigned
	_controller_devices = assignments
	_controllers_assigned = true
	if changed:
		controller_assignments_changed.emit()


func ensure_controller_assignments() -> void:
	if not _controllers_assigned or _controller_devices.size() != maximum_local_players():
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
	if device < 0:
		return -1
	var assignment := assignments.find(device)
	return assignment if assignment >= 0 else -1


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
