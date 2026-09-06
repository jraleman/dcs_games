extends SceneTree

## Covers the tutorial video card on the instructions screen: asset wiring, the
## play/pause/restart controls and the responsive two-column body.

const INSTRUCTIONS_SCENE := "res://scenes/menus/instructions.tscn"

var _failures := PackedStringArray()


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var session := get_root().get_node_or_null("GameSession")
	var settings := get_root().get_node_or_null("Settings")
	if session == null or settings == null:
		_failures.append("GameSession and Settings autoloads are required.")
		await _finish()
		return

	var original_reduced_motion: bool = settings.call(
		"get_value", "accessibility/reduced_motion"
	)
	settings.set("_values", _with_reduced_motion(settings, false))

	await _test_clip_per_game(session)
	await _test_playback_controls(session)
	await _test_responsive_body(session)
	await _test_player_avatars(session)
	await _test_reduced_motion_starts_paused(session, settings)
	await _test_clip_loops(session, settings)

	settings.set("_values", _with_reduced_motion(settings, original_reduced_motion))
	await _finish()


## Every registered game must present its own headline and rules summary, plus a
## walkthrough clip when it ships one. A game without footage is a supported
## state — [method Instructions._setup_video] hides the card and falls back to
## the single-column explanation — so the screen is held to that instead.
func _test_clip_per_game(session: Node) -> void:
	var manifests := GameCatalog.all()
	_expect(
		manifests.size() >= 2,
		"The catalog needs at least two games to prove the screen is per-game."
	)
	var clips := 0
	var headlines := PackedStringArray()
	var rules := PackedStringArray()
	for manifest: GameManifest in manifests:
		GameCatalog.select(manifest.id)
		session.call("configure_single_player")
		var screen := await _open_screen()
		if screen == null:
			return
		var video := screen.get_node("%Video") as VideoStreamPlayer
		if manifest.tutorial_video_path.is_empty():
			_expect(
				not (screen.get_node("%VideoCard") as Control).visible,
				"%s ships no clip, so the card must give way to the text." % manifest.id
			)
		else:
			clips += 1
			_expect(
				video.stream != null
				and video.stream.resource_path == manifest.tutorial_video_path,
				"%s must load its own tutorial clip." % manifest.id
			)
			_expect(
				(screen.get_node("%PosterImage") as TextureRect).texture != null,
				"%s must load a poster frame for the idle state." % manifest.id
			)
			_expect(
				(screen.get_node("%VideoTitle") as Label).text.contains(
					manifest.title.to_upper()
				),
				"%s must name its game above the clip." % manifest.id
			)
		headlines.append((screen.get_node("%Headline") as Label).text)
		rules.append((screen.get_node("%Rules") as Label).text)
		await _close_screen(screen)

	_expect(
		clips >= 2,
		"At least two games must ship clips, or this screen proves nothing."
	)
	_expect(
		_all_unique(headlines),
		"Each game needs its own headline, not another game's copy."
	)
	_expect(
		_all_unique(rules),
		"Each game needs its own rules summary."
	)


func _all_unique(values: PackedStringArray) -> bool:
	var seen := {}
	for value: String in values:
		if seen.has(value):
			return false
		seen[value] = true
	return not seen.is_empty()


func _test_playback_controls(session: Node) -> void:
	GameCatalog.select("triangle_rush")
	session.call("configure_single_player")
	var screen := await _open_screen()
	if screen == null:
		return
	var video := screen.get_node("%Video") as VideoStreamPlayer
	var play_button := screen.get_node("%PlayButton") as Button
	var poster := screen.get_node("%Poster") as CenterContainer

	_expect(
		video.is_playing() and not video.paused,
		"The clip must start playing when reduced motion is off."
	)
	_expect(not poster.visible, "The poster must be hidden during playback.")

	play_button.emit_signal("pressed")
	_expect(video.paused, "The play button must pause a playing clip.")
	_expect(poster.visible, "Pausing must bring the poster prompt back.")
	_expect(play_button.text == "Play", "A paused clip must offer to play again.")

	play_button.emit_signal("pressed")
	_expect(not video.paused, "The play button must resume a paused clip.")
	_expect(play_button.text == "Pause", "A playing clip must offer to pause.")

	await create_timer(0.4).timeout
	(screen.get_node("%RestartButton") as Button).emit_signal("pressed")
	_expect(
		video.is_playing() and video.stream_position < 0.2,
		"Restart must rewind the clip and keep playing."
	)

	screen.call("_on_video_finished")
	_expect(
		(screen.get_node("%PosterLabel") as Label).text == "Watch again",
		"A finished clip must invite the viewer to replay it."
	)
	await _close_screen(screen)


func _test_responsive_body(session: Node) -> void:
	GameCatalog.select("triangle_rush")
	session.call("configure_multiplayer", 0)
	var screen := await _open_screen()
	if screen == null:
		return
	var body := screen.get_node("%Body") as GridContainer
	var controls := screen.get_node("%ControlGrid") as GridContainer

	screen.call("_on_layout_changed", Vector2(1920.0, 1080.0))
	_expect(body.columns == 2, "Landscape must place the clip beside the details.")
	_expect(controls.columns == 2, "Landscape multiplayer must show both players.")

	screen.call("_on_layout_changed", Vector2(1080.0, 1920.0))
	_expect(body.columns == 1, "Portrait must stack the clip above the details.")
	_expect(controls.columns == 1, "Portrait must stack the control cards.")
	await _close_screen(screen)


## Each control card carries a portrait placeholder whose tag names the player
## holding that slot, so the roster reads without relying on colour.
func _test_player_avatars(session: Node) -> void:
	GameCatalog.select("triangle_rush")
	for setup: Array in [
		["configure_multiplayer", 0, "P2", true],
		["configure_multiplayer", 1, "CPU", true],
		["configure_single_player", -1, "", false],
	]:
		if int(setup[1]) < 0:
			session.call(setup[0])
		else:
			session.call(setup[0], int(setup[1]))
		var screen := await _open_screen()
		if screen == null:
			return
		var player_one := screen.get_node_or_null("%PlayerOneAvatar") as Control
		var opponent := screen.get_node_or_null("%OpponentAvatar") as Control
		_expect(
			player_one != null
			and player_one.is_visible_in_tree()
			and str(player_one.get("tag")) == "P1"
			and not player_one.accessibility_description.is_empty(),
			"Player 1's card must show a described portrait placeholder."
		)
		_expect(
			opponent != null
			and opponent.get_parent().get_parent().get_parent().visible
			== bool(setup[3]),
			"The opponent portrait must follow its card's visibility."
		)
		if bool(setup[3]):
			_expect(
				str(opponent.get("tag")) == str(setup[2]),
				"The opponent portrait must be tagged %s." % setup[2]
			)
		await _close_screen(screen)


func _test_reduced_motion_starts_paused(session: Node, settings: Node) -> void:
	settings.set("_values", _with_reduced_motion(settings, true))
	GameCatalog.select("desk_can_saw")
	session.call("configure_single_player")
	var screen := await _open_screen()
	if screen == null:
		settings.set("_values", _with_reduced_motion(settings, false))
		return
	var video := screen.get_node("%Video") as VideoStreamPlayer
	_expect(
		not video.is_playing(),
		"Reduced motion must leave the clip parked until the viewer starts it."
	)
	_expect(
		(screen.get_node("%Poster") as CenterContainer).visible,
		"Reduced motion must show the poster prompt."
	)
	_expect(
		not video.loop,
		"Reduced motion must not loop the clip: an endlessly restarting video is "
		+ "exactly the unrequested repeated motion that setting suppresses."
	)
	await _close_screen(screen)
	settings.set("_values", _with_reduced_motion(settings, false))


## The walkthrough repeats so a viewer can keep watching without hunting for the
## replay button, which is only reachable once the clip has stopped.
func _test_clip_loops(session: Node, settings: Node) -> void:
	settings.set("_values", _with_reduced_motion(settings, false))
	for manifest in GameCatalog.all():
		if manifest.tutorial_video_path.is_empty():
			continue
		GameCatalog.select(manifest.id)
		session.call("configure_single_player")
		var screen := await _open_screen()
		if screen == null:
			return
		var video := screen.get_node("%Video") as VideoStreamPlayer
		_expect(
			video.loop,
			"%s must loop its walkthrough clip when reduced motion is off."
			% manifest.id
		)
		_expect(
			video.is_playing(),
			"%s must autoplay its walkthrough clip when reduced motion is off."
			% manifest.id
		)
		await _close_screen(screen)


## Writes straight into the settings dictionary so the test never persists a
## value to the developer's user://settings.cfg.
func _with_reduced_motion(settings: Node, enabled: bool) -> Dictionary:
	var values: Dictionary = settings.get("_values").duplicate()
	values["accessibility/reduced_motion"] = enabled
	return values


func _open_screen() -> Node:
	var packed := load(INSTRUCTIONS_SCENE) as PackedScene
	if packed == null:
		_failures.append("Could not load %s." % INSTRUCTIONS_SCENE)
		return null
	var screen := packed.instantiate()
	get_root().add_child(screen)
	await process_frame
	await process_frame
	return screen


func _close_screen(screen: Node) -> void:
	screen.queue_free()
	await process_frame


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)


func _finish() -> void:
	await create_timer(0.3).timeout
	if _failures.is_empty():
		print("Instructions video tests passed.")
		quit(0)
		return
	for failure in _failures:
		push_error(failure)
	quit(1)
