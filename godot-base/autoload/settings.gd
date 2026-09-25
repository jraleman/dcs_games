extends Node

## Player settings: stores values, persists them to `user://settings.cfg`
## and applies the display-related ones.
##
## Audio settings are consumed by AudioManager and UI settings by Router,
## both of which listen to [signal changed] instead of being poked from here.
##
## Add a new setting by adding a key to DEFAULTS; the settings menu reads and
## writes through get_value()/set_value() so nothing else needs to change.

signal changed(key: String, value: Variant)

const SAVE_PATH := "user://settings.cfg"
const SAVE_DEBOUNCE := 0.4
const USER_DATA_MIGRATION_MARKER := "user://.legacy-user-data-migrated-v2"
const USER_DATA_COPY_SUFFIX := ".migration-copy"
const LEGACY_PROJECT_NAMES := ["DCS Base Game", "DeskCanSaw Game Base"]
const LEGACY_USER_FILES := ["settings.cfg", "achievements.cfg"]
const LEGACY_USER_DIRECTORIES := ["shares"]

## Below this window height the UI is scaled up so text and buttons stay
## legible/tappable on small windows and phones. See _update_content_scale().
const AUTO_SCALE_REFERENCE_HEIGHT := 700.0
const AUTO_SCALE_MAX := 2.0
const VISUAL_EFFECTS_KEY := "accessibility/visual_effects"
const REDUCED_MOTION_KEY := "accessibility/reduced_motion"
const AUDIO_CAPTIONS_KEY := "accessibility/audio_captions"
const PLAYER_LABELS_KEY := "accessibility/player_labels"
const ONE_BUTTON_TARGETS_KEY := "accessibility/one_button_targets"
## Pre-rename spelling of [constant ONE_BUTTON_TARGETS_KEY]. The setting is
## gated on the `targets` control style, never on a game, so it was renamed off
## the first game that used it — but a player's saved preference must survive
## that, so [method load_settings] still reads this key when the new one is
## absent. Keep it forever; removing it silently resets those players.
const LEGACY_ONE_BUTTON_TARGETS_KEY := "accessibility/one_button_triangle_rush"
const GAMEPLAY_SPEED_KEY := "accessibility/gameplay_speed"
const TARGET_SIZE_KEY := "accessibility/target_size"
const EXTRA_ROUND_TIME_KEY := "accessibility/extra_round_time"
const CONTROLLER_SPEED_KEY := "accessibility/controller_speed"
const CONTROLLER_DEADZONE_KEY := "accessibility/controller_deadzone"
const ROUND_MODE_KEY := "game/round_mode"
const STARTING_LIVES_KEY := "game/starting_lives"
const MIN_GAMEPLAY_SPEED := 0.6
const MAX_GAMEPLAY_SPEED := 1.0
const MIN_TARGET_SIZE := 1.0
const MAX_TARGET_SIZE := 1.4
const MIN_EXTRA_ROUND_TIME := 0.0
const MAX_EXTRA_ROUND_TIME := 30.0
const MIN_CONTROLLER_SPEED := 0.5
const MAX_CONTROLLER_SPEED := 1.5
const MIN_CONTROLLER_DEADZONE := 0.05
const MAX_CONTROLLER_DEADZONE := 0.5
const MIN_STARTING_LIVES := 1
const MAX_STARTING_LIVES := 9
const DEFAULT_STARTING_LIVES := 3

enum WindowMode { WINDOWED, FULLSCREEN, BORDERLESS }

## What ends a round. The two modes are exclusive alternatives:
##   [code]TIMER[/code] — the round runs until the countdown reaches zero.
##   [code]LIVES[/code] — there is no countdown; each player spends a life per
##                        mistake and the round ends once everyone is out.
##
## The shared [GameShell] reads this once per round, so switching modes never
## reshapes a round that is already being played.
enum RoundMode { TIMER, LIVES }

const PLAYER_ONE_ACTIONS := [
	&"player_one_target_1",
	&"player_one_target_2",
	&"player_one_target_3",
]
const PLAYER_TWO_ACTIONS := [
	&"player_two_target_1",
	&"player_two_target_2",
	&"player_two_target_3",
]
const PLAYER_THREE_ACTIONS := [
	&"player_three_target_1",
	&"player_three_target_2",
	&"player_three_target_3",
]
const CONTROL_ACTIONS := [
	&"player_one_target_1",
	&"player_one_target_2",
	&"player_one_target_3",
	&"player_two_target_1",
	&"player_two_target_2",
	&"player_two_target_3",
]
const CONTROL_SETTING_KEYS := {
	&"player_one_target_1": "controls/player_one_target_1",
	&"player_one_target_2": "controls/player_one_target_2",
	&"player_one_target_3": "controls/player_one_target_3",
	&"player_two_target_1": "controls/player_two_target_1",
	&"player_two_target_2": "controls/player_two_target_2",
	&"player_two_target_3": "controls/player_two_target_3",
	&"player_three_target_1": "controls/player_three_target_1",
	&"player_three_target_2": "controls/player_three_target_2",
	&"player_three_target_3": "controls/player_three_target_3",
}
const RESERVED_CONTROL_KEYS := [KEY_ESCAPE, KEY_F11]
const CONTROLLER_TARGET_KEYS := [
	"controls/controller_target_1",
	"controls/controller_target_2",
	"controls/controller_target_3",
]
const CONTROLLER_PAUSE_KEY := "controls/controller_pause"
const CONTROLLER_MOVEMENT_SCHEME_KEY := "controls/controller_movement_scheme"
const CONTROLLER_BINDING_KEYS := [
	"controls/controller_target_1",
	"controls/controller_target_2",
	"controls/controller_target_3",
	"controls/controller_pause",
]
const CONTROLLER_BUTTON_IDS := [
	JOY_BUTTON_A,
	JOY_BUTTON_B,
	JOY_BUTTON_X,
	JOY_BUTTON_Y,
	JOY_BUTTON_LEFT_SHOULDER,
	JOY_BUTTON_RIGHT_SHOULDER,
	JOY_BUTTON_LEFT_STICK,
	JOY_BUTTON_RIGHT_STICK,
	JOY_BUTTON_DPAD_UP,
	JOY_BUTTON_DPAD_DOWN,
	JOY_BUTTON_DPAD_LEFT,
	JOY_BUTTON_DPAD_RIGHT,
	JOY_BUTTON_START,
	JOY_BUTTON_BACK,
]
const CONTROLLER_DPAD_BUTTON_IDS := [
	JOY_BUTTON_DPAD_UP,
	JOY_BUTTON_DPAD_DOWN,
	JOY_BUTTON_DPAD_LEFT,
	JOY_BUTTON_DPAD_RIGHT,
]

enum ControllerMovementScheme {
	LEFT_STICK_AND_DPAD,
	RIGHT_STICK_AND_DPAD,
	LEFT_STICK_ONLY,
	RIGHT_STICK_ONLY,
}

const DEFAULTS := {
	"audio/master": 0.8,
	"audio/music": 0.7,
	"audio/sfx": 0.8,
	"audio/muted": false,
	"display/window_mode": WindowMode.WINDOWED,
	"display/vsync": true,
	"display/max_fps": 0,
	"ui/scale": 1.0,
	"ui/show_fps": false,
	"accessibility/visual_effects": true,
	"accessibility/reduced_motion": false,
	"accessibility/audio_captions": false,
	"accessibility/player_labels": true,
	"accessibility/one_button_targets": false,
	"accessibility/gameplay_speed": 1.0,
	"accessibility/target_size": 1.0,
	"accessibility/extra_round_time": 0.0,
	"accessibility/controller_speed": 1.0,
	"accessibility/controller_deadzone": 0.22,
	"game/round_mode": RoundMode.TIMER,
	"game/starting_lives": DEFAULT_STARTING_LIVES,
	"game/show_instructions": true,
	"controls/player_one_target_1": KEY_1,
	"controls/player_one_target_2": KEY_2,
	"controls/player_one_target_3": KEY_3,
	"controls/player_two_target_1": KEY_7,
	"controls/player_two_target_2": KEY_8,
	"controls/player_two_target_3": KEY_9,
	"controls/player_three_target_1": KEY_4,
	"controls/player_three_target_2": KEY_5,
	"controls/player_three_target_3": KEY_6,
	"controls/controller_target_1": JOY_BUTTON_A,
	"controls/controller_target_2": JOY_BUTTON_B,
	"controls/controller_target_3": JOY_BUTTON_X,
	"controls/controller_pause": JOY_BUTTON_START,
	"controls/controller_movement_scheme": ControllerMovementScheme.LEFT_STICK_AND_DPAD,
}

var _values: Dictionary = {}
var _tunables: Dictionary = {}
var _options_by_game: Dictionary = {}
var _control_bindings: Dictionary = {}
var _bindings_by_game: Dictionary = {}
var _bindings_by_style: Dictionary = {}
var _registered := false
var _save_timer: Timer


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_migrate_legacy_user_data()

	_save_timer = Timer.new()
	_save_timer.one_shot = true
	_save_timer.wait_time = SAVE_DEBOUNCE
	_save_timer.timeout.connect(save)
	add_child(_save_timer)

	_values = DEFAULTS.duplicate(true)
	# Absence means "use this game's default", not a saved Timer preference.
	_values.erase(ROUND_MODE_KEY)
	_register_games()
	load_settings()
	var repaired_controls := _repair_control_values()
	apply_controls()
	if repaired_controls:
		_save_timer.start()

	var window := get_window()
	if window:
		window.size_changed.connect(_update_content_scale)
	# The window is not guaranteed to be ready during autoload init.
	apply_display.call_deferred()


func get_value(key: String, default: Variant = null) -> Variant:
	if _values.has(key):
		return _values[key]
	if default != null:
		return default
	if key == ROUND_MODE_KEY:
		return _default_round_mode()
	return DEFAULTS.get(key)


func visual_effects_enabled() -> bool:
	return bool(get_value(VISUAL_EFFECTS_KEY, true))


func reduced_motion_enabled() -> bool:
	return bool(get_value(REDUCED_MOTION_KEY, false))


func audio_captions_enabled() -> bool:
	return bool(get_value(AUDIO_CAPTIONS_KEY, false))


func player_labels_enabled() -> bool:
	return bool(get_value(PLAYER_LABELS_KEY, true))


func one_button_targets_enabled() -> bool:
	return bool(get_value(ONE_BUTTON_TARGETS_KEY, false))


func gameplay_speed_scale() -> float:
	return clampf(
		float(get_value(GAMEPLAY_SPEED_KEY, 1.0)),
		MIN_GAMEPLAY_SPEED,
		MAX_GAMEPLAY_SPEED
	)


func target_size_scale() -> float:
	return clampf(
		float(get_value(TARGET_SIZE_KEY, 1.0)),
		MIN_TARGET_SIZE,
		MAX_TARGET_SIZE
	)


func extra_round_time() -> float:
	return clampf(
		float(get_value(EXTRA_ROUND_TIME_KEY, 0.0)),
		MIN_EXTRA_ROUND_TIME,
		MAX_EXTRA_ROUND_TIME
	)


## --- Round mode ------------------------------------------------------------
##
## The countdown and the lives pool are two ways of ending the same round, so
## they are one shared preference rather than a per-game option. [GameShell]
## reads them when a round starts; games only report their own mistakes.


## The saved choice wins; otherwise the manifest supplies the default.
## Pass a game id when running a scene directly, before catalog selection.
func round_mode(game_id := "") -> int:
	var fallback := _default_round_mode(game_id)
	var mode := int(get_value(ROUND_MODE_KEY, fallback))
	if mode != RoundMode.TIMER and mode != RoundMode.LIVES:
		return fallback
	return mode


func lives_mode_enabled(game_id := "") -> bool:
	return round_mode(game_id) == RoundMode.LIVES


func _default_round_mode(game_id := "") -> int:
	var game := (
		GameCatalog.current() if game_id.is_empty()
		else GameCatalog.get_manifest(game_id)
	)
	return RoundMode.LIVES if game != null and game.default_lives_mode else RoundMode.TIMER


## Lives each player starts a round with when [method lives_mode_enabled].
func starting_lives() -> int:
	return clampi(
		int(get_value(STARTING_LIVES_KEY, DEFAULT_STARTING_LIVES)),
		MIN_STARTING_LIVES,
		MAX_STARTING_LIVES
	)


## Player-facing name for a round mode, so menus and HUDs word it identically.
## Omit [param mode] to describe the stored preference.
func round_mode_label(mode := -1) -> String:
	var resolved := round_mode() if mode < 0 else mode
	return "Lives" if resolved == RoundMode.LIVES else "Timer"


## --- Game tunables ---------------------------------------------------------
##
## Games declare their own player-facing options through
## [member GameManifest.tunables]; the framework only stores and clamps them.


## Registered option definitions across every game, keyed by setting key.
func tunables() -> Dictionary:
	_ensure_registered()
	return _tunables


## Options [param game_id] declared, in the order the manifest listed them.
## This is what the in-game Settings → Game tab renders.
func options_for_game(game_id: String) -> Array[Dictionary]:
	_ensure_registered()
	var declared: Array = _options_by_game.get(game_id, [])
	var result: Array[Dictionary] = []
	for definition: Dictionary in declared:
		result.append(definition)
	return result


## Kind of widget [param key] wants: one of the `GameManifest.OPTION_*` values.
func option_type(key: String) -> String:
	var definition: Dictionary = tunables().get(key, {})
	return str(definition.get("type", GameManifest.OPTION_SLIDER))


## Clamped value for a game-declared numeric option.
func tunable(key: String) -> float:
	var definition: Dictionary = tunables().get(key, {})
	var fallback := float(definition.get("default", 0.0))
	return clampf(
		float(get_value(key, fallback)),
		float(definition.get("min", fallback)),
		float(definition.get("max", fallback))
	)


## Value of a game-declared toggle.
func tunable_bool(key: String) -> bool:
	var definition: Dictionary = tunables().get(key, {})
	return bool(get_value(key, definition.get("default", false)))


## Selected id of a game-declared choice list, falling back to the declared
## default when the stored value names a choice the game no longer offers.
func tunable_choice(key: String) -> int:
	var definition: Dictionary = tunables().get(key, {})
	var fallback := int(definition.get("default", 0))
	var value := int(get_value(key, fallback))
	for choice: Dictionary in option_choices(key):
		if int(choice.get("value", 0)) == value:
			return value
	return fallback


## Selectable entries of a choice option, as `{"value": int, "title": String}`.
func option_choices(key: String) -> Array[Dictionary]:
	var definition: Dictionary = tunables().get(key, {})
	var result: Array[Dictionary] = []
	for choice: Variant in definition.get("choices", []):
		if choice is Dictionary:
			result.append(choice)
	return result


## Setup and instructions use the same selected-choice wording, without game branches.
func solo_setup_text(game_id: String, text: String) -> String:
	var manifest := GameCatalog.get_manifest(game_id)
	if manifest == null or manifest.solo_setup_choices.is_empty() or not text.contains("%s"):
		return text
	var labels := PackedStringArray()
	for key: String in manifest.solo_setup_choices:
		var definition: Dictionary = {}
		for candidate: Dictionary in manifest.tunables:
			if str(candidate.get("key", "")) == key:
				definition = candidate
				break
		if definition.is_empty() or str(definition.get("type", "")) != GameManifest.OPTION_CHOICE:
			push_warning("Settings: %s cannot format undeclared solo choice '%s'." % [game_id, key])
			continue
		var value := tunable_choice(key)
		var title := str(value)
		for choice: Dictionary in option_choices(key):
			if int(choice.get("value", 0)) == value:
				title = str(choice.get("summary_title", choice.get("title", value))).strip_edges()
				break
		if title.is_empty():
			title = str(value)
		labels.append(
			"%s: %s" % [str(definition.get("title", key)), title]
			if manifest.solo_setup_choices.size() > 1 else title
		)
	return text.replace("%s", " · ".join(labels)) if not labels.is_empty() else text


## `Vector2` would truncate to 32-bit, so the bounds are exposed separately.
func tunable_min(key: String) -> float:
	var definition: Dictionary = tunables().get(key, {})
	return float(definition.get("min", definition.get("default", 0.0)))


func tunable_max(key: String) -> float:
	var definition: Dictionary = tunables().get(key, {})
	return float(definition.get("max", definition.get("default", 0.0)))


func tunable_step(key: String) -> float:
	var definition: Dictionary = tunables().get(key, {})
	var span := tunable_max(key) - tunable_min(key)
	# A hundred stops reads smoothly on every slider width the project uses.
	return float(definition.get("step", 0.01 if span <= 2.0 else 1.0))


## Renders a slider value the way its declared `format` asks for. Shared with
## the framework's own rows so a generated option is indistinguishable from a
## hand-authored one.
static func format_value(value: float, format: String) -> String:
	match format:
		GameManifest.FORMAT_PERCENT:
			return "%d%%" % roundi(value * 100.0)
		GameManifest.FORMAT_PLUS_PERCENT:
			return (
				"Off"
				if is_zero_approx(value)
				else "+%d%%" % roundi(value * 100.0)
			)
		GameManifest.FORMAT_SECONDS:
			return "%d sec" % roundi(value)
		GameManifest.FORMAT_PLUS_SECONDS:
			return "Off" if is_zero_approx(value) else "+%d sec" % roundi(value)
		GameManifest.FORMAT_MILLISECONDS:
			return "%d ms" % roundi(value)
		GameManifest.FORMAT_LIVES:
			var lives := roundi(value)
			return "%d %s" % [lives, "life" if lives == 1 else "lives"]
		GameManifest.FORMAT_COUNT:
			return str(roundi(value))
		_:
			return (
				str(roundi(value))
				if is_equal_approx(value, roundf(value))
				else "%.2f" % value
			)


## Read-out for one registered option, using the format it declared.
func format_option(key: String, value: float) -> String:
	var definition: Dictionary = tunables().get(key, {})
	return format_value(value, str(definition.get("format", GameManifest.FORMAT_NUMBER)))


## Discovers everything the installed games declare. Runs once, before the
## saved file is read, so stored values land on registered keys.
func _register_games() -> void:
	if _registered:
		return
	_registered = true
	_register_options()
	_register_control_bindings()


func _ensure_registered() -> void:
	if not _registered:
		_register_games()


func _register_options() -> void:
	for manifest in GameCatalog.all():
		var declared: Array[Dictionary] = []
		for definition in manifest.tunables:
			var key := str(definition.get("key", ""))
			if key.is_empty():
				continue
			if _tunables.has(key):
				push_warning("Settings: duplicate option key '%s'." % key)
				continue
			_tunables[key] = definition
			declared.append(definition)
			if not _values.has(key):
				_values[key] = definition.get("default", 0.0)
		_options_by_game[manifest.id] = declared


## Builds the keyboard-binding registry: the framework's own bindings, indexed
## by the control style they serve, plus whatever each game declared.
##
## Nothing here names a game. A game that declares no bindings inherits the
## built-in set for its [member GameManifest.control_style], so a `targets`
## game keeps the six target keys without saying so.
func _register_control_bindings() -> void:
	var built_in_targets: Array[Dictionary] = []
	var actions := CONTROL_ACTIONS + PLAYER_THREE_ACTIONS
	for index in actions.size():
		var action: StringName = actions[index]
		var setting_key := str(CONTROL_SETTING_KEYS[action])
		var player := index / PLAYER_ONE_ACTIONS.size()
		var definition := {
			"key": setting_key,
			"action": action,
			"default": DEFAULTS[setting_key],
			"title": "Target %d" % (index % PLAYER_ONE_ACTIONS.size() + 1),
			"description": (
				"Select, then press a key. Reusing a key swaps the bindings."
			),
			"player": player,
			"heading": "Player %d" % (player + 1),
		}
		_control_bindings[setting_key] = definition
		built_in_targets.append(definition)
	_bindings_by_style[GameManifest.CONTROL_STYLE_TARGETS] = built_in_targets

	for manifest in GameCatalog.all():
		var declared: Array[Dictionary] = []
		for definition in manifest.control_bindings:
			var key := str(definition.get("key", ""))
			if key.is_empty() or not definition.has("default"):
				push_warning(
					"Settings: %s declared a binding without a key or default."
					% manifest.id
				)
				continue
			if _control_bindings.has(key):
				push_warning("Settings: duplicate control binding '%s'." % key)
				continue
			_control_bindings[key] = definition
			declared.append(definition)
			if not _values.has(key):
				_values[key] = int(definition.get("default", KEY_NONE))
		if not declared.is_empty():
			_bindings_by_game[manifest.id] = declared


## Keyboard bindings the Controls tab should offer while [param game_id] runs.
func control_bindings_for_game(game_id: String) -> Array[Dictionary]:
	_ensure_registered()
	var result: Array[Dictionary] = []
	var manifest := GameCatalog.get_manifest(game_id)
	var source: Array = _bindings_by_game.get(game_id, [])
	if source.is_empty():
		var style := (
			manifest.control_style
			if manifest
			else GameManifest.CONTROL_STYLE_TARGETS
		)
		source = _bindings_by_style.get(style, [])
	for definition: Dictionary in source:
		if int(definition.get("player", -1)) >= (manifest.max_local_players if manifest else 2):
			continue
		result.append(definition)
	return result


func controller_movement_scale() -> float:
	return clampf(
		float(get_value(CONTROLLER_SPEED_KEY, 1.0)),
		MIN_CONTROLLER_SPEED,
		MAX_CONTROLLER_SPEED
	)


func controller_deadzone() -> float:
	return clampf(
		float(get_value(CONTROLLER_DEADZONE_KEY, 0.22)),
		MIN_CONTROLLER_DEADZONE,
		MAX_CONTROLLER_DEADZONE
	)


func set_value(key: String, value: Variant) -> void:
	if _values.get(key) == value:
		return
	_values[key] = value
	_apply(key, value)
	changed.emit(key, value)
	_save_timer.start()


## Restores every framework setting and every game-declared option. Progress
## and achievements are stored elsewhere and are never touched.
func reset_to_defaults() -> void:
	_values.erase(ROUND_MODE_KEY)
	changed.emit(ROUND_MODE_KEY, round_mode())
	_save_timer.start()
	for key: String in DEFAULTS:
		if key != ROUND_MODE_KEY:
			set_value(key, DEFAULTS[key])
	for key: String in tunables():
		var definition: Dictionary = _tunables[key]
		set_value(key, definition.get("default", 0.0))


## Restores keyboard and controller bindings. Passing a game id restores only
## that game's keyboard bindings, which is what the in-game Controls tab wants:
## resetting the running game must not silently rebind another one.
func reset_controls_to_defaults(game_id := "") -> void:
	_ensure_registered()
	var bindings := (
		control_bindings_for_game(game_id)
		if not game_id.is_empty()
		else _all_control_bindings()
	)
	for definition: Dictionary in bindings:
		set_value(str(definition["key"]), int(definition.get("default", KEY_NONE)))
	for setting_key: String in CONTROLLER_BINDING_KEYS:
		set_value(setting_key, DEFAULTS[setting_key])
	set_value(
		CONTROLLER_MOVEMENT_SCHEME_KEY,
		DEFAULTS[CONTROLLER_MOVEMENT_SCHEME_KEY]
	)


func _all_control_bindings() -> Array[Dictionary]:
	_ensure_registered()
	var result: Array[Dictionary] = []
	for key: String in _control_bindings:
		result.append(_control_bindings[key])
	return result


## Keyboard actions [param player_index] uses in the selected game. Games that
## declare no bindings fall back to the built-in set for their control style,
## so this keeps describing target games exactly as it always has.
func control_actions_for_player(player_index: int) -> Array[StringName]:
	var result: Array[StringName] = []
	for definition: Dictionary in control_bindings_for_game(GameCatalog.current_id()):
		if int(definition.get("player", -1)) != player_index:
			continue
		var action := StringName(definition.get("action", &""))
		if not action.is_empty():
			result.append(action)
	return result


## Keycode currently bound to an InputMap action, in any registered game.
func control_keycode(action: StringName) -> int:
	var setting_key := _setting_key_for_action(action)
	return binding_keycode(setting_key) if not setting_key.is_empty() else KEY_NONE


func control_key_label(action: StringName) -> String:
	var label := OS.get_keycode_string(control_keycode(action))
	return label if not label.is_empty() else "Unbound"


func control_summary(player_index: int, separator := ", ") -> String:
	var labels := PackedStringArray()
	for action: StringName in control_actions_for_player(player_index):
		labels.append(control_key_label(action))
	return separator.join(labels)


## The movement keys [param game_id] uses, for menus that describe a game's
## controls in one line.
##
## Returns [param fallback] when the game declares no movement bindings, and
## also while every one of them is still at its default — the shipped wording
## ("ARROW KEYS") reads better than four key names, and it is only a lie once
## the player has actually rebound something.
func movement_summary_for_game(
	game_id: String,
	separator := " · ",
	fallback := ""
) -> String:
	var labels := PackedStringArray()
	var customised := false
	for definition: Dictionary in control_bindings_for_game(game_id):
		if not bool(definition.get("movement", false)):
			continue
		var setting_key := str(definition["key"])
		var keycode := binding_keycode(setting_key)
		if keycode != int(definition.get("default", KEY_NONE)):
			customised = true
		labels.append(binding_key_label(setting_key))
	if labels.is_empty() or not customised:
		return fallback
	return separator.join(labels)


func control_action_title(action: StringName) -> String:
	var setting_key := _setting_key_for_action(action)
	return binding_title(setting_key) if not setting_key.is_empty() else "Unknown control"


func binding_keycode(setting_key: String) -> int:
	_ensure_registered()
	var definition: Dictionary = _control_bindings.get(setting_key, {})
	return int(get_value(setting_key, definition.get("default", KEY_NONE)))


func binding_key_label(setting_key: String) -> String:
	var label := OS.get_keycode_string(binding_keycode(setting_key))
	return label if not label.is_empty() else "Unbound"


func binding_title(setting_key: String) -> String:
	_ensure_registered()
	var definition: Dictionary = _control_bindings.get(setting_key, {})
	var title := str(definition.get("title", "")).strip_edges()
	return title if not title.is_empty() else "Unknown control"


func binding_description(setting_key: String) -> String:
	_ensure_registered()
	var definition: Dictionary = _control_bindings.get(setting_key, {})
	return str(definition.get("description", "")).strip_edges()


func is_control_key_allowed(keycode: int) -> bool:
	return keycode != KEY_NONE and not RESERVED_CONTROL_KEYS.has(keycode)


## Rebinds one key. Conflicts are swapped rather than rejected, but only inside
## [param scope_game_id]: two games may share a key without either noticing,
## because only one of them is ever running.
func set_binding_key(
	setting_key: String,
	keycode: int,
	scope_game_id := ""
) -> bool:
	_ensure_registered()
	if not _control_bindings.has(setting_key) or not is_control_key_allowed(keycode):
		return false

	var previous_keycode := binding_keycode(setting_key)
	if previous_keycode == keycode:
		return true

	var scope := (
		control_bindings_for_game(scope_game_id)
		if not scope_game_id.is_empty()
		else _scope_containing(setting_key)
	)
	for definition: Dictionary in scope:
		var candidate := str(definition["key"])
		if candidate != setting_key and binding_keycode(candidate) == keycode:
			set_value(candidate, previous_keycode)
			break
	set_value(setting_key, keycode)
	return true


func set_control_key(action: StringName, keycode: int) -> bool:
	var setting_key := _setting_key_for_action(action)
	return (
		set_binding_key(setting_key, keycode)
		if not setting_key.is_empty()
		else false
	)


func _setting_key_for_action(action: StringName) -> String:
	_ensure_registered()
	for setting_key: String in _control_bindings:
		var definition: Dictionary = _control_bindings[setting_key]
		if StringName(definition.get("action", &"")) == action:
			return setting_key
	return ""


## The group of bindings [param setting_key] belongs to, used when a caller
## rebinds without saying which game it is configuring.
func _scope_containing(setting_key: String) -> Array[Dictionary]:
	for game_id: String in _bindings_by_game:
		for definition: Dictionary in _bindings_by_game[game_id]:
			if str(definition["key"]) == setting_key:
				return _bindings_by_game[game_id]
	for style: String in _bindings_by_style:
		var bindings := _style_control_bindings(style)
		for definition: Dictionary in bindings:
			if str(definition["key"]) == setting_key:
				return bindings
	return []


func _style_control_bindings(style: String) -> Array[Dictionary]:
	var capacity := 2
	for manifest in GameCatalog.all():
		if manifest.control_style == style:
			capacity = maxi(capacity, manifest.max_local_players)
	var result: Array[Dictionary] = []
	for definition: Dictionary in _bindings_by_style.get(style, []):
		if int(definition.get("player", -1)) < capacity:
			result.append(definition)
	return result


func controller_target_button(target_index: int) -> int:
	if target_index < 0 or target_index >= CONTROLLER_TARGET_KEYS.size():
		return -1
	var setting_key: String = CONTROLLER_TARGET_KEYS[target_index]
	return int(get_value(setting_key, DEFAULTS[setting_key]))


func controller_target_index(button: int) -> int:
	for target_index in range(CONTROLLER_TARGET_KEYS.size()):
		if controller_target_button(target_index) == button:
			return target_index
	return -1


func controller_target_summary(separator := "  ") -> String:
	var labels := PackedStringArray()
	for target_index in range(CONTROLLER_TARGET_KEYS.size()):
		labels.append(controller_button_label(controller_target_button(target_index)))
	return separator.join(labels)


func controller_pause_button() -> int:
	return int(get_value(CONTROLLER_PAUSE_KEY, DEFAULTS[CONTROLLER_PAUSE_KEY]))


func controller_movement_scheme() -> int:
	var selected := int(
		get_value(
			CONTROLLER_MOVEMENT_SCHEME_KEY,
			ControllerMovementScheme.LEFT_STICK_AND_DPAD
		)
	)
	return clampi(
		selected,
		ControllerMovementScheme.LEFT_STICK_AND_DPAD,
		ControllerMovementScheme.RIGHT_STICK_ONLY
	)


func controller_uses_right_stick() -> bool:
	return controller_movement_scheme() in [
		ControllerMovementScheme.RIGHT_STICK_AND_DPAD,
		ControllerMovementScheme.RIGHT_STICK_ONLY,
	]


func controller_dpad_enabled() -> bool:
	return controller_movement_scheme() in [
		ControllerMovementScheme.LEFT_STICK_AND_DPAD,
		ControllerMovementScheme.RIGHT_STICK_AND_DPAD,
	]


func controller_movement_scheme_label(scheme: int = -1) -> String:
	var selected := controller_movement_scheme() if scheme < 0 else scheme
	match selected:
		ControllerMovementScheme.RIGHT_STICK_AND_DPAD:
			return "Right stick + D-pad"
		ControllerMovementScheme.LEFT_STICK_ONLY:
			return "Left stick only"
		ControllerMovementScheme.RIGHT_STICK_ONLY:
			return "Right stick only"
		_:
			return "Left stick + D-pad"


func controller_button_label(button: int) -> String:
	match button:
		JOY_BUTTON_A:
			return "A"
		JOY_BUTTON_B:
			return "B"
		JOY_BUTTON_X:
			return "X"
		JOY_BUTTON_Y:
			return "Y"
		JOY_BUTTON_LEFT_SHOULDER:
			return "LB"
		JOY_BUTTON_RIGHT_SHOULDER:
			return "RB"
		JOY_BUTTON_LEFT_STICK:
			return "L3"
		JOY_BUTTON_RIGHT_STICK:
			return "R3"
		JOY_BUTTON_DPAD_UP:
			return "D-pad Up"
		JOY_BUTTON_DPAD_DOWN:
			return "D-pad Down"
		JOY_BUTTON_DPAD_LEFT:
			return "D-pad Left"
		JOY_BUTTON_DPAD_RIGHT:
			return "D-pad Right"
		JOY_BUTTON_START:
			return "Start"
		JOY_BUTTON_BACK:
			return "Back"
	return "Button %d" % button


func is_controller_button_allowed(button: int) -> bool:
	return CONTROLLER_BUTTON_IDS.has(button)


func controller_button_ids_for_setting(setting_key: String) -> Array[int]:
	var result: Array[int] = []
	for button: int in CONTROLLER_BUTTON_IDS:
		if is_controller_button_allowed_for_setting(setting_key, button):
			result.append(button)
	return result


func is_controller_button_allowed_for_setting(
	setting_key: String,
	button: int
) -> bool:
	if not CONTROLLER_BINDING_KEYS.has(setting_key):
		return false
	return (
		is_controller_button_allowed(button)
		and not (
			setting_key == CONTROLLER_PAUSE_KEY
			and CONTROLLER_DPAD_BUTTON_IDS.has(button)
		)
	)


func set_controller_button(setting_key: String, button: int) -> bool:
	if (
		not CONTROLLER_BINDING_KEYS.has(setting_key)
		or not is_controller_button_allowed_for_setting(setting_key, button)
	):
		return false

	var previous_button := int(get_value(setting_key, DEFAULTS[setting_key]))
	if previous_button == button:
		return true

	var conflicting_key := ""
	for candidate: String in CONTROLLER_BINDING_KEYS:
		if candidate != setting_key and int(get_value(candidate)) == button:
			conflicting_key = candidate
			break

	if not conflicting_key.is_empty():
		set_value(conflicting_key, previous_button)
	set_value(setting_key, button)
	return true


## Reads the saved file over the defaults. Every registered key is considered,
## not just the framework's own, so game-declared options and bindings survive
## a restart. A value whose type drifted from its default is ignored, which is
## how settings written by an older build are discarded safely.
func load_settings(path := SAVE_PATH) -> void:
	var config := ConfigFile.new()
	if config.load(path) != OK:
		return
	var keys := _values.keys()
	if not keys.has(ROUND_MODE_KEY):
		keys.append(ROUND_MODE_KEY)
	for key: String in keys:
		var parts := key.split("/", false, 1)
		if parts.size() < 2:
			continue
		var section := parts[0]
		var name := parts[1]
		if not config.has_section_key(section, name):
			continue
		var stored: Variant = config.get_value(section, name)
		var expected: Variant = _values.get(key, DEFAULTS.get(key))
		if typeof(stored) == typeof(expected):
			_values[key] = stored
		elif typeof(expected) == TYPE_FLOAT and typeof(stored) == TYPE_INT:
			# A whole-numbered float round-trips through ConfigFile as an int.
			_values[key] = float(stored)
	_adopt_renamed_keys(config)


## Carries a saved value across a settings key that was renamed. Only applied
## when the new key is absent from the file, so a player who has since set the
## new one keeps their newer choice, and the old key is left on disk rather than
## erased: a shared `user://` may still be read by an older build.
func _adopt_renamed_keys(config: ConfigFile) -> void:
	for renamed: Array in [
		[LEGACY_ONE_BUTTON_TARGETS_KEY, ONE_BUTTON_TARGETS_KEY],
	]:
		var old_key: String = renamed[0]
		var new_key: String = renamed[1]
		var old_parts := old_key.split("/", false, 1)
		var new_parts := new_key.split("/", false, 1)
		if config.has_section_key(new_parts[0], new_parts[1]):
			continue
		if not config.has_section_key(old_parts[0], old_parts[1]):
			continue
		var stored: Variant = config.get_value(old_parts[0], old_parts[1])
		if typeof(stored) == typeof(DEFAULTS.get(new_key)):
			_values[new_key] = stored


func save(path := SAVE_PATH) -> void:
	var config := ConfigFile.new()
	# Start from what is on disk rather than from an empty file: a build that
	# ships one game registers one game's option and binding keys, and rewriting
	# the file from those alone would delete another build's saved values out of
	# a shared `user://`.
	config.load(path)
	if not _values.has(ROUND_MODE_KEY) and config.has_section_key("game", "round_mode"):
		config.erase_section_key("game", "round_mode")
	for key: String in _values:
		var parts := key.split("/", false, 1)
		config.set_value(parts[0], parts[1], _values[key])
	var err := config.save(path)
	if err != OK:
		push_warning("Could not save settings to %s (error %d)" % [path, err])


func _migrate_legacy_user_data() -> void:
	if FileAccess.file_exists(USER_DATA_MIGRATION_MARKER):
		return

	var legacy_parent := _legacy_user_data_parent()
	if legacy_parent.is_empty():
		_write_user_data_migration_marker()
		return

	var destination_root := OS.get_user_data_dir()
	var source_roots: Array[String] = []
	for project_name: String in LEGACY_PROJECT_NAMES:
		var source_root := legacy_parent.path_join(project_name)
		if source_root.simplify_path() != destination_root.simplify_path():
			source_roots.append(source_root)

	var migration_failed := false
	for file_name: String in LEGACY_USER_FILES:
		for source_root: String in source_roots:
			if not FileAccess.file_exists(source_root.path_join(file_name)):
				continue
			var file_error := _copy_missing_file(
				source_root.path_join(file_name),
				destination_root.path_join(file_name)
			)
			if file_error != OK:
				migration_failed = true
				push_warning(
					"Could not migrate %s from %s (error %d)."
					% [file_name, source_root, file_error]
				)
			break

	for directory_name: String in LEGACY_USER_DIRECTORIES:
		for source_root: String in source_roots:
			if not DirAccess.dir_exists_absolute(source_root.path_join(directory_name)):
				continue
			var directory_error := _copy_missing_directory(
				source_root.path_join(directory_name),
				destination_root.path_join(directory_name)
			)
			if directory_error != OK:
				migration_failed = true
				push_warning(
					"Could not migrate %s from %s (error %d)."
					% [directory_name, source_root, directory_error]
				)
				break

	if not migration_failed:
		_write_user_data_migration_marker()


func _legacy_user_data_parent() -> String:
	if OS.has_feature("web"):
		return "/userfs/godot/app_userdata"
	if OS.has_feature("mobile"):
		return ""

	var engine_directory := "Godot" if OS.get_name() in ["Windows", "macOS"] else "godot"
	return OS.get_data_dir().path_join(engine_directory).path_join("app_userdata")


func _copy_missing_file(source_path: String, destination_path: String) -> Error:
	var temporary_path := destination_path + USER_DATA_COPY_SUFFIX
	if FileAccess.file_exists(temporary_path):
		var cleanup_error := DirAccess.remove_absolute(temporary_path)
		if cleanup_error != OK:
			return cleanup_error
	if not FileAccess.file_exists(source_path) or FileAccess.file_exists(destination_path):
		return OK

	var directory_error := DirAccess.make_dir_recursive_absolute(destination_path.get_base_dir())
	if directory_error != OK:
		return directory_error

	var copy_error := DirAccess.copy_absolute(source_path, temporary_path)
	if copy_error != OK:
		if FileAccess.file_exists(temporary_path):
			DirAccess.remove_absolute(temporary_path)
		return copy_error

	if FileAccess.file_exists(destination_path):
		DirAccess.remove_absolute(temporary_path)
		return OK

	var rename_error := DirAccess.rename_absolute(temporary_path, destination_path)
	if rename_error != OK and FileAccess.file_exists(temporary_path):
		DirAccess.remove_absolute(temporary_path)
	return rename_error


func _copy_missing_directory(source_path: String, destination_path: String) -> Error:
	if not DirAccess.dir_exists_absolute(source_path):
		return OK

	var directory_error := DirAccess.make_dir_recursive_absolute(destination_path)
	if directory_error != OK:
		return directory_error

	var source_directory := DirAccess.open(source_path)
	if source_directory == null:
		return ERR_CANT_OPEN

	var list_error := source_directory.list_dir_begin()
	if list_error != OK:
		return list_error
	var entry := source_directory.get_next()
	while not entry.is_empty():
		if entry != "." and entry != "..":
			if source_directory.is_link(entry):
				entry = source_directory.get_next()
				continue
			var source_entry := source_path.path_join(entry)
			var destination_entry := destination_path.path_join(entry)
			var copy_error := (
				_copy_missing_directory(source_entry, destination_entry)
				if source_directory.current_is_dir()
				else _copy_missing_file(source_entry, destination_entry)
			)
			if copy_error != OK:
				source_directory.list_dir_end()
				return copy_error
		entry = source_directory.get_next()
	source_directory.list_dir_end()
	return OK


func _write_user_data_migration_marker() -> void:
	var marker := FileAccess.open(USER_DATA_MIGRATION_MARKER, FileAccess.WRITE)
	if marker == null:
		push_warning(
			"Could not record the user-data migration (error %d)."
			% FileAccess.get_open_error()
		)
		return
	marker.store_string("Legacy user data checked.\n")


## Re-applies every display/ui setting. Also used on startup.
func apply_display() -> void:
	for key: String in _values:
		if key.begins_with("display/") or key.begins_with("ui/"):
			_apply(key, _values[key])


## Pushes every registered keyboard binding into the InputMap. Bindings from
## games that are not running are applied too: their actions are unique, so a
## dormant game costs nothing and never has to re-apply on load.
func apply_controls() -> void:
	for definition: Dictionary in _all_control_bindings():
		var action := StringName(definition.get("action", &""))
		if action.is_empty():
			continue
		if not InputMap.has_action(action):
			InputMap.add_action(action)
		_apply_control_binding(action, binding_keycode(str(definition["key"])))
	_apply_pause_control_binding(controller_pause_button())


func _apply(key: String, value: Variant) -> void:
	match key:
		"display/window_mode":
			_apply_window_mode(int(value))
		"display/vsync":
			DisplayServer.window_set_vsync_mode(
				DisplayServer.VSYNC_ENABLED if bool(value) else DisplayServer.VSYNC_DISABLED
			)
		"display/max_fps":
			Engine.max_fps = int(value)
		"ui/scale":
			_update_content_scale()
		_:
			if key == CONTROLLER_PAUSE_KEY:
				_apply_pause_control_binding(int(value))
			elif key.begins_with("controls/"):
				var action := _control_action_for_setting(key)
				if not action.is_empty():
					_apply_control_binding(action, int(value))


func _apply_control_binding(action: StringName, keycode: int) -> void:
	if not InputMap.has_action(action):
		InputMap.add_action(action)

	var retained_events: Array[InputEvent] = []
	for event: InputEvent in InputMap.action_get_events(action):
		if not event is InputEventKey:
			retained_events.append(event)

	InputMap.action_erase_events(action)
	for event: InputEvent in retained_events:
		InputMap.action_add_event(action, event)

	var key_event := InputEventKey.new()
	key_event.physical_keycode = keycode
	InputMap.action_add_event(action, key_event)


func _apply_pause_control_binding(button: int) -> void:
	const PAUSE_ACTION := &"pause"
	if not InputMap.has_action(PAUSE_ACTION):
		InputMap.add_action(PAUSE_ACTION)

	var retained_events: Array[InputEvent] = []
	for event: InputEvent in InputMap.action_get_events(PAUSE_ACTION):
		if not event is InputEventJoypadButton:
			retained_events.append(event)

	InputMap.action_erase_events(PAUSE_ACTION)
	for event: InputEvent in retained_events:
		InputMap.action_add_event(PAUSE_ACTION, event)

	var button_event := InputEventJoypadButton.new()
	button_event.button_index = button
	InputMap.action_add_event(PAUSE_ACTION, button_event)


func _control_action_for_setting(setting_key: String) -> StringName:
	_ensure_registered()
	var definition: Dictionary = _control_bindings.get(setting_key, {})
	return StringName(definition.get("action", &""))


## Repairs bindings that a hand-edited or stale save left unusable. Each scope
## is checked on its own, so a key shared by two games is not a conflict.
func _repair_control_values() -> bool:
	var repaired := false
	var scopes: Array[Array] = []
	for style: String in _bindings_by_style:
		scopes.append(_style_control_bindings(style))
	for game_id: String in _bindings_by_game:
		scopes.append(_bindings_by_game[game_id])

	for scope: Array in scopes:
		var used_keycodes := {}
		for definition: Dictionary in scope:
			var keycode := binding_keycode(str(definition["key"]))
			if not is_control_key_allowed(keycode) or used_keycodes.has(keycode):
				for reset: Dictionary in scope:
					_values[str(reset["key"])] = int(
						reset.get("default", KEY_NONE)
					)
				repaired = true
				break
			used_keycodes[keycode] = true

	var used_buttons := {}
	for setting_key: String in CONTROLLER_BINDING_KEYS:
		var button := int(get_value(setting_key, -1))
		if (
			not is_controller_button_allowed_for_setting(setting_key, button)
			or used_buttons.has(button)
		):
			for reset_key: String in CONTROLLER_BINDING_KEYS:
				_values[reset_key] = DEFAULTS[reset_key]
			repaired = true
			break
		used_buttons[button] = true

	var movement_scheme := int(get_value(CONTROLLER_MOVEMENT_SCHEME_KEY, -1))
	if (
		movement_scheme < ControllerMovementScheme.LEFT_STICK_AND_DPAD
		or movement_scheme > ControllerMovementScheme.RIGHT_STICK_ONLY
	):
		_values[CONTROLLER_MOVEMENT_SCHEME_KEY] = (
			DEFAULTS[CONTROLLER_MOVEMENT_SCHEME_KEY]
		)
		repaired = true
	return repaired


## Combines the player's UI scale with an automatic boost for small windows.
## The project stretches 1920x1080 with aspect "expand", so the viewport never
## gets *narrower* than the base size — what actually hurts on a small screen
## is physical pixel size, which is what this compensates for.
func _update_content_scale() -> void:
	var window := get_window()
	if window == null:
		return
	var auto_scale := clampf(
		AUTO_SCALE_REFERENCE_HEIGHT / maxf(float(window.size.y), 1.0), 1.0, AUTO_SCALE_MAX
	)
	var factor: float = float(get_value("ui/scale")) * auto_scale
	if not is_equal_approx(window.content_scale_factor, factor):
		window.content_scale_factor = factor


func _apply_window_mode(mode: int) -> void:
	# Mobile and web decide their own window mode; leave them alone.
	if OS.has_feature("mobile") or OS.has_feature("web"):
		return
	match mode:
		WindowMode.FULLSCREEN:
			DisplayServer.window_set_flag(DisplayServer.WINDOW_FLAG_BORDERLESS, false)
			DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)
		WindowMode.BORDERLESS:
			DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
			DisplayServer.window_set_flag(DisplayServer.WINDOW_FLAG_BORDERLESS, true)
			var screen := DisplayServer.window_get_current_screen()
			DisplayServer.window_set_position(DisplayServer.screen_get_position(screen))
			DisplayServer.window_set_size(DisplayServer.screen_get_size(screen))
		_:
			DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
			DisplayServer.window_set_flag(DisplayServer.WINDOW_FLAG_BORDERLESS, false)


func toggle_fullscreen() -> void:
	var fullscreen: bool = int(get_value("display/window_mode")) == WindowMode.FULLSCREEN
	set_value("display/window_mode", WindowMode.WINDOWED if fullscreen else WindowMode.FULLSCREEN)
