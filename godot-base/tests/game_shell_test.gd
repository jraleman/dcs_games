extends SceneTree

## Framework regression checks for the shared `GameShell` round shell.
##
## Every game in `GameCatalog` is driven through the same flow - finish a
## round, read the results panel, swap to the stats panel, build a share
## payload, open the pause menu, replay - so a new game inherits this coverage
## by declaring a manifest, without touching this file.

var _failures := PackedStringArray()


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var session := get_root().get_node_or_null("GameSession")
	if session == null:
		printerr("GameSession autoload is unavailable.")
		quit(1)
		return

	var manifests := GameCatalog.all()
	_expect(not manifests.is_empty(), "GameCatalog must discover at least one game.")
	for manifest in manifests:
		GameCatalog.select(manifest.id)
		session.call("configure_single_player")
		await _drive(manifest)

	# Scene-owned audio releases its stopped playbacks on the mixer thread.
	await create_timer(0.15, true, false, true).timeout
	if _failures.is_empty():
		print("Game shell tests passed.")
		quit(0)
		return
	for failure in _failures:
		printerr(failure)
	quit(1)


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)


## Plays one game from a finished round through to a fresh one, asserting the
## shell wiring that every game shares.
##
## The scene is resolved with `load()` and poked with `call`/`get` on purpose:
## naming `GameShell` here would drag it into this script's compile pass, which
## runs before the autoloads it depends on exist.
func _drive(manifest: GameManifest) -> void:
	var packed := load(manifest.gameplay_scene_path) as PackedScene
	if packed == null:
		_failures.append("Could not load %s" % manifest.gameplay_scene_path)
		return
	var game := packed.instantiate()
	get_root().add_child(game)
	await process_frame
	await process_frame

	var timer := game.get_node("%RoundTimer") as Timer
	timer.stop()

	_expect(
		game.has_method("_playfield_bounds") and game.has_method("_share_payload")
		and game.has_method("_record_round"),
		"%s must build on GameShell." % manifest.id
	)
	_expect(
		str(game.call("game_id")) == manifest.id,
		"%s must report its own id through the shell." % manifest.id
	)
	_expect(
		(game.get_node("%ModeTitle") as Label).text == manifest.title.to_upper(),
		"%s must title the HUD from its manifest." % manifest.id
	)
	# Esc and the gamepad Back button already pause, so the HUD button is only
	# earning its space on a device that has neither.
	_expect(
		(game.get_node("%PauseButton") as Button).visible
		== DisplayServer.is_touchscreen_available(),
		"%s must only show the HUD pause button on a touchscreen." % manifest.id
	)

	var store := get_root().get_node_or_null("Store")
	var banked := int(store.call("points", manifest.id)) if store != null else 0
	game.set("_scores", [7, 3])
	game.set("_best_streaks", [4, 1])
	game.call("_on_round_timer_timeout")
	await process_frame

	# A game that sells cosmetics has to be paid for the round it just played,
	# or its shop is unreachable by playing it.
	if store != null and bool(store.call("has_store", manifest.id)):
		# `_finish_round` may settle the totals, so the payout is checked
		# against the scores the shell actually ended on.
		var totals: Array = game.get("_scores")
		var earned := int(game.call("_round_points_earned", totals[0], totals[1]))
		_expect(
			earned > 0
			and int(store.call("points", manifest.id)) == banked + earned,
			"%s must bank what its round paid into the store." % manifest.id
		)
		_expect(
			(game.get_node("%RoundHighlight") as Label).text.contains(
				str(store.call("format_points", manifest.id, earned))
			),
			"%s must tell the player what the round earned." % manifest.id
		)

	var round_over := game.get_node("%RoundOver") as Control
	var round_panel := game.get_node("%RoundPanel") as Control
	var score_panel := game.get_node("%ScorePanel") as Control
	_expect(
		round_over.visible and round_panel.visible and not score_panel.visible,
		"%s must show the results panel when a round ends." % manifest.id
	)
	_expect(
		not (game.get_node("%ResultLabel") as Label).text.is_empty()
		and not (game.get_node("%RoundSubtitle") as Label).text.is_empty(),
		"%s must headline and describe the finished round." % manifest.id
	)
	_expect(
		not (game.get_node("%RoundHighlight") as Label).text.is_empty(),
		"%s must summarise the round highlight." % manifest.id
	)
	_expect(
		(game.get_node("%GameDurationStat") as Label).text.ends_with("SEC")
		and (game.get_node("%PlayerOneStatsScore") as Label).text == "7",
		"%s must fill in the shared stats panel." % manifest.id
	)

	game.call("_on_see_score_pressed")
	await process_frame
	_expect(
		score_panel.visible and not round_panel.visible,
		"%s must swap to the stats panel." % manifest.id
	)
	_expect(
		(game.get_node("%SeeScoreButton") as Button).text == "See Scores",
		"%s must label the stats entry point 'See Scores'." % manifest.id
	)
	# The scorecard is a detail view of the results screen, so it offers one way
	# out. Leaving the match stays a decision made on the results panel itself.
	_expect(
		game.get_node_or_null("%StatsPlayAgainButton") == null
		and game.get_node_or_null("%StatsExitToMainMenuButton") == null,
		"%s must not let the stats panel leave the match." % manifest.id
	)
	game.call("_on_back_to_results_pressed")
	await process_frame
	_expect(
		round_panel.visible and not score_panel.visible,
		"%s must swap back to the results panel." % manifest.id
	)

	var payload: Dictionary = game.call("_share_payload")
	_expect(
		str(payload.get("game_id", "")) == manifest.id
		and str(payload.get("game_title", "")) == manifest.title,
		"%s must stamp its identity on the share payload." % manifest.id
	)
	# A single human can still be playing a two-sided match against the CPU.
	var shared_scores: Array = payload.get("score_values", [])
	var expected_scores := [7, 3] if shared_scores.size() == 2 else [7]
	_expect(
		shared_scores == expected_scores
		and str(payload.get("score", "")) == ("7 - 3" if shared_scores.size() == 2 else "7")
		and int(payload.get("hits_value", -1)) >= 0
		and int(payload.get("misses_value", -1)) >= 0
		and int(payload.get("combo_value", -1)) >= 0,
		"%s must report share totals for the finished round." % manifest.id
	)
	_expect(
		str(payload.get("stats_url", "")).to_utf8_buffer().size() <= 42,
		"%s must keep its share QR link scannable." % manifest.id
	)

	game.call("open_pause_menu")
	await process_frame
	var pause_menu := game.get("_pause_menu") as Node
	_expect(pause_menu != null, "%s must open the shared pause menu." % manifest.id)
	if pause_menu != null:
		pause_menu.free()

	game.call("_on_play_again_pressed")
	await process_frame
	_expect(
		bool(game.get("_round_active")) and not round_over.visible,
		"%s must restart cleanly from the results panel." % manifest.id
	)
	_expect(
		int(game.get("_scores")[0]) == 0 and int(game.get("_round_id")) >= 2,
		"%s must clear the score and advance the round id on replay." % manifest.id
	)

	timer.stop()
	game.set("_round_active", false)
	get_root().remove_child(game)
	game.free()
	await process_frame
