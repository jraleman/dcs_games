extends SceneTree

## The cartridge is part of navigation, not just decoration: it must finish once,
## remain usable on small screens, and never strand a reduced-motion player.

const MAIN_MENU := "res://scenes/menus/main_menu.tscn"
const GAME_SELECT := "res://scenes/menus/game_select.tscn"
const MODE_SELECT := "res://scenes/menus/mode_select.tscn"
const ARCADE_SELECT := "res://scenes/menus/arcade_select.tscn"
const ConsoleModel = preload("res://ui/components/cartridge_console.gd")
const KonamiCode = preload("res://scripts/konami_code.gd")

var _failures := PackedStringArray()
var _routes := PackedStringArray()
var _settings: Node
var _router: Node


func _init() -> void:
	_run.call_deferred()


func _run() -> void:
	_settings = root.get_node_or_null("Settings")
	_router = root.get_node_or_null("Router")
	if _settings == null or _router == null:
		push_error("Main menu tests require Settings and Router.")
		quit(1)
		return
	if not GameCatalog.offers_a_choice():
		push_error("Run main_menu_test.gd with -- --game=all.")
		quit(1)
		return
	var original_values: Dictionary = (_settings.get("_values") as Dictionary).duplicate()
	var original_size := root.size
	var original_theme := root.theme
	_router.connect("scene_changed", _on_scene_changed)
	_set_setting("ui/scale", 1.0)
	_set_setting("accessibility/reduced_motion", true)
	await _test_release_version()
	await _test_layouts()
	await _test_themed_portrait()
	await _test_cover_fallback()
	await _test_reduced_motion()
	await _test_setup_details()
	_test_konami_recognizer()
	await _test_konami_entry()
	await _test_konami_is_collection_only()
	await _test_launch(false, false)
	await _test_launch(true, false)
	await _test_launch(false, true)
	await _test_closed_menu_cancels_launch()
	await _test_standalone_launch()
	GameCatalog.clear_restriction()
	root.theme = original_theme
	root.size = original_size
	_settings.set("_values", original_values)
	_settings.emit_signal(
		"changed", "accessibility/reduced_motion",
		original_values.get("accessibility/reduced_motion", false)
	)
	if _failures.is_empty():
		print("Main menu tests passed.")
		quit(0)
	else:
		for failure in _failures:
			push_error(failure)
		quit(1)


func _test_release_version() -> void:
	var feature := "editor" if OS.has_feature("editor") else "template"
	var key := "application/config/version." + feature
	var existed := ProjectSettings.has_setting(key)
	var original: Variant = ProjectSettings.get_setting(key) if existed else null
	ProjectSettings.set_setting(key, "9.8.7")
	var menu := await _open(MAIN_MENU)
	if menu != null:
		_expect((menu.get_node("%FooterRight") as Label).text == "v9.8.7",
			"The title screen must display the feature-overridden release version.")
		await _close(menu)
	if existed:
		ProjectSettings.set_setting(key, original)
	else:
		ProjectSettings.clear(key)


func _test_layouts() -> void:
	var menu := await _open(MAIN_MENU)
	if menu == null:
		return
	_expect(not (menu.get_node("%Tagline") as Control).visible,
		"The title screen should not repeat its branding as a paragraph.")
	_expect(not (menu.get_node("%Title") as Control).accessibility_description.is_empty(),
		"The quieter title must retain its descriptive copy for assistive technology.")
	var play := menu.get_node("%PlayButton") as Button
	var box := play.get_theme_stylebox("normal") as StyleBoxFlat
	_expect(box != null and box.bg_color.a <= 0.18 and box.border_width_top == 1
		and box.corner_radius_top_left == 0,
		"Navigation must use translucent, square-edged one-pixel rows.")
	var scroll := menu.get_node("%MenuScroll") as ScrollContainer
	_expect(scroll.follow_focus, "A short menu must scroll to keyboard/gamepad focus.")
	for dimensions: Vector2i in [
		Vector2i(1280, 720), Vector2i(390, 844), Vector2i(844, 390),
		Vector2i(2560, 1080), Vector2i(320, 568),
	]:
		root.size = dimensions
		for frame in 5:
			await process_frame
		var bounds := menu.get_global_rect()
		var portrait := bounds.size.y > bounds.size.x
		var showcase := menu.get_node("%LogoShowcase") as Control
		var viewport := menu.get_node("%LogoViewport") as SubViewport
		var display_width := showcase.size.x * dimensions.x / bounds.size.x
		_expect(viewport.size.x <= display_width * 2.0,
			"The menu must not oversample its 3D illustration on a small screen.")
		_expect(bounds.encloses(showcase.get_global_rect()),
			"The console must remain in the viewport at %s." % dimensions)
		_expect(bounds.encloses((menu.get_node("%Title") as Control).get_global_rect()),
			"The title must remain in the viewport at %s." % dimensions)
		for button: Button in menu.get("_menu_buttons"):
			if not button.is_visible_in_tree():
				continue
			button.grab_focus()
			for frame in 3:
				await process_frame
			var rect := button.get_global_rect()
			var accent := menu.get_node("%FocusAccent") as Control
			_expect(accent.get_parent() == button
				and accent.get_global_rect().position.is_equal_approx(rect.position),
				"The focus bar must stay attached to %s through resize and scrolling."
				% button.name)
			_expect(bounds.grow(1.0).encloses(rect),
				"%s must be reachable without horizontal clipping at %s."
				% [button.name, dimensions])
			_expect(scroll.get_global_rect().grow(1.0).encloses(rect),
				"Focus must scroll the whole %s row into view at %s."
				% [button.name, dimensions])
			var pixels := rect.size.y * dimensions.x / bounds.size.x
			_expect(pixels >= 44.0,
				"%s must retain a 44px touch target at %s, not %.1fpx."
				% [button.name, dimensions, pixels])
			if portrait:
				_expect(showcase.get_global_rect().end.y <= rect.position.y + 1.0,
					"The portrait console must not cover menu actions at %s." % dimensions)
		_expect(bounds.encloses((menu.get_node("%FooterLeft") as Control).get_global_rect()),
			"The footer must stay in view at %s." % dimensions)
	await _close(menu)
	root.size = Vector2i(1280, 720)
	await process_frame


func _test_reduced_motion() -> void:
	_set_setting("accessibility/reduced_motion", true)
	var menu := await _open(MAIN_MENU)
	if menu == null:
		return
	var cartridge := menu.get_node("%LogoRig") as Node3D
	var resting := cartridge.transform
	(menu.get_node("%StoreButton") as Button).emit_signal("focus_entered")
	await create_timer(0.15).timeout
	_expect(cartridge.transform.is_equal_approx(resting) and not menu.is_processing(),
		"Reduced motion must park the cartridge, including focus feedback.")
	_set_setting("accessibility/reduced_motion", false)
	await create_timer(0.15).timeout
	_expect(not cartridge.transform.is_equal_approx(resting),
		"Disabling reduced motion must restore idle movement without a reload.")
	_set_setting("accessibility/reduced_motion", true)
	_expect(cartridge.position.is_equal_approx(ConsoleModel.READY_POSITION),
		"Enabling reduced motion must return to the stationary ready pose.")
	await _close(menu)


func _test_themed_portrait() -> void:
	var games := GameCatalog.all()
	for manifest in games:
		GameCatalog.restrict_to(manifest.id)
		root.theme = GameCatalog.theme().restyle(ThemeDB.get_project_theme())
		root.size = Vector2i(1280, 720)
		var menu := await _open(MAIN_MENU)
		if menu == null:
			continue
		var theme := GameCatalog.theme()
		var cover := theme.cover_texture()
		var face := menu.get_node("%Face") as Sprite3D
		if not theme.cover_texture_path.is_empty():
			_expect(cover != null and face.texture == cover and face.modulate == Color.WHITE,
				"The '%s' title must use its full-colour cover without the logo tint."
				% manifest.id)
		root.size = Vector2i(320, 568)
		for frame in 5:
			await process_frame
		var showcase := menu.get_node("%LogoShowcase") as Control
		var space := menu.get_node("%ShowcaseSpace") as Control
		var scroll := menu.get_node("%MenuScroll") as ScrollContainer
		_expect(is_equal_approx(showcase.global_position.y, space.global_position.y),
			"The '%s' console must follow the final title layout, not its pre-resize position."
			% manifest.id)
		_expect(showcase.get_global_rect().end.y <= scroll.global_position.y,
			"The '%s' console must not overlap Play on a small phone." % manifest.id)
		for button: Button in menu.get("_menu_buttons"):
			if not button.is_visible_in_tree():
				continue
			button.grab_focus()
			for frame in 3:
				await process_frame
			_expect(scroll.get_global_rect().grow(1.0).encloses(button.get_global_rect()),
				"The '%s' menu must scroll to every optional action, including %s."
				% [manifest.id, button.name])
		await _close(menu)
	GameCatalog.clear_restriction()
	root.theme = GameCatalog.theme().restyle(ThemeDB.get_project_theme())
	root.size = Vector2i(1280, 720)
	await process_frame


func _test_cover_fallback() -> void:
	GameCatalog.restrict_to(GameCatalog.all()[0].id)
	var manifest := GameCatalog.current()
	var original_theme := manifest.theme
	manifest.theme = GameTheme.studio_default()
	manifest.theme.cover_texture_path = "res://icon.svg"
	manifest.theme.logo_color = Color("e35a70")
	var menu := await _open(MAIN_MENU)
	if menu != null:
		var face := menu.get_node("%Face") as Sprite3D
		_expect(face.texture == load("res://icon.svg") and face.modulate == Color.WHITE,
			"Dedicated cover art must ignore a non-white silhouette tint.")
		for path in ["", "res://tests/missing_cover_art.png"]:
			manifest.theme.cover_texture_path = path
			menu.call("_apply_theme")
			_expect(face.texture == manifest.theme.logo_texture()
				and face.modulate == manifest.theme.logo_color,
				"A missing or undeclared cover must retain the original tinted logo fallback.")
		await _close(menu)
	manifest.theme = original_theme
	GameCatalog.clear_restriction()


func _test_setup_details() -> void:
	GameCatalog.select("triangle_rush")
	var screen := await _open(MODE_SELECT)
	if screen == null:
		return
	var details := screen.get_node("%DetailsButton") as Button
	var description := screen.get_node("%ConfirmDescription") as Label
	var controls := screen.get_node("%PlayerOneControlKeys") as Label
	_expect(not details.button_pressed and not description.visible,
		"Repeated setup notes should be collapsed by default.")
	_expect(controls.visible and not controls.text.is_empty(),
		"Essential controller bindings must never be hidden behind Details.")
	details.button_pressed = true
	_expect(description.visible and not description.text.is_empty(),
		"Details must reveal the game's original setup description.")
	_expect(details.text == "Less", "The expanded state must not rely on colour alone.")
	details.button_pressed = false
	_expect(not description.visible,
		"Details must be collapsible again without changing the chosen mode.")
	var choose := screen.get_node("%SinglePlayerButton") as Button
	_expect(not choose.accessibility_name.is_empty()
		and not choose.accessibility_description.is_empty(),
		"Short Select buttons must still identify their mode and game description.")
	root.size = Vector2i(390, 844)
	for frame in 5:
		await process_frame
	for button: Button in [details, choose]:
		var pixels := button.size.y * root.size.x / screen.size.x
		_expect(pixels >= 44.0,
			"Setup actions must retain 44px touch targets even without character or level choices.")
	await _close(screen)
	root.size = Vector2i(1280, 720)
	await process_frame


func _test_launch(reduced: bool, interrupt_motion: bool) -> void:
	_set_setting("accessibility/reduced_motion", reduced)
	var menu := await _open(MAIN_MENU)
	if menu == null:
		return
	current_scene = menu
	var count := _routes.size()
	var console := menu.get_node("%Console") as Node3D
	var cartridge := menu.get_node("%LogoRig") as Node3D
	var receiver := console.get_node("Receiver") as Node3D
	var receiver_pose := receiver.transform
	var cartridge_pose := cartridge.transform
	menu.call("_on_play_pressed")
	var tween: Tween = menu.get("_launch_tween")
	menu.call("_on_play_pressed")
	menu.call("_on_settings_pressed")
	menu.call("go_back")
	menu.call("_on_progression_changed", "test_unlock", true)
	for key: int in KonamiCode.SEQUENCE:
		root.push_input(_code_key(key))
	_expect(menu.get("_launch_tween") == tween,
		"Repeated activation must not restart insertion or schedule another route.")
	for button: Button in menu.get("_menu_buttons"):
		_expect(button.disabled, "All navigation must be locked until insertion completes.")
	if reduced:
		await create_timer(0.06).timeout
		_expect(cartridge.transform.is_equal_approx(cartridge_pose),
			"A reduced-motion launch must fade without moving the cartridge.")
		_expect((menu.get_node("%LogoShowcase") as Control).modulate.a < 1.0,
			"A reduced-motion launch should still acknowledge Play with a fade.")
	else:
		await create_timer(0.35).timeout
		var amount := float(console.get("insertion"))
		_expect(amount > 0.0 and amount < 1.0,
			"Play must visibly slide through an intermediate insertion pose.")
		_expect(cartridge.position.y < ConsoleModel.READY_POSITION.y
			and receiver.transform.is_equal_approx(receiver_pose),
			"The cartridge must descend into a stationary console.")
		_expect(_routes.size() == count and not bool(_router.call("is_transitioning")),
			"Navigation must wait for the insertion, not hide it behind a router fade.")
		root.size = Vector2i(720, 1280)
		await process_frame
		_expect(float(console.get("insertion")) >= amount,
			"Resizing during insertion must not reset its progress.")
		if interrupt_motion:
			_set_setting("accessibility/reduced_motion", true)
			var frozen := cartridge.transform
			await create_timer(0.06).timeout
			_expect(cartridge.transform.is_equal_approx(frozen),
				"A live reduced-motion change must stop all spatial launch motion.")
	await _wait_for_route(GAME_SELECT)
	_expect(_routes.size() == count + 1,
		"Every Play activation must complete exactly one route, even after a motion change.")
	await _close_current()
	root.size = Vector2i(1280, 720)


func _test_closed_menu_cancels_launch() -> void:
	_set_setting("accessibility/reduced_motion", false)
	var menu := await _open(MAIN_MENU)
	if menu == null:
		return
	var count := _routes.size()
	menu.call("_on_play_pressed")
	await _close(menu)
	await create_timer(1.1).timeout
	_expect(_routes.size() == count and not bool(_router.call("is_transitioning")),
		"Freeing a menu must cancel its pending launch callback.")


func _test_standalone_launch() -> void:
	GameCatalog.restrict_to("triangle_rush")
	_set_setting("accessibility/reduced_motion", true)
	var menu := await _open(MAIN_MENU)
	if menu == null:
		return
	current_scene = menu
	var count := _routes.size()
	menu.call("_on_play_pressed")
	await _wait_for_route(MODE_SELECT)
	_expect(_routes.size() == count + 1 and GameCatalog.current_id() == "triangle_rush",
		"A standalone cartridge must use the selected game's setup route, not the picker.")
	await _close_current()
	GameCatalog.clear_restriction()


func _test_konami_recognizer() -> void:
	var code := KonamiCode.new()
	for index in KonamiCode.SEQUENCE.size():
		var key: int = KonamiCode.SEQUENCE[index]
		var result := code.feed(_code_key(key))
		_expect(result == (KonamiCode.Result.COMPLETE if index == 9
			else KonamiCode.Result.CONSUME if index == 8 else KonamiCode.Result.PASS),
			"Only B/A may intercept normal title navigation, and only the full code opens town.")
		code.feed(_code_key(key, false))
	code.feed(_code_key(KEY_UP))
	code.feed(_code_key(KEY_UP))
	code.feed(_code_key(KEY_UP))
	for key: int in KonamiCode.SEQUENCE.slice(2, 9):
		code.feed(_code_key(key))
	_expect(code.feed(_code_key(KEY_A)) == KonamiCode.Result.COMPLETE,
		"An overlapping up/up prefix must recover without requiring a title reload.")
	for key: int in KonamiCode.SEQUENCE.slice(0, 5):
		code.feed(_code_key(key))
	code.feed(_code_key(KEY_SPACE))
	for key: int in KonamiCode.SEQUENCE.slice(5):
		_expect(code.feed(_code_key(key)) != KonamiCode.Result.COMPLETE,
			"An unrelated press must reset a partial code.")
	code.reset()
	var repeated := _code_key(KEY_UP)
	repeated.echo = true
	code.feed(_code_key(KEY_UP))
	code.feed(repeated)
	for key: int in KonamiCode.SEQUENCE.slice(2):
		_expect(code.feed(_code_key(key)) != KonamiCode.Result.COMPLETE,
			"Keyboard echo must not stand in for the second Up press.")
	code.reset()
	for key: int in KonamiCode.SEQUENCE.slice(0, 8):
		code.feed(_code_key(key))
	var modified := _code_key(KEY_B)
	modified.ctrl_pressed = true
	code.feed(modified)
	_expect(code.feed(_code_key(KEY_A)) != KonamiCode.Result.COMPLETE,
		"Modified shortcuts must not complete the code.")
	code.reset()
	for key: int in KonamiCode.SEQUENCE.slice(0, 4):
		code.feed(_code_key(key))
	code.reset()
	for key: int in KonamiCode.SEQUENCE.slice(4):
		_expect(code.feed(_code_key(key)) != KonamiCode.Result.COMPLETE,
			"Resetting the recognizer must abandon a partial entry.")


func _test_konami_entry() -> void:
	for use_pad in [false, true]:
		var menu := await _open(MAIN_MENU)
		if menu == null:
			return
		current_scene = menu
		var count := _routes.size()
		(menu.get_node("%QuitButton") as Button).grab_focus()
		for key: int in KonamiCode.SEQUENCE:
			if use_pad:
				var button := InputEventJoypadButton.new()
				button.button_index = KonamiCode.PAD_KEYS.find_key(key)
				button.pressed = true
				root.push_input(button)
				button = button.duplicate()
				button.pressed = false
				root.push_input(button)
			else:
				root.push_input(_code_key(key))
				root.push_input(_code_key(key, false))
		_expect(bool(menu.get("_closing")) and not bool(menu.get("_launching_game")),
			"The full code must open town directly, not activate a focused title action.")
		await _wait_for_route(ARCADE_SELECT)
		_expect(current_scene != null and current_scene.has_method("_enter_nearby"),
			"The Konami destination must load the working town controller, not an empty scene.")
		_expect(_routes.size() == count + 1,
			"The %s code must route to town exactly once." % ("gamepad" if use_pad else "keyboard"))
		await _close_current()
	var title := await _open(MAIN_MENU)
	if title == null:
		return
	root.push_input(_code_key(KEY_UP))
	root.push_input(_code_key(KEY_UP))
	title.call("_notification", Node.NOTIFICATION_APPLICATION_FOCUS_OUT)
	for key: int in KonamiCode.SEQUENCE.slice(2):
		root.push_input(_code_key(key))
	_expect(not bool(title.get("_closing")),
		"Losing application focus must abandon the title's partial code.")
	root.push_input(_code_key(KEY_B))
	root.push_input(_code_key(KEY_A))
	_expect(not bool(title.get("_closing"))
		and str(_router.call("game_selection_return_scene", GAME_SELECT, MAIN_MENU)) == GAME_SELECT,
		"A new title visit must forget the code and restore the ordinary Play picker.")
	await _close(title)


func _test_konami_is_collection_only() -> void:
	GameCatalog.restrict_to("triangle_rush")
	var menu := await _open(MAIN_MENU)
	if menu != null:
		for key: int in KonamiCode.SEQUENCE:
			root.push_input(_code_key(key))
			root.push_input(_code_key(key, false))
		_expect(not bool(menu.get("_closing")),
			"Standalone title screens must not activate the collection's secret selector.")
		await _close(menu)
	GameCatalog.clear_restriction()


func _code_key(key: int, pressed := true) -> InputEventKey:
	var event := InputEventKey.new()
	event.keycode = key
	event.physical_keycode = key
	event.pressed = pressed
	return event


func _wait_for_route(path: String) -> void:
	var deadline := Time.get_ticks_msec() + 6000
	while Time.get_ticks_msec() < deadline:
		if str(_router.get("current_scene_path")) == path \
			and not bool(_router.call("is_transitioning")) and current_scene != null \
			and current_scene.scene_file_path == path:
			return
		await process_frame
	_expect(false, "Navigation did not complete to %s." % path)


func _on_scene_changed(path: String) -> void:
	_routes.append(path)


func _set_setting(key: String, value: Variant) -> void:
	var values: Dictionary = (_settings.get("_values") as Dictionary).duplicate()
	values[key] = value
	_settings.set("_values", values)
	_settings.emit_signal("changed", key, value)


func _open(path: String) -> Control:
	var packed := load(path) as PackedScene
	if packed == null:
		_expect(false, "Could not load %s." % path)
		return null
	var screen := packed.instantiate() as Control
	root.add_child(screen)
	await process_frame
	await process_frame
	return screen


func _close(screen: Node) -> void:
	if current_scene == screen:
		current_scene = null
	root.remove_child(screen)
	screen.queue_free()
	await process_frame


func _close_current() -> void:
	if current_scene != null:
		await _close(current_scene)


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
