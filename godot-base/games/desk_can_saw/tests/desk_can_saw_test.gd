extends SceneTree

const GAME_SESSION_SCRIPT := preload("res://autoload/game_session.gd")
const MANIFEST_SCRIPT := preload("res://games/desk_can_saw/game.gd")

var _failures := PackedStringArray()


func _init() -> void:
	_test_manifest_is_ungated()
	_test_controller_assignment()
	_test_can_scores_once()

	if _failures.is_empty():
		print("Desk-Can-Saw tests passed.")
		quit(0)
		return

	for failure in _failures:
		push_error(failure)
	quit(1)


## Desk-Can-Saw ships with every other game rather than behind a Triangle Rush
## result, so the collection lists it from the first launch. An unlock rule
## would bring back both halves of the old gate: [method
## GameCatalog.available] would hide the game, and a half-finished
## qualification would narrow its mode selection to one route.
func _test_manifest_is_ungated() -> void:
	var manifest: GameManifest = MANIFEST_SCRIPT.manifest()
	_expect(
		not manifest.hidden_until_unlocked,
		"Desk-Can-Saw must be listed from the first launch, not hidden until earned."
	)
	_expect(
		manifest.unlock_rule == null and not manifest.has_unlock_rule(),
		"Desk-Can-Saw must declare no unlock rule."
	)
	_expect(
		manifest.progression_keys().is_empty(),
		"An ungated game has no progression flags to persist."
	)


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
