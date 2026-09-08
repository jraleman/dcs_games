class_name GameCatalog
extends RefCounted

## Discovers the games that ship with this project and tracks which one the
## player selected.
##
## Every game lives in `res://games/<id>/` and exposes a `game.gd` with a
## `static func manifest() -> GameManifest`. The folder is scanned once, on
## first use, so adding a game never requires editing framework code.
##
## Menus, achievements and share cards call [method current] instead of
## branching on a game name.
##
## This is a static registry rather than an autoload: autoload names are not
## resolvable at compile time from other autoloads or from headless
## `--script` test runs, and [AchievementManager] and the catalog need each
## other.

const GAMES_ROOT := "res://games"
const MANIFEST_FILE := "game.gd"

## Project setting that pins the build to a single game id. It is
## feature-overridable, so a per-game export preset selects its game with
## `build/single_game_id.<custom_feature>` and a collection preset overrides
## the value with an empty string.
const SINGLE_GAME_SETTING := "dcs/build/single_game_id"

## Command-line switch that pins one *run* to a single game, so a standalone
## build can be played and tested from source without exporting it:
## `godot --path . -- --game=<id>`.
const SINGLE_GAME_ARGUMENT := "--game"

## Reserved selector for the full collection, even when the project defaults
## to one game. Uses the same precedence as a game id: `--game=all`.
const ALL_GAMES_SELECTOR := "all"

## Environment variable equivalent of [constant SINGLE_GAME_ARGUMENT], for
## launchers and scripts that cannot pass engine arguments through.
const SINGLE_GAME_ENVIRONMENT := "DCS_GAME"

static var _manifests: Array[GameManifest] = []
static var _by_id: Dictionary = {}
static var _current_id := ""
static var _discovered := false

## Set by [method restrict_to]; overrides the setting, switch and environment
## variable so a test can exercise a standalone build in-process.
static var _forced_single_id := ""


static func _ensure_discovered() -> void:
	if _discovered:
		return
	_discovered = true

	var directory := DirAccess.open(GAMES_ROOT)
	if directory == null:
		push_error("GameCatalog: no %s folder; the project has no games." % GAMES_ROOT)
		return

	for folder in directory.get_directories():
		var path := "%s/%s/%s" % [GAMES_ROOT, folder, MANIFEST_FILE]
		if not ResourceLoader.exists(path):
			continue
		var script: Script = load(path)
		if script == null or not script.has_method("manifest"):
			push_warning("GameCatalog: %s has no manifest() function." % path)
			continue
		var manifest: GameManifest = script.call("manifest")
		if manifest == null or not manifest.is_valid():
			push_warning("GameCatalog: %s returned an invalid manifest." % path)
			continue
		if _by_id.has(manifest.id):
			push_warning("GameCatalog: duplicate game id '%s'." % manifest.id)
			continue
		_manifests.append(manifest)
		_by_id[manifest.id] = manifest

	_manifests.sort_custom(_compare_menu_order)
	_apply_single_game_filter()
	if not _by_id.has(_current_id):
		_current_id = _manifests[0].id if not _manifests.is_empty() else ""


static func _compare_menu_order(a: GameManifest, b: GameManifest) -> bool:
	if a.menu_order == b.menu_order:
		return a.id < b.id
	return a.menu_order < b.menu_order


## Drops every game but the requested one, so the rest of the project sees the
## catalog a standalone export would ship. Nothing downstream needs to know:
## the menu builds one entry, [method product_title] brands the build with the
## game's own name, and [method is_single_game_build] is true.
##
## An unknown id is a configuration mistake, not a reason to boot a build with
## nothing to play, so the full catalog is kept and the problem is reported.
static func _apply_single_game_filter() -> void:
	var wanted := single_game_id()
	if wanted.is_empty():
		return
	if not _by_id.has(wanted):
		push_warning(
			"GameCatalog: single-game mode wants '%s', which this build does not contain; "
			% wanted
			+ "keeping every game."
		)
		return
	var manifest: GameManifest = _by_id[wanted]
	_manifests.clear()
	_manifests.append(manifest)
	_by_id = {wanted: manifest}


## The game this build or run is pinned to, or "" for the full collection.
##
## Precedence runs from the most specific source to the least: an explicit
## [method restrict_to], then the command line, then the environment, then the
## project setting an export preset overrides.
static func single_game_id() -> String:
	var wanted := _forced_single_id
	if wanted.is_empty():
		wanted = _single_game_from_command_line()
	if wanted.is_empty():
		wanted = OS.get_environment(SINGLE_GAME_ENVIRONMENT).strip_edges()
	if wanted.is_empty():
		wanted = _single_game_from_settings()
	return "" if wanted == ALL_GAMES_SELECTOR else wanted


## Accepts `--game=<id>` and `--game <id>`, after `--` (where the engine puts
## user arguments) or as a plain argument in an exported build.
static func _single_game_from_command_line() -> String:
	var sources: Array[PackedStringArray] = [
		OS.get_cmdline_user_args(),
		OS.get_cmdline_args(),
	]
	for arguments in sources:
		for index in arguments.size():
			var argument := arguments[index]
			if argument.begins_with(SINGLE_GAME_ARGUMENT + "="):
				return argument.trim_prefix(SINGLE_GAME_ARGUMENT + "=").strip_edges()
			if argument == SINGLE_GAME_ARGUMENT and index + 1 < arguments.size():
				return arguments[index + 1].strip_edges()
	return ""


## Feature-tag overrides are what make one preset ship one game, and only
## `get_setting_with_override` resolves them.
static func _single_game_from_settings() -> String:
	if not ProjectSettings.has_setting(SINGLE_GAME_SETTING):
		return ""
	return str(ProjectSettings.get_setting_with_override(SINGLE_GAME_SETTING)).strip_edges()


## Pins the catalog to [param id] at runtime, rescanning so the change is
## complete. Pass "all" for the collection, or "" to restore the configured
## launch default. Returns false — and leaves the catalog untouched — for a
## game this build does not contain.
static func restrict_to(id: String) -> bool:
	var wanted := id.strip_edges()
	var previous := _forced_single_id
	_forced_single_id = wanted
	_rediscover()
	if (
		not wanted.is_empty() and wanted != ALL_GAMES_SELECTOR
		and not _by_id.has(wanted)
	):
		_forced_single_id = previous
		_rediscover()
		return false
	return true


## Restores the command-line, environment or project default after a runtime pin.
static func clear_restriction() -> void:
	if _forced_single_id.is_empty():
		return
	_forced_single_id = ""
	_rediscover()


static func _rediscover() -> void:
	_discovered = false
	_manifests.clear()
	_by_id.clear()
	_ensure_discovered()


## Every discovered game, in menu order.
static func all() -> Array[GameManifest]:
	_ensure_discovered()
	return _manifests.duplicate()


static func has(id: String) -> bool:
	_ensure_discovered()
	return _by_id.has(id)


static func get_manifest(id: String) -> GameManifest:
	_ensure_discovered()
	return _by_id.get(id, null)


## The game the player is about to play or is playing.
static func current() -> GameManifest:
	_ensure_discovered()
	return _by_id.get(_current_id, null)


static func current_id() -> String:
	_ensure_discovered()
	return _current_id


## Makes [param id] the active game. Returns false for an unknown id.
static func select(id: String) -> bool:
	_ensure_discovered()
	if not _by_id.has(id):
		push_warning("GameCatalog: unknown game '%s'." % id)
		return false
	_current_id = id
	return true


## Title of the selected game, or the project name before one is chosen.
static func current_title() -> String:
	var manifest := current()
	return manifest.title if manifest else StudioInfo.TITLE


## True when this build ships exactly one game, which is what a per-game
## standalone export produces (see `export_presets.cfg`) and what
## [method single_game_id] pins a run to. The shell then presents that game as
## the product instead of as one entry in a collection.
static func is_single_game_build() -> bool:
	return all().size() == 1


## Name for the product itself: the studio's project name in a collection
## build, the game's own name when only one game shipped. Framework screens use
## this instead of [constant StudioInfo.TITLE] so a standalone export is branded
## correctly without anything naming a specific game.
static func product_title() -> String:
	var games := all()
	return games[0].title if games.size() == 1 else StudioInfo.TITLE


static func product_tagline() -> String:
	var games := all()
	return games[0].tagline if games.size() == 1 else StudioInfo.TAGLINE


static func current_gameplay_scene_path() -> String:
	var manifest := current()
	return manifest.gameplay_scene_path if manifest else ""


## The opening to play after the studio sting.
##
## A standalone build shows its game's own intro when it declares one, because
## there is nothing else to introduce. A build with more than one game keeps
## [param fallback]: the intro runs before the main menu, so no game has been
## chosen yet and introducing one of them would be a lie.
static func intro_scene_path(fallback: String) -> String:
	var games := all()
	if games.size() != 1:
		return fallback
	var path := games[0].intro_scene_path.strip_edges()
	if path.is_empty():
		return fallback
	if not ResourceLoader.exists(path):
		push_warning(
			"GameCatalog: %s declares a missing intro scene '%s'." % [games[0].id, path]
		)
		return fallback
	return path


## The look the shared screens wear: the game's own in a build that ships one
## game, the studio's otherwise. Same rule as the intro and the credits — a
## collection has no single game to look like, and dressing every screen as one
## of them would misrepresent the other games in it.
##
## Never returns null, so callers can theme themselves unconditionally.
static func theme() -> GameTheme:
	var games := all()
	if games.size() == 1 and games[0].theme != null:
		return games[0].theme
	return GameTheme.studio_default()


## Games that are always visible plus any gated game the player has unlocked.
##
## The only game in a standalone build is always available: its gate describes
## progress in a game that is not in this build, so nothing could ever open it.
static func available() -> Array[GameManifest]:
	var games := all()
	if games.size() == 1:
		return games
	var achievements := _achievement_manager()
	var result: Array[GameManifest] = []
	for manifest in games:
		if manifest.hidden_until_unlocked:
			if achievements == null:
				continue
			if not bool(achievements.call("is_game_unlocked", manifest.id)):
				continue
		result.append(manifest)
	return result


## True when the player actually has a game to choose between.
##
## A standalone build, or a collection whose other games are still locked, has
## nothing to pick, so the framework skips its game picker rather than showing a
## screen with a single card on it — the same reason `main_menu.gd` skips mode
## select for a game that cannot be played by two people.
static func offers_a_choice() -> bool:
	return available().size() > 1



## Resolved from the tree because the catalog must not depend on autoload
## boot order.
static func _achievement_manager() -> Node:
	var tree := Engine.get_main_loop() as SceneTree
	if tree == null:
		return null
	return tree.root.get_node_or_null("AchievementManager")
