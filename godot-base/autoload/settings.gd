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

## Below this window height the UI is scaled up so text and buttons stay
## legible/tappable on small windows and phones. See _update_content_scale().
const AUTO_SCALE_REFERENCE_HEIGHT := 700.0
const AUTO_SCALE_MAX := 2.0

enum WindowMode { WINDOWED, FULLSCREEN, BORDERLESS }

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
}

var _values: Dictionary = {}
var _save_timer: Timer


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS

	_save_timer = Timer.new()
	_save_timer.one_shot = true
	_save_timer.wait_time = SAVE_DEBOUNCE
	_save_timer.timeout.connect(save)
	add_child(_save_timer)

	_values = DEFAULTS.duplicate(true)
	load_settings()

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


## Re-applies every display/ui setting. Also used on startup.
func apply_display() -> void:
	for key: String in _values:
		if key.begins_with("display/") or key.begins_with("ui/"):
			_apply(key, _values[key])


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
