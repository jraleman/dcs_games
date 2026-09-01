extends SceneTree

var _failures := PackedStringArray()
var _original_visual_effects := true
var _original_reduced_motion := false


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var settings := get_root().get_node_or_null("Settings")
	var session := get_root().get_node_or_null("GameSession")
	if settings == null or session == null:
		_failures.append("Settings and GameSession autoloads are required.")
		await _finish(settings)
		return

	_original_visual_effects = bool(
		settings.call("get_value", Settings.VISUAL_EFFECTS_KEY, true)
	)
	_original_reduced_motion = bool(
		settings.call("get_value", Settings.REDUCED_MOTION_KEY, false)
	)
	settings.call("set_value", Settings.REDUCED_MOTION_KEY, false)
	settings.call("set_value", Settings.VISUAL_EFFECTS_KEY, false)
	settings.call("save")
	_expect(
		not bool(settings.call("visual_effects_enabled")),
		"The intense-effects preference must be available through Settings."
	)
	_expect_saved_preference(false)

	await _test_settings_menu(settings)
	await _test_target_feedback()
	_test_can_spin()
	await _test_chainsaw_feedback()
	await _test_target_rush(session, settings)
	await _test_slice_and_slash(session, settings)

	settings.call(
		"set_value",
		Settings.VISUAL_EFFECTS_KEY,
		_original_visual_effects
	)
	settings.call(
		"set_value",
		Settings.REDUCED_MOTION_KEY,
		_original_reduced_motion
	)
	settings.call("save")
	await _finish(settings)


func _expect_saved_preference(expected: bool) -> void:
	var config := ConfigFile.new()
	_expect(
		config.load(Settings.SAVE_PATH) == OK,
		"The intense-effects preference must be persisted to settings.cfg."
	)
	_expect(
		bool(
			config.get_value("accessibility", "visual_effects", not expected)
		) == expected,
		"The persisted intense-effects preference must match the selected value."
	)


func _test_settings_menu(settings: Node) -> void:
	var menu := _instantiate_scene("res://scenes/menus/settings_menu.tscn")
	if menu == null:
		return
	await process_frame

	var toggle := menu.get_node_or_null("%VisualEffectsToggle") as CheckButton
	var label := menu.get_node_or_null(
		"Margins/Layout/Tabs/Accessibility/Pad/List/VisualEffectsRow/Label"
	) as Label
	_expect(toggle != null, "Settings must expose an Intense visual effects toggle.")
	_expect(
		label != null and label.text == "Intense visual effects",
		"The accessibility toggle must identify the setting as intense effects."
	)
	var description := toggle.tooltip_text if toggle != null else ""
	_expect(
		description.contains("full-screen flashes")
		and description.contains("screen shake")
		and description.contains("Other animation"),
		"The accessibility copy must explain the setting's focused scope."
	)
	if toggle != null:
		_expect(
			not toggle.button_pressed,
			"The Intense visual effects toggle must reflect the stored disabled state."
		)
		toggle.button_pressed = true
		_expect(
			bool(settings.call("visual_effects_enabled")),
			"The Intense visual effects toggle must update Settings when enabled."
		)
		toggle.button_pressed = false
		_expect(
			not bool(settings.call("visual_effects_enabled")),
			"The Intense visual effects toggle must update Settings when disabled."
		)
	await _free_scene(menu)


func _test_target_feedback() -> void:
	var target := _instantiate_scene(
		"res://games/target_rush/triangle_target.tscn"
	) as TriangleTarget
	if target == null:
		return
	await process_frame

	target.configure("1", 0, Color("31556f"), Color("4da3ff"), 320.0)
	target.position = Vector2(100.0, 100.0)
	target.velocity = Vector2.RIGHT
	var start_position := target.position
	target.move_and_bounce(0.1, Rect2(Vector2.ZERO, Vector2(400.0, 400.0)))
	target.call("_process", 0.05)
	target.play_wrong()

	_expect(
		not target.position.is_equal_approx(start_position),
		"Disabling intense effects must keep target movement enabled."
	)
	_expect(
		(target.get_node("%Trail") as Line2D).get_point_count() > 0,
		"Disabling intense effects must keep target trails enabled."
	)
	_expect(
		float(target.get("_shake_strength")) > 0.0,
		"Disabling intense effects must keep local target feedback enabled."
	)
	await _free_scene(target)


func _test_can_spin() -> void:
	var can := SliceCan.new()
	can.position = Vector2(100.0, 100.0)
	can.configure(30.0, Vector2(20.0, 0.0), 0.0, Color.WHITE, 3.0)
	can.advance(0.5, Rect2(Vector2.ZERO, Vector2(400.0, 400.0)))
	_expect(
		not is_zero_approx(can.rotation),
		"Disabling intense effects must keep falling-can spin enabled."
	)
	can.free()


func _test_chainsaw_feedback() -> void:
	var chainsaw := ChainsawCursor.new()
	get_root().add_child(chainsaw)
	await process_frame

	chainsaw.set_powered(true)
	chainsaw.trigger_cut()
	chainsaw.call("_process", 0.05)
	_expect(
		float(chainsaw.get("_impact")) > 0.0,
		"Disabling intense effects must keep chainsaw impact feedback enabled."
	)
	_expect(
		float(chainsaw.get("_chain_phase")) > 0.0,
		"Disabling intense effects must keep chainsaw animation enabled."
	)
	await _free_scene(chainsaw)


func _test_target_rush(session: Node, settings: Node) -> void:
	GameCatalog.select("target_rush")
	session.call("configure_single_player")
	var game := _instantiate_scene("res://games/target_rush/gameplay.tscn")
	if game == null:
		return
	await process_frame
	await process_frame

	(game.get_node("%RoundTimer") as Timer).stop()
	game.set("_round_active", true)
	await _clear_children(game.get_node("%WorldFX"))

	var active_targets: Array = game.get("_active_targets")
	var target := active_targets[0] as TriangleTarget
	if target == null:
		_failures.append("Target Rush must create an active Player 1 target.")
		await _free_scene(game)
		return

	var scores_before: Array = game.get("_scores")
	var score_before: int = scores_before[0]
	game.call("_attempt_target", target)

	var scores_after: Array = game.get("_scores")
	_expect(
		scores_after[0] == score_before + int(game.get("points_per_match")),
		"Target Rush must still award a point when intense effects are disabled."
	)
	_expect_hard_effects_cleared(
		game,
		"Target Rush",
		game.get_node("%Playfield") as Node2D
	)
	var world_fx := game.get_node("%WorldFX") as Node2D
	_expect(
		world_fx.get_child_count() > 0,
		"Target Rush must keep point bursts and score feedback enabled."
	)

	game.set("_ambient_time", PI / 22.0)
	game.call("_update_urgency", 0.0)
	_expect(
		(game.get_node("%TimeLabel") as Label).scale.x > 1.0,
		"Target Rush must keep urgency pulsing enabled."
	)

	var soft_effect_count := world_fx.get_child_count()
	settings.call("set_value", Settings.VISUAL_EFFECTS_KEY, true)
	game.call("_flash_screen", Color.WHITE, 0.8)
	game.call("_add_screen_shake", 20.0)
	game.call("_update_screen_shake", 0.0)
	_expect(
		(game.get_node("%ScreenFlash") as ColorRect).color.a > 0.0
		and float(game.get("_shake_strength")) > 0.0,
		"Target Rush must allow intense effects when the setting is enabled."
	)
	settings.call("set_value", Settings.VISUAL_EFFECTS_KEY, false)
	_expect_hard_effects_cleared(
		game,
		"Target Rush",
		game.get_node("%Playfield") as Node2D
	)
	_expect(
		world_fx.get_child_count() == soft_effect_count,
		"Disabling intense effects live must not remove Target Rush point feedback."
	)
	await _free_scene(game)


func _test_slice_and_slash(session: Node, settings: Node) -> void:
	GameCatalog.select("slice_and_slash")
	session.call("configure_single_player")
	var game := _instantiate_scene("res://games/slice_and_slash/slice_and_slash.tscn")
	if game == null:
		return
	await process_frame
	await process_frame

	(game.get_node("%RoundTimer") as Timer).stop()
	game.set("_round_active", false)
	game.call("_clear_cans")
	game.call("_clear_world_fx")
	await process_frame

	var chainsaws: Array = game.get("_chainsaws")
	var chainsaw := chainsaws[0] as ChainsawCursor
	if chainsaw == null:
		_failures.append("Desk-Can-Saw must create a Player 1 chainsaw.")
		await _free_scene(game)
		return
	var can := SliceCan.new()
	can.configure(30.0, Vector2.ZERO, 0.0, Color.WHITE, 2.0)
	can.position = chainsaw.position
	game.get_node("%Playfield").add_child(can)
	var cans: Array = game.get("_cans")
	cans.append(can)

	var scores_before: Array = game.get("_scores")
	var score_before: int = scores_before[0]
	game.call("_score_slice", 0, can)

	var scores_after: Array = game.get("_scores")
	_expect(
		scores_after[0] == score_before + int(game.get("points_per_can")),
		"Desk-Can-Saw must still award a point when intense effects are disabled."
	)
	_expect_hard_effects_cleared(
		game,
		"Desk-Can-Saw",
		game.get_node("%Playfield") as Node2D
	)
	var world_fx := game.get_node("%WorldFX") as Node2D
	_expect(
		world_fx.get_child_count() > 0,
		"Desk-Can-Saw must keep sparks, fragments and score feedback enabled."
	)
	_expect(
		float(chainsaw.get("_impact")) > 0.0,
		"Desk-Can-Saw must keep chainsaw impact feedback enabled after scoring."
	)

	game.set("_ambient_time", PI / 22.0)
	game.call("_update_urgency", 0.0)
	_expect(
		(game.get_node("%TimeLabel") as Label).scale.x > 1.0,
		"Desk-Can-Saw must keep urgency pulsing enabled."
	)

	var soft_effect_count := world_fx.get_child_count()
	settings.call("set_value", Settings.VISUAL_EFFECTS_KEY, true)
	game.call("_flash_screen", Color.WHITE, 0.8)
	game.call("_add_screen_shake", 20.0)
	game.call("_update_screen_shake", 0.0)
	_expect(
		(game.get_node("%ScreenFlash") as ColorRect).color.a > 0.0
		and float(game.get("_shake_strength")) > 0.0,
		"Desk-Can-Saw must allow intense effects when the setting is enabled."
	)
	settings.call("set_value", Settings.VISUAL_EFFECTS_KEY, false)
	_expect_hard_effects_cleared(
		game,
		"Desk-Can-Saw",
		game.get_node("%Playfield") as Node2D
	)
	_expect(
		world_fx.get_child_count() == soft_effect_count,
		"Disabling intense effects live must not remove Desk-Can-Saw point feedback."
	)
	await _free_scene(game)


func _expect_hard_effects_cleared(
	game: Node,
	mode_name: String,
	playfield: Node2D
) -> void:
	_expect(
		is_zero_approx((game.get_node("%ScreenFlash") as ColorRect).color.a),
		"%s must suppress full-screen flashes." % mode_name
	)
	_expect(
		is_zero_approx(float(game.get("_shake_strength")))
		and playfield.position.is_zero_approx()
		and (game.get_node("%WorldFX") as Node2D).position.is_zero_approx(),
		"%s must suppress screen shake." % mode_name
	)


func _clear_children(node: Node) -> void:
	for child in node.get_children():
		child.queue_free()
	await process_frame


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


func _finish(settings: Node) -> void:
	if settings != null:
		settings.call(
			"set_value",
			Settings.VISUAL_EFFECTS_KEY,
			_original_visual_effects
		)
		settings.call("save")

	await create_timer(0.8).timeout
	var audio_manager := get_root().get_node_or_null("AudioManager")
	if audio_manager != null:
		for child in audio_manager.find_children("*", "AudioStreamPlayer", true, false):
			var player := child as AudioStreamPlayer
			player.stop()
			player.stream = null
	await create_timer(0.1).timeout

	if _failures.is_empty():
		print("Intense visual effects tests passed.")
		quit(0)
		return
	for failure in _failures:
		push_error(failure)
	quit(1)
