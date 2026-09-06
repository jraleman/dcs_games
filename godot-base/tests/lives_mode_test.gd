extends SceneTree

## Regression checks for the shared lives round mode.
##
## Lives are an alternative to the countdown, so they live in `GameShell` and
## in `Settings` rather than in any one game. Every game in `GameCatalog` is
## driven through the same lives round here, so a new game inherits this
## coverage by declaring a manifest.
##
## Gameplay scenes are resolved with `load()` and poked with `call`/`get` on
## purpose: naming `GameShell` would drag it into this script's compile pass,
## which runs before the autoloads it depends on exist.

var _failures := PackedStringArray()
var _original_values: Dictionary = {}

const TOUCHED_KEYS := [
	Settings.ROUND_MODE_KEY,
	Settings.STARTING_LIVES_KEY,
	Settings.EXTRA_ROUND_TIME_KEY,
]


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var settings := get_root().get_node_or_null("Settings")
	var session := get_root().get_node_or_null("GameSession")
	if settings == null or session == null:
		printerr("Settings and GameSession autoloads are unavailable.")
		quit(1)
		return

	for key: String in TOUCHED_KEYS:
		_original_values[key] = settings.call("get_value", key)

	_test_defaults()
	_test_settings_helpers(settings)
	await _test_settings_menu(settings)
	await _test_instructions(settings, session)
	await _test_rounds(settings, session)
	await _test_wrong_key_costs_a_life(settings, session)

	for key: String in TOUCHED_KEYS:
		settings.call("set_value", key, _original_values[key])
	settings.call("save")

	if _failures.is_empty():
		print("Lives mode tests passed.")
		quit(0)
		return
	for failure in _failures:
		printerr(failure)
	quit(1)


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)


# --------------------------------------------------------------------------
# Settings
# --------------------------------------------------------------------------


func _test_defaults() -> void:
	_expect(
		int(Settings.DEFAULTS[Settings.ROUND_MODE_KEY]) == Settings.RoundMode.TIMER,
		"The countdown must stay the default round mode."
	)
	_expect(
		int(Settings.DEFAULTS[Settings.STARTING_LIVES_KEY]) == 3
		and Settings.DEFAULT_STARTING_LIVES == 3,
		"Lives mode must start a player on three lives."
	)


func _test_settings_helpers(settings: Node) -> void:
	settings.call("set_value", Settings.ROUND_MODE_KEY, Settings.RoundMode.TIMER)
	_expect(
		not bool(settings.call("lives_mode_enabled")),
		"The timer round mode must not report lives mode."
	)

	settings.call("set_value", Settings.ROUND_MODE_KEY, Settings.RoundMode.LIVES)
	_expect(
		bool(settings.call("lives_mode_enabled"))
		and str(settings.call("round_mode_label")) == "Lives",
		"Selecting lives mode must be readable through Settings."
	)

	# A save file from another build must never strand the player in a mode
	# this one cannot run.
	settings.call("set_value", Settings.ROUND_MODE_KEY, 47)
	_expect(
		int(settings.call("round_mode")) == Settings.RoundMode.TIMER,
		"An unknown stored round mode must fall back to the countdown."
	)

	settings.call("set_value", Settings.STARTING_LIVES_KEY, 99)
	_expect(
		int(settings.call("starting_lives")) == Settings.MAX_STARTING_LIVES,
		"Starting lives must clamp to the supported maximum."
	)
	settings.call("set_value", Settings.STARTING_LIVES_KEY, 0)
	_expect(
		int(settings.call("starting_lives")) == Settings.MIN_STARTING_LIVES,
		"Starting lives must clamp to the supported minimum."
	)


## Round mode and starting lives shape one game's round, so they live on the
## in-game Game tab and the screen has to be told which game is running.
func _test_settings_menu(settings: Node) -> void:
	settings.call("set_value", Settings.ROUND_MODE_KEY, Settings.RoundMode.TIMER)
	settings.call("set_value", Settings.STARTING_LIVES_KEY, 3)

	var packed := load("res://scenes/menus/settings_menu.tscn") as PackedScene
	if packed == null:
		_failures.append("Could not load the settings menu scene.")
		return
	var menu := packed.instantiate()
	menu.set("game_context_id", GameCatalog.current_id())
	get_root().add_child(menu)
	await process_frame

	var round_mode := menu.get_node_or_null("%RoundModeOption") as OptionButton
	var lives := menu.get_node_or_null("%StartingLivesSlider") as HSlider
	var lives_value := menu.get_node_or_null("%StartingLivesValue") as Label
	var game_list := menu.get_node_or_null(
		"Margins/Layout/Tabs/Game/Pad/List"
	) as VBoxContainer

	_expect(
		round_mode != null and lives != null and lives_value != null
		and game_list != null
		and round_mode.get_parent().get_parent() == game_list
		and lives.get_parent().get_parent() == game_list,
		"Round mode and starting lives must live on the Game tab."
	)
	if round_mode == null or lives == null or lives_value == null:
		get_root().remove_child(menu)
		menu.free()
		return

	_expect(
		round_mode.item_count == 2
		and round_mode.get_item_id(0) == Settings.RoundMode.TIMER
		and round_mode.get_item_id(1) == Settings.RoundMode.LIVES,
		"The round mode picker must offer exactly the two round modes."
	)
	_expect(
		not round_mode.tooltip_text.is_empty()
		and round_mode.accessibility_description == round_mode.tooltip_text
		and not lives.tooltip_text.is_empty()
		and lives.accessibility_description == lives.tooltip_text,
		"Round mode settings must expose details through accessible tooltips."
	)
	_expect(
		lives.min_value == Settings.MIN_STARTING_LIVES
		and lives.max_value == Settings.MAX_STARTING_LIVES,
		"The starting lives slider must span the range Settings clamps to."
	)
	_expect(
		not lives.editable,
		"The starting lives slider must be inert while the countdown runs."
	)

	round_mode.selected = round_mode.get_item_index(Settings.RoundMode.LIVES)
	round_mode.item_selected.emit(round_mode.selected)
	await process_frame
	_expect(
		bool(settings.call("lives_mode_enabled")),
		"The Game tab must switch the round mode to lives."
	)
	_expect(
		lives.editable,
		"Choosing lives mode must enable the starting lives slider."
	)

	lives.value = 5
	await process_frame
	_expect(
		int(settings.call("starting_lives")) == 5
		and typeof(settings.call("get_value", Settings.STARTING_LIVES_KEY)) == TYPE_INT,
		"The Game tab must store the lives pool as a whole count."
	)
	_expect(
		lives_value.text == "5 lives",
		"The starting lives row must read out the chosen pool."
	)

	lives.value = 1
	await process_frame
	_expect(
		lives_value.text == "1 life",
		"A one-life pool must be worded in the singular."
	)

	get_root().remove_child(menu)
	menu.free()
	await process_frame


# --------------------------------------------------------------------------
# Gameplay
# --------------------------------------------------------------------------


## The briefing must promise the round the player is about to get, not always
## a countdown.
func _test_instructions(settings: Node, session: Node) -> void:
	session.call("configure_single_player")
	for manifest in GameCatalog.all():
		GameCatalog.select(manifest.id)

		settings.call(
			"set_value", Settings.ROUND_MODE_KEY, Settings.RoundMode.TIMER
		)
		var timed := await _instructions_copy()
		_expect(
			not str(timed.get("rules", "")).contains("lives per round"),
			"%s must not advertise lives under the countdown." % manifest.id
		)

		settings.call(
			"set_value", Settings.ROUND_MODE_KEY, Settings.RoundMode.LIVES
		)
		settings.call("set_value", Settings.STARTING_LIVES_KEY, 3)
		var lived := await _instructions_copy()
		_expect(
			str(lived.get("rules", "")).contains("3 lives per round"),
			"%s must brief the lives pool before a lives round." % manifest.id
		)
		_expect(
			not str(lived.get("summary", "")).contains("timer reaches zero"),
			"%s must not promise a countdown in lives mode." % manifest.id
		)


func _instructions_copy() -> Dictionary:
	var packed := load("res://scenes/menus/instructions.tscn") as PackedScene
	if packed == null:
		_failures.append("Could not load the instructions scene.")
		return {}
	var screen := packed.instantiate()
	get_root().add_child(screen)
	await process_frame
	var copy := {
		"rules": (screen.get_node("%Rules") as Label).text,
		"summary": (screen.get_node("%Summary") as Label).text,
	}
	get_root().remove_child(screen)
	screen.free()
	await process_frame
	return copy


func _test_rounds(settings: Node, session: Node) -> void:
	settings.call("set_value", Settings.ROUND_MODE_KEY, Settings.RoundMode.LIVES)
	settings.call("set_value", Settings.STARTING_LIVES_KEY, 3)
	settings.call("set_value", Settings.EXTRA_ROUND_TIME_KEY, 0.0)

	var manifests := GameCatalog.all()
	_expect(not manifests.is_empty(), "GameCatalog must discover at least one game.")
	for manifest in manifests:
		GameCatalog.select(manifest.id)
		session.call("configure_single_player")
		await _drive_lives_round(manifest)


## Plays one game through a full lives round: three mistakes, three lost lives,
## then the same results panel the countdown produces.
func _drive_lives_round(manifest: GameManifest) -> void:
	var packed := load(manifest.gameplay_scene_path) as PackedScene
	if packed == null:
		_failures.append("Could not load %s" % manifest.gameplay_scene_path)
		return
	var game := packed.instantiate()
	get_root().add_child(game)
	await process_frame
	await process_frame

	var timer := game.get_node("%RoundTimer") as Timer
	var time_label := game.get_node("%TimeLabel") as Label
	var time_caption := game.get_node("%TimeCaption") as Label
	var time_progress := game.get_node("%TimeProgress") as ProgressBar
	var round_over := game.get_node("%RoundOver") as Control

	_expect(
		bool(game.get("_round_active")),
		"%s must be mid-round once the scene is ready." % manifest.id
	)
	_expect(
		bool(game.get("_lives_mode")) and timer.is_stopped(),
		"%s must replace the countdown with lives, not run both." % manifest.id
	)

	var lives: Array = game.get("_lives")
	_expect(
		int(lives[0]) == 3,
		"%s must open a lives round on three lives." % manifest.id
	)
	_expect(
		time_caption.text == "LIVES LEFT" and time_label.text == "3"
		and is_equal_approx(time_progress.max_value, 3.0)
		and is_equal_approx(time_progress.value, 3.0),
		"%s must show the lives pool where the countdown was." % manifest.id
	)
	_expect(
		is_equal_approx(
			float(game.call("_round_time_left")),
			float(game.get("_active_round_duration"))
		),
		"%s must hold its opening pace when nothing counts down." % manifest.id
	)

	game.call("_lose_life", 0)
	await process_frame
	lives = game.get("_lives")
	_expect(
		int(lives[0]) == 2 and time_label.text == "2"
		and is_equal_approx(time_progress.value, 2.0),
		"%s must charge one life per mistake." % manifest.id
	)
	_expect(
		bool(game.get("_round_active")) and not round_over.visible,
		"%s must keep playing while lives remain." % manifest.id
	)
	_expect(
		not bool(game.call("_player_is_out", 0)),
		"%s must not eliminate a player who still has lives." % manifest.id
	)

	game.call("_lose_life", 0)
	game.call("_lose_life", 0)
	await process_frame

	lives = game.get("_lives")
	_expect(
		int(lives[0]) == 0 and bool(game.call("_player_is_out", 0)),
		"%s must eliminate a player who spends their last life." % manifest.id
	)
	_expect(
		not bool(game.get("_round_active")) and round_over.visible
		and timer.is_stopped(),
		"%s must end the round when the lives run out." % manifest.id
	)
	_expect(
		not (game.get_node("%ResultLabel") as Label).text.is_empty()
		and not (game.get_node("%RoundSubtitle") as Label).text.is_empty(),
		"%s must still headline a round that ended on lives." % manifest.id
	)
	# A lives round has no fixed length, so the scorecard reports the time the
	# player actually survived rather than a countdown that never ran.
	_expect(
		(game.get_node("%GameDurationStat") as Label).text.ends_with("SEC"),
		"%s must report how long a lives round lasted." % manifest.id
	)

	# Charging an eliminated player again must not resurrect the round.
	game.call("_lose_life", 0)
	_expect(
		not bool(game.get("_round_active")),
		"%s must ignore mistakes made after the round ended." % manifest.id
	)

	var payload: Dictionary = game.call("_share_payload")
	_expect(
		str(payload.get("mode", "")).contains("3 Lives"),
		"%s must stamp the lives pool on the share payload." % manifest.id
	)

	game.call("_on_play_again_pressed")
	await process_frame
	lives = game.get("_lives")
	_expect(
		bool(game.get("_round_active")) and int(lives[0]) == 3,
		"%s must refill the lives pool on a replay." % manifest.id
	)

	timer.stop()
	game.set("_round_active", false)
	get_root().remove_child(game)
	game.free()
	await process_frame


## Triangle Rush is the game whose mistake is a key press, so it is where the
## "wrong key costs a life" rule is checked end to end.
func _test_wrong_key_costs_a_life(settings: Node, session: Node) -> void:
	settings.call("set_value", Settings.ROUND_MODE_KEY, Settings.RoundMode.LIVES)
	settings.call("set_value", Settings.STARTING_LIVES_KEY, 2)

	var manifest := GameCatalog.get_manifest("triangle_rush")
	if manifest == null:
		_failures.append("Triangle Rush must be registered in GameCatalog.")
		return
	GameCatalog.select(manifest.id)
	session.call("configure_single_player")

	var packed := load(manifest.gameplay_scene_path) as PackedScene
	var game := packed.instantiate()
	get_root().add_child(game)
	await process_frame
	await process_frame

	var lives: Array = game.get("_lives")
	_expect(
		int(lives[0]) == 2,
		"Triangle Rush must honour the chosen lives pool."
	)

	game.call("_attempt_target", _wrong_target(game))
	await process_frame
	lives = game.get("_lives")
	_expect(
		int(lives[0]) == 1,
		"A wrong key or triangle must cost Triangle Rush a life."
	)

	var correct: Object = (game.get("_active_targets") as Array)[0]
	game.call("_attempt_target", correct)
	await process_frame
	lives = game.get("_lives")
	_expect(
		int(lives[0]) == 1,
		"A correct match must never cost Triangle Rush a life."
	)

	game.call("_attempt_target", _wrong_target(game))
	await process_frame
	_expect(
		not bool(game.get("_round_active"))
		and (game.get_node("%RoundOver") as Control).visible,
		"Spending the last life on a wrong key must end the round."
	)

	# An eliminated player stops scoring even if more input arrives.
	var score_before: int = (game.get("_scores") as Array)[0]
	game.call("_attempt_target", correct)
	_expect(
		int((game.get("_scores") as Array)[0]) == score_before,
		"An eliminated Triangle Rush player must stop scoring."
	)

	(game.get_node("%RoundTimer") as Timer).stop()
	game.set("_round_active", false)
	get_root().remove_child(game)
	game.free()
	await process_frame


func _wrong_target(game: Node) -> Object:
	var active: Object = (game.get("_active_targets") as Array)[0]
	for entry in game.get("_targets") as Array:
		var candidate := entry as Node
		if int(candidate.get("player_index")) == 0 and candidate != active:
			return candidate
	return null
