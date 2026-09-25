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


class StaticStage:
	extends Control

	func configure(_exhibit: Dictionary) -> void:
		pass


class SpinStage:
	extends StaticStage
	var spinning := false

	func set_auto_spin(enabled: bool) -> void:
		spinning = enabled


class OrbitStage:
	extends StaticStage
	var view := Vector3.ZERO

	func set_view(yaw: float, pitch: float, zoom: float) -> void:
		view = Vector3(yaw, pitch, zoom)


var _failures := PackedStringArray()
## Whatever the machine had Reduced motion set to, put back on the way out. The
## turntable's behaviour depends on it, so the test pins it rather than
## inheriting whatever the last run left behind.
var _restore_reduced_motion := false
var _restore_ui_scale := 1.0
var _restore_window_size := Vector2i.ZERO


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
	_restore_ui_scale = float(settings.call("get_value", "ui/scale", 1.0))
	_restore_window_size = root.size
	_set_setting(settings, "ui/scale", 1.0)
	_set_reduced_motion(settings, false)

	var exhibiting := _games_with_galleries()
	_test_declarations()
	for manifest in exhibiting:
		_test_stage_contract(manifest)
	await _test_screen(exhibiting)
	await _test_orbit(exhibiting)
	await _test_mouse_routing(settings, exhibiting)
	await _test_touch(exhibiting)
	await _test_keyboard_and_pad(exhibiting)
	await _test_optional_stage_methods(exhibiting)
	await _test_responsive_layout(exhibiting)
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
		and not (screen.get_node("%Title") as Control).tooltip_text.is_empty()
		and not (screen.get_node("%Empty") as Control).visible,
		"%s must retain its context without a visible introduction." % manifest.id
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
	for removed: String in [
		"Controls", "Hint", "Intro", "ExhibitDescription", "Facts", "SpinToggle", "ResetButton",
	]:
		_expect(screen.get_node_or_null("%" + removed) == null,
			"%s must not reserve space for the old %s UI." % [manifest.id, removed])
	var selected: Dictionary = manifest.gallery_exhibits[int(screen.get("_selected"))]
	var caption := screen.get_node("%ExhibitTitle") as Label
	_expect(caption.tooltip_text.contains(str(selected.get("description", ""))),
		"The selected model's full description must remain available on hover.")
	var viewer := screen.get_node("%Viewer") as Control
	for fact: String in selected.get("facts", []):
		_expect(viewer.accessibility_description.contains(fact),
			"The model's facts must remain available to assistive technology.")
	_expect(viewer.tooltip_text.is_empty(),
		"Hovering the model itself must not cover it in a paragraph.")
	_expect(screen.find_children("*", "BaseButton", true, false).size() == buttons.size() + 1,
		"Only exhibit choices and Back should be visible buttons in the Gallery.")

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
			for index in buttons.size():
				_expect((buttons[index] as Button).button_pressed == (index == other),
					"Only the currently selected exhibit may remain pressed.")
	await _free_scene(screen)


## Exercise the actual viewer signal, including grabbing, zooming and the two
## mouse-only replacements for Reset and Auto-spin.
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

	_move_mouse(screen, Vector2(40, 60), false)
	_expect(spy.last().is_equal_approx(Vector3(0, 0, 1)),
		"Hovering without a grab must not rotate the asset.")
	_mouse(screen, MOUSE_BUTTON_LEFT, true)
	_expect(not spy.spinning, "Grabbing must suspend the stage's own auto-spin hook.")
	_move_mouse(screen, Vector2(40, 60), true)
	_expect(spy.last().x > 0.0 and spy.last().y > 0.0,
		"A mouse drag must reach the stage's yaw and pitch.")
	var release := InputEventMouseButton.new()
	release.button_index = MOUSE_BUTTON_LEFT
	release.position = Vector2(-10, -10)
	screen.call("_input", release)
	_expect(not bool(screen.get("_dragging")) and spy.spinning,
		"A release outside the model must end the grab and restore turntable state.")
	var last := spy.last()
	_move_mouse(screen, Vector2(40, 60), false)
	_expect(spy.last().is_equal_approx(last), "A released grab must not remain stuck.")

	_mouse(screen, MOUSE_BUTTON_LEFT, true, true)
	_expect(spy.last().is_equal_approx(Vector3(0, 0, 1)),
		"Double-click must restore the exhibit's default framing.")
	_expect(not bool(screen.get("_dragging")), "A double-click reset must not begin another drag.")
	_mouse(screen, MOUSE_BUTTON_WHEEL_UP, true)
	_expect(spy.last().z > 1.0, "Scrolling up must zoom in.")
	_mouse(screen, MOUSE_BUTTON_WHEEL_DOWN, true)
	_expect(is_equal_approx(spy.last().z, 1.0), "Opposite wheel steps must agree.")

	_mouse(screen, MOUSE_BUTTON_LEFT, true)
	_move_mouse(screen, Vector2(100000, 100000), true)
	_expect(spy.last().x >= -PI and spy.last().x <= PI,
		"Long drags must wrap yaw rather than accumulating unbounded rotation.")
	for step in 200:
		_mouse(screen, MOUSE_BUTTON_WHEEL_UP, true)
	_expect(
		is_equal_approx(spy.last().y, float(screen.get("PITCH_MAX")))
		and is_equal_approx(spy.last().z, float(screen.get("ZOOM_MAX"))),
		"Tilt and zoom must stop at their limits."
	)
	_move_mouse(screen, Vector2(-100000, -100000), true)
	for step in 200:
		_mouse(screen, MOUSE_BUTTON_WHEEL_DOWN, true)
	_expect(
		is_equal_approx(spy.last().y, float(screen.get("PITCH_MIN")))
		and is_equal_approx(spy.last().z, float(screen.get("ZOOM_MIN"))),
		"Tilt and zoom must stop at their other limits."
	)

	_mouse(screen, MOUSE_BUTTON_LEFT, true, true)
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
	_mouse(screen, MOUSE_BUTTON_RIGHT, true)
	_mouse(screen, MOUSE_BUTTON_LEFT, true, true)
	before = spy.views.size()
	screen.call("_process", 0.1)
	_expect(
		spy.views.size() == before,
		"Turning auto-spin off must leave the model where the player put it."
	)
	_expect(not spy.spinning
		and (screen.get_node("%Viewer") as Control).accessibility_description.contains("resume"),
		"The hidden spin action must still communicate its paused state.")
	_mouse(screen, MOUSE_BUTTON_RIGHT, true)
	_expect(spy.spinning, "A second right-click must resume auto-spin.")
	await _free_scene(screen)


## Real viewport dispatch catches a stage's child Controls intercepting the
## mouse, which emitting gui_input on the viewer directly cannot detect.
func _test_mouse_routing(settings: Node, exhibiting: Array[GameManifest]) -> void:
	_set_reduced_motion(settings, true)
	for manifest in exhibiting:
		var screen := await _open_gallery(manifest.id)
		var viewer := screen.get_node("%Viewer") as Control
		var center := viewer.get_global_rect().get_center()
		_push_mouse(MOUSE_BUTTON_LEFT, true, center)
		var motion := InputEventMouseMotion.new()
		motion.position = center + Vector2(85, 30)
		motion.global_position = motion.position
		motion.relative = Vector2(85, 30)
		motion.button_mask = MOUSE_BUTTON_MASK_LEFT
		root.push_input(motion, true)
		_push_mouse(MOUSE_BUTTON_LEFT, false, motion.position)
		_expect(absf(float(screen.get("_yaw"))) > 0.1
			and not bool(screen.get("_dragging")),
			"%s: native mouse dispatch must rotate and release the asset." % manifest.id)
		_push_mouse(MOUSE_BUTTON_WHEEL_UP, true, center)
		_push_mouse(MOUSE_BUTTON_WHEEL_UP, false, center)
		_expect(float(screen.get("_zoom")) > 1.0,
			"%s: native wheel input must reach the asset." % manifest.id)
		var zoom := float(screen.get("_zoom"))
		var list := screen.get_node("%ListScroll") as Control
		_push_mouse(MOUSE_BUTTON_WHEEL_DOWN, true, list.get_global_rect().get_center())
		_push_mouse(MOUSE_BUTTON_WHEEL_DOWN, false, list.get_global_rect().get_center())
		_expect(is_equal_approx(float(screen.get("_zoom")), zoom),
			"Scrolling the exhibit list must not also zoom the model.")
		_push_mouse(MOUSE_BUTTON_LEFT, true, center, true)
		_push_mouse(MOUSE_BUTTON_LEFT, false, center)
		_expect(is_zero_approx(float(screen.get("_yaw")))
			and is_equal_approx(float(screen.get("_zoom")), 1.0),
			"%s: native double-click must restore default framing." % manifest.id)
		await _free_scene(screen)
	_set_reduced_motion(settings, false)


func _test_touch(exhibiting: Array[GameManifest]) -> void:
	if exhibiting.is_empty():
		return
	var screen := await _open_gallery(exhibiting[0].id)
	var spy := _install_spy(screen)
	screen.call("_select", 0)
	_touch(screen, 0, Vector2(100, 100), true)
	_drag_touch(screen, 0, Vector2(130, 140), Vector2(30, 40))
	_expect(spy.last().x > 0.0 and spy.last().y > 0.0,
		"A touch drag must still rotate the asset without a toolbar.")
	_touch(screen, 0, Vector2(130, 140), false)
	_touch(screen, 0, Vector2(100, 100), true, true)
	_expect(spy.last().is_equal_approx(Vector3(0, 0, 1)), "Double-tap must reset the view.")

	_touch(screen, 0, Vector2(100, 100), true)
	_touch(screen, 1, Vector2(200, 100), true)
	_drag_touch(screen, 1, Vector2(250, 100), Vector2(50, 0))
	_expect(is_equal_approx(spy.last().z, 1.5), "Pinching apart must magnify the model.")
	_drag_touch(screen, 1, Vector2(101, 100), Vector2(-149, 0))
	_expect(is_equal_approx(spy.last().z, float(screen.get("ZOOM_MIN"))),
		"A pinch must respect the same zoom limits as the wheel.")
	_touch(screen, 1, Vector2(101, 100), false)
	_touch(screen, 0, Vector2(100, 100), false)
	_expect(bool(screen.get("_auto_spin")), "A pinch must not be mistaken for a two-finger tap.")
	_touch(screen, 0, Vector2(100, 100), true)
	_touch(screen, 1, Vector2(200, 100), true)
	_touch(screen, 1, Vector2(200, 100), false)
	_touch(screen, 0, Vector2(100, 100), false)
	_expect(not bool(screen.get("_auto_spin")), "A two-finger tap must pause auto-spin.")

	_touch(screen, 0, Vector2(100, 100), true)
	var cancel := InputEventScreenTouch.new()
	cancel.index = 0
	cancel.canceled = true
	(screen.get_node("%Viewer") as Control).emit_signal("gui_input", cancel)
	_expect(not bool(screen.get("_dragging")) and (screen.get("_touches") as Dictionary).is_empty(),
		"Touch cancellation must release every tracked contact.")
	await _free_scene(screen)


func _test_keyboard_and_pad(exhibiting: Array[GameManifest]) -> void:
	if exhibiting.is_empty():
		return
	var screen := await _open_gallery(exhibiting[0].id)
	var spy := _install_spy(screen)
	screen.call("_select", 0)
	var viewer := screen.get_node("%Viewer") as Control
	viewer.grab_focus()
	_key(screen, KEY_D)
	_expect(spy.last().x > 0.0, "A focused viewer must remain usable without a mouse.")
	_key(screen, KEY_R)
	_expect(spy.last().is_equal_approx(Vector3(0, 0, 1)), "R must reset the focused viewer.")
	var arrow := InputEventKey.new()
	arrow.keycode = KEY_LEFT
	arrow.pressed = true
	_expect(not bool(screen.call("_on_viewer_key", arrow)),
		"Arrow keys must remain free to move menu focus.")
	var pad := InputEventJoypadMotion.new()
	pad.axis = JOY_AXIS_RIGHT_X
	pad.axis_value = 0.8
	screen.call("_input", pad)
	screen.call("_process", 0.2)
	_expect(spy.last().x > 0.0 and not spy.spinning,
		"The focused viewer's right stick must orbit without fighting auto-spin.")
	(screen.get_node("%BackButton") as Button).grab_focus()
	_expect((screen.get("_pad_orbit") as Vector2).is_zero_approx(),
		"Leaving the viewer must release the held stick.")
	screen.call("_input", pad)
	_expect((screen.get("_pad_orbit") as Vector2).is_zero_approx(),
		"The gallery must not capture right-stick input outside the viewer.")
	await _free_scene(screen)


func _test_optional_stage_methods(exhibiting: Array[GameManifest]) -> void:
	if exhibiting.is_empty():
		return
	var screen := await _open_gallery(exhibiting[0].id)
	var still := StaticStage.new()
	_install_stage(screen, still)
	screen.call("_select", 0)
	var viewer := screen.get_node("%Viewer") as Control
	_expect(viewer.focus_mode == Control.FOCUS_NONE and not screen.is_processing(),
		"A static stage must not advertise dead gestures or keep ticking.")
	_mouse(screen, MOUSE_BUTTON_WHEEL_UP, true)
	_expect(is_equal_approx(float(screen.get("_zoom")), 1.0),
		"A stage without set_view must not claim to zoom.")

	var orbit := OrbitStage.new()
	_install_stage(screen, orbit)
	screen.call("_select", 0)
	_mouse(screen, MOUSE_BUTTON_WHEEL_UP, true)
	_expect(orbit.view.z > 1.0, "Orbit must work without the optional set_auto_spin method.")
	var spin := SpinStage.new()
	_install_stage(screen, spin)
	screen.call("_select", 0)
	_expect(spin.spinning, "A spin-only stage must receive its own turntable state.")
	_mouse(screen, MOUSE_BUTTON_RIGHT, true)
	_expect(not spin.spinning, "A spin-only stage must still be pausable with the mouse.")

	_install_stage(screen, Control.new())
	screen.call("_select", 0)
	_expect((screen.get_node("%Placeholder") as Control).visible
		and viewer.focus_mode == Control.FOCUS_NONE,
		"A stage without configure must retain its badge fallback, without gestures.")
	await _free_scene(screen)


func _test_responsive_layout(exhibiting: Array[GameManifest]) -> void:
	for manifest in exhibiting:
		var screen := await _open_gallery(manifest.id)
		for dimensions: Vector2i in [
			Vector2i(1280, 720), Vector2i(390, 844), Vector2i(320, 568),
			Vector2i(844, 390), Vector2i(2560, 1080),
		]:
			root.size = dimensions
			for frame in 5:
				await process_frame
			var control := screen as Control
			var bounds := control.get_global_rect()
			var viewer := screen.get_node("%Viewer") as Control
			var list := screen.get_node("%ListScroll") as ScrollContainer
			var caption := screen.get_node("%ExhibitTitle") as Control
			var portrait := bounds.size.y > bounds.size.x
			_expect(bounds.grow(1.0).encloses(viewer.get_global_rect())
				and bounds.grow(1.0).encloses(caption.get_global_rect())
				and bounds.grow(1.0).encloses(list.get_global_rect()),
				"%s: viewer, caption and asset list must fit at %s." % [manifest.id, dimensions])
			var minimum_share := 0.5 if portrait else 0.7 if dimensions.y < 500 else 0.78
			_expect(viewer.size.y >= bounds.size.y * minimum_share,
				"%s: the asset must get at least %.0f%% of the screen height at %s."
				% [manifest.id, minimum_share * 100.0, dimensions])
			_expect(not viewer.get_global_rect().intersects(list.get_global_rect()),
				"The asset and chooser must not overlap at %s." % dimensions)
			var ring := (screen.get_node("%ViewerFocus") as Control).get_theme_stylebox(
				"panel") as StyleBoxFlat
			_expect(ring.border_width_left * dimensions.x / bounds.size.x >= 1.8,
				"The viewer's focus ring must remain readable at %s." % dimensions)
			for button: Button in screen.get("_buttons"):
				if button.disabled:
					continue
				button.grab_focus()
				for frame in 2:
					await process_frame
				_expect(list.get_global_rect().grow(1.0).encloses(button.get_global_rect()),
					"Every exhibit must scroll into view at %s." % dimensions)
				_expect(button.size.y * dimensions.x / bounds.size.x >= 44.0,
					"Exhibit choices must retain 44px touch targets at %s." % dimensions)
		await _free_scene(screen)
	root.size = _restore_window_size
	await process_frame


## Reduced motion removes automatic motion, not direct manipulation.
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
		var viewer := screen.get_node("%Viewer") as Control
		_expect(
			not spy.spinning and viewer.accessibility_description.contains("Reduced motion"),
			"Reduced motion must park the stage and explain the unavailable spin action."
		)
		var before := spy.views.size()
		screen.call("_process", 0.5)
		_expect(
			spy.views.size() == before,
			"Reduced motion must park the turntable."
		)
		# Parked, not broken: the player can still turn it themselves.
		_mouse(screen, MOUSE_BUTTON_LEFT, true)
		_move_mouse(screen, Vector2(40, 20), true)
		_expect(
			spy.views.size() > before,
			"Reduced motion must still let the player turn the model."
		)
		_mouse(screen, MOUSE_BUTTON_LEFT, false)
		_mouse(screen, MOUSE_BUTTON_RIGHT, true)
		_expect(not spy.spinning, "Right-click must not override Reduced motion.")
		_set_reduced_motion(settings, false)
		_expect(spy.spinning, "Disabling Reduced motion must restore the requested turntable.")
		_set_reduced_motion(settings, true)
		_expect(not spy.spinning, "A live Reduced motion change must reach the stage.")
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
		_expect(int(screen.get("_selected")) == opened,
			"A live unlock must not switch away from the model being inspected.")
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
		(screen.get_node("%Viewer") as Control).focus_mode == Control.FOCUS_NONE
		and not screen.is_processing(),
		"A gallery with nothing to inspect must not offer gestures or keep spinning."
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
	var spy := ViewSpy.new()
	_install_stage(screen, spy)
	return spy


func _install_stage(screen: Node, replacement: Control) -> void:
	var stage: Node = screen.get("_stage")
	if stage != null:
		stage.get_parent().remove_child(stage)
		stage.queue_free()
	(screen.get_node("%StageHost") as Node).add_child(replacement)
	screen.set("_stage", replacement)
	screen.set("_stage_configures", replacement.has_method("configure"))
	screen.set("_stage_orbits", replacement.has_method("set_view"))
	screen.set("_stage_spins", replacement.has_method("set_auto_spin"))


func _mouse(screen: Node, button: MouseButton, pressed: bool, double_click := false) -> void:
	var event := InputEventMouseButton.new()
	event.button_index = button
	event.pressed = pressed
	event.double_click = double_click
	event.factor = 1.0
	(screen.get_node("%Viewer") as Control).emit_signal("gui_input", event)


func _push_mouse(
	button: MouseButton, pressed: bool, at: Vector2, double_click := false
) -> void:
	var event := InputEventMouseButton.new()
	event.button_index = button
	event.pressed = pressed
	event.position = at
	event.global_position = at
	event.double_click = double_click
	event.factor = 1.0
	root.push_input(event, true)


func _move_mouse(screen: Node, relative: Vector2, held: bool) -> void:
	var event := InputEventMouseMotion.new()
	event.relative = relative
	event.button_mask = MOUSE_BUTTON_MASK_LEFT if held else 0
	(screen.get_node("%Viewer") as Control).emit_signal("gui_input", event)


func _touch(
	screen: Node, index: int, at: Vector2, pressed: bool, double_tap := false
) -> void:
	var event := InputEventScreenTouch.new()
	event.index = index
	event.position = at
	event.pressed = pressed
	event.double_tap = double_tap
	(screen.get_node("%Viewer") as Control).emit_signal("gui_input", event)


func _drag_touch(screen: Node, index: int, at: Vector2, relative: Vector2) -> void:
	var event := InputEventScreenDrag.new()
	event.index = index
	event.position = at
	event.relative = relative
	(screen.get_node("%Viewer") as Control).emit_signal("gui_input", event)


func _key(screen: Node, keycode: Key) -> void:
	var event := InputEventKey.new()
	event.keycode = keycode
	event.pressed = true
	(screen.get_node("%Viewer") as Control).emit_signal("gui_input", event)


func _other_viewable(screen: Node, current: int) -> int:
	var buttons: Array = screen.get("_buttons")
	for index in buttons.size():
		if index != current and not (buttons[index] as Button).disabled:
			return index
	return -1


func _set_reduced_motion(settings: Node, enabled: bool) -> void:
	_set_setting(settings, Settings.REDUCED_MOTION_KEY, enabled)


func _set_setting(settings: Node, key: String, value: Variant) -> void:
	var values: Dictionary = (settings.get("_values") as Dictionary).duplicate()
	values[key] = value
	settings.set("_values", values)
	settings.emit_signal("changed", key, value)


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
		_set_setting(settings, "ui/scale", _restore_ui_scale)
	root.size = _restore_window_size
	for failure: String in _failures:
		printerr(failure)
	if _failures.is_empty():
		print("Gallery: all checks passed.")
	quit(0 if _failures.is_empty() else 1)
