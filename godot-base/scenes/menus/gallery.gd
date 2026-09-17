extends MenuScreen

## A museum for a game's models: pick an exhibit, then turn and zoom it.
##
## Everything on the plinths comes from a [GameManifest], so a new game — or a
## new model — appears here without this screen changing. The split is the same
## one the store uses for its cards: **this screen owns the room**, the game owns
## what is standing in it. The framework never learns what a chicken looks like;
## it only knows how to light a list, drive an orbit and word a caption.
##
## There is no Gallery autoload because a gallery saves nothing. A store has a
## wallet to protect; a museum has an opening time and a door.
##
## Which game it exhibits follows the same rule as the Settings screen's
## Controls and Game tabs, and the store's shelves: a standalone build adopts the
## only game it ships, and a collection is told by the pause menu which game is
## running, because a collection's main menu has not chosen a game yet.

## Game whose models this screen shows. Empty resolves in [method
## _resolve_game_context]; assign it before `add_child()`, since `_ready()` is
## what builds the room.
var game_context_id := ""

## Orbit limits. Pitch stops short of the poles because an orbit camera looking
## straight down has no idea which way "up" is, and the view rolls.
const PITCH_MIN := -1.0472
const PITCH_MAX := 1.2566
const ZOOM_MIN := 0.55
const ZOOM_MAX := 3.2

## Rates are per second, and a tap on a button is worth [constant STEP_SECONDS]
## of holding one, so tapping and holding cannot disagree about how fast the
## model turns.
const YAW_RATE := 1.5708
const PITCH_RATE := 0.9599
const ZOOM_RATE := 2.1
const STEP_SECONDS := 0.22
## How long a button is held before it starts repeating, so a tap is one step.
const HOLD_DELAY := 0.32
## A slow turntable: fast enough to show every side inside a few seconds of
## looking, slow enough not to fight a player reaching for the mouse.
const SPIN_RATE := 0.3665

const DRAG_YAW := 0.009
const DRAG_PITCH := 0.007

const AXIS_YAW := 0
const AXIS_PITCH := 1
const AXIS_ZOOM := 2

const MIN_LIST_WIDTH := 268.0
const MAX_LIST_WIDTH := 360.0
const MIN_VIEWER_HEIGHT := 240.0
const HEADING_FONT_SIZE := 22
const HEADING_COLOR := Color(0.686275, 0.866667, 0.917647, 1.0)

@onready var _margins: MarginContainer = %Margins
@onready var _title: Label = %Title
@onready var _body: BoxContainer = %Body
@onready var _list_column: VBoxContainer = %ListColumn
@onready var _stage_column: VBoxContainer = %StageColumn
@onready var _intro: Label = %Intro
@onready var _sections: VBoxContainer = %Sections
@onready var _viewer: Control = %Viewer
@onready var _stage_host: Control = %StageHost
@onready var _placeholder: Label = %Placeholder
@onready var _exhibit_title: Label = %ExhibitTitle
@onready var _exhibit_description: Label = %ExhibitDescription
@onready var _facts: Label = %Facts
@onready var _controls: HFlowContainer = %Controls
@onready var _hint: Label = %Hint
@onready var _spin_toggle: CheckButton = %SpinToggle
@onready var _reset_button: Button = %ResetButton
@onready var _empty: Label = %Empty
@onready var _back_button: Button = %BackButton

var _exhibits: Array[Dictionary] = []
var _buttons: Array[Button] = []
var _stage: Node = null
var _stage_orbits := false
var _stage_spins := false
## A stage scene is game-supplied data, so every call into it is optional. A
## stage that cannot draw an exhibit falls back to the badge placeholder rather
## than raising inside the menu.
var _stage_configures := false
var _selected := -1
var _yaw := 0.0
var _pitch := 0.0
var _zoom := 1.0
var _auto_spin := true
var _dragging := false
var _reduced_motion := false
var _nudges: Array[Dictionary] = []


func _ready() -> void:
	margins = _margins
	first_focus = _back_button
	_reduced_motion = Settings.reduced_motion_enabled()
	_resolve_game_context()
	_build_stage()
	_build_list()
	_wire_controls()
	Settings.changed.connect(_on_setting_changed)
	AchievementManager.unlocked.connect(_on_achievement_unlocked)
	super()


## Adopts the only game in a standalone build, so its models are reachable from
## the main menu rather than only from a paused round — the same rule, and the
## same reasoning, as `settings_menu.gd` and `store.gd`.
func _resolve_game_context() -> void:
	if not game_context_id.is_empty():
		return
	if GameCatalog.is_single_game_build():
		game_context_id = GameCatalog.current_id()


func _manifest() -> GameManifest:
	return GameCatalog.get_manifest(game_context_id)


# --------------------------------------------------------------------------
# Building the room
# --------------------------------------------------------------------------


## Loads the game's own viewer. A missing or malformed stage is not fatal: the
## list still works and the placeholder explains itself, because a gallery that
## cannot draw is still a readable catalogue of what the game contains.
func _build_stage() -> void:
	var manifest := _manifest()
	_title.text = "%s Gallery" % manifest.title if manifest else "Gallery"
	if manifest == null or manifest.gallery_stage_scene_path.is_empty():
		return
	if not ResourceLoader.exists(manifest.gallery_stage_scene_path):
		push_warning(
			"Gallery: %s declares a stage that does not exist (%s)."
			% [manifest.id, manifest.gallery_stage_scene_path]
		)
		return
	var packed: PackedScene = load(manifest.gallery_stage_scene_path)
	if packed == null:
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
			"Gallery: %s has no configure(Dictionary); exhibits will fall back "
			% manifest.gallery_stage_scene_path
			+ "to their badge."
		)


## One button per exhibit, grouped by heading in declaration order — the same
## contract as the store's shelves, so a game groups its models by writing a
## `heading` and nothing else.
func _build_list() -> void:
	for child in _sections.get_children():
		_sections.remove_child(child)
		child.queue_free()
	_buttons.clear()
	_exhibits.clear()

	var manifest := _manifest()
	if manifest != null:
		_exhibits.assign(manifest.gallery_exhibits)
	_empty.visible = _exhibits.is_empty()
	_body.visible = not _exhibits.is_empty()
	_intro.text = _intro_copy(manifest)
	if _exhibits.is_empty():
		_controls.visible = false
		_hint.visible = false
		return

	var group := ButtonGroup.new()
	var column: VBoxContainer = null
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
		label.text = heading
		label.add_theme_font_size_override("font_size", HEADING_FONT_SIZE)
		label.add_theme_color_override("font_color", HEADING_COLOR)
		section.add_child(label)
	var column := VBoxContainer.new()
	column.name = "Items"
	column.add_theme_constant_override("separation", 6)
	section.add_child(column)
	return column


func _build_button(exhibit: Dictionary, index: int, group: ButtonGroup) -> Button:
	var button := Button.new()
	button.name = "Exhibit_%s" % str(exhibit.get("id", index))
	button.text = _exhibit_title_of(exhibit)
	button.toggle_mode = true
	button.button_group = group
	button.alignment = HORIZONTAL_ALIGNMENT_LEFT
	button.clip_text = true
	button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	var accent := exhibit.get("color", Color.TRANSPARENT) as Color
	if accent.a > 0.0:
		# A tint, not the only signal: the title carries the meaning.
		button.add_theme_color_override("font_hover_color", accent.lightened(0.35))
	var reason := _locked_reason(exhibit)
	if not reason.is_empty():
		button.disabled = true
		button.text = "%s  (locked)" % button.text
		button.tooltip_text = reason
	else:
		button.tooltip_text = str(exhibit.get("description", ""))
	button.accessibility_description = button.tooltip_text
	button.pressed.connect(_on_exhibit_pressed.bind(index))
	_buttons.append(button)
	return button


## Wires every nudge control to an axis and a direction, so the orbit has one
## implementation and the buttons are just another way to reach it.
##
## Positive yaw walks the camera anticlockwise around the model, which is what a
## drag to the right does — so ▶ carries +1 and the two cannot disagree.
func _wire_controls() -> void:
	_add_nudge(%TurnLeft, AXIS_YAW, -1.0)
	_add_nudge(%TurnRight, AXIS_YAW, 1.0)
	_add_nudge(%TiltUp, AXIS_PITCH, 1.0)
	_add_nudge(%TiltDown, AXIS_PITCH, -1.0)
	_add_nudge(%ZoomOut, AXIS_ZOOM, -1.0)
	_add_nudge(%ZoomIn, AXIS_ZOOM, 1.0)
	_viewer.gui_input.connect(_on_viewer_gui_input)
	# A stage that cannot orbit gets no orbit controls, rather than buttons that
	# quietly do nothing.
	_controls.visible = _stage_orbits and not _exhibits.is_empty()
	_hint.visible = _controls.visible
	_refresh_spin_toggle()
	set_process(_stage_orbits)


func _add_nudge(button: Button, axis: int, direction: float) -> void:
	_nudges.append({"button": button, "axis": axis, "dir": direction, "held": 0.0})
	button.button_down.connect(_on_nudge_down.bind(axis, direction))


# --------------------------------------------------------------------------
# Layout
# --------------------------------------------------------------------------


func _on_layout_changed(size: Vector2) -> void:
	var portrait := Responsive.is_portrait(size)
	# The list reads as a sidebar in landscape and a drawer under the model in
	# portrait, where there is no room for two columns worth of words.
	_body.vertical = portrait
	_body.move_child(_stage_column, 0 if portrait else 1)
	# Whichever way round they sit, exactly one of the two is allowed to grow:
	# in landscape the model takes the space, and in portrait the list does,
	# because a viewer that expanded downwards would push the list off a phone.
	_stage_column.size_flags_vertical = (
		Control.SIZE_FILL if portrait else Control.SIZE_EXPAND_FILL
	)
	_viewer.size_flags_vertical = (
		Control.SIZE_FILL if portrait else Control.SIZE_EXPAND_FILL
	)
	_list_column.size_flags_horizontal = (
		Control.SIZE_EXPAND_FILL if portrait else Control.SIZE_FILL
	)
	_list_column.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_list_column.custom_minimum_size = Vector2(
		0.0 if portrait else clampf(size.x * 0.24, MIN_LIST_WIDTH, MAX_LIST_WIDTH),
		190.0 if portrait else 0.0
	)
	_viewer.custom_minimum_size.y = maxf(
		MIN_VIEWER_HEIGHT, size.y * (0.34 if portrait else 0.46)
	)
	_title.add_theme_font_size_override(
		"font_size", int(clampf(minf(size.x, size.y) * 0.055, 32.0, 56.0))
	)


# --------------------------------------------------------------------------
# Choosing an exhibit
# --------------------------------------------------------------------------


func _first_viewable() -> int:
	for index in _exhibits.size():
		if _locked_reason(_exhibits[index]).is_empty():
			return index
	return -1


func _select(index: int) -> void:
	_selected = index
	if index < 0 or index >= _exhibits.size():
		_show_placeholder(
			"Nothing on display yet."
			if _exhibits.is_empty()
			else "Keep playing to open the rest of the collection."
		)
		return
	var exhibit := _exhibits[index]
	# The group only unpresses the old button when a real press went through it,
	# so a selection made in code — including the one this screen opens on —
	# has to clear the others itself.
	for other in _buttons.size():
		_buttons[other].set_pressed_no_signal(other == index)
	_exhibit_title.text = _exhibit_title_of(exhibit)
	_exhibit_description.text = str(exhibit.get("description", ""))
	_exhibit_description.visible = not _exhibit_description.text.is_empty()
	_facts.text = _facts_copy(exhibit)
	_facts.visible = not _facts.text.is_empty()
	_reset_view()
	if _stage == null or not _stage_configures:
		_show_placeholder(_badge_of(exhibit))
		return
	_placeholder.visible = false
	_stage_host.visible = true
	_stage.call("configure", exhibit)
	_apply_view()


## The viewer still has to say something when there is no stage to draw with, so
## it falls back to the exhibit's badge — the same "a card always renders"
## contract the store's item art has.
func _show_placeholder(text: String) -> void:
	_placeholder.text = text
	_placeholder.visible = true
	_stage_host.visible = false


func _exhibit_title_of(exhibit: Dictionary) -> String:
	var title := str(exhibit.get("title", "")).strip_edges()
	if not title.is_empty():
		return title
	return str(exhibit.get("id", "Exhibit")).capitalize()


func _badge_of(exhibit: Dictionary) -> String:
	var badge := str(exhibit.get("badge", "")).strip_edges()
	return badge if not badge.is_empty() else _exhibit_title_of(exhibit)


## Facts are the model's specification in words. They exist so the exhibit is
## never carried by the picture alone, which is also what makes the screen work
## for a player who cannot see the plinth.
func _facts_copy(exhibit: Dictionary) -> String:
	var lines := PackedStringArray()
	for fact: Variant in exhibit.get("facts", []):
		var text := str(fact).strip_edges()
		if not text.is_empty():
			lines.append("·  %s" % text)
	return "\n".join(lines)


func _locked_reason(exhibit: Dictionary) -> String:
	var requirement := str(exhibit.get("requires_achievement", ""))
	if requirement.is_empty() or AchievementManager.is_unlocked(requirement):
		return ""
	var achievement := AchievementManager.get_achievement(requirement)
	var title := str(achievement.get("title", ""))
	return "Earn %s to view this." % title if not title.is_empty() else "Locked."


## Names the room without the framework knowing what is in it.
func _intro_copy(manifest: GameManifest) -> String:
	var fallback := "Turn and zoom the models this game is built from."
	return manifest.text("gallery_intro", fallback) if manifest else fallback


# --------------------------------------------------------------------------
# Orbit
# --------------------------------------------------------------------------


func _process(delta: float) -> void:
	var moved := false
	for nudge in _nudges:
		var button := nudge["button"] as Button
		if button == null or not button.button_pressed:
			nudge["held"] = 0.0
			continue
		nudge["held"] = float(nudge["held"]) + delta
		if float(nudge["held"]) < HOLD_DELAY:
			continue
		_nudge(int(nudge["axis"]), float(nudge["dir"]), delta)
		moved = true
	if _spinning():
		_yaw = wrapf(_yaw + SPIN_RATE * delta, -PI, PI)
		moved = true
	if moved:
		_apply_view()


func _spinning() -> bool:
	return (
		_auto_spin
		and not _reduced_motion
		and not _dragging
		and _stage != null
		and _selected >= 0
	)


## A tap is worth [constant STEP_SECONDS] of holding, so the two agree.
func _on_nudge_down(axis: int, direction: float) -> void:
	_nudge(axis, direction, STEP_SECONDS)
	_apply_view()


func _nudge(axis: int, direction: float, seconds: float) -> void:
	match axis:
		AXIS_YAW:
			_yaw = wrapf(_yaw + direction * YAW_RATE * seconds, -PI, PI)
		AXIS_PITCH:
			_pitch = clampf(
				_pitch + direction * PITCH_RATE * seconds, PITCH_MIN, PITCH_MAX
			)
		AXIS_ZOOM:
			_zoom = clampf(_zoom * pow(ZOOM_RATE, direction * seconds), ZOOM_MIN, ZOOM_MAX)


func _on_viewer_gui_input(event: InputEvent) -> void:
	if not _stage_orbits:
		return
	if event is InputEventMouseButton:
		var button := event as InputEventMouseButton
		match button.button_index:
			MOUSE_BUTTON_WHEEL_UP:
				if button.pressed:
					_nudge(AXIS_ZOOM, 1.0, STEP_SECONDS)
					_apply_view()
					_viewer.accept_event()
			MOUSE_BUTTON_WHEEL_DOWN:
				if button.pressed:
					_nudge(AXIS_ZOOM, -1.0, STEP_SECONDS)
					_apply_view()
					_viewer.accept_event()
			MOUSE_BUTTON_LEFT:
				_dragging = button.pressed
				_viewer.accept_event()
	elif event is InputEventMouseMotion and _dragging:
		_orbit_by((event as InputEventMouseMotion).relative)
		_viewer.accept_event()
	elif event is InputEventScreenDrag:
		_orbit_by((event as InputEventScreenDrag).relative)
		_viewer.accept_event()


func _orbit_by(relative: Vector2) -> void:
	_yaw = wrapf(_yaw + relative.x * DRAG_YAW, -PI, PI)
	_pitch = clampf(_pitch + relative.y * DRAG_PITCH, PITCH_MIN, PITCH_MAX)
	_apply_view()


func _reset_view() -> void:
	_yaw = 0.0
	_pitch = 0.0
	_zoom = 1.0
	_dragging = false


func _apply_view() -> void:
	if _stage != null and _stage_orbits:
		_stage.call("set_view", _yaw, _pitch, _zoom)


## Reduced motion parks the turntable and says so, rather than leaving a toggle
## that silently does nothing.
func _refresh_spin_toggle() -> void:
	_spin_toggle.visible = _stage_spins or _stage_orbits
	_spin_toggle.disabled = _reduced_motion
	_spin_toggle.set_pressed_no_signal(_auto_spin and not _reduced_motion)
	_spin_toggle.tooltip_text = (
		"Turned off while Reduced motion is on."
		if _reduced_motion
		else "Turn the model slowly on its own."
	)
	_spin_toggle.accessibility_description = _spin_toggle.tooltip_text
	if _stage != null and _stage_spins:
		_stage.call("set_auto_spin", _spinning())


# --------------------------------------------------------------------------
# Signals
# --------------------------------------------------------------------------


func _on_exhibit_pressed(index: int) -> void:
	if index == _selected:
		return
	_select(index)


func _on_reset_pressed() -> void:
	_reset_view()
	_apply_view()


func _on_spin_toggled(enabled: bool) -> void:
	_auto_spin = enabled
	_refresh_spin_toggle()


## An exhibit gated behind an achievement can unlock while the screen is open,
## because the pause overlay sits on top of a round that is still scoring.
func _on_achievement_unlocked(_id: String, _achievement: Dictionary) -> void:
	var previous := _selected
	_build_list()
	if previous >= 0 and previous < _exhibits.size():
		_select(previous)
	_attach_generated_sounds.call_deferred()


func _attach_generated_sounds() -> void:
	AudioManager.attach_ui_sounds(self)


func _on_setting_changed(key: String, value: Variant) -> void:
	if key != Settings.REDUCED_MOTION_KEY:
		return
	_reduced_motion = bool(value)
	_refresh_spin_toggle()


func _on_back_pressed() -> void:
	go_back()
