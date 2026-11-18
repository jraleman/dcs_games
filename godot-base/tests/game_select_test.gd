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
const ARCADE_SELECT := "res://scenes/menus/arcade_select.tscn"
const Town = preload("res://ui/components/arcade_town.gd")
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

class TownGate:
	extends GameUnlockRule

	var opened := false

	func is_unlocked(_state: Dictionary) -> bool:
		return opened

	func requirement_text(_state: Dictionary) -> String:
		return "Finish the town test challenge."


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

	if not "--arcade-only" in OS.get_cmdline_user_args():
		await _test_main_menu_has_one_game_button()
		await _test_cartridge_per_available_game()
		await _test_cover_and_logo_fallback()
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
	await _test_arcade_catalog_and_gates()
	await _test_arcade_architecture()
	await _test_arcade_controls()
	await _test_arcade_layouts()
	await _test_arcade_launch_and_return()
	await _test_arcade_instructions_return()

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
		var cover := theme.cover_texture()
		_expect(card.get("_cover") == cover,
			"The '%s' cartridge must use its declared cover, independently of its logo."
			% manifest.id)
		if not theme.cover_texture_path.is_empty():
			_expect(cover != null,
				"The '%s' cover declaration must resolve to an imported texture." % manifest.id)
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


## Cover printing must not obscure live preview labels or break a logo-only game.
func _test_cover_and_logo_fallback() -> void:
	var manifest := GameManifest.new()
	manifest.id = "cover_fixture"
	manifest.title = "Cover fixture"
	for candidate in GameCatalog.available():
		if not candidate.tutorial_video_path.is_empty():
			manifest.tutorial_video_path = candidate.tutorial_video_path
			manifest.tutorial_poster_path = candidate.tutorial_poster_path
			break
	manifest.theme = GameTheme.studio_default()
	manifest.theme.cover_texture_path = "res://icon.svg"
	manifest.theme.logo_color = Color("e35a70")
	var card := (load("res://ui/components/game_card.tscn") as PackedScene).instantiate() as GameCard
	get_root().add_child(card)
	card.configure(manifest)
	card.set_reduced_motion(true)
	card.set_current(false, true)
	var band := card.get_node("%Band") as Control
	_expect(card.get("_cover") == load("res://icon.svg") and is_zero_approx(band.modulate.a),
		"A parked cover must replace the separate title band, not be painted over by it.")
	card.set_current(true, true)
	_expect(is_equal_approx(band.modulate.a, 1.0)
		and (card.get_node("%Screen") as Control).visible
		and card.has_preview_clip() and card.poster() != null and not card.is_previewing(),
		"Reduced motion must show the poster and live labels without playing the clip.")
	for path in ["", "res://tests/missing_cover_art.png"]:
		manifest.theme.cover_texture_path = path
		card.configure(manifest)
		card.set_current(false, true)
		_expect(card.get("_cover") == null
			and card.get("_logo") == manifest.theme.logo_texture()
			and card.get("_logo_color") == manifest.theme.logo_color
			and is_equal_approx(band.modulate.a, 1.0),
			"An absent or missing cover must restore the original tinted logo and title band.")
	card.queue_free()
	await process_frame


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

	# A solo-only game with nothing to set up never sees mode select, so the
	# picker is the screen directly behind its instructions. One with a solo
	# setup step (levels, characters or solo choices) goes through mode select,
	# as `Router.start_selected_game()` does, so Back returns there.
	for manifest in GameCatalog.available():
		if manifest.supports_multiplayer:
			continue
		var solo_setup := not (manifest.levels.is_empty() and manifest.characters.is_empty()
			and manifest.solo_setup_choices.is_empty())
		GameCatalog.select(manifest.id)
		session.call("configure_single_player")
		var instructions := await _open(INSTRUCTIONS)
		if instructions == null:
			continue
		if solo_setup:
			_expect(
				str(instructions.get("back_scene")) == MODE_SELECT,
				"'%s' sets up a solo run on mode select, so its instructions return there."
				% manifest.id
			)
		else:
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


# --- Secret arcade town -----------------------------------------------------


func _test_arcade_catalog_and_gates() -> void:
	var manifest := GameCatalog.all()[0]
	var original_rule := manifest.unlock_rule
	var original_hidden := manifest.hidden_until_unlocked
	var gate := TownGate.new()
	manifest.unlock_rule = gate
	manifest.hidden_until_unlocked = true
	var screen := await _open(ARCADE_SELECT)
	if screen == null:
		manifest.unlock_rule = original_rule
		manifest.hidden_until_unlocked = original_hidden
		return
	var town := screen.get_node("%Town")
	var shops: Dictionary = town.get("_shops")
	_expect(shops.size() == GameCatalog.all().size() and shops.has(manifest.id)
		and not GameCatalog.available().has(manifest),
		"Town must include every catalog game, even a hidden, locked storefront.")
	_expect((screen.get_node("%WorldViewport") as SubViewport).own_world_3d,
		"The selector's 3D world must be isolated from games and other menu viewports.")
	town.call("stand_at_game", manifest.id)
	await physics_frame
	var enter := screen.get_node("%EnterButton") as Button
	_expect(enter.disabled and enter.text == "Locked"
		and (screen.get_node("%GameStatus") as Label).text.contains("town test challenge"),
		"A locked door must show its real requirement and refuse entry.")
	_expect((town.get("_locks") as Dictionary)[manifest.id].visible,
		"Locked doors need a shutter, not just a different colour.")
	await _capture_arcade(screen, "town-locked")
	var routes_before := _routes.size()
	var selected_before := GameCatalog.current_id()
	screen.call("_enter_nearby")
	_expect(_routes.size() == routes_before and GameCatalog.current_id() == selected_before
		and not bool(screen.get("_closing")),
		"A locked doorway must never select or launch its game.")
	var before: Vector3 = town.call("walker_position")
	screen.call("_set_directory_open", true)
	var buttons: Dictionary = screen.get("_directory_buttons")
	(buttons[manifest.id] as Button).emit_signal("pressed")
	_expect(str(screen.get("_destination_id")) == manifest.id
		and (town.call("walker_position") as Vector3).is_equal_approx(before)
		and not bool(screen.get("_closing")),
		"A directory choice marks a locked or open door without teleporting or launching.")
	screen.call("_set_directory_open", true)
	_press_action("ui_cancel")
	_expect(not (screen.get_node("%DirectoryOverlay") as Control).visible
		and not bool(screen.get("_closing")),
		"Escape must close the directory before leaving town.")
	gate.opened = true
	get_root().get_node("AchievementManager").emit_signal(
		"progression_changed", "town_test_gate", true
	)
	_expect(not enter.disabled and enter.text == "Enter"
		and not (town.get("_locks") as Dictionary)[manifest.id].visible,
		"A live unlock must open the existing storefront and its action.")
	(town.get("_walker") as Node3D).position = Town.SPAWN
	screen.call("_enter_nearby")
	_expect(not bool(screen.get("_closing")) and _routes.size() == routes_before,
		"Entry must recheck actual proximity rather than trust a stale on-screen prompt.")
	await _close(screen)
	manifest.unlock_rule = original_rule
	manifest.hidden_until_unlocked = original_hidden


func _test_arcade_architecture() -> void:
	var screen := await _open(ARCADE_SELECT)
	if screen == null:
		return
	var town := screen.get_node("%Town")
	var shops: Dictionary = town.get("_shops")
	var silhouettes := {}
	for id: String in shops:
		var shop := shops[id] as Node3D
		var silhouette := AABB()
		var bounds: AABB = (town.get("_shop_bounds") as Dictionary)[id]
		var contains_roof := true
		for child in shop.get_children():
			var instance := child as MeshInstance3D
			if instance == null:
				continue
			silhouette = silhouette.merge(instance.transform * instance.get_aabb())
			var vertices: PackedVector3Array = instance.mesh.surface_get_arrays(0)[
				Mesh.ARRAY_VERTEX]
			for point in vertices:
				var local := instance.transform * point
				if local.y > 1.4:
					contains_roof = contains_roof and bounds.grow(0.01).has_point(
						shop.transform * local)
		var size := silhouette.size * 10
		silhouettes[Vector3i(roundi(size.x), roundi(size.y), roundi(size.z))] = true
		_expect(contains_roof,
			"%s's occlusion volume must contain its actual tall roof and trim." % id)
	_expect(silhouettes.size() >= mini(5, shops.size()),
		"The town needs visibly different 3D building silhouettes, not recoloured boxes.")
	for index in mini(7, GameCatalog.all().size()):
		town.call("stand_at_game", GameCatalog.all()[index].id)
		await _physics_frames(3)
		await _capture_arcade(screen, "town-architecture-%02d" % (index + 1))
	await _close(screen)


func _test_arcade_controls() -> void:
	var screen := await _open(ARCADE_SELECT)
	if screen == null:
		return
	var town := screen.get_node("%Town")
	var walker := town.get("_walker") as CharacterBody3D
	walker.position = Town.SPAWN
	var camera := town.get("_camera") as Camera3D
	var angle := camera.rotation
	_arcade_key(KEY_W, true)
	await _physics_frames(16)
	_arcade_key(KEY_W, false)
	_expect(walker.position.distance_to(Town.SPAWN) > 0.5,
		"WASD must move the actual 3D character, not just a menu cursor.")
	_expect(camera.rotation.is_equal_approx(angle),
		"The isometric camera angle must remain fixed while following.")
	_arcade_key(KEY_W, true)
	_arcade_key(KEY_D, true)
	await _physics_frames(3)
	_expect(walker.velocity.length() <= Town.WALK_SPEED + 0.01,
		"Diagonal keyboard input must not walk faster.")
	screen.call("_notification", Node.NOTIFICATION_APPLICATION_FOCUS_OUT)
	var stopped := walker.position
	await _physics_frames(3)
	_expect(walker.position.is_equal_approx(stopped),
		"Focus loss must release held keys immediately.")
	_arcade_axis(0, JOY_AXIS_LEFT_X, 0.1)
	await _physics_frames(3)
	_expect(walker.position.is_equal_approx(stopped), "Stick drift must stay inside the deadzone.")
	_arcade_axis(0, JOY_AXIS_LEFT_X, 0.85)
	await _physics_frames(12)
	_expect(walker.position.distance_to(stopped) > 0.3,
		"The left stick must move the same walker as the keyboard.")
	screen.call("_on_pad_connection_changed", 0, false)
	stopped = walker.position
	await _physics_frames(3)
	_expect(walker.position.is_equal_approx(stopped),
		"Disconnecting a controller must not leave a stored stick direction.")
	screen.call("_set_touch_mode")
	for frame in 3:
		await process_frame
	var pad := screen.get_node("%WalkPad") as Control
	var press_at := pad.get_global_rect().get_center() + Vector2(pad.size.x * 0.3, 0)
	_arcade_touch(3, press_at, true)
	await _physics_frames(8)
	_expect(walker.position.distance_to(stopped) > 0.2,
		"An owned touch contact must steer the real walker.")
	_arcade_touch(7, Vector2(1, 1), false)
	_expect((town.get("_walk_input") as Vector2).length() > 0.0,
		"Another finger's release must not steal the movement contact.")
	_arcade_touch(3, Vector2(1, 1), false)
	stopped = walker.position
	await _physics_frames(3)
	_expect(walker.position.is_equal_approx(stopped),
		"A movement finger released outside the pad must still stop walking.")
	var directory_button := screen.get_node("%DirectoryButton") as Control
	_arcade_touch(7, directory_button.get_global_rect().get_center(), true)
	_arcade_touch(7, directory_button.get_global_rect().get_center(), false)
	_expect((screen.get_node("%DirectoryOverlay") as Control).visible,
		"A real touch tap must open the directory without mouse emulation.")
	for frame in 3:
		await process_frame
	var scroll := screen.get_node("%DirectoryScroll") as ScrollContainer
	var scroll_before := scroll.scroll_vertical
	var start := scroll.get_global_rect().get_center()
	var travel := Vector2(0, -scroll.size.y * 0.3)
	var destination_before := str(screen.get("_destination_id"))
	_arcade_touch(9, start, true)
	for step in 5:
		_arcade_drag(9, start + travel * (step + 1) / 5.0, travel / 5.0)
		await process_frame
	_arcade_touch(9, start + travel, false)
	_expect(scroll.scroll_vertical > scroll_before
		and str(screen.get("_destination_id")) == destination_before,
		"A directory swipe must scroll, not accidentally choose the touched game.")
	for id: String in screen.get("_directory_buttons"):
		var destination := (screen.get("_directory_buttons") as Dictionary)[id] as Button
		if scroll.get_global_rect().encloses(destination.get_global_rect()):
			var at := destination.get_global_rect().get_center()
			stopped = walker.position
			_arcade_touch(9, at, true)
			_arcade_touch(9, at, false)
			_expect(str(screen.get("_destination_id")) == id
				and not (screen.get_node("%DirectoryOverlay") as Control).visible
				and walker.position.is_equal_approx(stopped),
				"A touch directory tap must mark its door without moving or launching.")
			break
	var copy := screen.get_node("%GameStatus") as Label
	var original_copy := copy.text
	copy.text = "A long, descriptive doorway requirement remains readable. ".repeat(20)
	for frame in 3:
		await process_frame
	var info_scroll := screen.get_node("%InfoScroll") as ScrollContainer
	start = info_scroll.get_global_rect().get_center()
	travel = Vector2(0, -info_scroll.size.y * 0.7)
	_arcade_touch(5, start, true)
	_arcade_drag(5, start + travel, travel)
	_arcade_touch(5, start + travel, false)
	_expect(info_scroll.scroll_vertical > 0,
		"Long doorway requirements must also scroll under a real touch contact.")
	copy.text = original_copy
	info_scroll.scroll_vertical = 0
	_arcade_key(KEY_D, true)
	_set_reduced_motion(true)
	await _physics_frames(6)
	var mascot := town.get("_mascot") as Node3D
	var parked := true
	for limb: Node3D in town.get("_limbs"):
		parked = parked and limb.rotation.is_zero_approx()
	_expect(parked and is_zero_approx(mascot.position.y)
		and walker.position.distance_to(stopped) > 0.1,
		"Reduced motion must park bob and limbs without disabling essential walking.")
	_arcade_key(KEY_D, false)
	await _physics_frames(2)
	var camera_pose := camera.transform
	await _physics_frames(3)
	_expect(camera.transform.is_equal_approx(camera_pose),
		"A parked reduced-motion town must have no ambient camera drift.")
	var id := GameCatalog.all()[0].id
	town.call("stand_at_game", id)
	var door: Vector3 = town.call("door_position", id)
	var down := Vector3(Town.CAMERA_OFFSET.x, 0, Town.CAMERA_OFFSET.z).normalized()
	town.call("set_walk_input", Vector2(down.x, -down.z))
	await _physics_frames(40)
	town.call("set_walk_input", Vector2.ZERO)
	_expect(walker.position.z >= door.z - 1.1 and absf(walker.position.x - door.x) < 0.1,
		"Shop walls must block the capsule instead of allowing it through a facade.")
	var shop := (town.get("_shops") as Dictionary)[id] as Node3D
	walker.position = shop.position + Vector3(-2, 0, -3.4)
	town.call("_follow_camera", 0.0, true)
	town.call("_update_occlusion")
	_expect(bool((town.get("_faded") as Dictionary).get(id, false)),
		"A facade between the camera and mascot must become see-through.")
	var facade_faded := true
	for child in shop.get_children():
		if child is MeshInstance3D:
			var material := (child as MeshInstance3D).material_override as StandardMaterial3D
			facade_faded = facade_faded and is_equal_approx(material.albedo_color.a, 0.16)
	_expect(facade_faded and is_equal_approx(
		(town.get("_foliage") as StandardMaterial3D).albedo_color.a, 1.0),
		"Every facade material must fade without making shared town foliage transparent.")
	await _capture_arcade(screen, "town-occlusion")
	var space := walker.get_world_3d().direct_space_state
	var query := PhysicsShapeQueryParameters3D.new()
	query.shape = (walker.get_child(0) as CollisionShape3D).shape
	query.exclude = [walker.get_rid()]
	for target: Vector3 in (town.get("_doors") as Dictionary).values():
		for step in 6:
			query.transform = Transform3D(Basis.IDENTITY,
				target + Vector3(0, 1.04, step * 0.4))
			_expect(space.intersect_shape(query).is_empty(),
				"Every doorway needs a clear path to the street, past its porch and planters.")
	var bounds: Rect2 = town.get("_bounds")
	walker.position = Vector3(bounds.position.x + 0.7, 0, 11)
	town.call("set_walk_input", Vector2(-down.z, -down.x))
	await _physics_frames(12)
	_expect(walker.position.x >= bounds.position.x + 0.5,
		"The walking character must remain on the town's bounded ground.")
	screen.call("_clear_walk_input")
	await _close(screen)
	_set_reduced_motion(false)


func _test_arcade_layouts() -> void:
	var screen := await _open(ARCADE_SELECT)
	if screen == null:
		return
	screen.call("_set_touch_mode")
	var town := screen.get_node("%Town")
	(town.get("_walker") as Node3D).position = Town.SPAWN
	town.call("_follow_camera", 0.0, true)
	await _physics_frames(3)
	await _capture_arcade(screen, "town-plaza")
	town.call("stand_at_game", GameCatalog.all()[0].id)
	var original_scale: Variant = _settings.call("get_value", "ui/scale", 1.0)
	var windows := WINDOWS.duplicate()
	windows["small phone"] = Vector2i(320, 568)
	for scale_value in [1.0, 1.5]:
		_set_memory_setting("ui/scale", scale_value)
		for window_name: String in windows:
			screen.call("_set_directory_open", false)
			await _resize(windows[window_name])
			for frame in 3:
				await process_frame
			var bounds := (screen as Control).get_global_rect()
			var physical := float(get_root().size.x) / bounds.size.x
			for button_name in ["DirectoryButton", "BackButton", "EnterButton"]:
				var button := screen.get_node("%" + button_name) as Button
				_expect(bounds.grow(1).encloses(button.get_global_rect())
					and button.size.y * physical >= MIN_TOUCH_TARGET - 0.5,
					"Town %s at %.1fx: %s must fit and retain a 44px target."
					% [window_name, scale_value, button_name])
			var pad := screen.get_node("%WalkPad") as Control
			var card := screen.get_node("%InfoCard") as Control
			_expect(bounds.grow(1).encloses(pad.get_global_rect())
				and not pad.get_global_rect().intersects(card.get_global_rect()),
				"Town %s at %.1fx: movement and entry must not overlap."
				% [window_name, scale_value])
			_expect((screen.get_node("%InfoScroll") as Control).size.y * physical > 12,
				"Town's game copy must keep usable scroll space on %s." % window_name)
			var viewport := screen.get_node("%WorldViewport") as SubViewport
			_expect(viewport.size.x <= get_root().size.x * 2,
				"Town must not oversample a small phone as a desktop 3D viewport.")
			if scale_value == 1.0 and window_name in [
				"desktop", "portrait phone", "landscape phone",
			]:
				await _capture_arcade(screen, "town-" + window_name)
			screen.call("_set_directory_open", true)
			for frame in 3:
				await process_frame
			var scroll := screen.get_node("%DirectoryScroll") as ScrollContainer
			_expect(scroll.follow_focus and scroll.size.y * physical >= 44,
				"The town directory needs real focus-following scroll space on %s." % window_name)
			var buttons: Array = (screen.get("_directory_buttons") as Dictionary).values()
			for index in [0, buttons.size() - 1]:
				var button := buttons[index] as Button
				button.grab_focus()
				for frame in 3:
					await process_frame
				_expect(scroll.get_global_rect().grow(1).encloses(button.get_global_rect())
					and button.size.y * physical >= MIN_TOUCH_TARGET - 0.5,
					"Directory row %d must fit %s at %.1fx: row %s, scroll %s."
					% [index, window_name, scale_value, button.get_global_rect(),
						scroll.get_global_rect()])
			var close := screen.get_node("%DirectoryClose") as Button
			_expect(bounds.grow(1).encloses(close.get_global_rect())
				and close.size.y * physical >= MIN_TOUCH_TARGET - 0.5,
				"The directory's Close action must remain usable at every UI scale.")
			if scale_value == 1.0 and window_name == "portrait phone":
				await _capture_arcade(screen, "directory-portrait")
	_set_memory_setting("ui/scale", original_scale)
	screen.call("_set_directory_open", false)
	await _resize(WINDOWS["desktop"])
	await _close(screen)


func _test_arcade_launch_and_return() -> void:
	var manifest := GameCatalog.available()[0]
	for use_touch in [false, true]:
		var screen := await _open(ARCADE_SELECT)
		if screen == null:
			return
		current_scene = screen
		var town := screen.get_node("%Town")
		town.call("stand_at_game", manifest.id)
		_routes.clear()
		if use_touch:
			screen.call("_set_touch_mode")
			for frame in 3:
				await process_frame
			var pad := screen.get_node("%WalkPad") as Control
			_arcade_touch(2, pad.get_global_rect().get_center()
				+ Vector2(pad.size.x * 0.2, 0), true)
			var enter := screen.get_node("%EnterButton") as Control
			_arcade_touch(4, enter.get_global_rect().get_center(), true)
			_arcade_touch(4, enter.get_global_rect().get_center(), false)
			_arcade_touch(2, Vector2.ZERO, false)
		else:
			screen.call("_release_focus_for_walking")
			var event := InputEventJoypadButton.new()
			event.button_index = JOY_BUTTON_A
			event.pressed = true
			get_root().push_input(event)
		_expect(bool(screen.get("_closing")) and GameCatalog.current_id() == manifest.id,
			"A nearby %s interaction must latch and select exactly that game."
			% ("second-finger" if use_touch else "gamepad"))
		screen.call("_enter_nearby")
		await _await_route()
		_expect(_routes.size() == 1 and _routes[0] in _start_routes(),
			"Town entry must start once through the normal setup/instructions route.")
		var setup := current_scene
		_expect(setup != null and str(setup.get("back_scene")) == ARCADE_SELECT,
			"Setup must return to the town that launched it, not the normal picker.")
		if setup != null:
			setup.call("go_back")
			await _await_arcade_route(ARCADE_SELECT)
			if current_scene != null and current_scene.scene_file_path == ARCADE_SELECT:
				var restored := current_scene.get_node("%Town")
				_expect(str(restored.call("nearby_game")) == manifest.id,
					"Returning from setup must put the mascot back at the chosen door.")
				current_scene.call("go_back")
				await _await_arcade_route(MAIN_MENU)
				_expect(str(_router.call(
					"game_selection_return_scene", GAME_SELECT, MAIN_MENU
				)) == GAME_SELECT, "Returning to the title must forget the secret route.")
		await _clear_routed_scene()


func _capture_arcade(screen: Node, name: String) -> void:
	if DisplayServer.get_name() == "headless":
		return
	await RenderingServer.frame_post_draw
	var viewport := screen.get_node("%WorldViewport") as SubViewport
	var image := viewport.get_texture().get_image()
	var colours := {}
	if image != null and not image.is_empty():
		for y in range(0, image.get_height(), maxi(1, image.get_height() / 24)):
			for x in range(0, image.get_width(), maxi(1, image.get_width() / 24)):
				colours[image.get_pixel(x, y).to_rgba32()] = true
	_expect(colours.size() > 20,
		"The real Compatibility town must render geometry, not an empty viewport.")
	var draws := viewport.get_render_info(
		Viewport.RENDER_INFO_TYPE_VISIBLE, Viewport.RENDER_INFO_DRAW_CALLS_IN_FRAME)
	_expect(draws <= 350,
		"The detailed town must batch its trim rather than draw each piece separately.")
	print("Arcade %s: %d visible draws." % [
		name, draws,
	])
	for argument in OS.get_cmdline_user_args():
		if not argument.begins_with("--arcade-capture-dir="):
			continue
		var directory := argument.trim_prefix("--arcade-capture-dir=")
		_expect(DirAccess.make_dir_recursive_absolute(directory) == OK,
			"Could not create the requested arcade screenshot directory.")
		_expect(get_root().get_texture().get_image().save_png(
			directory.path_join(name.validate_filename() + ".png")
		) == OK, "Could not capture the actual town screen.")


func _test_arcade_instructions_return() -> void:
	for manifest in GameCatalog.available():
		if manifest.supports_multiplayer or not manifest.characters.is_empty() \
			or not manifest.levels.is_empty() or not manifest.solo_setup_choices.is_empty():
			continue
		GameCatalog.select(manifest.id)
		get_root().get_node("GameSession").call("configure_single_player")
		_router.call("set_game_selection_origin", ARCADE_SELECT)
		var guide := await _open(INSTRUCTIONS)
		if guide != null:
			_expect(str(guide.get("back_scene")) == ARCADE_SELECT,
				"A game that skips setup must return directly from its guide to town.")
			await _close(guide)
		_router.call("set_game_selection_origin", "")
		break


func _arcade_key(key: int, pressed: bool) -> void:
	var event := InputEventKey.new()
	event.keycode = key
	event.physical_keycode = key
	event.pressed = pressed
	get_root().push_input(event)


func _arcade_axis(device: int, axis: int, value: float) -> void:
	var event := InputEventJoypadMotion.new()
	event.device = device
	event.axis = axis
	event.axis_value = value
	get_root().push_input(event)


func _arcade_touch(index: int, at: Vector2, pressed: bool) -> void:
	var event := InputEventScreenTouch.new()
	event.index = index
	event.position = at
	event.pressed = pressed
	get_root().push_input(event, true)


func _arcade_drag(index: int, at: Vector2, relative: Vector2) -> void:
	var event := InputEventScreenDrag.new()
	event.index = index
	event.position = at
	event.relative = relative
	get_root().push_input(event, true)


func _physics_frames(count: int) -> void:
	for frame in count:
		await physics_frame


func _set_memory_setting(key: String, value: Variant) -> void:
	var values: Dictionary = (_settings.get("_values") as Dictionary).duplicate()
	values[key] = value
	_settings.set("_values", values)
	_settings.emit_signal("changed", key, value)


func _await_arcade_route(path: String) -> void:
	var deadline := Time.get_ticks_msec() + 6000
	while Time.get_ticks_msec() < deadline:
		if current_scene != null and current_scene.scene_file_path == path \
			and not bool(_router.call("is_transitioning")):
			return
		await process_frame
	_expect(false, "The arcade flow did not finish routing to " + path)


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
