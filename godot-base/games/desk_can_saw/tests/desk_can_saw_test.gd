extends SceneTree

const GAME_SESSION_SCRIPT := preload("res://autoload/game_session.gd")

var _failures := PackedStringArray()


func _init() -> void:
	_test_unlock_thresholds()
	_test_race_condition()
	_test_sticky_unlock()
	_test_progression_round_trip()
	_test_controller_assignment()
	_test_can_scores_once()

	if _failures.is_empty():
		print("Desk-Can-Saw tests passed.")
		quit(0)
		return

	for failure in _failures:
		push_error(failure)
	quit(1)


func _test_unlock_thresholds() -> void:
	var state := {}
	var outcome := DeskCanSawUnlockRules.apply_match(state, true, 24, 0, false)
	state = outcome["state"]
	_expect(
		not bool(state[DeskCanSawUnlockRules.SOLO_QUALIFIED_KEY]),
		"A solo score of 24 must not satisfy the solo unlock condition."
	)
	_expect(
		not bool(state[DeskCanSawUnlockRules.UNLOCKED_KEY]),
		"A solo score of 24 must leave Desk-Can-Saw locked."
	)

	outcome = DeskCanSawUnlockRules.apply_match(state, true, 25, 0, false)
	state = outcome["state"]
	_expect(
		bool(state[DeskCanSawUnlockRules.SOLO_QUALIFIED_KEY]),
		"A solo score of 25 must satisfy the solo unlock condition."
	)
	_expect(
		not bool(state[DeskCanSawUnlockRules.MULTIPLAYER_QUALIFIED_KEY]),
		"A solo unlock must not grant access to the multiplayer mode."
	)
	_expect(
		bool(state[DeskCanSawUnlockRules.UNLOCKED_KEY]),
		"The solo condition must unlock Desk-Can-Saw by itself."
	)
	_expect(
		bool(outcome["unlocked_now"]),
		"The qualifying solo result must report the new unlock."
	)

	var combined_outcome := DeskCanSawUnlockRules.apply_match(
		state,
		false,
		25,
		24,
		true
	)
	var combined_state: Dictionary = combined_outcome["state"]
	_expect(
		bool(combined_state[DeskCanSawUnlockRules.SOLO_QUALIFIED_KEY])
		and bool(combined_state[DeskCanSawUnlockRules.MULTIPLAYER_QUALIFIED_KEY]),
		"Completing the second condition must make both modes available."
	)
	_expect(
		not bool(combined_outcome["unlocked_now"]),
		"Completing the second condition must not re-unlock the level."
	)

	outcome = DeskCanSawUnlockRules.apply_match({}, false, 25, 24, true)
	var multiplayer_state: Dictionary = outcome["state"]
	_expect(
		bool(multiplayer_state[DeskCanSawUnlockRules.MULTIPLAYER_QUALIFIED_KEY]),
		"A qualifying Player 1 win must satisfy the multiplayer condition."
	)
	_expect(
		not bool(multiplayer_state[DeskCanSawUnlockRules.SOLO_QUALIFIED_KEY]),
		"A multiplayer unlock must not grant access to the single-player mode."
	)
	_expect(
		bool(multiplayer_state[DeskCanSawUnlockRules.UNLOCKED_KEY]),
		"The multiplayer condition must unlock Desk-Can-Saw by itself."
	)
	_expect(
		bool(outcome["unlocked_now"]),
		"The qualifying multiplayer result must report the new unlock."
	)


func _test_race_condition() -> void:
	var outcome := DeskCanSawUnlockRules.apply_match({}, false, 24, 25, true)
	var state: Dictionary = outcome["state"]
	_expect(
		not bool(state[DeskCanSawUnlockRules.MULTIPLAYER_QUALIFIED_KEY]),
		"A Player 2 win must not satisfy Player 1's unlock condition."
	)
	_expect(
		not bool(state[DeskCanSawUnlockRules.UNLOCKED_KEY]),
		"A Player 2 win must not unlock Desk-Can-Saw."
	)
	_expect(
		DeskCanSawUnlockRules.earns_race_condition(false, 24, 25),
		"A Player 2 win with 25 points must earn Race condition."
	)
	_expect(
		not DeskCanSawUnlockRules.earns_race_condition(false, 25, 25),
		"A draw must not earn Race condition."
	)


func _test_sticky_unlock() -> void:
	var unlocked_state := {
		DeskCanSawUnlockRules.SOLO_QUALIFIED_KEY: true,
		DeskCanSawUnlockRules.MULTIPLAYER_QUALIFIED_KEY: true,
		DeskCanSawUnlockRules.UNLOCKED_KEY: true,
	}
	var outcome := DeskCanSawUnlockRules.apply_match(
		unlocked_state,
		false,
		0,
		30,
		false
	)
	var state: Dictionary = outcome["state"]
	_expect(
		bool(state[DeskCanSawUnlockRules.UNLOCKED_KEY]),
		"Later results must never relock Desk-Can-Saw."
	)


func _test_progression_round_trip() -> void:
	var path := "user://desk-can-saw-progression-test.cfg"
	var saved := ConfigFile.new()
	saved.set_value(
		"progression",
		DeskCanSawUnlockRules.SOLO_QUALIFIED_KEY,
		true
	)
	_expect(saved.save(path) == OK, "Progression state must be writable.")

	var loaded := ConfigFile.new()
	_expect(loaded.load(path) == OK, "Progression state must be readable.")
	var state := DeskCanSawUnlockRules.normalized_state({
		DeskCanSawUnlockRules.SOLO_QUALIFIED_KEY: loaded.get_value(
			"progression",
			DeskCanSawUnlockRules.SOLO_QUALIFIED_KEY,
			false
		),
		DeskCanSawUnlockRules.MULTIPLAYER_QUALIFIED_KEY: loaded.get_value(
			"progression",
			DeskCanSawUnlockRules.MULTIPLAYER_QUALIFIED_KEY,
			false
		),
	})
	_expect(
		bool(state[DeskCanSawUnlockRules.UNLOCKED_KEY]),
		"A persisted solo qualification must restore the unlocked state."
	)
	var global_path := ProjectSettings.globalize_path(path)
	if FileAccess.file_exists(path):
		DirAccess.remove_absolute(global_path)


func _test_controller_assignment() -> void:
	var devices: Array[int] = [8, 3]
	_expect(
		GAME_SESSION_SCRIPT.controller_device_for_player_from_devices(0, devices) == 3,
		"The lowest connected controller device must be assigned to Player 1."
	)
	_expect(
		GAME_SESSION_SCRIPT.controller_device_for_player_from_devices(1, devices) == 8,
		"The next connected controller device must be assigned to Player 2."
	)
	_expect(
		GAME_SESSION_SCRIPT.controller_player_index_from_devices(8, devices) == 1,
		"Controller input must resolve only to its assigned player."
	)
	_expect(
		GAME_SESSION_SCRIPT.controller_player_index_from_assignments(8, [3, 8]) == 1,
		"A remaining controller must keep its Player 2 assignment after Player 1 disconnects."
	)


func _test_can_scores_once() -> void:
	var can := SliceCan.new()
	can.position = Vector2(100.0, 100.0)
	can.configure(30.0, Vector2.ZERO, 0.0, Color.WHITE, 0.0)
	var chainsaw_rect := Rect2(90.0, 90.0, 40.0, 20.0)
	_expect(can.try_slice(chainsaw_rect), "An intersecting chainsaw must slice a can.")
	_expect(
		not can.try_slice(chainsaw_rect),
		"A sliced can must reject every later scoring attempt."
	)
	can.free()


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
