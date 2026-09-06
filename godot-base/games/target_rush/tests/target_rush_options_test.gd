extends SceneTree

## Regression checks for the base-game (Target Rush) triangle options exposed
## under Settings → Game, and for the Handicap tab that owns the next-round
## assists.

var _failures := PackedStringArray()
var _original_values: Dictionary = {}


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var settings := get_root().get_node_or_null("Settings")
	var session := get_root().get_node_or_null("GameSession")
	if settings == null or session == null:
		_failures.append("Settings and GameSession autoloads are required.")
		await _finish(settings)
		return

	_test_defaults()
	var values := _test_values()
	for key: String in values:
		_original_values[key] = settings.call("get_value", key)
		settings.call("set_value", key, values[key])
	settings.call("save")

	_test_settings_helpers(settings)
	_test_persistence(values)
	await _test_target_size_range()
	await _test_settings_menu(settings)
	await _test_target_rush(session, settings)
	await _finish(settings)


## Neutral assists keep the expected values below tied to the game options.
func _test_values() -> Dictionary:
	return {
		TargetRushOptions.SIZE_KEY: 1.2,
		TargetRushOptions.SPEED_KEY: 1.5,
		TargetRushOptions.SPEED_RUSH_KEY: 0.5,
		TargetRushOptions.ROUND_LENGTH_KEY: 45.0,
		Settings.GAMEPLAY_SPEED_KEY: 1.0,
		Settings.TARGET_SIZE_KEY: 1.0,
		Settings.EXTRA_ROUND_TIME_KEY: 0.0,
	}


func _test_defaults() -> void:
	_expect_approx(
		TargetRushOptions.DEFAULT_SIZE,
		1.5,
		"Triangles must default to their designed size."
	)
	_expect_approx(
		TargetRushOptions.DEFAULT_SPEED,
		0.5,
		"Triangles must default to their designed speed."
	)
	_expect_approx(
		TargetRushOptions.DEFAULT_SPEED_RUSH,
		0.35,
		"The final-stretch speed rush must default to the designed boost."
	)
	_expect_approx(
		TargetRushOptions.DEFAULT_ROUND_LENGTH,
		30.0,
		"Target Rush rounds must default to 30 seconds."
	)


func _test_settings_helpers(settings: Node) -> void:
	_expect_approx(
		float(settings.call("tunable", TargetRushOptions.SIZE_KEY)),
		1.2,
		"The triangle-size option must be available through Settings."
	)
	_expect_approx(
		float(settings.call("tunable", TargetRushOptions.SPEED_KEY)),
		1.5,
		"The triangle-speed option must be available through Settings."
	)
	_expect_approx(
		float(settings.call("tunable", TargetRushOptions.SPEED_RUSH_KEY)),
		0.5,
		"The final-stretch speed rush must be available through Settings."
	)
	_expect_approx(
		float(settings.call("tunable", TargetRushOptions.ROUND_LENGTH_KEY)),
		45.0,
		"The round-length option must be available through Settings."
	)

	settings.call("set_value", TargetRushOptions.SPEED_KEY, 9.0)
	_expect_approx(
		float(settings.call("tunable", TargetRushOptions.SPEED_KEY)),
		TargetRushOptions.MAX_SPEED,
		"Out-of-range triangle speeds must be clamped."
	)
	settings.call("set_value", TargetRushOptions.SIZE_KEY, 0.0)
	_expect_approx(
		float(settings.call("tunable", TargetRushOptions.SIZE_KEY)),
		TargetRushOptions.MIN_SIZE,
		"Out-of-range triangle sizes must be clamped."
	)
	settings.call("set_value", TargetRushOptions.SPEED_KEY, 1.5)
	settings.call("set_value", TargetRushOptions.SIZE_KEY, 1.2)


func _test_persistence(values: Dictionary) -> void:
	var config := ConfigFile.new()
	_expect(
		config.load(Settings.SAVE_PATH) == OK,
		"Base-game options must be persisted to settings.cfg."
	)
	for key: String in values:
		var parts := key.split("/", false, 1)
		var stored: Variant = config.get_value(parts[0], parts[1], null)
		_expect(
			stored != null and is_equal_approx(float(stored), float(values[key])),
			"The persisted value for %s must match the selected option." % key
		)


func _test_target_size_range() -> void:
	var target := _instantiate_scene(
		"res://games/target_rush/triangle_target.tscn"
	) as TriangleTarget
	if target == null:
		return
	await process_frame

	target.set_size_scale(TargetRushOptions.MIN_SIZE)
	_expect_approx(
		target.size_scale(),
		TargetRushOptions.MIN_SIZE,
		"Targets must accept the smallest selectable triangle size."
	)
	target.set_size_scale(TargetRushOptions.MAX_SIZE * Settings.MAX_TARGET_SIZE)
	_expect_approx(
		target.size_scale(),
		TargetRushOptions.MAX_SIZE * Settings.MAX_TARGET_SIZE,
		"Targets must accept the largest option and assist combination."
	)
	await _free_scene(target)


## The triangle rows are generated from the manifest, so the screen only has
## them while it is configuring Target Rush — which is what the pause menu
## tells it. Opened from the main menu there is no game and no Game tab.
func _test_settings_menu(settings: Node) -> void:
	var menu := _open_settings_menu("")
	if menu == null:
		return
	await process_frame
	_expect(
		(menu.get("_option_controls") as Dictionary).is_empty(),
		"The main menu must not offer one game's options."
	)
	await _free_scene(menu)

	menu = _open_settings_menu(TargetRushOptions.GAME_ID)
	if menu == null:
		return
	await process_frame

	var controls := menu.get("_option_controls") as Dictionary
	var value_labels := menu.get("_option_values") as Dictionary
	var size_slider := controls.get(TargetRushOptions.SIZE_KEY) as HSlider
	var speed_slider := controls.get(TargetRushOptions.SPEED_KEY) as HSlider
	var rush_slider := controls.get(TargetRushOptions.SPEED_RUSH_KEY) as HSlider
	var length_slider := controls.get(
		TargetRushOptions.ROUND_LENGTH_KEY
	) as HSlider
	var game_list := menu.get_node_or_null(
		"Margins/Layout/Tabs/Game/Pad/List/GameOptions"
	) as VBoxContainer

	if (
		size_slider == null
		or speed_slider == null
		or rush_slider == null
		or length_slider == null
		or game_list == null
	):
		_failures.append("The Game tab must expose the triangle options.")
		await _free_scene(menu)
		return

	for slider: HSlider in [size_slider, speed_slider, rush_slider, length_slider]:
		_expect(
			slider.get_parent().get_parent() == game_list,
			"Every triangle option must live on the Game tab."
		)
		_expect(
			not slider.tooltip_text.is_empty()
			and slider.accessibility_description == slider.tooltip_text,
			"Every triangle option must describe itself for assistive tech."
		)

	_expect_slider(size_slider, 1.2, "the triangle size")
	_expect_slider(speed_slider, 1.5, "the triangle speed")
	_expect_slider(rush_slider, 0.5, "the final-stretch speed rush")
	_expect_slider(length_slider, 45.0, "the round length")
	_expect_range(
		size_slider,
		TargetRushOptions.MIN_SIZE,
		TargetRushOptions.MAX_SIZE,
		"the triangle size"
	)
	_expect_range(
		speed_slider,
		TargetRushOptions.MIN_SPEED,
		TargetRushOptions.MAX_SPEED,
		"the triangle speed"
	)
	_expect_range(
		rush_slider,
		TargetRushOptions.MIN_SPEED_RUSH,
		TargetRushOptions.MAX_SPEED_RUSH,
		"the final-stretch speed rush"
	)
	_expect_range(
		length_slider,
		TargetRushOptions.MIN_ROUND_LENGTH,
		TargetRushOptions.MAX_ROUND_LENGTH,
		"the round length"
	)

	var length_value := value_labels.get(
		TargetRushOptions.ROUND_LENGTH_KEY
	) as Label
	var rush_value := value_labels.get(
		TargetRushOptions.SPEED_RUSH_KEY
	) as Label
	_expect(
		length_value != null and length_value.text == "45 sec",
		"The round-length option must read out in seconds."
	)
	_expect(
		rush_value != null and rush_value.text == "+50%",
		"The final-stretch speed rush must read out as an added percentage."
	)

	size_slider.value = 0.8
	_expect_approx(
		float(settings.call("tunable", TargetRushOptions.SIZE_KEY)),
		0.8,
		"The triangle-size slider must write through to Settings."
	)
	length_slider.value = 60.0
	_expect_approx(
		float(settings.call("tunable", TargetRushOptions.ROUND_LENGTH_KEY)),
		60.0,
		"The round-length slider must write through to Settings."
	)
	settings.call("set_value", TargetRushOptions.SIZE_KEY, 1.2)
	settings.call("set_value", TargetRushOptions.ROUND_LENGTH_KEY, 45.0)
	await process_frame
	_expect_slider(size_slider, 1.2, "external triangle-size changes")
	_expect_slider(length_slider, 45.0, "external round-length changes")
	await _free_scene(menu)


func _test_target_rush(session: Node, settings: Node) -> void:
	GameCatalog.select("target_rush")
	session.call("configure_single_player")
	var game := _instantiate_scene("res://games/target_rush/gameplay.tscn")
	if game == null:
		return
	await process_frame
	await process_frame

	var timer := game.get_node("%RoundTimer") as Timer
	timer.stop()

	_expect_approx(
		float(game.get("_round_length")),
		45.0,
		"Target Rush must use the selected round length."
	)
	_expect_approx(
		float(game.get("_active_round_duration")),
		45.0,
		"The selected round length must drive the round duration."
	)
	_expect_approx(
		float(game.get("_round_triangle_size")),
		1.2,
		"Target Rush must apply the triangle-size option."
	)
	_expect_approx(
		float(game.get("_round_triangle_speed")),
		1.5,
		"Target Rush must apply the triangle-speed option."
	)
	_expect_approx(
		float(game.get("_round_speed_rush")),
		0.5,
		"Target Rush must apply the final-stretch speed rush option."
	)
	_expect_approx(
		float(game.call("_target_size_scale")),
		1.2,
		"The triangle-size option must combine with the size assist."
	)
	_expect_approx(
		float(game.call("_target_move_speed", 1.0)),
		float(game.get("target_speed")) * 1.5,
		"The triangle-speed option must scale the configured target speed."
	)
	_expect_approx(
		float(game.call("_target_radius")),
		TriangleTarget.HIT_RADIUS * 1.2,
		"The triangle-size option must grow the hit area with the visuals."
	)

	for entry in game.get("_targets"):
		var target := entry as TriangleTarget
		_expect(
			target.scale.is_equal_approx(Vector2.ONE * 1.2),
			"Every triangle must use the selected size."
		)
		var base_speed := float(game.get("target_speed")) * 1.5
		_expect(
			target.move_speed >= base_speed - 0.001
			and target.move_speed <= base_speed * 1.5 + 0.001,
			"Every triangle must move at the selected speed plus the rush at most."
		)

	settings.call("set_value", TargetRushOptions.SIZE_KEY, 0.6)
	settings.call("set_value", TargetRushOptions.ROUND_LENGTH_KEY, 15.0)
	_expect_approx(
		float(game.get("_round_triangle_size")),
		1.2,
		"Triangle options must not resize targets mid-round."
	)
	_expect_approx(
		float(game.get("_active_round_duration")),
		45.0,
		"Triangle options must not restretch a running round."
	)

	game.call("_start_round")
	timer.stop()
	_expect_approx(
		float(game.get("_round_triangle_size")),
		0.6,
		"A new round must pick up the selected triangle size."
	)
	_expect_approx(
		float(game.get("_active_round_duration")),
		15.0,
		"A new round must pick up the selected round length."
	)
	for entry in game.get("_targets"):
		var target := entry as TriangleTarget
		_expect(
			target.scale.is_equal_approx(Vector2.ONE * 0.6),
			"A new round must resize every triangle."
		)
	await _free_scene(game)


func _expect_slider(slider: HSlider, expected: float, title: String) -> void:
	_expect(
		slider != null and is_equal_approx(slider.value, expected),
		"The Settings screen must synchronize %s." % title
	)


func _expect_range(
	slider: HSlider,
	minimum: float,
	maximum: float,
	title: String
) -> void:
	_expect(
		slider != null
		and is_equal_approx(slider.min_value, minimum)
		and is_equal_approx(slider.max_value, maximum),
		"The slider for %s must match the range Settings accepts." % title
	)


## The pause menu names the running game before the screen enters the tree,
## because `_ready` is what builds the per-game tabs.
func _open_settings_menu(game_id: String) -> Node:
	var packed := load("res://scenes/menus/settings_menu.tscn") as PackedScene
	if packed == null:
		_failures.append("Could not load the settings menu scene.")
		return null
	var menu := packed.instantiate()
	menu.set("game_context_id", game_id)
	get_root().add_child(menu)
	return menu


func _instantiate_scene(path: String) -> Node:
	var packed := load(path) as PackedScene
	if packed == null:
		_failures.append("Could not load %s." % path)
		return null
	var instance := packed.instantiate()
	if instance.get_script() == null:
		_failures.append("Scene root has no valid script: %s." % path)
		instance.queue_free()
		return null
	get_root().add_child(instance)
	return instance


func _free_scene(scene: Node) -> void:
	scene.queue_free()
	await process_frame


func _expect_approx(actual: float, expected: float, message: String) -> void:
	_expect(is_equal_approx(actual, expected), message)


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)


func _finish(settings: Node) -> void:
	if settings != null:
		for key: String in _original_values:
			settings.call("set_value", key, _original_values[key])
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
		print("Target Rush option tests passed.")
		quit(0)
		return
	for failure in _failures:
		push_error(failure)
	quit(1)
