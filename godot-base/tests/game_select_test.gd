extends SceneTree

## The game picker: the one screen behind the title screen's Play button in any
## build with more than one game to offer.
##
## Everything here is driven from [method GameCatalog.available], so a game is
## covered the moment it declares a manifest — there is no per-game copy of this
## file to write.
##
## Headless `--script` runs compile before autoloads exist, so screens are loaded
## at runtime and poked with `call`/`get` rather than named as types.

const GAME_SELECT := "res://scenes/menus/game_select.tscn"
const MAIN_MENU := "res://scenes/menus/main_menu.tscn"
const MODE_SELECT := "res://scenes/menus/mode_select.tscn"
const INSTRUCTIONS := "res://scenes/menus/instructions.tscn"

var _failures := PackedStringArray()
var _settings: Node


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	_settings = get_root().get_node_or_null("Settings")
	if _settings == null:
		_failures.append("The Settings autoload is required.")
		await _finish()
		return
	if not GameCatalog.offers_a_choice():
		_failures.append(
			"Run this test against the collection (`-- --game=all`): a build with "
			+ "one game never opens the picker."
		)
		await _finish()
		return

	var original_reduced_motion: bool = _settings.call(
		"get_value", "accessibility/reduced_motion"
	)
	_set_reduced_motion(false)

	await _test_main_menu_has_one_game_button()
	await _test_card_per_available_game()
	await _test_previews_play()
	await _test_reduced_motion_parks_previews()
	await _test_responsive_grid()
	await _test_back_targets()
	await _test_choosing_selects_the_game()

	_set_reduced_motion(original_reduced_motion)
	await _finish()


## The point of the screen: the title screen stops listing games and offers one
## way in, whatever the catalog holds.
func _test_main_menu_has_one_game_button() -> void:
	var menu := await _open(MAIN_MENU)
	if menu == null:
		return
	var titles := {}
	for manifest in GameCatalog.all():
		titles[manifest.title] = true
	for node in menu.find_children("*", "Button", true, false):
		var button := node as Button
		_expect(
			not titles.has(button.text),
			"The title screen must not carry a per-game button ('%s')." % button.text
		)
	var play := menu.get_node("%PlayButton") as Button
	_expect(not play.disabled, "Play must be usable while games are available.")
	_expect(
		play.tooltip_text.contains(str(GameCatalog.available().size())),
		"Play must say how many games the picker will offer."
	)
	await _close(menu)


## One card per available game, each carrying that game's own name, tagline and
## walkthrough media. Locked-and-hidden games stay out, exactly as they did when
## the title screen listed them.
func _test_card_per_available_game() -> void:
	var screen := await _open(GAME_SELECT)
	if screen == null:
		return
	var games := GameCatalog.available()
	var cards := _cards(screen)
	_expect(
		cards.size() == games.size(),
		"The picker must show %d cards, not %d." % [games.size(), cards.size()]
	)
	_expect(
		cards.size() > 1, "This test needs more than one available game to mean anything."
	)

	for index in mini(cards.size(), games.size()):
		var manifest: GameManifest = games[index]
		var card: Control = cards[index]
		_expect(
			card.call("game_id") == manifest.id,
			"Card %d must be '%s', in catalog order." % [index, manifest.id]
		)
		_expect(
			(card.get_node("%Title") as Label).text == manifest.title
			and (card.get_node("%Tagline") as Label).text == manifest.tagline,
			"The '%s' card must carry that game's own name and tagline." % manifest.id
		)
		var button := card.call("focus_target") as Button
		_expect(
			button != null and not button.disabled
			and button.accessibility_description.contains(manifest.title),
			(
				"The '%s' card's button must be reachable and describe itself by "
				% manifest.id
			)
			+ "name, since three buttons reading 'Play' are useless read aloud."
		)

		var video := card.get_node("%Video") as VideoStreamPlayer
		var poster := card.get_node("%Poster") as TextureRect
		if manifest.tutorial_video_path.is_empty():
			_expect(
				video.stream == null,
				"'%s' declares no clip, so its card must not invent one." % manifest.id
			)
		else:
			_expect(
				video.stream != null
				and video.stream.resource_path == manifest.tutorial_video_path,
				"The '%s' card must load that game's own clip." % manifest.id
			)
			_expect(
				video.loop and video.volume_db < -40.0,
				"A thumbnail preview must loop and stay silent."
			)
		if not manifest.tutorial_poster_path.is_empty():
			_expect(
				poster.texture != null and poster.visible,
				"The '%s' card must show its poster frame behind the clip."
				% manifest.id
			)
		_expect(
			video.stream != null or poster.texture != null
			or (card.get_node("%Placeholder") as Label).visible,
			(
				"A '%s' card with no media must keep the thumbnail's shape and say "
				% manifest.id
			)
			+ "the preview is missing, not collapse."
		)
	await _close(screen)


## The thumbnails are the screen. Every card with a clip runs it, so long as the
## catalog stays under the screen's simultaneous-decode cap.
func _test_previews_play() -> void:
	var screen := await _open(GAME_SELECT)
	if screen == null:
		return
	var cap := int(
		screen.get_script().get_script_constant_map().get("MAX_LIVE_PREVIEWS", 0)
	)
	_expect(cap > 0, "The screen must declare how many previews may run at once.")
	var cards := _cards(screen)
	if cards.size() > cap:
		_expect(
			_previewing(cards) <= 1,
			"Past %d games only the focused card may decode a clip." % cap
		)
		await _close(screen)
		return

	var expected := 0
	for manifest in GameCatalog.available():
		if not manifest.tutorial_video_path.is_empty():
			expected += 1
	_expect(
		_previewing(cards) == expected,
		"All %d previews must run as thumbnails, not %d." % [expected, _previewing(cards)]
	)
	for card in cards:
		var badge := card.get_node("%Badge") as Label
		if not badge.visible:
			continue
		_expect(
			badge.text == ("PREVIEW" if card.call("is_previewing") else "PREVIEW PAUSED"),
			"The badge must say whether the thumbnail is actually moving."
		)
	await _close(screen)


## A looping thumbnail is ambient, decorative motion, which is exactly what the
## accessibility setting exists to stop.
func _test_reduced_motion_parks_previews() -> void:
	_set_reduced_motion(true)
	var screen := await _open(GAME_SELECT)
	if screen == null:
		_set_reduced_motion(false)
		return
	var cards := _cards(screen)
	_expect(
		_previewing(cards) == 0,
		"Reduced motion must park every preview on its poster frame."
	)
	for card in cards:
		_expect(
			not (card.get_node("%Video") as VideoStreamPlayer).visible,
			"A parked preview must show the still, not a frozen video surface."
		)

	# The setting has to reach cards that are already on screen, not just the
	# next time the screen is built.
	_set_reduced_motion(false)
	await process_frame
	_expect(
		_previewing(cards) > 0,
		"Turning reduced motion off must start the previews without a reload."
	)
	await _close(screen)


## Back must undo the step the player actually took. With a picker in the flow
## every screen behind it returns there, not to the title screen.
func _test_back_targets() -> void:
	var picker := await _open(GAME_SELECT)
	if picker == null:
		return
	_expect(
		str(picker.get("back_scene")) == MAIN_MENU,
		"The picker itself must return to the title screen."
	)
	await _close(picker)

	var session := get_root().get_node_or_null("GameSession")
	if session == null:
		_failures.append("The GameSession autoload is required.")
		return

	GameCatalog.select(GameCatalog.available()[0].id)
	session.call("configure_single_player")
	var mode_select := await _open(MODE_SELECT)
	if mode_select != null:
		_expect(
			str(mode_select.get("back_scene")) == GAME_SELECT,
			"Mode select must return to the picker the player came through."
		)
		await _close(mode_select)

	# A solo-only game never sees mode select, so the picker is the screen
	# directly behind its instructions.
	for manifest in GameCatalog.available():
		if manifest.supports_multiplayer:
			continue
		GameCatalog.select(manifest.id)
		session.call("configure_single_player")
		var instructions := await _open(INSTRUCTIONS)
		if instructions == null:
			continue
		_expect(
			str(instructions.get("back_scene")) == GAME_SELECT,
			(
				"'%s' skips mode select, so its instructions must return to the "
				% manifest.id
			)
			+ "picker rather than trapping the player in a loop."
		)
		await _close(instructions)


## Committing to a game selects it, latches the screen against a second click
## and stops every clip. Run last: it hands the round off to [Router], which
## replaces the running scene.
func _test_choosing_selects_the_game() -> void:
	var screen := await _open(GAME_SELECT)
	if screen == null:
		return
	var cards := _cards(screen)
	if cards.size() < 2:
		await _close(screen)
		return
	var target: Control = cards[cards.size() - 1]
	var wanted := str(target.call("game_id"))
	GameCatalog.select(str(cards[0].call("game_id")))

	(target.call("focus_target") as Button).emit_signal("pressed")
	_expect(
		GameCatalog.current_id() == wanted,
		"Picking a card must make that game the selected one."
	)
	_expect(
		bool(screen.get("_launching")),
		"Picking a card must latch the screen so a second click cannot race it."
	)
	for card in cards:
		_expect(
			not bool(card.call("is_previewing")),
			"Leaving the picker must stop every clip rather than decode into a fade."
		)
	await _close(screen)
	# Let the router's fade and scene swap finish before the tree is torn down.
	# The duration is spelled out rather than read from `Router.FADE_TIME`: a
	# headless `--script` run compiles this file's dependencies before autoloads
	# exist, and naming the autoload's script here would fail to compile it.
	await create_timer(0.6).timeout


func _test_responsive_grid() -> void:
	var screen := await _open(GAME_SELECT)
	if screen == null:
		return
	var grid := screen.get_node("%Grid") as GridContainer
	var cards := _cards(screen)

	screen.call("_on_layout_changed", Vector2(2560.0, 1080.0))
	var wide := grid.columns
	_expect(
		wide > 1 and wide <= mini(3, cards.size()),
		"A wide screen must lay the cards out in columns, capped at %d." % cards.size()
	)
	_expect(
		grid.custom_minimum_size.x <= 2560.0,
		"The grid must never ask for more width than the screen has."
	)

	screen.call("_on_layout_changed", Vector2(720.0, 1440.0))
	_expect(
		grid.columns == 1,
		"A portrait phone must stack the cards instead of shrinking the previews."
	)
	_expect(
		grid.custom_minimum_size.x >= GameCard.MIN_WIDTH,
		"A stacked card must still be at least as wide as a legible preview."
	)
	await _close(screen)


# --- Helpers ----------------------------------------------------------------


func _cards(screen: Node) -> Array:
	return Array(screen.get("_cards"))


func _previewing(cards: Array) -> int:
	var count := 0
	for card in cards:
		if bool(card.call("is_previewing")):
			count += 1
	return count


## Writes straight into the settings dictionary so the test never persists a
## value to the developer's user://settings.cfg.
func _set_reduced_motion(enabled: bool) -> void:
	var values: Dictionary = (_settings.get("_values") as Dictionary).duplicate()
	values["accessibility/reduced_motion"] = enabled
	_settings.set("_values", values)
	_settings.emit_signal("changed", "accessibility/reduced_motion", enabled)


func _open(path: String) -> Node:
	var packed := load(path) as PackedScene
	if packed == null:
		_failures.append("Could not load %s." % path)
		return null
	var screen := packed.instantiate()
	get_root().add_child(screen)
	await process_frame
	await process_frame
	return screen


func _close(screen: Node) -> void:
	get_root().remove_child(screen)
	screen.queue_free()
	await process_frame


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)


func _finish() -> void:
	await create_timer(0.3).timeout
	if _failures.is_empty():
		print("Game select tests passed.")
		quit(0)
		return
	for failure in _failures:
		push_error(failure)
	quit(1)
