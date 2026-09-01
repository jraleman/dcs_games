extends Node

## Development-only recorder for the "How to play" clips shown by the
## instructions screen.
##
## It runs the real gameplay scene, plays it with a scripted demo player and
## overlays numbered step captions, then quits so Godot's Movie Maker can close
## the file. Nothing here ships with the game; see `tools/record_tutorials.ps1`.
##
##     godot --path godot-base --resolution 1280x720 \
##         --write-movie build/target_rush.avi \
##         res://tools/tutorial_capture.tscn ++ --game=target_rush

const TARGET_RUSH := "target_rush"
const SLICE_AND_SLASH := "slice_and_slash"

const FADE_IN := 0.6
const FADE_OUT := 1.0
const KEYCAP_HOLD := 0.55
const CLIP_DURATION := 24.0

## Non-persistent Settings overrides so a developer's saved preferences cannot
## change what the recording looks like. Written straight into the backing
## dictionary because `Settings.set_value()` would persist them.
const SETTING_OVERRIDES := {
	"ui/show_fps": false,
	"accessibility/visual_effects": true,
	"accessibility/reduced_motion": false,
	"accessibility/audio_captions": false,
	"accessibility/player_labels": true,
	"accessibility/one_button_target_rush": false,
	"accessibility/gameplay_speed": 1.0,
	"accessibility/target_size": 1.0,
	"accessibility/extra_round_time": 0.0,
	"game/triangle_size": 1.0,
	"game/triangle_speed": 1.0,
	"game/triangle_speed_rush": 0.35,
	"game/triangle_round_length": 30.0,
}

const TARGET_RUSH_STEPS: Array[Dictionary] = [
	{
		"time": 0.0,
		"title": "Follow the bright triangle",
		"body": "One of your triangles lights up at a time. That one is your target.",
	},
	{
		"time": 4.6,
		"title": "Press its key to score",
		"body": "Tap 1, 2 or 3 — or click the triangle — to bank +1 point.",
	},
	{
		"time": 10.0,
		"title": "A dim triangle costs you",
		"body": "Hitting the wrong one subtracts a point and resets your streak.",
	},
	{
		"time": 14.8,
		"title": "Chain hits into a streak",
		"body": "Fast, accurate answers stack up your best combo of the round.",
	},
	{
		"time": 19.4,
		"title": "Beat the clock",
		"body": "Triangles speed up near the end. The highest score at zero wins.",
	},
]

const SLICE_STEPS: Array[Dictionary] = [
	{
		"time": 0.0,
		"title": "Cans drop onto the desk",
		"body": "Aluminium cans fall across the workshop bench, one after another.",
	},
	{
		"time": 4.6,
		"title": "Drive your chainsaw",
		"body": "Move Player 1 with the mouse, the arrow keys or a controller.",
	},
	{
		"time": 9.4,
		"title": "Touch a can to slice it",
		"body": "The chain cuts on contact. Every can bursts into sparks for +1.",
	},
	{
		"time": 14.6,
		"title": "Do not let cans land",
		"body": "A can that reaches the floor clatters away and breaks your streak.",
	},
	{
		"time": 19.4,
		"title": "Slice fast for a combo",
		"body": "Back-to-back cuts build the streak that decides the round.",
	},
]

const TARGET_RUSH_WRONG_PRESS_TIME := 11.4
const TARGET_RUSH_REACTION := 0.52
## While this step is on screen the demo player parks the chainsaw so a few
## cans reach the floor and the clatter penalty is actually shown.
const SLICE_IDLE_WINDOW := Vector2(15.0, 18.6)

var _game := TARGET_RUSH
var _steps: Array[Dictionary] = TARGET_RUSH_STEPS
var _elapsed := 0.0
var _step_index := -1
var _scene: Node

var _fade: ColorRect
var _caption_card: PanelContainer
var _step_badge: Label
var _step_title: Label
var _step_body: Label
var _keycap_column: VBoxContainer
var _keycap: PanelContainer
var _keycap_label: Label
var _keycap_time := -1.0
var _caption_tween: Tween

var _last_active_target: Object
var _press_due := -1.0
var _wrong_press_done := false
var _pending_releases: Array[InputEventKey] = []
var _saw_position := Vector2.ZERO


func _ready() -> void:
	_game = _requested_game()
	_steps = SLICE_STEPS if _game == SLICE_AND_SLASH else TARGET_RUSH_STEPS
	AudioServer.set_bus_mute(AudioServer.get_bus_index(&"Master"), true)
	_apply_setting_overrides()
	_configure_session()
	_build_overlay()
	_scene = load(GameCatalog.current_gameplay_scene_path()).instantiate()
	add_child(_scene)
	move_child(_scene, 0)
	_hide_duplicate_hint.call_deferred()
	_advance_step.call_deferred()


func _process(delta: float) -> void:
	_flush_key_releases()
	_elapsed += delta
	_update_fade()
	_update_keycap(delta)

	while (
		_step_index + 1 < _steps.size()
		and _elapsed >= float(_steps[_step_index + 1]["time"])
	):
		_advance_step()

	if _game == SLICE_AND_SLASH:
		_drive_slice_and_slash(delta)
	else:
		_drive_target_rush()

	if _elapsed >= CLIP_DURATION:
		set_process(false)
		get_tree().quit()


# --- Configuration ----------------------------------------------------------

func _requested_game() -> String:
	var arguments := OS.get_cmdline_user_args()
	arguments.append_array(OS.get_cmdline_args())
	for argument in arguments:
		if not argument.begins_with("--game="):
			continue
		var requested := argument.trim_prefix("--game=").strip_edges()
		if requested == SLICE_AND_SLASH or requested == TARGET_RUSH:
			return requested
		push_warning("Unknown --game=%s; recording Target Rush." % requested)
		return TARGET_RUSH
	return TARGET_RUSH


func _apply_setting_overrides() -> void:
	var values: Variant = Settings.get("_values")
	if not values is Dictionary:
		return
	for key: String in SETTING_OVERRIDES:
		(values as Dictionary)[key] = SETTING_OVERRIDES[key]


func _configure_session() -> void:
	GameCatalog.select(_game)
	GameSession.configure_single_player()


# --- Overlay ----------------------------------------------------------------

func _build_overlay() -> void:
	var layer := CanvasLayer.new()
	layer.layer = 64
	add_child(layer)

	var root := Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(root)

	_caption_card = PanelContainer.new()
	_caption_card.add_theme_stylebox_override("panel", _caption_style())
	_caption_card.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_caption_card.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	_caption_card.offset_left = 118.0
	_caption_card.offset_right = -118.0
	_caption_card.offset_top = -232.0
	_caption_card.offset_bottom = -52.0
	root.add_child(_caption_card)

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 26)
	_caption_card.add_child(row)

	_step_badge = Label.new()
	_step_badge.custom_minimum_size = Vector2(78, 0)
	_step_badge.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_step_badge.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_step_badge.add_theme_font_size_override("font_size", 62)
	_step_badge.add_theme_color_override("font_color", StudioInfo.SKY)
	row.add_child(_step_badge)

	var text_column := VBoxContainer.new()
	text_column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	text_column.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	text_column.add_theme_constant_override("separation", 4)
	row.add_child(text_column)

	var eyebrow := Label.new()
	eyebrow.text = "HOW TO PLAY · %s" % GameSession.game_title().to_upper()
	eyebrow.add_theme_font_size_override("font_size", 21)
	eyebrow.add_theme_color_override("font_color", Color(StudioInfo.SKY, 0.85))
	text_column.add_child(eyebrow)

	_step_title = Label.new()
	_step_title.add_theme_font_size_override("font_size", 46)
	_step_title.add_theme_color_override("font_color", StudioInfo.CREAM)
	text_column.add_child(_step_title)

	_step_body = Label.new()
	_step_body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_step_body.add_theme_font_size_override("font_size", 27)
	_step_body.add_theme_color_override("font_color", StudioInfo.MUTED)
	text_column.add_child(_step_body)

	_keycap_column = VBoxContainer.new()
	_keycap_column.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_keycap_column.add_theme_constant_override("separation", 6)
	_keycap_column.visible = _game == TARGET_RUSH
	row.add_child(_keycap_column)

	var keycap_caption := Label.new()
	keycap_caption.text = "PRESSED"
	keycap_caption.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	keycap_caption.add_theme_font_size_override("font_size", 17)
	keycap_caption.add_theme_color_override("font_color", StudioInfo.MUTED)
	_keycap_column.add_child(keycap_caption)

	_keycap = PanelContainer.new()
	_keycap.add_theme_stylebox_override("panel", _keycap_style())
	_keycap.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_keycap.custom_minimum_size = Vector2(96, 96)
	_keycap.pivot_offset = Vector2(48, 48)
	_keycap.modulate.a = 0.0
	_keycap_column.add_child(_keycap)

	_keycap_label = Label.new()
	_keycap_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_keycap_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_keycap_label.add_theme_font_size_override("font_size", 46)
	_keycap_label.add_theme_color_override("font_color", StudioInfo.CREAM)
	_keycap.add_child(_keycap_label)

	_fade = ColorRect.new()
	_fade.color = Color(0, 0, 0, 1)
	_fade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_fade.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.add_child(_fade)


## The gameplay HUD repeats the controls along the bottom edge, exactly where
## the caption card sits. The captions say it better for a recording.
func _hide_duplicate_hint() -> void:
	var hint := _scene.find_child("HintPanel", true, false) as CanvasItem
	if hint != null:
		hint.hide()


func _caption_style() -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.035, 0.078, 0.106, 0.93)
	style.border_color = Color(StudioInfo.SKY, 0.55)
	style.set_border_width_all(2)
	style.set_corner_radius_all(20)
	style.set_content_margin_all(26)
	style.shadow_color = Color(0, 0, 0, 0.45)
	style.shadow_size = 16
	return style


func _keycap_style() -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.035, 0.11, 0.176, 0.95)
	style.border_color = Color(0.302, 0.639, 1.0, 0.9)
	style.set_border_width_all(3)
	style.set_corner_radius_all(18)
	style.shadow_color = Color(0.02, 0.212, 0.42, 0.5)
	style.shadow_size = 12
	return style


func _advance_step() -> void:
	_step_index += 1
	if _step_index >= _steps.size():
		return
	var step: Dictionary = _steps[_step_index]
	_step_badge.text = "%d" % (_step_index + 1)
	_step_title.text = str(step["title"])
	_step_body.text = str(step["body"])
	if _caption_tween and _caption_tween.is_valid():
		_caption_tween.kill()
	_caption_card.modulate.a = 0.0
	_caption_tween = create_tween().set_trans(Tween.TRANS_QUART).set_ease(Tween.EASE_OUT)
	_caption_tween.tween_property(_caption_card, "modulate:a", 1.0, 0.32)


func _update_fade() -> void:
	var alpha := 0.0
	if _elapsed < FADE_IN:
		alpha = 1.0 - _elapsed / FADE_IN
	elif _elapsed > CLIP_DURATION - FADE_OUT:
		alpha = (_elapsed - (CLIP_DURATION - FADE_OUT)) / FADE_OUT
	_fade.color.a = clampf(alpha, 0.0, 1.0)


func _show_keycap(text: String) -> void:
	_keycap_label.text = text
	_keycap_time = KEYCAP_HOLD
	_keycap.modulate.a = 1.0
	_keycap.scale = Vector2(1.22, 1.22)


func _update_keycap(delta: float) -> void:
	if _keycap_time < 0.0:
		return
	_keycap_time -= delta
	_keycap.scale = _keycap.scale.lerp(Vector2.ONE, clampf(delta * 14.0, 0.0, 1.0))
	if _keycap_time > 0.0:
		return
	_keycap.modulate.a = maxf(_keycap.modulate.a - delta * 4.0, 0.0)
	if is_zero_approx(_keycap.modulate.a):
		_keycap_time = -1.0


# --- Scripted demo player ---------------------------------------------------

func _drive_target_rush() -> void:
	if not bool(_scene.get("_round_active")):
		return

	var active := _scene.get("_active_targets")[0] as TriangleTarget
	if active == null:
		return
	if active != _last_active_target:
		_last_active_target = active
		_press_due = _elapsed + TARGET_RUSH_REACTION + randf() * 0.16

	if _press_due < 0.0 or _elapsed < _press_due:
		return
	_press_due = -1.0

	if not _wrong_press_done and _elapsed >= TARGET_RUSH_WRONG_PRESS_TIME:
		_wrong_press_done = true
		var decoy := _decoy_target(active)
		if decoy != null:
			_press_target(decoy)
			return
	_press_target(active)


func _decoy_target(active: TriangleTarget) -> TriangleTarget:
	for entry in _scene.get("_targets"):
		var target := entry as TriangleTarget
		if target != null and target != active and target.player_index == 0:
			return target
	return null


func _press_target(target: TriangleTarget) -> void:
	var action := _action_for_target(target)
	if action == &"":
		return
	for event in InputMap.action_get_events(action):
		if not event is InputEventKey:
			continue
		var press := (event as InputEventKey).duplicate() as InputEventKey
		press.pressed = true
		press.echo = false
		Input.parse_input_event(press)
		_pending_releases.append(press)
		_show_keycap(Settings.control_key_label(action))
		return


func _action_for_target(target: TriangleTarget) -> StringName:
	var by_action: Dictionary = _scene.get("_targets_by_action")
	for action: StringName in by_action:
		if by_action[action] == target:
			return action
	return &""


func _flush_key_releases() -> void:
	for press in _pending_releases:
		var release := press.duplicate() as InputEventKey
		release.pressed = false
		Input.parse_input_event(release)
	_pending_releases.clear()


func _drive_slice_and_slash(delta: float) -> void:
	if not bool(_scene.get("_round_active")):
		return

	var bounds: Rect2 = _scene.call("_playfield_bounds")
	if _saw_position.is_zero_approx():
		_saw_position = bounds.get_center()

	_saw_position = _saw_position.lerp(
		_slice_goal(bounds),
		clampf(delta * 7.5, 0.0, 1.0)
	)
	_scene.call("_move_player_one_to", _saw_position)


func _slice_goal(bounds: Rect2) -> Vector2:
	if _elapsed >= SLICE_IDLE_WINDOW.x and _elapsed <= SLICE_IDLE_WINDOW.y:
		return Vector2(bounds.position.x + 120.0, bounds.end.y - 90.0)
	return _best_can_position(bounds)


func _best_can_position(bounds: Rect2) -> Vector2:
	var best := Vector2(bounds.get_center().x, bounds.end.y - 140.0)
	var best_score := -INF
	for entry in _scene.get("_cans"):
		var can := entry as SliceCan
		if can == null or not is_instance_valid(can) or can.sliced:
			continue
		if can.position.y < bounds.position.y:
			continue
		# Prefer the lowest can, biased towards whatever is already close.
		var score := can.position.y - _saw_position.distance_to(can.position) * 0.35
		if score > best_score:
			best_score = score
			best = can.position
	return best
