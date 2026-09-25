extends SceneTree

## The game picker: the one screen behind the title screen's Play button in any
## build with more than one game to offer.
##
## Every available game stands in a console rack as a cartridge. The one lifted
## out of the rack is the game Play starts; browsing slides the rack along, and
## choosing seats the cartridge before handing over to [Router].
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
const REDUCED_MOTION_KEY := "accessibility/reduced_motion"
## Long enough for a cartridge brought forward to start its clip.
const PREVIEW_WAIT := GameCard.PREVIEW_DELAY + 0.15
## Physical pixels; the smallest target a thumb can reliably hit.
const MIN_TOUCH_TARGET := 44.0
## Windows every layout must survive, from a portrait phone to an ultrawide.
const WINDOWS := {
	"desktop": Vector2i(1280, 720),
	"short desktop": Vector2i(1280, 600),
	"portrait phone": Vector2i(390, 844),
	"landscape phone": Vector2i(844, 390),
	"tablet": Vector2i(768, 1024),
	"ultrawide": Vector2i(2560, 1080),
}
## Where the details belong: beside the rack only on a short landscape screen,
## where stacking them would leave the cartridges too small to read.
const SIDE_LAYOUT_WINDOWS := ["landscape phone"]

var _failures := PackedStringArray()
var _settings: Node
var _router: Node
var _routes := PackedStringArray()


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	_settings = get_root().get_node_or_null("Settings")
	_router = get_root().get_node_or_null("Router")
	if _settings == null or _router == null:
		_failures.append("The Settings and Router autoloads are required.")
		await _finish()
		return
	if not GameCatalog.offers_a_choice():
		_failures.append(
			"Run this test against the collection (`-- --game=all`): a build with "
			+ "one game never opens the picker."
		)
		await _finish()
		return

	var original_reduced_motion: bool = _settings.call("get_value", REDUCED_MOTION_KEY)
	var original_selection := GameCatalog.current_id()
	var original_window := get_root().size
	# A headless window opens 64 pixels square, which is nobody's screen.
	await _resize(WINDOWS["desktop"])
	_set_reduced_motion(false)
	_router.connect("scene_changed", _on_scene_changed)

	await _test_main_menu_has_one_game_button()
	await _test_cartridge_per_available_game()
	await _test_opens_on_the_selected_game()
	await _test_only_the_cartridge_in_hand_previews()
	await _test_reduced_motion_parks_previews()
	await _test_browsing_with_keys_and_arrows()
	await _test_pressing_a_standing_cartridge_brings_it_forward()
	await _test_dragging_and_the_wheel()
	await _test_layouts()
	await _test_progression_rebuild()
	await _test_back_targets()
	# These hand the round to [Router], which replaces the running scene.
	await _test_choosing_seats_the_cartridge()
	await _test_reduced_motion_launch()
	await _test_reduced_motion_mid_seat()

	GameCatalog.select(original_selection)
	_set_reduced_motion(original_reduced_motion)
	get_root().size = original_window
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


## One cartridge per available game, in catalog order, each dressed and labelled
## from that game's own manifest. Locked-and-hidden games stay out, exactly as
## they did when the title screen listed them.
func _test_cartridge_per_available_game() -> void:
	var screen := await _open(GAME_SELECT)
	if screen == null:
		return
	var games := GameCatalog.available()
	var cards := _cards(screen)
	_expect(
		cards.size() == games.size(),
		"The rack must hold %d cartridges, not %d." % [games.size(), cards.size()]
	)
	_expect(
		cards.size() > 1, "This test needs more than one available game to mean anything."
	)
	var session := get_root().get_node_or_null("GameSession")
	var multiplayer_available := session == null or bool(session.call("multiplayer_available"))
	var track := screen.get_node("%Track")
	var current := int(screen.get("_current"))

	for index in mini(cards.size(), games.size()):
		var manifest: GameManifest = games[index]
		var card: Button = cards[index]
		_expect(
			card.call("game_id") == manifest.id,
			"Cartridge %d must be '%s', in catalog order." % [index, manifest.id]
		)
		_expect(
			card.get_parent() == track,
			"The '%s' cartridge must stand in the rack's track." % manifest.id
		)
		_expect(
			card.call("game_title") == manifest.title
			and card.call("game_tagline") == manifest.tagline,
			"The '%s' cartridge must carry that game's own name and tagline." % manifest.id
		)
		_expect(
			not card.disabled and card.accessibility_name == manifest.title,
			(
				"The '%s' cartridge must be usable and name itself, since a rack of "
				% manifest.id
			)
			+ "unnamed buttons is useless read aloud."
		)
		_expect(
			card.accessibility_description.contains(
				"Cartridge %d of %d." % [index + 1, cards.size()]
			),
			"The '%s' cartridge must say where it stands in the rack." % manifest.id
		)
		var modes: Dictionary = GameCard.describe_modes(manifest, multiplayer_available)
		_expect(
			card.call("badges") == modes["badges"],
			"The '%s' mode chips must come from its manifest." % manifest.id
		)
		var theme := manifest.theme if manifest.theme != null else GameTheme.studio_default()
		_expect(
			card.call("accent") == theme.accent,
			"The '%s' cartridge must wear its own game's accent." % manifest.id
		)
		_expect(
			(card.focus_mode == Control.FOCUS_ALL) == (index == current),
			(
				"Only the cartridge in hand may take focus, so Tab never wades "
				+ "through the rack ('%s')."
			) % manifest.id
		)

		var has_clip := (
			not manifest.tutorial_video_path.is_empty()
			and ResourceLoader.exists(manifest.tutorial_video_path)
		)
		_expect(
			bool(card.call("has_preview_clip")) == has_clip,
			"The '%s' cartridge must carry that game's own clip, and only that." % manifest.id
		)
		var poster := card.call("poster") as Texture2D
		if not manifest.tutorial_poster_path.is_empty():
			_expect(
				poster != null and poster.resource_path == manifest.tutorial_poster_path,
				"The '%s' label must show that game's poster frame." % manifest.id
			)
		_expect(
			has_clip or poster != null
			or (card.get_node("%Placeholder") as Label).visible,
			(
				"A '%s' cartridge with no media must say the preview is missing "
				% manifest.id
			)
			+ "rather than show an empty window."
		)
	var shelf := screen.get_node("%ShelfFront")
	_expect(
		(shelf.get("slot_accents") as PackedColorArray).size() == cards.size(),
		"The rack must light one slot per cartridge."
	)
	await _close(screen)


## The rack opens on the game already chosen, so backing out of setup lands on
## the cartridge the player just left, with its details and focus.
func _test_opens_on_the_selected_game() -> void:
	var games := GameCatalog.available()
	var index := mini(2, games.size() - 1)
	GameCatalog.select(games[index].id)
	var screen := await _open(GAME_SELECT)
	if screen == null:
		return
	var cards := _cards(screen)
	var card: Button = cards[index]
	_expect(
		int(screen.get("_current")) == index,
		"The rack must open on the selected game, '%s'." % games[index].id
	)
	_expect(
		is_equal_approx(float(screen.get("_scroll")), float(index)),
		"Opening must not slide the rack in from its first cartridge."
	)
	_expect(
		screen.get_viewport().gui_get_focus_owner() == card,
		"The cartridge in hand must take focus when the screen opens, so the arrow "
		+ "keys browse at once."
	)
	_expect(
		(screen.get_node("%GameTitle") as Label).text == games[index].title
		and (screen.get_node("%GameTagline") as Label).text == games[index].tagline
		and (screen.get_node("%GameModes") as Label).text == card.call("mode_summary"),
		"The details must describe the cartridge in hand."
	)
	var play := screen.get_node("%PlayButton") as Button
	_expect(
		play.accessibility_description.contains(games[index].title),
		"Play must say which game it starts."
	)
	await _close(screen)
	GameCatalog.select(games[0].id)


## Only the cartridge in hand opens its label window, and only it decodes a clip,
## so a growing catalog never means a growing number of video decoders.
func _test_only_the_cartridge_in_hand_previews() -> void:
	var screen := await _open(GAME_SELECT)
	if screen == null:
		return
	var cards := _cards(screen)
	var with_clip := _first_with_clip(cards)
	_expect(with_clip >= 0, "At least one game must declare a tutorial clip.")
	if with_clip < 0:
		await _close(screen)
		return
	screen.call("_select_index", with_clip)
	await create_timer(PREVIEW_WAIT).timeout
	var card: Button = cards[with_clip]
	_expect(
		bool(card.call("is_previewing")),
		"The cartridge in hand must play its clip in its label window."
	)
	_expect(
		_previewing(cards) == 1,
		"Only the cartridge in hand may play, not %d of them." % _previewing(cards)
	)
	_expect(
		_open_streams(cards) == 1,
		"A standing cartridge must not even hold a stream open."
	)
	var player := card.call("preview_player") as VideoStreamPlayer
	_expect(
		player.loop and player.volume_db < -40.0,
		"A label-window clip must loop and stay silent."
	)
	var badge := card.get_node("%Badge") as Label
	_expect(
		badge.visible and badge.text == "PREVIEW",
		"The label must say its window shows a preview."
	)

	var next := with_clip + 1 if with_clip + 1 < cards.size() else with_clip - 1
	screen.call("_select_index", next)
	_expect(
		not bool(card.call("is_previewing")) and _open_streams(cards) == 0,
		"Browsing past a cartridge must stop its clip at once."
	)
	_expect(
		_previewing(cards) == 0,
		"A cartridge just brought forward must wait before it starts, so skimming "
		+ "the rack never spins up a decoder per game."
	)
	await create_timer(PREVIEW_WAIT).timeout
	var expected := 1 if bool(cards[next].call("has_preview_clip")) else 0
	_expect(
		_previewing(cards) == expected,
		"Once the rack settles, the new cartridge in hand must play its own clip."
	)
	await _close(screen)


## A looping clip and a bobbing cartridge are ambient, decorative motion, which
## is exactly what the accessibility setting exists to stop.
func _test_reduced_motion_parks_previews() -> void:
	_set_reduced_motion(true)
	var screen := await _open(GAME_SELECT)
	if screen == null:
		_set_reduced_motion(false)
		return
	var cards := _cards(screen)
	var with_clip := _first_with_clip(cards)
	if with_clip >= 0:
		screen.call("_select_index", with_clip)
	await create_timer(PREVIEW_WAIT).timeout
	_expect(_previewing(cards) == 0, "Reduced motion must park the label window.")
	for card in cards:
		_expect(
			not (card.call("preview_player") as VideoStreamPlayer).visible,
			"A parked label must show the poster, not a frozen video surface."
		)
	_expect(
		not screen.is_processing(),
		"Reduced motion must stop the rack's idle motion, not merely slow it."
	)
	_expect(
		is_equal_approx(float(screen.get("_scroll")), float(screen.get("_current"))),
		"Reduced motion must move the rack in one step rather than slide it."
	)

	# The setting has to reach a screen that is already open.
	_set_reduced_motion(false)
	await process_frame
	_expect(screen.is_processing(), "Turning reduced motion off must restore the rack.")
	if with_clip >= 0:
		_expect(
			bool(cards[with_clip].call("is_previewing")),
			"Turning reduced motion off must start the clip in hand without a reload."
		)
	await _close(screen)


## The rack browses one game at a time from the keyboard, the pad and the
## arrow buttons alike, and stops at either end instead of wrapping.
func _test_browsing_with_keys_and_arrows() -> void:
	var games := GameCatalog.available()
	GameCatalog.select(games[0].id)
	var screen := await _open(GAME_SELECT)
	if screen == null:
		return
	var cards := _cards(screen)
	var last := cards.size() - 1
	var previous := screen.get_node("%PrevButton") as Button
	var next := screen.get_node("%NextButton") as Button
	var play := screen.get_node("%PlayButton") as Button
	var back := screen.get_node("%BackButton") as Button
	var title := screen.get_node("%GameTitle") as Label
	_expect(
		previous.disabled and not next.disabled,
		"At the start of the rack only the next arrow may be pressed."
	)
	_expect(
		not previous.accessibility_name.is_empty() and not next.accessibility_name.is_empty(),
		"The icon-only arrows must still name themselves."
	)
	_expect(
		not bool(screen.call("_browse", -1)),
		"Browsing before the first cartridge must stop, not wrap."
	)

	_press_action("ui_right")
	_expect(int(screen.get("_current")) == 1, "Right must bring the next cartridge forward.")
	_expect(
		screen.get_viewport().gui_get_focus_owner() == cards[1]
		and (cards[0] as Control).focus_mode == Control.FOCUS_NONE,
		"Focus must rove with the cartridge in hand."
	)
	_expect(title.text == games[1].title, "The details must follow the cartridge in hand.")
	_expect(
		GameCatalog.current_id() == games[0].id,
		"Browsing must not select a game; only choosing one does."
	)
	_press_action("ui_left")
	_expect(int(screen.get("_current")) == 0, "Left must bring the previous cartridge back.")

	next.emit_signal("pressed")
	_expect(int(screen.get("_current")) == 1, "The next arrow must browse forward.")
	previous.emit_signal("pressed")
	_expect(int(screen.get("_current")) == 0, "The previous arrow must browse back.")

	_press_action("ui_end")
	_expect(int(screen.get("_current")) == last, "End must jump to the last cartridge.")
	_expect(
		next.disabled and not previous.disabled,
		"At the end of the rack only the previous arrow may be pressed."
	)
	_expect(
		not bool(screen.call("_browse", 1)),
		"Browsing past the last cartridge must stop, not wrap."
	)
	_press_action("ui_home")
	_expect(int(screen.get("_current")) == 0, "Home must jump to the first cartridge.")

	# Up and down leave the rack for the header and the details.
	_press_action("ui_down")
	_expect(play.has_focus(), "Down from the cartridge in hand must reach Play.")
	# A pad player can compare games without leaving the button that starts one.
	_press_action("ui_right")
	_expect(
		int(screen.get("_current")) == 1 and play.has_focus(),
		"Right on Play must browse the rack and keep Play focused."
	)
	_expect(
		play.accessibility_description.contains(games[1].title),
		"Play must name the game it would start as the rack moves."
	)
	_press_action("ui_up")
	_expect(
		screen.get_viewport().gui_get_focus_owner() == cards[1],
		"Up from Play must return to the cartridge in hand."
	)
	_press_action("ui_up")
	_expect(back.has_focus(), "Up from the cartridge in hand must reach Back.")
	_press_action("ui_down")
	_expect(
		screen.get_viewport().gui_get_focus_owner() == cards[1],
		"Down from Back must return to the cartridge in hand."
	)
	await _close(screen)


## Pointing at a cartridge on the rack brings it forward. Only the cartridge in
## hand starts a game, so a stray tap can never launch the wrong one.
func _test_pressing_a_standing_cartridge_brings_it_forward() -> void:
	var games := GameCatalog.available()
	GameCatalog.select(games[0].id)
	var screen := await _open(GAME_SELECT)
	if screen == null:
		return
	var cards := _cards(screen)
	var standing: Button = cards[1]
	standing.emit_signal("pressed")
	_expect(
		int(screen.get("_current")) == 1,
		"Pressing a cartridge on the rack must bring it forward."
	)
	_expect(
		not bool(screen.get("_launching")) and GameCatalog.current_id() == games[0].id,
		"Pressing a cartridge on the rack must not start it."
	)
	_expect(standing.has_focus(), "The cartridge brought forward must take focus.")
	await _close(screen)


## The rack follows the pointer: a sideways drag slides it and settles on the
## nearest cartridge, an upright one is left to the scroll box, and a wheel
## notch browses one game.
func _test_dragging_and_the_wheel() -> void:
	var games := GameCatalog.available()
	GameCatalog.select(games[0].id)
	var screen := await _open(GAME_SELECT)
	if screen == null:
		return
	var cards := _cards(screen)
	if cards.size() < 4:
		await _close(screen)
		return
	var track := screen.get_node("%Track") as Control
	var width := float(screen.get("_card_width"))
	var pitch := width * (
		0.5 + float(_constant(screen, "NEIGHBOUR_GAP"))
		+ float(_constant(screen, "SIDE_SCALE")) * 0.5
	)
	var start := track.get_global_rect().get_center()

	_pointer_button(start, MOUSE_BUTTON_LEFT, true)
	for step in 8:
		_pointer_motion(start - Vector2(pitch * 2.0 * float(step + 1) / 8.0, 0.0), true)
		await process_frame
	_expect(bool(screen.get("_dragging")), "A sideways drag must take hold of the rack.")
	# Held still before letting go, so no momentum carries it further.
	await create_timer(0.15).timeout
	_pointer_button(start - Vector2(pitch * 2.0, 0.0), MOUSE_BUTTON_LEFT, false)
	await process_frame
	_expect(
		int(screen.get("_current")) == 2,
		"Dragging two cartridges' width must settle on the second, not %d."
		% int(screen.get("_current"))
	)
	_expect(
		not bool(screen.get("_dragging")) and not bool(screen.get("_launching")),
		"Letting go of a drag must not press the cartridge under the pointer."
	)
	await process_frame
	_expect(
		not bool(screen.get("_suppress_press")),
		"Only the release that ends a drag may be ignored, not the next press."
	)

	_pointer_button(start, MOUSE_BUTTON_LEFT, true)
	_pointer_motion(start + Vector2(0.0, 60.0), true)
	_pointer_button(start + Vector2(0.0, 60.0), MOUSE_BUTTON_LEFT, false)
	await process_frame
	_expect(
		int(screen.get("_current")) == 2 and not bool(screen.get("_dragging")),
		"An upright drag belongs to the scroll box and must not slide the rack."
	)
	_expect(
		not bool(screen.get("_launching")),
		"A gesture that ends on the cartridge in hand must not start its game."
	)
	await process_frame

	_pointer_button(start, MOUSE_BUTTON_WHEEL_DOWN, true)
	_pointer_button(start, MOUSE_BUTTON_WHEEL_DOWN, false)
	_expect(int(screen.get("_current")) == 3, "A wheel notch must browse one game on.")
	_pointer_button(start, MOUSE_BUTTON_WHEEL_DOWN, true)
	_expect(
		int(screen.get("_current")) == 3,
		"A spinning wheel must not skip through the rack faster than it can be read."
	)
	await create_timer(0.2).timeout
	_pointer_button(start, MOUSE_BUTTON_WHEEL_UP, true)
	_expect(int(screen.get("_current")) == 2, "Wheeling back must browse one game back.")
	await _close(screen)


## Every layout keeps the cartridge in hand, its details and Play on screen at
## once, from a portrait phone to an ultrawide, and the rack runs off the edge.
func _test_layouts() -> void:
	var screen := await _open(GAME_SELECT)
	if screen == null:
		return
	var scroll := screen.get_node("%Scroll") as ScrollContainer
	var body := screen.get_node("%Body") as Control
	var stage := screen.get_node("%Stage") as Control
	var play := screen.get_node("%PlayButton") as Button
	var back := screen.get_node("%BackButton") as Button
	var title := screen.get_node("%GameTitle") as Label
	for window_name: String in WINDOWS:
		await _resize(WINDOWS[window_name])
		var area := get_root().get_visible_rect().size
		var view := Rect2(Vector2.ZERO, area).grow(1.0)
		var physical := float(get_root().size.y) / area.y
		var unit := float(screen.get("_unit"))
		var side_mode := bool(screen.get("_side_mode"))
		_expect(
			side_mode == (window_name in SIDE_LAYOUT_WINDOWS),
			"%s: the details belong %s the rack." % [
				window_name, "beside" if window_name in SIDE_LAYOUT_WINDOWS else "below"
			]
		)
		_expect(
			float(screen.get("_card_width")) >= 200.0 * unit - 0.5,
			"%s: the cartridge in hand is too narrow to read." % window_name
		)
		_expect(
			body.size.y <= scroll.size.y + 1.0,
			"%s: the rack and details must fit without scrolling (%.0f > %.0f)." % [
				window_name, body.size.y, scroll.size.y
			]
		)
		var stage_rect := stage.get_global_rect()
		_expect(
			stage_rect.end.x >= area.x - 1.0 and (side_mode or stage_rect.position.x <= 1.0),
			"%s: the rack must run off the edge of the screen." % window_name
		)
		var card := _cards(screen)[int(screen.get("_current"))] as Control
		var card_rect := card.get_global_rect()
		_expect(
			view.encloses(card_rect) and scroll.get_global_rect().grow(1.0).encloses(card_rect),
			"%s: the cartridge in hand must be wholly on screen." % window_name
		)
		for arrow_name: String in ["%PrevButton", "%NextButton"]:
			var arrow := screen.get_node(arrow_name) as Control
			var arrow_rect := arrow.get_global_rect()
			_expect(
				view.encloses(arrow_rect) and not arrow_rect.intersects(card_rect),
				"%s: %s must sit on screen beside the cartridge in hand." % [
					window_name, arrow_name
				]
			)
			_expect(
				arrow_rect.size.y * physical >= MIN_TOUCH_TARGET - 0.5,
				"%s: %s is too small to tap." % [window_name, arrow_name]
			)
		for button: Button in [play, back]:
			_expect(
				view.encloses(button.get_global_rect()),
				"%s: %s must be on screen." % [window_name, button.name]
			)
			_expect(
				button.size.y * physical >= MIN_TOUCH_TARGET - 0.5,
				"%s: %s is too small to tap (%.0f px)." % [
					window_name, button.name, button.size.y * physical
				]
			)
		_expect(
			view.encloses(title.get_global_rect()),
			"%s: the game's name must be on screen." % window_name
		)
	await _resize(WINDOWS["desktop"])
	await _close(screen)


## An unlock can add a game while the picker is open, so progress rebuilds the
## rack — without losing the cartridge in hand or its focus.
func _test_progression_rebuild() -> void:
	var games := GameCatalog.available()
	GameCatalog.select(games[0].id)
	var screen := await _open(GAME_SELECT)
	if screen == null:
		return
	var index := mini(2, games.size() - 1)
	screen.call("_select_index", index, true)
	var before := _cards(screen)
	(before[index] as Control).grab_focus()
	screen.call("_on_progression_changed", "game_select_test_probe", true)
	await process_frame
	var after := _cards(screen)
	_expect(
		after.size() == before.size() and after[0] != before[0],
		"Progress must rebuild the rack from the catalog."
	)
	_expect(
		int(screen.get("_current")) == index
		and str(after[index].call("game_id")) == games[index].id,
		"Rebuilding the rack must keep the cartridge in hand."
	)
	_expect(
		(after[index] as Control).has_focus(),
		"Rebuilding the rack must keep focus on the cartridge in hand."
	)
	await process_frame
	var freed := true
	for card in before:
		freed = freed and not is_instance_valid(card)
	_expect(freed, "The rack's old cartridges must be freed, not left behind.")
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


## Choosing the cartridge in hand selects its game, latches the screen, stops
## every clip and seats the cartridge in the slot before the game starts once.
func _test_choosing_seats_the_cartridge() -> void:
	var games := GameCatalog.available()
	GameCatalog.select(games[0].id)
	var screen := await _open(GAME_SELECT)
	if screen == null:
		return
	var cards := _cards(screen)
	var last := cards.size() - 1
	screen.call("_select_index", last, true)
	await create_timer(PREVIEW_WAIT).timeout
	var target: Button = cards[last]
	var wanted := str(target.call("game_id"))
	var lifted := target.position.y
	_routes.clear()

	target.emit_signal("pressed")
	target.emit_signal("pressed")
	_expect(
		GameCatalog.current_id() == wanted,
		"Choosing a cartridge must make its game the selected one."
	)
	_expect(
		bool(screen.get("_launching")),
		"Choosing must latch the screen so a second press cannot race it."
	)
	var closed := true
	for card in cards:
		closed = closed and bool(card.call("is_closed")) and not bool(card.call("is_previewing"))
	_expect(closed, "Choosing must stop every clip and close every cartridge to input.")
	_expect(
		(screen.get_node("%PlayButton") as Button).disabled
		and (screen.get_node("%BackButton") as Button).disabled,
		"Play and Back must lock while the cartridge seats."
	)
	await create_timer(0.35).timeout
	_expect(
		float(screen.get("_seat")) > 0.2 and target.position.y > lifted + 1.0,
		"The chosen cartridge must travel down into the slot."
	)
	_expect(_routes.is_empty(), "The game must wait for its cartridge to seat.")
	await _await_route()
	_expect(
		_routes.size() == 1,
		"Choosing must start the game exactly once, not %d times." % _routes.size()
	)
	_expect(
		_routes.size() > 0 and _routes[0] in _start_routes(),
		"Choosing must go through the shared start route."
	)
	_expect(
		float(screen.get_node("%ShelfFront").get("power")) > 0.99,
		"The rack's lights must come up once the cartridge is seated."
	)
	await _close(screen)
	await _clear_routed_scene()


## Reduced motion swaps the seating for an opacity-only fade.
func _test_reduced_motion_launch() -> void:
	_set_reduced_motion(true)
	var games := GameCatalog.available()
	GameCatalog.select(games[0].id)
	var screen := await _open(GAME_SELECT)
	if screen == null:
		_set_reduced_motion(false)
		return
	var cards := _cards(screen)
	screen.call("_select_index", 1)
	var target := cards[1] as Control
	var resting := target.position
	_routes.clear()
	(screen.get_node("%PlayButton") as Button).emit_signal("pressed")
	_expect(
		GameCatalog.current_id() == games[1].id,
		"Play must start the cartridge in hand."
	)
	await create_timer(0.08).timeout
	_expect(
		target.position.is_equal_approx(resting) and float(screen.get("_seat")) == 0.0,
		"Reduced motion must not move the cartridge into the slot."
	)
	_expect(
		(screen.get_node("%Stage") as Control).modulate.a < 1.0,
		"Reduced motion must fade the rack out instead."
	)
	await _await_route()
	_expect(
		_routes.size() == 1,
		"A reduced-motion launch must start the game exactly once, not %d times."
		% _routes.size()
	)
	await _close(screen)
	await _clear_routed_scene()
	_set_reduced_motion(false)


## Turning reduced motion on while a cartridge seats must still start the game:
## killing a tween does not finish it, so a naive stop would trap the player.
func _test_reduced_motion_mid_seat() -> void:
	_set_reduced_motion(false)
	var games := GameCatalog.available()
	GameCatalog.select(games[0].id)
	var screen := await _open(GAME_SELECT)
	if screen == null:
		return
	_routes.clear()
	(_cards(screen)[0] as Button).emit_signal("pressed")
	await create_timer(0.25).timeout
	_set_reduced_motion(true)
	await _await_route()
	_expect(
		_routes.size() == 1,
		"A launch interrupted by reduced motion must start the game exactly once, "
		+ "not %d times." % _routes.size()
	)
	await _close(screen)
	await _clear_routed_scene()
	_set_reduced_motion(false)


# --- Helpers ----------------------------------------------------------------


func _cards(screen: Node) -> Array:
	# A copy: the screen clears and refills its own array when it rebuilds.
	return Array(screen.get("_cards")).duplicate()


func _constant(screen: Node, constant: String) -> Variant:
	return screen.get_script().get_script_constant_map().get(constant)


func _first_with_clip(cards: Array) -> int:
	for index in cards.size():
		if bool(cards[index].call("has_preview_clip")):
			return index
	return -1


func _previewing(cards: Array) -> int:
	var count := 0
	for card in cards:
		if bool(card.call("is_previewing")):
			count += 1
	return count


func _open_streams(cards: Array) -> int:
	var count := 0
	for card in cards:
		if (card.call("preview_player") as VideoStreamPlayer).stream != null:
			count += 1
	return count


func _start_routes() -> PackedStringArray:
	return PackedStringArray([
		MODE_SELECT, INSTRUCTIONS, GameCatalog.current_gameplay_scene_path()
	])


## Writes straight into the settings dictionary so the test never persists a
## value to the developer's user://settings.cfg.
func _set_reduced_motion(enabled: bool) -> void:
	var values: Dictionary = (_settings.get("_values") as Dictionary).duplicate()
	values[REDUCED_MOTION_KEY] = enabled
	_settings.set("_values", values)
	_settings.emit_signal("changed", REDUCED_MOTION_KEY, enabled)


func _resize(window_size: Vector2i) -> void:
	get_root().size = window_size
	for frame in 3:
		await process_frame


func _press_action(action: String) -> void:
	for pressed in [true, false]:
		var event := InputEventAction.new()
		event.action = action
		event.pressed = pressed
		get_root().push_input(event)


## Pointer events go through [Input] so that the screen's
## [method CanvasItem.get_global_mouse_position] sees them, as it would a mouse.
func _pointer_button(at: Vector2, button: MouseButton, pressed: bool) -> void:
	var event := InputEventMouseButton.new()
	event.button_index = button
	event.pressed = pressed
	if button == MOUSE_BUTTON_LEFT and pressed:
		event.button_mask = MOUSE_BUTTON_MASK_LEFT
	_send_pointer(event, at)


func _pointer_motion(at: Vector2, held: bool) -> void:
	var event := InputEventMouseMotion.new()
	event.button_mask = MOUSE_BUTTON_MASK_LEFT if held else 0
	_send_pointer(event, at)


func _send_pointer(event: InputEventMouse, at: Vector2) -> void:
	var window_at := get_root().get_final_transform() * at
	event.position = window_at
	event.global_position = window_at
	Input.parse_input_event(event)
	Input.flush_buffered_events()


func _on_scene_changed(path: String) -> void:
	_routes.append(path)


func _await_route() -> void:
	var deadline := Time.get_ticks_msec() + 4000
	while Time.get_ticks_msec() < deadline:
		if not _routes.is_empty() and not bool(_router.call("is_transitioning")):
			return
		await process_frame
	_failures.append("The picker never handed the game to the Router.")


func _clear_routed_scene() -> void:
	if current_scene != null:
		unload_current_scene()
	await process_frame


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
