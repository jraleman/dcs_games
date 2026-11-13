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
	# Give headless scene checks the same physical HUD metrics as a desktop.
	root.size = Vector2i(1280, 720)
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
	await _test_compact_layout()

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
	# Scores are supplied by this driver, not by incidental live collisions.
	game.process_mode = Node.PROCESS_MODE_DISABLED
	get_root().add_child(game)
	await process_frame
	await process_frame
	if not bool(game.get("_round_active")):
		game.call("_on_play_again_pressed")
		await process_frame

	var timer := game.get_node("%RoundTimer") as Timer
	timer.stop()
	var initial_scores := (game.get("_scores") as Array).duplicate()
	var active: Array = game.call("_active_player_indices")
	var supplied_scores := [7, 3]
	var supplied_streaks := [4, 1]
	while supplied_scores.size() < active.size():
		supplied_scores.append(2)
		supplied_streaks.append(1)

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
	_expect(
		not (game.get_node("%Hint") as Control).is_visible_in_tree(),
		"%s must keep persistent controls in paused help, not over gameplay." % manifest.id
	)
	# Esc and the gamepad Back button already pause, so the HUD button is only
	# earning its space on a device that has neither.
	var pause_button := game.get_node("%PauseButton") as Button
	# A game that moves the button into its own HUD also owns its presentation.
	if pause_button.get_parent() == game.get_node("HUD/Overlay/Margins/Layout/TopBar"):
		_expect(
			pause_button.visible == DisplayServer.is_touchscreen_available(),
			"%s must only show the default HUD pause button on a touchscreen." % manifest.id
		)

	var store := get_root().get_node_or_null("Store")
	var banked := int(store.call("points", manifest.id)) if store != null else 0
	game.set("_scores", supplied_scores)
	game.set("_best_streaks", supplied_streaks)
	game.call("_on_round_timer_timeout")
	await process_frame

	# A synthetic timeout is not necessarily a completed match for a game
	# that owns its ending rule. Its own suite covers genuine earning outcomes.
	if store != null and bool(store.call("has_store", manifest.id)):
		# `_finish_round` may settle the totals, so the payout is checked
		# against the scores the shell actually ended on.
		var totals: Array = game.get("_scores")
		var earned := int(game.call("_round_points_earned", totals[0], totals[1]))
		_expect(
			(earned > 0 or not manifest.uses_shell_round_rules)
			and int(store.call("points", manifest.id)) == banked + maxi(earned, 0),
			"%s must bank what its round paid into the store." % manifest.id
		)
		if earned > 0:
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
	var expected_scores := supplied_scores.slice(0, shared_scores.size())
	var score_parts := PackedStringArray()
	for score in expected_scores:
		score_parts.append(str(score))
	_expect(
		shared_scores == expected_scores
		and str(payload.get("score", "")) == " - ".join(score_parts),
		"%s must report share totals for the finished round." % manifest.id
	)
	# Domain-specific statistics need not invent hit/miss or combo counters.
	for key in ["hits_value", "misses_value", "combo_value"]:
		_expect(
			not payload.has(key) or int(payload[key]) >= 0,
			"%s must not share a negative %s." % [manifest.id, key]
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
		var round_id := int(game.get("_round_id"))
		(pause_menu.get_node("%GuideButton") as Button).pressed.emit()
		await process_frame
		await process_frame
		var guide := pause_menu.call("_active_overlay") as Control
		_expect(
			guide != null and guide.visible and paused,
			"%s must open its Guide without unpausing." % manifest.id
		)
		if guide != null:
			_expect(
				(guide.get_node("%Guide") as Control).is_visible_in_tree()
				and not (guide.get_node("%StartButton") as Control).visible
				and not (guide.get_node("%ShowAgainToggle") as Control).visible
				and not (guide.get_node("%Video") as VideoStreamPlayer).is_playing(),
				"%s's paused Guide must be read-only and must not play a tutorial." % manifest.id
			)
			var hint := (game.get_node("%Hint") as Label).text
			_expect(
				hint.strip_edges().is_empty()
				or (guide.get_node("%Rules") as Label).text.contains(hint),
				"%s must retain its game-owned controls in the Guide." % manifest.id
			)
			guide.call("_on_start_pressed")
			await process_frame
			_expect(
				int(game.get("_round_id")) == round_id and paused
				and (pause_menu as Control).visible,
				"%s's Guide must never restart or leave the round." % manifest.id
			)
		pause_menu.call("resume")
		await process_frame
		_expect(not paused, "%s must resume after leaving its Guide." % manifest.id)

	game.call("_on_play_again_pressed")
	await process_frame
	_expect(
		bool(game.get("_round_active")) and not round_over.visible,
		"%s must restart cleanly from the results panel." % manifest.id
	)
	_expect(
		game.get("_scores") == initial_scores and int(game.get("_round_id")) >= 2,
		"%s must restore its initial scores and advance the round id on replay." % manifest.id
	)

	timer.stop()
	game.set("_round_active", false)
	get_root().remove_child(game)
	game.free()
	await process_frame


func _test_compact_layout() -> void:
	var session := root.get_node("GameSession")
	var settings := root.get_node("Settings")
	var manifest := GameCatalog.current()
	var old_capacity := manifest.max_local_players
	var old_multiplayer := manifest.supports_multiplayer
	var old_scale := float(settings.call("get_value", "ui/scale", 1.0))
	var old_size := root.size
	manifest.max_local_players = 4
	manifest.supports_multiplayer = true
	for count in [1, 2, 4]:
		if count == 1:
			session.call("configure_single_player")
		else:
			session.call("configure_multiplayer", 0, 1, count)
		var shell := (load("res://scenes/game/game_shell.tscn") as PackedScene).instantiate()
		shell.process_mode = Node.PROCESS_MODE_DISABLED
		root.add_child(shell)
		(shell.get_node("%PauseButton") as Control).show()
		for scale_value in [1.0, 1.5]:
			settings.call("set_value", "ui/scale", scale_value)
			for dimensions in [Vector2i(1280, 720), Vector2i(390, 844), Vector2i(844, 390)]:
				root.size = dimensions
				await _settle_layout()
				var viewport := root.get_visible_rect().grow(1.0)
				var cards: Array = shell.get("_player_ui")
				var previous := Rect2()
				for player in count:
					var card := cards[player]["card"] as Control
					var rect := card.get_global_rect()
					_expect(viewport.encloses(rect),
						"All %d score chips must fit at %s, UI %s." % [count, dimensions, scale_value])
					_expect(player == 0 or not rect.intersects(previous),
						"Player chips must not overlap at %s." % dimensions)
					previous = rect
				var pause_button := shell.get_node("%PauseButton") as Control
				_expect(viewport.encloses(pause_button.get_global_rect()),
					"Touch pause must remain on screen at %s." % dimensions)
				var pixels := float(root.size.x) / root.get_visible_rect().size.x
				_expect(pause_button.size.y * pixels >= 43.5 * scale_value,
					"Compact pause must retain a full-size touch target.")
				var field: Rect2 = shell.call("_playfield_bounds")
				_expect(field.size.y > 0.0 and viewport.encloses(field),
					"Measured HUD bounds must leave usable gameplay at %s." % dimensions)
				if dimensions == Vector2i(1280, 720) and scale_value == 1.0:
					_expect(field.size.y >= viewport.size.y * 0.76,
						"The shared shell must reclaim the old title and instructions bands.")
		shell.free()
		await process_frame

	session.call("configure_single_player")
	root.size = Vector2i(320, 240)
	settings.call("set_value", "ui/scale", 1.5)
	var shell := (load("res://scenes/game/game_shell.tscn") as PackedScene).instantiate()
	shell.process_mode = Node.PROCESS_MODE_DISABLED
	root.add_child(shell)
	await _settle_layout()
	shell.call("_end_round")
	await _settle_layout()
	var exit_button := shell.get_node("%ExitToMainMenuButton") as Control
	exit_button.grab_focus()
	await _settle_layout()
	_expect(root.get_visible_rect().grow(1).encloses(exit_button.get_global_rect()),
		"Scrolling results must keep the focused last action visible on short screens.")
	shell.call("_on_see_score_pressed")
	await _settle_layout()
	var save_button := shell.get_node("%SaveImageButton") as Control
	save_button.grab_focus()
	await _settle_layout()
	_expect(root.get_visible_rect().grow(1).encloses(save_button.get_global_rect()),
		"Scrolling statistics must keep Save reachable at enlarged UI scale.")
	var custom_scroll := ScrollContainer.new()
	custom_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	var overlay := shell.get_node("%RoundOver") as Control
	overlay.add_child(custom_scroll)
	var column := VBoxContainer.new()
	column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	custom_scroll.add_child(column)
	for name in ["RoundPanel", "ScorePanel"]:
		shell.get_node("%" + name).reparent(column)
	(shell.get_node("HUD/RoundOver/Center") as Control).hide()
	var custom_rect := Rect2(Vector2(20, 20), root.get_visible_rect().size - Vector2(40, 40))
	custom_scroll.position = custom_rect.position
	custom_scroll.size = custom_rect.size
	await _settle_layout()
	_expect(custom_scroll.get_global_rect().is_equal_approx(custom_rect),
		"Shared scroll sorting must not resize or displace a game's own results container.")
	shell.call("open_pause_menu")
	await _settle_layout()
	var menu := shell.get("_pause_menu") as Node
	var last := menu.get_node("Center/Panel/Layout/ExitToMainMenuButton") as Control
	last.grab_focus()
	await _settle_layout()
	_expect(root.get_visible_rect().grow(1).encloses(last.get_global_rect()),
		"Pause actions must scroll rather than shrink their touch targets.")
	(shell.get_node("%Hint") as Label).text = "Updated controls while paused"
	(menu.get_node("%GuideButton") as Button).pressed.emit()
	await _settle_layout()
	var guide := menu.call("_active_overlay") as Control
	_expect(guide != null, "The compact pause menu must still open its Guide.")
	if guide != null:
		_expect(
			(guide.get_node("%Rules") as Label).text.contains("Updated controls while paused"),
			"Opening the Guide must read current controls, not the pause menu's initial snapshot."
		)
		guide.call("go_back")
	await _settle_layout()
	menu.call("resume")
	shell.free()
	root.size = old_size
	settings.call("set_value", "ui/scale", old_scale)
	manifest.max_local_players = old_capacity
	manifest.supports_multiplayer = old_multiplayer
	await _settle_layout()


func _settle_layout() -> void:
	for frame in 8:
		await process_frame
