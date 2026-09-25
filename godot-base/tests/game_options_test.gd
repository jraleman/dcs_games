extends SceneTree

## Per-game options and bindings: the Controls and Game tabs.
##
## Those two tabs configure one game, so they must not exist on the main-menu
## Settings screen and must appear — fully built from the active
## [GameManifest] — when the pause menu opens the same scene inside a game.
##
## This test iterates [method GameCatalog.all], so a new game is covered the
## moment it declares options. Nothing here names a game to decide behaviour;
## the per-game blocks only assert the values those games chose.
##
## Headless `--script` runs compile before autoloads exist, so the [Settings]
## instance is resolved from the tree and poked with `call`. Only its constants
## are referenced directly.

var _failures := PackedStringArray()
var _restore: Dictionary = {}


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var settings := get_root().get_node_or_null("Settings")
	if settings == null:
		_failures.append("The Settings autoload is required.")
		_finish(settings)
		return

	_test_declarations()
	_test_registry(settings)
	await _test_menu_without_a_game()
	for manifest in GameCatalog.all():
		await _test_menu_for_game(settings, manifest)
	await _test_slider_writes_through(settings)
	await _test_choice_writes_through(settings)
	_test_binding_scope(settings)
	_test_movement_summary(settings)
	_finish(settings)


## Every declared option and binding has to be well formed before any screen
## can render it, and keys have to be globally unique or one game would
## silently overwrite another's saved value.
func _test_declarations() -> void:
	var option_keys: Dictionary = {}
	var binding_keys: Dictionary = {}
	var actions: Dictionary = {}
	for manifest in GameCatalog.all():
		for definition: Dictionary in manifest.tunables:
			var key := str(definition.get("key", ""))
			_expect(
				key.begins_with("game/") and not option_keys.has(key),
				"%s declares a duplicate or unprefixed option key: '%s'."
				% [manifest.id, key]
			)
			option_keys[key] = manifest.id
			_expect(
				not str(definition.get("title", "")).strip_edges().is_empty(),
				"%s must give option '%s' a row title." % [manifest.id, key]
			)
			if str(definition.get("type", "")) == GameManifest.OPTION_CHOICE:
				_expect(
					not (definition.get("choices", []) as Array).is_empty(),
					"%s must give choice option '%s' some choices."
					% [manifest.id, key]
				)
				continue
			if str(definition.get("type", "")) == GameManifest.OPTION_TOGGLE:
				continue
			var minimum := float(definition.get("min", 0.0))
			var maximum := float(definition.get("max", 0.0))
			var fallback := float(definition.get("default", 0.0))
			_expect(
				minimum < maximum and fallback >= minimum and fallback <= maximum,
				"%s must give slider '%s' a default inside its range."
				% [manifest.id, key]
			)

		for definition: Dictionary in manifest.control_bindings:
			var key := str(definition.get("key", ""))
			var action := str(definition.get("action", ""))
			_expect(
				key.begins_with("controls/") and not binding_keys.has(key),
				"%s declares a duplicate or unprefixed binding key: '%s'."
				% [manifest.id, key]
			)
			binding_keys[key] = manifest.id
			_expect(
				not action.is_empty() and not actions.has(action),
				"%s declares a duplicate or missing binding action for '%s'."
				% [manifest.id, key]
			)
			actions[action] = manifest.id
			_expect(
				int(definition.get("default", KEY_NONE)) != KEY_NONE,
				"%s must give binding '%s' a default key." % [manifest.id, key]
			)


## The registry is what makes the tabs data-driven: everything a game declared
## must be stored, clamped, formatted and applied to the InputMap without the
## framework naming the game.
func _test_registry(settings: Node) -> void:
	for manifest in GameCatalog.all():
		var declared: Array = settings.call("options_for_game", manifest.id)
		_expect(
			declared.size() == manifest.tunables.size(),
			"Settings must register every option %s declares." % manifest.id
		)
		for definition: Dictionary in manifest.tunables:
			var key := str(definition["key"])
			_expect(
				settings.call("get_value", key) != null,
				"Settings must hold a value for '%s'." % key
			)

		for definition: Dictionary in manifest.control_bindings:
			var key := str(definition["key"])
			var action := StringName(definition["action"])
			_expect(
				InputMap.has_action(action),
				"Settings must apply '%s' to the InputMap." % action
			)
			_expect(
				int(settings.call("binding_keycode", key))
				== int(definition["default"]),
				"'%s' must start on its declared default key." % key
			)
			_expect(
				str(settings.call("binding_title", key))
				== str(definition["title"]),
				"'%s' must report the title its game gave it." % key
			)

	# A game that declares nothing still gets the bindings for its style, so
	# a `targets` game keeps its six keys without declaring them.
	for manifest in GameCatalog.all():
		if not manifest.control_bindings.is_empty():
			continue
		_expect(
			not (settings.call(
				"control_bindings_for_game", manifest.id
			) as Array).is_empty(),
			"%s must inherit the bindings for its control style." % manifest.id
		)


## Opened from the main menu there is no game to configure, so both per-game
## tabs must be gone rather than empty or full of another game's rows.
func _test_menu_without_a_game() -> void:
	var menu := await _open_menu("")
	if menu == null:
		return

	var tabs := menu.get_node_or_null("%Tabs") as TabContainer
	_expect(
		tabs != null
		and _tab_hidden(tabs, menu, "%GameOptions")
		and _tab_hidden(tabs, menu, "%KeyboardBindings"),
		"The main menu must not show the Controls and Game tabs."
	)
	_expect(
		(menu.get("_option_controls") as Dictionary).is_empty()
		and (menu.get("_binding_buttons") as Dictionary).is_empty(),
		"No game means no generated option or binding rows."
	)
	# The rows that are not about one game had to move somewhere reachable.
	_expect(
		menu.get_node_or_null("%ShowInstructionsToggle") != null
		and menu.get_node_or_null("%ResetButton") != null
		and not _tab_hidden(tabs, menu, "%ShowInstructionsToggle"),
		"Show instructions and Restore defaults must stay reachable."
	)
	await _free_scene(menu)


## Opened from the pause menu the two tabs appear, built entirely from the
## running game's manifest.
func _test_menu_for_game(settings: Node, manifest: GameManifest) -> void:
	var menu := await _open_menu(manifest.id)
	if menu == null:
		return

	var tabs := menu.get_node_or_null("%Tabs") as TabContainer
	_expect(
		tabs != null
		and not _tab_hidden(tabs, menu, "%GameOptions")
		and not _tab_hidden(tabs, menu, "%KeyboardBindings"),
		"%s must expose the Controls and Game tabs in-game." % manifest.id
	)

	var options := menu.get("_option_controls") as Dictionary
	_expect(
		options.size() == manifest.tunables.size(),
		"%s must get a row for every option it declares." % manifest.id
	)
	var bindings := menu.get("_binding_buttons") as Dictionary
	var declared_bindings: Array = settings.call(
		"control_bindings_for_game", manifest.id
	)
	_expect(
		bindings.size() == declared_bindings.size(),
		"%s must get a row for every binding it uses." % manifest.id
	)

	for key: String in options:
		var control := options[key] as Control
		if control is CheckButton:
			_expect(control.theme_type_variation == &"MenuToggle",
				"Game option '%s' must use the shared menu toggle style." % key)
		_expect(
			control != null
			and not control.tooltip_text.is_empty()
			and control.accessibility_description == control.tooltip_text,
			"Option '%s' must describe itself for assistive tech." % key
		)
	for key: String in bindings:
		var button := bindings[key] as Button
		_expect(
			button != null
			and button.text == str(settings.call("binding_key_label", key)),
			"Binding '%s' must show the key it is bound to." % key
		)
		_expect(
			button != null
			and not button.tooltip_text.is_empty()
			and button.accessibility_description == button.tooltip_text,
			"Binding '%s' must describe itself for assistive tech." % key
		)

	# Read-outs are formatted from the game's declared `format`, so a seconds
	# option never reads as a bare number.
	var values := menu.get("_option_values") as Dictionary
	for key: String in values:
		_expect(
			(values[key] as Label).text
			== str(settings.call("format_option", key, settings.call("tunable", key))),
			"Option '%s' must read out in its declared format." % key
		)

	await _free_scene(menu)


## A generated slider is only useful if it writes through to the store the game
## reads at the start of the next round.
func _test_slider_writes_through(settings: Node) -> void:
	var menu := await _open_menu(DeskCanSawOptions.GAME_ID)
	if menu == null:
		return

	var options := menu.get("_option_controls") as Dictionary
	var slider := options.get(DeskCanSawOptions.MAX_CANS_KEY) as HSlider
	if slider == null:
		_failures.append("Desk-Can-Saw must offer a cans-on-the-desk slider.")
		await _free_scene(menu)
		return

	_expect(
		is_equal_approx(slider.min_value, float(DeskCanSawOptions.MIN_MAX_CANS))
		and is_equal_approx(slider.max_value, float(DeskCanSawOptions.MAX_MAX_CANS)),
		"The generated slider must span the range Settings clamps to."
	)
	_remember(settings, DeskCanSawOptions.MAX_CANS_KEY)
	slider.value = 12.0
	_expect(
		int(settings.call("tunable", DeskCanSawOptions.MAX_CANS_KEY)) == 12,
		"Moving a generated slider must write through to Settings."
	)

	_remember(settings, DeskCanSawOptions.CAN_SPEED_KEY)
	settings.call("set_value", DeskCanSawOptions.CAN_SPEED_KEY, 1.5)
	await process_frame
	var speed := options.get(DeskCanSawOptions.CAN_SPEED_KEY) as HSlider
	_expect(
		speed != null and is_equal_approx(speed.value, 1.5),
		"A generated slider must follow a change made elsewhere."
	)
	await _free_scene(menu)


## Choice options exist because not every game option is a number: Dead Metal
## Jam picks which input it listens to.
func _test_choice_writes_through(settings: Node) -> void:
	var menu := await _open_menu(DmjOptions.GAME_ID)
	if menu == null:
		return

	var options := menu.get("_option_controls") as Dictionary
	var picker := options.get(DmjOptions.NOTE_SOURCE_KEY) as OptionButton
	if picker == null:
		_failures.append("Dead Metal Jam must offer a note-input picker.")
		await _free_scene(menu)
		return

	_expect(
		picker.item_count == 4
		and picker.get_selected_id() == DmjOptions.SOURCE_AUTO,
		"The note-input picker must offer every source and start automatic."
	)
	_remember(settings, DmjOptions.NOTE_SOURCE_KEY)
	menu.call(
		"_on_option_choice_selected",
		picker.get_item_index(DmjOptions.SOURCE_KEYBOARD),
		DmjOptions.NOTE_SOURCE_KEY
	)
	_expect(
		int(settings.call("tunable_choice", DmjOptions.NOTE_SOURCE_KEY))
		== DmjOptions.SOURCE_KEYBOARD,
		"Picking a note input must write through to Settings."
	)

	# An unknown stored choice must not strand the game on a source it cannot
	# offer any more.
	settings.call("set_value", DmjOptions.NOTE_SOURCE_KEY, 99)
	_expect(
		int(settings.call("tunable_choice", DmjOptions.NOTE_SOURCE_KEY))
		== DmjOptions.DEFAULT_NOTE_SOURCE,
		"An unknown stored choice must fall back to the declared default."
	)
	await _free_scene(menu)


## Two games may use the same key: only one of them is ever running, so a
## conflict only means something inside one game's own bindings.
func _test_binding_scope(settings: Node) -> void:
	for key: String in [
		DeskCanSawOptions.MOVE_UP_KEY,
		DeskCanSawOptions.MOVE_DOWN_KEY,
		DmjOptions.OCTAVE_DOWN_BINDING,
	]:
		_remember(settings, key)

	settings.call(
		"set_binding_key", DeskCanSawOptions.MOVE_UP_KEY, KEY_W, DeskCanSawOptions.GAME_ID
	)
	_expect(
		int(settings.call("binding_keycode", DeskCanSawOptions.MOVE_UP_KEY)) == KEY_W,
		"Rebinding must store the new key."
	)
	settings.call(
		"set_binding_key",
		DmjOptions.OCTAVE_DOWN_BINDING,
		KEY_W,
		DmjOptions.GAME_ID
	)
	_expect(
		int(settings.call("binding_keycode", DeskCanSawOptions.MOVE_UP_KEY)) == KEY_W
		and int(settings.call("binding_keycode", DmjOptions.OCTAVE_DOWN_BINDING))
		== KEY_W,
		"A key used by another game must not be taken away from it."
	)

	# Inside one game the same key cannot mean two things, so it swaps.
	var displaced := int(
		settings.call("binding_keycode", DeskCanSawOptions.MOVE_DOWN_KEY)
	)
	settings.call(
		"set_binding_key",
		DeskCanSawOptions.MOVE_DOWN_KEY,
		KEY_W,
		DeskCanSawOptions.GAME_ID
	)
	_expect(
		int(settings.call("binding_keycode", DeskCanSawOptions.MOVE_DOWN_KEY)) == KEY_W
		and int(settings.call("binding_keycode", DeskCanSawOptions.MOVE_UP_KEY))
		== displaced,
		"Reusing a key inside one game must swap the two bindings."
	)
	_expect(
		_action_uses_key(DeskCanSawOptions.MOVE_DOWN_ACTION, KEY_W)
		and _action_uses_key(DeskCanSawOptions.MOVE_UP_ACTION, displaced),
		"A rebind must reach the InputMap, not just the config file."
	)

	settings.call("reset_controls_to_defaults", DeskCanSawOptions.GAME_ID)
	_expect(
		int(settings.call("binding_keycode", DeskCanSawOptions.MOVE_UP_KEY)) == KEY_UP
		and int(settings.call("binding_keycode", DmjOptions.OCTAVE_DOWN_BINDING))
		== KEY_W,
		"Restoring one game's controls must leave every other game alone."
	)


## Menus describe a game's movement keys instead of hardcoding "arrow keys",
## but only once the player has actually moved them — the shipped wording reads
## better than four key names.
func _test_movement_summary(settings: Node) -> void:
	_remember(settings, DeskCanSawOptions.MOVE_LEFT_KEY)
	_expect(
		str(settings.call(
			"movement_summary_for_game", DeskCanSawOptions.GAME_ID, "/", "ARROWS"
		)) == "ARROWS",
		"Untouched movement keys must keep the shipped wording."
	)
	settings.call(
		"set_binding_key", DeskCanSawOptions.MOVE_LEFT_KEY, KEY_J, DeskCanSawOptions.GAME_ID
	)
	_expect(
		str(settings.call(
			"movement_summary_for_game", DeskCanSawOptions.GAME_ID, "/", "ARROWS"
		)).contains("J"),
		"Rebound movement keys must be named instead of assumed."
	)
	_expect(
		str(settings.call(
			"movement_summary_for_game", DmjOptions.GAME_ID, "/", "ARROWS"
		)) == "ARROWS",
		"A game with no movement keys must keep the fallback wording."
	)


func _open_menu(game_id: String) -> Node:
	var packed := load("res://scenes/menus/settings_menu.tscn") as PackedScene
	if packed == null:
		_failures.append("Could not load the settings menu scene.")
		return null
	var menu := packed.instantiate()
	# Assigned before `add_child`, which is when `_ready` builds the tabs.
	menu.set("game_context_id", game_id)
	get_root().add_child(menu)
	await process_frame
	return menu


## True when the tab owning a widget is hidden, or gone entirely. Walks up to
## the TabContainer's own child rather than assuming a nesting depth.
func _tab_hidden(tabs: TabContainer, menu: Node, unique_name: String) -> bool:
	var node := menu.get_node_or_null(unique_name) as Node
	while node != null and node.get_parent() != tabs:
		node = node.get_parent()
	var page := node as Control
	if page == null:
		return true
	var index := tabs.get_tab_idx_from_control(page)
	return index < 0 or tabs.is_tab_hidden(index)


func _remember(settings: Node, key: String) -> void:
	if not _restore.has(key):
		_restore[key] = settings.call("get_value", key)


## True when the action fires on a physical key, which is what the shell's
## `Input.is_action_pressed()` calls actually read.
func _action_uses_key(action: StringName, keycode: int) -> bool:
	if not InputMap.has_action(action):
		return false
	for event: InputEvent in InputMap.action_get_events(action):
		var key_event := event as InputEventKey
		if key_event != null and key_event.physical_keycode == keycode:
			return true
	return false


func _free_scene(scene: Node) -> void:
	scene.queue_free()
	await process_frame


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)


func _finish(settings: Node) -> void:
	if settings != null:
		for key: String in _restore:
			settings.call("set_value", key, _restore[key])
		settings.call("save")
	for failure: String in _failures:
		push_error(failure)
	if _failures.is_empty():
		print("Per-game options: all checks passed.")
	quit(0 if _failures.is_empty() else 1)
