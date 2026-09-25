class_name GameSaves
extends RefCounted

## One game's save, as the Saves screen manages it: that game's share of the
## achievements and store wallet the framework keeps for every game, plus the
## files of its own it lists in [member GameManifest.save_files].
##
## Static, like [GameCatalog], and for the same reason: the main menu, the Saves
## screen and headless tests all need it, and a test compiles before any
## autoload exists. [AchievementManager] and [Store] are therefore resolved from
## the tree rather than named.
##
## Options are never part of a save. `settings.cfg` keeps every game's tunables
## and key bindings beside the player's display and accessibility choices, and a
## player deleting their progress has not asked to lose any of those.
##
## Unlock progress toward a gated game is left out too. It records play in
## *another* game, and an unlock must never regress, so no delete or restore
## here can lock a game the player has already opened.
##
## A backup is one `ConfigFile` per snapshot in `<backup_root>/<game_id>/`,
## holding only that game's data. Restoring one cannot touch another game, and
## deleting a save leaves its backups where they are.

## Bumped when a backup's layout changes in a way an older build cannot read.
const BACKUP_FORMAT := 1
const DEFAULT_BACKUP_ROOT := "user://save_backups"
const BACKUP_EXTENSION := "cfg"
const BACKUP_SECTION := "backup"
const DATA_SECTION := "data"
## Suffix of a file being restored until every file has been written.
const STAGING_SUFFIX := ".restoring"

const PROBLEM_UNREADABLE := "This backup cannot be read."
const PROBLEM_NEWER := "Made by a newer version of this game."
const PROBLEM_OTHER_GAME := "This backup belongs to another game."
const PROBLEM_DAMAGED := "This backup is damaged."

const MONTHS := [
	"Jan", "Feb", "Mar", "Apr", "May", "Jun",
	"Jul", "Aug", "Sep", "Oct", "Nov", "Dec",
]

## Where backups are kept. Tests point it elsewhere, so a run never lists,
## writes or deletes a player's own backups.
static var backup_root := DEFAULT_BACKUP_ROOT

## Declarations already reported as unusable, so a bad path warns once instead
## of every time a menu asks what is saved.
static var _reported: Dictionary = {}


# --------------------------------------------------------------------------
# What is saved
# --------------------------------------------------------------------------


## The games a Saves screen lists: every available game with progress on this
## device or a backup to go back to, in menu order. A standalone build only ever
## has its own game to offer, because [method GameCatalog.available] does.
static func managed_games() -> Array[GameManifest]:
	var result: Array[GameManifest] = []
	for manifest in GameCatalog.available():
		if has_backups(manifest.id) or has_save(manifest):
			result.append(manifest)
	return result


## True when [param manifest] has any progress on this device.
static func has_save(manifest: GameManifest) -> bool:
	return bool(summary(manifest)["has_save"])


## What [param manifest]'s save holds on this device:
## [codeblock]
## {
##     "achievements_unlocked": 3,
##     "achievements_total": 12,
##     "store": {},       # Store.save_summary(), or {} when it sells nothing
##     "files": [],       # the declared files that exist, as save_files() has them
##     "has_save": true,  # any of the above is progress
## }
## [/codeblock]
static func summary(manifest: GameManifest) -> Dictionary:
	var unlocked := 0
	var total := 0
	var manager := _autoload("AchievementManager")
	if manager != null:
		var achievements: Dictionary = manager.call("save_summary", manifest.id)
		unlocked = int(achievements.get("unlocked", 0))
		total = int(achievements.get("total", 0))
	var store: Dictionary = {}
	var shop := _autoload("Store")
	if shop != null:
		var wallet: Dictionary = shop.call("save_summary", manifest.id)
		if bool(wallet.get("has_store", false)):
			store = wallet
	var files: Array[Dictionary] = []
	for entry in save_files(manifest):
		if FileAccess.file_exists(str(entry["path"])):
			files.append(entry)
	return {
		"achievements_unlocked": unlocked,
		"achievements_total": total,
		"store": store,
		"files": files,
		"has_save": (
			unlocked > 0 or bool(store.get("has_progress", false)) or not files.is_empty()
		),
	}


## [param manifest]'s declared files as `{ path, title, description }`, with
## every entry this class must not touch left out and reported once: see
## [method path_problem].
static func save_files(manifest: GameManifest) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	if manifest == null:
		return result
	var seen := PackedStringArray()
	for raw_entry: Variant in manifest.save_files:
		var entry: Dictionary = raw_entry if typeof(raw_entry) == TYPE_DICTIONARY else {}
		var path := str(entry.get("path", "")).strip_edges()
		var problem := path_problem(path)
		if not problem.is_empty():
			_report(manifest.id, path, problem)
			continue
		if seen.has(path):
			continue
		seen.append(path)
		var title := str(entry.get("title", "")).strip_edges()
		result.append({
			"path": path,
			"title": title if not title.is_empty() else path.get_file().get_basename().capitalize(),
			"description": str(entry.get("description", "")).strip_edges(),
		})
	return result


## Why [param path] cannot be one game's own save file, or "" when it can be.
##
## It has to be a plain file under `user://`: nothing that climbs out of it, not
## a folder, not one of [method shared_files] — they hold every game's data —
## and not a backup, which would then back itself up.
static func path_problem(path: String) -> String:
	const PREFIX := "user://"
	if not path.begins_with(PREFIX):
		return "a save file must be under user://"
	var relative := path.trim_prefix(PREFIX)
	if relative.is_empty() or relative.contains("\\") or relative.contains(":"):
		return "a save file needs a plain path under user://"
	for part in relative.split("/"):
		if part.is_empty() or part == "." or part == "..":
			return "a save file needs a plain path under user://"
	var lowered := path.to_lower()
	for shared in shared_files():
		if lowered == shared.to_lower():
			return "that file holds every game's data"
	var root := backup_root.trim_suffix("/").to_lower()
	if lowered == root or lowered.begins_with(root + "/"):
		return "that is where backups are kept"
	if DirAccess.dir_exists_absolute(path):
		return "that is a folder"
	return ""


## The framework's own saves. Each holds every game's data, so no game can claim
## one as its own: deleting that game's save would delete everybody's.
static func shared_files() -> PackedStringArray:
	return PackedStringArray([
		Settings.SAVE_PATH,
		# Naming this autoload would pull its toast scene into a headless test's
		# compile pass, which runs before autoloads exist.
		_constant("AchievementManager", "SAVE_PATH", "user://achievements.cfg"),
		Store.SAVE_PATH,
	])


# --------------------------------------------------------------------------
# Changing a save
# --------------------------------------------------------------------------


## Deletes [param manifest]'s save: locks its achievements, returns its wallet
## to the free defaults and removes its declared files. Its backups stay.
##
## Every part is attempted even when an earlier one fails, so one unreadable
## file cannot leave the rest of a save behind; the first error is returned.
static func erase(manifest: GameManifest) -> Error:
	var first := OK
	var manager := _autoload("AchievementManager")
	if manager != null:
		first = _first_error(first, manager.call("erase_save", manifest.id))
	var shop := _autoload("Store")
	if shop != null:
		first = _first_error(first, shop.call("erase_save", manifest.id))
	for entry in save_files(manifest):
		first = _first_error(first, _remove_file(str(entry["path"])))
	return first


## Snapshots [param manifest]'s save and returns the new backup's path, or ""
## when it could not be written.
static func back_up(manifest: GameManifest) -> String:
	var folder := _backup_folder(manifest.id)
	var err := DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(folder))
	if err != OK:
		push_warning("GameSaves: could not create %s (error %d)." % [folder, err])
		return ""
	var config := ConfigFile.new()
	config.set_value(BACKUP_SECTION, "format", BACKUP_FORMAT)
	config.set_value(BACKUP_SECTION, "game_id", manifest.id)
	config.set_value(BACKUP_SECTION, "title", manifest.title)
	config.set_value(BACKUP_SECTION, "created", Time.get_datetime_string_from_system())
	config.set_value(BACKUP_SECTION, "created_unix", Time.get_unix_time_from_system())
	config.set_value(BACKUP_SECTION, "app_version", StudioInfo.version())
	var manager := _autoload("AchievementManager")
	if manager != null:
		config.set_value(DATA_SECTION, "achievements", manager.call("export_save", manifest.id))
	var shop := _autoload("Store")
	if shop != null:
		var wallet: Dictionary = shop.call("export_save", manifest.id)
		if not wallet.is_empty():
			config.set_value(DATA_SECTION, "store", wallet)
	# Every declared file is recorded, present or not, so a restore can also
	# put back the absence of one that was created later.
	var files: Array = []
	for entry in save_files(manifest):
		var path := str(entry["path"])
		if not FileAccess.file_exists(path):
			files.append({"path": path, "exists": false})
			continue
		var file := FileAccess.open(path, FileAccess.READ)
		if file == null:
			push_warning(
				"GameSaves: could not read %s (error %d)." % [path, FileAccess.get_open_error()]
			)
			return ""
		files.append({"path": path, "exists": true, "data": file.get_buffer(file.get_length())})
	config.set_value(DATA_SECTION, "files", files)
	var target := _unused_backup_path(folder)
	err = config.save(target)
	if err != OK:
		push_warning("GameSaves: could not write %s (error %d)." % [target, err])
		_remove_file(target)
		return ""
	return target


## Puts [param manifest]'s save back the way the backup at [param path] found
## it. Every part the backup holds is replaced outright — an achievement
## unlocked since is locked again, a file that did not exist then is deleted —
## while a part it never captured is left alone. A file the game no longer
## declares is never written, whatever the backup says.
##
## The game's own files are staged beside their targets first, so running out of
## space leaves the current save untouched. After that every part is attempted,
## and the first error is returned.
static func restore(manifest: GameManifest, path: String) -> Error:
	if not _is_backup_of(manifest.id, path):
		return ERR_FILE_BAD_PATH
	var config := ConfigFile.new()
	var err := config.load(path)
	if err != OK:
		return err
	if not _backup_problem(config, manifest.id).is_empty():
		return ERR_INVALID_DATA
	var declared := PackedStringArray()
	for entry in save_files(manifest):
		declared.append(str(entry["path"]))
	var staged: Dictionary = {}
	var removals := PackedStringArray()
	for raw_record: Variant in config.get_value(DATA_SECTION, "files", []):
		var record: Dictionary = raw_record
		var target := str(record["path"])
		if not declared.has(target) or staged.has(target) or removals.has(target):
			continue
		if not bool(record.get("exists", false)):
			removals.append(target)
			continue
		var staging := target + STAGING_SUFFIX
		err = _write_bytes(staging, record["data"])
		if err != OK:
			_remove_file(staging)
			for staged_path: Variant in staged.values():
				_remove_file(str(staged_path))
			return err
		staged[target] = staging

	var first := OK
	for target: String in staged:
		var moved := DirAccess.rename_absolute(
			ProjectSettings.globalize_path(str(staged[target])),
			ProjectSettings.globalize_path(target)
		)
		if moved != OK:
			_remove_file(str(staged[target]))
		first = _first_error(first, moved)
	for target in removals:
		first = _first_error(first, _remove_file(target))
	var manager := _autoload("AchievementManager")
	if manager != null and config.has_section_key(DATA_SECTION, "achievements"):
		first = _first_error(first, manager.call(
			"import_save", manifest.id, config.get_value(DATA_SECTION, "achievements")
		))
	var shop := _autoload("Store")
	if shop != null and config.has_section_key(DATA_SECTION, "store"):
		first = _first_error(first, shop.call(
			"import_save", manifest.id, config.get_value(DATA_SECTION, "store")
		))
	return first


# --------------------------------------------------------------------------
# Backups
# --------------------------------------------------------------------------


## True when [param game_id] has at least one backup file, readable or not.
static func has_backups(game_id: String) -> bool:
	return not _backup_files(game_id).is_empty()


## [param game_id]'s backups, newest first, each as
## `{ path, created, created_unix, app_version, restorable, problem }`.
##
## One that cannot be restored is still listed, with the reason in `problem`,
## so the player can see it and delete it rather than find a folder that never
## empties.
static func backups(game_id: String) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for path in _backup_files(game_id):
		result.append(_describe_backup(game_id, path))
	result.sort_custom(_newer_first)
	return result


## Deletes one of [param manifest]'s backups, then any folder that leaves empty.
static func delete_backup(manifest: GameManifest, path: String) -> Error:
	if not _is_backup_of(manifest.id, path):
		return ERR_FILE_BAD_PATH
	var err := _remove_file(path)
	if err != OK:
		return err
	_remove_empty_folder(_backup_folder(manifest.id))
	_remove_empty_folder(backup_root.trim_suffix("/"))
	return OK


## A backup's date the way a person reads it — "25 Sep 2026 · 06:10:33" — in
## the device's local time. Seconds are kept so two backups made a moment apart
## can still be told apart.
static func backup_date_text(backup: Dictionary) -> String:
	var when: Dictionary = {}
	var created := str(backup.get("created", "")).strip_edges()
	if not created.is_empty():
		when = Time.get_datetime_dict_from_datetime_string(created, false)
	var month := int(when.get("month", 0))
	# An unparseable stamp reads as the epoch; no backup predates this project.
	if month < 1 or month > MONTHS.size() or int(when.get("year", 0)) < 2000:
		var bias := int(Time.get_time_zone_from_system().get("bias", 0))
		when = Time.get_datetime_dict_from_unix_time(
			int(float(backup.get("created_unix", 0.0))) + bias * 60
		)
		month = clampi(int(when.get("month", 1)), 1, MONTHS.size())
	return "%d %s %d · %02d:%02d:%02d" % [
		int(when.get("day", 1)), MONTHS[month - 1], int(when.get("year", 1970)),
		int(when.get("hour", 0)), int(when.get("minute", 0)), int(when.get("second", 0)),
	]


# --------------------------------------------------------------------------
# Internals
# --------------------------------------------------------------------------


static func _backup_folder(game_id: String) -> String:
	return "%s/%s" % [backup_root.trim_suffix("/"), game_id]


static func _backup_files(game_id: String) -> PackedStringArray:
	var result := PackedStringArray()
	var folder := _backup_folder(game_id)
	var directory := DirAccess.open(folder)
	if directory == null:
		return result
	for file in directory.get_files():
		if file.get_extension() == BACKUP_EXTENSION:
			result.append("%s/%s" % [folder, file])
	return result


## Only a file directly inside the game's own backup folder may be restored or
## deleted, so a path handed in by a screen can never reach anything else.
static func _is_backup_of(game_id: String, path: String) -> bool:
	return (
		path.get_base_dir() == _backup_folder(game_id)
		and path.get_extension() == BACKUP_EXTENSION
		and not path.get_file().begins_with(".")
	)


static func _describe_backup(game_id: String, path: String) -> Dictionary:
	var info := {
		"path": path,
		"created": "",
		"created_unix": float(FileAccess.get_modified_time(path)),
		"app_version": "",
		"restorable": false,
		"problem": PROBLEM_UNREADABLE,
	}
	var config := ConfigFile.new()
	if config.load(path) != OK:
		return info
	var created: Variant = config.get_value(BACKUP_SECTION, "created", "")
	if created is String:
		info["created"] = created
	var created_unix: Variant = config.get_value(
		BACKUP_SECTION, "created_unix", info["created_unix"]
	)
	if created_unix is float or created_unix is int:
		info["created_unix"] = float(created_unix)
	info["app_version"] = str(config.get_value(BACKUP_SECTION, "app_version", ""))
	info["problem"] = _backup_problem(config, game_id)
	info["restorable"] = str(info["problem"]).is_empty()
	return info


## Why the backup in [param config] cannot be restored into [param game_id], or
## "" when it can. Everything [method restore] reads is type-checked here, so
## a hand-edited or truncated file is refused before anything is changed.
static func _backup_problem(config: ConfigFile, game_id: String) -> String:
	# A null default makes ConfigFile log an error for a key that is missing.
	var format: Variant = config.get_value(BACKUP_SECTION, "format", 0)
	if not (format is int) or int(format) < 1:
		return PROBLEM_UNREADABLE
	if int(format) > BACKUP_FORMAT:
		return PROBLEM_NEWER
	if str(config.get_value(BACKUP_SECTION, "game_id", "")) != game_id:
		return PROBLEM_OTHER_GAME
	for key in ["achievements", "store"]:
		if (
			config.has_section_key(DATA_SECTION, key)
			and typeof(config.get_value(DATA_SECTION, key)) != TYPE_DICTIONARY
		):
			return PROBLEM_DAMAGED
	var files: Variant = config.get_value(DATA_SECTION, "files", [])
	if typeof(files) != TYPE_ARRAY:
		return PROBLEM_DAMAGED
	for raw_record: Variant in files:
		if typeof(raw_record) != TYPE_DICTIONARY:
			return PROBLEM_DAMAGED
		var record: Dictionary = raw_record
		if typeof(record.get("path", null)) != TYPE_STRING:
			return PROBLEM_DAMAGED
		if bool(record.get("exists", false)) and not (record.get("data", null) is PackedByteArray):
			return PROBLEM_DAMAGED
	return ""


static func _newer_first(a: Dictionary, b: Dictionary) -> bool:
	var a_time := float(a["created_unix"])
	var b_time := float(b["created_unix"])
	if a_time != b_time:
		return a_time > b_time
	return str(a["path"]) > str(b["path"])


## `<stamp>.cfg`, or `<stamp>_2.cfg` and so on when that second is taken; the
## underscore sorts after the dot, so name order stays creation order.
static func _unused_backup_path(folder: String) -> String:
	var now := Time.get_datetime_dict_from_system()
	var stamp := "%04d%02d%02d-%02d%02d%02d" % [
		now["year"], now["month"], now["day"], now["hour"], now["minute"], now["second"],
	]
	var path := "%s/%s.%s" % [folder, stamp, BACKUP_EXTENSION]
	var copy := 2
	while FileAccess.file_exists(path):
		path = "%s/%s_%d.%s" % [folder, stamp, copy, BACKUP_EXTENSION]
		copy += 1
	return path


static func _write_bytes(path: String, bytes: Variant) -> Error:
	if not (bytes is PackedByteArray):
		return ERR_INVALID_DATA
	var err := DirAccess.make_dir_recursive_absolute(
		ProjectSettings.globalize_path(path.get_base_dir())
	)
	if err != OK:
		return err
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		return FileAccess.get_open_error()
	var written := file.store_buffer(bytes)
	file.close()
	return OK if written else ERR_FILE_CANT_WRITE


static func _remove_file(path: String) -> Error:
	if not FileAccess.file_exists(path):
		return OK
	return DirAccess.remove_absolute(ProjectSettings.globalize_path(path))


static func _remove_empty_folder(folder: String) -> void:
	var directory := DirAccess.open(folder)
	if directory == null:
		return
	directory.include_hidden = true
	var empty := directory.get_files().is_empty() and directory.get_directories().is_empty()
	directory = null
	if empty:
		DirAccess.remove_absolute(ProjectSettings.globalize_path(folder))


static func _first_error(first: Error, next: Variant) -> Error:
	if first != OK:
		return first
	return int(next) as Error


static func _report(game_id: String, path: String, problem: String) -> void:
	var key := "%s|%s" % [game_id, path]
	if _reported.has(key):
		return
	_reported[key] = true
	push_warning("GameSaves: %s declares save file '%s', but %s." % [game_id, path, problem])


## Resolved from the tree, never named: see the class description.
static func _autoload(autoload_name: String) -> Node:
	var tree := Engine.get_main_loop() as SceneTree
	if tree == null or tree.root == null:
		return null
	return tree.root.get_node_or_null(autoload_name)


static func _constant(autoload_name: String, constant: String, fallback: String) -> String:
	var node := _autoload(autoload_name)
	if node == null or node.get_script() == null:
		return fallback
	var script: Script = node.get_script()
	return str(script.get_script_constant_map().get(constant, fallback))
