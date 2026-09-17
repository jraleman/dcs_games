extends SceneTree

var _failures := PackedStringArray()
var _original_values: Dictionary = {}


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var settings := get_root().get_node_or_null("Settings")
	var session := get_root().get_node_or_null("GameSession")
	var audio_manager := get_root().get_node_or_null("AudioManager")
	if settings == null or session == null or audio_manager == null:
		_failures.append(
			"Settings, GameSession and AudioManager autoloads are required."
		)
		await _finish(settings)
		return

	_test_defaults()
	var test_values := _test_values()
	for key: String in test_values:
		_original_values[key] = settings.call("get_value", key)
		settings.call("set_value", key, test_values[key])
	settings.call("save")

	_test_settings_helpers(settings)
	_test_controller_bindings(settings)
	_test_persistence()
	await _test_settings_menu(settings)
	await _test_audio_captions(settings, audio_manager)
	await _test_background_motion(settings)
	await _test_player_cues(settings, audio_manager)
	await _test_reduced_motion_menus(session)
	await _test_triangle_rush(session, settings)
	await _test_desk_can_saw(session, settings)
	await _finish(settings)


func _test_values() -> Dictionary:
	return {
		Settings.VISUAL_EFFECTS_KEY: true,
		Settings.REDUCED_MOTION_KEY: true,
		Settings.AUDIO_CAPTIONS_KEY: true,
		Settings.PLAYER_LABELS_KEY: true,
		Settings.ONE_BUTTON_TRIANGLE_RUSH_KEY: true,
		# Pinned, not inherited: the HUD copy checked below is exact, and a game
		# whose manifest declares default_lives_mode would otherwise append its
		# lives note on a profile that has never chosen a round mode. Lives-mode
		# behaviour is lives_mode_test.gd's subject, not this file's.
		Settings.ROUND_MODE_KEY: Settings.RoundMode.TIMER,
		Settings.GAMEPLAY_SPEED_KEY: 0.7,
		Settings.TARGET_SIZE_KEY: 1.3,
		Settings.EXTRA_ROUND_TIME_KEY: 15.0,
		Settings.CONTROLLER_SPEED_KEY: 0.75,
		Settings.CONTROLLER_DEADZONE_KEY: 0.3,
		Settings.CONTROLLER_TARGET_KEYS[0]: JOY_BUTTON_Y,
		Settings.CONTROLLER_TARGET_KEYS[1]: JOY_BUTTON_LEFT_SHOULDER,
		Settings.CONTROLLER_TARGET_KEYS[2]: JOY_BUTTON_RIGHT_SHOULDER,
		Settings.CONTROLLER_PAUSE_KEY: JOY_BUTTON_BACK,
		Settings.CONTROLLER_MOVEMENT_SCHEME_KEY: (
			Settings.ControllerMovementScheme.RIGHT_STICK_ONLY
		),
	}


func _test_defaults() -> void:
	_expect(
		not bool(Settings.DEFAULTS[Settings.REDUCED_MOTION_KEY]),
		"Reduced motion must remain opt-in by default."
	)
	_expect(
		not bool(Settings.DEFAULTS[Settings.AUDIO_CAPTIONS_KEY]),
		"Audio captions must remain opt-in by default."
	)
	_expect(
		int(Settings.DEFAULTS[Settings.CONTROLLER_TARGET_KEYS[0]]) == JOY_BUTTON_A
		and int(Settings.DEFAULTS[Settings.CONTROLLER_TARGET_KEYS[1]]) == JOY_BUTTON_B
		and int(Settings.DEFAULTS[Settings.CONTROLLER_TARGET_KEYS[2]]) == JOY_BUTTON_X,
		"Controller target controls must retain A, B and X as their defaults."
	)
	_expect(
		int(Settings.DEFAULTS[Settings.CONTROLLER_PAUSE_KEY]) == JOY_BUTTON_START,
		"Controller pause must retain Start as its default."
	)
	_expect(
		int(Settings.DEFAULTS[Settings.CONTROLLER_MOVEMENT_SCHEME_KEY])
		== Settings.ControllerMovementScheme.LEFT_STICK_AND_DPAD,
		"Desk-Can-Saw must default to left-stick and D-pad movement."
	)


func _test_settings_helpers(settings: Node) -> void:
	_expect(
		bool(settings.call("reduced_motion_enabled")),
		"Reduced motion must be available through Settings."
	)
	_expect(
		bool(settings.call("audio_captions_enabled")),
		"Audio captions must be available through Settings."
	)
	_expect(
		bool(settings.call("player_labels_enabled")),
		"Player identity labels must be available through Settings."
	)
	_expect(
		bool(settings.call("one_button_triangle_rush_enabled")),
		"One-button Triangle Rush must be available through Settings."
	)
	_expect_approx(
		float(settings.call("gameplay_speed_scale")),
		0.7,
		"The gameplay-speed assist must be available through Settings."
	)
	_expect_approx(
		float(settings.call("target_size_scale")),
		1.3,
		"The target-size assist must be available through Settings."
	)
	_expect_approx(
		float(settings.call("extra_round_time")),
		15.0,
		"The extra-time assist must be available through Settings."
	)
	_expect_approx(
		float(settings.call("controller_movement_scale")),
		0.75,
		"The controller-speed assist must be available through Settings."
	)
	_expect_approx(
		float(settings.call("controller_deadzone")),
		0.3,
		"The controller deadzone must be available through Settings."
	)
	_expect(
		int(settings.call("controller_target_button", 0)) == JOY_BUTTON_Y
		and int(settings.call("controller_target_button", 1))
		== JOY_BUTTON_LEFT_SHOULDER
		and int(settings.call("controller_target_button", 2))
		== JOY_BUTTON_RIGHT_SHOULDER,
		"Controller target mappings must be available through Settings."
	)
	_expect(
		int(settings.call("controller_target_index", JOY_BUTTON_RIGHT_SHOULDER)) == 2,
		"Controller button routing must resolve the configured target index."
	)
	_expect(
		str(settings.call("controller_target_summary", " / ")) == "Y / LB / RB",
		"Controller mapping summaries must use readable button labels."
	)
	_expect(
		int(settings.call("controller_pause_button")) == JOY_BUTTON_BACK,
		"The remapped pause button must be available through Settings."
	)
	_expect(
		bool(settings.call("controller_uses_right_stick"))
		and not bool(settings.call("controller_dpad_enabled"))
		and str(settings.call("controller_movement_scheme_label")) == "Right stick only",
		"The selected Desk-Can-Saw movement scheme must drive its helper methods."
	)


func _test_controller_bindings(settings: Node) -> void:
	_expect(
		bool(
			settings.call(
				"set_controller_button",
				Settings.CONTROLLER_TARGET_KEYS[0],
				JOY_BUTTON_LEFT_SHOULDER
			)
		),
		"A valid controller target button must be assignable."
	)
	_expect(
		int(settings.call("controller_target_button", 0))
		== JOY_BUTTON_LEFT_SHOULDER
		and int(settings.call("controller_target_button", 1)) == JOY_BUTTON_Y,
		"Assigning an occupied target button must swap the two mappings."
	)
	settings.call(
		"set_controller_button",
		Settings.CONTROLLER_TARGET_KEYS[0],
		JOY_BUTTON_Y
	)

	settings.call(
		"set_controller_button",
		Settings.CONTROLLER_TARGET_KEYS[0],
		JOY_BUTTON_BACK
	)
	_expect(
		int(settings.call("controller_target_button", 0)) == JOY_BUTTON_BACK
		and int(settings.call("controller_pause_button")) == JOY_BUTTON_Y,
		"Target and pause mappings must also swap when they conflict."
	)
	_expect_pause_binding(JOY_BUTTON_Y)
	settings.call(
		"set_controller_button",
		Settings.CONTROLLER_TARGET_KEYS[0],
		JOY_BUTTON_Y
	)
	_expect_pause_binding(JOY_BUTTON_BACK)
	_expect(
		not bool(
			settings.call(
				"set_controller_button",
				Settings.CONTROLLER_PAUSE_KEY,
				JOY_BUTTON_DPAD_UP
			)
		),
		"Pause must reject D-pad buttons reserved for optional movement."
	)

	var previous_button := int(settings.call("controller_target_button", 0))
	_expect(
		not bool(
			settings.call(
				"set_controller_button",
				Settings.CONTROLLER_TARGET_KEYS[0],
				999
			)
		)
		and int(settings.call("controller_target_button", 0)) == previous_button,
		"Unsupported controller buttons must be rejected without changing a mapping."
	)

	settings.call(
		"set_value",
		Settings.CONTROLLER_TARGET_KEYS[1],
		settings.call("controller_target_button", 0)
	)
	settings.call(
		"set_value",
		Settings.CONTROLLER_MOVEMENT_SCHEME_KEY,
		999
	)
	settings.call(
		"set_value",
		Settings.CONTROLLER_PAUSE_KEY,
		JOY_BUTTON_DPAD_UP
	)
	_expect(
		bool(settings.call("_repair_control_values")),
		"Invalid or duplicate controller settings must be repaired on load."
	)
	_expect(
		int(settings.call("controller_target_button", 0)) == JOY_BUTTON_A
		and int(settings.call("controller_target_button", 1)) == JOY_BUTTON_B
		and int(settings.call("controller_target_button", 2)) == JOY_BUTTON_X
		and int(settings.call("controller_pause_button")) == JOY_BUTTON_START,
		"Controller binding repair must restore the complete default layout."
	)
	_expect(
		int(settings.call("controller_movement_scheme"))
		== Settings.ControllerMovementScheme.LEFT_STICK_AND_DPAD,
		"Controller movement repair must restore the default movement scheme."
	)

	for key: String in [
		Settings.CONTROLLER_TARGET_KEYS[0],
		Settings.CONTROLLER_TARGET_KEYS[1],
		Settings.CONTROLLER_TARGET_KEYS[2],
		Settings.CONTROLLER_PAUSE_KEY,
		Settings.CONTROLLER_MOVEMENT_SCHEME_KEY,
	]:
		settings.call("set_value", key, _test_values()[key])
	settings.call("apply_controls")
	settings.call("save")
	_expect_pause_binding(JOY_BUTTON_BACK)


func _expect_pause_binding(expected_button: int) -> void:
	var escape_retained := false
	var joypad_buttons: Array[int] = []
	for event: InputEvent in InputMap.action_get_events(&"pause"):
		if event is InputEventKey:
			var key_event := event as InputEventKey
			escape_retained = escape_retained or (
				key_event.physical_keycode == KEY_ESCAPE
				or key_event.keycode == KEY_ESCAPE
			)
		elif event is InputEventJoypadButton:
			joypad_buttons.append(
				(event as InputEventJoypadButton).button_index
			)
	_expect(
		escape_retained,
		"Remapping controller pause must preserve the Escape binding."
	)
	_expect(
		joypad_buttons == [expected_button],
		"Pause must contain exactly the configured controller button."
	)


func _test_persistence() -> void:
	var config := ConfigFile.new()
	_expect(
		config.load(Settings.SAVE_PATH) == OK,
		"Accessibility assists must be persisted to settings.cfg."
	)
	for key: String in _test_values():
		var parts := key.split("/", false, 1)
		var expected: Variant = _test_values()[key]
		var stored: Variant = config.get_value(parts[0], parts[1], null)
		_expect(
			stored == expected,
			"The persisted value for %s must match the selected assist." % key
		)


## Headless runs expose no joypads, so every controller row must stay hidden and
## the explanatory note must stand in for the section.
func _assert_gamepad_rows_hidden(menu: Node) -> void:
	for control_path: String in [
		"%ControllerMovementScheme",
		"%ControllerSpeedSlider",
		"%ControllerDeadzoneSlider",
		"%ControllerTargetOne",
		"%ControllerTargetTwo",
		"%ControllerTargetThree",
		"%ControllerPause",
	]:
		var control := menu.get_node_or_null(control_path) as Control
		_expect(
			control != null and not control.get_parent().visible,
			"%s must stay hidden until a controller is connected." % control_path
		)
	var controller_hint := menu.get_node_or_null("%ControllerHint") as Label
	_expect(
		controller_hint != null
		and controller_hint.visible
		and not controller_hint.text.is_empty(),
		"Settings must explain the missing controller section instead of hiding it."
	)


func _test_settings_menu(settings: Node) -> void:
	var menu := _instantiate_scene("res://scenes/menus/settings_menu.tscn")
	if menu == null:
		return
	await process_frame

	var reduced_motion := menu.get_node_or_null("%ReducedMotionToggle") as CheckButton
	var audio_captions := menu.get_node_or_null("%AudioCaptionsToggle") as CheckButton
	var player_labels := menu.get_node_or_null("%PlayerLabelsToggle") as CheckButton
	var one_button := menu.get_node_or_null(
		"%OneButtonTriangleRushToggle"
	) as CheckButton
	var gameplay_speed := menu.get_node_or_null("%GameplaySpeedSlider") as HSlider
	var target_size := menu.get_node_or_null("%TargetSizeSlider") as HSlider
	var extra_time := menu.get_node_or_null("%ExtraRoundTimeSlider") as HSlider
	var controller_speed := menu.get_node_or_null("%ControllerSpeedSlider") as HSlider
	var controller_deadzone := menu.get_node_or_null(
		"%ControllerDeadzoneSlider"
	) as HSlider
	var controller_target_one := menu.get_node_or_null(
		"%ControllerTargetOne"
	) as OptionButton
	var controller_target_two := menu.get_node_or_null(
		"%ControllerTargetTwo"
	) as OptionButton
	var controller_target_three := menu.get_node_or_null(
		"%ControllerTargetThree"
	) as OptionButton
	var controller_pause := menu.get_node_or_null(
		"%ControllerPause"
	) as OptionButton
	var movement_scheme := menu.get_node_or_null(
		"%ControllerMovementScheme"
	) as OptionButton
	var hint := menu.get_node_or_null("%Hint") as Label
	var tabs := menu.get_node_or_null("%Tabs") as TabContainer
	var gameplay_list := menu.get_node_or_null(
		"Margins/Layout/Tabs/Gameplay/Pad/List"
	) as VBoxContainer

	_expect(
		gameplay_list != null
		and gameplay_speed != null
		and target_size != null
		and extra_time != null
		and gameplay_speed.get_parent().get_parent() == gameplay_list
		and target_size.get_parent().get_parent() == gameplay_list
		and extra_time.get_parent().get_parent() == gameplay_list,
		"Next-round gameplay assists must live on their own Gameplay tab."
	)
	_expect(
		menu.find_children("Intro", "Label", true, false).is_empty()
		and menu.find_children("*Help", "Label", true, false).is_empty(),
		"Settings details must not remain as persistent paragraphs."
	)
	for control_path: String in [
		"%MasterSlider",
		"%WindowMode",
		"%ReducedMotionToggle",
		"%ShowInstructionsToggle",
	]:
		var help_control := menu.get_node_or_null(control_path) as Control
		_expect(
			help_control != null
			and not help_control.tooltip_text.is_empty()
			and help_control.accessibility_description
			== help_control.tooltip_text,
			"Each Settings tab must expose details through accessible tooltips."
		)
	_expect(
		reduced_motion != null
		and reduced_motion.get_theme_stylebox("pressed") is StyleBoxEmpty,
		"Active toggles must not inherit the filled Button pressed style."
	)
	_assert_gamepad_rows_hidden(menu)
	var toggle_focus := (
		reduced_motion.get_theme_stylebox("focus") as StyleBoxFlat
		if reduced_motion != null
		else null
	)
	_expect(
		toggle_focus != null
		and toggle_focus.bg_color.a <= 0.1
		and toggle_focus.border_width_left >= 2,
		"Toggle focus must use a restrained outline instead of a filled state."
	)
	if reduced_motion != null and hint != null and tabs != null:
		tabs.current_tab = 2
		await process_frame
		reduced_motion.grab_focus()
		await process_frame
		_expect(
			hint.text == reduced_motion.tooltip_text,
			"Focused settings must show their tooltip in the footer."
		)
		tabs.current_tab = 1
		await process_frame
		_expect(
			hint.text.contains("focus a setting for details"),
			"Changing tabs must restore the default Settings footer."
		)

	_expect(
		reduced_motion != null and reduced_motion.button_pressed,
		"The Accessibility tab must synchronize reduced motion."
	)
	_expect(
		audio_captions != null and audio_captions.button_pressed,
		"The Accessibility tab must synchronize audio captions."
	)
	_expect(
		player_labels != null and player_labels.button_pressed,
		"The Accessibility tab must synchronize the P1/P2 label setting."
	)
	_expect(
		one_button != null and one_button.button_pressed,
		"The Accessibility tab must synchronize one-button Triangle Rush."
	)
	_expect_slider(gameplay_speed, 0.7, "moving-object speed")
	_expect_slider(target_size, 1.3, "target and can size")
	_expect_slider(extra_time, 15.0, "extra round time")
	_expect_slider(controller_speed, 0.75, "controller movement speed")
	_expect_slider(controller_deadzone, 0.3, "controller deadzone")
	_expect_selected_id(
		controller_target_one,
		JOY_BUTTON_Y,
		"controller target 1"
	)
	_expect_selected_id(
		controller_target_two,
		JOY_BUTTON_LEFT_SHOULDER,
		"controller target 2"
	)
	_expect_selected_id(
		controller_target_three,
		JOY_BUTTON_RIGHT_SHOULDER,
		"controller target 3"
	)
	_expect_selected_id(controller_pause, JOY_BUTTON_BACK, "controller pause")
	_expect(
		controller_pause != null
		and controller_pause.get_item_index(JOY_BUTTON_DPAD_UP) < 0,
		"The pause selector must omit D-pad buttons used for movement."
	)
	_expect_selected_id(
		movement_scheme,
		Settings.ControllerMovementScheme.RIGHT_STICK_ONLY,
		"controller movement scheme"
	)

	if reduced_motion != null:
		reduced_motion.button_pressed = false
		_expect(
			not bool(settings.call("reduced_motion_enabled")),
			"The reduced-motion toggle must update Settings."
		)
		reduced_motion.button_pressed = true
	if audio_captions != null:
		audio_captions.button_pressed = false
		_expect(
			not bool(settings.call("audio_captions_enabled")),
			"The audio-caption toggle must update Settings."
		)
		audio_captions.button_pressed = true
	if one_button != null:
		one_button.button_pressed = false
		_expect(
			not bool(settings.call("one_button_triangle_rush_enabled")),
			"The one-button toggle must update Settings."
		)
		one_button.button_pressed = true
	if gameplay_speed != null:
		gameplay_speed.value = 0.8
		_expect_approx(
			float(settings.call("gameplay_speed_scale")),
			0.8,
			"The moving-object speed slider must update Settings."
		)
		settings.call("set_value", Settings.GAMEPLAY_SPEED_KEY, 0.7)

	if controller_target_one != null and controller_target_two != null:
		var y_index := controller_target_two.get_item_index(JOY_BUTTON_Y)
		menu.call(
			"_on_controller_button_selected",
			y_index,
			Settings.CONTROLLER_TARGET_KEYS[1]
		)
		_expect(
			int(settings.call("controller_target_button", 0))
			== JOY_BUTTON_LEFT_SHOULDER
			and int(settings.call("controller_target_button", 1)) == JOY_BUTTON_Y
			and controller_target_one.get_selected_id()
			== JOY_BUTTON_LEFT_SHOULDER
			and controller_target_two.get_selected_id() == JOY_BUTTON_Y,
			"The Controls tab must display both sides of a controller-button swap."
		)
		var shoulder_index := controller_target_two.get_item_index(
			JOY_BUTTON_LEFT_SHOULDER
		)
		menu.call(
			"_on_controller_button_selected",
			shoulder_index,
			Settings.CONTROLLER_TARGET_KEYS[1]
		)

	if movement_scheme != null:
		var left_dpad_index := movement_scheme.get_item_index(
			Settings.ControllerMovementScheme.LEFT_STICK_AND_DPAD
		)
		menu.call(
			"_on_controller_movement_scheme_selected",
			left_dpad_index
		)
		_expect(
			int(settings.call("controller_movement_scheme"))
			== Settings.ControllerMovementScheme.LEFT_STICK_AND_DPAD,
			"The movement-scheme selector must update Settings."
		)
		var right_only_index := movement_scheme.get_item_index(
			Settings.ControllerMovementScheme.RIGHT_STICK_ONLY
		)
		menu.call(
			"_on_controller_movement_scheme_selected",
			right_only_index
		)

	await _free_scene(menu)


func _expect_slider(slider: HSlider, expected: float, title: String) -> void:
	_expect(
		slider != null and is_equal_approx(slider.value, expected),
		"The Accessibility tab must synchronize %s." % title
	)


func _expect_selected_id(
	option: OptionButton,
	expected: int,
	title: String
) -> void:
	_expect(
		option != null and option.get_selected_id() == expected,
		"The Controls tab must synchronize %s." % title
	)


func _test_audio_captions(settings: Node, audio_manager: Node) -> void:
	var caption := _instantiate_scene(
		"res://ui/components/audio_caption.tscn"
	)
	if caption == null:
		return
	await process_frame

	caption.set("hold_time", 0.05)
	audio_manager.call("request_caption", "Player 1: correct target")
	_expect(
		caption.visible
		and str(caption.call("caption_text")) == "Player 1: correct target",
		"Enabled audio captions must display semantic gameplay text."
	)
	audio_manager.call("request_caption", "3 seconds remaining")
	_expect(
		caption.visible
		and str(caption.call("caption_text")) == "3 seconds remaining",
		"A new audio caption must replace the previous caption."
	)

	settings.call("set_value", Settings.AUDIO_CAPTIONS_KEY, false)
	_expect(
		not caption.visible,
		"Disabling audio captions live must clear the active caption."
	)
	audio_manager.call("request_caption", "This must stay hidden")
	_expect(
		not caption.visible,
		"Disabled audio captions must ignore new caption requests."
	)
	settings.call("set_value", Settings.AUDIO_CAPTIONS_KEY, true)
	audio_manager.call("request_caption", "Caption timeout")
	await create_timer(0.3).timeout
	_expect(
		not caption.visible,
		"Audio captions must hide after their hold and fade interval."
	)
	await _free_scene(caption)


func _test_background_motion(settings: Node) -> void:
	var background := _instantiate_scene(
		"res://ui/components/background.tscn"
	) as ColorRect
	if background == null:
		return
	await process_frame

	var material := background.material as ShaderMaterial
	_expect(
		material != null
		and is_zero_approx(float(material.get_shader_parameter("speed"))),
		"Reduced motion must freeze the shared animated background."
	)
	settings.call("set_value", Settings.REDUCED_MOTION_KEY, false)
	_expect(
		material != null
		and float(material.get_shader_parameter("speed")) > 0.0,
		"Disabling reduced motion live must restore background movement."
	)
	settings.call("set_value", Settings.REDUCED_MOTION_KEY, true)
	_expect(
		material != null
		and is_zero_approx(float(material.get_shader_parameter("speed"))),
		"Enabling reduced motion live must freeze background movement again."
	)
	await _free_scene(background)


func _test_player_cues(settings: Node, audio_manager: Node) -> void:
	var target := _instantiate_scene(
		"res://games/triangle_rush/triangle_target.tscn"
	) as TriangleTarget
	if target == null:
		return
	await process_frame

	target.configure("7", 1, Color("6b343d"), Color("ff5c6c"), 320.0)
	target.set_size_scale(1.3)
	var owner_label := target.get_node("%OwnerLabel") as Label
	_expect(
		owner_label.text == "P2" and owner_label.visible,
		"Targets must identify their player without relying on color."
	)
	_expect(
		target.scale.is_equal_approx(Vector2.ONE * 1.3),
		"The target-size assist must enlarge visuals and the hit area together."
	)
	target.position = Vector2(100.0, 100.0)
	target.velocity = Vector2.RIGHT
	var target_start := target.position
	target.move_and_bounce(
		0.1,
		Rect2(Vector2.ZERO, Vector2(500.0, 500.0))
	)
	target.set_highlighted(true)
	target.call("_process", 0.05)
	_expect(
		not target.position.is_equal_approx(target_start),
		"Reduced motion must preserve essential target movement."
	)
	_expect(
		not (target.get_node("%Trail") as Line2D).visible
		and (target.get_node("%Trail") as Line2D).get_point_count() == 0,
		"Reduced motion must hide and clear target trails."
	)
	_expect(
		(target.get_node("%Visual") as Node2D).position.is_zero_approx()
		and (target.get_node("%Body") as Node2D).rotation == 0.0,
		"Reduced motion must remove target bobbing and leaning."
	)
	target.play_wrong()
	target.play_spawn()
	_expect(
		is_zero_approx(float(target.get("_shake_strength")))
		and is_equal_approx(float(target.get("_feedback_scale")), 1.0),
		"Reduced motion must suppress target shake and scale feedback."
	)

	settings.call("set_value", Settings.REDUCED_MOTION_KEY, false)
	target.call("_process", 0.05)
	target.play_wrong()
	_expect(
		(target.get_node("%Trail") as Line2D).visible
		and (target.get_node("%Trail") as Line2D).get_point_count() > 0
		and float(target.get("_shake_strength")) > 0.0,
		"Disabling reduced motion live must restore ordinary target feedback."
	)
	settings.call("set_value", Settings.REDUCED_MOTION_KEY, true)
	_expect(
		not (target.get_node("%Trail") as Line2D).visible
		and is_zero_approx(float(target.get("_shake_strength"))),
		"Enabling reduced motion live must clear active target feedback."
	)
	target.set_player_label_visible(false)
	_expect(
		not owner_label.visible,
		"Target player labels must respect the accessibility setting."
	)
	await _free_scene(target)

	var chainsaw := ChainsawCursor.new()
	chainsaw.configure(1, Color("ff5c6c"))
	chainsaw.set_player_label_visible(true)
	get_root().add_child(chainsaw)
	await process_frame
	var chainsaw_label := chainsaw.get_node_or_null("PlayerLabel") as Label
	_expect(
		chainsaw_label != null
		and chainsaw_label.text == "P2"
		and chainsaw_label.visible,
		"Chainsaws must identify their player without relying on color."
	)
	chainsaw.set_player_label_visible(false)
	_expect(
		chainsaw_label != null and not chainsaw_label.visible,
		"Chainsaw player labels must respect the accessibility setting."
	)
	chainsaw.set_motor_stream(audio_manager.call("chainsaw_motor_stream"))
	chainsaw.set_powered(true)
	chainsaw.trigger_cut()
	chainsaw.call("_process", 0.05)
	_expect(
		is_zero_approx(float(chainsaw.get("_impact")))
		and is_zero_approx(float(chainsaw.get("_chain_phase")))
		and float(chainsaw.get("_motor_level")) > 0.0,
		"Reduced motion must freeze chainsaw visuals without disabling its motor state."
	)
	settings.call("set_value", Settings.REDUCED_MOTION_KEY, false)
	chainsaw.trigger_cut()
	chainsaw.call("_process", 0.05)
	_expect(
		float(chainsaw.get("_impact")) > 0.0
		and float(chainsaw.get("_chain_phase")) > 0.0,
		"Disabling reduced motion must restore chainsaw impact and chain animation."
	)
	settings.call("set_value", Settings.REDUCED_MOTION_KEY, true)
	await _free_scene(chainsaw)


func _test_reduced_motion_menus(session: Node) -> void:
	GameCatalog.select("triangle_rush")
	session.call("configure_single_player")
	var instructions := _instantiate_scene(
		"res://scenes/menus/instructions.tscn"
	)
	if instructions != null:
		await process_frame
		await process_frame
		_expect(
			(instructions.get_node("%Card") as Control).scale.is_equal_approx(
				Vector2.ONE
			)
			and instructions.get("_rule_tween") == null,
			"Reduced motion must make instructions static."
		)
		await _free_scene(instructions)

	var mode_select := _instantiate_scene(
		"res://scenes/menus/mode_select.tscn"
	)
	if mode_select == null:
		return
	await process_frame
	mode_select.call("_on_single_player_pressed")
	await process_frame
	var selection_step := mode_select.get_node("%SelectionStep") as Control
	var confirm_step := mode_select.get_node("%ConfirmStep") as Control
	_expect(
		not selection_step.visible
		and confirm_step.visible
		and confirm_step.scale.is_equal_approx(Vector2.ONE)
		and mode_select.get("_page_tween") == null,
		"Reduced motion must switch mode-selection steps without spatial animation."
	)
	await _test_opponent_selector(mode_select)
	await _free_scene(mode_select)


## The Player 2 selector must never rest on colour or on a switch position: the
## armed option carries a tick in its own label and a sentence spells the choice
## out, so the answer survives a greyscale screen and a screen reader.
func _test_opponent_selector(mode_select: Node) -> void:
	mode_select.call("_on_multiplayer_pressed")
	await process_frame
	var human := mode_select.get_node("%HumanOptionButton") as Button
	var cpu := mode_select.get_node("%CpuOptionButton") as Button
	var hint := mode_select.get_node("%OpponentChoiceHint") as Label
	var difficulty := mode_select.get_node("%CpuDifficultyPanel") as Control

	_expect(
		human.button_group != null and human.button_group == cpu.button_group,
		"Both Player 2 options must share a button group so one is always armed."
	)
	for state in [true, false]:
		if state:
			cpu.button_pressed = true
		else:
			human.button_pressed = true
		mode_select.call("_on_opponent_option_pressed")
		await process_frame
		var armed: Button = cpu if state else human
		var idle: Button = human if state else cpu
		_expect(
			armed.button_pressed and not idle.button_pressed,
			"Exactly one Player 2 option may be armed at a time."
		)
		_expect(
			armed.text.begins_with("✔") and not idle.text.begins_with("✔"),
			"The armed Player 2 option must be marked without relying on colour."
		)
		_expect(
			not hint.text.is_empty()
			and hint.text.containsn("cpu") == state,
			"The Player 2 hint must describe the current choice in words."
		)
		_expect(
			not armed.accessibility_description.is_empty()
			and not idle.accessibility_description.is_empty(),
			"Both Player 2 options must expose an accessibility description."
		)
		_expect(
			difficulty.visible == state,
			"CPU difficulty must appear only while the CPU is the opponent."
		)
		var opponent_avatar := mode_select.get_node("%OpponentAvatar")
		_expect(
			str(mode_select.get_node("%PlayerOneAvatar").get("tag")) == "P1"
			and str(opponent_avatar.get("tag")) == ("CPU" if state else "P2"),
			"Mode-select portraits must re-tag with the seat they represent."
		)
		_expect(
			not str(opponent_avatar.get("accessibility_description")).is_empty(),
			"Mode-select portraits must describe the seat they represent."
		)


func _test_triangle_rush(session: Node, settings: Node) -> void:
	GameCatalog.select("triangle_rush")
	session.call("configure_single_player")
	var game := _instantiate_scene("res://games/triangle_rush/gameplay.tscn")
	if game == null:
		return
	await process_frame
	await process_frame

	var timer := game.get_node("%RoundTimer") as Timer
	timer.stop()
	_expect(
		(game.get_node("%Callout") as Label).text
		== "FOLLOW THE HIGHLIGHT - PRESS ANY ASSIGNED CONTROL",
		"Triangle Rush callout copy must match reduced motion and one-button input."
	)
	_expect_approx(
		float(game.get("_active_round_duration")),
		float(game.get("_round_length")) + 15.0,
		"Triangle Rush must apply the extra-time assist to a new round."
	)
	_expect_approx(
		float(game.get("_round_gameplay_speed")),
		0.7,
		"Triangle Rush must apply the moving-object speed assist."
	)
	_expect_approx(
		float(game.get("_round_target_size")),
		1.3,
		"Triangle Rush must apply the target-size assist."
	)
	_expect_approx(
		timer.wait_time,
		float(game.get("_active_round_duration")),
		"Triangle Rush must start its timer with the assisted duration."
	)
	settings.call("set_value", Settings.GAMEPLAY_SPEED_KEY, 0.8)
	settings.call("set_value", Settings.TARGET_SIZE_KEY, 1.1)
	settings.call("set_value", Settings.EXTRA_ROUND_TIME_KEY, 30.0)
	_expect_approx(
		float(game.get("_active_round_duration")),
		float(game.get("_round_length")) + 15.0,
		"Triangle Rush must defer extra-time changes until the next round."
	)
	_expect_approx(
		float(game.get("_round_gameplay_speed")),
		0.7,
		"Triangle Rush must defer speed changes until the next round."
	)
	_expect_approx(
		float(game.get("_round_target_size")),
		1.3,
		"Triangle Rush must defer size changes until the next round."
	)
	settings.call("set_value", Settings.GAMEPLAY_SPEED_KEY, 0.7)
	settings.call("set_value", Settings.TARGET_SIZE_KEY, 1.3)
	settings.call("set_value", Settings.EXTRA_ROUND_TIME_KEY, 15.0)

	var targets: Array = game.get("_targets")
	var assisted_scale := 1.3 * float(game.get("_round_triangle_size"))
	for entry in targets:
		var target := entry as TriangleTarget
		_expect(
			target.scale.is_equal_approx(Vector2.ONE * assisted_scale),
			"Every Triangle Rush target must use the assisted size."
		)
		_expect(
			(target.get_node("%OwnerLabel") as Label).visible,
			"Triangle Rush must show P1/P2 identity labels."
		)

	var active_targets: Array = game.get("_active_targets")
	var active_target := active_targets[0] as TriangleTarget
	var actions: Array = settings.call("control_actions_for_player", 0)
	var mapped_action: StringName = actions[0]
	var targets_by_action: Dictionary = game.get("_targets_by_action")
	if targets_by_action[mapped_action] == active_target and actions.size() > 1:
		mapped_action = actions[1]
	var mapped_target := targets_by_action[mapped_action] as TriangleTarget
	var key_event := InputEventKey.new()
	key_event.physical_keycode = int(
		settings.call("control_keycode", mapped_action)
	)
	key_event.pressed = true
	var one_button_target := game.call(
		"_target_for_keyboard_event",
		key_event
	) as TriangleTarget
	_expect(
		one_button_target == active_target,
		"One-button Triangle Rush must route any assigned key to the active target."
	)
	var fake_controller_devices: Array[int] = [41, -1]
	session.set("_controller_devices", fake_controller_devices)
	session.set("_controllers_assigned", true)
	_expect(
		int(session.call("controller_player_index", 41)) == 0,
		"The controller-routing test must assign its simulated device to Player 1."
	)
	var controller_event := InputEventJoypadButton.new()
	controller_event.device = 41
	controller_event.button_index = int(
		settings.call(
			"controller_target_button",
			actions.find(mapped_action)
		)
	)
	controller_event.pressed = true
	var one_button_controller_target := game.call(
		"_target_for_controller_event",
		controller_event
	) as TriangleTarget
	_expect(
		one_button_controller_target == active_target,
		"One-button Triangle Rush must route any mapped controller button to the active target."
	)

	settings.call("set_value", Settings.ONE_BUTTON_TRIANGLE_RUSH_KEY, false)
	var direct_target := game.call(
		"_target_for_keyboard_event",
		key_event
	) as TriangleTarget
	_expect(
		direct_target == mapped_target,
		"Standard Triangle Rush input must retain one key per target."
	)
	var direct_controller_target := game.call(
		"_target_for_controller_event",
		controller_event
	) as TriangleTarget
	_expect(
		direct_controller_target == mapped_target,
		"Standard Triangle Rush input must route each remapped controller button directly."
	)
	_expect(
		(game.get_node("%Callout") as Label).text
		== "FOLLOW THE HIGHLIGHT - PRESS THE MATCHING CONTROL",
		"Triangle Rush callout copy must update when one-button mode changes live."
	)
	settings.call("set_value", Settings.ONE_BUTTON_TRIANGLE_RUSH_KEY, true)

	var caption := game.get_node_or_null("%AudioCaption") as Control
	var world_fx := game.get_node("%WorldFX") as Node2D
	_expect(
		caption != null
		and caption.z_index > (game.get_node("%RoundOver") as Control).z_index,
		"Audio captions must render above the round-results overlay."
	)
	game.set("_round_active", true)
	await _clear_children(world_fx)
	game.call("_attempt_target", active_target)
	_expect(
		caption != null
		and caption.visible
		and str(caption.call("caption_text")) == "Player 1: correct target",
		"Triangle Rush must caption its correct-target sound cue."
	)
	_expect(
		world_fx.get_child_count() == 1
		and world_fx.get_child(0) is Label,
		"Reduced motion must keep static score text while suppressing Triangle Rush bursts."
	)
	_expect(
		(game.get_node("%PlayerOneScore") as Label).scale.is_equal_approx(
			Vector2.ONE
		),
		"Reduced motion must suppress score scaling."
	)

	var current_active_targets: Array = game.get("_active_targets")
	var current_active := current_active_targets[0] as TriangleTarget
	var wrong_target: TriangleTarget
	for entry in game.get("_targets"):
		var candidate := entry as TriangleTarget
		if candidate.player_index == 0 and candidate != current_active:
			wrong_target = candidate
			break
	game.call("_attempt_target", wrong_target)
	_expect(
		caption != null
		and str(caption.call("caption_text")) == "Player 1: wrong target",
		"Triangle Rush must caption its wrong-target sound cue."
	)
	game.call("_update_time", 3)
	_expect(
		caption != null
		and str(caption.call("caption_text")) == "3 seconds remaining",
		"Triangle Rush must caption its final countdown."
	)
	game.call("_celebrate_level_unlock", "Desk-Can-Saw")
	_expect(
		caption != null
		and str(caption.call("caption_text")).contains("unlocked"),
		"Triangle Rush must caption the Desk-Can-Saw unlock cue."
	)

	game.set("_ambient_time", PI / 22.0)
	game.call("_update_urgency", 1.0)
	game.call("_add_screen_shake", 12.0)
	game.call("_show_announcement", "STATIC", Color.WHITE)
	var round_panel := game.get_node("%RoundPanel") as Control
	round_panel.scale = Vector2.ONE * 0.5
	game.call("_animate_modal_panel", round_panel)
	_expect(
		(game.get_node("%TimeLabel") as Label).scale.is_equal_approx(
			Vector2.ONE
		)
		and is_zero_approx(
			(game.get_node("%DangerOverlay") as ColorRect).color.a
		)
		and is_zero_approx(float(game.get("_shake_strength")))
		and (game.get_node("%Announcement") as Label).scale.is_equal_approx(
			Vector2.ONE
		)
		and round_panel.scale.is_equal_approx(Vector2.ONE),
		"Reduced motion must remove urgency pulses, shake and spatial UI feedback."
	)

	settings.call("set_value", Settings.REDUCED_MOTION_KEY, false)
	game.set("_ambient_time", PI / 22.0)
	game.call("_update_urgency", 1.0)
	var moving_targets: Array = game.get("_targets")
	var moving_target := moving_targets[0] as TriangleTarget
	moving_target.call("_process", 0.05)
	await _clear_children(world_fx)
	game.call(
		"_spawn_hit_effect",
		moving_target.global_position,
		Color.WHITE,
		true,
		"+1"
	)
	game.call("_add_screen_shake", 12.0)
	_expect(
		(game.get_node("%TimeLabel") as Label).scale.x > 1.0
		and (game.get_node("%Callout") as Label).text.contains("PULSE")
		and (moving_target.get_node("%Trail") as Line2D).visible
		and world_fx.get_child_count() > 1
		and float(game.get("_shake_strength")) > 0.0,
		"Disabling reduced motion live must restore Triangle Rush motion feedback."
	)

	settings.call("set_value", Settings.REDUCED_MOTION_KEY, true)
	await process_frame
	_expect(
		(game.get_node("%TimeLabel") as Label).scale.is_equal_approx(
			Vector2.ONE
		)
		and (game.get_node("%Callout") as Label).text.contains("HIGHLIGHT")
		and not (moving_target.get_node("%Trail") as Line2D).visible
		and world_fx.get_child_count() == 0
		and is_zero_approx(float(game.get("_shake_strength"))),
		"Enabling reduced motion live must clear active Triangle Rush motion effects."
	)

	settings.call("set_value", Settings.PLAYER_LABELS_KEY, false)
	for entry in targets:
		var target := entry as TriangleTarget
		_expect(
			not (target.get_node("%OwnerLabel") as Label).visible,
			"Triangle Rush must update player labels while paused."
		)
	settings.call("set_value", Settings.PLAYER_LABELS_KEY, true)
	await _free_scene(game)


func _test_desk_can_saw(session: Node, settings: Node) -> void:
	GameCatalog.select("desk_can_saw")
	session.call("configure_single_player")
	var game := _instantiate_scene("res://games/desk_can_saw/desk_can_saw.tscn")
	if game == null:
		return
	await process_frame
	await process_frame

	var timer := game.get_node("%RoundTimer") as Timer
	timer.stop()
	var caption := game.get_node_or_null("%AudioCaption") as Control
	_expect(
		caption != null
		and caption.visible
		and str(caption.call("caption_text")) == "Chainsaw powered",
		"Desk-Can-Saw must caption its startup power cue."
	)
	_expect(
		(game.get_node("%Hint") as Label).text
		== "Mouse or arrow keys   |   Drive the moving chain through each can",
		"Desk-Can-Saw must drop pad copy until a controller is connected."
	)
	_expect(
		(game.get_node("%Callout") as Label).text
		== "DRIVE THE CHAIN THROUGH EACH CAN",
		"Desk-Can-Saw must replace Triangle Rush's matching-control callout."
	)
	_expect(
		(game.get_node("%ModeTitle") as Label).text
		== GameCatalog.get_manifest("desk_can_saw").title.to_upper(),
		"Desk-Can-Saw must replace the inherited Triangle Rush title."
	)
	_expect_approx(
		float(game.get("_active_round_duration")),
		float(game.get("round_duration")) + 15.0,
		"Desk-Can-Saw must apply the extra-time assist to a new round."
	)
	_expect_approx(
		float(game.get("_round_gameplay_speed")),
		0.7,
		"Desk-Can-Saw must apply the moving-object speed assist."
	)
	_expect_approx(
		float(game.get("_round_target_size")),
		1.3,
		"Desk-Can-Saw must apply the target-size assist."
	)
	_expect_approx(
		float(game.call("_controller_movement_speed")),
		float(game.get("chainsaw_speed")) * 0.75,
		"Desk-Can-Saw must apply the controller movement-speed setting."
	)
	settings.call("set_value", Settings.GAMEPLAY_SPEED_KEY, 0.8)
	settings.call("set_value", Settings.TARGET_SIZE_KEY, 1.1)
	settings.call("set_value", Settings.EXTRA_ROUND_TIME_KEY, 30.0)
	_expect_approx(
		float(game.get("_active_round_duration")),
		float(game.get("round_duration")) + 15.0,
		"Desk-Can-Saw must defer extra-time changes until the next round."
	)
	_expect_approx(
		float(game.get("_round_gameplay_speed")),
		0.7,
		"Desk-Can-Saw must defer speed changes until the next round."
	)
	_expect_approx(
		float(game.get("_round_target_size")),
		1.3,
		"Desk-Can-Saw must defer size changes until the next round."
	)
	settings.call("set_value", Settings.GAMEPLAY_SPEED_KEY, 0.7)
	settings.call("set_value", Settings.TARGET_SIZE_KEY, 1.3)
	settings.call("set_value", Settings.EXTRA_ROUND_TIME_KEY, 15.0)
	game.set("_round_active", false)
	game.call("_clear_cans")
	game.set("_ambient_time", 2.0)
	game.call("_process", 0.1)
	game.call("_update_urgency", 1.0)
	game.call("_add_screen_shake", 12.0)
	game.call("_show_announcement", "STATIC", Color.WHITE)
	var round_panel := game.get_node("%RoundPanel") as Control
	round_panel.scale = Vector2.ONE * 0.5
	game.call("_animate_modal_panel", round_panel)
	_expect(
		is_equal_approx(float(game.get("_ambient_time")), 2.0)
		and (game.get_node("%TimeLabel") as Label).scale.is_equal_approx(
			Vector2.ONE
		)
		and is_zero_approx(
			(game.get_node("%DangerOverlay") as ColorRect).color.a
		)
		and is_zero_approx(float(game.get("_shake_strength")))
		and (game.get_node("%Announcement") as Label).scale.is_equal_approx(
			Vector2.ONE
		)
		and round_panel.scale.is_equal_approx(Vector2.ONE),
		"Reduced motion must freeze ambient, urgency, shake and spatial UI motion in Desk-Can-Saw."
	)

	var slice_script: Script = game.get_script()
	var filtered: Vector2 = slice_script.call(
		"apply_controller_deadzone",
		Vector2(0.2, 0.4),
		0.3
	)
	_expect(
		filtered.is_equal_approx(Vector2(0.0, 0.4)),
		"Desk-Can-Saw must filter stick drift using the configured deadzone."
	)
	var combined_velocity: Vector2 = slice_script.call(
		"combine_movement_velocity",
		Vector2.RIGHT,
		Vector2(0.0, 0.06),
		600.0,
		600.0
	)
	_expect(
		combined_velocity.x > 590.0 and absf(combined_velocity.y) < 40.0,
		"Controller drift must not replace active keyboard movement."
	)

	game.call("_spawn_can")
	var cans: Array = game.get("_cans")
	var assisted_can := cans[0] as SliceCan
	_expect_approx(
		assisted_can.radius,
		float(game.get("can_radius")) * 1.3,
		"Desk-Can-Saw must enlarge newly spawned cans."
	)
	_expect(
		bool(assisted_can.get("_reduced_motion")),
		"New cans must inherit the live reduced-motion setting."
	)
	game.call("_clear_cans")
	await process_frame

	var motion_can := SliceCan.new()
	motion_can.configure(30.0, Vector2(100.0, 0.0), 0.0, Color.WHITE, 0.0)
	var bounds: Rect2 = game.call("_playfield_bounds")
	motion_can.position = bounds.position + Vector2(220.0, 100.0)
	var start_position := motion_can.position
	game.get_node("%Playfield").add_child(motion_can)
	cans = game.get("_cans")
	cans.append(motion_can)
	game.call("_update_cans", 0.5)
	_expect_approx(
		motion_can.position.x - start_position.x,
		35.0,
		"Desk-Can-Saw must scale can movement by the gameplay-speed assist."
	)
	var reduced_spin_can := SliceCan.new()
	reduced_spin_can.configure(
		30.0,
		Vector2(100.0, 0.0),
		0.0,
		Color.WHITE,
		3.0
	)
	reduced_spin_can.set_reduced_motion(true)
	reduced_spin_can.position = bounds.position + Vector2(220.0, 100.0)
	var reduced_spin_start := reduced_spin_can.position
	reduced_spin_can.advance(0.5, bounds)
	_expect(
		is_zero_approx(reduced_spin_can.rotation)
		and reduced_spin_can.position.x > reduced_spin_start.x,
		"Reduced motion must stop decorative can spin without stopping its fall path."
	)
	reduced_spin_can.free()
	game.call("_clear_cans")
	await process_frame

	var world_fx := game.get_node("%WorldFX") as Node2D
	game.call("_clear_world_fx")
	await process_frame
	game.call(
		"_spawn_slice_effect",
		Vector2(420.0, 420.0),
		Color.WHITE,
		0,
		0.0,
		34.0
	)
	_expect(
		world_fx.get_child_count() == 2
		and world_fx.get_child(0) is Line2D
		and world_fx.get_child(1) is Label,
		"Reduced motion must replace slice fragments and sparks with static feedback."
	)
	var reduced_effect_count := world_fx.get_child_count()
	game.call("_spawn_clatter_effect", Vector2(420.0, 420.0), Color.WHITE)
	game.call("_spawn_round_confetti", Color.WHITE)
	_expect(
		world_fx.get_child_count() == reduced_effect_count,
		"Reduced motion must suppress clatter particles and round confetti."
	)

	var chainsaws: Array = game.get("_chainsaws")
	var chainsaw := chainsaws[0] as ChainsawCursor
	var player_label := chainsaw.get_node_or_null("PlayerLabel") as Label
	_expect(
		player_label != null and player_label.visible,
		"Desk-Can-Saw must show P1/P2 identity labels."
	)
	settings.call("set_value", Settings.PLAYER_LABELS_KEY, false)
	_expect(
		player_label != null and not player_label.visible,
		"Desk-Can-Saw must update player labels while paused."
	)
	settings.call("set_value", Settings.PLAYER_LABELS_KEY, true)

	game.call("_clear_world_fx")
	await process_frame
	var live_can := SliceCan.new()
	live_can.configure(30.0, Vector2.ZERO, 0.0, Color.WHITE, 2.0)
	live_can.set_reduced_motion(true)
	game.get_node("%Playfield").add_child(live_can)
	cans = game.get("_cans")
	cans.append(live_can)
	settings.call("set_value", Settings.REDUCED_MOTION_KEY, false)
	game.set("_ambient_time", PI / 22.0)
	game.call("_update_urgency", 1.0)
	chainsaw.trigger_cut()
	chainsaw.call("_process", 0.05)
	game.call(
		"_spawn_slice_effect",
		Vector2(420.0, 420.0),
		Color.WHITE,
		0,
		0.0,
		34.0
	)
	game.call("_add_screen_shake", 12.0)
	_expect(
		(game.get_node("%TimeLabel") as Label).scale.x > 1.0
		and not bool(live_can.get("_reduced_motion"))
		and float(chainsaw.get("_chain_phase")) > 0.0
		and float(chainsaw.get("_impact")) > 0.0
		and world_fx.get_child_count() > 2
		and float(game.get("_shake_strength")) > 0.0,
		"Disabling reduced motion live must restore Desk-Can-Saw motion feedback."
	)

	settings.call("set_value", Settings.REDUCED_MOTION_KEY, true)
	await process_frame
	_expect(
		(game.get_node("%TimeLabel") as Label).scale.is_equal_approx(
			Vector2.ONE
		)
		and bool(live_can.get("_reduced_motion"))
		and is_zero_approx(float(chainsaw.get("_chain_phase")))
		and is_zero_approx(float(chainsaw.get("_impact")))
		and world_fx.get_child_count() == 0
		and is_zero_approx(float(game.get("_shake_strength"))),
		"Enabling reduced motion live must clear active Desk-Can-Saw motion effects."
	)

	var scored_can := SliceCan.new()
	scored_can.configure(30.0, Vector2.ZERO, 0.0, Color.WHITE, 0.0)
	scored_can.position = chainsaw.position
	game.get_node("%Playfield").add_child(scored_can)
	cans = game.get("_cans")
	cans.append(scored_can)
	game.call("_score_slice", 0, scored_can)
	_expect(
		caption != null
		and str(caption.call("caption_text")) == "Player 1 sliced a can",
		"Desk-Can-Saw must caption can-slice sounds."
	)

	game.call("_clear_cans")
	await process_frame
	var missed_can := SliceCan.new()
	missed_can.configure(30.0, Vector2.ZERO, 0.0, Color.WHITE, 0.0)
	missed_can.position = Vector2(
		bounds.get_center().x,
		bounds.end.y + missed_can.radius + 1.0
	)
	game.get_node("%Playfield").add_child(missed_can)
	cans = game.get("_cans")
	cans.append(missed_can)
	game.call("_update_cans", 0.0)
	_expect(
		caption != null
		and str(caption.call("caption_text")) == "Can missed",
		"Desk-Can-Saw must caption missed-can sounds."
	)
	game.set("_round_active", true)
	game.call("_update_time", 2)
	_expect(
		caption != null
		and str(caption.call("caption_text")) == "2 seconds remaining",
		"Desk-Can-Saw must caption its final countdown."
	)
	await _free_scene(game)


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
		print("Accessibility tests passed.")
		quit(0)
		return
	for failure in _failures:
		push_error(failure)
	quit(1)
