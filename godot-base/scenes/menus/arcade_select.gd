extends MenuScreen

## The secret selector changes how a game is found, never how that game starts.
## Keyboard, pads and independent touch contacts all drive the same town walker.

const Town = preload("res://ui/components/arcade_town.gd")
const WalkPad = preload("res://ui/components/arcade_walk_pad.gd")
const KEY_DIRECTIONS := {
	KEY_W: Vector2.UP, KEY_UP: Vector2.UP,
	KEY_S: Vector2.DOWN, KEY_DOWN: Vector2.DOWN,
	KEY_A: Vector2.LEFT, KEY_LEFT: Vector2.LEFT,
	KEY_D: Vector2.RIGHT, KEY_RIGHT: Vector2.RIGHT,
}
const PAD_DIRECTIONS := {
	JOY_BUTTON_DPAD_UP: Vector2.UP, JOY_BUTTON_DPAD_DOWN: Vector2.DOWN,
	JOY_BUTTON_DPAD_LEFT: Vector2.LEFT, JOY_BUTTON_DPAD_RIGHT: Vector2.RIGHT,
}
const COMPASS: Array[String] = ["right", "down-right", "down", "down-left",
	"left", "up-left", "up", "up-right"]
const KEY_HELP := "WASD / arrows: walk   E / Enter: enter   M: directory   Esc: title"
const PAD_HELP := "Stick / D-pad: walk   A: enter   Y: directory   B: title"

@export_file("*.tscn") var play_scene := "res://scenes/menus/mode_select.tscn"
@export_file("*.tscn") var instructions_scene := "res://scenes/menus/instructions.tscn"

@onready var _town: Town = %Town
@onready var _world_container: SubViewportContainer = %WorldContainer
@onready var _margins: MarginContainer = %Margins
@onready var _layout: VBoxContainer = %Layout
@onready var _heading: Label = %Heading
@onready var _subtitle: Label = %Subtitle
@onready var _controls: Label = %Controls
@onready var _directory_button: Button = %DirectoryButton
@onready var _back_button: Button = %BackButton
@onready var _footer: HBoxContainer = %Footer
@onready var _walk_pad: WalkPad = %WalkPad
@onready var _info_card: PanelContainer = %InfoCard
@onready var _info_scroll: ScrollContainer = %InfoScroll
@onready var _game_title: Label = %GameTitle
@onready var _game_status: Label = %GameStatus
@onready var _wayfinding: Label = %Wayfinding
@onready var _enter_button: Button = %EnterButton
@onready var _directory: Control = %DirectoryOverlay
@onready var _directory_margins: MarginContainer = %DirectoryMargins
@onready var _directory_title: Label = %DirectoryTitle
@onready var _directory_help: Label = %DirectoryHelp
@onready var _directory_close: Button = %DirectoryClose
@onready var _directory_scroll: ScrollContainer = %DirectoryScroll
@onready var _directory_list: VBoxContainer = %DirectoryList

var _directory_buttons: Dictionary[String, Button] = {}
var _held_keys: Dictionary[int, Vector2] = {}
var _held_pad_buttons: Dictionary[Vector2i, Vector2] = {}
var _pad_sticks: Dictionary[int, Vector2] = {}
var _touch_buttons: Dictionary[int, Button] = {}
var _touch_origins: Dictionary[int, Vector2] = {}
var _scroll_finger := -1
var _touch_scroll: ScrollContainer
var _scroll_touch_origin := Vector2.ZERO
var _scroll_origin := 0
var _touch_direction := Vector2.ZERO
var _destination_id := ""
var _touch_mode := false
var _unit := 1.0
var _last_wayfinding := ""


func _ready() -> void:
	var returning := Router.game_selection_return_scene("", "") == scene_file_path
	Router.set_game_selection_origin(scene_file_path)
	margins = _margins
	first_focus = _directory_button
	_town.game_approached.connect(_on_game_approached)
	_town.configure(GameCatalog.all())
	_town.set_reduced_motion(Settings.reduced_motion_enabled())
	_build_directory()
	_directory_list.sort_children.connect(_reveal_directory_focus.call_deferred)
	_directory_scroll.resized.connect(_reveal_directory_focus.call_deferred)
	_refresh_locks()
	if returning and GameCatalog.has(GameCatalog.current_id()):
		_town.stand_at_game(GameCatalog.current_id())
	_refresh_info()
	_subtitle.text = "%d games. One little town." % GameCatalog.all().size()
	_controls.text = PAD_HELP if GameSession.gamepad_connected() else KEY_HELP
	_controls.tooltip_text = KEY_HELP + "\n" + PAD_HELP
	_controls.accessibility_description = _controls.tooltip_text
	accessibility_name = "Arcade Town"
	accessibility_description = _controls.tooltip_text
	_walk_pad.accessibility_name = "Walk"
	_walk_pad.accessibility_description = "Drag in a direction to walk. Use another finger to enter."
	_walk_pad.direction_changed.connect(_on_touch_direction_changed)
	_directory_button.pressed.connect(_toggle_directory)
	_directory_close.pressed.connect(_set_directory_open.bind(false))
	_back_button.pressed.connect(go_back)
	_enter_button.pressed.connect(_enter_nearby)
	_touch_mode = OS.has_feature("mobile") or DisplayServer.is_touchscreen_available()
	_walk_pad.visible = _touch_mode
	Settings.changed.connect(_on_setting_changed)
	AchievementManager.progression_changed.connect(_on_progression_changed)
	Input.joy_connection_changed.connect(_on_pad_connection_changed)
	_world_container.resized.connect(_fit_world)
	super()
	_fit_world()


func _process(_delta: float) -> void:
	if _destination_id.is_empty() or _closing:
		return
	var distance := _town.walker_position().distance_to(_town.door_position(_destination_id))
	var direction := _town.direction_to_game(_destination_id)
	var compass := COMPASS[posmod(roundi(direction.angle() / (PI / 4.0)), 8)]
	var manifest := GameCatalog.get_manifest(_destination_id)
	var text := "%s: %s (%d m)" % [manifest.title, compass, ceili(distance)]
	if distance < Town.DOOR_REACH:
		text = "%s: you are here." % manifest.title
	if text != _last_wayfinding:
		_last_wayfinding = text
		_wayfinding.text = text


func _input(event: InputEvent) -> void:
	if _closing or Router.is_transitioning():
		return
	if event is InputEventMouse and event.device == InputEvent.DEVICE_ID_EMULATION:
		get_viewport().set_input_as_handled()
		return
	if event is InputEventScreenTouch or event is InputEventScreenDrag:
		_set_touch_mode()
		if _handle_touch(event):
			get_viewport().set_input_as_handled()
		return
	if _directory.visible:
		if event.is_action_pressed("ui_cancel") or _is_directory_shortcut(event):
			_set_directory_open(false)
			get_viewport().set_input_as_handled()
		return
	if _is_directory_shortcut(event):
		_set_directory_open(true)
		get_viewport().set_input_as_handled()
	elif event is InputEventKey:
		_handle_key(event)
	elif event is InputEventJoypadButton:
		_handle_pad_button(event)
	elif event is InputEventJoypadMotion:
		_handle_pad_axis(event)


func _handle_key(event: InputEventKey) -> void:
	var key := event.physical_keycode \
		if event.physical_keycode != KEY_NONE else event.keycode
	if KEY_DIRECTIONS.has(key):
		if event.pressed:
			_held_keys[key] = KEY_DIRECTIONS[key]
			_release_focus_for_walking()
		else:
			_held_keys.erase(key)
		_controls.text = KEY_HELP
		_update_walk_input()
		get_viewport().set_input_as_handled()
	elif event.pressed and not event.echo:
		if key == KEY_E or (key == KEY_ENTER and _world_has_focus()):
			_enter_nearby()
			get_viewport().set_input_as_handled()


func _handle_pad_button(event: InputEventJoypadButton) -> void:
	if PAD_DIRECTIONS.has(event.button_index):
		var key := Vector2i(event.device, event.button_index)
		if event.pressed:
			_held_pad_buttons[key] = PAD_DIRECTIONS[event.button_index]
			_release_focus_for_walking()
		else:
			_held_pad_buttons.erase(key)
		_controls.text = PAD_HELP
		_update_walk_input()
		get_viewport().set_input_as_handled()
	elif event.pressed and event.button_index == JOY_BUTTON_A and _world_has_focus():
		_enter_nearby()
		get_viewport().set_input_as_handled()


func _handle_pad_axis(event: InputEventJoypadMotion) -> void:
	if event.axis != JOY_AXIS_LEFT_X and event.axis != JOY_AXIS_LEFT_Y:
		return
	var stick := _pad_sticks.get(event.device, Vector2.ZERO) as Vector2
	stick[event.axis] = event.axis_value
	_pad_sticks[event.device] = stick
	if stick.length() > 0.22:
		_controls.text = PAD_HELP
		_release_focus_for_walking()
	_update_walk_input()
	get_viewport().set_input_as_handled()


func _is_directory_shortcut(event: InputEvent) -> bool:
	if event is InputEventKey:
		var key: int = event.physical_keycode \
			if event.physical_keycode != KEY_NONE else event.keycode
		return event.pressed and not event.echo and key == KEY_M
	return event is InputEventJoypadButton and event.pressed \
		and event.button_index == JOY_BUTTON_Y


func _world_has_focus() -> bool:
	var focus := get_viewport().gui_get_focus_owner()
	return focus == null or focus == _enter_button


func _release_focus_for_walking() -> void:
	var focus := get_viewport().gui_get_focus_owner()
	if focus != null:
		focus.release_focus()


func _update_walk_input() -> void:
	var direction := _touch_direction
	for held: Vector2 in _held_keys.values():
		direction += held
	for held: Vector2 in _held_pad_buttons.values():
		direction += held
	for raw: Vector2 in _pad_sticks.values():
		var length := raw.length()
		if length > 0.22:
			direction += raw.normalized() * minf(1.0, (length - 0.22) / 0.78)
	_town.set_walk_input(direction.limit_length())


func _clear_walk_input() -> void:
	_held_keys.clear()
	_held_pad_buttons.clear()
	_pad_sticks.clear()
	_touch_buttons.clear()
	_touch_origins.clear()
	_scroll_finger = -1
	_touch_scroll = null
	_touch_direction = Vector2.ZERO
	_walk_pad.reset()
	_town.set_walk_input(Vector2.ZERO)


func _on_touch_direction_changed(direction: Vector2) -> void:
	_touch_direction = direction
	_update_walk_input()


func _set_touch_mode() -> void:
	if _touch_mode:
		return
	_touch_mode = true
	_walk_pad.show()
	refresh_layout()


func _handle_touch(event: InputEvent) -> bool:
	if not _directory.visible and _walk_pad.handle_touch(event):
		_release_focus_for_walking()
		return true
	var threshold := 12.0 * viewport_size().x / maxf(get_window().size.x, 1)
	if event is InputEventScreenTouch:
		return _handle_touch_press(event, threshold)
	if event is InputEventScreenDrag:
		return _handle_touch_drag(event, threshold)
	return false


func _handle_touch_press(event: InputEventScreenTouch, threshold: float) -> bool:
	if event.pressed:
		# Scrolling must own its finger too, rather than borrowing the pad's mouse emulation.
		var scroller := _directory_scroll if _directory.visible else _info_scroll
		if _scroll_finger < 0 and scroller.get_global_rect().has_point(event.position):
			_scroll_finger = event.index
			_touch_scroll = scroller
			_scroll_touch_origin = event.position
			_scroll_origin = scroller.scroll_vertical
		var buttons: Array[Button] = [_directory_button, _back_button, _enter_button]
		if _directory.visible:
			buttons.clear()
			buttons.append(_directory_close)
			buttons.append_array(_directory_buttons.values())
		for button in buttons:
			if not button.disabled and button.get_global_rect().has_point(event.position):
				_touch_buttons[event.index] = button
				_touch_origins[event.index] = event.position
				return true
		return event.index == _scroll_finger
	var scrolling := event.index == _scroll_finger
	if scrolling:
		_scroll_finger = -1
		_touch_scroll = null
	if _touch_buttons.has(event.index):
		var button := _touch_buttons[event.index]
		var origin := _touch_origins[event.index]
		_touch_buttons.erase(event.index)
		_touch_origins.erase(event.index)
		if not event.canceled and not button.disabled and button.is_visible_in_tree() \
			and button.get_global_rect().has_point(event.position) \
			and origin.distance_to(event.position) <= threshold:
			button.emit_signal("pressed")
		return true
	return scrolling


func _handle_touch_drag(event: InputEventScreenDrag, threshold: float) -> bool:
	if _touch_origins.has(event.index) \
		and _touch_origins[event.index].distance_to(event.position) > threshold:
		_touch_buttons.erase(event.index)
		_touch_origins.erase(event.index)
	if event.index == _scroll_finger:
		_touch_scroll.scroll_vertical = _scroll_origin + roundi(
			_scroll_touch_origin.y - event.position.y
		)
		return true
	return false


func _on_pad_connection_changed(device: int, connected: bool) -> void:
	if connected:
		_controls.text = PAD_HELP
		return
	_pad_sticks.erase(device)
	for key: Vector2i in _held_pad_buttons.keys():
		if key.x == device:
			_held_pad_buttons.erase(key)
	_update_walk_input()
	if Input.get_connected_joypads().is_empty():
		_controls.text = KEY_HELP


func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_FOCUS_OUT and is_node_ready():
		_clear_walk_input()


func _build_directory() -> void:
	for manifest in GameCatalog.all():
		var button := Button.new()
		button.name = "Destination_" + manifest.id
		button.theme_type_variation = &"NavigationButton"
		button.alignment = HORIZONTAL_ALIGNMENT_LEFT
		button.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		button.pressed.connect(_choose_destination.bind(manifest.id))
		button.focus_entered.connect(_reveal_directory_focus.call_deferred)
		_directory_list.add_child(button)
		_directory_buttons[manifest.id] = button


func _refresh_locks() -> void:
	var index := 0
	for manifest in GameCatalog.all():
		index += 1
		var is_open := AchievementManager.is_game_unlocked(manifest.id)
		_town.set_game_open(manifest.id, is_open)
		var status := "Open" if is_open else "Locked"
		var button := _directory_buttons[manifest.id]
		button.text = "%02d   %s  /  %s" % [index, manifest.title, status]
		button.tooltip_text = manifest.tagline if is_open else _lock_description(manifest.id)
		button.accessibility_name = "%s. %s." % [manifest.title, status]
		button.accessibility_description = "Mark this doorway. " + button.tooltip_text


func _lock_description(id: String) -> String:
	var requirement := AchievementManager.game_requirement_text(id)
	return "Locked. " + (
		requirement if not requirement.is_empty() else "Complete this game's unlock requirements."
	)


func _on_game_approached(_id: String) -> void:
	_refresh_info()
	_info_scroll.scroll_vertical = 0


func _refresh_info() -> void:
	var id := _town.nearby_game()
	if id.is_empty():
		_game_title.text = "Find your next game"
		_game_status.text = "Walk to a doorway. The directory can mark one for you."
		_enter_button.text = "Find a door"
		_enter_button.disabled = true
		_enter_button.accessibility_name = "Walk to a game doorway to enter."
		_enter_button.accessibility_description = _game_status.text
		_game_title.tooltip_text = _game_title.text
		_game_status.tooltip_text = _game_status.text
		return
	var manifest := GameCatalog.get_manifest(id)
	var is_open := AchievementManager.is_game_unlocked(id)
	_game_title.text = manifest.title
	_game_status.text = manifest.tagline if is_open else _lock_description(id)
	_enter_button.text = "Enter" if is_open else "Locked"
	_enter_button.disabled = not is_open
	_enter_button.accessibility_name = "Enter " + manifest.title if is_open \
		else manifest.title + " is locked."
	_enter_button.accessibility_description = _game_status.text
	_game_title.tooltip_text = manifest.title
	_game_status.tooltip_text = _game_status.text


func _toggle_directory() -> void:
	_set_directory_open(not _directory.visible)


func _set_directory_open(open: bool) -> void:
	_clear_walk_input()
	_directory.visible = open
	for button: Button in [_directory_button, _back_button, _enter_button]:
		button.focus_mode = Control.FOCUS_NONE if open else Control.FOCUS_ALL
	if open and not _directory_buttons.is_empty():
		var id := _town.nearby_game()
		var target := _directory_buttons.get(id, _directory_buttons.values()[0]) as Button
		target.grab_focus()
		_reveal_directory_focus.call_deferred()
	else:
		_directory_button.grab_focus()


func _reveal_directory_focus() -> void:
	if not _directory.visible or _scroll_finger >= 0:
		return
	var focus := get_viewport().gui_get_focus_owner()
	if focus != null and _directory_list.is_ancestor_of(focus):
		_directory_scroll.ensure_control_visible(focus)


func _choose_destination(id: String) -> void:
	_destination_id = id
	_last_wayfinding = ""
	_town.mark_destination(id)
	_wayfinding.show()
	_set_directory_open(false)


func _enter_nearby() -> void:
	if _closing or _directory.visible or Router.is_transitioning():
		return
	var id := _town.nearby_game()
	if id.is_empty() or not AchievementManager.is_game_unlocked(id):
		_refresh_info()
		return
	if not GameCatalog.select(id):
		push_error("ArcadeTown: its doorway is no longer in the catalog.")
		return
	_closing = true
	_clear_walk_input()
	for button: Button in [_enter_button, _directory_button, _back_button]:
		button.disabled = true
	Router.start_selected_game(play_scene, instructions_scene)


## Escape closes the directory first; leaving town always returns to a normal title.
func go_back() -> void:
	if _closing:
		return
	if _directory.visible:
		_set_directory_open(false)
		return
	_clear_walk_input()
	super()


func _on_setting_changed(key: String, value: Variant) -> void:
	if key == "accessibility/reduced_motion":
		_town.set_reduced_motion(bool(value))
	elif key == "ui/scale":
		refresh_layout()


func _on_progression_changed(_key: String, _value: bool) -> void:
	_refresh_locks()
	_refresh_info()


func _fit_world() -> void:
	_world_container.stretch_shrink = maxi(
		1, floori(viewport_size().x / maxf(get_window().size.x, 1))
	)
	_town.fit_camera(_world_container.size.x / maxf(_world_container.size.y, 1.0))


func _on_layout_changed(area: Vector2) -> void:
	_clear_walk_input()
	var preference := float(Settings.get_value("ui/scale", 1.0))
	_unit = maxf(1.0, area.x * preference / maxf(get_window().size.x, 1.0) / 1.5)
	var compact := area.x / _unit < 1000.0 or area.y / _unit < 650.0
	var gap := 16.0 * _unit
	var side := _margins.get_theme_constant("margin_left")
	var inner_width := area.x - 2 * side
	_layout.add_theme_constant_override("separation", roundi(gap))
	_footer.add_theme_constant_override("separation", roundi(gap))
	_heading.add_theme_font_size_override("font_size", roundi((30 if compact else 42) * _unit))
	_heading.text = "Arcade" if compact else "Arcade Town"
	_heading.accessibility_name = "Arcade Town"
	_heading.tooltip_text = "Arcade Town"
	_subtitle.visible = not compact
	_subtitle.add_theme_font_size_override("font_size", roundi(20 * _unit))
	_controls.visible = not compact and not _touch_mode
	_controls.add_theme_font_size_override("font_size", roundi(18 * _unit))
	var pad := minf(210.0 * _unit, inner_width * 0.36) if _touch_mode else 0.0
	_walk_pad.custom_minimum_size = Vector2.ONE * pad
	_info_card.custom_minimum_size = Vector2(
		minf(660.0 * _unit, inner_width - pad - (gap if _touch_mode else 0.0)),
		minf((250 if compact else 220) * _unit, area.y * 0.36)
	)
	for button: Button in [
		_directory_button, _back_button, _enter_button, _directory_close,
	]:
		button.custom_minimum_size.y = 72.0 * _unit
		button.add_theme_font_size_override("font_size", roundi(24 * _unit))
	_directory_button.text = "Map" if compact else "Directory"
	_game_title.add_theme_font_size_override("font_size", roundi(28 * _unit))
	for label: Label in [_game_status, _wayfinding, _directory_help]:
		label.add_theme_font_size_override("font_size", roundi(20 * _unit))
	_directory_title.add_theme_font_size_override("font_size", roundi(32 * _unit))
	for button in _directory_buttons.values():
		button.custom_minimum_size.y = 76.0 * _unit
		button.add_theme_font_size_override("font_size", roundi(24 * _unit))
	_directory_list.add_theme_constant_override("separation", roundi(12 * _unit))
	for edge in ["left", "right", "top", "bottom"]:
		_directory_margins.add_theme_constant_override("margin_" + edge,
			_margins.get_theme_constant("margin_" + edge))
	_fit_world()
