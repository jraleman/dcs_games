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

## Whether the mode-select screen offers local multiplayer.
var supports_multiplayer := true

## Maximum human seats offered by local setup. Existing games keep two.
var max_local_players := 2

## Local players take complete turns and share the first player's keyboard
## bindings. Games still own their turn rules; the shell only describes setup.
var local_multiplayer_turns := false

## Selectable characters, in default seat order:
## [{"id": String, "title": String, "description": String}].
## Optional requires_achievement and locked_description gate a choice.
## An optional icon, a texture path, is shown beside the title in the setup
## row and its list; a missing file warns and leaves a text row.
## Selection is session-local and independent for each player.
var characters: Array[Dictionary] = []

## Optional levels, shared by all players in a round. Entries use the same
## id, title, description, icon and achievement-gate fields as characters.
## Games own the level geometry and completion rules.
var levels: Array[Dictionary] = []

## Optional Control scene with configure(Dictionary). The dictionary contains
## the character entry, player_index, multiplayer and player_color.
## The setup screen stands it on a plinth, in a 1.7:1 rect twice the plinth's
## radius wide whose bottom edge sits just in front of the plinth's centre, so
## frame the subject to stand on that edge. The screen sets it to ignore the
## mouse. Empty keeps the generic numbered player portrait.
var character_preview_scene_path := ""

## Whether the mode-select screen offers the shared "Player 2 is the CPU"
## multiplayer picker.
##
## This is only the menu capability for a game's optional second seat. It does
## not describe a game's own built-in solo AI setup, which may still use the
## single-player flow and [member solo_setup_choices].
var supports_cpu_opponent := true

## Whether a solo round is one of this game's modes.
##
## Clear it for a game that always seats two, one of them possibly the CPU: a
## player-count question with a single honest answer is a step to remove, not a
## card to grey out, so mode select drops that step and opens on the control
## confirmation where the remaining choice — who holds the second seat — lives.
## The platform still wins: where a second seat is impossible, solo is all that
## can be run and the question comes back.
var supports_single_player := true

## Choice-type [member tunables] rendered on the single-player confirmation
## pane before the control cards.
##
## Each entry must be the `key` of one of this manifest's declared
## [constant OPTION_CHOICE] tunables. The shared mode-select screen reads and
## writes them through [Settings], so a game can ask one more solo question —
## colour, character, loadout — without the framework learning its name.
## An empty array keeps the existing setup flow unchanged.
var solo_setup_choices: Array[String] = []

## Initial round mode when the player has not saved a shared preference.
## For games using shell round rules, an explicit Timer or Lives choice wins.
var default_lives_mode := false

## False for self-paced matches whose rules, rather than a clock or life pool,
## decide the ending. The shell still owns pause, elapsed time and results.
## Arcade time/size/speed modifiers are hidden without changing saved choices.
var uses_shell_round_rules := true

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
## Optional walkthrough clip for local human-vs-human instructions. Empty
## falls back to [member tutorial_video_path].
var local_tutorial_video_path := ""
var tutorial_poster_path := ""
## Optional still image paired with [member local_tutorial_video_path]. Empty
## falls back to [member tutorial_poster_path].
var local_tutorial_poster_path := ""

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
## Recognised keys: `mode_select_title`, `mode_select_intro`, `mode_select_hint`,
## `level_label`, `character_label`,
## `single_player_description`, `single_player_roster`,
## `single_player_selection_summary`, `multiplayer_description`,
## `player_one_control_description`, `player_two_control_description`, `player_three_control_description`,
## `solo_confirm_title`, `solo_confirm_description`, `versus_confirm_title`,
## `versus_confirm_description`, `instructions_headline`, `instructions_rules`,
## `instructions_demo_prompt`, `instructions_solo_summary`,
## `instructions_versus_summary`, `instructions_player_one_controls`,
## `instructions_player_two_controls`, `instructions_player_three_controls`, `cpu_opponent_description`,
## `instructions_cpu_summary`, `instructions_cpu_controls`.
##
## Custom-key games supply action descriptions, not literal key names: the
## menus append each player's live bindings. CPU copy describes the game's own
## opponent; the shared target-game difficulty picker is not used by this style.
## When a game uses [member solo_setup_choices], the shared solo setup strings
## above may include one `%s` placeholder, which the setup and instructions
## screens replace with the current solo choice summary.
var copy := {}

## Player-facing options this game adds to the in-game Settings → Game tab. The
## framework stores, clamps and renders them; the game reads them through
## [method Settings.tunable], [method Settings.tunable_bool] or
## [method Settings.tunable_choice].
##
## `key` is a globally unique `section/name` string so saved settings from
## different games never collide. Every other field is optional and has a
## neutral default, so a bare `{"key": …, "default": …}` still works.
## A choice may add `summary_title` for compact setup buttons and selected-choice
## copy; its full `title` remains available in the Game settings tab.
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

## Cosmetics this game sells for the points its rounds pay out, rendered on the
## shared Store screen. The framework prices, stores, sells and equips them; it
## never learns what any of them look like.
##
## An item is bought once and may then be equipped into any [member store_slots]
## entry whose `kind` matches, so a game with two wearers does not have to sell
## the same hat twice.
##
## [codeblock]
## {
##     "id": "pit_hat_straw",       # required, globally unique and permanent
##     "kind": "hat",               # which slots will take it; default "cosmetic"
##     "price": 40,                 # in this game's points; 0 is a freebie
##     "title": "Straw Boater",     # card title; derived from the id if absent
##     "description": "…",          # card copy and assistive-tech description
##     "badge": "STR",              # short label drawn when there is no preview
##     "color": Color("e8c46a"),    # swatch behind the badge
##     "default": true,             # owned from the start and worn by default
##     "requires_achievement": "…", # gate: cannot be bought until it unlocks
##     "heading": "Hats",           # groups consecutive cards under a heading
## }
## [/codeblock]
var store_items: Array[Dictionary] = []

## Where this game's cosmetics are worn. One item per slot at a time.
##
## A game with one wearer declares one slot and the store shows a plain
## Equip button; a game with several labels them, so a duel can dress each
## side without the framework knowing there are two coops.
##
## [codeblock]
## {
##     "id": "pit_hat_red",         # required, globally unique and permanent
##     "kind": "hat",               # accepts items declaring this kind
##     "title": "Red coop",         # what the slot is called
##     "empty_title": "No hat",     # shown when the slot is empty; omit to
##                                  #   require a choice (see `default` items)
## }
## [/codeblock]
var store_slots: Array[Dictionary] = []

## Naming and payout rule for the points this game banks.
##
## Scores differ by orders of magnitude between games, so each game converts
## its own round into its own currency rather than sharing a wallet. Omitted
## keys fall back to [constant Store.DEFAULT_CURRENCY].
##
## [codeblock]
## {
##     "name": "Feather",           # singular, used for "1 Feather"
##     "plural": "Feathers",
##     "points_per_score": 0.02,    # multiplies the round's best score
##     "round_bonus": 5,            # flat payment for finishing a round
##     "win_bonus": 10,             # added when the player out-scores the CPU
##                                  #   (needs a CPU: a two-human duel and a
##                                  #   round with no opponent both pay none)
##     "max_per_round": 120,        # payout ceiling; 0 removes it
## }
## [/codeblock]
var store_currency := {}

## Optional `Control` scene drawn as a store item's picture, in the same shape
## as [member share_art_scene_path]: it is handed the item dictionary through
## `configure(Dictionary)`. Without one the store draws the item's `badge` on a
## plate in its `color`, so a store always renders something sensible.
var store_preview_scene_path := ""

## Models this game is proud of, shown on the shared Gallery screen.
##
## A gallery is a museum, not a feature: nothing here is bought, unlocked by
## spending or worn. It exists so the work that goes into a game's models can be
## looked at properly, from any angle, instead of only ever being glimpsed at
## gameplay distance.
##
## The framework owns the room — the list, the orbit and zoom controls, the
## caption and every accessibility rule — and knows nothing about what is on the
## plinth. [member gallery_stage_scene_path] is what actually draws it.
##
## [codeblock]
## {
##     "id": "pit_bird_red",        # required, unique within this game
##     "title": "Red Coop Puller",  # derived from the id if absent
##     "description": "…",          # a sentence under the model
##     "heading": "The birds",      # groups consecutive entries in the list
##     "badge": "HEN",              # short label when the stage cannot draw
##     "color": Color("e8453c"),    # accent for this entry's list button
##     "facts": ["Six per coop"],   # short spec lines beside the model
##     "requires_achievement": "…", # gate: listed, but not viewable until then
## }
## [/codeblock]
var gallery_exhibits: Array[Dictionary] = []

## `Control` scene that draws whatever [member gallery_exhibits] entry it is
## given, in the same shape as [member store_preview_scene_path]: it is handed
## the exhibit through `configure(Dictionary)`.
##
## The screen drives it with two optional methods, both safe to omit:
## [codeblock]
## func set_view(yaw: float, pitch: float, zoom: float) -> void
## # yaw/pitch in radians from the exhibit's default framing; zoom is a
## # magnification, so 1.0 is that default and 2.0 is twice as close.
##
## func set_auto_spin(enabled: bool) -> void
## # Turntable state. The screen already honours reduced motion before calling.
## [/codeblock]
##
## A game that draws in 2D, or has one fixed camera, simply implements
## `configure()` and lets the screen hide the controls it cannot use.
var gallery_stage_scene_path := ""

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


## True when this game has something to sell and somewhere to wear it. Menus ask
## before offering a Store entry, so a game without cosmetics never shows the
## player an empty shop.
func has_store() -> bool:
	return not store_items.is_empty() and not store_slots.is_empty()


## True when this game has models worth showing and something to draw them with.
## Menus ask before offering a Gallery entry, so a game with nothing on display
## never sends the player to an empty room.
##
## Unlike the store there is no autoload behind this: a gallery saves nothing,
## so the manifest is the whole state.
func has_gallery() -> bool:
	return not gallery_exhibits.is_empty() and not gallery_stage_scene_path.is_empty()


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
