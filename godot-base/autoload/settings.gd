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

enum WindowMode { WINDOWED, FULLSCREEN, BORDERLESS }

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
}
const RESERVED_CONTROL_KEYS := [KEY_ESCAPE, KEY_F11]

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
	"game/show_instructions": true,
	"controls/player_one_target_1": KEY_1,
	"controls/player_one_target_2": KEY_2,
	"controls/player_one_target_3": KEY_3,
	"controls/player_two_target_1": KEY_7,
	"controls/player_two_target_2": KEY_8,
	"controls/player_two_target_3": KEY_9,
}

var _values: Dictionary = {}
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
	return DEFAULTS.get(key)


func set_value(key: String, value: Variant) -> void:
	if _values.get(key) == value:
		return
	_values[key] = value
	_apply(key, value)
	changed.emit(key, value)
	_save_timer.start()


func reset_to_defaults() -> void:
	for key: String in DEFAULTS:
		set_value(key, DEFAULTS[key])


func reset_controls_to_defaults() -> void:
	for action: StringName in CONTROL_ACTIONS:
		var setting_key := str(CONTROL_SETTING_KEYS[action])
		set_value(setting_key, DEFAULTS[setting_key])


func control_actions_for_player(player_index: int) -> Array[StringName]:
	var result: Array[StringName] = []
	var source: Array = []
	match player_index:
		0:
			source = PLAYER_ONE_ACTIONS
		1:
			source = PLAYER_TWO_ACTIONS
	for action: StringName in source:
		result.append(action)
	return result


func control_keycode(action: StringName) -> int:
	if not CONTROL_SETTING_KEYS.has(action):
		return KEY_NONE
	var setting_key := str(CONTROL_SETTING_KEYS[action])
	return int(get_value(setting_key, KEY_NONE))


func control_key_label(action: StringName) -> String:
	var label := OS.get_keycode_string(control_keycode(action))
	return label if not label.is_empty() else "Unbound"


func control_summary(player_index: int, separator := ", ") -> String:
	var labels := PackedStringArray()
	for action: StringName in control_actions_for_player(player_index):
		labels.append(control_key_label(action))
	return separator.join(labels)


func control_action_title(action: StringName) -> String:
	var action_index := CONTROL_ACTIONS.find(action)
	if action_index < 0:
		return "Unknown control"
	var player_number := 1 if action_index < PLAYER_ONE_ACTIONS.size() else 2
	var target_number := action_index % PLAYER_ONE_ACTIONS.size() + 1
	return "Player %d target %d" % [player_number, target_number]


func is_control_key_allowed(keycode: int) -> bool:
	return keycode != KEY_NONE and not RESERVED_CONTROL_KEYS.has(keycode)


func set_control_key(action: StringName, keycode: int) -> bool:
	if not CONTROL_SETTING_KEYS.has(action) or not is_control_key_allowed(keycode):
		return false

	var setting_key := str(CONTROL_SETTING_KEYS[action])
	var previous_keycode := control_keycode(action)
	if previous_keycode == keycode:
		return true

	var conflicting_action: StringName = &""
	for candidate: StringName in CONTROL_ACTIONS:
		if candidate != action and control_keycode(candidate) == keycode:
			conflicting_action = candidate
			break

	if not conflicting_action.is_empty():
		set_value(str(CONTROL_SETTING_KEYS[conflicting_action]), previous_keycode)
	set_value(setting_key, keycode)
	return true


func load_settings() -> void:
	var config := ConfigFile.new()
	if config.load(SAVE_PATH) != OK:
		return
	for key: String in DEFAULTS:
		var parts := key.split("/", false, 1)
		var section := parts[0]
		var name := parts[1]
		if config.has_section_key(section, name):
			var stored: Variant = config.get_value(section, name)
			# Ignore values whose type drifted from the default (old save files).
			if typeof(stored) == typeof(DEFAULTS[key]):
				_values[key] = stored


func save() -> void:
	var config := ConfigFile.new()
	for key: String in _values:
		var parts := key.split("/", false, 1)
		config.set_value(parts[0], parts[1], _values[key])
	var err := config.save(SAVE_PATH)
	if err != OK:
		push_warning("Could not save settings to %s (error %d)" % [SAVE_PATH, err])


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


func apply_controls() -> void:
	for action: StringName in CONTROL_ACTIONS:
		if not InputMap.has_action(action):
			InputMap.add_action(action)
		_apply_control_binding(action, control_keycode(action))


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
			if key.begins_with("controls/"):
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


func _control_action_for_setting(setting_key: String) -> StringName:
	for action: StringName in CONTROL_ACTIONS:
		if str(CONTROL_SETTING_KEYS[action]) == setting_key:
			return action
	return &""


func _repair_control_values() -> bool:
	var used_keycodes := {}
	for action: StringName in CONTROL_ACTIONS:
		var keycode := control_keycode(action)
		if not is_control_key_allowed(keycode) or used_keycodes.has(keycode):
			for reset_action: StringName in CONTROL_ACTIONS:
				var setting_key := str(CONTROL_SETTING_KEYS[reset_action])
				_values[setting_key] = DEFAULTS[setting_key]
			return true
		used_keycodes[keycode] = true
	return false


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
