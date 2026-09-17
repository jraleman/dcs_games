extends SceneTree

## Framework regression checks for the model [b]Gallery[/b].
##
## The gallery is declared data, exactly like achievements, options and the
## store, so this test walks [method GameCatalog.all] and covers every game that
## exhibits anything. Nothing here names a game to decide behaviour.
##
## Headless `--script` runs compile before autoloads exist, so [AchievementManager]
## is resolved from the tree and poked with `call`. The gallery screen itself is
## loaded at runtime rather than preloaded, for the same reason: it is a
## `MenuScreen` and it touches autoloads.

## Stands in for a game's stage so the screen's orbit wiring can be observed
## without a real 3D viewport — headless has no renderer, and a test that only
## checked the screen's own numbers would not prove they ever left the screen.
class ViewSpy:
	extends Control

	var views: Array[Vector3] = []
	var configured: Array[String] = []
	var spinning := false

	func configure(exhibit: Dictionary) -> void:
		configured.append(str(exhibit.get("id", "")))

	func set_view(yaw: float, pitch: float, zoom: float) -> void:
		views.append(Vector3(yaw, pitch, zoom))

	func set_auto_spin(enabled: bool) -> void:
		spinning = enabled

	func last() -> Vector3:
		return views[-1] if not views.is_empty() else Vector3.ZERO


var _failures := PackedStringArray()
## Whatever the machine had Reduced motion set to, put back on the way out. The
## turntable's behaviour depends on it, so the test pins it rather than
## inheriting whatever the last run left behind.
var _restore_reduced_motion := false


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var achievements := get_root().get_node_or_null("AchievementManager")
	var settings := get_root().get_node_or_null("Settings")
	if achievements == null or settings == null:
		printerr("The Settings and AchievementManager autoloads are required.")
		quit(1)
		return
	_restore_reduced_motion = bool(
		settings.call("get_value", Settings.REDUCED_MOTION_KEY, false)
	)
	_set_reduced_motion(settings, false)

	var exhibiting := _games_with_galleries()
	_test_declarations()
	for manifest in exhibiting:
		_test_stage_contract(manifest)
	await _test_screen(exhibiting)
	await _test_orbit(exhibiting)
	await _test_reduced_motion(settings, exhibiting)
	await _test_locked_exhibits(achievements, exhibiting)
	await _test_empty_screen()
	await _test_menu_entry_points(exhibiting)
	# Menu sounds release their stopped playbacks on the mixer thread.
	await create_timer(0.25, true, false, true).timeout
	_finish()


func _games_with_galleries() -> Array[GameManifest]:
	var exhibiting: Array[GameManifest] = []
	for manifest in GameCatalog.all():
		_expect(
			manifest.has_gallery()
			== (
				not manifest.gallery_exhibits.is_empty()
				and not manifest.gallery_stage_scene_path.is_empty()
			),
			"%s: a gallery is exhibits plus a stage, and nothing else." % manifest.id
		)
		if manifest.has_gallery():
			exhibiting.append(manifest)
	_expect(
		not exhibiting.is_empty(),
		"At least one game must ship a gallery, or this test proves nothing."
	)
	return exhibiting


## An exhibit that cannot be told apart from its neighbour, or named in a list,
## is not an exhibit. Gating is checked against the game's own achievements so a
## typo cannot hide a model forever.
func _test_declarations() -> void:
	for manifest in GameCatalog.all():
		if manifest.gallery_exhibits.is_empty():
			continue
		var ids := PackedStringArray()
		for exhibit: Dictionary in manifest.gallery_exhibits:
			var id := str(exhibit.get("id", ""))
			_expect(
				not id.is_empty() and not ids.has(id),
				"%s declares a duplicate or unnamed exhibit: '%s'." % [manifest.id, id]
			)
			ids.append(id)
			_expect(
				not str(exhibit.get("title", "")).strip_edges().is_empty(),
				"%s must give exhibit '%s' a title." % [manifest.id, id]
			)
			# The facts are the label card. Without them the exhibit is carried
			# by the picture alone, which fails the project's own rule.
			_expect(
				not str(exhibit.get("description", "")).strip_edges().is_empty()
				or not (exhibit.get("facts", []) as Array).is_empty(),
				"%s must describe exhibit '%s' in words." % [manifest.id, id]
			)
			var requirement := str(exhibit.get("requires_achievement", ""))
			_expect(
				requirement.is_empty() or manifest.achievements.has(requirement),
				"%s gates exhibit '%s' behind an achievement it does not declare."
				% [manifest.id, id]
			)


## The stage is the one thing a game has to write itself, so the contract it is
## held to is checked before the screen ever tries to drive it.
func _test_stage_contract(manifest: GameManifest) -> void:
	var path := manifest.gallery_stage_scene_path
	_expect(
		ResourceLoader.exists(path),
		"%s declares a gallery stage that does not exist (%s)." % [manifest.id, path]
	)
	if not ResourceLoader.exists(path):
		return
	var packed := load(path) as PackedScene
	_expect(packed != null, "%s's gallery stage must be a scene." % manifest.id)
	if packed == null:
		return
	var stage := packed.instantiate()
	_expect(
		stage is Control, "%s's gallery stage must be a Control." % manifest.id
	)
	_expect(
		stage.has_method("configure"),
		"%s's gallery stage must implement configure(Dictionary)." % manifest.id
	)
	# Orbiting is optional in the contract, but a gallery whose stage cannot
	# turn is a slideshow, so every shipped one is expected to.
	_expect(
		stage.has_method("set_view"),
		"%s's gallery stage must implement set_view(yaw, pitch, zoom)." % manifest.id
	)
	stage.free()


## The room is generated, so a game gets a plinth per exhibit — and a caption
## that follows the selection — without this screen knowing what any of them are.
func _test_screen(exhibiting: Array[GameManifest]) -> void:
	if exhibiting.is_empty():
		return
	var manifest := exhibiting[0]
	var screen := await _open_gallery(manifest.id)
	if screen == null:
		return

	var buttons: Array = screen.get("_buttons")
	_expect(
		buttons.size() == manifest.gallery_exhibits.size(),
		"%s must get a button for every exhibit it declares." % manifest.id
	)
	var headings := PackedStringArray()
	for exhibit: Dictionary in manifest.gallery_exhibits:
		var heading := str(exhibit.get("heading", ""))
		if not headings.has(heading):
			headings.append(heading)
	_expect(
		(screen.get_node("%Sections") as Node).get_child_count() == headings.size(),
		"%s must get one section per heading it uses." % manifest.id
	)
	_expect(
		(screen.get_node("%Title") as Label).text.contains(manifest.title)
		and not (screen.get_node("%Intro") as Label).text.is_empty()
		and not (screen.get_node("%Empty") as Control).visible,
		"%s must title and introduce its own gallery." % manifest.id
	)
	_expect(
		screen.get("_stage") != null,
		"%s must load the stage it declares." % manifest.id
	)
	_expect(
		int(screen.get("_selected")) >= 0
		and not (screen.get_node("%ExhibitTitle") as Label).text.is_empty(),
		"%s's gallery must open on something." % manifest.id
	)
	_expect(
		(screen.get_node("%Controls") as Control).visible
		and (screen.get_node("%Hint") as Control).visible,
		"%s's gallery must show the orbit controls its stage supports." % manifest.id
	)

	# Selecting the second exhibit has to move the caption, or the list is
	# decoration.
	if manifest.gallery_exhibits.size() > 1:
		var before := (screen.get_node("%ExhibitTitle") as Label).text
		var other := _other_viewable(screen, int(screen.get("_selected")))
		if other >= 0:
			screen.call("_on_exhibit_pressed", other)
			await process_frame
			_expect(
				(screen.get_node("%ExhibitTitle") as Label).text != before,
				"%s's caption must follow the selected exhibit." % manifest.id
			)
	await _free_scene(screen)


## The orbit has one implementation and several ways in; this checks they reach
## it, agree about direction, and stop where they are told to.
func _test_orbit(exhibiting: Array[GameManifest]) -> void:
	if exhibiting.is_empty():
		return
	var screen := await _open_gallery(exhibiting[0].id)
	if screen == null:
		return
	var spy := _install_spy(screen)
	var exhibit: Dictionary = exhibiting[0].gallery_exhibits[0]

	screen.call("_select", 0)
	_expect(
		spy.configured.has(str(exhibit.get("id", ""))),
		"Choosing an exhibit must hand it to the stage."
	)
	_expect(
		spy.last().is_equal_approx(Vector3(0.0, 0.0, 1.0)),
		"A freshly chosen exhibit must be shown the way its stage framed it."
	)

	# ▶ and a drag to the right must push yaw the same way, or the buttons and
	# the mouse would fight each other.
	screen.call("_on_nudge_down", screen.get("AXIS_YAW"), 1.0)
	_expect(spy.last().x > 0.0, "Turning right must raise yaw.")
	screen.call("_orbit_by", Vector2(40.0, 0.0))
	_expect(
		spy.last().x > 0.0, "Dragging right must turn the model the same way."
	)
	screen.call("_orbit_by", Vector2(0.0, 60.0))
	_expect(spy.last().y > 0.0, "Dragging down must raise the camera.")

	# Held long enough to run off the end of every axis: nothing may escape.
	for step in 200:
		screen.call("_nudge", screen.get("AXIS_PITCH"), 1.0, 0.2)
		screen.call("_nudge", screen.get("AXIS_ZOOM"), 1.0, 0.2)
	screen.call("_apply_view")
	_expect(
		is_equal_approx(spy.last().y, float(screen.get("PITCH_MAX")))
		and is_equal_approx(spy.last().z, float(screen.get("ZOOM_MAX"))),
		"Tilt and zoom must stop at their limits."
	)
	for step in 200:
		screen.call("_nudge", screen.get("AXIS_PITCH"), -1.0, 0.2)
		screen.call("_nudge", screen.get("AXIS_ZOOM"), -1.0, 0.2)
	screen.call("_apply_view")
	_expect(
		is_equal_approx(spy.last().y, float(screen.get("PITCH_MIN")))
		and is_equal_approx(spy.last().z, float(screen.get("ZOOM_MIN"))),
		"Tilt and zoom must stop at their other limits."
	)

	screen.call("_on_reset_pressed")
	_expect(
		spy.last().is_equal_approx(Vector3(0.0, 0.0, 1.0)),
		"Reset must put the model back the way it was framed."
	)

	# The turntable is the only thing on this screen that moves on its own.
	var before := spy.views.size()
	screen.call("_process", 0.1)
	_expect(
		spy.views.size() > before and spy.last().x > 0.0,
		"Auto-spin must keep turning the model."
	)
	screen.call("_on_spin_toggled", false)
	screen.call("_on_reset_pressed")
	before = spy.views.size()
	screen.call("_process", 0.1)
	_expect(
		spy.views.size() == before,
		"Turning auto-spin off must leave the model where the player put it."
	)
	await _free_scene(screen)


## Reduced motion parks the turntable, and says so, rather than leaving a toggle
## that silently does nothing.
func _test_reduced_motion(
	settings: Node, exhibiting: Array[GameManifest]
) -> void:
	if exhibiting.is_empty():
		return
	_set_reduced_motion(settings, true)

	var screen := await _open_gallery(exhibiting[0].id)
	if screen != null:
		var spy := _install_spy(screen)
		screen.call("_select", 0)
		var toggle := screen.get_node("%SpinToggle") as CheckButton
		_expect(
			toggle.disabled
			and not toggle.button_pressed
			and toggle.tooltip_text.to_lower().contains("reduced motion"),
			"Reduced motion must disable the auto-spin toggle and explain why."
		)
		var before := spy.views.size()
		screen.call("_process", 0.5)
		_expect(
			spy.views.size() == before,
			"Reduced motion must park the turntable."
		)
		# Parked, not broken: the player can still turn it themselves.
		screen.call("_on_nudge_down", screen.get("AXIS_YAW"), 1.0)
		_expect(
			spy.views.size() > before,
			"Reduced motion must still let the player turn the model."
		)
		await _free_scene(screen)

	_set_reduced_motion(settings, false)


## A gated exhibit is listed but not viewable, so the collection reads as
## something to finish rather than something the game is hiding.
func _test_locked_exhibits(
	achievements: Node, exhibiting: Array[GameManifest]
) -> void:
	var manifest: GameManifest = null
	var gated := ""
	for candidate in exhibiting:
		for exhibit: Dictionary in candidate.gallery_exhibits:
			if not str(exhibit.get("requires_achievement", "")).is_empty():
				manifest = candidate
				gated = str(exhibit.get("requires_achievement", ""))
				break
		if manifest != null:
			break
	_expect(
		manifest != null,
		"Some game must gate an exhibit, or the locked path is never exercised."
	)
	if manifest == null:
		return

	# The in-memory flag only: unlocking for real would write to the player's
	# save file, and this test has no business doing that.
	var unlocked_map: Dictionary = achievements.get("_unlocked")
	var was_unlocked: Variant = unlocked_map.get(gated)
	unlocked_map.erase(gated)

	var screen := await _open_gallery(manifest.id)
	if screen != null:
		var locked_buttons := 0
		var buttons: Array = screen.get("_buttons")
		for index in manifest.gallery_exhibits.size():
			var exhibit: Dictionary = manifest.gallery_exhibits[index]
			var requirement := str(exhibit.get("requires_achievement", ""))
			var button := buttons[index] as Button
			var should_lock := (
				not requirement.is_empty()
				and not bool(achievements.call("is_unlocked", requirement))
			)
			_expect(
				button.disabled == should_lock,
				"%s must disable exhibit '%s' exactly while it is locked."
				% [manifest.id, str(exhibit.get("id", ""))]
			)
			if should_lock:
				locked_buttons += 1
				_expect(
					not button.tooltip_text.strip_edges().is_empty()
					and button.text.to_lower().contains("locked"),
					"A locked exhibit must say it is locked, and why."
				)
		_expect(locked_buttons > 0, "The locked exhibit must be locked.")
		_expect(
			not (screen.get_node("%Sections") as Node).get_children().is_empty(),
			"A locked exhibit must still be listed."
		)
		var opened: int = screen.get("_selected")
		_expect(
			opened >= 0 and not (buttons[opened] as Button).disabled,
			"A gallery must open on an exhibit the player can actually view."
		)

		# An achievement can land while the screen is open, because the pause
		# overlay sits on a round that is still scoring.
		unlocked_map[gated] = "now"
		achievements.emit_signal(
			"unlocked", gated, achievements.call("get_achievement", gated)
		)
		await process_frame
		var rebuilt: Array = screen.get("_buttons")
		for index in manifest.gallery_exhibits.size():
			if (
				str(manifest.gallery_exhibits[index].get("requires_achievement", ""))
				== gated
			):
				_expect(
					not (rebuilt[index] as Button).disabled,
					"Earning the achievement must open the exhibit straight away."
				)
		await _free_scene(screen)

	if was_unlocked == null:
		unlocked_map.erase(gated)
	else:
		unlocked_map[gated] = was_unlocked


## A collection's main menu has not chosen a game, so the screen must say there
## is nothing on display rather than guess or crash.
func _test_empty_screen() -> void:
	var screen := await _open_gallery("")
	if screen == null:
		return
	_expect(
		(screen.get("_buttons") as Array).is_empty()
		and (screen.get_node("%Empty") as Control).visible
		and not (screen.get_node("%Body") as Control).visible,
		"A gallery with no game must show its empty state."
	)
	_expect(
		not (screen.get_node("%Controls") as Control).visible,
		"A gallery with nothing to turn must not offer controls that turn it."
	)
	await _free_scene(screen)


## The gallery is reached from two places, and both have to know whose models
## they would be showing. A collection's title screen has not chosen a game, so
## it must not offer one; the pause menu always has a round running.
func _test_menu_entry_points(exhibiting: Array[GameManifest]) -> void:
	var menu: Node = (load("res://scenes/menus/main_menu.tscn") as PackedScene).instantiate()
	get_root().add_child(menu)
	await process_frame
	_expect(
		not (menu.get_node("%GalleryButton") as Button).visible,
		"A collection's title screen must not offer a gallery it cannot name."
	)
	await _free_scene(menu)

	for manifest in GameCatalog.all():
		GameCatalog.select(manifest.id)
		var pause: Node = (
			load("res://scenes/menus/pause_menu.tscn") as PackedScene
		).instantiate()
		get_root().add_child(pause)
		await process_frame
		_expect(
			(pause.get_node("%GalleryButton") as Button).visible == manifest.has_gallery(),
			"The pause menu must offer %s's gallery exactly when it has one."
			% manifest.id
		)
		if manifest.has_gallery():
			pause.call("_on_gallery_pressed")
			await process_frame
			var overlay: Node = pause.get("_gallery_overlay")
			_expect(
				overlay != null
				and str(overlay.get("game_context_id")) == manifest.id
				and not (pause as Control).visible,
				"Pausing into the gallery must show the running game's models."
			)
			if overlay != null:
				overlay.call("go_back")
				await process_frame
				await process_frame
				_expect(
					(pause as Control).visible,
					"Leaving the gallery must return to the pause menu."
				)
		pause.free()
		paused = false
		await process_frame
	if not exhibiting.is_empty():
		GameCatalog.select(exhibiting[0].id)


# --------------------------------------------------------------------------
# Helpers
# --------------------------------------------------------------------------


## Swaps the game's real stage for one that records what it is told. Headless
## has no renderer, so this is the only way to prove the screen's numbers ever
## reach a model.
func _install_spy(screen: Node) -> ViewSpy:
	var stage: Node = screen.get("_stage")
	if stage != null:
		stage.queue_free()
	var spy := ViewSpy.new()
	(screen.get_node("%StageHost") as Node).add_child(spy)
	screen.set("_stage", spy)
	screen.set("_stage_orbits", true)
	screen.set("_stage_spins", true)
	# The turntable is stepped by hand from here on, so a frame passing between
	# two assertions cannot quietly move the model underneath them.
	screen.set_process(false)
	return spy


func _other_viewable(screen: Node, current: int) -> int:
	var buttons: Array = screen.get("_buttons")
	for index in buttons.size():
		if index != current and not (buttons[index] as Button).disabled:
			return index
	return -1


func _set_reduced_motion(settings: Node, enabled: bool) -> void:
	settings.call("set_value", Settings.REDUCED_MOTION_KEY, enabled)


func _open_gallery(game_id: String) -> Node:
	var packed := load("res://scenes/menus/gallery.tscn") as PackedScene
	if packed == null:
		_failures.append("Could not load the gallery scene.")
		return null
	var screen := packed.instantiate()
	# Assigned before `add_child`, which is when `_ready` builds the room.
	screen.set("game_context_id", game_id)
	get_root().add_child(screen)
	await process_frame
	return screen


func _free_scene(scene: Node) -> void:
	scene.queue_free()
	await process_frame


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)


func _finish() -> void:
	var settings := get_root().get_node_or_null("Settings")
	if settings != null:
		_set_reduced_motion(settings, _restore_reduced_motion)
	for failure: String in _failures:
		printerr(failure)
	if _failures.is_empty():
		print("Gallery: all checks passed.")
	quit(0 if _failures.is_empty() else 1)
