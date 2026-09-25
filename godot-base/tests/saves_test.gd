extends SceneTree

## Framework regression checks for [GameSaves] and the Saves screen.
##
## A save is declared data — a game's share of the achievements and store
## wallet the framework keeps, plus the files its manifest lists in
## `save_files` — so these checks walk [method GameCatalog.all] and pick the
## games they exercise by what those games declare, never by name.
##
## Headless `--script` runs compile before autoloads exist, so [Store],
## [AchievementManager] and [Settings] are resolved from the tree and poked with
## `call`. [GameSaves] is named directly on purpose: it is a `class_name` script
## that touches no autoload instance, and this test is what keeps it that way.
##
## Every file a save can reach is copied first and written back byte for byte
## at the end, and backups go to a folder of the run's own, so a run never
## changes a player's progress or lists, writes or deletes their backups.

const SAVES_SCENE := "res://scenes/menus/saves.tscn"
const MAIN_MENU := "res://scenes/menus/main_menu.tscn"
## Long enough for every screen check; short enough that a hang still restores.
const WATCHDOG_SECONDS := 150.0
const STAMP := "2026-01-02T03:04:05"
const ORPHAN_ACHIEVEMENT := "saves_test_orphan_achievement"
const ORPHAN_GAME := "saves_test_absent_game"
const LAYOUTS: Array[Vector2i] = [
	Vector2i(1280, 720), Vector2i(390, 844), Vector2i(844, 390),
	Vector2i(2560, 1080), Vector2i(320, 568),
]

var _failures := PackedStringArray()
## `{ path: PackedByteArray }` for files that existed, `{ path: null }` for ones
## that did not, so the end of the run can put either back.
var _snapshots: Dictionary = {}
var _achievements: Node
var _store: Node
var _settings: Node
var _achievements_path := ""
var _unlocked_section := ""
var _original_settings: Dictionary = {}
var _original_size := Vector2i.ZERO
var _finished := false


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	_achievements = root.get_node_or_null("AchievementManager")
	_store = root.get_node_or_null("Store")
	_settings = root.get_node_or_null("Settings")
	if _achievements == null or _store == null or _settings == null:
		printerr("The Saves tests need the AchievementManager, Store and Settings autoloads.")
		quit(1)
		return
	if not GameCatalog.offers_a_choice():
		printerr("Run saves_test.gd with -- --game=all.")
		quit(1)
		return
	# Naming AchievementManager would pull its toast scene into this compile pass.
	var constants: Dictionary = _achievements.get_script().get_script_constant_map()
	_achievements_path = str(constants.get("SAVE_PATH", ""))
	_unlocked_section = str(constants.get("UNLOCKED_SECTION", ""))
	if _achievements_path.is_empty() or _unlocked_section.is_empty():
		printerr("AchievementManager no longer names its save file and section.")
		quit(1)
		return
	GameSaves.backup_root = "user://saves_test_backups_%d" % OS.get_process_id()
	_remove_tree(GameSaves.backup_root)
	_snapshot()
	_original_settings = (_settings.get("_values") as Dictionary).duplicate()
	_original_size = root.size
	_set_setting("ui/scale", 1.0)
	create_timer(WATCHDOG_SECONDS, true, false, true).timeout.connect(_on_watchdog)

	var subject := _pick_subject()
	if subject == null:
		_expect(false, (
			"No game declares achievements, a store and a save file of its own, "
			+ "so nothing here would be proved."
		))
		_finish()
		return
	_ran("declarations", _test_declarations())
	_ran("path rules", _test_path_rules())
	_ran("summary", _test_summary(subject))
	_ran("erase is surgical", _test_erase_is_surgical(subject))
	_ran("round trip", _test_round_trip(subject))
	_ran("restore replaces files", _test_restore_replaces_files(subject))
	_ran("refused backups", _test_refused_backups(subject))
	_ran("backup names and dates", _test_backup_names_and_dates(subject))
	_ran("delete backup", _test_delete_backup(subject))
	_ran("screen", await _test_screen(subject))
	_ran("screen layouts", await _test_screen_layouts(subject))
	_ran("empty state", await _test_empty_state())
	_ran("menu entry", await _test_menu_entry(subject.id))
	_ran("standalone", await _test_standalone(subject.id))
	# Menu sounds release their stopped playbacks on the mixer thread.
	await create_timer(0.25, true, false, true).timeout
	_finish()


## The richest save any listed game declares, so every part of a save is
## exercised on a card the screen really shows.
func _pick_subject() -> GameManifest:
	for manifest in GameCatalog.available():
		if (
			not manifest.achievements.is_empty()
			and bool(_store.call("has_store", manifest.id))
			and not GameSaves.save_files(manifest).is_empty()
		):
			return manifest
	return null


# --------------------------------------------------------------------------
# Declarations
# --------------------------------------------------------------------------


## A declaration GameSaves refuses would never be backed up or deleted, and the
## screen would not say so, so every shipped one has to pass validation.
func _test_declarations() -> bool:
	var declaring := 0
	var owners: Dictionary = {}
	for manifest in GameCatalog.all():
		var files := GameSaves.save_files(manifest)
		_expect(
			files.size() == manifest.save_files.size(),
			"%s declares a save file GameSaves refuses: %s" % [manifest.id, manifest.save_files]
		)
		if not files.is_empty():
			declaring += 1
		for entry in files:
			var path := str(entry["path"]).to_lower()
			_expect(
				not str(entry["title"]).is_empty(),
				"%s must name its save file '%s'." % [manifest.id, entry["path"]]
			)
			# Two games claiming one file would delete each other's progress.
			_expect(
				not owners.has(path),
				"%s and %s both claim %s." % [owners.get(path, ""), manifest.id, path]
			)
			owners[path] = manifest.id
	_expect(declaring > 0, "At least one game must declare a save file of its own.")
	return true


func _test_path_rules() -> bool:
	var folder := "user://saves_test_folder_%d" % OS.get_process_id()
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(folder))
	var refused := [
		"", "res://game.cfg", "C:/game.cfg", "user://", "user://../game.cfg",
		"user://a//b.cfg", "user://./game.cfg", "user://a\\b.cfg",
		Settings.SAVE_PATH, Store.SAVE_PATH, _achievements_path,
		_achievements_path.to_upper().replace("USER://", "user://"),
		GameSaves.backup_root, GameSaves.backup_root + "/some_game/backup.cfg", folder,
	]
	for path: String in refused:
		_expect(
			not GameSaves.path_problem(path).is_empty(),
			"'%s' must not be accepted as one game's own save file." % path
		)
	for path: String in ["user://a_game_history.cfg", "user://a_game/tags.cfg"]:
		_expect(
			GameSaves.path_problem(path).is_empty(),
			"'%s' is a plain game-owned file and must be accepted." % path
		)
	DirAccess.remove_absolute(ProjectSettings.globalize_path(folder))
	_expect(
		GameSaves.shared_files().has(_achievements_path)
		and GameSaves.shared_files().has(Store.SAVE_PATH)
		and GameSaves.shared_files().has(Settings.SAVE_PATH),
		"Every file that holds every game's data must be off limits to a single game."
	)

	var fixture := GameManifest.new()
	fixture.id = "saves_test_fixture"
	fixture.save_files = [
		{"path": Store.SAVE_PATH, "title": "Everybody's wallet"},
		{"path": "user://saves_test_fixture.cfg"},
		{"path": " user://saves_test_fixture.cfg "},
		{"path": "res://saves_test_fixture.cfg"},
	]
	var files := GameSaves.save_files(fixture)
	_expect(
		files.size() == 1
		and str(files[0]["path"]) == "user://saves_test_fixture.cfg"
		and not str(files[0]["title"]).is_empty(),
		(
			"Unusable and repeated declarations must be dropped, and a file "
			+ "declared without a title must still be named."
		)
	)
	return true


# --------------------------------------------------------------------------
# Changing a save
# --------------------------------------------------------------------------


func _test_summary(subject: GameManifest) -> bool:
	var ids := _achievement_ids(subject)
	_put(subject, [], 0, "")
	_expect(
		not GameSaves.has_save(subject)
		and not _ids(GameSaves.managed_games()).has(subject.id),
		"%s with nothing unlocked, earned or written must have no save." % subject.id
	)
	_put(subject, [ids[0]], 25, "history")
	var summary := GameSaves.summary(subject)
	var wallet: Dictionary = summary["store"]
	_expect(
		int(summary["achievements_unlocked"]) == 1
		and int(summary["achievements_total"]) == ids.size(),
		"The summary must count %s's unlocked achievements." % subject.id
	)
	_expect(
		int(wallet.get("points", -1)) == 25 and bool(wallet.get("has_progress", false))
		and str(wallet.get("points_text", "")) == str(_store.call("format_points", subject.id, 25)),
		"The summary must show %s's wallet in its own currency." % subject.id
	)
	_expect(
		(summary["files"] as Array).size() == GameSaves.save_files(subject).size(),
		"The summary must list the files %s has written." % subject.id
	)
	_expect(
		bool(summary["has_save"]) and _ids(GameSaves.managed_games()).has(subject.id),
		"A game with progress must be managed."
	)
	# Any one part is progress on its own.
	_put(subject, [], 0, "history")
	_expect(GameSaves.has_save(subject), "A game-owned file alone must count as a save.")
	_put(subject, [], 5, "")
	_expect(GameSaves.has_save(subject), "A wallet alone must count as a save.")
	_put(subject, [ids[0]], 0, "")
	_expect(GameSaves.has_save(subject), "An achievement alone must count as a save.")
	return true


## A save shares its files with every other game and with builds that ship
## other games, so deleting one must remove exactly that game's entries.
func _test_erase_is_surgical(subject: GameManifest) -> bool:
	var ids := _achievement_ids(subject)
	var other := _other_game_with_achievements(subject.id)
	var other_before: Dictionary = {}
	var other_id := ""
	if other != null:
		other_id = _achievement_ids(other)[0]
		other_before = _achievements.call("export_save", other.id)
		_achievements.call("import_save", other.id, {other_id: STAMP})
	_put(subject, [ids[0]], 40, "history")
	var shared := ConfigFile.new()
	shared.load(_achievements_path)
	shared.set_value(_unlocked_section, ORPHAN_ACHIEVEMENT, STAMP)
	shared.save(_achievements_path)
	var wallet := ConfigFile.new()
	wallet.load(Store.SAVE_PATH)
	wallet.set_value(Store.POINTS_SECTION, ORPHAN_GAME, 4200)
	wallet.save(Store.SAVE_PATH)
	var settings_before := _read(Settings.SAVE_PATH)

	_expect(GameSaves.erase(subject) == OK, "Deleting %s's save must succeed." % subject.id)
	_expect(not GameSaves.has_save(subject), "Deleting a save must leave nothing of it.")
	for entry in GameSaves.save_files(subject):
		_expect(
			not FileAccess.file_exists(str(entry["path"])),
			"Deleting a save must delete %s." % entry["path"]
		)
	_expect(
		not bool(_achievements.call("is_unlocked", ids[0]))
		and int(_store.call("points", subject.id)) == 0,
		"Deleting a save must lock its achievements and empty its wallet in memory."
	)
	var after := ConfigFile.new()
	after.load(_achievements_path)
	_expect(
		not after.has_section_key(_unlocked_section, ids[0]),
		"Deleting a save must lock its achievements on disk, not just until restart."
	)
	_expect(
		after.has_section_key(_unlocked_section, ORPHAN_ACHIEVEMENT),
		"Deleting one save must keep achievements this build does not know."
	)
	if other != null:
		_expect(
			bool(_achievements.call("is_unlocked", other_id))
			and after.has_section_key(_unlocked_section, other_id),
			"Deleting one game's save must not touch another game's achievements."
		)
		_achievements.call("import_save", other.id, other_before)
	var wallet_after := ConfigFile.new()
	wallet_after.load(Store.SAVE_PATH)
	_expect(
		int(wallet_after.get_value(Store.POINTS_SECTION, ORPHAN_GAME, 0)) == 4200
		and int(wallet_after.get_value(Store.POINTS_SECTION, subject.id, -1)) == 0,
		"Deleting a save must empty only that game's wallet on disk."
	)
	_expect(
		_read(Settings.SAVE_PATH) == settings_before,
		"Deleting a save must never touch options or key bindings."
	)
	return true


## Restoring replaces every part the backup captured: later unlocks are locked
## again and later purchases go, rather than being merged with the old save.
func _test_round_trip(subject: GameManifest) -> bool:
	var ids := _achievement_ids(subject)
	var bought := _first_paid_item(subject.id)
	var owned := PackedStringArray() if bought.is_empty() else PackedStringArray([bought])
	_put(subject, [ids[0]], 40, "before", owned)
	var path := GameSaves.back_up(subject)
	_expect(
		not path.is_empty() and FileAccess.file_exists(path)
		and path.get_base_dir() == GameSaves.backup_root.path_join(subject.id),
		"Backing up must write one file into the game's own backup folder."
	)
	var listed := GameSaves.backups(subject.id)
	_expect(
		listed.size() == 1 and bool(listed[0]["restorable"])
		and str(listed[0]["problem"]).is_empty() and not str(listed[0]["created"]).is_empty(),
		"A fresh backup must be listed, dated and restorable."
	)
	var settings_before := _read(Settings.SAVE_PATH)
	_put(subject, ids, 90, "after")
	_expect(GameSaves.restore(subject, path) == OK, "Restoring a fresh backup must succeed.")
	_expect(
		bool(_achievements.call("is_unlocked", ids[0]))
		and (ids.size() < 2 or not bool(_achievements.call("is_unlocked", ids[1]))),
		"Restoring must put achievements back as they were, locking later unlocks."
	)
	_expect(
		int(_store.call("points", subject.id)) == 40
		and (bought.is_empty() or bool(_store.call("is_owned", subject.id, bought))),
		"Restoring must put the wallet and purchases back as they were."
	)
	for entry in GameSaves.save_files(subject):
		var file_path := str(entry["path"])
		_expect(
			_read(file_path) == ("before:%s" % file_path).to_utf8_buffer(),
			"Restoring must put %s back byte for byte." % file_path
		)
		_expect(
			not FileAccess.file_exists(file_path + GameSaves.STAGING_SUFFIX),
			"Restoring must not leave a staged copy of %s behind." % file_path
		)
	_expect(
		_read(Settings.SAVE_PATH) == settings_before,
		"Restoring must never touch options or key bindings."
	)
	var check := ConfigFile.new()
	check.load(_achievements_path)
	_expect(
		check.has_section_key(_unlocked_section, ids[0])
		and (ids.size() < 2 or not check.has_section_key(_unlocked_section, ids[1])),
		"A restore must reach the achievements file, not just memory."
	)
	_expect(GameSaves.backups(subject.id).size() == 1, "Restoring must keep the backup.")
	_clear_backups(subject)
	return true


## A file that did not exist when the backup was made is part of what it
## recorded, while a file the game no longer declares is none of its business.
func _test_restore_replaces_files(subject: GameManifest) -> bool:
	_put(subject, [], 0, "")
	var path := GameSaves.back_up(subject)
	_expect(not path.is_empty(), "A game with nothing saved must still be able to back up.")
	var undeclared := "user://saves_test_undeclared_%d.cfg" % OS.get_process_id()
	var config := ConfigFile.new()
	config.load(path)
	var records: Array = config.get_value(GameSaves.DATA_SECTION, "files", [])
	records.append({"path": undeclared, "exists": true, "data": "x".to_utf8_buffer()})
	config.set_value(GameSaves.DATA_SECTION, "files", records)
	config.save(path)

	_put(subject, [_achievement_ids(subject)[0]], 10, "later")
	_expect(GameSaves.restore(subject, path) == OK, "Restoring an empty backup must succeed.")
	for entry in GameSaves.save_files(subject):
		_expect(
			not FileAccess.file_exists(str(entry["path"])),
			"Restoring must delete %s, which did not exist at the backup." % entry["path"]
		)
	_expect(not GameSaves.has_save(subject), "Restoring an empty backup must leave no save.")
	_expect(
		not FileAccess.file_exists(undeclared),
		"A restore must never write a file the game does not declare."
	)
	_remove(undeclared)
	_clear_backups(subject)
	return true


## A backup the screen cannot restore is still listed, with the reason, so the
## player can delete it; restoring it anyway must change nothing.
func _test_refused_backups(subject: GameManifest) -> bool:
	var ids := _achievement_ids(subject)
	_put(subject, [ids[0]], 7, "current")
	var folder := GameSaves.backup_root.path_join(subject.id)
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(folder))
	var declared := str(GameSaves.save_files(subject)[0]["path"])
	var cases := {
		"newer": [
			_backup_config(subject.id, GameSaves.BACKUP_FORMAT + 1, {}), GameSaves.PROBLEM_NEWER,
		],
		"elsewhere": [
			_backup_config(ORPHAN_GAME, GameSaves.BACKUP_FORMAT, {}), GameSaves.PROBLEM_OTHER_GAME,
		],
		"truncated": [
			_backup_config(
				subject.id, GameSaves.BACKUP_FORMAT,
				{"files": [{"path": declared, "exists": true}]}
			),
			GameSaves.PROBLEM_DAMAGED,
		],
		"mangled": [
			_backup_config(subject.id, GameSaves.BACKUP_FORMAT, {"achievements": "all of them"}),
			GameSaves.PROBLEM_DAMAGED,
		],
	}
	for name: String in cases:
		(cases[name][0] as ConfigFile).save(folder.path_join("%s.cfg" % name))
	var stray := ConfigFile.new()
	stray.set_value("notes", "text", "Not a backup at all.")
	stray.save(folder.path_join("stray.cfg"))
	cases["stray"] = [stray, GameSaves.PROBLEM_UNREADABLE]
	_write(folder.path_join("unreadable.cfg"), "[[[ this is not a config file")
	cases["unreadable"] = [null, GameSaves.PROBLEM_UNREADABLE]

	var listed: Dictionary = {}
	for backup in GameSaves.backups(subject.id):
		listed[str(backup["path"]).get_file().get_basename()] = backup
	for name: String in cases:
		var backup: Dictionary = listed.get(name, {})
		var problem := str(cases[name][1])
		_expect(
			not backup.is_empty() and not bool(backup["restorable"])
			and str(backup["problem"]) == problem,
			"A %s backup must be listed as not restorable: %s" % [name, problem]
		)
		var path := folder.path_join("%s.cfg" % name)
		_expect(GameSaves.restore(subject, path) != OK, "A %s backup must be refused." % name)
		_expect(
			bool(_achievements.call("is_unlocked", ids[0]))
			and int(_store.call("points", subject.id)) == 7
			and _read(declared) == ("current:%s" % declared).to_utf8_buffer(),
			"Refusing a %s backup must leave the current save exactly as it was." % name
		)
		_expect(
			GameSaves.delete_backup(subject, path) == OK and not FileAccess.file_exists(path),
			"A %s backup must still be deletable." % name
		)

	# Only files directly inside the game's own backup folder can be reached.
	_expect(
		GameSaves.restore(subject, Store.SAVE_PATH) == ERR_FILE_BAD_PATH
		and GameSaves.delete_backup(subject, Store.SAVE_PATH) == ERR_FILE_BAD_PATH
		and FileAccess.file_exists(Store.SAVE_PATH),
		"Restore and delete must refuse a path outside the game's backup folder."
	)
	var other := _other_game_with_achievements(subject.id)
	if other != null:
		var foreign := GameSaves.back_up(other)
		_expect(
			GameSaves.restore(subject, foreign) == ERR_FILE_BAD_PATH
			and GameSaves.delete_backup(subject, foreign) == ERR_FILE_BAD_PATH
			and FileAccess.file_exists(foreign),
			"One game must not restore or delete another game's backup."
		)
		_clear_backups(other)
	_clear_backups(subject)
	return true


func _test_backup_names_and_dates(subject: GameManifest) -> bool:
	_put(subject, [], 3, "")
	var first := GameSaves.back_up(subject)
	var second := GameSaves.back_up(subject)
	_expect(
		not first.is_empty() and not second.is_empty() and first != second
		and FileAccess.file_exists(first) and FileAccess.file_exists(second),
		"Two backups made within a second must not overwrite each other."
	)
	var listed := GameSaves.backups(subject.id)
	_expect(
		listed.size() == 2 and str(listed[0]["path"]) == second,
		"Backups must be listed newest first."
	)
	_expect(
		GameSaves.backup_date_text({"created": "2026-09-25T06:10:33"}) == "25 Sep 2026 · 06:10:33",
		"A backup date must read the way a person writes it."
	)
	var pattern := RegEx.create_from_string(
		"^\\d{1,2} [A-Z][a-z]{2} \\d{4} · \\d{2}:\\d{2}:\\d{2}$"
	)
	var fallback := GameSaves.backup_date_text({"created": "garbled", "created_unix": 1790000000.0})
	_expect(
		pattern.search(fallback) != null and fallback.contains(" 2026 · "),
		"An unreadable date must fall back to the file's own time, not '%s'." % fallback
	)
	_clear_backups(subject)
	return true


func _test_delete_backup(subject: GameManifest) -> bool:
	_put(subject, [], 3, "")
	var path := GameSaves.back_up(subject)
	_expect(GameSaves.has_backups(subject.id), "A backup must be found once made.")
	_expect(
		GameSaves.delete_backup(subject, path) == OK and not FileAccess.file_exists(path)
		and not GameSaves.has_backups(subject.id),
		"Deleting a backup must remove it."
	)
	_expect(
		not DirAccess.dir_exists_absolute(GameSaves.backup_root.path_join(subject.id))
		and not DirAccess.dir_exists_absolute(GameSaves.backup_root),
		"Deleting the last backup must not leave empty folders behind."
	)
	_expect(
		int(_store.call("points", subject.id)) == 3,
		"Deleting a backup must not touch the current save."
	)
	return true


# --------------------------------------------------------------------------
# The screen
# --------------------------------------------------------------------------


func _test_screen(subject: GameManifest) -> bool:
	var ids := _achievement_ids(subject)
	_put(subject, [ids[0]], 30, "screen")
	GameSaves.back_up(subject)
	var screen := await _open(SAVES_SCENE)
	if screen == null:
		return true
	var cards := screen.get_node("%Cards")
	_expect(
		cards.get_child_count() == GameSaves.managed_games().size(),
		"The Saves screen must list exactly the games with something to manage."
	)
	var card := _card(screen, subject.id)
	if card == null:
		_expect(false, "The Saves screen must list %s, which has a save." % subject.id)
		await _close(screen)
		return true
	var details := card.get_node("Layout/Details") as Label
	_expect(
		(card.get_node("Layout/Title") as Label).text == subject.title
		and details.text.contains("Achievements: 1 of %d" % ids.size())
		and details.text.contains(str(_store.call("format_points", subject.id, 30)))
		and details.text.contains(str(GameSaves.save_files(subject)[0]["title"])),
		"The card must say what %s's save holds." % subject.id
	)
	var described := false
	for entry in GameSaves.save_files(subject):
		described = described or not str(entry["description"]).is_empty()
	_expect(
		not described or (
			not details.tooltip_text.is_empty()
			and details.accessibility_description == details.tooltip_text
		),
		"The card must describe the game's own files for assistive technology."
	)
	var focus := screen.get_viewport().gui_get_focus_owner()
	_expect(focus is Button, "The Saves screen must open on something the player can press.")
	var status := screen.get_node("%Status") as Label
	var confirm := screen.get_node("%Confirm") as Control
	var cancel := screen.get_node("%CancelButton") as Button
	var accept := screen.get_node("%ConfirmButton") as Button

	# Backing up loses nothing, so it is the one action that does not ask.
	var back_up := card.get_node("Layout/Actions/BackUpButton") as Button
	back_up.grab_focus()
	back_up.emit_signal("pressed")
	await process_frame
	card = _card(screen, subject.id)
	_expect(
		not confirm.visible and GameSaves.backups(subject.id).size() == 2
		and card.get_node("Layout/Backups").get_child_count() == 2,
		"Back up must add a listed backup without asking."
	)
	_expect(
		screen.get_viewport().gui_get_focus_owner() == card.get_node("Layout/Actions/BackUpButton"),
		"Focus must stay on Back up when the list is rebuilt."
	)
	_expect(
		status.visible and status.text.contains(subject.title),
		"Every change must be confirmed in words, not only by the list changing."
	)

	var delete := card.get_node("Layout/Actions/DeleteSaveButton") as Button
	delete.grab_focus()
	delete.emit_signal("pressed")
	await process_frame
	var message := (screen.get_node("%ConfirmMessage") as Label).text
	_expect(
		confirm.visible and cancel.has_focus(),
		"Deleting a save must ask first, with the safe answer focused."
	)
	_expect(
		message.contains("Achievements: 1 of") and message.contains("Backups are kept")
		and message.contains("Options and key bindings are not affected"),
		"The question must say what will be deleted and what will not."
	)
	_expect(
		cancel.focus_neighbor_left == cancel.get_path_to(accept)
		and cancel.focus_next == cancel.get_path_to(accept)
		and accept.focus_neighbor_right == accept.get_path_to(cancel)
		and accept.focus_previous == accept.get_path_to(cancel),
		"Focus must not wander from the question into the list behind it."
	)
	var escape := InputEventAction.new()
	escape.action = &"ui_cancel"
	escape.pressed = true
	# Input is delivered at once, so this is judged before a closing screen is
	# freed at the end of the frame.
	root.push_input(escape)
	_expect(
		not confirm.visible and not bool(screen.get("_closing"))
		and not screen.is_queued_for_deletion(),
		"Escape must close the question, not the Saves screen."
	)
	if screen.is_queued_for_deletion():
		return true
	_expect(
		GameSaves.has_save(subject) and delete.has_focus(),
		"Backing out must delete nothing and return focus to the button that asked."
	)
	await process_frame

	delete.emit_signal("pressed")
	await process_frame
	accept.emit_signal("pressed")
	await process_frame
	card = _card(screen, subject.id)
	_expect(
		not confirm.visible and not GameSaves.has_save(subject),
		"Confirming must delete the save."
	)
	_expect(
		card != null and card.get_node_or_null("Layout/Actions") == null
		and card.get_node_or_null("Layout/Backups") != null,
		"A game with backups keeps its card, without the actions for a save it lacks."
	)
	if card == null:
		await _close(screen)
		return true
	var owner := screen.get_viewport().gui_get_focus_owner()
	_expect(
		owner != null and card.is_ancestor_of(owner),
		"Focus must stay in the card when the button it was on has gone."
	)
	_expect(status.text.contains("backups are kept"), "Deleting must say the backups remain.")

	var restore := card.get_node("Layout/Backups").get_child(0).get_node(
		"Buttons/RestoreButton"
	) as Button
	_expect(
		not restore.disabled and restore.accessibility_name.begins_with("Restore backup from "),
		"Each Restore button must name the backup it restores."
	)
	restore.grab_focus()
	restore.emit_signal("pressed")
	await process_frame
	_expect(confirm.visible and cancel.has_focus(), "Restoring must ask first.")
	accept.emit_signal("pressed")
	await process_frame
	card = _card(screen, subject.id)
	_expect(
		GameSaves.has_save(subject) and int(_store.call("points", subject.id)) == 30
		and card != null and card.get_node_or_null("Layout/Actions") != null,
		"Restoring from the screen must bring the save, and its actions, back."
	)

	if card != null:
		var count := GameSaves.backups(subject.id).size()
		var remove := card.get_node("Layout/Backups").get_child(0).get_node(
			"Buttons/DeleteBackupButton"
		) as Button
		remove.grab_focus()
		remove.emit_signal("pressed")
		await process_frame
		_expect(confirm.visible, "Deleting a backup must ask first.")
		accept.emit_signal("pressed")
		await process_frame
		_expect(
			GameSaves.backups(subject.id).size() == count - 1
			and GameSaves.has_save(subject),
			"Deleting a backup must remove exactly one, and not the save."
		)
	await _close(screen)
	_clear_backups(subject)
	return true


func _test_screen_layouts(subject: GameManifest) -> bool:
	_put(subject, [_achievement_ids(subject)[0]], 30, "layout")
	GameSaves.back_up(subject)
	var screen := await _open(SAVES_SCENE)
	if screen == null:
		return true
	var scroll := screen.get_node("%Scroll") as Control
	for dimensions in LAYOUTS:
		root.size = dimensions
		for _frame in 5:
			await process_frame
		var bounds := screen.get_global_rect()
		var card := _card(screen, subject.id)
		var buttons: Array[Button] = [
			screen.get_node("%FolderButton") as Button, screen.get_node("%BackButton") as Button,
		]
		if card != null:
			for node in card.find_children("*", "Button", true, false):
				buttons.append(node as Button)
		for button in buttons:
			if not button.is_visible_in_tree():
				continue
			button.grab_focus()
			for _frame in 3:
				await process_frame
			var rect := button.get_global_rect()
			var pixels := rect.size.y * dimensions.x / bounds.size.x
			_expect(
				pixels >= 44.0,
				"%s must keep a 44px touch target at %s, not %.1fpx."
				% [button.name, dimensions, pixels]
			)
			_expect(
				bounds.grow(1.0).encloses(rect),
				"%s must stay on screen at %s." % [button.name, dimensions]
			)
			if card != null and card.is_ancestor_of(button):
				_expect(
					scroll.get_global_rect().grow(1.0).encloses(rect),
					"Focus must scroll %s into view at %s." % [button.name, dimensions]
				)

		# The question has to fit, and be answerable, on the same screens.
		if card != null:
			var delete := card.get_node("Layout/Actions/DeleteSaveButton") as Button
			delete.grab_focus()
			delete.emit_signal("pressed")
			for _frame in 3:
				await process_frame
			_expect(
				(screen.get_node("%Confirm") as Control).visible,
				"Delete save must ask first at %s." % dimensions
			)
			for name: String in ["%CancelButton", "%ConfirmButton"]:
				var answer := screen.get_node(name) as Button
				answer.grab_focus()
				for _frame in 3:
					await process_frame
				var rect := answer.get_global_rect()
				var pixels := rect.size.y * dimensions.x / bounds.size.x
				_expect(
					pixels >= 44.0 and bounds.grow(1.0).encloses(rect),
					"%s must be a reachable 44px target at %s, not %.1fpx."
					% [answer.name, dimensions, pixels]
				)
			screen.call("go_back")
			if screen.is_queued_for_deletion():
				_expect(false, "Back must close the question at %s, not the screen." % dimensions)
				return true
			await process_frame
	root.size = Vector2i(1280, 720)
	await process_frame
	await _close(screen)
	_clear_backups(subject)
	return true


## Nothing saved anywhere: the screen says so, and the title screen stops
## offering it. Every save here is erased; the snapshot puts them back.
func _test_empty_state() -> bool:
	for manifest in GameCatalog.all():
		GameSaves.erase(manifest)
		_clear_backups(manifest)
	_expect(
		GameSaves.managed_games().is_empty(),
		"With nothing saved and no backups, no game has anything to manage."
	)
	var screen := await _open(SAVES_SCENE)
	if screen != null:
		_expect(
			(screen.get_node("%Empty") as Control).visible
			and not (screen.get_node("%Scroll") as Control).visible
			and screen.get_node("%Cards").get_child_count() == 0,
			"An empty Saves screen must say that nothing is saved."
		)
		_expect(
			screen.get_viewport().gui_get_focus_owner() == screen.get_node("%BackButton"),
			"An empty Saves screen must still open on a way back."
		)
		await _close(screen)
	var menu := await _open(MAIN_MENU)
	if menu != null:
		_expect(
			not (menu.get_node("%SavesButton") as Button).visible,
			"The title screen must not offer Saves when there is nothing to manage."
		)
		await _close(menu)
	return true


func _test_menu_entry(subject_id: String) -> bool:
	var subject := GameCatalog.get_manifest(subject_id)
	_put(subject, [], 0, "")
	var backup := GameSaves.back_up(subject)
	var menu := await _open(MAIN_MENU)
	if menu == null:
		return true
	var button := menu.get_node("%SavesButton") as Button
	_expect(
		button.visible and not button.accessibility_description.is_empty()
		and (menu.get("_menu_buttons") as Array).has(button),
		"A backup alone must keep Saves on the title screen, as a real menu row."
	)
	_expect(
		str(menu.get("saves_scene")) == SAVES_SCENE,
		"The title screen's Saves row must lead to the Saves screen."
	)
	await _close(menu)
	GameSaves.delete_backup(subject, backup)

	_put(subject, [_achievement_ids(subject)[0]], 0, "")
	menu = await _open(MAIN_MENU)
	if menu != null:
		_expect(
			(menu.get_node("%SavesButton") as Button).visible,
			"A collection must offer Saves as soon as any game has progress."
		)
		await _close(menu)
	return true


## A standalone build is one game's product, so it manages that game's save
## and nothing else, however much another game has saved on the same device.
func _test_standalone(subject_id: String) -> bool:
	var subject := GameCatalog.get_manifest(subject_id)
	var other := _other_game_with_achievements(subject_id)
	# Chosen while the catalog still holds every game: a pinned one holds one.
	var bare := ""
	for manifest in GameCatalog.all():
		if manifest.id != subject_id and (other == null or manifest.id != other.id):
			bare = manifest.id
			GameSaves.erase(manifest)
			_clear_backups(manifest)
			break
	_put(subject, [_achievement_ids(subject)[0]], 12, "standalone")
	if other != null:
		_achievements.call("import_save", other.id, {_achievement_ids(other)[0]: STAMP})
	_expect(GameCatalog.restrict_to(subject_id), "The catalog must pin %s." % subject_id)
	var managed := GameSaves.managed_games()
	_expect(
		managed.size() == 1 and managed[0].id == subject_id,
		"A standalone %s build must manage only its own save." % subject_id
	)
	var screen := await _open(SAVES_SCENE)
	if screen != null:
		var title := GameCatalog.get_manifest(subject_id).title
		_expect(
			screen.get_node("%Cards").get_child_count() == 1
			and _card(screen, subject_id) != null
			and (screen.get_node("%Intro") as Label).text.contains(title),
			"A standalone Saves screen must show one card, for its own game."
		)
		await _close(screen)
	var menu := await _open(MAIN_MENU)
	if menu != null:
		var button := menu.get_node("%SavesButton") as Button
		_expect(
			button.visible and button.tooltip_text.contains(subject.title),
			"A standalone title screen must offer to manage its own game's save."
		)
		await _close(menu)

	# A game with nothing saved hides Saves, whatever other games have saved.
	_expect(not bare.is_empty(), "The standalone checks need a third game with no save.")
	if not bare.is_empty() and GameCatalog.restrict_to(bare):
		_expect(
			GameSaves.managed_games().is_empty(),
			"A standalone build must not manage other games' progress."
		)
		menu = await _open(MAIN_MENU)
		if menu != null:
			_expect(
				not (menu.get_node("%SavesButton") as Button).visible,
				"A standalone build must not offer Saves for other games' progress."
			)
			await _close(menu)
	GameCatalog.clear_restriction()
	return true


# --------------------------------------------------------------------------
# Helpers
# --------------------------------------------------------------------------


## Replaces [param manifest]'s whole save through the same calls a restore uses.
## [param contents] goes into every file the game declares, tagged with the
## file's path; "" deletes them instead.
func _put(
	manifest: GameManifest, unlocked: Array, points: int, contents: String,
	owned := PackedStringArray()
) -> void:
	var unlocks: Dictionary = {}
	for id: Variant in unlocked:
		unlocks[str(id)] = STAMP
	_expect(
		int(_achievements.call("import_save", manifest.id, unlocks)) == OK
		and int(_store.call("import_save", manifest.id, {"points": points, "owned": owned}))
		== OK,
		"Could not set up %s's save." % manifest.id
	)
	for entry in GameSaves.save_files(manifest):
		var path := str(entry["path"])
		if contents.is_empty():
			_remove(path)
		else:
			_write(path, "%s:%s" % [contents, path])


func _backup_config(game_id: String, format: int, data: Dictionary) -> ConfigFile:
	var config := ConfigFile.new()
	config.set_value(GameSaves.BACKUP_SECTION, "format", format)
	config.set_value(GameSaves.BACKUP_SECTION, "game_id", game_id)
	config.set_value(GameSaves.BACKUP_SECTION, "created", STAMP)
	for key: String in data:
		config.set_value(GameSaves.DATA_SECTION, key, data[key])
	return config


func _clear_backups(manifest: GameManifest) -> void:
	for backup in GameSaves.backups(manifest.id):
		GameSaves.delete_backup(manifest, str(backup["path"]))


func _achievement_ids(manifest: GameManifest) -> Array[String]:
	var ids: Array[String] = []
	for raw_id: Variant in manifest.achievements:
		ids.append(str(raw_id))
	return ids


func _other_game_with_achievements(game_id: String) -> GameManifest:
	for manifest in GameCatalog.all():
		if manifest.id != game_id and not manifest.achievements.is_empty():
			return manifest
	return null


func _first_paid_item(game_id: String) -> String:
	for item: Dictionary in _store.call("items", game_id):
		if not bool(item.get("default", false)):
			return str(item["id"])
	return ""


func _ids(manifests: Array[GameManifest]) -> PackedStringArray:
	var ids := PackedStringArray()
	for manifest in manifests:
		ids.append(manifest.id)
	return ids


func _card(screen: Node, game_id: String) -> Control:
	return screen.get_node("%Cards").get_node_or_null("Card_%s" % game_id) as Control


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
	if not is_instance_valid(screen):
		return
	if screen.is_inside_tree():
		root.remove_child(screen)
	screen.queue_free()
	await process_frame


func _set_setting(key: String, value: Variant) -> void:
	var values: Dictionary = (_settings.get("_values") as Dictionary).duplicate()
	values[key] = value
	_settings.set("_values", values)
	_settings.emit_signal("changed", key, value)


func _read(path: String) -> PackedByteArray:
	if not FileAccess.file_exists(path):
		return PackedByteArray()
	var file := FileAccess.open(path, FileAccess.READ)
	return PackedByteArray() if file == null else file.get_buffer(file.get_length())


func _write(path: String, text: String) -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(path.get_base_dir()))
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		_expect(false, "Could not write %s." % path)
		return
	file.store_string(text)


func _remove(path: String) -> void:
	if FileAccess.file_exists(path):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(path))


func _remove_tree(path: String) -> void:
	var directory := DirAccess.open(path)
	if directory == null:
		return
	directory.include_hidden = true
	for file in directory.get_files():
		DirAccess.remove_absolute(ProjectSettings.globalize_path(path.path_join(file)))
	for folder in directory.get_directories():
		_remove_tree(path.path_join(folder))
	directory = null
	DirAccess.remove_absolute(ProjectSettings.globalize_path(path))


## Every file a save can reach: the shared files and each game's own.
func _snapshot() -> void:
	var paths := Array(GameSaves.shared_files())
	for manifest in GameCatalog.all():
		for entry in GameSaves.save_files(manifest):
			paths.append(str(entry["path"]))
	for path: String in paths:
		_snapshots[path] = _read(path) if FileAccess.file_exists(path) else null


func _restore_snapshots() -> void:
	for path: String in _snapshots:
		var bytes: Variant = _snapshots[path]
		_remove(path + GameSaves.STAGING_SUFFIX)
		if bytes == null:
			_remove(path)
			continue
		var file := FileAccess.open(path, FileAccess.WRITE)
		if file == null:
			printerr("Could not put %s back; it may need restoring by hand." % path)
			continue
		file.store_buffer(bytes)


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)


## A script error ends a test function early, returning its default — false —
## while the run carries on, so a crashed check would otherwise pass by never
## being made.
func _ran(checks: String, finished: bool) -> void:
	_expect(finished, "The %s checks stopped early; see the script error above." % checks)


func _on_watchdog() -> void:
	if _finished:
		return
	_failures.append("The Saves tests did not finish within %d seconds." % WATCHDOG_SECONDS)
	_finish()


func _finish() -> void:
	if _finished:
		return
	_finished = true
	GameCatalog.clear_restriction()
	root.size = _original_size
	_settings.set("_values", _original_settings)
	_restore_snapshots()
	_remove_tree(GameSaves.backup_root)
	GameSaves.backup_root = GameSaves.DEFAULT_BACKUP_ROOT
	for failure: String in _failures:
		printerr(failure)
	if _failures.is_empty():
		print("Saves: all checks passed.")
	quit(0 if _failures.is_empty() else 1)
