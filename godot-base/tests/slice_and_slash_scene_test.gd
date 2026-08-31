extends SceneTree

const GAME_SESSION_SCRIPT := preload("res://autoload/game_session.gd")

var _failures := PackedStringArray()


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var session := get_root().get_node_or_null("GameSession")
	var achievement_manager := get_root().get_node_or_null("AchievementManager")
	if session == null or achievement_manager == null:
		_failures.append(
			"GameSession and AchievementManager autoloads are required for scene tests."
		)
		await _finish()
		return

	var original_progress: Dictionary = achievement_manager.call(
		"slice_and_slash_progress"
	)
	await _test_slice_mode_access(session, achievement_manager)
	achievement_manager.set("_progression", _slice_progress(true, true))
	await _test_slice_mode_flow(session)
	achievement_manager.set("_progression", original_progress)
	await _test_single_player_scene(session)
	await _test_multiplayer_isolation(session)
	await _finish()


func _test_slice_mode_access(
	session: Node,
	achievement_manager: Node
) -> void:
	session.call("select_slice_and_slash")
	await _assert_slice_mode_access(
		achievement_manager,
		true,
		false,
		"solo-only unlock"
	)
	await _assert_slice_mode_access(
		achievement_manager,
		false,
		true,
		"multiplayer-only unlock"
	)
	await _assert_slice_mode_access(
		achievement_manager,
		true,
		true,
		"dual unlock"
	)


func _assert_slice_mode_access(
	achievement_manager: Node,
	single_player_unlocked: bool,
	multiplayer_unlocked: bool,
	context: String
) -> void:
	achievement_manager.set(
		"_progression",
		_slice_progress(single_player_unlocked, multiplayer_unlocked)
	)
	var menu := _instantiate_scene("res://scenes/menus/mode_select.tscn")
	if menu == null:
		return
	await process_frame

	var single_player_card := menu.get_node(
		"Margins/Layout/Stage/SelectionStep/Layout/ModeGrid/SinglePlayer"
	) as Control
	var multiplayer_card := menu.get_node("%Multiplayer") as Control
	_expect(
		single_player_card.visible == single_player_unlocked,
		"Mode selection must match single-player access for %s." % context
	)
	_expect(
		multiplayer_card.visible == multiplayer_unlocked,
		"Mode selection must match multiplayer access for %s." % context
	)

	var expected_focus := (
		menu.get_node("%SinglePlayerButton")
		if single_player_unlocked
		else menu.get_node("%MultiplayerButton")
	)
	_expect(
		menu.get("first_focus") == expected_focus,
		"Mode selection must focus an available choice for %s." % context
	)

	var confirm_step := menu.get_node("%ConfirmStep") as Control
	if not single_player_unlocked:
		menu.call("_on_single_player_pressed")
		await process_frame
		_expect(
			not confirm_step.visible,
			"A hidden single-player mode must not be activatable for %s." % context
		)
	if not multiplayer_unlocked:
		menu.call("_on_multiplayer_pressed")
		await process_frame
		_expect(
			not confirm_step.visible,
			"A hidden multiplayer mode must not be activatable for %s." % context
		)

	if single_player_unlocked:
		menu.call("_on_single_player_pressed")
	else:
		menu.call("_on_multiplayer_pressed")
	await process_frame
	_expect(
		confirm_step.visible,
		"An unlocked mode must remain activatable for %s." % context
	)
	await _free_scene(menu)


func _test_slice_mode_flow(session: Node) -> void:
	session.call("select_slice_and_slash")
	session.call("configure_single_player")

	var menu := _instantiate_scene("res://scenes/menus/mode_select.tscn")
	if menu == null:
		return
	await process_frame
	var title := menu.get_node("Margins/Layout/Header/Title") as Label
	_expect(
		title.text == GameInfo.DESK_CAN_SAW_TITLE,
		"The unlocked menu flow must identify Desk-Can-Saw."
	)
	menu.call("_on_multiplayer_pressed")
	await process_frame
	var selector := menu.get_node("%OpponentSelector") as Control
	var confirm := menu.get_node("%ConfirmButton") as Button
	_expect(
		not selector.visible,
		"Desk-Can-Saw multiplayer must stay local instead of offering a CPU."
	)
	_expect(
		confirm.text.contains("Local Desk-Can-Saw"),
		"The multiplayer confirmation must launch the local slicing mode."
	)
	await _free_scene(menu)

	session.call(
		"configure_multiplayer",
		GAME_SESSION_SCRIPT.PlayerTwoController.HUMAN,
		GAME_SESSION_SCRIPT.CpuDifficulty.MEDIUM
	)
	var instructions := _instantiate_scene("res://scenes/menus/instructions.tscn")
	if instructions == null:
		return
	await process_frame
	var player_one_copy := instructions.get_node("%PlayerOneControls") as Label
	var player_two_copy := instructions.get_node("%OpponentControls") as Label
	_expect(
		player_one_copy.text.contains("mouse"),
		"Multiplayer instructions must advertise Player 1 mouse input."
	)
	_expect(
		player_two_copy.text.contains("arrow keys"),
		"Multiplayer instructions must advertise Player 2 arrow-key input."
	)
	await _free_scene(instructions)


func _slice_progress(
	single_player_unlocked: bool,
	multiplayer_unlocked: bool
) -> Dictionary:
	return SliceUnlockRules.normalized_state({
		SliceUnlockRules.SOLO_QUALIFIED_KEY: single_player_unlocked,
		SliceUnlockRules.MULTIPLAYER_QUALIFIED_KEY: multiplayer_unlocked,
	})


func _test_single_player_scene(session: Node) -> void:
	session.call("select_slice_and_slash")
	session.call("configure_single_player")
	var game := _instantiate_scene("res://scenes/game/slice_and_slash.tscn")
	if game == null:
		return
	await process_frame
	await process_frame

	game.call("open_pause_menu")
	await process_frame
	_expect(paused, "Opening the slicing pause menu must pause the round.")
	var pause_menu := game.get("_pause_menu") as Node
	if pause_menu != null:
		var pause_event := InputEventAction.new()
		pause_event.action = &"pause"
		pause_event.pressed = true
		pause_menu.call("_input", pause_event)
		await process_frame
		_expect(
			not paused,
			"The configured pause action must resume the slicing round."
		)

		game.call("open_pause_menu")
		await process_frame
		pause_menu = game.get("_pause_menu") as Node
		pause_menu.call("_on_settings_pressed")
		await process_frame
		var settings_overlay := pause_menu.get("_settings_overlay") as Control
		_expect(
			settings_overlay != null
			and settings_overlay.z_index == (pause_menu as Control).z_index,
			"Nested pause settings must stay above gameplay captions."
		)
		pause_menu.call("_input", pause_event)
		await process_frame
		_expect(
			paused and pause_menu.get("_settings_overlay") == null,
			"Pause must close nested settings before it resumes gameplay."
		)
		pause_menu.call("_input", pause_event)
		await process_frame
		_expect(
			not paused,
			"A second pause press must resume after nested settings close."
		)
	else:
		_failures.append("The slicing pause menu did not instantiate.")
		paused = false

	var timer := game.get_node("%RoundTimer") as Timer
	timer.stop()
	game.set("_round_active", false)
	game.call("_clear_cans")
	game.set("_scores", [0, 0])

	var chainsaws: Array = game.get("_chainsaws")
	var player_one := chainsaws[0] as ChainsawCursor
	var motor_player := player_one.get("_motor_player") as AudioStreamPlayer
	var motor_stream: AudioStreamWAV
	if motor_player != null:
		motor_stream = motor_player.stream as AudioStreamWAV
	_expect(
		motor_stream != null
		and motor_stream.loop_mode == AudioStreamWAV.LOOP_FORWARD,
		"Desk-Can-Saw must synthesize a looping electric chainsaw motor."
	)
	game.call("_move_player_one_to", Vector2(-500.0, -500.0))
	var bounds: Rect2 = game.call("_play_bounds")
	_expect(
		player_one.collision_rect().position.x >= bounds.position.x - 0.01,
		"Player 1's chainsaw must stay inside the left playfield boundary."
	)
	_expect(
		player_one.collision_rect().position.y >= bounds.position.y - 0.01,
		"Player 1's chainsaw must stay inside the top playfield boundary."
	)

	var can := SliceCan.new()
	can.configure(30.0, Vector2.ZERO, 0.0, Color.WHITE, 0.0)
	can.position = player_one.position
	game.get_node("%Targets").add_child(can)
	var cans: Array = game.get("_cans")
	cans.append(can)
	game.set("_round_active", true)
	game.call("_update_cans", 0.0)
	var scores: Array = game.get("_scores")
	_expect(scores[0] == 1, "Slicing an intersecting can must award one point.")
	game.call("_update_cans", 0.0)
	scores = game.get("_scores")
	_expect(scores[0] == 1, "The same can must never award a second point.")

	game.call("_on_round_timer_timeout")
	var round_over := game.get_node("%RoundOver") as Control
	_expect(round_over.visible, "Round completion must show the existing results UI.")
	await _free_scene(game)


func _test_multiplayer_isolation(session: Node) -> void:
	session.call("select_slice_and_slash")
	session.call(
		"configure_multiplayer",
		GAME_SESSION_SCRIPT.PlayerTwoController.HUMAN,
		GAME_SESSION_SCRIPT.CpuDifficulty.MEDIUM
	)
	var game := _instantiate_scene("res://scenes/game/slice_and_slash.tscn")
	if game == null:
		return
	await process_frame
	await process_frame
	(game.get_node("%RoundTimer") as Timer).stop()
	game.set("_round_active", false)

	var chainsaws: Array = game.get("_chainsaws")
	var player_one := chainsaws[0] as ChainsawCursor
	var player_two := chainsaws[1] as ChainsawCursor
	_expect(
		player_one != null and player_two != null,
		"Local multiplayer must create one chainsaw for each player."
	)
	if player_one != null and player_two != null:
		var player_two_position := player_two.position
		game.call("_move_player_one_to", Vector2(900.0, 500.0))
		_expect(
			player_two.position.is_equal_approx(player_two_position),
			"Player 1 mouse input must not move Player 2's chainsaw."
		)
	await _free_scene(game)


func _instantiate_scene(path: String) -> Node:
	var packed := load(path) as PackedScene
	if packed == null:
		_failures.append("Could not load %s." % path)
		return null
	var instance := packed.instantiate()
	get_root().add_child(instance)
	return instance


func _free_scene(scene: Node) -> void:
	scene.queue_free()
	await process_frame


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)


func _finish() -> void:
	await create_timer(0.6).timeout
	var audio_manager := get_root().get_node_or_null("AudioManager")
	if audio_manager != null:
		for child in audio_manager.find_children("*", "AudioStreamPlayer", true, false):
			var player := child as AudioStreamPlayer
			player.stop()
			player.stream = null
	await create_timer(0.1).timeout

	if _failures.is_empty():
		print("Desk-Can-Saw scene tests passed.")
		quit(0)
		return
	for failure in _failures:
		push_error(failure)
	quit(1)
