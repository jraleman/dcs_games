extends SceneTree

## Covers media, direct playback, the complete on-demand guide and physically
## sized layouts. Optional graphics captures use --instructions-capture-dir.

const INSTRUCTIONS_SCENE := "res://scenes/menus/instructions.tscn"

var _failures := PackedStringArray()
var _capture_dir := ""


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--instructions-capture-dir="):
			_capture_dir = argument.trim_prefix("--instructions-capture-dir=")
	if not _capture_dir.is_empty():
		if DisplayServer.get_name() == "headless":
			_failures.append("Instructions captures need a real graphics window.")
			await _finish()
			return
		var error := DirAccess.make_dir_recursive_absolute(_capture_dir)
		if error != OK:
			_failures.append("Could not create capture directory: " + error_string(error))
			await _finish()
			return
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
	await _test_missing_clip_fallback(session)
	await _test_local_clips(session)
	await _test_playback_controls(session)
	await _test_guide(session, settings)
	await _test_start_preference(session, settings)
	await _test_solo_setup_context(session, settings)
	await _test_responsive_body(session, settings)
	await _test_roster_layouts(session, settings)
	await _test_player_avatars(session)
	await _test_reduced_motion_starts_paused(session, settings)
	await _test_clip_loops(session, settings)

	settings.set("_values", _with_reduced_motion(settings, original_reduced_motion))
	await _finish()


## Every shipped game has a real walkthrough. The no-media authoring fallback
## is exercised separately rather than leaving a shipped game without footage.
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
		var show_again := screen.get_node("%ShowAgainToggle") as CheckButton
		_expect(show_again.theme_type_variation == &"MenuToggle",
			"The instructions preference must use the same toggle style as Settings.")
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
				(screen.get_node("%ModeLabel") as Label).text.contains(
					manifest.title.to_upper()
				) and (screen.get_node("%VideoTitle") as Label).text == "Walkthrough",
				"%s must identify its game once, without repeating it on the clip." % manifest.id
			)
			_expect(not (screen.get_node("%Guide") as Control).visible
				and not (screen.get_node("%Rules") as Control).is_visible_in_tree()
				and not (screen.get_node("%PlayerOneControls") as Control).is_visible_in_tree(),
				"%s must open on the video, not a wall of instructions." % manifest.id)
		headlines.append((screen.get_node("%Headline") as Label).text)
		rules.append((screen.get_node("%Rules") as Label).text)
		await _close_screen(screen)

	_expect(
		clips == manifests.size(),
		"Every shipped game must provide a walkthrough recording."
	)
	_expect(
		_all_unique(headlines),
		"Each game needs its own headline, not another game's copy."
	)
	_expect(
		_all_unique(rules),
		"Each game needs its own rules summary."
	)


func _test_missing_clip_fallback(session: Node) -> void:
	var manifest := GameCatalog.all()[0]
	GameCatalog.select(manifest.id)
	session.call("configure_single_player")
	var original := manifest.tutorial_video_path
	for missing: String in ["", "res://missing_instructions_clip.ogv"]:
		manifest.tutorial_video_path = missing
		var screen := await _open_screen()
		manifest.tutorial_video_path = original
		if screen == null:
			return
		_expect(not (screen.get_node("%VideoCard") as Control).visible
			and (screen.get_node("%Guide") as Control).is_visible_in_tree()
			and (screen.get_node("%Rules") as Control).is_visible_in_tree()
			and not (screen.get_node("%GuideButton") as Control).visible,
			"A missing clip must open the complete guide, without a dead Watch button.")
		await _close_screen(screen)


func _all_unique(values: PackedStringArray) -> bool:
	var seen := {}
	for value: String in values:
		if seen.has(value):
			return false
		seen[value] = true
	return not seen.is_empty()


func _test_local_clips(session: Node) -> void:
	for manifest in GameCatalog.all():
		if manifest.local_tutorial_video_path.is_empty():
			continue
		GameCatalog.select(manifest.id)
		session.call("configure_multiplayer", 0)
		var screen := await _open_screen()
		if screen == null:
			return
		var video := screen.get_node("%Video") as VideoStreamPlayer
		var poster := screen.get_node("%PosterImage") as TextureRect
		_expect(video.stream != null
			and video.stream.resource_path == manifest.local_tutorial_video_path,
			"%s local humans must get their local walkthrough." % manifest.id)
		var expected_poster := (
			manifest.local_tutorial_poster_path
			if not manifest.local_tutorial_poster_path.is_empty()
			else manifest.tutorial_poster_path
		)
		_expect(poster.texture != null and poster.texture.resource_path == expected_poster,
			"%s local instructions must use a matching idle poster." % manifest.id)
		await _close_screen(screen)
		var cpu_offered := manifest.supports_cpu_opponent
		manifest.supports_cpu_opponent = true
		session.call("configure_multiplayer", 1)
		screen = await _open_screen()
		manifest.supports_cpu_opponent = cpu_offered
		if screen == null:
			return
		video = screen.get_node("%Video") as VideoStreamPlayer
		_expect(video.stream != null and video.stream.resource_path == manifest.tutorial_video_path,
			"An automatic second seat must not use a human-only local tutorial.")
		await _close_screen(screen)


func _test_playback_controls(session: Node) -> void:
	GameCatalog.select("triangle_rush")
	session.call("configure_single_player")
	var screen := await _open_screen()
	if screen == null:
		return
	var video := screen.get_node("%Video") as VideoStreamPlayer
	var poster := screen.get_node("%Poster") as CenterContainer
	_expect(screen.get_node_or_null("%PlayButton") == null,
		"Playback must not reserve space for a separate Play/Pause button.")
	_expect(video.focus_mode == Control.FOCUS_ALL and not video.tooltip_text.is_empty(),
		"The video itself must be focusable and explain its direct playback input.")

	_expect(
		video.is_playing() and not video.paused,
		"The clip must start playing when reduced motion is off."
	)
	_expect(not poster.visible, "The poster must be hidden during playback.")

	_click_video(video)
	_expect(video.paused, "Clicking the video must pause a playing clip.")
	_expect(poster.visible, "Pausing must bring the poster prompt back.")
	_expect(video.accessibility_description.contains("resume"),
		"A paused clip must expose how to resume it without a visual button.")
	_expect((screen.get_node("%VideoFocus") as Control).visible,
		"The directly focused video needs a visible focus outline.")

	var confirm := InputEventKey.new()
	confirm.keycode = KEY_ENTER
	confirm.pressed = true
	root.push_input(confirm, true)
	confirm.pressed = false
	root.push_input(confirm, true)
	_expect(not video.paused, "Keyboard confirm must resume the focused clip.")
	var touch := InputEventScreenTouch.new()
	touch.position = video.get_global_rect().get_center()
	touch.pressed = true
	root.push_input(touch, true)
	touch.pressed = false
	root.push_input(touch, true)
	_expect(video.paused, "Touch must also control playback.")
	_click_video(video, InputEvent.DEVICE_ID_EMULATION)
	_expect(video.paused, "An emulated mouse click must not undo the same touch's pause.")
	var controller := InputEventJoypadButton.new()
	controller.button_index = JOY_BUTTON_A
	controller.pressed = true
	root.push_input(controller, true)
	controller.pressed = false
	root.push_input(controller, true)
	_expect(not video.paused, "Controller confirm must resume the focused clip.")

	await create_timer(0.4).timeout
	(screen.get_node("%RestartButton") as Button).emit_signal("pressed")
	_expect(
		video.is_playing() and video.stream_position < 0.2,
		"Restart must rewind the clip and keep playing."
	)

	video.stop()
	screen.call("_on_video_finished")
	_expect(
		(screen.get_node("%PosterLabel") as Label).text == "Watch again",
		"A finished clip must invite the viewer to replay it."
	)
	await _close_screen(screen)


func _click_video(video: Control, device := 0) -> void:
	for pressed: bool in [true, false]:
		var event := InputEventMouseButton.new()
		event.button_index = MOUSE_BUTTON_LEFT
		event.position = video.get_global_rect().get_center()
		event.global_position = event.position
		event.device = device
		event.pressed = pressed
		root.push_input(event, true)


func _test_guide(session: Node, settings: Node) -> void:
	GameCatalog.select("creep_code")
	session.call("configure_single_player")
	var screen := await _open_screen()
	if screen == null:
		return
	var button := screen.get_node("%GuideButton") as Button
	var guide := screen.get_node("%Guide") as ScrollContainer
	var video := screen.get_node("%Video") as VideoStreamPlayer
	var before := video.stream_position
	button.grab_focus()
	_confirm()
	await _settle_layout()
	_expect(guide.visible and video.paused and not video.is_visible_in_tree()
		and button.text == "Watch" and button.button_pressed,
		"Opening Guide must replace the video and pause hidden decoding.")
	_expect((screen.get_node("%Rules") as Label).is_visible_in_tree()
		and (screen.get_node("%PlayerOneControls") as Label).is_visible_in_tree()
		and guide.horizontal_scroll_mode == ScrollContainer.SCROLL_MODE_DISABLED,
		"The full rules and current controls must be readable in the scrollable guide.")
	_expect((screen.get_node("%BackButton") as Control).find_next_valid_focus() == guide,
		"Keyboard focus must enter the guide, not the hidden video.")
	_confirm()
	_expect(not guide.visible and not video.paused and video.is_visible_in_tree()
		and video.stream_position >= before,
		"Returning from Guide must continue, not restart, an automatically playing clip.")
	_click_video(video)
	screen.call("_on_guide_toggled", true)
	screen.call("_on_guide_toggled", false)
	_expect(video.paused, "Reading Guide must not undo an explicit pause.")
	_click_video(video)
	screen.call("_on_guide_toggled", true)
	settings.set("_values", _with_reduced_motion(settings, true))
	settings.emit_signal("changed", "accessibility/reduced_motion", true)
	screen.call("_on_guide_toggled", false)
	_expect(video.paused and not video.loop,
		"Enabling Reduced motion while reading must cancel the pending automatic resume.")
	settings.set("_values", _with_reduced_motion(settings, false))
	settings.emit_signal("changed", "accessibility/reduced_motion", false)
	_expect(video.paused, "Changing motion preference must not start a paused clip.")
	await _close_screen(screen)


func _test_responsive_body(session: Node, settings: Node) -> void:
	var original_size := root.size
	var original_minimum := root.min_size
	var original_theme := root.theme
	var original_scale: float = settings.call("get_value", "ui/scale")
	root.min_size = Vector2i.ZERO
	var manifests := GameCatalog.all()
	for manifest in manifests:
		GameCatalog.restrict_to(manifest.id)
		root.theme = GameCatalog.theme().restyle(ThemeDB.get_project_theme())
		session.call("configure_single_player")
		var screen := await _open_screen()
		if screen == null:
			continue
		if DisplayServer.get_name() != "headless":
			await create_timer(1.1).timeout
		for dimensions: Vector2i in [
			Vector2i(1280, 720), Vector2i(390, 844), Vector2i(320, 568),
			Vector2i(844, 390), Vector2i(2560, 1080),
		]:
			_set_ui_scale(settings, 1.0)
			root.size = dimensions
			await _settle_layout()
			_check_layout(screen, dimensions, 1.0)
			await _capture("%s-%dx%d-watch" % [manifest.id, dimensions.x, dimensions.y])
			screen.call("_on_guide_toggled", true)
			await _settle_layout()
			_check_layout(screen, dimensions, 1.0)
			await _capture("%s-%dx%d-guide" % [manifest.id, dimensions.x, dimensions.y])
			var guide := screen.get_node("%Guide") as ScrollContainer
			guide.scroll_vertical = 100000
			await _settle_layout()
			var rules := screen.get_node("%Rules") as Label
			_expect(_native_rect(rules).end.y <= _native_rect(guide).end.y + 2,
				"%s: even the final rules must scroll fully into view at %s."
				% [manifest.id, dimensions])
			guide.scroll_vertical = 0
			screen.call("_on_guide_toggled", false)
		root.size = Vector2i(390, 844)
		_set_ui_scale(settings, 1.5)
		await _settle_layout()
		_check_layout(screen, root.size, 1.5)
		screen.call("_on_guide_toggled", true)
		await _settle_layout()
		_check_layout(screen, root.size, 1.5)
		await _capture(manifest.id + "-large-ui-guide")
		await _close_screen(screen)
	_set_ui_scale(settings, original_scale)
	root.min_size = original_minimum
	root.size = original_size
	root.theme = original_theme
	GameCatalog.clear_restriction()
	await _settle_layout()


func _test_start_preference(session: Node, settings: Node) -> void:
	GameCatalog.select("triangle_rush")
	session.call("configure_single_player")
	var original: bool = settings.call("get_value", "game/show_instructions")
	var timer := settings.get("_save_timer") as Timer
	var was_stopped := timer.is_stopped()
	var remaining := timer.time_left
	var process_mode := timer.process_mode
	timer.process_mode = Node.PROCESS_MODE_DISABLED
	var screen := await _open_screen()
	if screen != null:
		var toggle := screen.get_node("%ShowAgainToggle") as CheckButton
		_expect(toggle.text == "Show on start"
			and toggle.accessibility_name == "Show instructions when starting a mode",
			"The short preference caption must keep its complete accessible meaning.")
		toggle.grab_focus()
		_confirm()
		_expect(bool(settings.call("get_value", "game/show_instructions")) != original,
			"The redesigned toggle must still change the existing saved preference key.")
		var values: Dictionary = settings.get("_values").duplicate()
		values["game/show_instructions"] = original
		settings.set("_values", values)
		settings.emit_signal("changed", "game/show_instructions", original)
		_expect(toggle.button_pressed == original, "Live settings must also update the preference.")
		await _close_screen(screen)
	timer.stop()
	timer.process_mode = process_mode
	if not was_stopped:
		timer.start(remaining)


func _test_solo_setup_context(session: Node, settings: Node) -> void:
	for manifest in GameCatalog.all():
		if manifest.solo_setup_choices.is_empty():
			continue
		GameCatalog.select(manifest.id)
		session.call("configure_single_player")
		var saved: Dictionary = settings.get("_values").duplicate()
		var screen := await _open_screen()
		if screen == null:
			continue
		var key := manifest.solo_setup_choices[0]
		var choices: Array = settings.call("option_choices", key)
		for choice: Dictionary in choices:
			var values: Dictionary = settings.get("_values").duplicate()
			values[key] = choice["value"]
			settings.set("_values", values)
			settings.emit_signal("changed", key, choice["value"])
			var label := screen.get_node("%SetupLabel") as Label
			_expect(label.is_visible_in_tree()
				and label.text.contains(str(choice.get("summary_title", choice["title"]))),
				"%s must show the selected solo side even while Guide is closed." % manifest.id)
		settings.set("_values", saved)
		await _close_screen(screen)


func _test_roster_layouts(session: Node, settings: Node) -> void:
	var original_size := root.size
	var original_theme := root.theme
	var original_scale: float = settings.call("get_value", "ui/scale")
	_set_ui_scale(settings, 1.0)
	for manifest in GameCatalog.all():
		if not manifest.supports_multiplayer:
			continue
		GameCatalog.restrict_to(manifest.id)
		root.theme = GameCatalog.theme().restyle(ThemeDB.get_project_theme())
		for count in range(2, manifest.max_local_players + 1):
			session.call("configure_multiplayer", 0, int(session.get("cpu_difficulty")), count)
			var screen := await _open_screen()
			if screen == null:
				continue
			screen.call("_on_guide_toggled", true)
			for dimensions: Vector2i in [Vector2i(1280, 720), Vector2i(390, 844)]:
				root.size = dimensions
				await _settle_layout()
				_check_layout(screen, dimensions, 1.0)
				var grid := screen.get_node("%ControlGrid") as GridContainer
				_expect(grid.columns == (count if dimensions.x > dimensions.y else 1),
					"%s: %d seats must have room to read at %s."
					% [manifest.id, count, dimensions])
				var visible := 0
				for card: Control in grid.get_children():
					if card.is_visible_in_tree():
						visible += 1
				_expect(visible == count,
					"%s: the guide must include all %d active seats." % [manifest.id, count])
				if not manifest.characters.is_empty():
					var setup := screen.get_node("%SetupLabel") as Label
					_expect(setup.is_visible_in_tree() and setup.text.contains("P%d:" % count),
						"%s: all %d selected characters must remain outside the guide."
						% [manifest.id, count])
					if manifest.local_multiplayer_turns:
						_expect(setup.text.contains(" -> "),
							"Hot-seat order must be explicit rather than relying on colors.")
				await _capture("%s-%d-players-%dx%d-guide"
					% [manifest.id, count, dimensions.x, dimensions.y])
			if count == 2 and manifest.max_local_players > 2:
				session.call("configure_multiplayer", 0, int(session.get("cpu_difficulty")), 3)
				session.emit_signal("controller_assignments_changed")
				await _settle_layout()
				var extra: Array = screen.get("_extra_control_cards")
				_expect(extra.size() == 1, "A live roster refresh must add the third guide card.")
				if not extra.is_empty():
					var panel := extra[0]["panel"] as Control
					var label := extra[0]["controls"] as Label
					var transform := root.get_final_transform() * panel.get_global_transform_with_canvas()
					var pixels := transform.get_scale().x
					_expect(label.get_theme_font_size("font_size") * pixels >= 15.5
						and absf(panel.get_theme_stylebox("panel").get_content_margin(SIDE_LEFT)
							* pixels - 16.0) < 1.0,
						"A late guide card must scale once, with sharp text and matching padding.")
			await _close_screen(screen)
		GameCatalog.clear_restriction()
	root.theme = original_theme
	root.size = original_size
	_set_ui_scale(settings, original_scale)
	await _settle_layout()


func _check_layout(screen: Node, dimensions: Vector2i, ui_scale: float) -> void:
	var bounds := Rect2(Vector2.ZERO, Vector2(dimensions)).grow(2)
	var guide := screen.get_node("%Guide") as Control
	for name: String in [
		"Header", "Actions", "GuideButton", "BackButton", "StartButton", "ShowAgainToggle",
		"Guide" if guide.visible else "VideoCard",
	]:
		var control := screen.get_node("%" + name) as Control
		if control.is_visible_in_tree():
			_expect(bounds.encloses(_native_rect(control)),
				"%s: %s must fit %s at UI scale %.1f (got %s)."
				% [GameCatalog.current_id(), name, dimensions, ui_scale, _native_rect(control)])
	for name: String in ["GuideButton", "BackButton", "StartButton", "ShowAgainToggle", "RestartButton"]:
		var button := screen.get_node("%" + name) as BaseButton
		if button.is_visible_in_tree():
			_expect(_native_rect(button).size.y >= 44.0 * ui_scale - 1,
				"%s must keep a real 44-pixel touch height at %s." % [name, dimensions])
	var content := _native_rect(guide if guide.visible else screen.get_node("%VideoCard"))
	_expect(content.position.y >= _native_rect(screen.get_node("%Header")).end.y
		and content.end.y <= _native_rect(screen.get_node("%Actions")).position.y + 1,
		"Content must never cover navigation or the always-reachable Start action.")
	if guide.visible:
		var label := screen.get_node("%PlayerOneControls") as Label
		var transform := root.get_final_transform() * label.get_global_transform_with_canvas()
		_expect(label.get_theme_font_size("font_size") * transform.get_scale().y
			>= 15.5 * ui_scale, "Guide text must remain physically legible, including on phones.")
	else:
		var video := _native_rect(screen.get_node("%Video"))
		_expect(absf(video.size.x / video.size.y - 16.0 / 9.0) < 0.01,
			"The full 16:9 recording must fit without cropping or stretching.")
		if dimensions == Vector2i(1280, 720) and is_equal_approx(ui_scale, 1.0):
			_expect(video.size.x >= 760,
				"The walkthrough must be larger than the previous crowded two-column preview.")


func _native_rect(control: Control) -> Rect2:
	return root.get_final_transform() * control.get_global_transform_with_canvas() \
		* Rect2(Vector2.ZERO, control.size)


func _set_ui_scale(settings: Node, value: float) -> void:
	var values: Dictionary = settings.get("_values").duplicate()
	values["ui/scale"] = value
	settings.set("_values", values)
	settings.call("_update_content_scale")
	settings.emit_signal("changed", "ui/scale", value)


func _confirm() -> void:
	for pressed: bool in [true, false]:
		var event := InputEventKey.new()
		event.keycode = KEY_ENTER
		event.pressed = pressed
		root.push_input(event, true)


func _settle_layout() -> void:
	for frame in 6:
		await process_frame


func _capture(name: String) -> void:
	if _capture_dir.is_empty():
		return
	await RenderingServer.frame_post_draw
	var error := root.get_texture().get_image().save_png(
		_capture_dir.path_join(name + ".png")
	)
	_expect(error == OK, "Could not capture " + name + ": " + error_string(error))


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
		screen.call("_on_guide_toggled", true)
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
	_click_video(video)
	_expect(video.is_playing() and not video.paused and not video.loop,
		"Clicking the poster must explicitly start one non-looping reduced-motion viewing.")
	await _close_screen(screen)
	settings.set("_values", _with_reduced_motion(settings, false))


## The walkthrough repeats without requiring another click on the picture.
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
