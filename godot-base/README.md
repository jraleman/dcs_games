# DCS Base Game

A Godot 4 starting point for DeskCanSaw Games projects. It ships the parts every
game needs before it is a game: the studio sting, an intro, a main menu,
settings that persist, credits, a pause overlay and a placeholder gameplay
scene — plus the unlockable Desk-Can-Saw minigame — all built to look right
from a phone in portrait to an ultrawide monitor.

Made with **Godot 4.7** (`gl_compatibility` renderer, so it exports to web and
mobile without changes).

## Running it

```bash
godot --path .            # or open project.godot in the editor
godot --path . -- --game=dead_metal_jam   # run one game as if it shipped alone
```

The first scene is `scenes/boot/studio_logo.tscn`; from there the flow is:

```
studio_logo  ──►  intro  ──►  main_menu  ──┬──►  mode_select  ──►  instructions
 (skippable)   (skippable)                 │                         (optional)
                                           │                              │
                                           │                    ┌─────────┴─────────┐
                                           │                    ▼                   ▼
                                           │                gameplay       slice_and_slash
                                           ├──►  settings_menu
                                           └──►  credits
```

## What's in the box

| Path | What it does |
| --- | --- |
| `scripts/studio_info.gd` | Studio identity: project title, tagline, intro cards, credits, palette. **Start here when renaming the project.** |
| `scripts/game_manifest.gd` | `GameManifest` resource — everything the framework needs to know about one game (scene, copy, achievements, tunables, share art). |
| `scripts/game_catalog.gd` | `GameCatalog` static registry — discovers `games/*/game.gd` and tracks the selected game. |
| `scripts/game_unlock_rule.gd` | `GameUnlockRule` base class for gating a game behind progress in another. |
| `scripts/game_shell.gd` | `GameShell` base class — the shared round loop, HUD, results/stats panels, pause, sharing and accessibility plumbing every game inherits. |
| `scenes/game/game_shell.tscn` | The matching reusable scene: HUD, results panel, stats panel and an empty `%Playfield` for your game to fill. |
| `autoload/settings.gd` | Stores, persists (`user://settings.cfg`) and applies player settings, including game-declared tunables. |
| `autoload/game_session.gd` | Holds player count, CPU configuration and controller assignment while moving between scenes, and reports gamepad presence via `gamepad_connected()` / `gamepad_availability_changed`. |
| `autoload/audio_manager.gd` | Music crossfades, an 8-voice SFX pool, bus volumes, UI/gameplay sound cues and semantic audio-caption requests. |
| `autoload/achievement_manager.gd` | Persistent achievement registry, per-game unlock progression and queued global achievement toasts. |
| `autoload/share_manager.gd` | Renders reusable 1200×630 session cards, downloads them on web and saves them for desktop sharing. |
| `autoload/router.gd` | `Router.goto(path)` — scene changes with a fade. Owns the top overlay layer (fade + FPS counter). |
| `ui/menu_screen.gd` | `MenuScreen` base class: UI sounds, focus handling, `ui_cancel` to go back, responsive margins. |
| `ui/responsive.gd` | Helpers for margins, portrait detection and content width. |
| `ui/theme/dcs_theme.tres` | The whole look: buttons, panels, sliders, tabs. A standalone build restyles its accent from the game's `GameTheme`. |
| `ui/components/background.tscn` | Animated gradient backdrop (shader), aspect-corrected and tinted by the current `GameTheme`. |
| `ui/components/achievement_toast.tscn` | Small reusable unlock notification used by `AchievementManager`. |
| `ui/components/audio_caption.tscn` | Reusable gameplay caption panel for important sound-only events. |
| `ui/components/player_avatar.gd` | Drawn placeholder for per-player portrait art; set `portrait` to swap in a real texture. |
| `ui/components/share_card.tscn` | Default score/achievement image; swap it or pass another scene to `ShareManager`. |
| `ui/components/share_preview.tscn` | Modal generated-image preview with close and open-original actions. |
| `ui/components/splash_motion.gd` | Lightweight animated geometry for logo stings and splash screens. |
| `games/target_rush/` | Target Rush: manifest, gameplay scene, targets, options and its own tests. |
| `games/slice_and_slash/` | Desk-Can-Saw: manifest, gameplay scene, cans, chainsaw cursor, unlock rule and its own tests. |
| `games/dead_metal_jam/` | Dead Metal Jam: manifest, pitch-detection instrument input, encounters, its own intro and theme, and its own tests. |
| `tools/tutorial_capture.tscn` | Development-only recorder: plays a real round with a scripted demo player and captioned steps for the instructions video. |
| `tools/record_tutorials.ps1` | Records both tutorial clips through Godot's Movie Maker and encodes them to `assets/video/*.ogv` plus poster frames. |

## Looking right on every screen

The project stretches a **1920x1080** base with `canvas_items` + `expand`, so a
viewport is never *narrower* than the base on one axis and simply shows more
space on the other. Layouts are written in those units and adapt at runtime:

- **`Settings._update_content_scale()`** scales the UI up on physically small
  windows (below ~700px tall), so text stays legible on a phone. The player can
  bias it further with *Settings → Display → Interface size*.
- **Settings → Accessibility → Intense visual effects** disables full-screen
  flashes and screen shake during gameplay while preserving other animation
  and visual feedback.
- **Reduced motion** freezes ambient and decorative movement, removes pulses,
  trails, particles, shake and spatial UI animation, and keeps opacity-only
  fades. Essential target, can and player-controlled chainsaw movement remains
  active.
- **Audio captions** identify correct and wrong targets, countdown cues,
  Desk-Can-Saw power-up and unlock sounds, sliced cans and missed cans.
- **P1/P2 identity labels** keep player ownership readable without depending
  on blue/red color differences.
- **Gameplay assists** live on their own **Settings → Gameplay** tab: they can
  slow moving targets and cans to 60%, enlarge them to 140%, and add up to 30
  seconds to each round. These settings take effect when the next round starts
  and do not disable progression or achievements. That tab also holds the
  *Show instructions* toggle and *Restore defaults*.
- **Per-game options** live on **Settings → Controls** and **Settings → Game**,
  which only exist while a game is running — the pause menu supplies the
  context and the main menu does not, because "triangle speed" means nothing
  before a game is chosen. Both tabs are generated from the running game's
  manifest, so they show Triangle Rush's size, speed, final-stretch rush and
  round length in Target Rush; the round length, can fall speed, spawn rate,
  desk capacity, chainsaw speed and four rebindable movement keys in
  Desk-Can-Saw; and the waves per track, timing leniency, wrong-note penalty,
  note input and the octave and self-test keys in Dead Metal Jam. Options apply
  from the next round and stack with the Gameplay assists (size and speed
  multiply, extra time is added on top), so they can make a game harder as well
  as easier.
- **One-button Target Rush** lets any of a player's assigned keys or mapped
  controller target buttons activate their highlighted target. Desk-Can-Saw
  also exposes controller movement speed, stick deadzone and movement-layout
  controls. Every one of those pad-only rows hides itself until a controller is
  connected, so the screen never advertises hardware the player does not have.
- **`MenuScreen.refresh_layout()`** recomputes margins from the live viewport
  on every resize and calls `_on_layout_changed(size)`, which screens override.
  The main menu uses it to switch between a left-aligned poster layout in
  landscape and a centred stack in portrait, and to tighten spacing on short
  viewports.
- Long content (the settings tabs, the credits roll) lives in `ScrollContainer`s,
  so nothing is ever unreachable on a small screen.
- The background shader is driven by `UV` and gets the current aspect ratio from
  `ui/components/background.gd`, so its glows stay round on any window shape.

Anchored controls are animated with `modulate` and `scale` (with a centred
pivot), never `position` — moving an anchored control bakes its offsets in and
breaks the layout on the next resize.

## Common changes

**Rename the project** — edit `scripts/studio_info.gd` (`TITLE`, `TAGLINE`,
`INTRO_CARDS`, `CREDITS`), `application/config/name` and
`application/config/custom_user_dir_name` in `project.godot`. Give every
derived game a unique custom user directory before release, then keep it stable
so later display-name changes do not strand saves. When renaming a released
project that previously used Godot's default directory, add its old project
name to `Settings.LEGACY_PROJECT_NAMES` for the one-time desktop migration.

**Replace the intro** — either edit the `cards` array on
`scenes/boot/intro.tscn`, or build a new scene and point
`studio_logo.tscn → next_scene` at it. The only contract is that it eventually
calls `Router.goto(next_scene)`.

**Add a setting** — for a framework-wide setting, add a key to
`Settings.DEFAULTS`, handle it in `Settings._apply()` (or let another node
listen to `Settings.changed`), then add a row to
`scenes/menus/settings_menu.tscn` and wire it in
`settings_menu.gd::_connect_ui()`. Saving, loading and defaults come for free.
For a setting that only makes sense for one game, declare it in that game's
manifest `tunables` and it appears on the in-game *Game* tab with no scene
edit at all — see *Adding your own game* below.

**Change how a round ends** — *Settings → Game → Round mode* picks between the
two shapes every game shares:

- **Timer** (default) — the round runs for its configured duration and mistakes
  only cost points.
- **Lives** — the countdown is replaced by a pool of lives (3 by default,
  1–9 via the *Starting lives* slider). Each mistake spends one; the round ends
  when the pool is empty. In two-player and CPU rounds each side gets its own
  pool, a side that runs out is eliminated, and the round ends once nobody is
  left. The TimerCard becomes a `LIVES LEFT` readout and reddens on the last
  life exactly as the clock reddens in its final seconds.

`GameShell` owns all of it — `Settings.round_mode()`, `.lives_mode_enabled()`
and `.starting_lives()` are read once per round in `_load_round_settings()`, so
switching modes shapes the *next* round rather than the live one. A game only
has to report its own mistakes with `_lose_life(player_index)` and skip
eliminated players with `_player_is_out(player_index)`; both no-op under the
countdown, so a game never branches on the mode itself. What counts as a
mistake is the game's call — a wrong key in Target Rush, an escaped can in
Desk-Can-Saw.

**Add music** — drop an `.ogg` in `assets/audio/`, then set the `music` export
on the main menu, intro or gameplay scene. Volume is already wired to the Music
bus and its slider. Call `AudioManager.play_music(stream)` anywhere else.

**Add an achievement** — define its title, description and short badge in your
game's `game.gd` manifest (`game.achievements`), then call
`AchievementManager.unlock("your_id")` at the game-specific unlock point.
Registration, persistence, duplicate protection, audio and the animated toast
are automatic.

**Share a result** — the round-over **See Scores** button opens the
scorecard, which renders the share card in place with
`await ShareManager.preview_score_image(session_data)`: the image *is* the score
summary, so there is no separate preview step. **Save Image** then calls
`await ShareManager.generate_score_image(session_data)` to write the file.
The scorecard is a detail view of the results screen, so **Back to Results** is
its only way out — leaving the match stays a decision made on the results panel,
which keeps its own Play Again and Main Menu buttons.
`ShareManager.show_preview(result)` remains available for screens that want the
standalone modal. The default card expects a game ID, result, score, accuracy,
hits, combo and achievement fields.
It renders game-specific promotional art plus a QR information panel containing
the game name, website and stats link. Set `stats_url` in the payload to use a
published per-run URL, or configure the short per-game defaults under
`share/stats_urls` in `project.godot`. Keep stats URLs at 42 UTF-8 bytes or less
so the QR modules remain scan-safe after the card is resized to 600×315.

Any scene with a `configure(Dictionary)` method can still be passed as the
second argument. `ShareManager` supplies that scene with `website`,
`stats_url`, and a generated `qr_texture`. `preview_score_image()` renders
without touching the disk or the clipboard; `generate_score_image()` saves.
Web exports download the PNG; desktop exports save it under `user://shares` and
copy the saved path to the clipboard, after which the scorecard's **Open Image**
button opens the original in the system image viewer. That action stays hidden
in browser exports. QR generation uses the MIT-licensed GDScript implementation
vendored under `third_party/greaby_qrcode`.

**Tune the sample game** — the exported values on
`games/target_rush/gameplay.gd` control colours, target speed, round length,
points and miss penalty. Round length and the final-stretch speed rush are also
player-facing under *Settings → Game* while the game is running, which
overrides those exports at runtime; those ranges and their row titles, formats
and descriptions live in `games/target_rush/target_rush_options.gd` and are
published to `Settings` through the manifest's `tunables`. Desk-Can-Saw and
Dead Metal Jam do the same through `slice_options.gd` and `dmj_options.gd`.
Keyboard bindings are
persisted by `Settings`, while the CPU difficulty profiles live in
`GameSession`. The sample keeps rules in `gameplay.gd`, target input / movement
in `triangle_target.gd` and everything reusable in `GameShell`, so each part can
be replaced independently.

## Adding your own game

Games are self-contained folders under `res://games/<id>/`. `GameCatalog` scans
that directory at startup, so **no framework file needs to change** to add one.

1. Create `res://games/<id>/game.gd` with a
   `static func manifest() -> GameManifest`. Set at least `id`, `title`,
   `gameplay_scene_path` and `menu_order`.
2. Create your gameplay scene as an **inherited scene** of
   `res://scenes/game/game_shell.tscn` (open it, *Scene ▸ New Inherited Scene*)
   and attach a script that `extends GameShell`. You inherit the countdown,
   HUD, results and stats panels, pause overlay, share card, screen shake and
   every accessibility setting; you only write the game.
3. Override `game_id()` to return your manifest id, then override the hooks you
   actually need. They all have working no-op or neutral defaults:

   | Hook | Override it to |
   | --- | --- |
   | `game_id()` | **Required.** Return your manifest id. |
   | `_build_playfield()` | Spawn your actors under `%Playfield`. |
   | `_prepare_session()` | Read `GameSession` before the first round. |
   | `_begin_first_round()` | Kick off the opening round if it needs custom timing. |
   | `_load_round_settings()` | Pull your `Settings.tunable(...)` values. Call `super()`. |
   | `_reset_round_state()` | Clear per-round state before the countdown. |
   | `_activate_round()` | Start motion the moment the countdown clears. |
   | `_update_round(delta)` | Per-frame gameplay. |
   | `_handle_gameplay_input(event)` | Gameplay input; the shell already ate `pause`. |
   | `_finish_round()` | Stop motion and settle scores when time runs out. |
   | `_round_totals()` / `_player_stats(index)` | Feed the results and stats panels. |
   | `_describe_round_outcome()` / `_round_highlight_summary()` | Word the results copy. |
   | `_award_round_achievements(result)` | Unlock your own achievements. |
   | `_spawn_round_confetti()` | Custom celebration particles. |
   | `_playfield_bounds()` | Report your play area if it is not the whole viewport. |
   | `_configure_mode_ui()` | Extra HUD wiring for 1P/2P/CPU. Call `super()`. |
   | `_on_player_labels_changed()` / `_on_controls_changed()` | React to accessibility settings. |
   | `_on_game_setting_changed(key)` | React to one of your tunables changing live. |

   The shell also hands you three helpers for the lives round mode (see *Round
   modes* below). All three are safe to call unconditionally — under the
   countdown they no-op, return `false` and return an empty string:

   | Helper | Call it to |
   | --- | --- |
   | `_lose_life(player_index)` | Report a player mistake. Ends the round when everyone runs out. |
   | `_player_is_out(player_index)` | Stop scoring or accepting input from an eliminated player. |
   | `_lives_rule_note()` | Append "Each mistake costs a life" to your own HUD copy. |

   Use `_round_length_phrase()` instead of hardcoding "in 60 seconds" in
   results copy; it words itself for whichever mode the round was played in.

4. Optional extras, all declared on the manifest:
   - `achievements` — registered and persisted automatically.
   - `copy` — overrides menu and instructions wording (see `GameManifest.copy`
     for the recognised keys); anything you omit falls back to neutral text.
   - `tunables` — player-facing options, stored and clamped by `Settings` and
     rendered as rows on the in-game *Game* tab with no scene edit. Use a
     globally unique `game/name` key and declare a `title`; add `min`, `max`,
     `step` and a `format` (`percent`, `seconds`, `count`, …) for a slider, or
     `"type": GameManifest.OPTION_TOGGLE` / `OPTION_CHOICE` with `choices` for
     the other two shapes. Consecutive options sharing a `heading` are grouped
     under it. Read them back with `Settings.tunable(key)`,
     `.tunable_bool(key)` or `.tunable_choice(key)` — usually from
     `_load_round_settings()`, so a slider moved mid-round never reshapes the
     round being played.
   - `control_bindings` — rebindable keyboard controls, rendered on the in-game
     *Controls* tab. Give each one a unique `controls/name` key, a `default`
     keycode, an `action` the framework keeps in sync with the `InputMap`, and
     a `title`. Mark the ones that steer the player with `"movement": true` so
     menus can name them through `Settings.movement_summary_for_game()` instead
     of assuming arrow keys. A game that declares none inherits the built-in
     bindings for its `control_style`. Conflicts are only conflicts inside one
     game, so two games may use the same key.
   - `control_style` — `targets` or `direct_movement`; the shared menus adapt
     their control explanations instead of branching on a game name.
   - `unlock_rule` + `hidden_until_unlocked` — gate the game behind progress in
     another one. Subclass `GameUnlockRule`; every finished round is offered to
     every rule, so "playing A unlocks B" needs no framework change.
   - `share_art_style`, `stats_url`, `tutorial_video_path` — share card and
     instructions media.
   - `intro_scene_path` — an opening of your own, played instead of the
     framework's placeholder cards. It is only used when the build ships this
     game alone, because a collection has not chosen a game yet when the intro
     runs. See *Shipping one game on its own*.
   - `credits` — your game's own credits sections, in the same
     `{"heading": …, "lines": […]}` shape as `StudioInfo.CREDITS`. They lead
     the credits roll when the build ships this game alone.
   - `theme` — a `GameTheme` with your logo and a handful of colours. Like the
     intro, it only dresses the shared screens when the build ships this game
     alone. See *Shipping one game on its own*.
5. Put the game's own tests in `res://games/<id>/tests/`. The framework-level
   `tests/game_shell_test.gd` picks your game up from the catalog
   automatically and drives it through a full round, results, stats, share and
   replay cycle — no edit needed.

The main menu needs no edit either. It builds one button per game from
`GameCatalog.available()`, in `menu_order`, so a new game appears as soon as
its manifest does — and disappears again behind an `unlock_rule` until earned.

## Shipping one game on its own

The same project produces the collection build *and* a standalone build of any
single game, with no code that knows a game by name. The trick is that **a
build whose catalog holds exactly one game already looks like a standalone
game**: the Play button starts it, no secondary entry appears, and the title
screen takes its name and tagline from that game's manifest rather than from
`StudioInfo`. A game that is normally gated behind an `unlock_rule` is always
playable when it is the only game in the build, because nothing in that build
could ever open the gate.

`GameCatalog` resolves which game the build is pinned to from three sources, in
this order — `restrict_to()` (tests), the command line and environment, then
the project setting:

```bash
godot --path . -- --game=dead_metal_jam    # one run, one game
godot --path . -- --game=target_rush
godot --path . -- --game=slice_and_slash
DCS_GAME=dead_metal_jam godot --path .     # same, for launchers that cannot pass args
```

An id the build does not contain is refused with a warning and the full catalog
is kept, so a typo never produces a build with nothing to play.

### Its own settings

The Controls and Game tabs configure one game, so in a collection build they
only appear once a round is running and the pause menu names it. A standalone
build has no such ambiguity: the settings screen adopts the only game in the
catalog, so **both tabs sit on the main menu** and a player can rebind keys and
change the game's options before pressing Play. Rows outside those tabs that
only suit one control style — one-button play, the controller target buttons —
are hidden for a game they do not fit, so nothing on screen names another game.

None of that is per-game code: the screen asks `GameCatalog` which game the
build ships, and the rows come from that game's manifest.

### Its own opening

A standalone build is that game's product, so it may open with its own intro
instead of the framework's placeholder cards. Declare the scene on the manifest:

```gdscript
game.intro_scene_path = "res://games/dead_metal_jam/intro.tscn"
```

`studio_logo.gd` asks `GameCatalog.intro_scene_path(next_scene)` after the
studio sting, and that returns the declared path **only when the catalog holds
exactly one game** — a collection has not chosen a game at that point, so
promising one would be a lie. Collection builds keep
`scenes/boot/intro.tscn`, and a declared path that does not exist falls back to
it with a warning.

The custom intro replaces *only* the intro. Everything after it is still the
framework: the studio sting, the main menu (branded with the game's title and
tagline), mode select, instructions, settings including the in-game *Controls*
and *Game* tabs, credits, the pause overlay, achievements and share cards.

An intro is a plain `Control` scene. It must stay skippable (`skip` and
`ui_cancel`) and hand over with `Router.goto(next_scene)` when it ends.
Dead Metal Jam's — `games/dead_metal_jam/intro.gd` — is worth copying: it walks
the game's real `RustDrone` actors across a stage so the opening cannot drift
away from the game, synthesises its own audio rather than adding sounds to
`AudioManager`, and honours reduced motion, intense visual effects and audio
captions.

### Its own credits

Credits are data, so the roll follows the build. Declare your game's sections
on the manifest, in the same shape as `StudioInfo.CREDITS`:

```gdscript
game.credits = [
	{"heading": "Game Design & Code", "lines": ["DeskCanSaw"]},
	{"heading": "Pitch Detection", "lines": ["McLeod Pitch Method over the NSDF"]},
]
```

A standalone build is that game's product, so the roll opens with the game's
title, then its sections, then the studio's — one credits screen covering
everything in the build.

A collection cannot pick one game's credits over another's, so it rolls the
studio sections and finishes by naming the games it ships and sending the
player to each game's own credits. That list is generated from `GameCatalog`,
so it can never go stale; only the wording lives in `StudioInfo`
(`COLLECTION_CREDITS_HEADING`, `COLLECTION_CREDITS_NOTE`). A game with no
`credits` declared simply contributes nothing.

### Its own look

Declare a `GameTheme` and a standalone build wears it everywhere:

```gdscript
var theme := GameTheme.new()
theme.logo_texture_path = "res://games/dead_metal_jam/assets/game-icon.svg"
theme.logo_color = Color("ffd34e")
theme.plaque_color = Color("2a2019")
theme.accent = Color("ffd34e")        # focus rings, sliders, tabs, menu glow
theme.light = Color("ffe3a8")         # key light on the plaque
theme.background_top = Color("241a12")
theme.background_bottom = Color("0b0806")
game.theme = theme
```

Four things read it, and none of them names a game:

- `background.gd` — every screen instances it, so the menu gradient and glow
  are the game's on every screen in the build.
- `main_menu.gd` — the rotating plaque takes `logo_texture_path`, tinted with
  `logo_color`, and its lights and slab take `light` and `plaque_color`. The
  logo is scaled to span the plaque, so any resolution or aspect fits.
- `router.gd` — at boot it hands `ThemeDB.get_project_theme()` to
  `GameTheme.restyle()` and puts the result on the root window, which every
  Control inherits. That swaps the studio accent for the game's wherever
  `dcs_theme.tres` uses it — focus rings, sliders, tab underlines — while
  leaving spacing, fonts and every neutral shade alone.
- `menu_screen.gd` and `game_shell.gd` — both call `GameTheme.restyle_tree()`
  on themselves in `_ready()`. A `Theme` only reaches what a scene left
  unstyled, and the HUD and the credits roll bake the accent into per-node
  `theme_override_*` entries, scene-local styleboxes and `ColorRect`s. The
  repaint walks the tree and substitutes exactly the studio accents, so the
  round timer, mode title, callouts and credit headings follow the game.

A logo is best authored as a single-colour silhouette so `logo_color` can tint
it; the Dead Metal Jam icon is imported with its RGB channels remapped from
alpha (see `game-icon.svg.import`), which turns a black traced silhouette into
a white one the tint can colour. A logo with its own colours should leave
`logo_color` white.

What a theme deliberately does *not* touch is the player-one/player-two
colours. Those are an accessibility contract — two players have to stay
tellable apart — so they are the framework's, not a game's.

A game that declares no theme, and every collection build, gets
`GameTheme.studio_default()`: the exact values the shared scenes are authored
with, so nothing moves.

That makes a standalone release **export configuration only**. All three games
already have a preset — *Windows — Target Rush / Desk-Can-Saw / Dead Metal Jam
(standalone)* — each pinned by its own feature tag, spelled as the initials of
the game's id (`tr`, `scs`, `dmj`). A preset carries the tag and drops the other
games:

```ini
custom_features="dmj"
exclude_filter="games/target_rush/*, games/slice_and_slash/*"
```

and in `project.godot`, override the pin and the identity for that feature tag:

```ini
build/single_game_id.dmj="dead_metal_jam"
config/name.dmj="Dead Metal Jam"
config/custom_user_dir_name.dmj="DeskCanSaw Games/Dead Metal Jam"
```

`build/single_game_id` is what pins the catalog; the `exclude_filter` then keeps
the other games' assets out of the package. Setting both means the build is
correct even if one of them is edited later.

The user-dir override is **not optional**. Without it the standalone build
shares `user://` with the collection, so saves, settings and achievements
collide. Running from source with `--game` cannot change the user dir — the
engine fixes it at startup — so a pinned dev run still reads and writes the
collection's save files. That is fine for playtesting, and the reason the
override belongs in the preset.

`export_presets.cfg` is tracked deliberately — an untracked preset file means
nobody else can reproduce a release. Keep credentials out of it; when mobile
exports land, the Android keystore path and password belong in the editor's
per-machine settings.

## Input actions

| Action | Bound to |
| --- | --- |
| `skip` | Space, Enter, left mouse button, gamepad A |
| `pause` | Esc plus a remappable gamepad button (Start by default) |
| `toggle_fullscreen` | F11 |
| `player_one_target_1/2/3` | Remappable; defaults to 1, 2 and 3 |
| `player_two_target_1/2/3` | Remappable; defaults to 7, 8 and 9 |
| `slice_move_up/down/left/right` | Remappable; defaults to the arrow keys |
| `dmj_octave_down` / `dmj_octave_up` | Remappable; defaults to Z and X |
| `dmj_self_test` | Remappable; defaults to F2 |
| `ui_accept` / `ui_cancel` | Godot defaults (menu navigation and back) |

Gameplay keys can be changed under **Settings → Controls** — which only exists
while a game is running, because a key binding belongs to a game — and are
saved in `user://settings.cfg`; assigning an occupied key swaps the two
bindings within that game. Two different games may use the same key, since only
one of them is ever running. A game with no `control_bindings` of its own
inherits the built-in set for its `control_style`, which is where Target Rush's
six target keys come from. Desk-Can-Saw declares four movement keys (the arrow
keys by default) and Dead Metal Jam declares its octave and self-test keys.
Controller 1 controls Player 1 and Controller 2 controls Player 2. In Target
Rush they share three remappable target buttons (A, B and X by default).
Controller pause is remappable too; target and pause buttons remain unique, so
assigning an occupied button swaps the two bindings. Pause excludes D-pad
directions so they remain available to Desk-Can-Saw movement. The HUD's on-screen
**PAUSE** button only appears when `DisplayServer.is_touchscreen_available()` is
true: a keyboard or pad already pauses without it, so it would just be clutter
beside the scores, but a touchscreen has neither and needs the button. Single-player
creates only Player 1's targets; multiplayer lets Player 2 use those controls
or hands P2 to the CPU.

Every gamepad surface stays hidden until a controller is actually plugged in.
`GameSession.gamepad_connected()` is the single source of truth and
`GameSession.gamepad_availability_changed` fires on hot-plug, so Settings, the
mode-select copy, the instructions cards and the in-game HUD hints all drop
their pad wording — and bring it straight back — without leaving the screen.
**Settings → Controls** collapses the whole controller section to
"Connect a controller to configure its buttons.", and the pad speed and stick
deadzone rows disappear from **Accessibility**. Games get this for free:
`GameShell` routes the hot-plug signal through the existing
`_on_controls_changed()` hook.
Each active player has one bright target at a time: matching it earns a point,
while choosing one of that player's dim targets costs a point. Human-controlled
targets also accept mouse and touchscreen presses. Optional P1/P2 labels make
ownership independent of color, and one-button mode routes any assigned
keyboard or controller target button to the highlighted target.

Desk-Can-Saw uses direct movement instead: solo accepts the mouse, arrow keys
or Controller 1. The shared controller layout can use the left or right stick,
with or without D-pad input. In local multiplayer Player 1 uses the mouse by
default, Player 2 uses the arrow keys by default, and assigned controllers use
the same Controller 1/Controller 2 ordering and movement layout. A chainsaw is
clamped to the playfield, and the first chainsaw to intersect a can earns that
can's single point. The workshop wall, wood desk, power cords, aluminum cans,
electric chainsaws, moving chain teeth, sparks, metal fragments and sawdust are
all drawn procedurally. Chainsaw motors, startup revs, cuts and dropped-can
clatter are synthesized at runtime and routed through the existing SFX bus.

Mode selection uses a two-step setup: choose single player or multiplayer, then
confirm the controller assignment. Each mode card names its roster with labelled
`P1`/`P2`/`CPU` chips, the chosen card keeps a **SELECTED** badge and a one-line
summary of what pressing Start would launch, and the confirmation step tags both
seats with a `PlayerAvatar` portrait placeholder plus a **HUMAN**/**CPU** role.
The Player 2 seat is picked with an explicit two-option control —
**A Second Player** or **The CPU** — rather than an unlabelled switch. The armed
option carries a tick in its own label so the answer survives a greyscale screen,
a sentence underneath restates the choice in plain words, and the CPU difficulty
row lives inside the same card because it only applies to one of the two answers.
Multiplayer defaults to the CPU so a lone player can start without finding a
second person first. CPU opponents offer Easy
(Baby seed), Medium (Hard seed) and Hard (Impossible seed) profiles, which adjust
reaction time and accuracy. Games steered directly rather than by target keys
share one screen between two humans, so they hide the selector entirely. The
confirmation body scrolls, so the step survives portrait phones and the taller
CPU layout. Android and iOS builds expose single-player mode
only.

The instructions screen is shown after mode selection by default. Its
**Show instructions when starting a mode** toggle is persisted, and the same
preference can be restored under **Settings → Gameplay**.

It leads with a captioned walkthrough clip of a real round of the selected game
(`assets/video/tutorial_<game>.ogv`), which takes roughly two thirds of the body
width so the round is actually readable, alongside the control cards and rules
summary. Playback starts automatically and repeats on a loop so a viewer can keep
watching without hunting for the replay button. It can be paused, restarted or
toggled by clicking the picture. **Reduced motion** opts out of both: an
endlessly restarting clip is exactly the kind of unrequested repeated movement
that setting exists to suppress, so the clip parks on its poster with an explicit
**Watch again** prompt instead. If a
clip is missing the card disappears and the screen falls back to the static
explanation, so the scene is safe to ship without the videos.

Each control card is headed by a portrait placeholder
(`ui/components/player_avatar.gd`) tagged **P1**, **P2** or **CPU**, tinted with
the same colours the gameplay HUD uses. The mode-selection confirmation step
reuses the same component, so a seat looks identical from the moment it is
chosen to the moment the round starts. The stand-in is drawn rather than
shipped as an image, so the card already reserves the exact box a finished
portrait needs and there are no throwaway art files to maintain. Assign the
component's `portrait` texture — or pass one to `configure()` — once real art
exists and it renders in the same box; no screen has to change to adopt it. A
scene that authors its own `custom_minimum_size` keeps it, so the same
placeholder can sit at 64 px in a mode card and 76 px on an instructions card.
The
tag is drawn onto the placeholder so a card never identifies its player by
colour alone, and it is mirrored into `accessibility_description` for screen
readers.

Re-record the clips after changing gameplay visuals or the tutorial captions:

```bash
pwsh tools/record_tutorials.ps1 -Godot /path/to/godot
godot --headless --path . --import
```

`tools/tutorial_capture.tscn` loads the actual gameplay scene, drives it with a
scripted demo player and overlays numbered step captions, so the clips can never
drift from how the game really behaves. `tools/record_tutorials.ps1` runs that
scene through Godot's Movie Maker, encodes the result to Ogg Theora with ffmpeg
and extracts the still poster frame shown before playback starts. Nothing
outside `tools/` references either file — add `tools/*` to your export preset's
exclude filter to keep the recorder out of shipped builds.

The sample unlocks **Solo Starter** after the first completed single-player
round and **First Win** after Player 1's first multiplayer victory.
Desk-Can-Saw is completely hidden until the player either scores at least 25
in a solo Target Rush round or wins a multiplayer Target Rush round as Player 1
with at least 25 points (Medium difficulty when the opponent is the CPU). Its
first unlock triggers a dedicated fanfare and visual celebration. The
Desk-Can-Saw's mode selector only shows the matching unlocked route: solo,
local multiplayer, or both after both Target Rush conditions have been
completed. A Player 2 win with at least 25 points awards **Race condition** but
does not satisfy Player 1's multiplayer requirement. These flags and
achievements are stored in `user://achievements.cfg` and never regress after
later matches. Both files are written by merging into what is already on disk,
never by rebuilding them: a standalone build registers only its own game's keys
and must not delete another build's saved options or unlocks out of a shared
`user://`.

Focused regression checks can be run headlessly:

```bash
godot --headless --path . --script res://games/slice_and_slash/tests/slice_and_slash_test.gd
godot --headless --path . --script res://games/slice_and_slash/tests/slice_and_slash_scene_test.gd
godot --headless --path . --script res://tests/visual_effects_test.gd
godot --headless --path . --script res://tests/accessibility_test.gd
godot --headless --path . --script res://games/target_rush/tests/target_rush_options_test.gd
godot --headless --path . --script res://tests/share_card_test.gd
godot --headless --path . --script res://tests/instructions_video_test.gd
godot --headless --path . --script res://tests/game_shell_test.gd
godot --headless --path . --script res://tests/lives_mode_test.gd
godot --headless --path . --script res://tests/game_options_test.gd
godot --headless --path . --script res://tests/single_game_test.gd
```

Run the suite against the full collection: several checks assert values that
Target Rush and Desk-Can-Saw declare, so they cannot pass in a run pinned with
`--game`. `single_game_test.gd` is the exception — it passes in both, so a
standalone build can still verify its own path.

The FPS counter is available under **Settings → Display** and is drawn by
`Router`, so it stays visible across scenes without each game implementing its
own counter.

## Placeholder assets

- `assets/images/dcs_logo.png` — the real DeskCanSaw Games logo.
- `assets/audio/ui_click.wav`, `ui_focus.wav`, `ui_back.wav` — synthesised UI
  blips generated for this template; replace them with your own.
- `assets/video/tutorial_*.ogv` and `tutorial_*_poster.webp` — generated from
  the placeholder games by `tools/record_tutorials.ps1`; re-record them once
  your own game replaces the sample.
- `icon.svg` — a simple placeholder mark, not the finished studio icon.

The theme uses Godot's default font. To use your own, drop a `.ttf`/`.otf` in
`assets/fonts/`, then set it as the theme's default font in
`ui/theme/dcs_theme.tres`.
