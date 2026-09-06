class_name GameShell
extends Node2D

## Shared round shell every DeskCanSaw game plays inside.
##
## A game scene owns its actors, its art and its scoring; everything around
## that - the HUD, the countdown, the pause overlay, the results and stats
## panels, the share card, and the accessibility settings plumbing - is
## identical from game to game and lives here.
##
## Subclasses override the small set of `_`-prefixed hooks below rather than
## reimplementing the shell. Every hook has a neutral default so a new game
## only overrides what it actually changes. The framework never branches on a
## game id: anything game-specific is either a hook or a `GameManifest` field.
##
## Expected scene contract (see `scenes/game/game_shell.tscn`): a `Node2D` root
## with `%Playfield`, `%WorldFX`, `%HUD`, `%RoundTimer` and the HUD widgets
## referenced below, all reachable by scene-unique name.

@export_file("*.tscn") var pause_scene := "res://scenes/menus/pause_menu.tscn"
@export_file("*.tscn") var main_menu_scene := "res://scenes/menus/main_menu.tscn"

## Design-time round length. Games that expose a player-facing round-length
## tunable override `_load_round_settings()` and ignore this.
@export_range(5.0, 180.0, 1.0) var round_duration := 30.0

## Player colours drive the score labels, the results panel and the share card.
@export var player_one_color := Color("4da3ff")
@export var player_two_color := Color("ff5c6c")

## How quickly screen shake settles, in pixels per second.
@export_range(1.0, 200.0, 1.0) var screen_shake_decay := 30.0

## Drop a gameplay track here to have it fade in when the scene starts.
@export var music: AudioStream

const PLAYER_ONE := 0
const PLAYER_TWO := 1
const PLAYER_COUNT := 2
const SIDE_CLEARANCE := 38.0
const TOP_CLEARANCE := 190.0
const BOTTOM_CLEARANCE := 105.0
const DANGER_SECONDS := 8.0
const DANGER_COLOR := Color("ff4964")

@onready var _playfield: Node2D = %Playfield
@onready var _world_fx: Node2D = %WorldFX
@onready var _hud: CanvasLayer = %HUD
@onready var _screen_flash: ColorRect = %ScreenFlash
@onready var _danger_overlay: ColorRect = %DangerOverlay
@onready var _player_one_card: PanelContainer = %PlayerOneCard
@onready var _player_two_card: PanelContainer = %PlayerTwoCard
# The card captions, the two "VS" labels and the second stats card share their
# names with sibling widgets, so they are addressed by path rather than by a
# scene-unique name.
@onready var _player_one_caption: Label = (
	$HUD/Overlay/Margins/Layout/TopBar/PlayerOneCard/Layout/Caption
)
@onready var _player_two_caption: Label = (
	$HUD/Overlay/Margins/Layout/TopBar/PlayerTwoCard/Layout/Caption
)
@onready var _player_one_score: Label = %PlayerOneScore
@onready var _player_two_score: Label = %PlayerTwoScore
@onready var _player_one_streak: Label = %PlayerOneStreak
@onready var _player_two_streak: Label = %PlayerTwoStreak
@onready var _time_label: Label = %TimeLabel
@onready var _time_caption: Label = %TimeCaption
@onready var _mode_title: Label = %ModeTitle
@onready var _pause_button: Button = %PauseButton
@onready var _time_progress: ProgressBar = %TimeProgress
@onready var _callout: Label = %Callout
@onready var _hint: Label = %Hint
@onready var _announcement: Label = %Announcement
@onready var _round_timer: Timer = %RoundTimer
@onready var _round_over: Control = %RoundOver
@onready var _round_panel: PanelContainer = %RoundPanel
@onready var _score_panel: PanelContainer = %ScorePanel
@onready var _result_label: Label = %ResultLabel
@onready var _round_subtitle: Label = %RoundSubtitle
@onready var _round_player_one_score: Label = %RoundPlayerOneScore
@onready var _round_player_two_score: Label = %RoundPlayerTwoScore
@onready var _round_versus: Label = (
	$HUD/RoundOver/Center/RoundPanel/Layout/ScoreShowdown/Versus
)
@onready var _round_player_two_card: PanelContainer = %PlayerTwoScoreCard
@onready var _round_player_two_caption: Label = (
	$HUD/RoundOver/Center/RoundPanel/Layout/ScoreShowdown/PlayerTwoScoreCard/Layout/Caption
)
@onready var _round_highlight: Label = %RoundHighlight
@onready var _round_instructions: Label = %RoundInstructions
@onready var _see_score_button: Button = %SeeScoreButton
@onready var _play_again_button: Button = %PlayAgainButton
@onready var _score_screen_title: Label = %ScoreScreenTitle
@onready var _score_screen_subtitle: Label = %ScoreScreenSubtitle
@onready var _game_duration_stat: Label = %GameDurationStat
@onready var _game_hits_stat: Label = %GameHitsStat
@onready var _game_accuracy_stat: Label = %GameAccuracyStat
@onready var _player_one_stats_score: Label = %PlayerOneStatsScore
@onready var _player_one_stats_hits: Label = %PlayerOneStatsHits
@onready var _player_one_stats_misses: Label = %PlayerOneStatsMisses
@onready var _player_one_stats_accuracy: Label = %PlayerOneStatsAccuracy
@onready var _player_one_stats_streak: Label = %PlayerOneStatsStreak
@onready var _player_two_stats_score: Label = %PlayerTwoStatsScore
@onready var _player_two_stats_hits: Label = %PlayerTwoStatsHits
@onready var _player_two_stats_misses: Label = %PlayerTwoStatsMisses
@onready var _player_two_stats_accuracy: Label = %PlayerTwoStatsAccuracy
@onready var _player_two_stats_streak: Label = %PlayerTwoStatsStreak
@onready var _stats_versus: Label = (
	$HUD/RoundOver/Center/ScorePanel/Layout/Report/Players/Versus
)
@onready var _player_two_stats_card: PanelContainer = (
	$HUD/RoundOver/Center/ScorePanel/Layout/Report/Players/PlayerTwo
)
@onready var _player_two_stats_title: Label = (
	$HUD/RoundOver/Center/ScorePanel/Layout/Report/Players/PlayerTwo/Layout/Title
)
@onready var _back_to_results_button: Button = %BackToResultsButton
@onready var _save_image_button: Button = %SaveImageButton
@onready var _open_image_button: Button = %OpenImageButton
@onready var _share_card_preview: TextureRect = %ShareCardPreview
@onready var _share_placeholder: Label = %SharePlaceholder
@onready var _share_card_hint: Label = %ShareCardHint
@onready var _share_status: Label = %ShareStatus

var _scores := [0, 0]
var _streaks := [0, 0]
var _best_streaks := [0, 0]
var _rng := RandomNumberGenerator.new()
var _displayed_seconds := -1
var _round_active := false
var _round_id := 0
var _ambient_time := 0.0
var _intense_effects_enabled := true
var _reduced_motion_enabled := false
var _shake_strength := 0.0
var _sharing := false
## Round the currently displayed scorecard image belongs to, so a replay never
## shows the previous round's card.
var _share_card_round := -1
var _saved_image_path := ""
var _pause_menu: MenuScreen
var _announcement_tween: Tween
var _flash_tween: Tween
var _round_panel_tween: Tween
var _share_status_tween: Tween
var _round_achievements: Array[Dictionary] = []
var _round_progression_notes := PackedStringArray()
var _round_result_color := StudioInfo.SKY
var _active_round_duration := 30.0
## Set from [method Settings.lives_mode_enabled] when a round starts, so a mode
## change mid-round only takes effect on the next one.
var _lives_mode := false
var _starting_lives := Settings.DEFAULT_STARTING_LIVES
var _lives := [0, 0]
## Seconds the current round has been running. Lives mode has no fixed length,
## so this is what the results and stats panels report instead.
var _round_elapsed := 0.0
var _round_gameplay_speed := 1.0
var _round_target_size := 1.0


func _ready() -> void:
	GameCatalog.theme().restyle_tree(self)
	_rng.randomize()
	_intense_effects_enabled = Settings.visual_effects_enabled()
	_reduced_motion_enabled = Settings.reduced_motion_enabled()
	_load_round_settings()
	Settings.changed.connect(_on_setting_changed)
	GameSession.gamepad_availability_changed.connect(
		_on_gamepad_availability_changed
	)
	_prepare_session()

	_configure_mode_ui()
	# Escape and the gamepad Back button already pause, so the HUD button is
	# clutter next to the scores on anything with keys or a pad. A touchscreen
	# has neither, so it is the only pause affordance there and has to stay.
	_pause_button.visible = DisplayServer.is_touchscreen_available()
	_player_one_score.add_theme_color_override("font_color", player_one_color)
	_player_two_score.add_theme_color_override("font_color", player_two_color)
	_player_one_streak.add_theme_color_override("font_color", player_one_color)
	_player_two_streak.add_theme_color_override("font_color", player_two_color)
	_reset_round_gauge()
	AudioManager.attach_ui_sounds(_hud)

	if music:
		AudioManager.play_music(music)

	_build_playfield()
	_begin_first_round()


func _process(delta: float) -> void:
	if not _reduced_motion_enabled:
		_ambient_time += delta
	queue_redraw()
	_update_screen_shake(delta)

	if not _round_active:
		return

	if _lives_mode:
		_round_elapsed += delta
		_update_round(delta, _round_time_left())
		_update_urgency(_lives_urgency_seconds())
		return

	var time_left := _round_timer.time_left
	_round_elapsed += delta
	_update_round(delta, time_left)
	_time_progress.value = time_left
	_update_urgency(time_left)

	var seconds_left := int(ceil(time_left))
	if seconds_left != _displayed_seconds:
		_update_time(seconds_left)


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("pause"):
		get_viewport().set_input_as_handled()
		if _round_over.visible and _score_panel.visible:
			_show_round_results()
			return
		open_pause_menu()
		return

	if not _round_active:
		return

	_handle_gameplay_input(event)


# --------------------------------------------------------------------------
# Game identity
# --------------------------------------------------------------------------


## The `games/<id>/` folder name. Override in every game so the shell can find
## the matching `GameManifest` without the framework naming any game.
func game_id() -> String:
	return ""


## This game's manifest, or `null` when the scene runs outside the catalog.
func manifest() -> GameManifest:
	return GameCatalog.get_manifest(game_id())


func _game_title() -> String:
	var game := manifest()
	return game.title if game else StudioInfo.TITLE


# --------------------------------------------------------------------------
# Round lifecycle
# --------------------------------------------------------------------------


func _start_round() -> void:
	_round_id += 1
	_round_timer.stop()
	_load_round_settings()
	_scores = [0, 0]
	_streaks = [0, 0]
	_best_streaks = [0, 0]
	_round_achievements.clear()
	_round_progression_notes.clear()
	_round_elapsed = 0.0
	_round_active = true
	_round_over.hide()
	_score_panel.hide()
	_round_panel.show()
	_round_panel.modulate = Color.WHITE
	_round_panel.scale = Vector2.ONE
	_share_status.hide()
	_share_card_round = -1
	_saved_image_path = ""
	_open_image_button.hide()
	_set_share_placeholder("Open the scorecard to draw your share image.")
	_reset_motion_fx()
	_reset_round_gauge()
	_reset_round_state()
	_update_scores()
	_update_streaks()
	# The HUD copy describes the options this round is running with, so it is
	# rebuilt after `_load_round_settings()` rather than only once at startup.
	_configure_mode_ui()

	if not _lives_mode:
		_round_timer.start(_active_round_duration)
	_activate_round()


## Waits for the `Router` fade to finish so the first round does not burn
## seconds behind the transition overlay.
func _start_round_after_transition() -> void:
	if Router.is_transitioning():
		await Router.transition_finished
	if is_inside_tree():
		_start_round()


func _on_round_timer_timeout() -> void:
	_end_round()


## Settles the finished round: results copy, achievements, progression, the
## share payload and the results panel.
##
## Reached from the countdown running out in timed mode and from the last
## player losing their last life in lives mode, so both modes end a round
## through exactly the same path.
func _end_round() -> void:
	_round_active = false
	_round_timer.stop()
	_finish_round()
	if _lives_mode:
		_update_lives()
	else:
		_update_time(0)
		_time_progress.value = 0.0
	_reset_urgency()

	var player_one_total: int = _scores[PLAYER_ONE]
	var player_two_total: int = _scores[PLAYER_TWO]
	_round_player_one_score.text = "%d" % player_one_total
	_round_player_two_score.text = "%d" % player_two_total

	var outcome := _describe_round_outcome(player_one_total, player_two_total)
	var result_text := str(outcome.get("result", "DRAW!"))
	var celebration_color: Color = outcome.get("color", StudioInfo.CREAM)
	_result_label.text = result_text
	_result_label.add_theme_color_override("font_color", celebration_color)
	_round_subtitle.text = str(outcome.get("subtitle", ""))

	_award_round_achievements(player_one_total, player_two_total)
	var unlocked_title := _record_round(player_one_total, player_two_total)

	_round_highlight.text = _round_highlight_summary()
	_round_result_color = celebration_color
	_populate_score_screen(result_text, celebration_color)
	_spawn_round_confetti(celebration_color)
	_round_over.show()
	_score_panel.hide()
	_round_panel.show()
	_animate_modal_panel.call_deferred(_round_panel)
	if not unlocked_title.is_empty():
		_celebrate_level_unlock(unlocked_title)
	_play_again_button.grab_focus.call_deferred()


## Offers the finished round to every registered game's unlock rule and folds
## the results back into this round's highlight line. Returns the title of a
## game that unlocked just now, or an empty string.
func _record_round(player_one_total: int, player_two_total: int) -> String:
	var outcomes := AchievementManager.record_round(
		game_id(),
		{
			"single_player": GameSession.is_single_player(),
			"player_one_score": player_one_total,
			"player_two_score": player_two_total,
			"multiplayer_result_is_eligible": (
				GameSession.multiplayer_result_is_eligible()
			),
		}
	)
	var unlocked_title := ""
	for unlocked_game_id: String in outcomes:
		var outcome: Dictionary = outcomes[unlocked_game_id]
		for note: String in outcome.get("notes", []):
			_round_progression_notes.append(note)
		for achievement: Dictionary in outcome.get("unlocked_achievements", []):
			_round_achievements.append(achievement)
		if bool(outcome.get("unlocked_now", false)):
			var game := GameCatalog.get_manifest(unlocked_game_id)
			unlocked_title = game.title if game else unlocked_game_id
	return unlocked_title


func _unlock_round_achievement(id: String) -> void:
	if AchievementManager.unlock(id):
		_round_achievements.append(AchievementManager.get_achievement(id))


func _celebrate_level_unlock(title: String) -> void:
	AudioManager.play_level_unlock()
	AudioManager.request_caption("%s unlocked" % title)
	_show_announcement("%s UNLOCKED!" % title.to_upper(), StudioInfo.SKY, 1.2)
	_flash_screen(StudioInfo.SKY, 0.24)
	_add_screen_shake(10.0)
	_spawn_round_confetti(StudioInfo.SKY)


func _round_highlight_summary() -> String:
	var parts := PackedStringArray([_best_combo_summary()])
	parts.append_array(_round_progression_notes)
	if _round_achievements.is_empty():
		return "  |  ".join(parts)
	var titles := PackedStringArray()
	for achievement in _round_achievements:
		titles.append(str(achievement.get("title", "Achievement")))
	parts.append("Unlocked: %s" % ", ".join(titles))
	return "  |  ".join(parts)


func _best_combo_summary() -> String:
	var player_one_best: int = _best_streaks[PLAYER_ONE]
	if GameSession.is_single_player():
		if player_one_best == 0:
			return "No combo this round - keep chasing the streak."
		return "Best combo: Player 1 chained x%d" % player_one_best

	var player_two_best: int = _best_streaks[PLAYER_TWO]
	if player_one_best == 0 and player_two_best == 0:
		return "No combos this round - the rematch is wide open."
	if player_one_best == player_two_best:
		return "Shared top combo: x%d" % player_one_best
	if player_one_best > player_two_best:
		return "Top combo: Player 1 chained x%d" % player_one_best
	return "Top combo: %s chained x%d" % [_player_name(PLAYER_TWO), player_two_best]


# --------------------------------------------------------------------------
# HUD
# --------------------------------------------------------------------------


func _active_player_indices() -> Array[int]:
	var players: Array[int] = [PLAYER_ONE]
	if GameSession.player_two_enabled():
		players.append(PLAYER_TWO)
	return players


func _player_name(player_index: int) -> String:
	if player_index == PLAYER_TWO:
		return GameSession.player_two_name()
	return "Player %d" % (player_index + 1)


func _player_color(player_index: int) -> Color:
	return player_two_color if player_index == PLAYER_TWO else player_one_color


func _score_label(player_index: int) -> Label:
	return _player_one_score if player_index == PLAYER_ONE else _player_two_score


func _streak_label(player_index: int) -> Label:
	return _player_one_streak if player_index == PLAYER_ONE else _player_two_streak


func _update_scores() -> void:
	_player_one_score.text = "%d" % _scores[PLAYER_ONE]
	_player_two_score.text = "%d" % _scores[PLAYER_TWO]


func _update_streaks() -> void:
	for player_index in _active_player_indices():
		var streak: int = _streaks[player_index]
		_streak_label(player_index).text = (
			"COMBO x%d" % streak if streak >= 2 else " "
		)
	if GameSession.is_single_player():
		_player_two_streak.text = " "


func _update_time(seconds_left: int) -> void:
	_displayed_seconds = maxi(seconds_left, 0)
	_time_label.text = "%02d" % _displayed_seconds
	if _round_active and _displayed_seconds > 0 and _displayed_seconds <= 3:
		_show_announcement(str(_displayed_seconds), DANGER_COLOR)
		AudioManager.request_caption(
			"%d %s remaining" % [
				_displayed_seconds,
				"second" if _displayed_seconds == 1 else "seconds",
			]
		)


# --------------------------------------------------------------------------
# Lives mode
# --------------------------------------------------------------------------
#
# The countdown and the lives pool are alternatives, so both drive the same
# TimerCard readout and the same progress bar. Games never touch that wiring:
# they report a mistake with `_lose_life()` and ask `_player_is_out()` before
# accepting input, which both no-op in timed mode.


## Repoints the TimerCard and the progress bar at whatever this round is
## measuring, and rearms the lives pool.
func _reset_round_gauge() -> void:
	_time_caption.text = "LIVES LEFT" if _lives_mode else "SECONDS LEFT"
	if _lives_mode:
		_lives = [_starting_lives, _starting_lives]
		_displayed_seconds = -1
		_time_progress.max_value = _starting_lives
		_update_lives()
		return

	_lives = [0, 0]
	_time_progress.max_value = _active_round_duration
	_time_progress.value = _active_round_duration
	_update_time(int(ceil(_active_round_duration)))


func _update_lives() -> void:
	if not _lives_mode:
		return
	# Two numbers rather than colour-coded pips, so the readout survives the
	# player-labels and colour-blindness cases the rest of the HUD honours.
	_time_label.text = (
		"%d" % int(_lives[PLAYER_ONE])
		if GameSession.is_single_player()
		else "%d-%d" % [int(_lives[PLAYER_ONE]), int(_lives[PLAYER_TWO])]
	)
	_time_progress.value = _remaining_lives()


## Charges [param player_index] one life for a mistake.
##
## A no-op outside lives mode, so a game can report every mistake it detects
## unconditionally and let the shared round mode decide what it costs.
func _lose_life(player_index: int, amount := 1) -> void:
	if not _lives_mode or not _round_active:
		return
	if not _active_player_indices().has(player_index):
		return

	var previous := int(_lives[player_index])
	var remaining := maxi(previous - maxi(amount, 1), 0)
	if remaining == previous:
		return

	_lives[player_index] = remaining
	_update_lives()
	_announce_lost_life(player_index, remaining)
	_flash_screen(DANGER_COLOR, 0.16)
	_add_screen_shake(9.0)
	if _every_player_is_out():
		_end_round()


## True once lives mode has knocked this player out of the round. Games check
## this before accepting input so an eliminated player stops scoring while the
## others play on.
func _player_is_out(player_index: int) -> bool:
	if not _lives_mode:
		return false
	if player_index < PLAYER_ONE or player_index >= PLAYER_COUNT:
		return false
	return int(_lives[player_index]) <= 0


func _every_player_is_out() -> bool:
	if not _lives_mode:
		return false
	for player_index in _active_player_indices():
		if not _player_is_out(player_index):
			return false
	return true


## Lives still held by the player who has the most of them, which is what the
## progress bar empties towards: the round ends when it reaches zero.
func _remaining_lives() -> int:
	var remaining := 0
	for player_index in _active_player_indices():
		remaining = maxi(remaining, int(_lives[player_index]))
	return remaining


## Maps the lives pool onto the countdown's danger scale so the last life
## pulses and reddens exactly like the last seconds do.
func _lives_urgency_seconds() -> float:
	if _starting_lives <= 0:
		return 0.0
	return DANGER_SECONDS * float(_remaining_lives()) / float(_starting_lives)


func _announce_lost_life(player_index: int, remaining: int) -> void:
	var headline := (
		"OUT!" if remaining == 0
		else "LAST LIFE!" if remaining == 1
		else "%d LIVES LEFT" % remaining
	)
	if not GameSession.is_single_player():
		headline = "%s: %s" % [_player_name(player_index).to_upper(), headline]
	_show_announcement(headline, DANGER_COLOR, 0.42)
	AudioManager.request_caption(
		"%s is out" % _player_name(player_index)
		if remaining == 0
		else "%s: %d %s left" % [
			_player_name(player_index),
			remaining,
			"life" if remaining == 1 else "lives",
		]
	)


## Seconds left on the clock.
##
## Lives mode has no clock, so a round always reports its full length there and
## games that ramp difficulty with the countdown hold their opening pace.
func _round_time_left() -> float:
	return _active_round_duration if _lives_mode else _round_timer.time_left


## How long the round lasted, for the stats panel. Lives mode has no fixed
## length, so it reports the time actually survived.
func _round_length_seconds() -> float:
	return _round_elapsed if _lives_mode else _active_round_duration


## How the round was measured, for results copy that used to say "in 30
## seconds". Reads correctly in both modes, so games never branch on the mode.
func _round_length_phrase() -> String:
	if not _lives_mode:
		return "%d seconds" % roundi(_active_round_duration)
	return "%d seconds on %d %s" % [
		roundi(_round_elapsed),
		_starting_lives,
		"life" if _starting_lives == 1 else "lives",
	]


## Mode line for the share card and the scorecard, including the lives pool
## the round was played with.
func _round_mode_summary() -> String:
	if not _lives_mode:
		return GameSession.mode_title()
	return "%s - %d Lives" % [GameSession.mode_title(), _starting_lives]


## One-line reminder of what a mistake costs, for a game's hint copy. Empty in
## timed mode, where a mistake only costs points.
func _lives_rule_note() -> String:
	if not _lives_mode:
		return ""
	return "Each mistake costs 1 of %d lives" % _starting_lives


## Parks the TimerCard back in its calm state once a round is settled, so the
## readout never stays frozen mid-pulse. A short round could otherwise finish
## inside the danger window and leave the label red.
func _reset_urgency() -> void:
	_update_urgency(DANGER_SECONDS * 2.0)


func _update_urgency(time_left: float) -> void:
	_time_label.pivot_offset = _time_label.size * 0.5
	if time_left > DANGER_SECONDS:
		_time_label.scale = Vector2.ONE
		_time_label.add_theme_color_override("font_color", StudioInfo.CREAM)
		_danger_overlay.color = _with_alpha(DANGER_COLOR, 0.0)
		return

	var urgency := 1.0 - clampf(time_left / DANGER_SECONDS, 0.0, 1.0)
	if _reduced_motion_enabled:
		_time_label.scale = Vector2.ONE
		_time_label.add_theme_color_override(
			"font_color",
			StudioInfo.CREAM.lerp(DANGER_COLOR, urgency)
		)
		_danger_overlay.color = _with_alpha(DANGER_COLOR, 0.0)
		return
	var pulse := (sin(_ambient_time * lerpf(6.0, 11.0, urgency)) + 1.0) * 0.5
	_time_label.scale = Vector2.ONE * (1.0 + pulse * lerpf(0.03, 0.09, urgency))
	_time_label.add_theme_color_override(
		"font_color",
		DANGER_COLOR.lerp(Color.WHITE, pulse * 0.22)
	)
	_danger_overlay.color = _with_alpha(DANGER_COLOR, pulse * urgency * 0.045)


## Shows or hides every second-player widget and titles the round from the
## manifest. Games override this, call `super()`, then write their own
## captions, callout and hint copy.
func _configure_mode_ui() -> void:
	var multiplayer := GameSession.player_two_enabled()
	var player_two_title := GameSession.player_two_name().to_upper()
	_mode_title.text = _game_title().to_upper()
	_player_one_card.size_flags_horizontal = (
		Control.SIZE_SHRINK_BEGIN if multiplayer else Control.SIZE_EXPAND_FILL
	)
	_player_two_card.visible = multiplayer
	_round_versus.visible = multiplayer
	_round_player_two_card.visible = multiplayer
	_round_player_two_caption.text = player_two_title
	_stats_versus.visible = multiplayer
	_player_two_stats_card.visible = multiplayer
	_player_two_stats_title.text = player_two_title


# --------------------------------------------------------------------------
# Results and stats panels
# --------------------------------------------------------------------------


func _populate_score_screen(result_text: String, result_color: Color) -> void:
	var totals := _round_totals()
	var hits := int(totals.get("hits", 0))
	var attempts := int(totals.get("attempts", 0))

	_score_screen_title.text = result_text
	_score_screen_title.add_theme_color_override("font_color", result_color)
	_score_screen_subtitle.text = _round_subtitle.text
	_game_duration_stat.text = "%d SEC" % roundi(_round_length_seconds())
	_game_hits_stat.text = "%d" % hits
	_game_accuracy_stat.text = "%d%%" % _accuracy_percent(hits, attempts)

	_populate_player_stats(PLAYER_ONE)
	_populate_player_stats(PLAYER_TWO)


func _populate_player_stats(player_index: int) -> void:
	var stats := _player_stats(player_index)
	var score := "%d" % int(stats.get("score", 0))
	var hits := "%d" % int(stats.get("hits", 0))
	var misses := "%d" % int(stats.get("misses", 0))
	var accuracy := "%d%%" % int(stats.get("accuracy", 0))
	var streak := "x%d" % int(stats.get("streak", 0))
	if player_index == PLAYER_ONE:
		_player_one_stats_score.text = score
		_player_one_stats_hits.text = hits
		_player_one_stats_misses.text = misses
		_player_one_stats_accuracy.text = accuracy
		_player_one_stats_streak.text = streak
		return
	_player_two_stats_score.text = score
	_player_two_stats_hits.text = hits
	_player_two_stats_misses.text = misses
	_player_two_stats_accuracy.text = accuracy
	_player_two_stats_streak.text = streak


func _accuracy_percent(hits: int, attempts: int) -> int:
	if attempts <= 0:
		return 0
	return roundi(float(hits) / float(attempts) * 100.0)


func _on_see_score_pressed() -> void:
	_round_panel.hide()
	_score_panel.show()
	_animate_modal_panel.call_deferred(_score_panel)
	_back_to_results_button.grab_focus.call_deferred()
	_refresh_share_card()


func _show_round_results() -> void:
	_score_panel.hide()
	_round_panel.show()
	_animate_modal_panel.call_deferred(_round_panel)
	_see_score_button.grab_focus.call_deferred()


func _on_back_to_results_pressed() -> void:
	_show_round_results()


func _on_play_again_pressed() -> void:
	_start_round()


func _on_exit_to_main_menu_pressed() -> void:
	_round_timer.stop()
	_finish_round()
	Router.goto(main_menu_scene)


# --------------------------------------------------------------------------
# Pause
# --------------------------------------------------------------------------


func open_pause_menu() -> void:
	if is_instance_valid(_pause_menu):
		return
	var packed: PackedScene = load(pause_scene)
	if packed == null:
		push_error("Could not load pause menu scene '%s'." % pause_scene)
		return
	_pause_menu = packed.instantiate()
	_pause_menu.closed.connect(_on_pause_closed)
	_hud.add_child(_pause_menu)


func _on_pause_closed() -> void:
	_pause_menu = null


func _on_pause_button_pressed() -> void:
	open_pause_menu()


# --------------------------------------------------------------------------
# Sharing
# --------------------------------------------------------------------------


func _on_share_pressed() -> void:
	if _sharing:
		return
	_sharing = true
	var shared_round_id := _round_id
	_set_share_buttons_disabled(true)
	_show_share_status("Saving your scorecard...", StudioInfo.MUTED, false)

	var result: Dictionary = await ShareManager.generate_score_image(_share_payload())
	if not is_inside_tree():
		return

	_sharing = false
	_set_share_buttons_disabled(false)
	if shared_round_id != _round_id:
		return
	if bool(result.get("ok", false)):
		AudioManager.play_share()
		_apply_share_card(result, shared_round_id)
		_saved_image_path = str(result.get("global_path", ""))
		_open_image_button.visible = (
			bool(result.get("can_open_original", false))
			and not _saved_image_path.is_empty()
		)
		_show_share_status(
			str(result.get("message", "Share image ready.")),
			StudioInfo.SKY
		)
	else:
		AudioManager.play_game_miss()
		var message := str(result.get("message", "The share image could not be created."))
		push_warning(message)
		_show_share_status(message, DANGER_COLOR)


func _on_open_image_pressed() -> void:
	var error := ShareManager.open_original_image(_saved_image_path)
	if error != OK:
		_show_share_status("The saved image could not be opened.", DANGER_COLOR)
		push_warning("Opening the share image failed with error %d." % error)
		return
	_show_share_status("Opened in your default image viewer.", StudioInfo.SKY)


## Draws the finished round's share card straight into the scorecard, so the
## panel shows the very image the player would post. Rendering only - nothing
## is written to disk until "Save Image" is pressed.
func _refresh_share_card() -> void:
	if _share_card_round == _round_id or _sharing:
		return
	if not ShareQrCode.validation_error(_stats_url()).is_empty():
		_set_share_placeholder("A scorecard image is not available for this game.")
		return

	_share_card_round = _round_id
	_set_share_placeholder("Drawing your scorecard...")
	var previewed_round_id := _round_id
	var result: Dictionary = await ShareManager.preview_score_image(_share_payload())
	if not is_inside_tree() or previewed_round_id != _round_id:
		return
	if bool(result.get("ok", false)):
		_apply_share_card(result, previewed_round_id)
		return
	# A missing renderer or a busy manager is not an error the player caused.
	_share_card_round = -1
	_set_share_placeholder(str(result.get("message", "Scorecard preview unavailable.")))


func _apply_share_card(result: Dictionary, round_id: int) -> void:
	var texture: Texture2D = result.get("texture")
	if texture == null:
		return
	_share_card_round = round_id
	_share_card_preview.texture = texture
	_share_placeholder.hide()


func _set_share_placeholder(message: String) -> void:
	_share_card_preview.texture = null
	_share_placeholder.text = message
	_share_placeholder.show()


## The QR target for both the embedded card and the saved image, so the two can
## never disagree about where the stats live.
func _stats_url() -> String:
	var game := manifest()
	return game.resolved_stats_url() if game else ""


func _share_payload() -> Dictionary:
	var totals := _round_totals()
	var hits := int(totals.get("hits", 0))
	var attempts := int(totals.get("attempts", 0))
	var best_combo := 0
	for player_index in _active_player_indices():
		best_combo = maxi(best_combo, int(_best_streaks[player_index]))

	var achievement_titles := _share_achievement_titles()
	var achievements_are_new := not _round_achievements.is_empty()
	var accuracy := _accuracy_percent(hits, attempts)
	var score_values: Array[int] = [_scores[PLAYER_ONE]]
	if GameSession.player_two_enabled():
		score_values.append(_scores[PLAYER_TWO])
	return {
		"game_id": game_id(),
		"game_title": _game_title(),
		"studio": StudioInfo.STUDIO,
		"website": StudioInfo.WEBSITE,
		"stats_url": _stats_url(),
		"mode": _round_mode_summary(),
		"result": _result_label.text,
		"subtitle": _round_subtitle.text,
		"score_caption": "SOLO SCORE" if GameSession.is_single_player() else "FINAL SCORE",
		"score": (
			str(_scores[PLAYER_ONE])
			if GameSession.is_single_player()
			else "%d - %d" % [_scores[PLAYER_ONE], _scores[PLAYER_TWO]]
		),
		"accuracy": "%d%%" % accuracy,
		"hits": str(hits),
		"combo": "x%d" % best_combo,
		"score_values": score_values,
		"accuracy_value": accuracy,
		"hits_value": hits,
		"misses_value": maxi(attempts - hits, 0),
		"combo_value": best_combo,
		"achievements": achievement_titles,
		"achievements_are_new": achievements_are_new,
		"achievement_count": AchievementManager.unlocked_count(),
		"achievement_badge": (
			str(_round_achievements[0].get("badge", "NEW"))
			if achievements_are_new
			else "ACH"
		),
		"accent_color": _round_result_color,
		"secondary_color": (
			player_two_color if GameSession.player_two_enabled() else player_one_color
		),
		"footer": "%s  |  %s" % [StudioInfo.TAGLINE, StudioInfo.website_label()],
	}


func _share_achievement_titles() -> PackedStringArray:
	var titles := PackedStringArray()
	var source := _round_achievements
	if source.is_empty():
		source = AchievementManager.get_unlocked_achievements()
	for achievement in source:
		titles.append(str(achievement.get("title", "Achievement")))
	return titles


func _set_share_buttons_disabled(disabled: bool) -> void:
	_save_image_button.disabled = disabled


func _show_share_status(message: String, color: Color, auto_hide := true) -> void:
	if _share_status_tween and _share_status_tween.is_valid():
		_share_status_tween.kill()
	_share_status.text = message
	_share_status.add_theme_color_override("font_color", color)
	_share_status.modulate.a = 1.0
	_share_status.show()
	if not auto_hide:
		return
	_share_status_tween = create_tween()
	_share_status_tween.tween_interval(2.8)
	_share_status_tween.tween_property(_share_status, "modulate:a", 0.0, 0.3)
	_share_status_tween.tween_callback(_share_status.hide)


# --------------------------------------------------------------------------
# Visual effects and accessibility
# --------------------------------------------------------------------------


func _with_alpha(color: Color, alpha: float) -> Color:
	var result := color
	result.a = alpha
	return result


func _add_screen_shake(amount: float) -> void:
	if not _intense_effects_enabled or _reduced_motion_enabled:
		return
	_shake_strength = maxf(_shake_strength, amount)


func _update_screen_shake(delta: float) -> void:
	if (
		not _intense_effects_enabled
		or _reduced_motion_enabled
		or _shake_strength <= 0.05
	):
		_shake_strength = 0.0
		_playfield.position = Vector2.ZERO
		_world_fx.position = Vector2.ZERO
		return

	var offset := Vector2(
		_rng.randf_range(-_shake_strength, _shake_strength),
		_rng.randf_range(-_shake_strength, _shake_strength)
	)
	_playfield.position = offset
	_world_fx.position = offset
	_shake_strength = move_toward(_shake_strength, 0.0, delta * screen_shake_decay)


func _flash_screen(color: Color, alpha: float) -> void:
	if _flash_tween and _flash_tween.is_valid():
		_flash_tween.kill()
	if not _intense_effects_enabled:
		_flash_tween = null
		_screen_flash.color = _with_alpha(color, 0.0)
		return
	_screen_flash.color = _with_alpha(color, alpha)
	_flash_tween = create_tween()
	_flash_tween.tween_property(_screen_flash, "color:a", 0.0, 0.34).set_trans(
		Tween.TRANS_QUAD
	).set_ease(Tween.EASE_OUT)


func _show_announcement(text: String, color: Color, hold_time := 0.28) -> void:
	if _announcement_tween and _announcement_tween.is_valid():
		_announcement_tween.kill()

	_announcement.show()
	_announcement.text = text
	_announcement.add_theme_color_override("font_color", color)
	_announcement.pivot_offset = _announcement.size * 0.5
	if _reduced_motion_enabled:
		_announcement.scale = Vector2.ONE
		_announcement.modulate = Color.WHITE
		_announcement_tween = create_tween()
		_announcement_tween.tween_interval(hold_time)
		_announcement_tween.tween_property(_announcement, "modulate:a", 0.0, 0.16)
		_announcement_tween.finished.connect(_announcement.hide)
		return
	_announcement.scale = Vector2.ONE * 0.68
	_announcement.modulate = Color(1.0, 1.0, 1.0, 0.0)

	_announcement_tween = create_tween()
	_announcement_tween.tween_property(
		_announcement,
		"scale",
		Vector2.ONE,
		0.2
	).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_announcement_tween.parallel().tween_property(_announcement, "modulate:a", 1.0, 0.12)
	_announcement_tween.tween_interval(hold_time)
	_announcement_tween.tween_property(_announcement, "modulate:a", 0.0, 0.2)
	_announcement_tween.parallel().tween_property(
		_announcement,
		"scale",
		Vector2.ONE * 1.12,
		0.2
	)
	_announcement_tween.finished.connect(_announcement.hide)


func _animate_modal_panel(panel: Control) -> void:
	if _round_panel_tween and _round_panel_tween.is_valid():
		_round_panel_tween.kill()
	panel.pivot_offset = panel.size * 0.5
	if _reduced_motion_enabled:
		panel.scale = Vector2.ONE
		panel.modulate = Color.WHITE
		return
	panel.scale = Vector2.ONE * 0.78
	panel.modulate = Color(1.0, 1.0, 1.0, 0.0)
	_round_panel_tween = create_tween().set_parallel(true)
	_round_panel_tween.tween_property(panel, "scale", Vector2.ONE, 0.34).set_trans(
		Tween.TRANS_BACK
	).set_ease(Tween.EASE_OUT)
	_round_panel_tween.tween_property(panel, "modulate:a", 1.0, 0.18)


func _clear_world_fx() -> void:
	for child in _world_fx.get_children():
		child.queue_free()


func _set_intense_effects_enabled(value: bool) -> void:
	_intense_effects_enabled = value
	if not value:
		_reset_intense_effects()


func _reset_intense_effects() -> void:
	if _flash_tween and _flash_tween.is_valid():
		_flash_tween.kill()
	_flash_tween = null
	_shake_strength = 0.0
	_playfield.position = Vector2.ZERO
	_world_fx.position = Vector2.ZERO
	_screen_flash.color = _with_alpha(Color.WHITE, 0.0)


func _reset_motion_fx() -> void:
	_reset_intense_effects()
	_danger_overlay.color = _with_alpha(DANGER_COLOR, 0.0)
	_time_label.scale = Vector2.ONE


func _set_reduced_motion_enabled(value: bool) -> void:
	_reduced_motion_enabled = value
	if value:
		_ambient_time = 0.0
		_reset_reduced_motion_state()
	queue_redraw()


## Parks every decorative animation at its resting frame. Games extend this
## when they own extra tweens or moving actors.
func _reset_reduced_motion_state() -> void:
	_shake_strength = 0.0
	_playfield.position = Vector2.ZERO
	_world_fx.position = Vector2.ZERO
	_danger_overlay.color = _with_alpha(DANGER_COLOR, 0.0)
	_time_label.scale = Vector2.ONE
	_clear_world_fx()
	if _announcement_tween and _announcement_tween.is_valid():
		_announcement_tween.kill()
	_announcement.hide()
	if _round_panel_tween and _round_panel_tween.is_valid():
		_round_panel_tween.kill()
	for panel in [_round_panel, _score_panel]:
		panel.scale = Vector2.ONE
		panel.modulate = Color.WHITE


func _on_setting_changed(key: String, value: Variant) -> void:
	if key == Settings.VISUAL_EFFECTS_KEY:
		_set_intense_effects_enabled(Settings.visual_effects_enabled())
		return
	if key == Settings.REDUCED_MOTION_KEY:
		_set_reduced_motion_enabled(bool(value))
		return
	if key == Settings.PLAYER_LABELS_KEY:
		_on_player_labels_changed()
		return
	if key.begins_with("controls/"):
		_on_controls_changed()
		return
	_on_game_setting_changed(key, value)


## Playfield rectangle inside the HUD clearances, in local coordinates.
func _playfield_bounds() -> Rect2:
	var viewport_size := get_viewport_rect().size
	var minimum := Vector2(SIDE_CLEARANCE, TOP_CLEARANCE)
	var maximum := Vector2(
		viewport_size.x - SIDE_CLEARANCE,
		viewport_size.y - BOTTOM_CLEARANCE
	)
	if maximum.x < minimum.x:
		minimum.x = viewport_size.x * 0.5
		maximum.x = minimum.x
	if maximum.y < minimum.y:
		minimum.y = viewport_size.y * 0.5
		maximum.y = minimum.y
	return Rect2(minimum, maximum - minimum)


## Neutral end-of-round celebration. Games with their own particle language
## override this; it must stay silent under reduced motion.
func _spawn_round_confetti(color: Color) -> void:
	if _reduced_motion_enabled:
		return
	var bounds := _playfield_bounds()
	for index in range(24):
		var piece := Polygon2D.new()
		piece.polygon = PackedVector2Array([
			Vector2(-7.0, -3.0),
			Vector2(9.0, -5.0),
			Vector2(6.0, 4.0),
			Vector2(-8.0, 5.0),
		])
		piece.color = (
			color.lightened(_rng.randf_range(0.0, 0.3))
			if index % 3 == 0
			else Color("d9e2e3")
			if index % 3 == 1
			else Color("ffd34e")
		)
		piece.position = Vector2(
			_rng.randf_range(bounds.position.x, bounds.end.x),
			_rng.randf_range(bounds.position.y, bounds.end.y)
		)
		piece.rotation = _rng.randf_range(0.0, TAU)
		_world_fx.add_child(piece)
		var tween := piece.create_tween().set_parallel(true)
		tween.tween_property(
			piece,
			"position:y",
			piece.position.y + _rng.randf_range(90.0, 210.0),
			0.75
		)
		tween.tween_property(piece, "rotation", piece.rotation + TAU, 0.75)
		tween.tween_property(piece, "modulate:a", 0.0, 0.75).set_delay(0.2)
		tween.finished.connect(piece.queue_free)


# --------------------------------------------------------------------------
# Hooks - override these in `games/<id>/`
# --------------------------------------------------------------------------


## Reads the options that may only change between rounds, including the shared
## round mode. Override and call `super()` to add game-declared
## `GameManifest.tunables`.
func _load_round_settings() -> void:
	_active_round_duration = round_duration + Settings.extra_round_time()
	_round_gameplay_speed = Settings.gameplay_speed_scale()
	_round_target_size = Settings.target_size_scale()
	_lives_mode = Settings.lives_mode_enabled()
	_starting_lives = Settings.starting_lives()


## Settles who is playing before the HUD is configured.
func _prepare_session() -> void:
	GameSession.ensure_controller_assignments()


## Spawns the long-lived actors that survive between rounds.
func _build_playfield() -> void:
	pass


## Kicks off the opening round once the scene is ready.
func _begin_first_round() -> void:
	_start_round_after_transition()


## Clears per-round game state and rearms the actors.
func _reset_round_state() -> void:
	pass


## Runs once the countdown has started: opening cue, caption, announcement.
func _activate_round() -> void:
	_show_announcement("GO!", StudioInfo.CREAM)


## Stops the actors when the round ends or the player leaves.
func _finish_round() -> void:
	pass


## Per-frame gameplay while the round is live. `time_left` is the countdown,
## and holds steady at the full round length in lives mode, where nothing is
## counting down.
func _update_round(_delta: float, _time_left: float) -> void:
	pass


## Gameplay input, already filtered for pause and for an inactive round.
func _handle_gameplay_input(_event: InputEvent) -> void:
	pass


## Result headline, subtitle and celebration colour for the finished round.
func _describe_round_outcome(
	player_one_total: int,
	player_two_total: int
) -> Dictionary:
	if GameSession.is_single_player():
		return {
			"result": "ROUND COMPLETE",
			"subtitle": "Player 1 scored %d points in %s." % [
				player_one_total,
				_round_length_phrase(),
			],
			"color": _player_color(PLAYER_ONE),
		}
	if player_one_total > player_two_total:
		return {
			"result": "PLAYER 1 WINS!",
			"subtitle": "Player 1 wins by %d points." % (
				player_one_total - player_two_total
			),
			"color": _player_color(PLAYER_ONE),
		}
	if player_two_total > player_one_total:
		return {
			"result": "%s WINS!" % _player_name(PLAYER_TWO).to_upper(),
			"subtitle": "%s takes it by %d points." % [
				_player_name(PLAYER_TWO),
				player_two_total - player_one_total,
			],
			"color": _player_color(PLAYER_TWO),
		}
	return {
		"result": "DRAW!",
		"subtitle": "Dead even after %s. Run it back!" % _round_length_phrase(),
		"color": StudioInfo.CREAM,
	}


## Game-specific achievements earned by the finished round. Unlock them with
## `_unlock_round_achievement()` so they reach the results panel and the card.
func _award_round_achievements(_player_one_total: int, _player_two_total: int) -> void:
	pass


## Round-wide `{"hits": int, "attempts": int}` used by the stats panel, the
## accuracy figure and the share card.
func _round_totals() -> Dictionary:
	var hits := 0
	for player_index in _active_player_indices():
		hits += int(_scores[player_index])
	return {"hits": hits, "attempts": hits}


## Per-player `{"score", "hits", "misses", "accuracy", "streak"}` stat row.
func _player_stats(player_index: int) -> Dictionary:
	return {
		"score": _scores[player_index],
		"hits": _scores[player_index],
		"misses": 0,
		"accuracy": 0,
		"streak": _best_streaks[player_index],
	}


## The player-labels accessibility setting changed.
func _on_player_labels_changed() -> void:
	_configure_mode_ui()


## A `controls/...` binding changed.
func _on_controls_changed() -> void:
	_configure_mode_ui()


## A pad was plugged in or the last one removed. Control copy is rebuilt through
## the same hook a rebinding uses, so a game only has to describe its controls
## once and the pad lines appear or disappear on their own.
func _on_gamepad_availability_changed(_available: bool) -> void:
	_on_controls_changed()


## Any other setting changed, including this game's own `tunables`.
func _on_game_setting_changed(_key: String, _value: Variant) -> void:
	pass
