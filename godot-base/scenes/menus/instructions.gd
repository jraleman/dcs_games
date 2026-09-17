extends MenuScreen

## Walkthrough clips are declared per game in its [GameManifest] and recorded by
## `tools/record_tutorials.ps1`. A missing file is not an error: the screen
## simply falls back to the static explanation.
##
## The clip is the centrepiece here: it reserves a fixed slice of the screen
## height so a viewer can actually read the round it is showing.

## The screen a solo-only game came from, since it reaches this screen without
## passing through mode select.
@export_file("*.tscn") var main_menu_scene := "res://scenes/menus/main_menu.tscn"
@export_file("*.tscn") var game_select_scene := "res://scenes/menus/game_select.tscn"

## Smallest usable clip width; also stops the grid squeezing the video column.
const VIDEO_MIN_WIDTH := 420.0
## Share of the viewport height reserved for the clip. Tuned so a 16:9 screen
## still fits the whole card without scrolling.
const VIDEO_HEIGHT_RATIO := 0.369
const VIDEO_MIN_HEIGHT := 240.0
const VIDEO_MAX_HEIGHT := 560.0

## Portrait tints, matching the P1/P2 colours the gameplay HUD already uses so a
## player is recognisable from the instructions through to the round itself.
const PLAYER_ONE_COLOR := Color("4da3ff")
const PLAYER_TWO_COLOR := Color("ff5c6c")

@onready var _margins: MarginContainer = %Margins
@onready var _mode_label: Label = %ModeLabel
@onready var _card: PanelContainer = %Card
@onready var _headline: Label = %Headline
@onready var _summary: Label = %Summary
@onready var _body: GridContainer = %Body
@onready var _video_card: PanelContainer = %VideoCard
@onready var _video_frame: AspectRatioContainer = %VideoFrame
@onready var _video_title: Label = %VideoTitle
@onready var _video: VideoStreamPlayer = %Video
@onready var _poster_image: TextureRect = %PosterImage
@onready var _video_scrim: ColorRect = %Scrim
@onready var _poster: CenterContainer = %Poster
@onready var _poster_label: Label = %PosterLabel
@onready var _time_label: Label = %TimeLabel
@onready var _play_button: Button = %PlayButton
@onready var _video_caption: Label = %VideoCaption
@onready var _demo_prompt: Label = %DemoPrompt
@onready var _rule: ColorRect = %Rule
@onready var _control_grid: GridContainer = %ControlGrid
@onready var _player_one_avatar: PlayerAvatar = %PlayerOneAvatar
@onready var _player_one_controls: Label = %PlayerOneControls
@onready var _opponent_card: PanelContainer = %OpponentCard
@onready var _opponent_avatar: PlayerAvatar = %OpponentAvatar
@onready var _opponent_title: Label = %OpponentTitle
@onready var _opponent_controls: Label = %OpponentControls
@onready var _rules: Label = %Rules
@onready var _actions: HBoxContainer = %Actions
@onready var _show_again: CheckButton = %ShowAgainToggle
@onready var _start_button: Button = %StartButton

var _multiplayer := false
var _entrance_tween: Tween
var _rule_tween: Tween
var _reduced_motion := false
var _video_ready := false


func _ready() -> void:
	_reduced_motion = Settings.reduced_motion_enabled()
	first_focus = _start_button
	margins = _margins
	_multiplayer = GameSession.player_two_enabled()
	# Back has to undo however the player got here. A solo-only game skips mode
	# select entirely (see `main_menu.gd`), so returning to it would bounce
	# straight back and trap the player in a loop. What is left depends on
	# whether the build stopped to ask which game: the picker if it did, the
	# title screen if there was nothing to pick.
	if not GameSession.multiplayer_offered():
		back_scene = (
			game_select_scene if GameCatalog.offers_a_choice() else main_menu_scene
		)
	_populate_instructions()
	_setup_video()
	_show_again.button_pressed = bool(Settings.get_value("game/show_instructions", true))
	_show_again.toggled.connect(_on_show_again_toggled)
	GameSession.gamepad_availability_changed.connect(_on_gamepad_availability_changed)
	Settings.changed.connect(_on_setting_changed)
	_play_entrance.call_deferred()
	super()


## The control cards only list pad bindings while a pad is attached.
func _on_gamepad_availability_changed(_available: bool) -> void:
	_populate_instructions()


func _on_setting_changed(key: String, _value: Variant) -> void:
	if _is_solo_setup_key(key):
		_populate_instructions()
		return
	if not _uses_custom_keys():
		return
	for binding: Dictionary in Settings.control_bindings_for_game(GameCatalog.current_id()):
		if str(binding["key"]) == key:
			_populate_instructions()
			return


func _process(_delta: float) -> void:
	_update_video_time()


func _exit_tree() -> void:
	if _video_ready:
		_video.stop()


func _on_layout_changed(size: Vector2) -> void:
	var portrait := Responsive.is_portrait(size)
	_body.columns = 1 if portrait or not _video_ready else 2
	# Long content stacks in portrait; landscape multiplayer has the width to
	# show both players' cards side by side.
	_control_grid.columns = 1 if not _multiplayer or portrait else 2
	# The clip is the primary teaching aid, so claim a fixed slice of the screen
	# height for it. Anything the card cannot fit scrolls, rather than shrinking
	# the picture down to a thumbnail.
	_video_frame.custom_minimum_size = Vector2(
		VIDEO_MIN_WIDTH, clampf(size.y * VIDEO_HEIGHT_RATIO, VIDEO_MIN_HEIGHT, VIDEO_MAX_HEIGHT)
	)


func _populate_instructions() -> void:
	_configure_avatars()
	if _uses_custom_keys():
		_populate_custom_keys_instructions()
		_summary.text = _solo_setup_text(_summary.text)
		_append_round_mode_note()
		return
	if _uses_direct_movement():
		_populate_direct_movement_instructions()
		_summary.text = _solo_setup_text(_summary.text)
		_append_round_mode_note()
		return

	_populate_target_instructions()
	_summary.text = _solo_setup_text(_summary.text)
	_append_round_mode_note()


## Copy for games whose players select numbered targets
## ([constant GameManifest.CONTROL_STYLE_TARGETS]). Like the other two style
## branches, every string is routed through [method _game_text] so a second
## `targets` game can describe its own scoring instead of inheriting the first
## one's, and the framework wording is only the fallback.
func _populate_target_instructions() -> void:
	_mode_label.text = GameSession.mode_title().to_upper()
	_headline.text = _game_text(
		"instructions_headline", "Follow your highlighted target"
	)
	_rules.text = _game_text(
		"instructions_rules",
		"Bright target = correct  ·  Correct hit +1  ·  Wrong target -1  ·  Esc pauses"
	)
	_player_one_controls.text = _target_controls(0, 1)
	if GameSession.is_single_player():
		_summary.text = _game_text(
			"instructions_solo_summary",
			"Only Player 1 is active. Score as many correct hits as possible "
			+ "%s." % _round_goal_phrase()
		)
		_demo_prompt.text = _game_text(
			"instructions_demo_prompt", "WATCH PLAYER 1'S HIGHLIGHTED TARGET"
		)
		_opponent_card.hide()
	elif GameSession.player_two_is_cpu():
		_summary.text = _game_text(
			"instructions_cpu_summary",
			(
				"Race the %s CPU for the highest score. You control P1 targets; "
				% GameSession.cpu_difficulty_title().to_lower()
			)
			+ "the CPU controls P2 targets."
		)
		_demo_prompt.text = _game_text(
			"instructions_demo_prompt", "PLAYER 1 FOLLOWS THE HIGHLIGHT"
		)
		_opponent_title.text = "CPU OPPONENT"
		_opponent_controls.text = _game_text(
			"instructions_cpu_controls",
			(
				"%s · %s\n" % [
					GameSession.cpu_difficulty_title(),
					GameSession.cpu_preset_title(),
				]
			)
			+ "The CPU plays automatically.\n"
			+ "Follow Player 1's highlighted target and beat the CPU's score."
		)
	else:
		_summary.text = _game_text(
			"instructions_versus_summary",
			"Both players act at the same time. Each player must follow their "
			+ "own highlighted target."
		)
		_demo_prompt.text = _game_text(
			"instructions_demo_prompt", "EACH PLAYER FOLLOWS THEIR OWN HIGHLIGHT"
		)
		_opponent_title.text = "PLAYER 2"
		_opponent_controls.text = _target_controls(1, 2)


## How the round the player is about to start will end, so the briefing
## promises the countdown or the lives pool that is actually configured.
func _round_goal_phrase() -> String:
	if not Settings.lives_mode_enabled():
		return "before the timer reaches zero"
	var lives := Settings.starting_lives()
	return "without spending all %d %s" % [
		lives,
		"life" if lives == 1 else "lives",
	]


## Adds what a mistake costs to the rules line. The scoring rules themselves
## belong to the game; only the round mode decides whether a mistake also ends
## the round, so the note is appended rather than baked into a game's copy.
func _append_round_mode_note() -> void:
	var game := GameCatalog.current()
	if game != null and not game.uses_shell_round_rules:
		return
	if not Settings.lives_mode_enabled():
		return
	var lives := Settings.starting_lives()
	_rules.text += "  ·  %d %s per round" % [
		lives,
		"life" if lives == 1 else "lives",
	]


## Each control card carries a portrait placeholder so the roster is readable at
## a glance. The tag tracks who actually holds the slot, so a CPU opponent is
## never presented as a second human player.
func _configure_avatars() -> void:
	_player_one_avatar.configure(
		"P1", PLAYER_ONE_COLOR, "Player 1 portrait placeholder."
	)
	if GameSession.is_single_player():
		return
	var cpu := GameSession.player_two_is_cpu()
	_opponent_avatar.configure(
		"CPU" if cpu else "P2",
		PLAYER_TWO_COLOR,
		(
			"CPU opponent portrait placeholder."
			if cpu
			else "Player 2 portrait placeholder."
		)
	)


## Copy for games whose players steer a cursor directly
## ([constant GameManifest.CONTROL_STYLE_DIRECT_MOVEMENT]).
func _populate_direct_movement_instructions() -> void:
	_mode_label.text = "%s · %s" % [
		_current_game_title().to_upper(),
		GameSession.mode_title().to_upper(),
	]
	_headline.text = _game_text(
		"instructions_headline", "Reach every target before it disappears"
	)
	_rules.text = _game_text(
		"instructions_rules",
		"Touch a target to score  ·  Each target scores once  ·  Esc pauses"
	)
	_demo_prompt.text = _game_text(
		"instructions_demo_prompt", "MOVE YOUR CURSOR ONTO A TARGET"
	)
	if GameSession.is_single_player():
		_summary.text = _game_text(
			"instructions_solo_summary",
			"Steer Player 1 around the board and clear every target you reach."
		)
		# A game that describes its own controls describes all of them. The
		# framework cannot know whether a connected pad does anything in a game
		# it knows nothing about, and offering a controller to someone holding
		# a guitar is worse than saying nothing.
		var solo_controls := _game_text("instructions_player_one_controls", "")
		_player_one_controls.text = (
			solo_controls
			if not solo_controls.is_empty()
			else _direct_movement_controls("Mouse or arrow keys", 1)
		)
		_opponent_card.hide()
	else:
		_summary.text = _game_text(
			"instructions_versus_summary",
			"Both players share one board. The first player to reach a target "
			+ "earns its point."
		)
		_player_one_controls.text = _direct_movement_controls("Player 1: mouse", 1)
		_opponent_title.text = "PLAYER 2"
		_opponent_controls.text = _direct_movement_controls(
			"Player 2: arrow keys", 2
		)


## Action descriptions come from the game; key names always come from the
## current bindings. A custom-key style implies no mouse or controller actions.
func _populate_custom_keys_instructions() -> void:
	var single_player := GameSession.is_single_player()
	var cpu := GameSession.player_two_is_cpu()
	var mode := (
		"Single Player" if single_player
		else "Multiplayer vs CPU" if cpu
		else "Local Multiplayer"
	)
	_mode_label.text = "%s · %s" % [_current_game_title().to_upper(), mode.to_upper()]
	_headline.text = _game_text("instructions_headline", "Play using your action keys")
	_rules.text = _game_text(
		"instructions_rules", "Rebind action keys in Settings → Controls  ·  Esc pauses"
	)
	_demo_prompt.text = _game_text("instructions_demo_prompt", "USE YOUR ACTION KEYS")
	_player_one_controls.text = _custom_key_controls(0)
	_opponent_card.visible = not single_player
	if single_player:
		_summary.text = _game_text(
			"instructions_solo_summary", "Play using Player 1's action keys."
		)
	elif cpu:
		_summary.text = _game_text(
			"instructions_cpu_summary",
			_game_text(
				"instructions_solo_summary",
				"You control Player 1. The CPU plays as Player 2."
			)
		)
		_opponent_title.text = "CPU OPPONENT"
		_opponent_controls.text = _game_text(
			"instructions_cpu_controls",
			_game_text(
				"cpu_opponent_description",
				"Player 2 plays automatically using this game's CPU opponent."
			)
		)
	else:
		_summary.text = _game_text(
			"instructions_versus_summary",
			"Both players share this device using their own action keys."
		)
		_opponent_title.text = "PLAYER 2"
		_opponent_controls.text = _custom_key_controls(1)


func _custom_key_controls(player_index: int) -> String:
	var player := "one" if player_index == 0 else "two"
	var lines := PackedStringArray([_game_text(
		"instructions_player_%s_controls" % player,
		_game_text("player_%s_control_description" % player, "Use the action keys below.")
	)])
	for binding: Dictionary in Settings.control_bindings_for_game(GameCatalog.current_id()):
		var binding_player := int(binding.get("player", -1))
		if binding_player >= 0 and binding_player != player_index:
			continue
		var key := str(binding["key"])
		lines.append("%s: %s" % [Settings.binding_title(key), Settings.binding_key_label(key)])
	return "\n".join(lines)


## One control card for a direct-movement game: the keyboard/mouse line, plus
## a pad line only while a pad is actually connected.
func _direct_movement_controls(keyboard_line: String, controller_number: int) -> String:
	if not GameSession.gamepad_connected():
		return keyboard_line
	return "%s\nController %d: %s" % [
		keyboard_line,
		controller_number,
		Settings.controller_movement_scheme_label(),
	]


## Screen copy for the active game, falling back to neutral framework wording.
func _game_text(key: String, fallback: String) -> String:
	var manifest := GameCatalog.current()
	return manifest.text(key, fallback) if manifest else fallback


# --- Tutorial video ---------------------------------------------------------


## Loads the walkthrough clip for the active game. When the file is missing the
## card is removed and the screen keeps its original single-column layout.
func _setup_video() -> void:
	var path := _selected_tutorial_video_path()
	if path.is_empty() or not ResourceLoader.exists(path):
		_video_card.hide()
		set_process(false)
		return
	var stream := load(path) as VideoStream
	if stream == null:
		_video_card.hide()
		set_process(false)
		return

	_video_ready = true
	_video.stream = stream
	# The walkthrough repeats so a player can keep watching without hunting for
	# the replay button. Reduced motion opts out: an endlessly restarting clip is
	# exactly the kind of unrequested repeated movement that setting exists for,
	# so it keeps the explicit "Watch again" prompt instead.
	_video.loop = not _reduced_motion
	_video.volume_db = -80.0
	_video_title.text = "WATCH A ROUND · %s" % _current_game_title().to_upper()
	_video_caption.text = "No audio — captions explain each step."
	_video.gui_input.connect(_on_video_gui_input)
	var poster_path := _selected_tutorial_poster_path()
	if not poster_path.is_empty() and ResourceLoader.exists(poster_path):
		_poster_image.texture = load(poster_path)
	_update_video_time()
	if _reduced_motion:
		_set_video_idle("Play the walkthrough")
	else:
		_play_video()


func _selected_tutorial_video_path() -> String:
	var manifest := GameCatalog.current()
	if manifest == null:
		return ""
	if _uses_local_tutorial_media() and not manifest.local_tutorial_video_path.is_empty():
		return manifest.local_tutorial_video_path
	return manifest.tutorial_video_path


func _selected_tutorial_poster_path() -> String:
	var manifest := GameCatalog.current()
	if manifest == null:
		return ""
	if _uses_local_tutorial_media() and not manifest.local_tutorial_poster_path.is_empty():
		return manifest.local_tutorial_poster_path
	return manifest.tutorial_poster_path


func _uses_local_tutorial_media() -> bool:
	return GameSession.player_two_enabled() and not GameSession.player_two_is_cpu()


func _current_game_id() -> String:
	return GameCatalog.current_id()


func _current_game_title() -> String:
	return GameCatalog.current_title()


## True when the selected game is steered directly rather than by target keys.
func _uses_direct_movement() -> bool:
	var manifest := GameCatalog.current()
	return (
		manifest != null
		and manifest.control_style == GameManifest.CONTROL_STYLE_DIRECT_MOVEMENT
	)


func _uses_custom_keys() -> bool:
	var manifest := GameCatalog.current()
	return (
		manifest != null
		and manifest.control_style == GameManifest.CONTROL_STYLE_CUSTOM_KEYS
	)


func _is_solo_setup_key(key: String) -> bool:
	var manifest := GameCatalog.current()
	if manifest == null:
		return false
	for choice_key: String in manifest.solo_setup_choices:
		if choice_key == key:
			return true
	return false


func _solo_setup_text(text: String) -> String:
	return Settings.solo_setup_text(GameCatalog.current_id(), text)


func _play_video() -> void:
	if not _video_ready:
		return
	if not _video.is_playing():
		_video.play()
	_video.paused = false
	_play_button.text = "Pause"
	_video_scrim.hide()
	_poster.hide()
	_poster_image.hide()
	set_process(true)


func _pause_video() -> void:
	if not _video_ready or not _video.is_playing():
		return
	_video.paused = true
	_set_video_idle("Paused")


## Parks the player and shows the poster scrim with the supplied prompt.
func _set_video_idle(prompt: String) -> void:
	_poster_label.text = prompt
	_play_button.text = "Play"
	_video_scrim.show()
	_poster.show()
	set_process(false)
	_update_video_time()


func _toggle_video() -> void:
	if not _video_ready:
		return
	if _video.is_playing() and not _video.paused:
		_pause_video()
	else:
		_play_video()


func _update_video_time() -> void:
	if not _video_ready:
		return
	var length := _video.get_stream_length()
	if length <= 0.0:
		_time_label.text = _format_time(_video.stream_position)
		return
	_time_label.text = "%s / %s" % [
		_format_time(minf(_video.stream_position, length)),
		_format_time(length),
	]


func _format_time(seconds: float) -> String:
	var total := int(round(maxf(seconds, 0.0)))
	return "%d:%02d" % [total / 60, total % 60]


func _on_video_gui_input(event: InputEvent) -> void:
	var click := event as InputEventMouseButton
	if click != null and click.pressed and click.button_index == MOUSE_BUTTON_LEFT:
		_toggle_video()
		accept_event()


func _on_play_pressed() -> void:
	_toggle_video()


func _on_restart_pressed() -> void:
	if not _video_ready:
		return
	_video.stop()
	_play_video()


## Only reached when looping is off, which today means Reduced motion is on.
## The clip parks on its poster so replaying stays an explicit choice.
func _on_video_finished() -> void:
	if not _video_ready:
		return
	_set_video_idle("Watch again")
	_play_button.text = "Replay"


# --- Static explanation ------------------------------------------------------


## One control card for a target-selection game. Named for the control style,
## not for the first game that used it.
func _target_controls(player_index: int, controller_number: int) -> String:
	var keyboard_summary := Settings.control_summary(player_index)
	var target_summary := "P%d targets" % (player_index + 1)
	var lines := PackedStringArray(["Keyboard: %s" % keyboard_summary])
	if GameSession.gamepad_connected():
		var controller_summary := (
			"any mapped button (%s)" % Settings.controller_target_summary(", ")
			if Settings.one_button_targets_enabled()
			else Settings.controller_target_summary(", ")
		)
		lines.append("Controller %d: %s" % [controller_number, controller_summary])
	lines.append("Mouse/touch: select %s" % target_summary)
	return "\n".join(lines)


func _play_entrance() -> void:
	_center_pivot(_card)
	if _reduced_motion:
		_mode_label.modulate.a = 1.0
		_card.modulate.a = 1.0
		_card.scale = Vector2.ONE
		_actions.modulate.a = 1.0
		_rule.modulate.a = 1.0
		return
	_mode_label.modulate.a = 0.0
	_card.modulate.a = 0.0
	_card.scale = Vector2(0.965, 0.965)
	_actions.modulate.a = 0.0

	_entrance_tween = create_tween().set_trans(Tween.TRANS_QUART).set_ease(Tween.EASE_OUT)
	_entrance_tween.tween_property(_mode_label, "modulate:a", 1.0, 0.18)
	_entrance_tween.tween_property(_card, "modulate:a", 1.0, 0.26)
	_entrance_tween.parallel().tween_property(_card, "scale", Vector2.ONE, 0.38)
	_entrance_tween.tween_property(_actions, "modulate:a", 1.0, 0.2)

	_rule.modulate.a = 0.45
	_rule_tween = create_tween().set_loops()
	_rule_tween.tween_property(_rule, "modulate:a", 1.0, 0.9).set_trans(Tween.TRANS_SINE)
	_rule_tween.tween_property(_rule, "modulate:a", 0.45, 0.9).set_trans(Tween.TRANS_SINE)


func _center_pivot(control: Control) -> void:
	control.pivot_offset = control.size * 0.5


func _on_show_again_toggled(pressed: bool) -> void:
	Settings.set_value("game/show_instructions", pressed)


func _on_start_pressed() -> void:
	Router.goto(GameCatalog.current_gameplay_scene_path())


func _on_back_pressed() -> void:
	go_back()
