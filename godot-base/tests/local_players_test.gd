extends SceneTree

## Opt-in extra seats must not change legacy two-player games.

const Identity = preload("res://scripts/player_identity.gd")
var _failures := PackedStringArray()


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var session := get_root().get_node("GameSession")
	var settings := get_root().get_node("Settings")
	var game := GameCatalog.current()
	var saved := {
		"max_local_players": game.max_local_players,
		"supports_multiplayer": game.supports_multiplayer,
		"local_multiplayer_turns": game.local_multiplayer_turns,
		"characters": game.characters, "levels": game.levels,
		"character_preview_scene_path": game.character_preview_scene_path,
		"control_style": game.control_style, "control_bindings": game.control_bindings,
	}
	game.max_local_players = 2
	session.call("configure_single_player")
	_expect(session.call("player_count") == 1, "Solo must still have one active seat.")
	session.call("configure_multiplayer", 0)
	_expect(session.call("player_count") == 2, "The existing multiplayer call must still seat two.")
	game.max_local_players = 3
	game.supports_multiplayer = true
	game.local_multiplayer_turns = true
	game.character_preview_scene_path = ""
	game.characters = [
		{"id": "alpha", "title": "Alpha"}, {"id": "beta", "title": "Beta"},
		{"id": "gamma", "title": "Gamma"},
	]
	session.call("configure_multiplayer", 0, 1, 3)
	_expect(session.call("player_count") == 3 and session.call("takes_turns"),
		"A declared three-seat turn-based game must retain its selected count.")
	_expect(session.call("player_color", 2) == Color("55c47a")
		and session.call("player_name", 2) == "Player 3", "P3 must be numbered and green.")
	session.call("set_character_for_player", 0, "beta")
	session.call("set_character_for_player", 2, "beta")
	var selection: Dictionary = session.call("character_for_player", 2)
	selection["title"] = "Not a manifest mutation"
	_expect((session.call("character_for_player", 0) as Dictionary)["id"] == "beta"
		and (session.call("character_for_player", 2) as Dictionary)["title"] == "Beta",
		"Seats may choose the same character; callers cannot mutate the catalogue.")
	var assignments: Array[int] = [4, -1, 8]
	_expect(session.call("controller_player_index_from_assignments", 8, assignments) == 2
		and session.call("controller_player_index_from_assignments", -1, assignments) == -1,
		"Controller mapping must include P3 and reject the unassigned sentinel.")
	await _test_setup()
	await _test_shell()
	await _test_setup_gates()
	for key: String in saved:
		game.set(key, saved[key])
	session.call("configure_single_player")
	_expect(session.call("player_count") == 1, "Leaving extra-seat play must restore solo mode.")
	# The default action names remain available without being offered by two-seat games.
	_expect(InputMap.has_action("player_three_target_1"),
		"Opt-in target games need a registered third-player keyboard action.")
	if game.max_local_players == 2:
		for binding: Dictionary in settings.call("control_bindings_for_game", game.id):
			_expect(int(binding.get("player", -1)) < 2, "Two-seat games must not acquire P3 settings.")
	_test_target_controls()
	await create_timer(0.15).timeout
	_finish.call_deferred()


func _test_setup() -> void:
	var session := get_root().get_node("GameSession")
	var menu := (load("res://scenes/menus/mode_select.tscn") as PackedScene).instantiate()
	get_root().add_child(menu)
	await process_frame
	menu.call("_on_multiplayer_pressed")
	var count := menu.get("_player_count_choice") as OptionButton
	count.item_selected.emit(count.get_item_index(3))
	var cards: Array = menu.get("_player_setup_cards")
	_expect(cards.size() == 3 and (cards[2]["panel"] as Control).visible,
		"Confirmation must include the selected third seat.")
	_expect(count.get_selected_id() == 3, "The count selector must display the active roster size.")
	(cards[2]["picker"] as OptionButton).item_selected.emit(2)
	_expect((session.call("character_for_player", 2) as Dictionary)["id"] == "gamma",
		"The third character picker must change only the third seat.")
	count.item_selected.emit(count.get_item_index(2))
	_expect(not (cards[2]["panel"] as Control).visible,
		"Switching back to two players must hide the third setup card.")
	menu.free()
	var briefing := (load("res://scenes/menus/instructions.tscn") as PackedScene).instantiate()
	get_root().add_child(briefing)
	await process_frame
	var extra: Array = briefing.get("_extra_control_cards")
	_expect(extra.size() == 1 and (extra[0]["panel"] as Control).visible,
		"Instructions must brief every active player.")
	briefing.free()


func _test_shell() -> void:
	var shell := (load("res://scenes/game/game_shell.tscn") as PackedScene).instantiate()
	get_root().add_child(shell)
	await process_frame
	shell.set_process(false)
	(shell.get_node("%RoundTimer") as Timer).stop()
	_expect(shell.call("_active_player_indices") == [0, 1, 2]
		and (shell.get("_scores") as Array).size() == 3,
		"The shell's active indices and state buffers must include P3.")
	var ui: Array = shell.get("_player_ui")
	_expect((ui[2]["caption"] as Label).text == "PLAYER 3"
		and (ui[2]["score"] as Label).get_theme_color("font_color").is_equal_approx(Identity.color(2)),
		"P3's HUD must use its own label and green tint.")
	for field in ["caption", "result_caption", "stats_title"]:
		_expect((ui[2][field] as Label).get_theme_color("font_color").is_equal_approx(
			Identity.color(2).lightened(0.25)
		), "P3's identity captions must not inherit Player 1's blue.")
	_expect((ui[2]["card"] as Control).get_theme_stylebox("panel")
		!= (ui[0]["card"] as Control).get_theme_stylebox("panel"),
		"Extra panels must not share mutable player-one styles.")
	shell.set("_scores", [2, 5, 9])
	shell.set("_best_streaks", [1, 2, 7])
	shell.set("_lives_mode", true)
	shell.set("_starting_lives", 2)
	shell.call("_reset_round_gauge")
	shell.call("_lose_life", 2, 2)
	_expect(shell.call("_player_is_out", 2) and shell.get("_round_active"),
		"Losing P3's lives must not end a match while the other seats remain.")
	shell.call("_lose_life", 0, 2)
	shell.call("_lose_life", 1, 2)
	_expect(not shell.get("_round_active")
		and (shell.get_node("%ResultLabel") as Label).text == "PLAYER 3 WINS!",
		"Generic outcomes must consider the third player's score.")
	_expect((ui[2]["result_score"] as Label).text == "9"
		and (ui[2]["stats"]["score"] as Label).text == "9",
		"Round and detailed results must retain all three scores.")
	var share: Dictionary = shell.call("_share_payload")
	_expect(share["score_values"] == [2, 5, 9] and share["score"] == "2 - 5 - 9"
		and share["combo_value"] == 7 and share["player_count"] == 3,
		"Share data must include every score and the third player's best combo.")
	shell.call("_on_play_again_pressed")
	_expect(shell.get("_scores") == [0, 0, 0], "Replay must reset every active score.")
	shell.free()


func _test_setup_gates() -> void:
	var session := get_root().get_node("GameSession")
	var achievements := get_root().get_node("AchievementManager")
	var game := GameCatalog.current()
	var original_characters: Dictionary = (session.get("_characters_by_game") as Dictionary).duplicate(true)
	var original_levels: Dictionary = (session.get("_levels_by_game") as Dictionary).duplicate(true)
	var original_unlocks: Dictionary = (achievements.get("_unlocked") as Dictionary).duplicate(true)
	var gate := "test_local_setup_complete"
	game.levels = [
		{"id": "first", "title": "First level", "description": "Begin here."},
		{"id": "second", "title": "Second level", "requires_achievement": gate,
			"locked_description": "Complete the first level."},
	]
	game.characters = [
		{"id": "alpha", "title": "Alpha"},
		{"id": "beta", "title": "Beta", "requires_achievement": gate,
			"locked_description": "Complete the first level."},
	]
	session.set("_characters_by_game", {})
	session.set("_levels_by_game", {})
	session.call("set_level", "second")
	session.call("set_character_for_player", 2, "beta")
	_expect((session.call("selected_level") as Dictionary)["id"] == "first"
		and (session.call("character_for_player", 2) as Dictionary)["id"] == "alpha",
		"Session setters and default seats must reject locked levels and characters.")
	var menu := (load("res://scenes/menus/mode_select.tscn") as PackedScene).instantiate()
	get_root().add_child(menu)
	menu.call("_on_multiplayer_pressed")
	var picker := menu.get("_level_choice") as OptionButton
	var cards: Array = menu.get("_player_setup_cards")
	_expect(picker.item_count == 2 and picker.is_item_disabled(1)
		and (cards[0]["picker"] as OptionButton).is_item_disabled(1)
		and picker.get_popup().get_item_tooltip(1) == "Complete the first level.",
		"Locked choices must stay visible, disabled and explained.")
	(achievements.get("_unlocked") as Dictionary)[gate] = "fixture"
	achievements.emit_signal("unlocked", gate, {"id": gate})
	_expect(not picker.is_item_disabled(1)
		and not (cards[0]["picker"] as OptionButton).is_item_disabled(1),
		"An open setup screen must refresh gates when the achievement is earned.")
	picker.item_selected.emit(1)
	(cards[0]["picker"] as OptionButton).item_selected.emit(1)
	var selection: Dictionary = session.call("selected_level")
	selection["title"] = "Not a manifest mutation"
	_expect((session.call("selected_level") as Dictionary)["title"] == "Second level"
		and (session.call("character_for_player", 0) as Dictionary)["id"] == "beta",
		"Unlocked pickers must commit choices without exposing mutable manifest entries.")
	session.call("set_level", "not-a-level")
	_expect((session.call("selected_level") as Dictionary)["id"] == "second",
		"An invalid level ID must not overwrite a valid session selection.")
	(achievements.get("_unlocked") as Dictionary).erase(gate)
	_expect((session.call("selected_level") as Dictionary)["id"] == "first"
		and (session.call("character_for_player", 0) as Dictionary)["id"] == "alpha",
		"Stale selections must be revalidated against the current profile's unlocks.")
	menu.free()
	game.characters = []
	game.supports_multiplayer = false
	menu = (load("res://scenes/menus/mode_select.tscn") as PackedScene).instantiate()
	get_root().add_child(menu)
	_expect(not menu.get("_player_count_offered")
		and (menu.get("_level_choice") as Control).is_visible_in_tree()
		and menu.call("_preferred_confirm_focus") == menu.get("_level_choice"),
		"Level-only solo games must keep a focused, reachable setup choice.")
	menu.free()
	session.set("_characters_by_game", original_characters)
	session.set("_levels_by_game", original_levels)
	achievements.set("_unlocked", original_unlocks)
	await process_frame


func _test_target_controls() -> void:
	var settings := get_root().get_node("Settings")
	var original_values := (settings.get("_values") as Dictionary).duplicate(true)
	var timer := settings.get("_save_timer") as Timer
	var timer_mode := timer.process_mode
	timer.process_mode = Node.PROCESS_MODE_DISABLED
	var game := GameCatalog.current()
	var original_style := game.control_style
	var original_capacity := game.max_local_players
	var declared := settings.get("_bindings_by_game") as Dictionary
	var had_bindings := declared.has(game.id)
	var original_bindings: Variant = declared.get(game.id)
	declared.erase(game.id)
	game.control_style = GameManifest.CONTROL_STYLE_TARGETS
	game.max_local_players = 2
	settings.call("reset_controls_to_defaults", game.id)
	settings.call("set_value", "controls/player_three_target_1", KEY_4)
	settings.call("set_value", "controls/player_one_target_1", KEY_4)
	settings.call("_repair_control_values")
	_expect(settings.call("binding_keycode", "controls/player_one_target_1") == KEY_4,
		"Unused P3 defaults must not reset a legacy player's saved key bindings.")
	_expect((settings.call("control_bindings_for_game", game.id) as Array).size() == 6,
		"Legacy target games must still expose only their six keyboard actions.")
	game.max_local_players = 3
	settings.call("reset_controls_to_defaults", game.id)
	_expect((settings.call("control_bindings_for_game", game.id) as Array).size() == 9,
		"Opt-in target games must expose all nine keyboard actions.")
	settings.call("set_control_key", &"player_three_target_1", KEY_1)
	_expect(settings.call("binding_keycode", "controls/player_three_target_1") == KEY_1
		and settings.call("binding_keycode", "controls/player_one_target_1") == KEY_4,
		"Rebinding P3 must use the same conflict-swapping contract as the first two seats.")
	var key := InputEventKey.new()
	key.physical_keycode = KEY_1
	key.pressed = true
	_expect(InputMap.event_is_action(key, "player_three_target_1")
		and not InputMap.event_is_action(key, "player_one_target_1"),
		"The rebound key must reach P3's actual InputMap action, not just its Settings label.")
	game.control_style = original_style
	game.max_local_players = original_capacity
	if had_bindings:
		declared[game.id] = original_bindings
	for setting: String in original_values:
		settings.call("set_value", setting, original_values[setting])
	timer.stop()
	timer.process_mode = timer_mode


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)


func _finish() -> void:
	if _failures.is_empty():
		print("Local player scaffolding tests passed.")
	else:
		for failure in _failures:
			printerr(failure)
	quit(0 if _failures.is_empty() else 1)
