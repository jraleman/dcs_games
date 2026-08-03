extends MenuScreen

## Settings screen. Every control reads and writes through the Settings
## autoload, which persists and applies the values — nothing is stored here.
##
## Works both as a standalone scene (from the main menu) and as an overlay
## (from the pause menu); MenuScreen.go_back() handles the difference.
##
## Signals are connected in code rather than in the scene so adding a setting
## means touching one file.

const FPS_OPTIONS := [0, 30, 60, 90, 120, 144]

@onready var _master: HSlider = %MasterSlider
@onready var _master_value: Label = %MasterValue
@onready var _music: HSlider = %MusicSlider
@onready var _music_value: Label = %MusicValue
@onready var _sfx: HSlider = %SfxSlider
@onready var _sfx_value: Label = %SfxValue
@onready var _mute: CheckButton = %MuteToggle
@onready var _window_mode: OptionButton = %WindowMode
@onready var _vsync: CheckButton = %VSyncToggle
@onready var _max_fps: OptionButton = %MaxFps
@onready var _ui_scale: HSlider = %UiScaleSlider
@onready var _ui_scale_value: Label = %UiScaleValue
@onready var _show_fps: CheckButton = %ShowFpsToggle

var _syncing := false


func _ready() -> void:
	_populate_options()
	_connect_ui()
	_sync_from_settings()
	Settings.changed.connect(_on_setting_changed)
	super()


func _populate_options() -> void:
	_window_mode.clear()
	_window_mode.add_item("Windowed", Settings.WindowMode.WINDOWED)
	_window_mode.add_item("Fullscreen", Settings.WindowMode.FULLSCREEN)
	_window_mode.add_item("Borderless window", Settings.WindowMode.BORDERLESS)
	# The browser and mobile OSes own the window; don't pretend otherwise.
	_window_mode.disabled = OS.has_feature("web") or OS.has_feature("mobile")

	_max_fps.clear()
	for fps: int in FPS_OPTIONS:
		_max_fps.add_item("Unlimited" if fps == 0 else str(fps), fps)


func _connect_ui() -> void:
	_master.value_changed.connect(_on_volume_changed.bind("audio/master"))
	_music.value_changed.connect(_on_volume_changed.bind("audio/music"))
	_sfx.value_changed.connect(_on_volume_changed.bind("audio/sfx"))
	_mute.toggled.connect(_on_bool_toggled.bind("audio/muted"))
	_vsync.toggled.connect(_on_bool_toggled.bind("display/vsync"))
	_show_fps.toggled.connect(_on_bool_toggled.bind("ui/show_fps"))
	_window_mode.item_selected.connect(_on_window_mode_selected)
	_max_fps.item_selected.connect(_on_max_fps_selected)
	_ui_scale.value_changed.connect(_on_ui_scale_changed)


## Pushes the stored values into the widgets without echoing them back.
func _sync_from_settings() -> void:
	_syncing = true
	_master.value = float(Settings.get_value("audio/master"))
	_music.value = float(Settings.get_value("audio/music"))
	_sfx.value = float(Settings.get_value("audio/sfx"))
	_mute.button_pressed = bool(Settings.get_value("audio/muted"))
	_vsync.button_pressed = bool(Settings.get_value("display/vsync"))
	_show_fps.button_pressed = bool(Settings.get_value("ui/show_fps"))
	_ui_scale.value = float(Settings.get_value("ui/scale"))
	_select_id(_window_mode, int(Settings.get_value("display/window_mode")))
	_select_id(_max_fps, int(Settings.get_value("display/max_fps")))
	_syncing = false
	_refresh_value_labels()


func _select_id(option: OptionButton, id: int) -> void:
	var index := option.get_item_index(id)
	option.selected = index if index >= 0 else 0


func _refresh_value_labels() -> void:
	_master_value.text = "%d%%" % roundi(_master.value * 100.0)
	_music_value.text = "%d%%" % roundi(_music.value * 100.0)
	_sfx_value.text = "%d%%" % roundi(_sfx.value * 100.0)
	_ui_scale_value.text = "%d%%" % roundi(_ui_scale.value * 100.0)


# --- Widget handlers --------------------------------------------------------

func _on_volume_changed(value: float, key: String) -> void:
	_refresh_value_labels()
	if _syncing:
		return
	Settings.set_value(key, value)


func _on_bool_toggled(pressed: bool, key: String) -> void:
	if _syncing:
		return
	Settings.set_value(key, pressed)


func _on_window_mode_selected(index: int) -> void:
	if _syncing:
		return
	Settings.set_value("display/window_mode", _window_mode.get_item_id(index))


func _on_max_fps_selected(index: int) -> void:
	if _syncing:
		return
	Settings.set_value("display/max_fps", _max_fps.get_item_id(index))


func _on_ui_scale_changed(value: float) -> void:
	_refresh_value_labels()
	if _syncing:
		return
	Settings.set_value("ui/scale", value)


func _on_reset_pressed() -> void:
	Settings.reset_to_defaults()
	_sync_from_settings()


func _on_back_pressed() -> void:
	go_back()


## Keeps the widgets honest when something else changes a setting
## (F11 for fullscreen, for instance).
func _on_setting_changed(_key: String, _value: Variant) -> void:
	if not _syncing:
		_sync_from_settings()
