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

static var _manifests: Array[GameManifest] = []
static var _by_id: Dictionary = {}
static var _current_id := ""
static var _discovered := false


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
	if _current_id.is_empty() and not _manifests.is_empty():
		_current_id = _manifests[0].id


static func _compare_menu_order(a: GameManifest, b: GameManifest) -> bool:
	if a.menu_order == b.menu_order:
		return a.id < b.id
	return a.menu_order < b.menu_order


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
## standalone export produces (see `export_presets.cfg`). The shell then
## presents that game as the product instead of as one entry in a collection.
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


## Games that are always visible plus any gated game the player has unlocked.
static func available() -> Array[GameManifest]:
	var achievements := _achievement_manager()
	var result: Array[GameManifest] = []
	for manifest in all():
		if manifest.hidden_until_unlocked:
			if achievements == null:
				continue
			if not bool(achievements.call("is_game_unlocked", manifest.id)):
				continue
		result.append(manifest)
	return result


## Resolved from the tree because the catalog must not depend on autoload
## boot order.
static func _achievement_manager() -> Node:
	var tree := Engine.get_main_loop() as SceneTree
	if tree == null:
		return null
	return tree.root.get_node_or_null("AchievementManager")
