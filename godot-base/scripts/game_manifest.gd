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
const CONTROL_STYLE_CUSTOM_KEYS := "custom_keys"

## Stable identifier. Used for save keys, share payloads and `[share]` project
## settings, so it must never change once a game has shipped.
var id := ""

## Player-facing name, shown on the menu, HUD and share card.
var title := ""

## One-line description used by the mode-select and instructions screens.
var tagline := ""

## Scene loaded when the player starts this game.
var gameplay_scene_path := ""

## Optional opening played instead of `scenes/boot/intro.tscn`.
##
## Only a build that ships this game on its own uses it: the intro runs before
## the main menu, so in a collection no game has been chosen yet and the
## framework's placeholder is the only honest opening. Empty keeps that
## placeholder. The scene's only contract is the intro's: reach
## `Router.goto()` eventually, and let the player skip.
var intro_scene_path := ""

## Achievement definitions merged into [AchievementManager] at boot.
## `{ id: { "title": String, "description": String, "badge": String } }`
var achievements := {}

## This game's own credits sections, in the same shape as [StudioInfo.CREDITS]:
## `[{ "heading": String, "lines": Array[String] }]`.
##
## The credits screen renders them above the shared studio sections when this
## game is the whole build. A collection cannot show one game's credits over
## another's, so it lists the games it ships instead. Empty is fine — the
## studio sections still roll.
var credits: Array[Dictionary] = []

## This game's logo and colours. Like the intro, it dresses the shared screens
## only in a build that ships this game alone: a collection has no one game to
## look like. `null` keeps the studio's own look.
var theme: GameTheme = null

## Optional gating. `null` means the game is always available.
var unlock_rule: GameUnlockRule = null

## Set when this game should not be advertised until its rule unlocks it.
var hidden_until_unlocked := false

## Whether the mode-select screen offers local multiplayer / a CPU opponent.
var supports_multiplayer := true
var supports_cpu_opponent := true

## Initial round mode when the player has not saved a shared preference.
## An explicit Timer or Lives choice still takes precedence in every game.
var default_lives_mode := false

## How the player acts, which decides the control cards and instructions the
## shared menus render. Games pick an existing style rather than being named
## individually by the framework.
##   [code]targets[/code]          — press a bound key/button for a highlighted target
##   [code]direct_movement[/code]  — steer a cursor around the playfield
##   [code]custom_keys[/code]      — use the game's own declared action keys
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
## `instructions_versus_summary`, `instructions_player_one_controls`,
## `instructions_player_two_controls`, `cpu_opponent_description`,
## `instructions_cpu_summary`, `instructions_cpu_controls`.
##
## Custom-key games supply action descriptions, not literal key names: the
## menus append each player's live bindings. CPU copy describes the game's own
## opponent; the shared target-game difficulty picker is not used by this style.
var copy := {}

## Player-facing options this game adds to the in-game Settings → Game tab. The
## framework stores, clamps and renders them; the game reads them through
## [method Settings.tunable], [method Settings.tunable_bool] or
## [method Settings.tunable_choice].
##
## `key` is a globally unique `section/name` string so saved settings from
## different games never collide. Every other field is optional and has a
## neutral default, so a bare `{"key": …, "default": …}` still works.
##
## [codeblock]
## {
##     "key": "game/triangle_size",   # required, globally unique
##     "type": OPTION_SLIDER,         # SLIDER (default), TOGGLE or CHOICE
##     "default": 1.5,
##     "min": 0.6, "max": 1.6, "step": 0.05,   # sliders only
##     "choices": [{"value": 0, "title": "Auto"}],  # choice lists only
##     "title": "Triangle size",      # row label; derived from the key if absent
##     "description": "…",            # hint line and assistive-tech description
##     "format": FORMAT_PERCENT,      # how the value reads out beside a slider
##     "heading": "Triangles",        # groups consecutive rows under a heading
## }
## [/codeblock]
var tunables: Array[Dictionary] = []

## Option kinds the Settings screen knows how to render.
const OPTION_SLIDER := "slider"
const OPTION_TOGGLE := "toggle"
const OPTION_CHOICE := "choice"

## Read-outs available to a slider option. Unknown values render the raw number.
const FORMAT_NUMBER := "number"
const FORMAT_PERCENT := "percent"
## Renders `0` as "Off" and anything else as a signed percentage or count, for
## options that add to a baseline rather than replacing it.
const FORMAT_PLUS_PERCENT := "plus_percent"
const FORMAT_SECONDS := "seconds"
const FORMAT_PLUS_SECONDS := "plus_seconds"
const FORMAT_LIVES := "lives"
const FORMAT_COUNT := "count"
const FORMAT_MILLISECONDS := "milliseconds"

## Rebindable keyboard controls this game owns, rendered on the in-game
## Settings → Controls tab.
##
## A game that leaves this empty inherits the framework's built-in bindings for
## its [member control_style], so a `targets` game gets the six target keys for
## free. Declare bindings when the game is driven by something else — movement
## keys, instrument keys — rather than living with controls it does not use.
## A [constant CONTROL_STYLE_CUSTOM_KEYS] game always declares its own bindings;
## there are no built-in keys or implied mouse/gamepad actions for that style.
##
## [codeblock]
## {
##     "key": "controls/slice_move_up",  # required, globally unique
##     "default": KEY_UP,                # required
##     "action": &"slice_move_up",       # optional InputMap action kept in sync
##     "title": "Move up",               # row label
##     "description": "…",
##     "player": 0,                      # 0 = P1, 1 = P2, -1 = shared (default)
##     "movement": true,                 # drives the character; see below
##     "heading": "Chainsaw movement",   # groups consecutive rows
## }
## [/codeblock]
##
## `movement` marks the keys that move the player, so menus can describe them
## in one line with [method Settings.movement_summary_for_game] instead of
## hardcoding "arrow keys". Leave it off for keys that do something else.
var control_bindings: Array[Dictionary] = []


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
