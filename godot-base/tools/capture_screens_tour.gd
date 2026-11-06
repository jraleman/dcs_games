extends Node

## Walks one build's screens the way a player reaches them and saves a PNG of
## each for review. `capture_screens.gd` loads it at runtime, once the
## autoloads exist, so unlike a headless suite it may name them; it still
## reaches `GameShell` members with `get`/`call`, never by type.
##
## The tour: the studio sting and opening, the title screen, every settings
## tab, the store, each gallery exhibit, the saves screen and its questions,
## the credits and, in a collection, the game picker. In a standalone build
## it then plays each mode the game offers (solo, then local two-player):
## setup, briefing, round, pause overlay, results, stats panel and share card.
## Long lists are kept a page at a time. `screens.txt` indexes every file with
## the scene it came from, followed by the run's notes and warnings.
##
## It seeds the isolated profile it runs in: every achievement and unlock rule
## is met and every shop can buy its whole catalogue, so gated levels,
## characters, exhibits and items are on screen. A game's own `save_files`
## stay fresh, so its first-run screens are kept too, unless its hook's
## `seed_profile()` opens gates that only they record.
##
## A game can seed its own progress and add screens only it knows how to reach
## with an optional `games/<folder>/tools/screen_tour.gd`; see `_load_hook()`.
## Development only: `tools/*` and `games/*/tools/*` are excluded from every
## export preset.

const STUDIO_LOGO_SCENE := "res://scenes/boot/studio_logo.tscn"
const MAIN_MENU_SCENE := "res://scenes/menus/main_menu.tscn"
const GAME_SELECT_SCENE := "res://scenes/menus/game_select.tscn"
const MODE_SELECT_SCENE := "res://scenes/menus/mode_select.tscn"
const INSTRUCTIONS_SCENE := "res://scenes/menus/instructions.tscn"
## The wrapper writes this file into every profile it makes. Seeding refuses a
## profile without it, so a stray launch can never fill a player's real save.
const PROFILE_MARKER := ".dcs_capture_profile"
const HOOK_PATH := "res://games/%s/tools/screen_tour.gd"
const INDEX_FILE := "screens.txt"
const MODES: Array[String] = ["solo", "local2"]

const DEFAULT_TIMEOUT := 900.0
const MIN_TIMEOUT := 60.0
const SCENE_TIMEOUT := 20.0
## Every shop gets at least this much, or its whole catalogue if that costs more.
const MIN_WALLET := 1000
const PAGE_LIMIT := 8
const CREDITS_PAGE_LIMIT := 12
## Pixels a list may be off its top, or hide below the fold, before it counts.
const SCROLL_SLACK := 8
## A flow that passes more scenes than this is going round in circles.
const MAX_FLOW_SCENES := 8
const SHARE_CARD_WAIT := 8.0
## How long a round plays before it is ended, and how often a frame of it is
## kept meanwhile in case it ends by itself first.
const PLAY_WAIT := 3.0
const PLAY_SAMPLE := 0.5
## The finished round's scores and best streaks, one per seat. Frames that show
## them are labelled, so nobody reviews a hit count that contradicts its score.
const RESULT_SCORES: Array[int] = [12, 9, 7, 5]
const RESULT_STREAKS: Array[int] = [5, 3, 2, 1]
const RESULT_NOTE := "tour-set scores"

# The opening is sampled rather than scripted. Frames are compared as small
# greyscale signatures; a pixel has changed when it moved past PIXEL_THRESHOLD.
const BOOT_SAMPLE := 0.5
const BOOT_LIMIT := 150.0
const BOOT_MAX_SHOTS := 16
const BOOT_FIRST_SHOT := 1.0
const BOOT_OVERDUE := 3.0
const BOOT_NUDGE_AFTER := 12.0
const BOOT_MAX_NUDGES := 10
const SIGNATURE_SIZE := Vector2i(160, 90)
const PIXEL_THRESHOLD := 24
const NOVEL_FRACTION := 0.015
const STEADY_FRACTION := 0.006
const DARK_PEAK := 20

var _out_dir := ""
var _profile_dir := ""
var _timeout := DEFAULT_TIMEOUT
var _expected_size := Vector2i.ZERO
var _scroll_pages := true
var _hook: Object = null
var _master_bus := 0
var _shot_count := 0
var _entries: Array[String] = []
var _notes: Array[String] = []
var _warnings: Array[String] = []
var _size_warned := false
var _mode_select_kept := false
var _finished := false
var _unsafe := RegEx.create_from_string("[^a-z0-9]+")


func _ready() -> void:
	# The pause overlay pauses the tree; the tour has to keep walking.
	process_mode = Node.PROCESS_MODE_ALWAYS
	_master_bus = maxi(AudioServer.get_bus_index(&"Master"), 0)
	_run.call_deferred()


func _process(_delta: float) -> void:
	# Settings re-applies the saved volumes whenever a screen touches them, so
	# the mute is held every frame rather than set once.
	AudioServer.set_bus_mute(_master_bus, true)


func _run() -> void:
	if not _read_arguments() or not _profile_is_isolated():
		return
	_seed_profile()
	get_tree().create_timer(_timeout, true, false, true).timeout.connect(_on_watchdog)
	_load_hook()
	await _seed_hook()
	await _tour_boot()
	if not await _ensure_main_menu():
		_fail("The title screen never opened.")
		return
	await _tour_title_screens()
	if GameCatalog.offers_a_choice():
		await _tour_game_select()
	if GameCatalog.is_single_game_build():
		for mode in MODES:
			await _tour_mode(mode)
	await _finish(0)


func _read_arguments() -> bool:
	_out_dir = _argument("--capture-out=").replace("\\", "/")
	_profile_dir = _argument("--capture-profile=").replace("\\", "/")
	if _out_dir.is_empty() or _profile_dir.is_empty():
		_out_dir = ""
		_fail("Pass --capture-out=<dir> and --capture-profile=<dir> after --.")
		return false
	var error := DirAccess.make_dir_recursive_absolute(_out_dir)
	if error != OK:
		var folder := _out_dir
		_out_dir = ""
		_fail("Could not create %s (error %d)." % [folder, error])
		return false
	_scroll_pages = not _has_flag("--no-scroll-pages")
	var seconds := _argument("--capture-timeout=")
	if seconds.is_valid_float():
		_timeout = maxf(seconds.to_float(), MIN_TIMEOUT)
	var parts := _argument("--capture-size=").to_lower().split("x")
	if parts.size() == 2 and parts[0].is_valid_int() and parts[1].is_valid_int():
		_expected_size = Vector2i(parts[0].to_int(), parts[1].to_int())
	return true


func _argument(prefix: String) -> String:
	var arguments := OS.get_cmdline_user_args()
	arguments.append_array(OS.get_cmdline_args())
	for argument in arguments:
		if argument.begins_with(prefix):
			return argument.trim_prefix(prefix).strip_edges()
	return ""


func _has_flag(flag: String) -> bool:
	return flag in OS.get_cmdline_user_args() or flag in OS.get_cmdline_args()


## Seeding unlocks every achievement and fills every wallet of whichever
## profile this launch writes to, so the tour refuses to run anywhere but a
## marked profile that the user data folder really lives in.
func _profile_is_isolated() -> bool:
	var data := _comparable(OS.get_user_data_dir())
	var profile := _comparable(_profile_dir)
	if profile.is_empty() or not data.begins_with(profile + "/"):
		_fail("User data %s is not inside --capture-profile=%s; refusing to seed it." % [
			OS.get_user_data_dir(), _profile_dir,
		])
		return false
	if not FileAccess.file_exists(_profile_dir.path_join(PROFILE_MARKER)):
		_fail("%s has no %s marker; refusing to seed it." % [_profile_dir, PROFILE_MARKER])
		return false
	return true


func _comparable(path: String) -> String:
	var clean := path.replace("\\", "/").simplify_path().rstrip("/")
	return clean.to_lower() if OS.get_name() == "Windows" else clean


## Meets every achievement and unlock rule and lets every shop buy its whole
## catalogue, so gated levels, characters, exhibits and items are captured as
## a player who has earned them sees them.
func _seed_profile() -> void:
	var manifests := GameCatalog.all()
	var unlocked := 0
	for manifest in manifests:
		for id: Variant in manifest.achievements:
			if AchievementManager.unlock(str(id)):
				unlocked += 1
	var progression: Variant = AchievementManager.get("_progression")
	if progression is Dictionary:
		for manifest in manifests:
			for key in manifest.progression_keys():
				(progression as Dictionary)[key] = true
		AchievementManager.call("_save_state")
	else:
		_warn("AchievementManager keeps no _progression; unlock rules were not seeded.")
	for manifest in manifests:
		if not Store.has_store(manifest.id):
			continue
		var catalogue := 0
		for item in Store.items(manifest.id):
			catalogue += int(item.get("price", 0))
		var missing := maxi(MIN_WALLET, catalogue) - Store.points(manifest.id)
		if missing > 0:
			Store.add_points(manifest.id, missing)
	# Each unlock queued a toast; the deferred show that follows finds none.
	var toasts: Variant = AchievementManager.get("_toast_queue")
	if toasts is Array:
		(toasts as Array).clear()
	_note("Seeded %d achievements, every unlock rule and every wallet." % unlocked)


func _on_watchdog() -> void:
	if _finished:
		return
	_warn("The tour ran past %d s; ending it with what it kept." % int(_timeout))
	_finish(1)

# --- Shots -------------------------------------------------------------------


func _settle(seconds: float) -> void:
	if seconds > 0.0:
		await get_tree().create_timer(seconds, true, false, true).timeout
	await get_tree().process_frame
	await get_tree().process_frame


## Saves the frame on screen once it has been drawn.
func _shot(label: String, note := "") -> void:
	if _finished:
		return
	await RenderingServer.frame_post_draw
	if _finished:
		return
	var image := get_viewport().get_texture().get_image()
	_check_size(image)
	_save_image(image, label, note)


func _save_image(image: Image, label: String, note := "") -> void:
	if image == null or image.is_empty():
		_warn("There was nothing to save for %s." % label)
		return
	_shot_count += 1
	var file_name := "%03d_%s.png" % [_shot_count, _slug(label)]
	var error := image.save_png(_out_dir.path_join(file_name))
	if error != OK:
		_warn("Could not save %s (error %d)." % [file_name, error])
		return
	var scene := get_tree().current_scene
	var scene_path := scene.scene_file_path if scene != null else ""
	_entries.append("%s\t%s\t%s" % [file_name, scene_path, note])
	print("[capture] %s" % file_name)


## A window the display scaled or clamped no longer matches the size asked
## for; the shots are still kept, but the reviewer should know.
func _check_size(image: Image) -> void:
	if _size_warned or _expected_size == Vector2i.ZERO or image == null:
		return
	if image.get_size() != _expected_size:
		_size_warned = true
		_warn("Frames are %dx%d, not the %dx%d asked for." % [
			image.get_width(), image.get_height(), _expected_size.x, _expected_size.y,
		])


func _slug(text: String) -> String:
	var slug := _unsafe.sub(text.to_lower(), "_", true).lstrip("_").rstrip("_")
	return slug if not slug.is_empty() else "screen"


func _scene_name(scene: Node) -> String:
	if not is_instance_valid(scene):
		return "none"
	var path := scene.scene_file_path
	return path.get_file().get_basename() if not path.is_empty() else String(scene.name)


## Keeps whatever every long list on screen hides, a page at a time, then puts
## each list back where it was. A list that opened scrolled down is kept from
## its top too, as `_p1`, and noted: what sits above the fold is still a screen.
func _capture_pages(label: String, limit := PAGE_LIMIT) -> void:
	if not _scroll_pages or _finished:
		return
	var lists: Array[ScrollContainer] = []
	for node in get_tree().root.find_children("*", "ScrollContainer", true, false):
		var scroll := node as ScrollContainer
		if (
			scroll.is_visible_in_tree()
			and scroll.vertical_scroll_mode != ScrollContainer.SCROLL_MODE_DISABLED
		):
			var bar := scroll.get_v_scroll_bar()
			if bar.max_value - bar.page > SCROLL_SLACK:
				lists.append(scroll)
	for index in lists.size():
		var scroll := lists[index]
		var origin := scroll.scroll_vertical
		var prefix := label + ("_s%d" % (index + 1) if lists.size() > 1 else "")
		var page := 2
		if origin > SCROLL_SLACK:
			_note("%s opened %d px down its list; %s_p1 is the top." % [label, origin, prefix])
			scroll.scroll_vertical = 0
			await _settle(0.3)
			if _finished or not is_instance_valid(scroll):
				continue
			await _shot(prefix + "_p1", "scrolled to the top")
		while page <= limit + 1 and not _finished and is_instance_valid(scroll):
			var bar := scroll.get_v_scroll_bar()
			var before := scroll.scroll_vertical
			if float(before) >= bar.max_value - bar.page - 1.0:
				break
			scroll.scroll_vertical = before + maxi(int(bar.page * 0.9), 1)
			await _settle(0.3)
			if not is_instance_valid(scroll) or scroll.scroll_vertical == before:
				break
			await _shot("%s_p%d" % [prefix, page], "scrolled")
			page += 1
		if is_instance_valid(scroll):
			scroll.scroll_vertical = origin
	await _settle(0.1)


# --- Navigation --------------------------------------------------------------


func _current_id() -> int:
	var scene := get_tree().current_scene
	return scene.get_instance_id() if scene != null else 0


func _is_scene(path: String) -> bool:
	var scene := get_tree().current_scene
	return scene != null and scene.scene_file_path == path


func _is_shell(scene: Node) -> bool:
	return (
		is_instance_valid(scene)
		and scene.has_method("_share_payload")
		and scene.has_method("open_pause_menu")
	)


func _flag(node: Object, member: String) -> bool:
	var value: Variant = node.get(member) if is_instance_valid(node) else null
	return value is bool and value


func _int(node: Object, member: String, fallback := -1) -> int:
	var value: Variant = node.get(member) if is_instance_valid(node) else null
	return int(value) if value is int or value is float else fallback


## Waits for another scene to be current and for its fade to finish.
func _await_scene_change(previous_id: int, timeout := SCENE_TIMEOUT) -> bool:
	var deadline := Time.get_ticks_msec() + int(timeout * 1000.0)
	while not _finished and Time.get_ticks_msec() < deadline:
		await get_tree().process_frame
		var scene := get_tree().current_scene
		if (
			scene != null
			and scene.get_instance_id() != previous_id
			and not Router.is_transitioning()
		):
			await _settle(0.5)
			return true
	return false


func _await_scene(path: String, timeout: float) -> bool:
	var deadline := Time.get_ticks_msec() + int(timeout * 1000.0)
	while not _finished:
		if _is_scene(path) and not Router.is_transitioning():
			return true
		if Time.get_ticks_msec() >= deadline:
			return false
		await get_tree().process_frame
	return false


func _await_router_idle(timeout := 10.0) -> void:
	var deadline := Time.get_ticks_msec() + int(timeout * 1000.0)
	while not _finished and Router.is_transitioning() and Time.get_ticks_msec() < deadline:
		await get_tree().process_frame


func _ensure_main_menu() -> bool:
	if _finished:
		return false
	if _is_scene(MAIN_MENU_SCENE) and not Router.is_transitioning():
		return true
	return await _go_main_menu()


func _go_main_menu() -> bool:
	await _await_router_idle()
	if not _is_scene(MAIN_MENU_SCENE):
		Router.goto(MAIN_MENU_SCENE)
	if not await _await_scene(MAIN_MENU_SCENE, SCENE_TIMEOUT):
		return false
	await _settle(0.5)
	return true


## Presses a title-screen button through its handler and returns the screen
## it opened, or null when none did.
func _open_from_main_menu(handler: String) -> Node:
	if not await _ensure_main_menu():
		return null
	var menu := get_tree().current_scene
	if not menu.has_method(handler):
		_warn("The title screen has no %s()." % handler)
		return null
	var previous := menu.get_instance_id()
	menu.call(handler)
	if not await _await_scene_change(previous):
		_warn("%s() did not open a screen." % handler)
		return null
	return get_tree().current_scene


func _title_button_visible(member: String) -> bool:
	var menu := get_tree().current_scene
	var button: Variant = menu.get(member) if menu != null else null
	return is_instance_valid(button) and button is Control and (button as Control).visible


## Leaves a screen the way a player would, through its own Back, and falls
## back to opening the title screen when that goes nowhere.
func _leave(screen: Node) -> void:
	if _finished:
		return
	if is_instance_valid(screen) and screen == get_tree().current_scene:
		for handler: String in ["_on_back_pressed", "go_back"]:
			if screen.has_method(handler):
				var previous := screen.get_instance_id()
				screen.call(handler)
				await _await_scene_change(previous, 10.0)
				break
	if not _is_scene(MAIN_MENU_SCENE):
		await _go_main_menu()


func _press_action(action: StringName) -> void:
	if not InputMap.has_action(action):
		return
	for pressed: bool in [true, false]:
		var event := InputEventAction.new()
		event.action = action
		event.pressed = pressed
		Input.parse_input_event(event)
		await get_tree().process_frame


# --- Ending ------------------------------------------------------------------


func _note(text: String) -> void:
	_notes.append(text)
	print("[capture] %s" % text)


func _warn(text: String) -> void:
	_warnings.append(text)
	push_warning("[capture] %s" % text)


func _fail(text: String) -> void:
	_warnings.append(text)
	printerr("[capture] %s" % text)
	_finish(1)


## Writes the index, stops every sound and quits with [param code]: 0 when the
## tour reached its end, however many notes it left, and 1 when it did not.
func _finish(code: int) -> void:
	if _finished:
		return
	_finished = true
	_write_index(code)
	_silence()
	get_tree().paused = false
	await get_tree().create_timer(0.15, true, false, true).timeout
	get_tree().quit(code)


func _write_index(code: int) -> void:
	if _out_dir.is_empty():
		return
	var file := FileAccess.open(_out_dir.path_join(INDEX_FILE), FileAccess.WRITE)
	if file == null:
		printerr("[capture] Could not write %s (error %d)." % [
			INDEX_FILE, FileAccess.get_open_error(),
		])
		return
	var window := get_window().size
	file.store_line("# DCS screenshot tour")
	file.store_line("# build: %s" % _build_name())
	file.store_line("# window: %dx%d" % [window.x, window.y])
	file.store_line("# result: %s" % ("complete" if code == 0 else "incomplete"))
	file.store_line("# file\tscene\tnote")
	for entry in _entries:
		file.store_line(entry)
	for text in _notes:
		file.store_line("# note: %s" % text)
	for text in _warnings:
		file.store_line("# warning: %s" % text)
	file.close()


## Stops every player before quitting, as the tutorial recorder does, so the
## engine is not tearing down streams that are still playing.
func _silence() -> void:
	AudioManager.stop_music(0.0)
	for type: String in ["AudioStreamPlayer", "AudioStreamPlayer2D", "AudioStreamPlayer3D"]:
		for node in get_tree().root.find_children("*", type, true, false):
			node.call("stop")
			node.set("stream", null)


func _build_name() -> String:
	return GameCatalog.single_game_id() if GameCatalog.is_single_game_build() else "collection"

# --- Opening -----------------------------------------------------------------


## Plays the studio sting and the opening as a player sees them, keeping one
## frame of each distinct card. A frame is new when it differs from the last
## one kept. It is kept once it holds still, once it has kept changing for a
## while (an animated card never holds still), or when it is the first a scene
## shows. Fades are never kept. A screen that holds still for a long time is
## waiting for the player, so the tour presses accept.
func _tour_boot() -> void:
	Router.goto(STUDIO_LOGO_SCENE, false)
	var started := Time.get_ticks_msec()
	var kept: Image = null
	var last: Image = null
	var shots := 0
	var nudges := 0
	var scene_id := 0
	var scene_since := started
	var scene_shots := 0
	var still_since := started
	var novel_since := -1
	while not _finished:
		await get_tree().create_timer(BOOT_SAMPLE, true, false, true).timeout
		var now := Time.get_ticks_msec()
		if _is_scene(MAIN_MENU_SCENE):
			break
		if now - started > int(BOOT_LIMIT * 1000.0):
			_note("The opening was still running after %d s." % int(BOOT_LIMIT))
			break
		var scene := get_tree().current_scene
		if scene == null or Router.is_transitioning():
			still_since = now
			continue
		if scene.get_instance_id() != scene_id:
			scene_id = scene.get_instance_id()
			scene_since = now
			scene_shots = 0
			still_since = now
		var scene_label := _scene_name(scene)
		await RenderingServer.frame_post_draw
		var image := get_viewport().get_texture().get_image()
		var signature := _signature(image)
		var steady := last != null and _difference(signature, last) < STEADY_FRACTION
		last = signature
		if not steady:
			still_since = now
		var novel := _difference(signature, kept) > NOVEL_FRACTION
		if not novel:
			novel_since = -1
		elif novel_since < 0:
			novel_since = now
		var overdue := novel_since >= 0 and now - novel_since >= int(BOOT_OVERDUE * 1000.0)
		var first := scene_shots == 0 and now - scene_since >= int(BOOT_FIRST_SHOT * 1000.0)
		if (
			novel and shots < BOOT_MAX_SHOTS and _peak(signature) >= DARK_PEAK
			and (steady or overdue or first)
		):
			shots += 1
			scene_shots += 1
			kept = signature
			novel_since = -1
			_check_size(image)
			_save_image(image, "boot_%02d_%s" % [shots, scene_label], "opening")
		elif now - still_since >= int(BOOT_NUDGE_AFTER * 1000.0) and nudges < BOOT_MAX_NUDGES:
			nudges += 1
			still_since = now
			_note("%s held still for %d s; pressed accept." % [
				scene_label, int(BOOT_NUDGE_AFTER),
			])
			await _press_action(&"ui_accept")
	if not _finished and not _is_scene(MAIN_MENU_SCENE):
		await _skip_opening()


## The opening did not end by itself: try what a player would, then leave.
func _skip_opening() -> void:
	for action: StringName in [&"skip", &"ui_cancel"]:
		if _finished or _is_scene(MAIN_MENU_SCENE):
			return
		await _press_action(action)
		if await _await_scene(MAIN_MENU_SCENE, 5.0):
			_note("Reached the title screen by pressing %s." % action)
			return
	if not _finished and not _is_scene(MAIN_MENU_SCENE):
		_note("The opening never reached the title screen; opened it directly.")
		await _go_main_menu()


## A small greyscale copy of [param image]. It is sampled from the image's
## mipmaps, which average every pixel, so a line of text that changes still
## registers; resizing an image without mipmaps would only sample a few.
func _signature(image: Image) -> Image:
	var signature := Image.new()
	signature.copy_from(image)
	signature.convert(Image.FORMAT_L8)
	signature.generate_mipmaps()
	signature.resize(SIGNATURE_SIZE.x, SIGNATURE_SIZE.y, Image.INTERPOLATE_TRILINEAR)
	signature.clear_mipmaps()
	return signature


## The share of signature pixels that differ by more than PIXEL_THRESHOLD.
func _difference(a: Image, b: Image) -> float:
	if a == null or b == null:
		return 1.0
	var left := a.get_data()
	var right := b.get_data()
	if left.is_empty() or left.size() != right.size():
		return 1.0
	var changed := 0
	for index in left.size():
		if absi(left[index] - right[index]) > PIXEL_THRESHOLD:
			changed += 1
	return float(changed) / float(left.size())


func _peak(signature: Image) -> int:
	var peak := 0
	for value in signature.get_data():
		peak = maxi(peak, value)
	return peak

# --- Title screens -----------------------------------------------------------


## The title screen and every screen it opens, each left through its own Back.
func _tour_title_screens() -> void:
	await _settle(2.0)
	await _shot("main_menu")
	await _capture_pages("main_menu")
	await _tour_settings()
	if await _ensure_main_menu() and _title_button_visible("_store_button"):
		await _tour_simple("_on_store_pressed", "store", 1.5)
	if await _ensure_main_menu() and _title_button_visible("_gallery_button"):
		await _tour_gallery()
	if await _ensure_main_menu() and _title_button_visible("_saves_button"):
		await _tour_saves()
	await _tour_credits()
	await _ensure_main_menu()


## Opens a screen from the title, keeps it and every page of it, and leaves.
func _tour_simple(handler: String, label: String, settle: float) -> void:
	var screen := await _open_from_main_menu(handler)
	if screen == null:
		return
	await _settle(settle)
	await _shot(label)
	await _capture_pages(label)
	await _leave(screen)


## One frame of every tab the build shows, including a standalone build's
## Controls and Game tabs.
func _tour_settings() -> void:
	var screen := await _open_from_main_menu("_on_settings_pressed")
	if screen == null:
		return
	await _settle(1.0)
	var tabs: Variant = screen.get("_tabs")
	if tabs is TabContainer:
		var container := tabs as TabContainer
		for index in container.get_tab_count():
			if _finished or not is_instance_valid(container):
				break
			if container.is_tab_hidden(index):
				continue
			container.current_tab = index
			await _settle(0.6)
			var label := "settings_%02d_%s" % [index + 1, container.get_tab_title(index)]
			await _shot(label)
			await _capture_pages(label)
	else:
		_warn("The settings screen has no _tabs; kept one frame of it.")
		await _shot("settings")
		await _capture_pages("settings")
	await _leave(screen)


## Every exhibit that is open. A locked one is listed in the notes instead,
## since seeding opens every achievement gate and only game progress remains.
## The exhibit the gallery opens on is kept as it opened; any other is reached
## the way a player reaches it, from its focused entry, so the list follows.
## The gallery is then put back as it opened before its pages are kept.
func _tour_gallery() -> void:
	var screen := await _open_from_main_menu("_on_gallery_pressed")
	if screen == null:
		return
	await _settle(1.0)
	var exhibits: Variant = screen.get("_exhibits")
	var buttons: Variant = screen.get("_buttons")
	if not (exhibits is Array and buttons is Array and screen.has_method("_select")):
		_warn("The gallery has no _exhibits, _buttons or _select(); kept one frame of it.")
		await _shot("gallery")
	else:
		var shelf := exhibits as Array
		var toggles := buttons as Array
		var opened: Variant = screen.get("_selected")
		var opened_focus := screen.get_viewport().gui_get_focus_owner()
		var lists := screen.find_children("*", "ScrollContainer", true, false)
		var offsets: Array[int] = []
		for list in lists:
			offsets.append((list as ScrollContainer).scroll_vertical)
		for index in shelf.size():
			if _finished or not is_instance_valid(screen):
				break
			var exhibit: Dictionary = shelf[index] if shelf[index] is Dictionary else {}
			var id := str(exhibit.get("id", index + 1))
			var button: Variant = toggles[index] if index < toggles.size() else null
			if is_instance_valid(button) and button is BaseButton and button.disabled:
				_note("Gallery exhibit %s is locked; it was not kept." % id)
				continue
			if index != opened and is_instance_valid(button) and button is Control:
				(button as Control).grab_focus()
			screen.call("_select", index)
			await _settle(1.5)
			await _shot("gallery_%02d_%s" % [index + 1, id])
		if is_instance_valid(opened_focus):
			opened_focus.grab_focus()
		for list_index in lists.size():
			if is_instance_valid(lists[list_index]):
				var scroll := lists[list_index] as ScrollContainer
				scroll.scroll_vertical = offsets[list_index]
		await _settle(0.3)
	await _capture_pages("gallery")
	await _leave(screen)


## The saves screen and, in a standalone build, its two questions and the
## status a backup leaves. Every question is cancelled, so nothing is lost;
## the backup is written into the throwaway profile.
func _tour_saves() -> void:
	var screen := await _open_from_main_menu("_on_saves_pressed")
	if screen == null:
		return
	await _settle(1.0)
	await _shot("saves")
	await _capture_pages("saves")
	if GameCatalog.is_single_game_build():
		var id := GameCatalog.single_game_id()
		await _ask_and_cancel(screen, "_on_delete_save_pressed", [id], "saves_confirm_delete")
		if is_instance_valid(screen) and screen.has_method("_on_back_up_pressed"):
			screen.call("_on_back_up_pressed", id)
			await _settle(0.8)
			await _shot("saves_backed_up")
			await _capture_pages("saves_backed_up")
		var backups := GameSaves.backups(id)
		if not backups.is_empty():
			var backup := backups[0]
			await _ask_and_cancel(
				screen, "_on_restore_pressed",
				[id, str(backup.get("path", "")), GameSaves.backup_date_text(backup)],
				"saves_confirm_restore"
			)
	await _leave(screen)


func _ask_and_cancel(screen: Node, handler: String, arguments: Array, label: String) -> void:
	if _finished or not is_instance_valid(screen) or not screen.has_method(handler):
		_warn("The saves screen could not ask %s()." % handler)
		return
	screen.callv(handler, arguments)
	await _settle(0.6)
	await _shot(label)
	if is_instance_valid(screen) and screen.has_method("_on_cancel_pressed"):
		screen.call("_on_cancel_pressed")
		await _settle(0.3)


## The credits roll by themselves and loop; the tour holds them at the top
## and pages through them by hand instead.
func _tour_credits() -> void:
	var screen := await _open_from_main_menu("_on_credits_pressed")
	if screen == null:
		return
	screen.set("_auto", false)
	var scroll: Variant = screen.get("_scroll")
	if scroll is ScrollContainer:
		(scroll as ScrollContainer).scroll_vertical = 0
	await _settle(1.0)
	await _shot("credits")
	await _capture_pages("credits", CREDITS_PAGE_LIMIT)
	await _leave(screen)


# --- Game picker -------------------------------------------------------------


## A collection's rack with every cartridge taken in hand in turn.
func _tour_game_select() -> void:
	var screen := await _open_from_main_menu("_on_play_pressed")
	if screen == null:
		return
	if not _is_scene(GAME_SELECT_SCENE):
		_warn("Play opened %s, not the game picker." % _scene_name(screen))
		await _shot("unexpected_play_%s" % _scene_name(screen))
		await _go_main_menu()
		return
	await _settle(1.0)
	var cards: Variant = screen.get("_cards")
	if not (cards is Array and screen.has_method("_select_index")):
		_warn("The game picker has no _cards or _select_index(); kept one frame of it.")
		await _shot("game_select")
	else:
		var rack := cards as Array
		for index in rack.size():
			if _finished or not is_instance_valid(screen):
				break
			var card: Variant = rack[index]
			var id := str(index + 1)
			if is_instance_valid(card) and card.has_method("game_id"):
				id = str(card.call("game_id"))
			screen.call("_select_index", index, true)
			await _settle(1.6)
			await _shot("game_select_%02d_%s" % [index + 1, id])
	await _leave(screen)

# --- Playing -----------------------------------------------------------------


## Plays one mode from the title screen to its results and back: setup,
## briefing, the round, its pause overlay, results, stats panel and share
## card. A screen the game skips for this mode is simply never met.
func _tour_mode(mode: String) -> void:
	var offered := (
		GameSession.single_player_offered() if mode == "solo"
		else GameSession.multiplayer_offered()
	)
	if not offered:
		_note("This build does not offer %s; it was skipped." % mode)
		return
	var screen := await _open_from_main_menu("_on_play_pressed")
	var visited := 0
	while screen != null and not _finished and visited < MAX_FLOW_SCENES:
		visited += 1
		var previous := screen.get_instance_id()
		if _is_scene(MAIN_MENU_SCENE):
			break
		if _is_scene(MODE_SELECT_SCENE):
			if not await _tour_mode_select(screen, mode):
				break
		elif _is_scene(INSTRUCTIONS_SCENE):
			await _tour_instructions(screen, mode)
		elif _is_shell(screen):
			await _tour_round(screen, mode)
		else:
			_warn("Playing %s reached %s, which the tour does not know." % [
				mode, _scene_name(screen),
			])
			await _shot("unexpected_%s_%s" % [mode, _scene_name(screen)])
			break
		if not await _await_scene_change(previous):
			var stalled := _scene_name(get_tree().current_scene)
			_warn("Playing %s stopped on %s." % [mode, stalled])
			await _shot("stalled_%s_%s" % [mode, stalled])
			break
		screen = get_tree().current_scene
	if visited >= MAX_FLOW_SCENES and not _is_scene(MAIN_MENU_SCENE):
		_warn("Playing %s passed %d screens without coming back." % [mode, visited])
	await _go_main_menu()


## Setup: the player-count step once, then this mode's choices with and
## without the Details notes. A game that offers a CPU makes it the default
## local opponent, so local play keeps that frame, then seats a second human.
func _tour_mode_select(screen: Node, mode: String) -> bool:
	await _settle(1.0)
	if not is_instance_valid(screen):
		return false
	if _int(screen, "_step", 1) == 0:
		if not _mode_select_kept:
			_mode_select_kept = true
			await _shot("mode_select")
			await _capture_pages("mode_select")
		screen.call("_on_single_player_pressed" if mode == "solo" else "_on_multiplayer_pressed")
		await _settle(1.0)
	if mode != "solo" and screen.has_method("_cpu_selected") and screen.call("_cpu_selected"):
		await _shot("mode_select_%s_vs_cpu" % mode)
		_choose_human_opponent(screen)
		await _settle(0.6)
	var label := "mode_select_%s" % mode
	await _shot(label)
	await _capture_pages(label)
	await _expand_and_keep(screen.get("_details_button"), label + "_details")
	if not is_instance_valid(screen) or not screen.has_method("_on_confirm_pressed"):
		_warn("Mode select has no _on_confirm_pressed().")
		return false
	screen.call("_on_confirm_pressed")
	return true


## A real press, unlike `set_pressed_no_signal()`, also releases the other
## button of their group; the handler then rewrites the confirmation.
func _choose_human_opponent(screen: Node) -> void:
	var human: Variant = screen.get("_human_option_button")
	if not (is_instance_valid(human) and human is BaseButton):
		_warn("Mode select has no _human_option_button; local play kept the CPU.")
		return
	human.button_pressed = true
	var cpu: Variant = screen.get("_cpu_option_button")
	if is_instance_valid(cpu) and cpu is BaseButton and cpu.button_pressed:
		cpu.button_pressed = false
	if screen.has_method("_on_opponent_option_pressed"):
		screen.call("_on_opponent_option_pressed")


## Opens a toggle that reveals more of a screen, keeps what it shows and
## closes it again. A toggle already open or not shown is left alone.
func _expand_and_keep(toggle: Variant, label: String) -> void:
	if _finished or not (is_instance_valid(toggle) and toggle is BaseButton):
		return
	var button := toggle as BaseButton
	if not button.is_visible_in_tree() or button.button_pressed:
		return
	button.button_pressed = true
	await _settle(0.6)
	await _shot(label)
	await _capture_pages(label)
	if is_instance_valid(button):
		button.button_pressed = false
		await _settle(0.3)


## The briefing and, when a tutorial clip stands in its place, the written
## guide behind it. Then Start.
func _tour_instructions(screen: Node, mode: String) -> void:
	await _settle(1.5)
	var label := "instructions_%s" % mode
	await _shot(label)
	await _capture_pages(label)
	if _flag(screen, "_video_ready"):
		await _expand_and_keep(screen.get("_guide_button"), label + "_guide")
	if is_instance_valid(screen) and screen.has_method("_on_start_pressed"):
		screen.call("_on_start_pressed")
	else:
		_warn("The briefing has no _on_start_pressed().")


## A round from its first frame to its stats panel, then back to the title.
## A game that opens on a lobby is kept there first and started the way its
## replay button would start it. The pause overlay is kept first, while the
## round surely runs. A round still running after the wait for play is ended
## as its timer running out would end it, with fixed scores, so its results
## match from run to run.
func _tour_round(shell: Node, mode: String) -> void:
	await _settle(0.5)
	await _dismiss_pause(shell)
	if not _flag(shell, "_round_active"):
		await _settle(1.5)
		await _dismiss_pause(shell)
		await _shot("play_%s_lobby" % mode)
		await _run_hook(shell, mode, "lobby")
		if is_instance_valid(shell) and not _flag(shell, "_round_active"):
			shell.call("_on_play_again_pressed")
			await _settle(0.2)
	if not is_instance_valid(shell):
		return
	await _shot("play_%s_start" % mode)
	await _tour_pause(shell, mode)
	await _shot_play(shell, mode)
	if is_instance_valid(shell) and not _results_up(shell):
		await _run_hook(shell, mode, "round")
	var note := RESULT_NOTE if _end_round(shell) else ""
	await _settle(1.5)
	await _shot("results_%s" % mode, note)
	await _capture_pages("results_%s" % mode)
	await _run_hook(shell, mode, "results")
	await _tour_score_panel(shell, mode, note)
	if is_instance_valid(shell) and shell == get_tree().current_scene:
		shell.call("_on_exit_to_main_menu_pressed")
	else:
		Router.goto(MAIN_MENU_SCENE)


## The round in motion. Nobody is playing, so a round on lives can end by
## itself while the tour waits; frames are kept in memory as it runs, and the
## last one drawn before its results is the one saved.
func _shot_play(shell: Node, mode: String) -> void:
	var kept: Image = null
	var waited := 0.0
	while waited < PLAY_WAIT and not _finished and is_instance_valid(shell):
		await _settle(PLAY_SAMPLE)
		waited += PLAY_SAMPLE
		await _dismiss_pause(shell)
		if not is_instance_valid(shell) or _results_up(shell):
			break
		await RenderingServer.frame_post_draw
		if _finished or not is_instance_valid(shell) or _results_up(shell):
			break
		kept = get_viewport().get_texture().get_image()
	if _finished:
		return
	if is_instance_valid(shell) and _results_up(shell):
		_note("Playing %s, the round ended by itself within %.1f s." % [mode, waited])
	if kept == null:
		_warn("Playing %s, no frame of the round in motion was kept." % mode)
		return
	_check_size(kept)
	_save_image(kept, "play_%s_active" % mode)


## Three games pause by themselves when the window loses focus mid-round;
## a review frame of play should show the play.
func _dismiss_pause(shell: Node) -> void:
	var overlay: Variant = shell.get("_pause_menu") if is_instance_valid(shell) else null
	if is_instance_valid(overlay) and overlay.has_method("resume"):
		overlay.call("resume")
		await _settle(0.3)


func _tour_pause(shell: Node, mode: String) -> void:
	if _finished or not is_instance_valid(shell) or _results_up(shell):
		return
	shell.call("open_pause_menu")
	await _settle(0.8)
	var overlay: Variant = shell.get("_pause_menu") if is_instance_valid(shell) else null
	if not is_instance_valid(overlay):
		_warn("open_pause_menu() showed no pause overlay.")
		return
	await _shot("pause_%s" % mode)
	await _capture_pages("pause_%s" % mode)
	await _dismiss_pause(shell)


func _results_up(shell: Node) -> bool:
	var panel: Variant = shell.get("_round_over") if is_instance_valid(shell) else null
	return is_instance_valid(panel) and panel is CanvasItem and panel.visible


## Ends the round the way `tests/game_shell_test.gd` does: the timer stops,
## every seat gets a fixed score and best streak, and time runs out. Returns
## whether it did, rather than finding the round already over.
func _end_round(shell: Node) -> bool:
	if _finished or not is_instance_valid(shell) or _results_up(shell):
		return false
	var timer := shell.get_node_or_null("%RoundTimer") as Timer
	if timer != null:
		timer.stop()
	var seats := 2
	if shell.has_method("_active_player_indices"):
		var active: Variant = shell.call("_active_player_indices")
		if active is Array:
			seats = maxi(seats, (active as Array).size())
	var scores: Array = []
	var streaks: Array = []
	for seat in mini(seats, RESULT_SCORES.size()):
		scores.append(RESULT_SCORES[seat])
		streaks.append(RESULT_STREAKS[seat])
	shell.set("_scores", scores)
	shell.set("_best_streaks", streaks)
	shell.call("_on_round_timer_timeout")
	return true


## The stats panel and the share card drawn for it, which is also kept on its
## own at full size, as the image a player would save.
func _tour_score_panel(shell: Node, mode: String, note: String) -> void:
	if _finished or not is_instance_valid(shell) or not shell.has_method("_on_see_score_pressed"):
		return
	shell.call("_on_see_score_pressed")
	var deadline := Time.get_ticks_msec() + int(SHARE_CARD_WAIT * 1000.0)
	while not _finished and is_instance_valid(shell) and Time.get_ticks_msec() < deadline:
		var waiting: Variant = shell.get("_share_placeholder")
		var drawing: bool = (
			is_instance_valid(waiting) and waiting is CanvasItem and waiting.visible
			and _int(shell, "_share_card_round") >= 0
		)
		if not drawing:
			break
		await get_tree().process_frame
	if not is_instance_valid(shell):
		return
	await _settle(0.8)
	await _shot("stats_%s" % mode, note)
	await _capture_pages("stats_%s" % mode)
	var preview: Variant = shell.get("_share_card_preview")
	var texture: Variant = preview.get("texture") if is_instance_valid(preview) else null
	if texture is Texture2D:
		_save_image(
			(texture as Texture2D).get_image(), "share_card_%s" % mode,
			"share card" if note.is_empty() else "share card, %s" % note
		)
	else:
		var placeholder: Variant = shell.get("_share_placeholder")
		var reason := str(placeholder.get("text")) if is_instance_valid(placeholder) else ""
		_note("Playing %s drew no share card. %s" % [mode, reason])
	if is_instance_valid(shell) and shell.has_method("_on_back_to_results_pressed"):
		shell.call("_on_back_to_results_pressed")
		await _settle(0.5)

# --- Game hooks --------------------------------------------------------------


## Loads a standalone game's optional `games/<folder>/tools/screen_tour.gd`,
## for progress and screens only that game knows about. Any script will do; a
## Node is added under the tour, so it keeps running while the tree is paused.
## Every method is optional and may be a coroutine:
##
## - `seed_profile() -> String`: runs once in the isolated profile, after the
##   tour's own seeding and before the opening, to open gates the game records
##   in its own `save_files`. A returned line is added to the notes.
## - `screens(mode: String) -> Array`: what to keep while [param mode] is
##   played ("solo" or "local2"). An entry is an id, or a Dictionary with
##   `id`, `phase` ("lobby", "round" or "results"; default "round") and
##   `settle`, the seconds to wait before the shot (default 0.8).
## - `enter(scene: Node, id: String) -> bool`: shows that screen on the
##   running game scene. Returning false skips the shot.
## - `leave(scene: Node, id: String)`: puts the game back afterwards.
func _load_hook() -> void:
	if not GameCatalog.is_single_game_build():
		return
	var manifest := GameCatalog.current()
	if manifest == null or not manifest.gameplay_scene_path.begins_with("res://games/"):
		return
	var folder := manifest.gameplay_scene_path.trim_prefix("res://games/").get_slice("/", 0)
	var path := HOOK_PATH % folder
	if not ResourceLoader.exists(path):
		return
	var script := load(path) as GDScript
	if script == null or not script.can_instantiate():
		_warn("%s could not be loaded." % path)
		return
	_hook = script.new()
	if _hook is Node:
		(_hook as Node).name = "ScreenHook"
		add_child(_hook as Node)
	_note("Loaded %s." % path)


## Gives the hook its one chance to seed, before any screen reads the profile.
func _seed_hook() -> void:
	if _hook == null or not _hook.has_method("seed_profile"):
		return
	var seeded: Variant = await _hook.call("seed_profile")
	if seeded is String and not (seeded as String).is_empty():
		_note(seeded)


func _run_hook(scene: Node, mode: String, phase: String) -> void:
	if _hook == null or _finished or not is_instance_valid(scene):
		return
	if not _hook.has_method("screens"):
		return
	var listed: Variant = await _hook.call("screens", mode)
	if not listed is Array:
		return
	for entry: Variant in listed:
		if _finished or not is_instance_valid(scene):
			return
		var spec: Dictionary = entry if entry is Dictionary else {"id": str(entry)}
		if str(spec.get("phase", "round")) != phase:
			continue
		var id := str(spec.get("id", ""))
		if id.is_empty():
			continue
		var entered: Variant = true
		if _hook.has_method("enter"):
			entered = await _hook.call("enter", scene, id)
		if entered is bool and not entered:
			_note("The game hook skipped %s while playing %s." % [id, mode])
		else:
			var settle: Variant = spec.get("settle", 0.8)
			await _settle(float(settle) if settle is int or settle is float else 0.8)
			await _shot("hook_%s_%s" % [mode, id], "game hook")
		if _hook.has_method("leave") and is_instance_valid(scene):
			await _hook.call("leave", scene, id)
		await _settle(0.2)
