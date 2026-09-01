class_name GameManifest
extends Resource

## Everything the reusable base needs to know about one game.
##
## The framework (menus, achievements, settings, share cards, instructions)
## reads games exclusively through this manifest, so adding a game means adding
## a `games/<id>/game.gd` that returns one — no framework file has to change.
##
## Keep game rules in the game's own scripts; keep only description here.

## Control styles the shared menus know how to describe.
const CONTROL_STYLE_TARGETS := "targets"
const CONTROL_STYLE_DIRECT_MOVEMENT := "direct_movement"

## Stable identifier. Used for save keys, share payloads and `[share]` project
## settings, so it must never change once a game has shipped.
var id := ""

## Player-facing name, shown on the menu, HUD and share card.
var title := ""

## One-line description used by the mode-select and instructions screens.
var tagline := ""

## Scene loaded when the player starts this game.
var gameplay_scene_path := ""

## Achievement definitions merged into [AchievementManager] at boot.
## `{ id: { "title": String, "description": String, "badge": String } }`
var achievements := {}

## Optional gating. `null` means the game is always available.
var unlock_rule: GameUnlockRule = null

## Set when this game should not be advertised until its rule unlocks it.
var hidden_until_unlocked := false

## Whether the mode-select screen offers local multiplayer / a CPU opponent.
var supports_multiplayer := true
var supports_cpu_opponent := true

## How the player acts, which decides the control cards and instructions the
## shared menus render. Games pick an existing style rather than being named
## individually by the framework.
##   [code]targets[/code]          — press a bound key/button for a highlighted target
##   [code]direct_movement[/code]  — steer a cursor around the playfield
var control_style := CONTROL_STYLE_TARGETS

## Walkthrough media for the instructions screen. Missing files are tolerated:
## the screen falls back to the static explanation.
var tutorial_video_path := ""
var tutorial_poster_path := ""

## Fallback stats URL for the share card's QR code. Overridden by the
## `share/stats_urls/<id>` project setting when present. Must stay within
## [constant ShareQrCode.MAX_URL_BYTES].
var stats_url := ""

## Optional `Control` scene drawn as the share card's promotional art.
var share_art_scene_path := ""

## Selects one of the built-in share-card art styles when the game does not
## ship its own [member share_art_scene_path]. Unknown values fall back to the
## neutral style, so a new game always renders something sensible.
var share_art_style := ""

## Ordered menu weight; lower sorts first on the main menu.
var menu_order := 0

## Screen copy the shared menus render for this game. Missing keys fall back to
## the framework's neutral wording, so a manifest only overrides what it needs.
## Recognised keys: `mode_select_intro`, `mode_select_hint`,
## `single_player_description`, `multiplayer_description`,
## `player_one_control_description`, `player_two_control_description`,
## `solo_confirm_title`, `solo_confirm_description`, `versus_confirm_title`,
## `versus_confirm_description`, `instructions_headline`, `instructions_rules`,
## `instructions_demo_prompt`, `instructions_solo_summary`,
## `instructions_versus_summary`.
var copy := {}

## Player-facing numeric options this game adds to the Settings screen. The
## framework stores and clamps them; the game reads them through
## [method Settings.tunable].
##
## Each entry is `{"key": String, "default": float, "min": float, "max": float}`
## where `key` is a globally unique `section/name` string so saved settings from
## different games never collide.
var tunables: Array[Dictionary] = []


## Reads one [member copy] entry, falling back to [param fallback].
func text(key: String, fallback := "") -> String:
	var value := str(copy.get(key, "")).strip_edges()
	return value if not value.is_empty() else fallback


func is_valid() -> bool:
	return not id.is_empty() and not title.is_empty()


func has_unlock_rule() -> bool:
	return unlock_rule != null


func progression_keys() -> Array[String]:
	return unlock_rule.progression_keys() if unlock_rule else []


## Resolves the QR target, preferring the project setting so a build can be
## repointed without editing the game.
func resolved_stats_url() -> String:
	var configured := str(
		ProjectSettings.get_setting("share/stats_urls/%s" % id, stats_url)
	).strip_edges()
	return configured if not configured.is_empty() else stats_url


func gameplay_scene_exists() -> bool:
	return (
		not gameplay_scene_path.is_empty()
		and ResourceLoader.exists(gameplay_scene_path)
	)
