extends MenuScreen

## An asset-first museum: the manifest owns the exhibits and the game owns the
## stage. Direct manipulation replaces the toolbar; descriptions remain in
## tooltips and accessibility text instead of taking space from the model.

## Assign before add_child(). A standalone build adopts its only game.
var game_context_id := ""

const PITCH_MIN := -1.0472
const PITCH_MAX := 1.2566
const ZOOM_MIN := 0.55
const ZOOM_MAX := 3.2
const YAW_RATE := 1.5708
const PITCH_RATE := 0.9599
const ZOOM_RATE := 2.1
const STEP_SECONDS := 0.22
const SPIN_RATE := 0.3665
const DRAG_YAW := 0.009
const DRAG_PITCH := 0.007
const AXIS_YAW := 0
const AXIS_PITCH := 1
const AXIS_ZOOM := 2
const MIN_LIST_WIDTH := 260.0
const MAX_LIST_WIDTH := 330.0
const TOUCH_TAP_MSEC := 350
const TOUCH_TAP_SLOP := 12.0

@onready var _margins: MarginContainer = %Margins
@onready var _title: Label = %Title
@onready var _body: BoxContainer = %Body
@onready var _list_column: VBoxContainer = %ListColumn
@onready var _stage_column: VBoxContainer = %StageColumn
@onready var _sections: VBoxContainer = %Sections
@onready var _list_scroll: ScrollContainer = %ListScroll
@onready var _viewer: Control = %Viewer
@onready var _viewer_focus: Control = %ViewerFocus
@onready var _stage_host: Control = %StageHost
@onready var _placeholder: Label = %Placeholder
@onready var _exhibit_title: Label = %ExhibitTitle
@onready var _empty: Label = %Empty
@onready var _back_button: Button = %BackButton

var _exhibits: Array[Dictionary] = []
var _buttons: Array[Button] = []
var _headings: Array[Label] = []
var _navigation_styles: Dictionary[StringName, StyleBox] = {}
var _stage: Node
var _stage_orbits := false
var _stage_spins := false
var _stage_configures := false
var _selected := -1
var _yaw := 0.0
var _pitch := 0.0
var _zoom := 1.0
var _auto_spin := true
var _dragging := false
var _reduced_motion := false
var _ui_scale := 1.0
var _full_title := "Gallery"
var _pad_orbit := Vector2.ZERO
var _touches: Dictionary[int, Vector2] = {}
var _touch_started := 0
var _touch_travel := 0.0
var _touch_max_count := 0


func _ready() -> void:
	margins = _margins
	first_focus = _back_button
	_reduced_motion = Settings.reduced_motion_enabled()
	_resolve_game_context()
	_build_stage()
	_build_list()
	_viewer.gui_input.connect(_on_viewer_gui_input)
	_viewer.focus_entered.connect(_on_viewer_focus_entered)
	_viewer.focus_exited.connect(_on_viewer_focus_exited)
	get_window().focus_exited.connect(_cancel_gestures)
	Settings.changed.connect(_on_setting_changed)
	AchievementManager.unlocked.connect(_on_achievement_unlocked)
	super()


func _resolve_game_context() -> void:
	if game_context_id.is_empty() and GameCatalog.is_single_game_build():
		game_context_id = GameCatalog.current_id()


func _manifest() -> GameManifest:
	return GameCatalog.get_manifest(game_context_id)


func _build_stage() -> void:
	var manifest := _manifest()
	_full_title = "%s Gallery" % manifest.title if manifest else "Gallery"
	_title.accessibility_name = _full_title
	_title.tooltip_text = (
		manifest.text("gallery_intro", "Explore this game's models.")
		if manifest else "Gallery"
	)
	_title.accessibility_description = _title.tooltip_text
	if manifest == null or manifest.gallery_stage_scene_path.is_empty():
		return
	if not ResourceLoader.exists(manifest.gallery_stage_scene_path):
		push_warning(
			"Gallery: %s declares a missing stage (%s)."
			% [manifest.id, manifest.gallery_stage_scene_path]
		)
		return
	var packed := load(manifest.gallery_stage_scene_path) as PackedScene
	if packed == null:
		push_warning("Gallery: %s is not a scene." % manifest.gallery_stage_scene_path)
		return
	var stage := packed.instantiate()
	if stage is not Control:
		push_error("Gallery: %s is not a Control." % manifest.gallery_stage_scene_path)
		stage.free()
		return
	_stage = stage
	var view := stage as Control
	view.name = "Stage"
	view.set_anchors_preset(Control.PRESET_FULL_RECT)
	view.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_stage_host.add_child(view)
	_stage_orbits = _stage.has_method("set_view")
	_stage_spins = _stage.has_method("set_auto_spin")
	_stage_configures = _stage.has_method("configure")
	if not _stage_configures:
		push_warning(
			"Gallery: %s has no configure(Dictionary); showing exhibit badges."
			% manifest.gallery_stage_scene_path
		)


func _build_list() -> void:
	for child in _sections.get_children():
		_sections.remove_child(child)
		child.queue_free()
	_buttons.clear()
	_headings.clear()
	_exhibits.clear()
	var manifest := _manifest()
	if manifest != null:
		_exhibits.assign(manifest.gallery_exhibits)
	_empty.visible = _exhibits.is_empty()
	_body.visible = not _exhibits.is_empty()

	var group := ButtonGroup.new()
	var column: VBoxContainer
	var heading := ""
	for index in _exhibits.size():
		var exhibit := _exhibits[index]
		var next_heading := str(exhibit.get("heading", ""))
		if column == null or next_heading != heading:
			heading = next_heading
			column = _add_group(heading)
		column.add_child(_build_button(exhibit, index, group))
	_select(_first_viewable())


func _add_group(heading: String) -> VBoxContainer:
	var section := VBoxContainer.new()
	section.name = "Section%d" % (_sections.get_child_count() + 1)
	section.add_theme_constant_override("separation", 6)
	_sections.add_child(section)
	if not heading.is_empty():
		var label := Label.new()
		label.name = "Heading"
		label.text = heading.to_upper()
		label.theme_type_variation = &"MenuSectionHeading"
		label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		label.add_theme_color_override("font_color", GameCatalog.theme().accent)
		section.add_child(label)
		_headings.append(label)
	var column := VBoxContainer.new()
	column.name = "Items"
	column.add_theme_constant_override("separation", 6)
	section.add_child(column)
	return column


func _build_button(exhibit: Dictionary, index: int, group: ButtonGroup) -> Button:
	var button := Button.new()
	button.name = "Exhibit_%s" % str(exhibit.get("id", index))
	button.theme_type_variation = &"NavigationButton"
	button.text = _exhibit_title_of(exhibit)
	button.accessibility_name = button.text
	button.toggle_mode = true
	button.button_group = group
	button.alignment = HORIZONTAL_ALIGNMENT_LEFT
	button.clip_text = true
	button.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	var reason := _locked_reason(exhibit)
	button.disabled = not reason.is_empty()
	if button.disabled:
		button.text = "Locked: %s" % button.text
	button.tooltip_text = _describe_exhibit(exhibit)
	if button.disabled:
		button.tooltip_text = "%s\n%s" % [reason, button.tooltip_text]
	button.accessibility_description = button.tooltip_text
	button.pressed.connect(_on_exhibit_pressed.bind(index))
	_buttons.append(button)
	return button


func _on_layout_changed(size: Vector2) -> void:
	var portrait := Responsive.is_portrait(size)
	var preference := float(Settings.get_value("ui/scale", 1.0))
	_ui_scale = maxf(1.0, size.x * preference / maxf(get_window().size.x, 1.0) / 1.5)
	_body.vertical = portrait
	_body.move_child(_stage_column, 0 if portrait else 1)
	_body.add_theme_constant_override("separation", roundi(20.0 * _ui_scale))
	_stage_column.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_viewer.custom_minimum_size.y = 180.0 * _ui_scale
	_list_column.size_flags_horizontal = (
		Control.SIZE_EXPAND_FILL if portrait else Control.SIZE_FILL
	)
	_list_column.size_flags_vertical = (
		Control.SIZE_FILL if portrait else Control.SIZE_EXPAND_FILL
	)
	_list_column.custom_minimum_size = Vector2(
		0.0 if portrait else clampf(
			size.x * 0.2, MIN_LIST_WIDTH * _ui_scale, MAX_LIST_WIDTH * _ui_scale
		),
		minf(size.y * 0.24, 200.0 * _ui_scale) if portrait else 0.0
	)
	_title.text = "Gallery" if portrait else _full_title
	_title.add_theme_font_size_override("font_size", roundi(
		(36.0 if portrait else 44.0) * _ui_scale
	))
	_exhibit_title.add_theme_font_size_override("font_size", roundi(24.0 * _ui_scale))
	_empty.add_theme_font_size_override("font_size", roundi(24.0 * _ui_scale))
	_placeholder.add_theme_font_size_override("font_size", roundi(28.0 * _ui_scale))
	_sections.add_theme_constant_override("separation", roundi(18.0 * _ui_scale))
	for heading in _headings:
		heading.add_theme_font_size_override("font_size", roundi(18.0 * _ui_scale))
	for button in _buttons:
		button.custom_minimum_size.y = 66.0 * _ui_scale
		button.add_theme_font_size_override("font_size", roundi(22.0 * _ui_scale))
	_back_button.custom_minimum_size.y = 66.0 * _ui_scale
	_back_button.add_theme_font_size_override("font_size", roundi(24.0 * _ui_scale))
	for frame: Control in [_viewer, _viewer_focus]:
		var border := frame.get_theme_stylebox("panel").duplicate() as StyleBoxFlat
		var width := 3.0 if frame == _viewer_focus else 1.5
		border.set_border_width_all(roundi(width * _ui_scale))
		frame.add_theme_stylebox_override("panel", border)
	_scale_navigation_styles()


func _scale_navigation_styles() -> void:
	if _navigation_styles.is_empty():
		for state: StringName in [&"normal", &"hover", &"pressed", &"disabled", &"focus"]:
			_navigation_styles[state] = get_theme_stylebox(state, &"NavigationButton")
	for state: StringName in _navigation_styles:
		var original := _navigation_styles[state]
		var scaled := original.duplicate() as StyleBox
		for side in [SIDE_LEFT, SIDE_TOP, SIDE_RIGHT, SIDE_BOTTOM]:
			scaled.set_content_margin(side, original.get_content_margin(side) * _ui_scale)
		if state == &"focus" and scaled is StyleBoxFlat:
			scaled.set_border_width_all(roundi(3.0 * _ui_scale))
		if state == &"pressed" and scaled is StyleBoxFlat:
			scaled.border_width_left = roundi(4.0 * _ui_scale)
		_back_button.add_theme_stylebox_override(state, scaled)
		for button in _buttons:
			button.add_theme_stylebox_override(state, scaled)


func _first_viewable() -> int:
	for index in _exhibits.size():
		if _locked_reason(_exhibits[index]).is_empty():
			return index
	return -1


func _select(index: int) -> void:
	_cancel_gestures()
	_selected = index
	for other in _buttons.size():
		_buttons[other].set_pressed_no_signal(other == index)
	if index < 0 or index >= _exhibits.size():
		_selected = -1
		_exhibit_title.text = ""
		_exhibit_title.tooltip_text = ""
		_exhibit_title.accessibility_description = ""
		_viewer.accessibility_name = "Gallery"
		_viewer.accessibility_description = ""
		_show_placeholder("No exhibits yet." if _exhibits.is_empty() else "Exhibits are locked.")
		_sync_interaction()
		return
	var exhibit := _exhibits[index]
	_exhibit_title.text = _exhibit_title_of(exhibit)
	_viewer.accessibility_name = _exhibit_title.text
	if _stage == null or not _stage_configures:
		_show_placeholder(_badge_of(exhibit))
	else:
		_placeholder.hide()
		_stage_host.show()
		_stage.call("configure", exhibit)
	_reset_view()
	_sync_interaction()


func _show_placeholder(text: String) -> void:
	_placeholder.text = text
	_placeholder.show()
	_stage_host.hide()


func _exhibit_title_of(exhibit: Dictionary) -> String:
	var title := str(exhibit.get("title", "")).strip_edges()
	return title if not title.is_empty() else str(exhibit.get("id", "Exhibit")).capitalize()


func _badge_of(exhibit: Dictionary) -> String:
	var badge := str(exhibit.get("badge", "")).strip_edges()
	return badge if not badge.is_empty() else _exhibit_title_of(exhibit)


func _describe_exhibit(exhibit: Dictionary) -> String:
	var lines := PackedStringArray([_exhibit_title_of(exhibit)])
	var description := str(exhibit.get("description", "")).strip_edges()
	if not description.is_empty():
		lines.append(description)
	for fact: Variant in exhibit.get("facts", []):
		var text := str(fact).strip_edges()
		if not text.is_empty():
			lines.append(text)
	return "\n".join(lines)


func _locked_reason(exhibit: Dictionary) -> String:
	var requirement := str(exhibit.get("requires_achievement", ""))
	if requirement.is_empty() or AchievementManager.is_unlocked(requirement):
		return ""
	var achievement := AchievementManager.get_achievement(requirement)
	var title := str(achievement.get("title", ""))
	return "Earn %s to view this." % title if not title.is_empty() else "Locked."


func _can_inspect() -> bool:
	return (
		is_instance_valid(_stage) and _stage.is_inside_tree()
		and _stage_configures and _stage_host.visible
		and _selected >= 0 and _selected < _exhibits.size()
	)


func _can_orbit() -> bool:
	return _can_inspect() and _stage_orbits


func _can_spin() -> bool:
	return _can_inspect() and (_stage_orbits or _stage_spins)


func _spinning() -> bool:
	return (
		_can_spin() and _auto_spin and not _reduced_motion
		and not _dragging and _pad_orbit.is_zero_approx()
	)


func _sync_interaction() -> void:
	if is_queued_for_deletion() or not is_instance_valid(_viewer_focus):
		return
	var interactive := _can_orbit() or _can_spin()
	_viewer.focus_mode = Control.FOCUS_ALL if interactive else Control.FOCUS_NONE
	_viewer.mouse_default_cursor_shape = (
		Control.CURSOR_DRAG if _dragging
		else Control.CURSOR_POINTING_HAND if interactive else Control.CURSOR_ARROW
	)
	_viewer_focus.visible = interactive and _viewer.has_focus()
	if is_instance_valid(_stage) and _stage.is_inside_tree() and _stage_spins:
		_stage.call("set_auto_spin", _spinning())
	set_process(_can_orbit() and (_spinning() or not _pad_orbit.is_zero_approx()))
	if _selected < 0 or _selected >= _exhibits.size():
		return
	var details := _describe_exhibit(_exhibits[_selected])
	var help := PackedStringArray()
	if _can_orbit():
		help.append("Drag to rotate. Scroll to zoom. Double-click to reset.")
		help.append("Touch: drag, pinch to zoom, double-tap to reset.")
		help.append("Keyboard: W/A/S/D rotate, +/- zoom, R resets. Tab changes focus.")
		help.append("Controller: right stick rotates, shoulders zoom, Y resets.")
	if _can_spin():
		if _reduced_motion:
			help.append("Auto-spin is off while Reduced motion is enabled.")
		else:
			help.append("Right-click to %s auto-spin." % ("pause" if _auto_spin else "resume"))
			help.append("Space, controller X or a two-finger tap does the same.")
	if not help.is_empty():
		details += "\n\n" + "\n".join(help)
	_exhibit_title.tooltip_text = details
	_exhibit_title.accessibility_description = details
	_viewer.accessibility_description = details


func _process(delta: float) -> void:
	var moved := false
	if _spinning() and _stage_orbits:
		_yaw = wrapf(_yaw + SPIN_RATE * delta, -PI, PI)
		moved = true
	if _can_orbit() and _viewer.has_focus() and not _pad_orbit.is_zero_approx():
		_nudge(AXIS_YAW, _pad_orbit.x, delta)
		_nudge(AXIS_PITCH, -_pad_orbit.y, delta)
		moved = true
	if moved:
		_apply_view()


func _nudge(axis: int, direction: float, seconds: float) -> void:
	match axis:
		AXIS_YAW:
			_yaw = wrapf(_yaw + direction * YAW_RATE * seconds, -PI, PI)
		AXIS_PITCH:
			_pitch = clampf(_pitch + direction * PITCH_RATE * seconds, PITCH_MIN, PITCH_MAX)
		AXIS_ZOOM:
			_zoom = clampf(_zoom * pow(ZOOM_RATE, direction * seconds), ZOOM_MIN, ZOOM_MAX)


func _on_viewer_gui_input(event: InputEvent) -> void:
	if not (_can_orbit() or _can_spin()):
		return
	if event is InputEventMouseButton:
		if event.device == InputEvent.DEVICE_ID_EMULATION:
			return
		var button := event as InputEventMouseButton
		if button.pressed:
			_viewer.grab_focus()
		match button.button_index:
			MOUSE_BUTTON_RIGHT:
				if button.pressed:
					_toggle_spin()
			MOUSE_BUTTON_LEFT:
				if not _can_orbit():
					return
				if button.pressed and button.double_click:
					_cancel_gestures()
					_reset_view()
				else:
					_dragging = button.pressed
					_sync_interaction()
			MOUSE_BUTTON_WHEEL_UP, MOUSE_BUTTON_WHEEL_DOWN:
				if not _can_orbit() or not button.pressed:
					return
				var direction := 1.0 if button.button_index == MOUSE_BUTTON_WHEEL_UP else -1.0
				_nudge(AXIS_ZOOM, direction, STEP_SECONDS * button.factor)
				_apply_view()
			_:
				return
	elif event is InputEventMouseMotion:
		var motion := event as InputEventMouseMotion
		if motion.device == InputEvent.DEVICE_ID_EMULATION or not _dragging:
			return
		if not (motion.button_mask & MOUSE_BUTTON_MASK_LEFT):
			_cancel_gestures()
			return
		_orbit_by(motion.relative)
	elif event is InputEventScreenTouch:
		_on_touch(event as InputEventScreenTouch)
	elif event is InputEventScreenDrag:
		_on_touch_drag(event as InputEventScreenDrag)
	elif event is InputEventMagnifyGesture and _can_orbit():
		if _touches.is_empty():
			_zoom = clampf(_zoom * (event as InputEventMagnifyGesture).factor, ZOOM_MIN, ZOOM_MAX)
			_apply_view()
	elif event is InputEventKey:
		if not _on_viewer_key(event as InputEventKey):
			return
	else:
		return
	_viewer.accept_event()


func _input(event: InputEvent) -> void:
	# A release over the sidebar (or another Control) must still end a grab.
	if event is InputEventMouseButton:
		var button := event as InputEventMouseButton
		if button.button_index == MOUSE_BUTTON_LEFT and not button.pressed \
			and button.device != InputEvent.DEVICE_ID_EMULATION and _dragging:
			_cancel_gestures()
	elif event is InputEventScreenTouch:
		var touch := event as InputEventScreenTouch
		if not touch.pressed and _touches.has(touch.index) \
			and not _viewer.get_global_rect().has_point(touch.position):
			_cancel_gestures()
	if _viewer.has_focus() and _on_viewer_pad(event):
		get_viewport().set_input_as_handled()


func _on_viewer_key(event: InputEventKey) -> bool:
	if not event.pressed:
		return false
	var code := event.physical_keycode if event.physical_keycode != 0 else event.keycode
	if code == KEY_SPACE:
		if not event.echo:
			_toggle_spin()
		return _can_spin()
	if not _can_orbit():
		return false
	match code:
		KEY_A: _nudge(AXIS_YAW, -1.0, STEP_SECONDS)
		KEY_D: _nudge(AXIS_YAW, 1.0, STEP_SECONDS)
		KEY_W: _nudge(AXIS_PITCH, 1.0, STEP_SECONDS)
		KEY_S: _nudge(AXIS_PITCH, -1.0, STEP_SECONDS)
		KEY_PLUS, KEY_EQUAL, KEY_KP_ADD: _nudge(AXIS_ZOOM, 1.0, STEP_SECONDS)
		KEY_MINUS, KEY_KP_SUBTRACT: _nudge(AXIS_ZOOM, -1.0, STEP_SECONDS)
		KEY_R, KEY_HOME:
			_reset_view()
			return true
		_: return false
	_apply_view()
	return true


func _on_viewer_pad(event: InputEvent) -> bool:
	if event is InputEventJoypadMotion and _can_orbit():
		var motion := event as InputEventJoypadMotion
		if motion.axis not in [JOY_AXIS_RIGHT_X, JOY_AXIS_RIGHT_Y]:
			return false
		var value := motion.axis_value
		var deadzone := Settings.controller_deadzone()
		value = 0.0 if absf(value) <= deadzone else (
			signf(value) * (absf(value) - deadzone) / (1.0 - deadzone)
		)
		_pad_orbit[0 if motion.axis == JOY_AXIS_RIGHT_X else 1] = value
		_sync_interaction()
		return true
	if event is not InputEventJoypadButton:
		return false
	var button := event as InputEventJoypadButton
	if not button.pressed:
		return false
	if button.button_index == JOY_BUTTON_X:
		_toggle_spin()
		return _can_spin()
	if not _can_orbit():
		return false
	match button.button_index:
		JOY_BUTTON_LEFT_SHOULDER: _nudge(AXIS_ZOOM, -1.0, STEP_SECONDS)
		JOY_BUTTON_RIGHT_SHOULDER: _nudge(AXIS_ZOOM, 1.0, STEP_SECONDS)
		JOY_BUTTON_Y:
			_reset_view()
			return true
		_: return false
	_apply_view()
	return true


func _on_touch(event: InputEventScreenTouch) -> void:
	if event.canceled:
		_cancel_gestures()
		return
	if event.pressed:
		_viewer.grab_focus()
		if event.double_tap and _can_orbit():
			_cancel_gestures()
			_reset_view()
			return
		if _touches.is_empty():
			_touch_started = Time.get_ticks_msec()
			_touch_travel = 0.0
			_touch_max_count = 0
		_touches[event.index] = event.position
		_touch_max_count = maxi(_touch_max_count, _touches.size())
		_dragging = true
	elif _touches.has(event.index):
		_touches.erase(event.index)
		if _touches.is_empty():
			var tap := _touch_max_count == 2 \
				and _touch_travel < TOUCH_TAP_SLOP * _ui_scale \
				and Time.get_ticks_msec() - _touch_started <= TOUCH_TAP_MSEC
			_dragging = false
			if tap:
				_toggle_spin()
	_sync_interaction()


func _on_touch_drag(event: InputEventScreenDrag) -> void:
	if not _touches.has(event.index):
		return
	var previous := _touches[event.index]
	var before := _pinch_span()
	_touches[event.index] = event.position
	_touch_travel += previous.distance_to(event.position)
	if not _can_orbit():
		return
	if _touches.size() == 2 and before > 0.0:
		_zoom = clampf(_zoom * _pinch_span() / before, ZOOM_MIN, ZOOM_MAX)
		_apply_view()
	elif _touches.size() == 1 and _touch_max_count == 1:
		_orbit_by(event.relative)


func _pinch_span() -> float:
	if _touches.size() != 2:
		return 0.0
	var points := _touches.values()
	var first: Vector2 = points[0]
	var second: Vector2 = points[1]
	return first.distance_to(second)


func _orbit_by(relative: Vector2) -> void:
	if not _can_orbit():
		return
	_yaw = wrapf(_yaw + relative.x * DRAG_YAW, -PI, PI)
	_pitch = clampf(_pitch + relative.y * DRAG_PITCH, PITCH_MIN, PITCH_MAX)
	_apply_view()


func _reset_view() -> void:
	_yaw = 0.0
	_pitch = 0.0
	_zoom = 1.0
	_apply_view()


func _apply_view() -> void:
	if _can_orbit():
		_stage.call("set_view", _yaw, _pitch, _zoom)


func _toggle_spin() -> void:
	if _can_spin() and not _reduced_motion:
		_auto_spin = not _auto_spin
		_sync_interaction()


func _cancel_gestures() -> void:
	_dragging = false
	_pad_orbit = Vector2.ZERO
	_touches.clear()
	_sync_interaction()


func _on_viewer_focus_entered() -> void:
	_sync_interaction()


func _on_viewer_focus_exited() -> void:
	_cancel_gestures()


func _on_exhibit_pressed(index: int) -> void:
	if index != _selected and not _buttons[index].disabled:
		_select(index)


func _on_achievement_unlocked(_id: String, _achievement: Dictionary) -> void:
	var previous := _selected
	_build_list()
	if previous >= 0 and previous < _exhibits.size():
		_select(previous)
	refresh_layout()
	_attach_sounds.call_deferred()


func _on_setting_changed(key: String, value: Variant) -> void:
	if key == Settings.REDUCED_MOTION_KEY:
		_reduced_motion = bool(value)
		_sync_interaction()


func _on_back_pressed() -> void:
	go_back()
