extends SceneTree

## A synthetic manifest proves custom action keys are a trait, not a game-name
## exception. Real menu handlers configure the session; only Router's scene
## transitions are blocked. Settings, InputMap and catalog state are restored,
## and the save timer is disabled while fixture values exist.
##
## Run from the framework: godot --headless --path . --script
## res://tests/custom_keys_test.gd -- --game=all

const MODE_SELECT := "res://scenes/menus/mode_select.tscn"
const INSTRUCTIONS := "res://scenes/menus/instructions.tscn"
const SETTINGS_MENU := "res://scenes/menus/settings_menu.tscn"
const FIXTURE_ID := "custom_keys_regression_fixture"
const ONE_KEY := "controls/custom_keys_fixture_one"
const EXTRA_KEY := "controls/custom_keys_fixture_extra"
const TWO_KEY := "controls/custom_keys_fixture_two"
const SHARED_KEY := "controls/custom_keys_fixture_shared"
const CPU_CHOICE_KEY := "game/custom_keys_fixture_opponent"
const SETTINGS_PATH := "user://settings.cfg"
const HUMAN_CONTROLLER := 0
const CPU_CONTROLLER := 1

const BINDINGS: Array[Dictionary] = [
	{
		"key": ONE_KEY, "default": KEY_A, "title": "Wind",
		"action": &"custom_keys_fixture_one", "player": 0, "movement": true,
	},
	{
		"key": EXTRA_KEY, "default": KEY_D, "title": "Release", "player": 0,
	},
	{
		"key": TWO_KEY, "default": KEY_J, "title": "Catch",
		"action": &"custom_keys_fixture_two", "player": 1, "movement": true,
	},
	{
		"key": SHARED_KEY, "default": KEY_SPACE, "title": "Ready",
	},
]
const CPU_OPTION := {
	"key": CPU_CHOICE_KEY,
	"type": GameManifest.OPTION_CHOICE,
	"default": 7,
	"title": "Automatic opponent",
	"choices": [
		{"value": 7, "title": "Careful"},
		{"value": 11, "title": "Bold"},
	],
}
const COPY := {
	"mode_select_intro": "Choose who catches the next throw.",
	"mode_select_hint": "Check each player's action keys next.",
	"single_player_description": "Practice winding and releasing.",
	"multiplayer_description": "Take turns winding and catching.",
	"player_one_control_description": "Wind, then release.",
	"player_two_control_description": "Catch the throw.",
	"solo_confirm_title": "Ready to wind?",
	"solo_confirm_description": "Wind before you release.",
	"versus_confirm_title": "Ready to trade throws?",
	"versus_confirm_description": "Each player has a different job.",
	"cpu_opponent_description": "The CPU catches automatically; choose its style in Settings.",
	"instructions_headline": "Wind and catch",
	"instructions_rules": "One throw at a time  ·  Esc pauses",
	"instructions_demo_prompt": "WATCH THE THROW",
	"instructions_solo_summary": "Practice your release.",
	"instructions_versus_summary": "Trade throws with another player.",
	"instructions_cpu_summary": "Throw to the automatic catcher.",
	"instructions_player_one_controls": "Wind before releasing the throw.",
	"instructions_player_two_controls": "Catch after the release.",
	"instructions_cpu_controls": "The automatic catcher uses the game's selected style.",
}

var _failures := PackedStringArray()
var _settings: Node
var _session: Node
var _router: Node
var _fixture: GameManifest
var _original_settings: Dictionary = {}
var _original_session: Dictionary = {}
var _original_actions: Dictionary = {}
var _original_manifests: Array[GameManifest] = []
var _original_by_id: Dictionary = {}
var _original_current_id := ""
var _original_forced_id := ""
var _original_router_busy := false
var _save_timer: Timer
var _save_timer_mode := Node.PROCESS_MODE_INHERIT
var _save_timer_wait := 0.0
var _save_timer_remaining := 0.0
var _original_settings_hash := ""


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	_settings = get_root().get_node_or_null("Settings")
	_session = get_root().get_node_or_null("GameSession")
	_router = get_root().get_node_or_null("Router")
	if _settings == null or _session == null or _router == null:
		_expect(false, "Settings, GameSession and Router autoloads are required.")
		_finish()
		return

	_snapshot_state()
	_install_fixture()
	await _test_named_cpu_setting()
	await _test_custom_mode_selection()
	await _test_custom_instructions()
	await _test_live_rebindings()
	await _test_copy_fallbacks()
	await _test_style_capabilities()
	await _test_two_seat_only_selection()
	await _test_existing_instructions()
	await _test_controller_rows()
	_restore_state()
	_expect(
		_settings.get("_values") == _original_settings["_values"]
		and GameCatalog.current_id() == _original_current_id
		and GameCatalog._forced_single_id == _original_forced_id
		and GameCatalog.all() == _original_manifests,
		"The test must restore settings, selection and catalog restrictions."
	)
	for property: String in _original_session:
		_expect(
			_session.get(property) == _original_session[property],
			"The test must restore GameSession.%s." % property
		)
	_expect(
		_settings_hash() == _original_settings_hash,
		"The test must never write fixture values to user://settings.cfg."
	)
	_finish()


func _snapshot_state() -> void:
	_original_manifests = GameCatalog.all()
	_original_by_id = GameCatalog._by_id.duplicate()
	_original_current_id = GameCatalog.current_id()
	_original_forced_id = GameCatalog._forced_single_id
	for property: String in [
		"_values", "_tunables", "_options_by_game",
		"_control_bindings", "_bindings_by_game",
	]:
		_original_settings[property] = (_settings.get(property) as Dictionary).duplicate(true)
	for property: String in [
		"game_mode", "player_two_controller", "cpu_difficulty",
		"_controllers_assigned", "_gamepad_available",
	]:
		_original_session[property] = _session.get(property)
	_original_session["_controller_devices"] = (
		_session.get("_controller_devices") as Array
	).duplicate()
	_original_router_busy = bool(_router.get("_busy"))
	_router.set("_busy", true)
	_save_timer = _settings.get("_save_timer") as Timer
	_save_timer_mode = _save_timer.process_mode
	_save_timer_wait = _save_timer.wait_time
	_save_timer_remaining = _save_timer.time_left
	_save_timer.process_mode = Node.PROCESS_MODE_DISABLED
	_save_timer.stop()
	_original_settings_hash = _settings_hash()

	for binding: Dictionary in BINDINGS:
		var action := StringName(binding.get("action", &""))
		if action.is_empty():
			continue
		var exists := InputMap.has_action(action)
		_original_actions[action] = {
			"exists": exists,
			"deadzone": InputMap.action_get_deadzone(action) if exists else 0.5,
			"events": InputMap.action_get_events(action) if exists else [],
		}


func _install_fixture() -> void:
	_fixture = GameManifest.new()
	_fixture.id = FIXTURE_ID
	_fixture.title = "Action Keys Fixture"
	_fixture.control_style = GameManifest.CONTROL_STYLE_CUSTOM_KEYS
	_fixture.control_bindings = BINDINGS
	_fixture.tunables = [CPU_OPTION]
	_fixture.copy = COPY.duplicate()
	_fixture.gameplay_scene_path = INSTRUCTIONS
	GameCatalog._manifests = [_fixture]
	GameCatalog._by_id = {FIXTURE_ID: _fixture}
	GameCatalog._current_id = FIXTURE_ID
	GameCatalog._forced_single_id = FIXTURE_ID

	var bindings: Dictionary = _original_settings["_control_bindings"].duplicate(true)
	var values: Dictionary = _original_settings["_values"].duplicate(true)
	for binding: Dictionary in BINDINGS:
		var key := str(binding["key"])
		bindings[key] = binding
		values[key] = int(binding["default"])
	values[CPU_CHOICE_KEY] = 7
	values["accessibility/reduced_motion"] = true
	values["game/show_instructions"] = true
	values["game/round_mode"] = 0
	_settings.set("_values", values)
	_settings.set("_control_bindings", bindings)
	_use_fixture_bindings(true)

	var tunables: Dictionary = _original_settings["_tunables"].duplicate(true)
	tunables[CPU_CHOICE_KEY] = CPU_OPTION
	_settings.set("_tunables", tunables)
	var options: Dictionary = _original_settings["_options_by_game"].duplicate(true)
	options[FIXTURE_ID] = [CPU_OPTION]
	_settings.set("_options_by_game", options)
	_session.call("configure_single_player")
	_session.set("cpu_difficulty", 2)


func _use_fixture_bindings(enabled: bool) -> void:
	var bindings: Dictionary = (_settings.get("_bindings_by_game") as Dictionary).duplicate()
	if enabled:
		_fixture.control_bindings = BINDINGS
		bindings[FIXTURE_ID] = BINDINGS
	else:
		_fixture.control_bindings = []
		bindings.erase(FIXTURE_ID)
	_settings.set("_bindings_by_game", bindings)


func _test_named_cpu_setting() -> void:
	var menu := await _open(SETTINGS_MENU)
	if menu == null:
		return
	var options: Dictionary = menu.get("_option_controls")
	var choice := options.get(CPU_CHOICE_KEY) as OptionButton
	_expect(choice != null, "A custom game must retain its declared CPU choice row.")
	if choice != null:
		var index := choice.get_item_index(11)
		choice.select(index)
		choice.emit_signal("item_selected", index)
		_expect(
			int(_settings.call("tunable_choice", CPU_CHOICE_KEY)) == 11,
			"The game's named CPU setting must write through the existing menu handler."
		)
	var bindings: Dictionary = menu.get("_binding_buttons")
	_expect(
		bindings.size() == BINDINGS.size(),
		"All custom action keys, including shared keys, must be rebindable."
	)
	await _close(menu)


func _test_custom_mode_selection() -> void:
	var menu := await _open(MODE_SELECT)
	if menu == null:
		return
	_expect(
		_text(menu, "%Intro") == COPY["mode_select_intro"]
		and _text(menu, "%SelectionHint") == COPY["mode_select_hint"],
		"Mode selection must use the manifest's introduction and hint."
	)
	_expect(
		_text(menu, "%SinglePlayerControls") == "PLAYER 1 · KEYS A  D  Space"
		and _text(menu, "%MultiplayerControls") == "P1 · A  D  Space     P2 · J  Space",
		"Mode cards must include per-player and shared keys, even without InputMap actions."
	)
	_assert_custom_copy(menu)
	_press(menu, "%MultiplayerButton")
	_expect(
		_visible(menu, "%OpponentSelector")
		and bool(menu.call("_cpu_selected"))
		and not _visible(menu, "%CpuDifficultyPanel")
		and (menu.get_node("%CpuDifficulty") as OptionButton).item_count == 0,
		"Custom keys must offer the CPU without the unrelated target difficulty picker."
	)
	_expect(
		_text(menu, "%OpponentControlDescription") == COPY["cpu_opponent_description"]
		and _text(menu, "%OpponentChoiceHint") == COPY["cpu_opponent_description"],
		"The CPU card and choice hint must describe the game's own opponent."
	)
	_choose_opponent(menu, false)
	_expect(
		_text(menu, "%PlayerOneControlKeys") == "KEYS A · D · Space"
		and _text(menu, "%OpponentControlKeys") == "KEYS J · Space"
		and _text(menu, "%OpponentControlDescription") == COPY["player_two_control_description"]
		and _text(menu, "%ConfirmDescription") == COPY["versus_confirm_description"],
		"Human versus confirmation must describe both players' actual actions."
	)
	_press(menu, "%ConfirmButton")
	_expect(
		bool(_session.call("player_two_enabled"))
		and not bool(_session.call("player_two_is_cpu")),
		"Choosing a second player and confirming must configure human multiplayer."
	)
	_choose_opponent(menu, true)
	_press(menu, "%ConfirmButton")
	_expect(
		bool(_session.call("player_two_is_cpu"))
		and int(_session.get("cpu_difficulty")) == 2
		and int(_settings.call("tunable_choice", CPU_CHOICE_KEY)) == 11,
		"CPU confirmation must configure its seat without overwriting the game's named choice."
	)
	_expect(
		str(menu.call("_next_scene")) == INSTRUCTIONS,
		"Custom-key modes must retain the existing instructions route."
	)
	_assert_custom_copy(menu)
	menu.call("_on_previous_pressed")
	_press(menu, "%SinglePlayerButton")
	_press(menu, "%ConfirmButton")
	_expect(
		bool(_session.call("is_single_player"))
		and not _visible(menu, "%OpponentControl")
		and not _visible(menu, "%OpponentSelector")
		and _text(menu, "%ConfirmDescription") == COPY["solo_confirm_description"],
		"Standalone single-player selection must still configure one seat and use solo copy."
	)
	_assert_custom_copy(menu)
	await _close(menu)


func _test_custom_instructions() -> void:
	for controller: int in [-1, HUMAN_CONTROLLER, CPU_CONTROLLER]:
		_configure_session(controller)
		var screen := await _open(INSTRUCTIONS)
		if screen == null:
			return
		_expect(
			_text(screen, "%Headline") == COPY["instructions_headline"]
			and _text(screen, "%Rules") == COPY["instructions_rules"]
			and _text(screen, "%DemoPrompt") == COPY["instructions_demo_prompt"],
			"Every custom-key mode must render the manifest's rules and demonstration copy."
		)
		_expect(
			_text(screen, "%PlayerOneControls")
			== "%s\nWind: A\nRelease: D\nReady: Space" % COPY["instructions_player_one_controls"],
			"Solo and versus must both combine P1 action copy with live key lines."
		)
		_expect(
			_visible(screen, "%OpponentCard") == (controller >= 0),
			"The instructions opponent card must follow the actual second seat."
		)
		if controller < 0:
			_expect(
				_text(screen, "%Summary") == COPY["instructions_solo_summary"],
				"Single player must use the manifest's solo summary."
			)
		elif controller == HUMAN_CONTROLLER:
			_expect(
				_text(screen, "%OpponentControls")
				== "%s\nCatch: J\nReady: Space" % COPY["instructions_player_two_controls"]
				and _text(screen, "%Summary") == COPY["instructions_versus_summary"],
				"Human versus must show P2 action copy and only P2/shared bindings."
			)
		else:
			_expect(
				_text(screen, "%Summary") == COPY["instructions_cpu_summary"]
				and _text(screen, "%OpponentControls") == COPY["instructions_cpu_controls"]
				and _text(screen, "%OpponentTitle") == "CPU OPPONENT"
				and not _text(screen, "%ModeLabel").containsn("hard"),
				"CPU instructions must use game-owned copy, not target difficulty or human keys."
			)
		_assert_custom_copy(screen)
		await _close(screen)


func _test_live_rebindings() -> void:
	_configure_session(HUMAN_CONTROLLER)
	var menu := await _open(MODE_SELECT)
	var screen := await _open(INSTRUCTIONS)
	if menu == null or screen == null:
		await _close(menu)
		await _close(screen)
		return
	_press(menu, "%MultiplayerButton")
	_choose_opponent(menu, false)
	for binding: Array in [[ONE_KEY, KEY_F6], [TWO_KEY, KEY_F8], [SHARED_KEY, KEY_F9]]:
		_expect(
			bool(_settings.call("set_binding_key", binding[0], binding[1], FIXTURE_ID)),
			"The fixture key must rebind through Settings."
		)
	_expect(
		_text(menu, "%PlayerOneControlKeys") == "KEYS F6 · D · F9"
		and _text(menu, "%OpponentControlKeys") == "KEYS F8 · F9"
		and _text(menu, "%SinglePlayerControls") == "PLAYER 1 · KEYS F6  D  F9"
		and _text(menu, "%MultiplayerControls") == "P1 · F6  D  F9     P2 · F8  F9"
		and _text(menu, "%ConfirmHint") == "Player 1: F6 · D · F9  |  Player 2: F8 · F9",
		"Every open mode-select key hint must refresh when either player or a shared key changes."
	)
	_expect(
		_text(screen, "%PlayerOneControls")
		== "%s\nWind: F6\nRelease: D\nReady: F9" % COPY["instructions_player_one_controls"]
		and _text(screen, "%OpponentControls")
		== "%s\nCatch: F8\nReady: F9" % COPY["instructions_player_two_controls"],
		"Open instructions must refresh rebound action lines without replacing the manifest copy."
	)
	menu.call("_on_gamepad_availability_changed", true)
	screen.call("_on_gamepad_availability_changed", true)
	_assert_custom_copy(menu)
	_assert_custom_copy(screen)
	await _close(menu)
	await _close(screen)
	_configure_session(-1)
	screen = await _open(INSTRUCTIONS)
	if screen != null:
		_expect(
			_text(screen, "%PlayerOneControls")
			== "%s\nWind: F6\nRelease: D\nReady: F9" % COPY["instructions_player_one_controls"]
			and not _visible(screen, "%OpponentCard"),
			"Fresh solo instructions must retain rebound keys and the manifest action copy."
		)
		await _close(screen)


func _test_copy_fallbacks() -> void:
	_fixture.copy.erase("instructions_player_two_controls")
	_configure_session(HUMAN_CONTROLLER)
	var screen := await _open(INSTRUCTIONS)
	if screen != null:
		_expect(
			_text(screen, "%OpponentControls").begins_with(
				str(COPY["player_two_control_description"]) + "\nCatch: F8"
			),
			"Missing P2 instructions must fall back to its manifest action description."
		)
		await _close(screen)

	_fixture.copy = {}
	for controller: int in [-1, HUMAN_CONTROLLER, CPU_CONTROLLER]:
		_configure_session(controller)
		screen = await _open(INSTRUCTIONS)
		if screen != null:
			_assert_custom_copy(screen)
			await _close(screen)
	var menu := await _open(MODE_SELECT)
	if menu != null:
		_assert_custom_copy(menu)
		_press(menu, "%SinglePlayerButton")
		_assert_custom_copy(menu)
		_press(menu, "%MultiplayerButton")
		_assert_custom_copy(menu)
		_choose_opponent(menu, false)
		_assert_custom_copy(menu)
		await _close(menu)

	_use_fixture_bindings(false)
	_expect(
		(_settings.call("control_bindings_for_game", FIXTURE_ID) as Array).is_empty(),
		"Custom keys with no declarations must not inherit target controls."
	)
	menu = await _open(MODE_SELECT)
	if menu != null:
		_expect(
			_text(menu, "%SinglePlayerControls").contains("No action keys declared"),
			"An empty custom-key manifest must not advertise invented keys."
		)
		_assert_custom_copy(menu)
		await _close(menu)
	_use_fixture_bindings(true)
	_fixture.copy = COPY.duplicate()


func _test_style_capabilities() -> void:
	_fixture.copy = {}
	for style: String in [
		GameManifest.CONTROL_STYLE_CUSTOM_KEYS,
		GameManifest.CONTROL_STYLE_TARGETS,
		GameManifest.CONTROL_STYLE_DIRECT_MOVEMENT,
	]:
		_fixture.control_style = style
		_use_fixture_bindings(style == GameManifest.CONTROL_STYLE_CUSTOM_KEYS)
		for supports_cpu: bool in [true, false]:
			_fixture.supports_cpu_opponent = supports_cpu
			_configure_session(-1)
			var menu := await _open(MODE_SELECT)
			if menu == null:
				continue
			_press(menu, "%MultiplayerButton")
			var offered := supports_cpu and style != GameManifest.CONTROL_STYLE_DIRECT_MOVEMENT
			_expect(
				bool(_session.call("cpu_opponent_available")) == supports_cpu
				and bool(menu.call("_cpu_selected")) == offered
				and _visible(menu, "%OpponentSelector") == offered
				and (menu.get_node("%CpuOptionButton") as Button).disabled == (not offered),
				"%s must honour the CPU capability while preserving direct-movement semantics."
				% style
			)
			_expect(
				_visible(menu, "%CpuDifficultyPanel")
				== (offered and style == GameManifest.CONTROL_STYLE_TARGETS),
				"Only target-style CPU matches should show the target difficulty picker."
			)
			# Even a stale pressed state must not bypass the manifest's capability.
			_choose_opponent(menu, true)
			_press(menu, "%ConfirmButton")
			_expect(
				bool(_session.call("player_two_is_cpu")) == offered,
				"%s confirmation must not configure an unavailable CPU opponent." % style
			)
			if not offered:
				_expect(
					not _text(menu, "%ConfirmDescription").containsn("cpu")
					and _text(menu, "%MultiplayerRoster") == "Player 1 vs Player 2",
					"A human-only game must not invite the player to race the CPU."
				)
			await _close(menu)

	_fixture.control_style = GameManifest.CONTROL_STYLE_CUSTOM_KEYS
	_fixture.supports_cpu_opponent = true
	_fixture.supports_multiplayer = false
	_use_fixture_bindings(true)
	var solo_menu := await _open(MODE_SELECT)
	if solo_menu != null:
		_press(solo_menu, "%MultiplayerButton")
		_press(solo_menu, "%ConfirmButton")
		_expect(
			not _visible(solo_menu, "%Multiplayer")
			and not bool(solo_menu.call("_cpu_selected"))
			and bool(_session.call("is_single_player")),
			"A solo-only custom game must not enable a CPU or second human seat."
		)
		await _close(solo_menu)
	_fixture.supports_multiplayer = true
	_fixture.copy = COPY.duplicate()


## A game whose second seat is never optional — a tug-of-war, a duel — has one
## honest answer to "how many players?", so the screen must not ask. Clearing
## the capability collapses step one rather than pre-selecting a card the
## player could still change.
func _test_two_seat_only_selection() -> void:
	_fixture.supports_single_player = false
	var menu := await _open(MODE_SELECT)
	if menu != null:
		_expect(
			not bool(menu.get("_player_count_offered"))
			and not (menu.get_node("Margins/Layout/Stepper") as Control).visible
			and not _visible(menu, "%PreviousButton")
			and not _visible(menu, "%SelectionStep")
			and _visible(menu, "%ConfirmStep"),
			"A two-seat-only game must open on the confirmation with no player-count step."
		)
		_expect(
			_visible(menu, "%OpponentSelector"),
			"Collapsing the player count must keep the human-or-CPU choice."
		)
		_choose_opponent(menu, false)
		_press(menu, "%ConfirmButton")
		_expect(
			bool(_session.call("player_two_enabled"))
			and not bool(_session.call("is_single_player")),
			"Confirming without a player-count step must still seat two players."
		)
		await _close(menu)
	_fixture.supports_single_player = true


func _test_existing_instructions() -> void:
	_fixture.copy = {}
	_use_fixture_bindings(false)
	var connected := bool(_session.call("gamepad_connected"))
	for style: String in [
		GameManifest.CONTROL_STYLE_TARGETS, GameManifest.CONTROL_STYLE_DIRECT_MOVEMENT,
	]:
		_fixture.control_style = style
		for controller: int in [-1, HUMAN_CONTROLLER]:
			_configure_session(controller)
			var screen := await _open(INSTRUCTIONS)
			if screen == null:
				continue
			var controls := _text(screen, "%PlayerOneControls")
			var targets := style == GameManifest.CONTROL_STYLE_TARGETS
			_expect(
				controls.contains("Controller 1:") == connected,
				"Existing styles must retain their conditional gamepad instructions."
			)
			_expect(
				_text(screen, "%Headline") == (
					"Follow your highlighted target" if targets
					else "Reach every target before it disappears"
				)
				and controls.contains("Mouse/touch:" if targets else "ouse"),
				"Existing target and direct-movement instructions must stay unchanged."
			)
			if controller == HUMAN_CONTROLLER:
				_expect(
					_text(screen, "%OpponentControls").contains(
						"Mouse/touch:" if targets else "Player 2: arrow keys"
					),
					"Existing human P2 controls must retain their original style."
				)
			await _close(screen)
	_fixture.control_style = GameManifest.CONTROL_STYLE_CUSTOM_KEYS
	_use_fixture_bindings(true)
	_fixture.copy = COPY.duplicate()


func _test_controller_rows() -> void:
	for style: String in [
		GameManifest.CONTROL_STYLE_TARGETS,
		GameManifest.CONTROL_STYLE_DIRECT_MOVEMENT,
		GameManifest.CONTROL_STYLE_CUSTOM_KEYS,
	]:
		_fixture.control_style = style
		var menu := await _open(SETTINGS_MENU)
		if menu == null:
			continue
		for connected: bool in [false, true, false]:
			menu.call("_on_gamepad_availability_changed", connected)
			for path: String in [
				"%ControllerTargetOne", "%ControllerTargetTwo", "%ControllerTargetThree",
			]:
				_expect(
					_row_visible(menu, path)
					== (connected and style == GameManifest.CONTROL_STYLE_TARGETS),
					"Hot-plug must not expose target-controller rows for other styles."
				)
			_expect(
				_row_visible(menu, "%ControllerMovementScheme")
				== (connected and style == GameManifest.CONTROL_STYLE_DIRECT_MOVEMENT),
				"Hot-plug must not misclassify custom keys as direct movement."
			)
			for path: String in ["%ControllerSpeedSlider", "%ControllerDeadzoneSlider"]:
				_expect(
					_row_visible(menu, path)
					== (connected and style != GameManifest.CONTROL_STYLE_CUSTOM_KEYS),
					"Custom keys must not advertise controller movement assists."
				)
			_expect(
				_row_visible(menu, "%ControllerPause") == connected
				and _visible(menu, "%ControllerHint") == (not connected),
				"Universal controller pause and disconnected help must retain their visibility."
			)
			_expect(
				_text(menu, "%BindingStatus").contains("Controller 1")
				== (connected and style != GameManifest.CONTROL_STYLE_CUSTOM_KEYS),
				"Custom-key help must not promise that controllers drive the players."
			)
		_expect(
			_row_visible(menu, "%OneButtonTriangleRushToggle")
			== (style == GameManifest.CONTROL_STYLE_TARGETS),
			"One-button target play must remain specific to target games."
		)
		await _close(menu)


func _configure_session(controller: int) -> void:
	if controller < 0:
		_session.call("configure_single_player")
	else:
		_session.call("configure_multiplayer", controller, 2)


func _press(screen: Node, path: String) -> void:
	(screen.get_node(path) as Button).emit_signal("pressed")


func _choose_opponent(screen: Node, cpu: bool) -> void:
	var button := screen.get_node("%CpuOptionButton" if cpu else "%HumanOptionButton") as Button
	button.button_pressed = true
	button.emit_signal("pressed")


func _text(screen: Node, path: String) -> String:
	return (screen.get_node(path) as Label).text


func _visible(screen: Node, path: String) -> bool:
	return (screen.get_node(path) as Control).visible


func _row_visible(screen: Node, path: String) -> bool:
	return (screen.get_node(path).get_parent() as Control).visible


func _assert_custom_copy(screen: Node) -> void:
	var copy := _visible_copy(screen)
	for forbidden: String in [
		"highlighted target", "mouse", "arrow keys", "controller 1", "pad 1",
		"baby seed", "hard seed", "impossible seed", "pick its difficulty",
	]:
		_expect(
			not copy.containsn(forbidden),
			"Custom-key screens must not advertise unrelated controls: %s." % forbidden
		)


func _visible_copy(node: Node) -> String:
	var result := ""
	if node is Control and not (node as Control).is_visible_in_tree():
		return result
	if node is Label:
		result += (node as Label).text + "\n"
	elif node is Button:
		result += (node as Button).text + "\n"
	for child: Node in node.get_children():
		result += _visible_copy(child)
	return result


func _open(path: String) -> Node:
	var packed := load(path) as PackedScene
	_expect(packed != null, "The screen must load: %s." % path)
	if packed == null:
		return null
	var screen := packed.instantiate()
	if path == SETTINGS_MENU:
		screen.set("game_context_id", FIXTURE_ID)
	get_root().add_child(screen)
	await process_frame
	await process_frame
	return screen


func _close(screen: Node) -> void:
	if is_instance_valid(screen):
		screen.queue_free()
		await process_frame


func _restore_state() -> void:
	_save_timer.stop()
	for property: String in _original_settings:
		_settings.set(property, _original_settings[property])
	for property: String in _original_session:
		_session.set(property, _original_session[property])
	_router.set("_busy", _original_router_busy)
	GameCatalog._manifests = _original_manifests
	GameCatalog._by_id = _original_by_id
	GameCatalog._current_id = _original_current_id
	GameCatalog._forced_single_id = _original_forced_id
	for action: StringName in _original_actions:
		var saved: Dictionary = _original_actions[action]
		if not bool(saved["exists"]):
			if InputMap.has_action(action):
				InputMap.erase_action(action)
			continue
		InputMap.action_set_deadzone(action, float(saved["deadzone"]))
		InputMap.action_erase_events(action)
		for event: InputEvent in saved["events"]:
			InputMap.action_add_event(action, event)
	_save_timer.process_mode = _save_timer_mode
	if _save_timer_remaining > 0.0:
		_save_timer.start(_save_timer_remaining)
	_save_timer.wait_time = _save_timer_wait


func _settings_hash() -> String:
	return FileAccess.get_sha256(SETTINGS_PATH) if FileAccess.file_exists(SETTINGS_PATH) else ""


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)


func _finish() -> void:
	if _failures.is_empty():
		print("Custom-key controls regression passed.")
		quit(0)
		return
	for failure: String in _failures:
		push_error(failure)
	quit(1)
