extends SceneTree

## Standalone builds: shipping — or just running — one game on its own.
##
## A build whose catalog holds exactly one game *is* the standalone product, so
## the whole feature is one filter in [GameCatalog] plus the branding that
## already reads from it. This test pins the catalog to each game in turn and
## asserts that the rest of the project follows without knowing a game by name:
## the title screen takes that game's name and tagline, only its entry exists,
## a gate it can never satisfy on its own does not hide it, its options reach
## the main-menu settings screen, and the credits roll is its own.
##
## Every assertion is driven from [method GameCatalog.all], so a new game is
## covered the moment it declares a manifest.
##
## Headless `--script` runs compile before autoloads exist, so screens are
## loaded at runtime and poked with `call`/`get` rather than named as types.

const MAIN_MENU := "res://scenes/menus/main_menu.tscn"
const SETTINGS_MENU := "res://scenes/menus/settings_menu.tscn"
const CREDITS_MENU := "res://scenes/menus/credits.tscn"
const FRAMEWORK_INTRO := "res://scenes/boot/intro.tscn"
const BACKGROUND := "res://ui/components/background.tscn"

var _failures := PackedStringArray()


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var collection := _catalog_ids()
	var pinned := GameCatalog.single_game_id()
	if pinned.is_empty():
		_test_collection_baseline(collection)
	else:
		_test_already_pinned_build(pinned, collection)
	_test_unknown_game_is_refused(collection)
	_test_project_is_not_pinned_by_default()
	for id in collection:
		_test_pinned_catalog(id)
		await _test_pinned_title_screen(id)
		await _test_pinned_settings_screen(id)
		await _test_pinned_credits_screen(id)
	_test_restriction_is_reversible(collection)
	_test_saving_keeps_absent_games_data()
	await _test_declared_intros(collection)
	await _test_collection_credits(collection)
	_test_declared_themes(collection)
	_finish()


## The default build is the collection: every game present, studio branding.
func _test_collection_baseline(collection: PackedStringArray) -> void:
	_expect(
		collection.size() > 1, "The collection build must ship more than one game."
	)
	_expect(
		not GameCatalog.is_single_game_build(),
		"The collection build must not report itself as a standalone build."
	)
	_expect(
		GameCatalog.product_title() == StudioInfo.TITLE
		and GameCatalog.product_tagline() == StudioInfo.TAGLINE,
		"The collection build must carry the studio's project branding."
	)


## The same file also has to pass inside an already-pinned build — exported, or
## run with `--game` — which is the only place the pin can be checked for real.
func _test_already_pinned_build(pinned: String, collection: PackedStringArray) -> void:
	_expect(
		collection == PackedStringArray([pinned]),
		"A build pinned to '%s' must hold only that game." % pinned
	)
	_expect(
		GameCatalog.is_single_game_build()
		and GameCatalog.product_title() == GameCatalog.current_title(),
		"A build pinned to '%s' must be branded as that game." % pinned
	)


## A typo in a preset or on the command line must not boot a build with nothing
## to play, so the request is refused and the catalog is left alone.
func _test_unknown_game_is_refused(collection: PackedStringArray) -> void:
	_expect(
		not GameCatalog.restrict_to("no_such_game"),
		"Pinning the catalog to an absent game must fail."
	)
	_expect(
		_catalog_ids() == collection,
		"A refused restriction must leave the catalog untouched."
	)


## The committed project is the collection: a standalone build is an export
## preset or a run argument, never the checked-in default. Only runs from source
## are inspected, because a per-game export is *supposed* to arrive here pinned
## through its feature-tag override of the same setting.
func _test_project_is_not_pinned_by_default() -> void:
	if not OS.has_feature("editor"):
		return
	_expect(
		str(ProjectSettings.get_setting(GameCatalog.SINGLE_GAME_SETTING, "")).is_empty(),
		"project.godot must leave `%s` empty and pin a standalone build with a "
		% GameCatalog.SINGLE_GAME_SETTING
		+ "feature-tag override instead."
	)


## The invariants every standalone build relies on, whichever game it ships.
func _test_pinned_catalog(id: String) -> void:
	_expect(GameCatalog.restrict_to(id), "Pinning the catalog to '%s' must succeed." % id)

	var manifest := GameCatalog.get_manifest(id)
	if manifest == null:
		_failures.append("'%s' disappeared from the catalog after pinning to it." % id)
		GameCatalog.clear_restriction()
		return

	_expect(
		_catalog_ids() == PackedStringArray([id]),
		"Pinning to '%s' must leave exactly that game in the catalog." % id
	)
	_expect(
		GameCatalog.is_single_game_build(),
		"A catalog holding only '%s' must report itself as a standalone build." % id
	)
	_expect(
		GameCatalog.current_id() == id
		and GameCatalog.current_gameplay_scene_path() == manifest.gameplay_scene_path,
		"'%s' must be the selected game, so Play starts it without a picker." % id
	)
	_expect(
		GameCatalog.product_title() == manifest.title
		and GameCatalog.product_tagline() == manifest.tagline,
		"A standalone build of '%s' must be branded with that game." % id
	)
	var expected_intro := (
		manifest.intro_scene_path
		if not manifest.intro_scene_path.is_empty()
		else FRAMEWORK_INTRO
	)
	_expect(
		GameCatalog.intro_scene_path(FRAMEWORK_INTRO) == expected_intro,
		"A standalone build of '%s' must open with the intro it declares." % id
	)
	# Slice-and-Slash is gated behind progress in another game; a build that
	# ships only Slice-and-Slash contains nothing that could ever open the gate.
	var available := GameCatalog.available()
	_expect(
		available.size() == 1 and available[0].id == id,
		"The only game in a standalone build must be playable even when gated ('%s')." % id
	)

	GameCatalog.clear_restriction()


## The title screen is where a standalone build has to stop looking like a
## collection: one game entry, and the game's own name above it.
func _test_pinned_title_screen(id: String) -> void:
	if not GameCatalog.restrict_to(id):
		return
	var manifest := GameCatalog.get_manifest(id)
	var packed := load(MAIN_MENU) as PackedScene
	if packed == null:
		_failures.append("Could not load %s" % MAIN_MENU)
		GameCatalog.clear_restriction()
		return

	var menu := packed.instantiate()
	get_root().add_child(menu)
	await process_frame
	await process_frame

	_expect(
		(menu.get_node("%Title") as Label).text == manifest.title
		and (menu.get_node("%Tagline") as Label).text == manifest.tagline,
		"The title screen of a standalone '%s' build must show that game." % id
	)

	var slots: Array = menu.get("_game_buttons")
	var shown := PackedStringArray()
	for index in slots.size():
		var button := slots[index] as Button
		if button.visible and not button.disabled:
			shown.append(button.name)
	_expect(
		shown.size() == 1,
		"A standalone '%s' build must offer one game entry, not %d." % [id, shown.size()]
	)
	_expect(
		PackedStringArray(menu.get("_game_ids")) == PackedStringArray([id]),
		"The title screen's only entry must start '%s'." % id
	)

	var logo := GameCatalog.theme().logo_texture()
	var face := menu.get_node_or_null("%Face") as Sprite3D
	_expect(
		face != null and face.texture != null and (logo == null or face.texture == logo),
		"A standalone '%s' build must show that game's logo on the plaque." % id
	)
	if face != null and face.texture != null:
		var span := float(
			menu.get_script().get_script_constant_map().get("LOGO_FACE_SPAN", 0.0)
		)
		var longest := maxf(face.texture.get_width(), face.texture.get_height())
		_expect(
			is_equal_approx(face.pixel_size * longest, span),
			"The '%s' logo must be scaled to the plaque, whatever its resolution." % id
		)

	menu.queue_free()
	await process_frame
	GameCatalog.clear_restriction()


## The other place a standalone build differs: with one game in the catalog,
## that game's Controls and Game tabs belong on the main-menu settings screen.
## Reaching your own game's options should not mean starting a round first.
func _test_pinned_settings_screen(id: String) -> void:
	if not GameCatalog.restrict_to(id):
		return
	var manifest := GameCatalog.get_manifest(id)
	var packed := load(SETTINGS_MENU) as PackedScene
	if packed == null or manifest == null:
		_failures.append("Could not open %s pinned to '%s'." % [SETTINGS_MENU, id])
		GameCatalog.clear_restriction()
		return

	# Opened the way the main menu opens it: nothing tells it which game.
	var menu := packed.instantiate()
	get_root().add_child(menu)
	await process_frame

	_expect(
		str(menu.get("game_context_id")) == id,
		"A standalone '%s' build's settings screen must configure that game." % id
	)
	var tabs := menu.get_node_or_null("%Tabs") as TabContainer
	_expect(
		tabs != null
		and not _tab_hidden(tabs, menu, "%GameOptions")
		and not _tab_hidden(tabs, menu, "%KeyboardBindings"),
		"A standalone '%s' build must show Controls and Game on the main menu." % id
	)
	_expect(
		(menu.get("_option_controls") as Dictionary).size() == manifest.tunables.size(),
		"'%s' must get a main-menu row for every option it declares." % id
	)
	_expect(
		not (menu.get("_binding_buttons") as Dictionary).is_empty(),
		"'%s' must get its rebindable controls on the main menu." % id
	)

	var one_button := menu.get_node_or_null("%OneButtonTargetRushToggle") as Control
	var row: Control = one_button.get_parent() if one_button != null else null
	_expect(
		row != null
		and row.visible == (manifest.control_style == GameManifest.CONTROL_STYLE_TARGETS),
		"Only a game played with target keys may offer one-button play ('%s')." % id
	)

	menu.queue_free()
	await process_frame
	GameCatalog.clear_restriction()


## Mirrors the settings screen's own page lookup: walk up to the direct child
## of the TabContainer, because a hidden tab keeps its page in the tree.
func _tab_hidden(tabs: TabContainer, menu: Node, unique_name: String) -> bool:
	var node := menu.get_node_or_null(unique_name) as Node
	while node != null and node.get_parent() != tabs:
		node = node.get_parent()
	var page := node as Control
	if page == null:
		return true
	var index := tabs.get_tab_idx_from_control(page)
	return index < 0 or tabs.is_tab_hidden(index)


## A standalone build is one game's product, so the roll leads with that game's
## own credits and still finishes with the studio's. Driven from the manifest,
## so a game is covered the moment it declares any.
func _test_pinned_credits_screen(id: String) -> void:
	if not GameCatalog.restrict_to(id):
		return
	var manifest := GameCatalog.get_manifest(id)
	var menu: Node = await _open_credits()
	if menu == null or manifest == null:
		_failures.append("Could not open %s pinned to '%s'." % [CREDITS_MENU, id])
		GameCatalog.clear_restriction()
		return

	var rolled := _credits_texts(menu)
	_expect(
		rolled.has(manifest.title),
		"A standalone '%s' build must credit that game by name." % id
	)
	var missing := PackedStringArray()
	for section: Dictionary in manifest.credits:
		for text in _section_texts(section):
			if not rolled.has(text):
				missing.append(text)
	_expect(
		missing.is_empty(),
		"The '%s' credits never roll: %s" % [id, ", ".join(missing)]
	)
	var shared := _studio_texts()
	_expect(
		shared.is_empty() or rolled.has(shared[0]),
		"A standalone '%s' build must still roll the studio credits." % id
	)
	_expect(
		not rolled.has(StudioInfo.COLLECTION_CREDITS_HEADING),
		"A standalone '%s' build has no other games to send the player to." % id
	)

	menu.queue_free()
	await process_frame
	GameCatalog.clear_restriction()


## With more than one game there is no right game to credit, so the roll names
## the ones it ships and points at them instead of borrowing anybody's credits.
func _test_collection_credits(collection: PackedStringArray) -> void:
	if collection.size() < 2:
		return
	GameCatalog.clear_restriction()
	var menu: Node = await _open_credits()
	if menu == null:
		_failures.append("Could not open %s for a collection build." % CREDITS_MENU)
		return

	var rolled := _credits_texts(menu)
	_expect(
		rolled.has(StudioInfo.COLLECTION_CREDITS_HEADING)
		and rolled.has(StudioInfo.COLLECTION_CREDITS_NOTE),
		"A collection build must send players to each game's own credits."
	)

	var shared := _studio_texts()
	var unnamed := PackedStringArray()
	var borrowed := PackedStringArray()
	for id in collection:
		var manifest := GameCatalog.get_manifest(id)
		if manifest == null:
			continue
		var named := false
		for text in rolled:
			if text.contains(manifest.title):
				named = true
				break
		if not named:
			unnamed.append(id)
		for section: Dictionary in manifest.credits:
			for text in _section_texts(section):
				if not shared.has(text) and rolled.has(text):
					borrowed.append("%s: %s" % [id, text])
	_expect(
		unnamed.is_empty(),
		"The collection credits must name every game it ships (%s)." % ", ".join(unnamed)
	)
	_expect(
		borrowed.is_empty(),
		"A collection build must not roll one game's own credits: %s" % ", ".join(borrowed)
	)

	menu.queue_free()
	await process_frame


## The credits screen with its auto-scroll stopped: the roll is what is being
## read here, not the motion.
func _open_credits() -> Node:
	var packed := load(CREDITS_MENU) as PackedScene
	if packed == null:
		return null
	var menu := packed.instantiate()
	get_root().add_child(menu)
	menu.set_process(false)
	await process_frame
	return menu


## Every line the roll renders, in order.
func _credits_texts(menu: Node) -> PackedStringArray:
	var texts := PackedStringArray()
	var list := menu.get_node_or_null("%List") as Node
	if list == null:
		return texts
	for child in list.get_children():
		var label := child as Label
		if label != null:
			texts.append(label.text)
	return texts


func _section_texts(section: Dictionary) -> PackedStringArray:
	var texts := PackedStringArray([str(section.get("heading", ""))])
	for line: String in section.get("lines", []):
		texts.append(line)
	return texts


func _studio_texts() -> PackedStringArray:
	var texts := PackedStringArray()
	for section: Dictionary in StudioInfo.CREDITS:
		texts.append_array(_section_texts(section))
	return texts


func _test_restriction_is_reversible(collection: PackedStringArray) -> void:
	_expect(
		_catalog_ids() == collection,
		"Clearing the restriction must restore every game this build ships."
	)
	var expected_title := StudioInfo.TITLE
	if collection.size() == 1:
		var manifest := GameCatalog.get_manifest(collection[0])
		expected_title = manifest.title if manifest else StudioInfo.TITLE
	_expect(
		GameCatalog.product_title() == expected_title,
		"Clearing the restriction must restore the build's own branding."
	)


## A build only registers the keys of the games it ships, and a run pinned with
## `--game` shares `user://` with the collection because the user directory is
## fixed at startup. Saving must therefore merge into the stored file: rebuilding
## it from the registered keys alone would drop another game's options and — the
## rule that must never break — its unlocks.
func _test_saving_keeps_absent_games_data() -> void:
	var settings := get_root().get_node_or_null("Settings")
	var achievements := get_root().get_node_or_null("AchievementManager")
	if settings == null or achievements == null:
		_failures.append("The Settings and AchievementManager autoloads are required.")
		return

	var settings_backup := _read_file(Settings.SAVE_PATH)
	# `AchievementManager.SAVE_PATH` cannot be written the way `Settings.SAVE_PATH`
	# is: naming that autoload here pulls `achievement_manager.gd` — and the toast
	# scene it references — into this script's compile pass, which runs before any
	# autoload exists. Read the constants off the running instance instead.
	var achievements_path := _constant(achievements, "SAVE_PATH", "user://achievements.cfg")
	var progression_section := _constant(achievements, "PROGRESSION_SECTION", "progression")
	var achievements_backup := _read_file(achievements_path)

	_expect(
		_survives_a_save(
			Settings.SAVE_PATH, "game", "absent_game_option", 7.0,
			func() -> void: settings.call("save")
		),
		"Saving settings must keep an option key this build does not register."
	)
	_expect(
		_survives_a_save(
			achievements_path, "unlocked", "absent_game_achievement", "1970-01-01",
			func() -> void: achievements.call("_save_state")
		),
		"Saving achievements must keep an unlock this build does not register."
	)
	_expect(
		_survives_a_save(
			achievements_path, progression_section, "absent_game_progress", true,
			func() -> void: achievements.call("_save_state")
		),
		"Saving achievements must keep a progression flag this build does not register."
	)

	_restore_file(Settings.SAVE_PATH, settings_backup)
	_restore_file(achievements_path, achievements_backup)


func _constant(node: Node, name: String, fallback: String) -> String:
	var map: Dictionary = node.get_script().get_script_constant_map()
	return str(map.get(name, fallback))


## Writes [param value] straight into the stored file, asks the autoload to
## save over it, and reports whether the value is still there.
func _survives_a_save(
	path: String, section: String, key: String, value: Variant, save: Callable
) -> bool:
	var config := ConfigFile.new()
	config.load(path)
	config.set_value(section, key, value)
	if config.save(path) != OK:
		_failures.append("Could not seed %s for the save-merge check." % path)
		return false

	save.call()

	var reloaded := ConfigFile.new()
	if reloaded.load(path) != OK:
		return false
	if not reloaded.has_section_key(section, key):
		return false
	return reloaded.get_value(section, key) == value


func _read_file(path: String) -> PackedByteArray:
	if not FileAccess.file_exists(path):
		return PackedByteArray()
	return FileAccess.get_file_as_bytes(path)


func _restore_file(path: String, contents: PackedByteArray) -> void:
	if contents.is_empty():
		DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
		return
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		_failures.append("Could not restore %s after the save-merge check." % path)
		return
	file.store_buffer(contents)
	file.close()


func _catalog_ids() -> PackedStringArray:
	var ids := PackedStringArray()
	for manifest in GameCatalog.all():
		ids.append(manifest.id)
	return ids


## Every intro a game declares must actually open: load, reach `_ready` and
## point at a scene that exists. The timeline itself belongs to the game's own
## test — this only guards the contract the framework relies on.
func _test_declared_intros(collection: PackedStringArray) -> void:
	_expect(
		collection.size() < 2 or GameCatalog.intro_scene_path(FRAMEWORK_INTRO) == FRAMEWORK_INTRO,
		"A collection build has no game selected yet, so it must use the framework intro."
	)

	for id in collection:
		var manifest := GameCatalog.get_manifest(id)
		if manifest == null or manifest.intro_scene_path.is_empty():
			continue
		var packed := load(manifest.intro_scene_path) as PackedScene
		if packed == null:
			_failures.append("'%s' declares an intro that will not load." % id)
			continue

		var intro := packed.instantiate()
		get_root().add_child(intro)
		await process_frame
		await process_frame
		_expect(
			ResourceLoader.exists(str(intro.get("next_scene"))),
			"The '%s' intro must hand over to a scene that exists." % id
		)
		_expect(
			intro.has_method("_on_skip_pressed"),
			"The '%s' intro must be skippable." % id
		)
		intro.queue_free()
		await process_frame


## Every theme a game declares must be usable: a logo that loads, and colours
## that actually reach the shared theme. The studio default is checked against
## the values `background.tscn` and `main_menu.tscn` are authored with, so a
## collection build cannot drift away from how it looks today.
func _test_declared_themes(collection: PackedStringArray) -> void:
	var studio := GameTheme.studio_default()
	_expect(
		collection.size() < 2 or GameCatalog.theme().accent == studio.accent,
		"A collection build has no single game to look like, so it wears the studio's."
	)
	_expect(
		ResourceLoader.exists(studio.logo_texture_path)
		and studio.logo_texture() != null,
		"The studio logo must load: every unthemed build shows it."
	)

	var background := load(BACKGROUND) as PackedScene
	if background != null:
		var node := background.instantiate() as ColorRect
		var mat := node.material as ShaderMaterial
		_expect(
			mat != null
			and _same_color(mat.get_shader_parameter("top_color"), studio.background_top)
			and _same_color(
				mat.get_shader_parameter("bottom_color"), studio.background_bottom
			)
			and _same_color(mat.get_shader_parameter("glow_color"), studio.accent),
			"GameTheme.studio_default must match the colours background.tscn is authored with."
		)
		node.free()

	for id in collection:
		var manifest := GameCatalog.get_manifest(id)
		if manifest == null or manifest.theme == null:
			continue
		_expect(
			manifest.theme.logo_texture() != null,
			"The '%s' theme declares a logo that will not load." % id
		)
		if not GameCatalog.restrict_to(id):
			continue
		# Restricting rebuilds the catalog, so ask it again rather than
		# comparing against the manifest built before the pin.
		var pinned := GameCatalog.current()
		_expect(
			pinned != null
			and pinned.theme != null
			and GameCatalog.theme() == pinned.theme,
			"A standalone '%s' build must wear that game's theme." % id
		)
		GameCatalog.clear_restriction()

	_test_restyling(studio)


## The accent swap: the shared theme comes back wearing the game's colours,
## alpha intact, and the project's own copy is left alone for the next build.
func _test_restyling(studio: GameTheme) -> void:
	var base := Theme.new()
	base.set_color("font_color", "Button", Color(studio.accent, 0.5))
	var box := StyleBoxFlat.new()
	box.border_color = studio.accent
	box.bg_color = Color("112233")
	base.set_stylebox("focus", "Button", box)

	var game := GameTheme.new()
	game.accent = Color("ffd34e")
	var restyled := game.restyle(base)

	_expect(restyled != base, "Restyling must not hand back the theme it was given.")
	var swapped := restyled.get_color("font_color", "Button")
	_expect(
		swapped.r == game.accent.r and is_equal_approx(swapped.a, 0.5),
		"A restyled colour takes the game's accent and keeps its own alpha."
	)
	var swapped_box := restyled.get_stylebox("focus", "Button") as StyleBoxFlat
	_expect(
		swapped_box != null
		and _same_color(swapped_box.border_color, game.accent)
		and _same_color(swapped_box.bg_color, Color("112233")),
		"A restyled stylebox swaps the accent and leaves every other colour alone."
	)
	_expect(
		_same_color(base.get_color("font_color", "Button"), studio.accent)
		and _same_color(box.border_color, studio.accent),
		"Restyling must not touch the project theme other builds still use."
	)
	_expect(
		studio.restyle(base) == base,
		"A theme that keeps the studio accent needs no copy of the shared theme."
	)

	_test_tree_restyling(studio)


## The HUD and the credits roll colour themselves with per-node overrides and
## scene-local styleboxes, which no [Theme] can reach, so a game's look has to
## be painted onto the tree as well.
func _test_tree_restyling(studio: GameTheme) -> void:
	var game := GameTheme.new()
	game.accent = Color("ffd34e")
	game.light = Color("ffe3a8")

	var root := Control.new()
	var label := Label.new()
	label.add_theme_color_override("font_color", Color(studio.accent, 0.4))
	var plain := Label.new()
	var player_one := Label.new()
	player_one.add_theme_color_override("font_color", Color("4da3ff"))
	var rule := ColorRect.new()
	rule.color = studio.accent
	var panel := Panel.new()
	var box := StyleBoxFlat.new()
	box.bg_color = studio.light
	panel.add_theme_stylebox_override("panel", box)
	for child in [label, plain, player_one, rule, panel]:
		root.add_child(child)

	game.restyle_tree(root)

	var painted := label.get_theme_color("font_color")
	_expect(
		_same_color(painted, game.accent) and is_equal_approx(painted.a, 0.4),
		"A baked override takes the game's accent and keeps its own alpha."
	)
	_expect(
		_same_color(rule.color, game.accent),
		"A ColorRect painted with the studio accent follows the game's theme."
	)
	var painted_box := panel.get_theme_stylebox("panel") as StyleBoxFlat
	_expect(
		painted_box != null and _same_color(painted_box.bg_color, game.light),
		"A scene-local stylebox is repainted too."
	)
	_expect(
		_same_color(box.bg_color, studio.light),
		"Repainting a tree must not edit the stylebox resource it was handed."
	)
	_expect(
		_same_color(player_one.get_theme_color("font_color"), Color("4da3ff")),
		"Repainting a tree leaves the player colours alone."
	)
	_expect(
		not plain.has_theme_color_override("font_color"),
		"Repainting a tree must not invent overrides on nodes that had none."
	)

	var untouched := ColorRect.new()
	untouched.color = studio.accent
	studio.restyle_tree(untouched)
	_expect(
		_same_color(untouched.color, studio.accent),
		"A theme that keeps the studio accent repaints nothing."
	)

	untouched.free()
	root.free()


## Colours here come from `.tres` files, where they are written as rounded
## decimals, so they never match an in-code literal bit for bit.
func _same_color(a: Color, b: Color) -> bool:
	return (
		is_equal_approx(a.r, b.r)
		and is_equal_approx(a.g, b.g)
		and is_equal_approx(a.b, b.b)
	)


func _expect(condition: bool, message: String) -> void:	if not condition:
		_failures.append(message)


func _finish() -> void:
	GameCatalog.clear_restriction()
	if _failures.is_empty():
		print("Single-game build tests passed.")
		quit(0)
		return
	for failure in _failures:
		printerr(failure)
	quit(1)
