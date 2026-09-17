extends Node

## Development-only recorder for the "How to play" clips shown by the
## instructions screen.
##
## It runs the real gameplay scene, plays it with a scripted demo player and
## overlays numbered step captions, then quits so Godot's Movie Maker can close
## the file. Nothing here ships with the game; see `tools/record_tutorials.ps1`.
##
##     godot --path godot-base --resolution 1280x720 \
##         --write-movie build/triangle_rush.avi \
##         res://tools/tutorial_capture.tscn ++ --game=triangle_rush

const TRIANGLE_RUSH := "triangle_rush"
const DESK_CAN_SAW := "desk_can_saw"
const DEAD_METAL_JAM := "dead_metal_jam"
const CHICKEN_PIT := "chicken_pit"

const DEFAULT_TUTORIAL_VARIANT := "solo"
const EXTERNAL_DRIVER_PATH := "res://games/%s/tools/tutorial_driver.gd"
const DEFAULT_CAPTURE_INSET := 260.0
const REQUIRED_DRIVER_METHODS: Array[String] = [
	"configure", "steps", "duration", "settings_overrides",
	"configure_session", "start", "update",
]

const FADE_IN := 0.6
const FADE_OUT := 1.0
const KEYCAP_HOLD := 0.55
const CLIP_DURATION := 24.0

## Dead Metal Jam's clip runs longer than the other two. It has more to say —
## a note to read, an instrument to play it on, a beat to land it on and a
## robot that shoots back — and at 100 BPM the robots it is describing arrive
## roughly three seconds apart. Measured against the shipped chart rather than
## guessed: five steps is thirty seconds of Scrapyard Stomp.
##
## The armoured robot is deliberately *not* taught here. Every shipped chart
## holds its first one back past the half-minute mark, on purpose — an enemy
## that demands reading ahead is not the thing to meet before the one that
## demands a single note (§8.2) — so a caption about it would be describing
## something the viewer cannot see.
const DEAD_METAL_JAM_DURATION := 30.0

## Chicken Pit's clip runs a little long for the same reason: a tug-of-war is
## the one game here whose subject is a *trend*. A caption about ground creeping
## back needs seconds of rope to point at, not a frame, so the clip buys time
## for the rope to be hauled one way, given up, and hauled back.
const CHICKEN_PIT_DURATION := 28.0

## A game may own `res://games/<id>/tools/tutorial_driver.gd`. The recorder
## loads that script at runtime before choosing captions or a session and
## expects a RefCounted with this interface:
##
## - `configure(variant: String) -> bool`
## - `steps() -> Array[Dictionary]`
## - `duration() -> float`
## - `settings_overrides() -> Dictionary`
## - `configure_session(session: Node) -> void`
## - `start(scene: Node) -> void`
## - `update(scene: Node, time: float, delta: float) -> void`
##
## Optional:
## - `signal keycap_requested(text: String)` to drive the shared keycap badge
## - `capture_inset() -> float` for gameplay that must clear extra space under
##   the shared caption card; the recorder supplies 260 logical units by default
##   when the scene implements `_set_capture_inset(bottom: float)`.
## - `validate_finished(scene: Node) -> bool` to reject an incomplete take.

## Non-persistent Settings overrides so a developer's saved preferences cannot
## change what the recording looks like. Written straight into the backing
## dictionary because `Settings.set_value()` would persist them.
const SETTING_OVERRIDES := {
	"ui/show_fps": false,
	"accessibility/visual_effects": true,
	"accessibility/reduced_motion": false,
	"accessibility/audio_captions": false,
	"accessibility/player_labels": true,
	"accessibility/one_button_triangle_rush": false,
	"accessibility/gameplay_speed": 1.0,
	"accessibility/target_size": 1.0,
	"accessibility/extra_round_time": 0.0,
	"game/round_mode": Settings.RoundMode.TIMER,
	"game/triangle_size": 1.0,
	"game/triangle_speed": 1.0,
	"game/triangle_speed_rush": 0.35,
	"game/triangle_round_length": 30.0,
	# Dead Metal Jam. The note source is pinned to the computer keyboard
	# because the scripted player cannot hold a guitar — the reason that source
	# exists at all (§4.5) — and pinning it also stops a real microphone in the
	# room from scoring notes nobody played into the recording.
	#
	# The track is a shipped chart rather than the practice ramp because the
	# ramp is seeded from the clock: every take would be a different song, and
	# a caption timed against one take would be describing another. A chart is
	# fixed data, so re-recording after an art change gives the same robots in
	# the same lanes at the same beats. Scrapyard Stomp is the slowest of the
	# three (§10), which is what a first viewer needs.
	"game/dmj_mode": DmjOptions.MODE_JAM,
	"game/dmj_track": DmjOptions.TRACK_SONG_02,
	"game/dmj_timing_window": 1.0,
	"game/dmj_wrong_note_penalty": DmjOptions.DEFAULT_WRONG_NOTE_PENALTY,
	"game/dmj_note_source": DmjOptions.SOURCE_KEYBOARD,
	# Chicken Pit, recorded on its shipped defaults so the clip teaches the
	# round a first-time player will actually be given. The bird is named
	# rather than numbered, so the middle one is spelled out instead of
	# left to a saved preference.
	"game/pit_round_length": ChickenPitOptions.DEFAULT_ROUND_LENGTH,
	"game/pit_rope_length": float(ChickenPitOptions.DEFAULT_ROPE_LENGTH),
	"game/pit_pull_power": ChickenPitOptions.DEFAULT_PULL_POWER,
	"game/pit_strength_decay": ChickenPitOptions.DEFAULT_STRENGTH_DECAY,
	"game/pit_cpu_difficulty": ChickenPitOptions.CPU_HEN,
}

const TRIANGLE_RUSH_STEPS: Array[Dictionary] = [
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

const DESK_CAN_SAW_STEPS: Array[Dictionary] = [
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

const DEAD_METAL_JAM_STEPS: Array[Dictionary] = [
	{
		"time": 0.0,
		"title": "Match the note and its color",
		"body": "Every pitch has a color, shared by its plate and the HUD. Shoot before the attack bar fills.",
	},
	{
		"time": 5.6,
		"title": "Your instrument is the trigger",
		"body": "The correct note fires a matching-colored shot. Guitar, bass, keys or voice: any octave counts.",
	},
	{
		"time": 11.6,
		"title": "Beat timing earns a bonus",
		"body": "Shoot any time before the robot fires. Use the closing target ring to land higher-scoring hits.",
	},
	{
		"time": 17.4,
		"title": "Enemy shots burn a life tube",
		"body": "When the attack bar fills, the arm cannon shoots at your amp. Answer before it fires.",
	},
	{
		"time": 25.0,
		"title": "No instrument? Use the keys",
		"body": "A S D F G H J plays a scale, so you can learn the game before you plug in.",
	},
]

const CHICKEN_PIT_STEPS: Array[Dictionary] = [
	{
		"time": 0.0,
		"title": "Two coops, one rope",
		"body": "You pull for the red coop. A rival bird pulls for the blue one.",
	},
	{
		"time": 5.2,
		"title": "Roll your three pull keys",
		"body": "Q, W and E each pull once. Alternating them beats hammering one key.",
	},
	{
		"time": 10.6,
		"title": "Let up and you lose ground",
		"body": "Strength drains between pulls, so the bird drags the rope straight back.",
	},
	{
		"time": 16.2,
		"title": "Hold ground to score",
		"body": "Every second the rope sits on their side of the pit banks points for you.",
	},
	{
		"time": 21.6,
		"title": "Or pin them outright",
		"body": "Haul the rope past the last notch and the blue coop drops into the pit.",
	},
]

const TRIANGLE_RUSH_WRONG_PRESS_TIME := 11.4
const TRIANGLE_RUSH_REACTION := 0.52

## While this step is on screen the demo player parks the chainsaw so a few
## cans reach the floor and the clatter penalty is actually shown.
const DESK_CAN_SAW_IDLE_WINDOW := Vector2(15.0, 18.6)

## How close to the beat the scripted player answers, in seconds. Well inside
## the Perfect window, because a tutorial should show the game being played
## right — but not exactly zero, which no hand achieves and which would make
## the judgement callouts look scripted rather than earned.
const DEAD_METAL_JAM_ACCURACY := 0.018

## Shortest gap between two synthesised notes. A plated knuckle asks for its
## next plate 0.8 s later (§8.2), so this cannot swallow a plate beat, and it
## is long enough that one press cannot be counted twice across frames.
const DEAD_METAL_JAM_REPRESS := 0.2

## Show one incoming shot during step four, then resume before the take can end.
const DEAD_METAL_JAM_IDLE_WINDOW := Vector2(17.6, 24.6)

## Gap between two synthesised pulls. It sits inside the model's full-cadence
## band, so the recording shows a coop pulling *well* — a slower roll would
## teach the game while quietly demonstrating a worse rhythm than it describes.
## It also has to be fast enough to actually beat the Hen: the first take rolled
## at 0.19 s, settled barely six points of strength above the bird, and spent
## the clip creeping around the centre line while the last caption promised a
## pin that never came.
const CHICKEN_PIT_PULL_INTERVAL := 0.13

## While this step is on screen the demo player lets go of the rope, so the
## rival bird hauls it back and the caption about draining strength has the
## thing it is describing on screen rather than only in the text.
const CHICKEN_PIT_IDLE_WINDOW := Vector2(10.9, 15.4)

var _game := TRIANGLE_RUSH
var _tutorial_variant := DEFAULT_TUTORIAL_VARIANT
var _steps: Array[Dictionary] = TRIANGLE_RUSH_STEPS
var _elapsed := 0.0
var _step_index := -1
var _scene: Node
var _external_driver: RefCounted
var _startup_failed := false

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
## When the scripted Dead Metal Jam player is next allowed to play a note.
var _note_ready_at := 0.0
## Chicken Pit's rotating pull: the declared Player 1 bindings, and when the
## next one is due.
var _pull_bindings: Array[Dictionary] = []
var _pull_index := -1
var _pull_ready_at := 0.0


func _ready() -> void:
	_game = _requested_game()
	if _startup_failed:
		return
	_tutorial_variant = _requested_variant()
	if _startup_failed:
		return
	_external_driver = _load_external_driver()
	if _startup_failed:
		return
	if _external_driver != null:
		var external_steps: Variant = _external_driver.call("steps")
		if not external_steps is Array:
			_fail_capture("External tutorial driver for --game=%s must return an Array of steps." % _game)
			return
		_steps = external_steps
	else:
		_steps = _steps_for(_game)
	if _steps.is_empty():
		_fail_capture("No tutorial steps are available for --game=%s." % _game)
		return
	AudioServer.set_bus_mute(AudioServer.get_bus_index(&"Master"), true)
	_apply_setting_overrides()
	if _startup_failed:
		return
	_configure_session()
	if _startup_failed:
		return
	_build_overlay()
	var gameplay_path := GameCatalog.current_gameplay_scene_path()
	if gameplay_path.is_empty():
		_fail_capture("GameCatalog did not resolve a gameplay scene for --game=%s." % _game)
		return
	var packed := load(gameplay_path) as PackedScene
	if packed == null:
		_fail_capture("Could not load the tutorial gameplay scene '%s'." % gameplay_path)
		return
	_scene = packed.instantiate()
	if _scene == null:
		_fail_capture("Could not instantiate the tutorial gameplay scene '%s'." % gameplay_path)
		return
	add_child(_scene)
	move_child(_scene, 0)
	if _external_driver != null:
		if _scene.has_method("_set_capture_inset"):
			var bottom := (
				float(_external_driver.call("capture_inset"))
				if _external_driver.has_method("capture_inset") else DEFAULT_CAPTURE_INSET
			)
			_scene.call("_set_capture_inset", bottom)
		_external_driver.call("start", _scene)
	_hide_duplicate_hint.call_deferred()
	_advance_step.call_deferred()


func _process(delta: float) -> void:
	if _startup_failed:
		return
	_flush_key_releases()
	_elapsed += delta
	_update_fade()
	_update_keycap(delta)

	while (
		_step_index + 1 < _steps.size()
		and _elapsed >= float(_steps[_step_index + 1]["time"])
	):
		_advance_step()

	if _external_driver != null:
		_external_driver.call("update", _scene, _elapsed, delta)
	elif _game == DESK_CAN_SAW:
		_drive_desk_can_saw(delta)
	elif _game == DEAD_METAL_JAM:
		_drive_dead_metal_jam()
	elif _game == CHICKEN_PIT:
		_drive_chicken_pit()
	else:
		_drive_triangle_rush()

	if _elapsed >= _clip_duration():
		set_process(false)
		if _external_driver != null and _external_driver.has_method("validate_finished"):
			var complete: Variant = _external_driver.call("validate_finished", _scene)
			if not complete is bool or not complete:
				_fail_capture("The %s (%s) tutorial did not complete its lessons." % [
					_game, _tutorial_variant,
				])
				return
		print("Tutorial complete: %s (%s)." % [_game, _tutorial_variant])
		_finish_capture()


func _finish_capture() -> void:
	AudioManager.stop_music(0.0)
	for node in get_tree().root.find_children("*", "AudioStreamPlayer", true, false):
		var player := node as AudioStreamPlayer
		player.stop()
		player.stream = null
	await get_tree().process_frame
	get_tree().quit()


# --- Configuration ----------------------------------------------------------

func _requested_game() -> String:
	var arguments := OS.get_cmdline_user_args()
	arguments.append_array(OS.get_cmdline_args())
	var requested := ""
	for argument in arguments:
		if not argument.begins_with("--game="):
			continue
		requested = argument.trim_prefix("--game=").strip_edges()
		break
	if requested.is_empty():
		return TRIANGLE_RUSH
	if GameCatalog.get_manifest(requested) == null:
		_fail_capture("Unknown tutorial game '%s'." % requested)
		return TRIANGLE_RUSH
	if _steps_for(requested).is_empty() and not ResourceLoader.exists(EXTERNAL_DRIVER_PATH % requested):
		_fail_capture("Game '%s' has no tutorial driver or built-in tutorial script." % requested)
		return TRIANGLE_RUSH
	return requested


func _requested_variant() -> String:
	var arguments := OS.get_cmdline_user_args()
	arguments.append_array(OS.get_cmdline_args())
	var requested := DEFAULT_TUTORIAL_VARIANT
	for argument in arguments:
		if not argument.begins_with("--tutorial-variant="):
			continue
		requested = argument.trim_prefix("--tutorial-variant=").strip_edges().to_lower()
		break
	if requested.is_empty():
		_fail_capture("Tutorial variant cannot be empty.")
		return DEFAULT_TUTORIAL_VARIANT
	if not ResourceLoader.exists(EXTERNAL_DRIVER_PATH % _game):
		if requested != DEFAULT_TUTORIAL_VARIANT:
			_fail_capture(
				"Tutorial variant '%s' is unsupported for --game=%s." % [requested, _game]
			)
		return DEFAULT_TUTORIAL_VARIANT
	return requested


func _load_external_driver() -> RefCounted:
	var path := EXTERNAL_DRIVER_PATH % _game
	if not ResourceLoader.exists(path):
		return null
	var script := load(path) as Script
	if script == null or not script.can_instantiate():
		_fail_capture("Could not instantiate the external tutorial driver '%s'." % path)
		return null
	var driver: Object = script.new()
	if not driver is RefCounted:
		_fail_capture("External tutorial driver '%s' must extend RefCounted." % path)
		return null
	for method_name: String in REQUIRED_DRIVER_METHODS:
		if not driver.has_method(method_name):
			_fail_capture("External tutorial driver '%s' is missing `%s()`." % [path, method_name])
			return null
	var accepted: Variant = driver.call("configure", _tutorial_variant)
	if typeof(accepted) != TYPE_BOOL:
		_fail_capture("External tutorial driver '%s' must return bool from configure()." % path)
		return null
	if not bool(accepted):
		_fail_capture(
			"Tutorial variant '%s' is unsupported for --game=%s." % [_tutorial_variant, _game]
		)
		return null
	if driver.has_signal("keycap_requested"):
		driver.connect("keycap_requested", Callable(self, "_show_keycap"))
	return driver


func _fail_capture(message: String) -> void:
	if _startup_failed:
		return
	_startup_failed = true
	printerr(message)
	push_error(message)
	call_deferred("_quit_with_error")


func _quit_with_error() -> void:
	get_tree().quit(1)


## The captions for a game, or empty when the recorder has no script for it.
## Recording a game the tool cannot drive would produce a clip of a round
## nobody is playing, which is worse than no clip at all.
func _steps_for(game: String) -> Array[Dictionary]:
	match game:
		DESK_CAN_SAW:
			return DESK_CAN_SAW_STEPS
		DEAD_METAL_JAM:
			return DEAD_METAL_JAM_STEPS
		CHICKEN_PIT:
			return CHICKEN_PIT_STEPS
		TRIANGLE_RUSH:
			return TRIANGLE_RUSH_STEPS
		_:
			return [] as Array[Dictionary]


func _clip_duration() -> float:
	if _external_driver != null:
		return float(_external_driver.call("duration"))
	match _game:
		DEAD_METAL_JAM:
			return DEAD_METAL_JAM_DURATION
		CHICKEN_PIT:
			return CHICKEN_PIT_DURATION
		_:
			return CLIP_DURATION


func _apply_setting_overrides() -> void:
	var values: Variant = Settings.get("_values")
	if not values is Dictionary:
		return
	var overrides := SETTING_OVERRIDES.duplicate()
	if _external_driver != null:
		var external: Variant = _external_driver.call("settings_overrides")
		if not external is Dictionary:
			_fail_capture("External tutorial driver '%s' must return a Dictionary of settings." % _game)
			return
		overrides.merge(external, true)
	(Settings.get("_save_timer") as Timer).process_mode = Node.PROCESS_MODE_DISABLED
	for key: String in overrides:
		(values as Dictionary)[key] = overrides[key]
	if _game == DEAD_METAL_JAM:
		(values as Dictionary)[Settings.ROUND_MODE_KEY] = Settings.RoundMode.LIVES
		(values as Dictionary)[Settings.STARTING_LIVES_KEY] = 3


func _configure_session() -> void:
	GameCatalog.select(_game)
	if _external_driver != null:
		_external_driver.call("configure_session", GameSession)
	else:
		# A game with no solo mode is recorded the way it will be played: one human
		# seat with the CPU on the other, rather than a single-seat session the
		# menus would never hand a player.
		if GameSession.single_player_offered():
			GameSession.configure_single_player()
		else:
			GameSession.configure_multiplayer(GameSession.PlayerTwoController.CPU)
	# A recorded round is not a played round. An achievement toast would slide
	# a badge the viewer has not earned across the corner of the clip, so the
	# overlay is hidden for the take.
	var toasts: Variant = AchievementManager.get("_toast_layer")
	if toasts is CanvasLayer:
		(toasts as CanvasLayer).hide()


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
	# The game's own title, from the catalog. `GameSession` used to answer this
	# and no longer does, which took the whole overlay down with it: the error
	# aborted `_build_overlay` before the captions, the keycap and the fade were
	# built, and every clip recorded was a bare game with a numbered badge over
	# it. The catalog is the manifest's own title and cannot drift from it.
	var manifest := GameCatalog.get_manifest(_game)
	eyebrow.text = "HOW TO PLAY · %s" % (
		manifest.title if manifest != null else _game
	).to_upper()
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
	_keycap_column.visible = (
		_game != DESK_CAN_SAW
		and (_external_driver == null or _external_driver.has_signal("keycap_requested"))
	)
	row.add_child(_keycap_column)

	var keycap_caption := Label.new()
	# Dead Metal Jam is played on an instrument; the keyboard is only how this
	# recording holds one. So the badge names the note that was played, not the
	# key that produced it, and the caption has to say so.
	keycap_caption.text = (
		"PLAYED" if _game == DEAD_METAL_JAM
		else "INPUT" if _external_driver != null else "PRESSED"
	)
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
	var duration := _clip_duration()
	var alpha := 0.0
	if _elapsed < FADE_IN:
		alpha = 1.0 - _elapsed / FADE_IN
	elif _elapsed > duration - FADE_OUT:
		alpha = (_elapsed - (duration - FADE_OUT)) / FADE_OUT
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

func _drive_triangle_rush() -> void:
	if not bool(_scene.get("_round_active")):
		return

	var active := _scene.get("_active_targets")[0] as TriangleTarget
	if active == null:
		return
	if active != _last_active_target:
		_last_active_target = active
		_press_due = _elapsed + TRIANGLE_RUSH_REACTION + randf() * 0.16

	if _press_due < 0.0 or _elapsed < _press_due:
		return
	_press_due = -1.0

	if not _wrong_press_done and _elapsed >= TRIANGLE_RUSH_WRONG_PRESS_TIME:
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
	_press_action(action, Settings.control_key_label(action))


## Presses whichever key currently drives [param action] and shows it on the
## keycap. The InputMap event is duplicated rather than rebuilt from a keycode
## because that is what [Settings] wrote when the binding was applied, so a
## rebound key records as itself instead of as the shipped default.
func _press_action(action: StringName, label: String) -> bool:
	for event in InputMap.action_get_events(action):
		if not event is InputEventKey:
			continue
		var press := (event as InputEventKey).duplicate() as InputEventKey
		press.pressed = true
		press.echo = false
		Input.parse_input_event(press)
		_pending_releases.append(press)
		_show_keycap(label)
		return true
	return false


func _action_for_target(target: TriangleTarget) -> StringName:
	var by_action: Dictionary = _scene.get("_targets_by_action")
	for action: StringName in by_action:
		if by_action[action] == target:
			return action
	return &""


## Show free-timing shots during the instrument lesson, then beat-timed bonuses.
##
## It reaches into the gameplay scene for the director and synthesises key
## events into [KeyboardNoteSource] rather than calling the scoring code, so
## what the recording shows is a round genuinely played through the game's own
## input path — the same reason the other two drivers press keys and move a
## mouse instead of adding points directly.
func _drive_dead_metal_jam() -> void:
	if not bool(_scene.get("_round_active")):
		return
	var lives: Array = _scene.get("_lives")
	if (
		_elapsed >= DEAD_METAL_JAM_IDLE_WINDOW.x and _elapsed <= DEAD_METAL_JAM_IDLE_WINDOW.y
		and int(lives[0]) == 3
	):
		return
	if _elapsed < _note_ready_at:
		return
	var director: Object = _scene.get("_director")
	if director == null:
		return

	var live: Array = director.call("live_drones")
	for entry in live:
		var drone: JamBot = entry
		if drone == null or drone.required_note < 0:
			continue
		if _step_index == 1:
			if drone.approach_progress() < 0.4:
				continue
		elif drone.time_to_beat() < -DEAD_METAL_JAM_ACCURACY:
			continue
		_play_note(drone.required_note)
		return


## Presses whichever key on [KeyboardNoteSource]'s layout sounds `note`.
##
## Notes are matched by pitch class (§4), so the octave never has to be shifted
## — every note the game can ask for is somewhere on the one row of keys.
func _play_note(note: int) -> void:
	var source: Object = _scene.get("_keys")
	if source == null:
		return
	var base: int = source.call("base_midi")
	var semitone := posmod(note - base, 12)
	for keycode: int in KeyboardNoteSource.LAYOUT:
		if int(KeyboardNoteSource.LAYOUT[keycode]) != semitone:
			continue
		var press := InputEventKey.new()
		press.keycode = keycode
		press.physical_keycode = keycode
		press.pressed = true
		press.echo = false
		Input.parse_input_event(press)
		_pending_releases.append(press)
		_show_keycap(PitchDetector.note_name(note))
		_note_ready_at = _elapsed + DEAD_METAL_JAM_REPRESS
		return


func _flush_key_releases() -> void:
	for press in _pending_releases:
		var release := press.duplicate() as InputEventKey
		release.pressed = false
		Input.parse_input_event(release)
	_pending_releases.clear()


## Rolls the red coop's three declared pull keys.
##
## It reads the bindings rather than naming Q, W and E so a rebound coop still
## records truthfully, and it presses keys instead of calling `register_pull()`
## so the clip shows a round played through the game's own input path — the
## same rule the other drivers follow.
func _drive_chicken_pit() -> void:
	if not bool(_scene.get("_round_active")):
		return
	if (
		_elapsed >= CHICKEN_PIT_IDLE_WINDOW.x
		and _elapsed <= CHICKEN_PIT_IDLE_WINDOW.y
	):
		return
	if _elapsed < _pull_ready_at:
		return
	var bindings := _chicken_pit_pull_bindings()
	if bindings.is_empty():
		return
	# Rotating rather than repeating: the model pays a repeated key a third of
	# a pull (§3.3), so hammering one key would film the mistake the captions
	# tell the player to avoid.
	_pull_index = (_pull_index + 1) % bindings.size()
	var binding := bindings[_pull_index]
	var action := StringName(binding.get("action", &""))
	if action == &"":
		return
	if _press_action(action, Settings.binding_key_label(str(binding["key"]))):
		_pull_ready_at = _elapsed + CHICKEN_PIT_PULL_INTERVAL


func _chicken_pit_pull_bindings() -> Array[Dictionary]:
	if not _pull_bindings.is_empty():
		return _pull_bindings
	for binding: Dictionary in Settings.control_bindings_for_game(CHICKEN_PIT):
		if int(binding.get("player", -1)) == 0:
			_pull_bindings.append(binding)
	return _pull_bindings


func _drive_desk_can_saw(delta: float) -> void:
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
	if _elapsed >= DESK_CAN_SAW_IDLE_WINDOW.x and _elapsed <= DESK_CAN_SAW_IDLE_WINDOW.y:
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
