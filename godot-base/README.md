# DCS Base Game

A Godot 4 starting point for DeskCanSaw Games projects. It ships the parts every
game needs before it is a game: the studio sting, an intro, a main menu,
settings that persist, credits, a pause overlay and a placeholder gameplay
scene — plus the Desk-Can-Saw minigame — all built to look right
from a phone in portrait to an ultrawide monitor.

Made with **Godot 4.7** (`gl_compatibility` renderer, so it exports to web and
mobile without changes).

## Running it

```bash
godot --path .                         # standalone Desk-Can-Saw, also the editor default
godot --path . -- --game=triangle_rush  # launch a different standalone game
godot --path . -- --game=dead_metal_jam
godot --path . -- --game=chicken_pit
godot --path . -- --game=anti_chess
godot --path . -- --game=anti_checkers
godot --path . -- --game=lazer_nfc
godot --path . -- --game=creep_code
godot --path . -- --game=all            # launch the full collection
```

Ordinary launches show only Desk-Can-Saw and default to three lives. A saved
round-mode choice or starting-lives preference still wins. No game is gated:
`--game=all` lists every game in the picker from the first launch, and
standalone Desk-Can-Saw is always playable.

The first scene is `scenes/boot/studio_logo.tscn`; from there the flow is:

```
studio_logo  ──►  intro  ──►  main_menu  ──┬──►  game_select  ──►  mode_select  ──►  instructions
 (skippable)   (skippable)                 │    (>1 game only)                        (optional)
                                           │                                               │
                                           │                                     ┌─────────┴─────────┐
                                           │                                     ▼                   ▼
                                           │                                 gameplay        game's own scene
                                           ├──►  settings_menu
                                           └──►  credits
```

The title screen offers a single **Play** button. Where it lands depends on
what the build actually has to offer, and the rule is the same one the rest of
the framework follows: never ask a question with one answer. With more than one
game available it opens `scenes/menus/game_select.tscn`, which shows a card per
game with that game's walkthrough clip running as a moving thumbnail. A
standalone build — or a collection in which everything else is still locked —
has nothing to pick, so **Play** selects that game and goes straight on to mode
select or instructions.

## What's in the box

| Path | What it does |
| --- | --- |
| `scripts/studio_info.gd` | Studio identity: project title, tagline, intro cards, credits, palette. **Start here when renaming the project.** |
| `scripts/game_manifest.gd` | `GameManifest` resource — everything the framework needs to know about one game (scene, copy, achievements, tunables, share art). |
| `scripts/game_catalog.gd` | `GameCatalog` static registry — discovers `games/*/game.gd`, skipping `_`- and `.`-prefixed archive/private folders, and tracks the selected game. |
| `scripts/game_unlock_rule.gd` | `GameUnlockRule` base class for gating a game behind progress in another. |
| `scripts/game_shell.gd` | `GameShell` base class — the shared round loop, HUD, results/stats panels, pause, sharing and accessibility plumbing every game inherits. |
| `scenes/game/game_shell.tscn` | The matching reusable scene: HUD, results panel, stats panel and an empty `%Playfield` for your game to fill. |
| `autoload/settings.gd` | Stores, persists (`user://settings.cfg`) and applies player settings, including game-declared tunables. |
| `autoload/game_session.gd` | Holds player count, CPU configuration and controller assignment while moving between scenes, and reports gamepad presence via `gamepad_connected()` / `gamepad_availability_changed`. |
| `autoload/audio_manager.gd` | Music crossfades, an 8-voice SFX pool, bus volumes, UI/gameplay sound cues and semantic audio-caption requests. |
| `autoload/achievement_manager.gd` | Persistent achievement registry, per-game unlock progression and queued global achievement toasts. |
| `autoload/store.gd` | Per-game cosmetics store: wallets, purchases, equipped slots and round payouts, persisted to `user://store.cfg`. |
| `autoload/share_manager.gd` | Renders reusable 1200×630 session cards, downloads them on web and saves them for desktop sharing. |
| `autoload/router.gd` | `Router.goto(path)` — scene changes with a fade. Owns the top overlay layer (fade + FPS counter). `start_selected_game()` is the single definition of "begin the selected game", shared by the title screen and the picker. |
| `scenes/menus/game_select.tscn` | The picker the **Play** button opens: one card per available game, built from `GameCatalog.available()`. Reached only when there is more than one game to choose from. |
| `scenes/menus/store.tscn` | The shop: one card per item a game declares in `store_items`, grouped by heading. Reached from the title screen in a standalone build and from the pause menu in any build. |
| `scenes/menus/gallery.tscn` | The museum: one plinth per entry in `gallery_exhibits`, turned and zoomed on a game-owned stage scene. Reached from the same two places as the store. |
| `ui/menu_screen.gd` | `MenuScreen` base class: UI sounds, focus handling, `ui_cancel` to go back, responsive margins. |
| `ui/responsive.gd` | Helpers for margins, portrait detection and content width. |
| `ui/theme/dcs_theme.tres` | Base buttons, panels, sliders and tabs. A standalone `GameTheme` can recolour it and merge a game-owned partial skin. |
| `ui/components/background.tscn` | Animated gradient backdrop (shader), aspect-corrected and tinted by the current `GameTheme`. |
| `ui/components/achievement_toast.tscn` | Small reusable unlock notification used by `AchievementManager`. |
| `ui/components/audio_caption.tscn` | Reusable gameplay caption panel for important sound-only events. |
| `ui/components/game_card.tscn` | One game on the picker: looping muted walkthrough clip as a thumbnail, poster fallback, name, tagline and Play button. A view only — it reads no autoload. |
| `ui/components/store_item_card.gd` | One cosmetic on the shop shelf: preview, price, lock reason and a button per slot it can be worn in. A view only — it reads no autoload and moves no money. |
| `ui/components/player_avatar.gd` | Drawn placeholder for per-player portrait art; set `portrait` to swap in a real texture. |
| `ui/components/share_card.tscn` | Default score/achievement image; swap it or pass another scene to `ShareManager`. |
| `ui/components/share_preview.tscn` | Modal generated-image preview with close and open-original actions. |
| `ui/components/splash_motion.gd` | Lightweight animated geometry for logo stings and splash screens. |
| `games/triangle_rush/` | Triangle Rush: manifest, gameplay scene, targets, options, arcade theme and its own tests. |
| `games/desk_can_saw/` | Desk-Can-Saw: manifest, gameplay scene, cans, chainsaw cursor, workshop theme and its own tests. |
| `games/dead_metal_jam/` | Dead Metal Jam: manifest, pitch-detection instrument input, encounters, its own intro and theme, and its own tests. |
| `games/chicken_pit/` | Chicken Pit: a real 3D toy-farm tug-of-war inside the 2D shell, with deterministic pulling, three CPU birds, Timer/Lives rules, original models/audio, and its own regression coverage. |
| `games/anti_chess/` | Anti-Chess: untimed 3D losing chess, compulsory captures, a seeded CPU or local turn-taking, original chessmen, and a jade/brass standalone theme. |
| `games/anti_checkers/` | Anti Checkers: untimed 3D English giveaway checkers, compulsory jump chains, crowned kings, a solo CPU or local turn-taking, and an original garnet/ivory table. |
| `games/lazer_nfc/` | LaZer NFC: real 3D Simon-style memory combat, Android reader-mode NFC, guided tag binding, assisted touch, seven instruments, shades and relaxed timing. |
| `games/creep_code/` | Creep Code: one evolving 3D ritual stage with Sliding Window, Binary Search and BFS relics, a growing constellation, permanent seals and a game-local Puzzle Manager. |
| `tools/tutorial_capture.tscn` | Development-only recorder: plays a real round with a scripted demo player and captioned steps for the instructions video. |
| `tools/record_tutorials.ps1` | Records each game's tutorial clip through Godot's Movie Maker and encodes it to that game's own `games/<id>/assets/video/tutorial.ogv` plus a poster frame. |
| `tools/measure_intro_cues.py` | Development-only: finds the pauses in a narration recording and prints the `cue_times` array a card-based intro needs. |

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
  trails, particles, shake and spatial UI animation, parks the game picker's
  video thumbnails on their poster frames, and keeps opacity-only fades.
  Essential target, can and player-controlled chainsaw movement remains
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
  round length in Triangle Rush; the round length, can fall speed, spawn rate,
  desk capacity, chainsaw speed and four rebindable movement keys in
  Desk-Can-Saw; the waves per track, timing leniency, wrong-note penalty,
  note input and the octave and self-test keys in Dead Metal Jam; and the round
  length, rope length, pull power, strength decay, CPU opponent and six
  rebindable pull keys in Chicken Pit. Anti-Chess adds solo colour, CPU difficulty,
  live legal-move hints and piece letters, plus shared board and camera controls.
  Anti Checkers follows the same setup with Red/Ivory sides, hints and checker
  labels. Their self-paced matches hide the unused arcade assists. Round options apply
  from the next round and stack with the Gameplay assists (size and speed
  multiply, extra time is added on top), so they can make a game harder as well
  as easier.
- **One-button target select** lets any of a player's assigned keys or mapped
  controller target buttons activate their highlighted target. It belongs to the
  `targets` control style, not to one game, and so do the rest of the shared
  rows: object size, pad cursor speed, movement scheme and the target buttons.
  Their captions and help text are neutral by default and any game may reword
  them with a `setting_*` key on its `GameManifest.copy` (see *Its own
  settings*). Games in the `direct_movement` style
  also expose controller movement speed, stick deadzone and movement-layout
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
two shapes arcade games share:

- **Timer** (Triangle Rush's default) — the round runs for its configured
  duration and mistakes only cost points.
- **Lives** — the countdown is replaced by a pool of lives (3 by default,
  1–9 via the *Starting lives* slider). Each mistake spends one; the round ends
  when the pool is empty. In two-player and CPU rounds each side gets its own
  pool, a side that runs out is eliminated, and the round ends once nobody is
  left. The TimerCard becomes a `LIVES LEFT` readout and reddens on the last
  life exactly as the clock reddens in its final seconds.

Desk-Can-Saw and Dead Metal Jam default to **Lives** through their manifests'
`default_lives_mode` flag. An existing saved round-mode choice takes precedence;
resetting settings restores the selected game's default.

Self-paced games declare `uses_shell_round_rules = false`: no countdown or
life pool is started, the unused arcade modifiers are hidden, and elapsed
time, pause and results still belong to `GameShell`. The saved Timer/Lives
preference remains intact for other games. Anti-Chess and Anti Checkers use
this capability to end on their giveaway rules rather than an unrelated arcade limit.

`GameShell` owns all of it — `Settings.round_mode()`, `.lives_mode_enabled()`
and `.starting_lives()` are read once per round in `_load_round_settings()`, so
switching modes shapes the *next* round rather than the live one. A game only
has to report its own mistakes with `_lose_life(player_index)` and skip
eliminated players with `_player_is_out(player_index)`; both no-op under the
countdown, so a game never branches on the mode itself. What counts as a
mistake is the game's call — a wrong key in Triangle Rush, an escaped can in
Desk-Can-Saw.

**Add music** — drop an `.ogg` in `assets/audio/`, then set the `music` export
on the main menu, intro or gameplay scene. Volume is already wired to the Music
bus and its slider. Call `AudioManager.play_music(stream)` anywhere else.

**Add an achievement** — define its title, description and short badge in your
game's `game.gd` manifest (`game.achievements`), then call
`AchievementManager.unlock("your_id")` at the game-specific unlock point.
Registration, persistence, duplicate protection, audio and the animated toast
are automatic.

**Add a cosmetic** — add a dictionary to your manifest's `store_items` with an
`id`, `title` and `price`. The shop card, the purchase, the wallet, the saved
ownership and the Store button all follow from that one entry; read the result
back with `Store.equipped_id(game_id(), slot_id)`. See *A store of your own*.

**Add an exhibit** — add a dictionary to your manifest's `gallery_exhibits` with
an `id`, `title` and a line or two of `facts`, and teach your
`gallery_stage_scene_path` scene to draw that id. The plinth, the grouped list,
the caption and the orbit controls all follow. See *A gallery of your own*.

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
`games/triangle_rush/gameplay.gd` control colours, target speed, round length,
points and miss penalty. Round length and the final-stretch speed rush are also
player-facing under *Settings → Game* while the game is running, which
overrides those exports at runtime; those ranges and their row titles, formats
and descriptions live in `games/triangle_rush/triangle_rush_options.gd` and are
published to `Settings` through the manifest's `tunables`. Desk-Can-Saw and
Dead Metal Jam do the same through `desk_can_saw_options.gd` and `dmj_options.gd`.
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
   | `game_id() -> String` | **Required.** Return your manifest id. |
   | `_build_playfield() -> void` | Spawn your actors under `%Playfield`. |
   | `_prepare_session() -> void` | Read `GameSession` before the first round. |
   | `_begin_first_round() -> void` | Kick off the opening round if it needs custom timing. |
   | `_load_round_settings() -> void` | Pull your `Settings.tunable(...)` values. Call `super()`. |
   | `_reset_round_state() -> void` | Clear per-round state before the countdown. |
   | `_activate_round() -> void` | Start motion the moment the countdown clears. |
   | `_update_round(delta: float, time_left: float) -> void` | Per-frame gameplay. |
   | `_handle_gameplay_input(event: InputEvent) -> void` | Gameplay input; the shell already ate `pause`. |
   | `_finish_round() -> void` | Stop motion and settle scores when time runs out. |
   | `_round_totals() -> Dictionary` / `_player_stats(player_index: int) -> Dictionary` | Feed the results and stats panels. |
   | `_describe_round_outcome(p1_total: int, p2_total: int) -> Dictionary` / `_round_highlight_summary() -> String` | Word the results copy. |
   | `_award_round_achievements(p1_total: int, p2_total: int) -> void` | Unlock your own achievements. |
   | `_round_points_earned(p1_total: int, p2_total: int) -> int` | Replace the store payout rule; negative declines it. |
   | `_spawn_round_confetti(color: Color) -> void` | Custom celebration particles. |
   | `_playfield_bounds() -> Rect2` | Report your play area if it is not the whole viewport. |
   | `_configure_mode_ui() -> void` | Extra HUD wiring for 1P/2P/CPU. Call `super()`. |
   | `_on_player_labels_changed() -> void` / `_on_controls_changed() -> void` | React to accessibility settings. |
   | `_on_game_setting_changed(key: String, value: Variant) -> void` | React to one of your tunables changing live. |
   | `_set_reduced_motion_enabled(value: bool) -> void` | Park your own ambient motion. **Call `super(value)`.** |
   | `_set_intense_effects_enabled(value: bool) -> void` | Gate your own flashes and shake. **Call `super(value)`.** |
   | `_reset_reduced_motion_state() -> void` | Re-apply the parked pose when a round restarts. |

   The two accessibility setters are the only hooks where forgetting `super()`
   breaks a contract rather than a feature: the base implementations are what
   store the flag the shell's own shake, flash and confetti read.
   `tests/accessibility_test.gd` and `tests/visual_effects_test.gd` sweep every
   game in `GameCatalog.all()` for exactly that, so a new game is covered the
   moment it is discovered.

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
     keycode and a `title`; an optional `action` is kept in sync with the
     `InputMap`. Set `"player": 0` for P1, `1` for P2, or `-1` (the default)
     for a shared action. Mark the ones that steer the player with
     `"movement": true` so menus can name them through
     `Settings.movement_summary_for_game()` instead of assuming arrow keys.
     A game that declares none inherits the built-in bindings, if any, for its
     `control_style`. Conflicts are only conflicts inside one game, so two games
     may use the same key.
   - `control_style` — `CONTROL_STYLE_TARGETS` (`targets`) for highlighted-target
     inputs, `CONTROL_STYLE_DIRECT_MOVEMENT` (`direct_movement`) for cursor
     steering, or `CONTROL_STYLE_CUSTOM_KEYS` (`custom_keys`) for a game's own
     declared action keys. These are `GameManifest` constants, not game names.
     Custom-key games declare `control_bindings`; there are no inherited target,
     mouse or gamepad gameplay actions. Both players' menu hints use their
     current keys, including shared actions and bindings without a `movement` flag.
     Supply `instructions_player_one_controls` and
     `instructions_player_two_controls` in `copy` for action explanations, not
     literal default keys: the instructions append each action title and its
     live binding in solo and versus. Missing control copy falls back to
     `player_one_control_description` / `player_two_control_description`.
   - `supports_multiplayer`, `supports_cpu_opponent` — whether multiplayer
     and a CPU-controlled second seat are offered. Direct movement keeps its two-human setup;
     custom keys can offer either a human or the CPU. A custom-key game's CPU
     tuning belongs in its own `tunables`, read by the game from `Settings`;
     the shared target-game difficulty picker is hidden. Use
     `cpu_opponent_description`, `instructions_cpu_summary` and
     `instructions_cpu_controls` in `copy` to explain that opponent. CPU
     instructions otherwise use the solo summary and generic automatic-play
     wording. That selector creates a multiplayer session with an automatic
     second seat, not `GameSession.is_single_player()`. A game can separately own an intrinsic
     solo CPU: Anti-Chess does, while clearing `supports_cpu_opponent` to keep
     its multiplayer mode exclusively local humans.
   - `solo_setup_choices` — keys of this game's declared choice tunables to
     offer in the solo confirmation, before play. Settings remains the source
     of truth. These choices keep setup available even on solo-only platforms;
     the player-count question collapses, but the choices are not skipped.
     Anti-Chess declares its White/Black option here.
   - `supports_single_player` — clear it for a game that is inherently two
     seats, such as a tug-of-war whose second end is held by a human or a
     bird. Mode selection then skips the player-count step and opens on the
     confirmation, where the human/CPU selector already asks the only real
     question. It is a presentation flag, not a guarantee: the platform still
     wins where a second seat is impossible, and `tests/game_shell_test.gd`
     drives every catalogued game through `configure_single_player()`, so the
     gameplay scene must still seat its second player rather than assert.
   - `default_lives_mode` — defaults new rounds to lives when no round-mode
     preference has been saved; omitted means Timer.
   - `uses_shell_round_rules` — true by default. Clear it for an untimed,
     self-paced match that calls `_end_round()` when its model reaches a
     result. The shell keeps elapsed time and shared round UI but does not
     start a timer or apply lives. Settings hides unused arcade round assists
     without deleting the player's shared preferences.
   - `unlock_rule` + `hidden_until_unlocked` — gate the game behind progress in
     another one. Subclass `GameUnlockRule`; every finished round is offered to
     every rule, so "playing A unlocks B" needs no framework change.
   - `store_items`, `store_slots`, `store_currency`, `store_preview_scene_path`
     — a shop where finished rounds buy cosmetics. See *A store of your own*.
   - `gallery_exhibits`, `gallery_stage_scene_path` — a turntable museum of the
     models the game is built from. See *A gallery of your own*.
   - `share_art_style`, `stats_url`, `tutorial_video_path`, `tutorial_poster_path`
     — share card and instructions media. `share_art_style` names one of
     `ShareCardArt`'s hand-drawn variants; anything it does not recognise —
     including leaving it unset — draws the neutral studio mark, never another
     game's art. Optional `local_tutorial_video_path`
     and `local_tutorial_poster_path` override instructions media only for two
     local humans; solo, CPU multiplayer and the game picker retain the primary
     media. Each empty override falls back to its primary counterpart.
   - `intro_scene_path` — an opening of your own, played instead of the
     framework's placeholder cards. It is only used when the build ships this
     game alone, because a collection has not chosen a game yet when the intro
     runs. See *Shipping one game on its own*.
   - `credits` — your game's own credits sections, in the same
     `{"heading": …, "lines": […]}` shape as `StudioInfo.CREDITS`. They lead
     the credits roll when the build ships this game alone.
   - `theme` — a `GameTheme` with your logo, colours and optional UI skin,
     materials and menu sounds. Like the intro, it only dresses the shared
     screens when the build ships this game alone. See *Shipping one game on its own*.
5. Put the game's own tests in `res://games/<id>/tests/`. The framework-level
   `tests/game_shell_test.gd` picks your game up from the catalog
   automatically and drives it through a full round, results, stats, share and
   replay cycle — no edit needed.

The menus need no edit either. The title screen has a single **Play** button,
and the picker behind it builds one card from `GameCatalog.available()`, in
`menu_order`, so a new game appears as soon as its manifest does — and
disappears again behind an `unlock_rule` until earned. The card's moving
thumbnail is the same `tutorial_video_path` clip the instructions screen uses,
falling back to `tutorial_poster_path` and then to a labelled placeholder, so a
game with no recording yet still gets a card of the right shape.

### A store of your own

Rounds can pay out, and the payout can buy cosmetics. The shop is data: a game
declares what it sells and the framework does the rest — there is no store
code to write, and nothing under `autoload/`, `scenes/` or `ui/` knows which
game it is serving.

Declare four manifest fields (all optional; `store_items` alone turns the shop
on):

- **`store_items`** — the shelf. Each entry needs an `id` (globally unique and
  permanent — it is a save key), a `title` and a `price`. Add `description`,
  `badge` (a glyph for the fallback art), `color`, `heading` to group
  consecutive cards, `requires_achievement` to gate one behind an unlock, and
  `"default": true` for a free item the player starts in. `color` may be a
  `Color` or an HTML string — a manifest is data, so the store coerces it and
  warns on anything else instead of asserting the shop out of existence.
- **`store_slots`** — where items are worn, one item each. An item declares a
  `kind`, a slot accepts a `kind`, and any item fits any matching slot, so one
  purchase can dress both sides of a duel. Omit `empty_title` to make the slot
  always full — give it a `default` item instead of an empty state.
- **`store_currency`** — what the points are called and how a round earns them:
  `round(best_score × points_per_score) + round_bonus`, plus `win_bonus` when
  the player beat a **CPU** opponent, clamped to `max_per_round`. A two-human
  duel and a round with no opponent pay no bonus — there is nobody to have
  beaten. Scores differ by orders
  of magnitude between games, so **each game keeps its own wallet**; one shared
  purse would let the loudest game buy out every other shop.
- **`store_preview_scene_path`** — an optional `Control` scene drawn as the item
  picture. It is handed the item dictionary through `configure(Dictionary)`,
  exactly like a share card, and may also expose `set_preview_running(bool)` if
  it animates. Without one the store draws the item's `badge` on a coloured
  plate, so a store always renders something sensible.

`GameShell` banks the payout itself when a round ends; override
`_round_points_earned(player_one_total, player_two_total)` only if the default
rule is wrong for your game (return a negative number to decline the payout
entirely).

Read the result back through the `Store` autoload — usually from
`_load_round_settings()`, so a change made mid-round applies at the next
countdown rather than mutating the round being played:

```gdscript
var hat: String = Store.equipped_id(game_id(), "pit_hat_red")
```

Purely cosmetic changes can instead follow `Store.equipped_changed` live, as
Creep Code's keeper does, provided they do not alter a round's rules or state.
The shop coalesces the equip, wallet and purchase notifications into one card
refresh so a purchase cannot remove its own deferred focus target. Rebuilt
previews retain the reduced-motion policy. The grid and its header use native
window sizing for readable text and touch targets on a stretched phone canvas;
`StoreItemCard.set_ui_scale()` applies that size to new action buttons too.

The rest of the API is `points`, `add_points`, `is_owned`, `purchase`, `equip`,
`unequip`, `equipped_item`, `items`, `slots`, `describe` and `format_points`,
all taking the game id first. State lives in `user://store.cfg` (sections
`points`, `owned`, `equipped`) and, like `settings.cfg` and `achievements.cfg`,
is **merged** into the stored file — a one-game build never deletes another
build's purchases. Ownership never regresses, and an equipped id the build does
not recognise falls back to the slot's `default` rather than being dropped.

The **Store** button appears wherever the shop has a game to serve: on the title
screen of a standalone build, and on the pause overlay of any build while a
round with a store is running. Both hide themselves otherwise, so declaring no
store costs nothing. `tests/store_test.gd` walks `GameCatalog.all()`, so your
shop is covered the moment the manifest declares it.

### A gallery of your own

The gallery is a museum for the models a game is made of: a list of exhibits on
the left, one of them on a turntable on the right, and a written label under it.
It exists because a game's art is usually only ever seen at gameplay distance,
moving, half-occluded — and because "what am I actually looking at" is a fair
question to be able to answer.

Like the store it is pure data, and unlike the store it has **no autoload**: a
shop has a wallet to protect, a museum has an opening time and a door. Two
manifest fields turn it on, and both are required:

- **`gallery_exhibits`** — what is on the plinths, in order. Each entry needs an
  `id` (unique within the game) and a `title`. Add `description` and `facts` (an
  array of short specification lines) for the label, `heading` to group
  consecutive entries under a subtitle, `badge` and `color` for the fallback art
  and the list accent, and `requires_achievement` to leave an exhibit **listed
  but not viewable** until it is earned — a collection reads as something to
  finish rather than something the game is hiding.
- **`gallery_stage_scene_path`** — the `Control` scene that actually draws a
  model. This is the one piece a game writes itself, because only the game knows
  what its models are.

The stage contract mirrors `share_art_scene_path` and `store_preview_scene_path`:

| Method | Required | Meaning |
| --- | --- | --- |
| `configure(exhibit: Dictionary)` | expected | Put this exhibit on the plinth. A stage without it is a mistake the screen survives rather than a crash: `gallery.gd` warns once and falls back to the exhibit's badge. |
| `set_view(yaw: float, pitch: float, zoom: float)` | no | Yaw and pitch are **offsets in radians from the exhibit's own default framing**; `zoom` is a magnification where `1.0` is that framing. Without it the screen hides the whole controls row rather than showing buttons that do nothing. |
| `set_auto_spin(enabled: bool)` | no | The screen has already checked reduced motion before calling. |

Positive yaw walks the camera anticlockwise around the model — the same
direction a drag to the right does, so the buttons and the mouse can never
disagree. Positive pitch raises the camera.

Every orbit action has an on-screen button as well as a drag, a wheel notch and
a touch drag, because the arrow keys are deliberately **not** bound: `ui_left`
and friends move menu focus, and a viewer that swallowed them would trap
keyboard and d-pad players inside the picture with no way out.

Reduced motion parks the turntable and **disables** the auto-spin toggle with a
tooltip saying why, rather than leaving a switch that silently does nothing; the
player can still turn the model by hand. The `facts` lines are the reason an
exhibit is never carried by the picture alone.

`games/chicken_pit/ui/gallery_stage.gd` is the worked example: a request-driven
`SubViewport` turntable that builds every exhibit from the same `ChickenRig` and
`Scenery` calls a match uses — including the hats the player bought in the store
— and frames each one automatically from its bounding cylinder, so a new exhibit
needs no hand-measured camera distance.

The **Gallery** button follows the store's rule exactly: the title screen of a
standalone build, and the pause overlay of any build while a round with a
gallery is running. `tests/gallery_test.gd` walks `GameCatalog.all()`, so your
museum is covered the moment the manifest declares it.

### Chicken Pit — 3D inside the shared shell

`games/chicken_pit/` hosts a bright, vertex-painted toy farm in an isolated
`SubViewportContainer` under `%Playfield`. The HUD, pause, results, stats and
share flow remain the ordinary 2D `GameShell`; the framework does not need
a 3D-specific shell or a different renderer.

`pit/pit_state.gd` is a node-free model: alternating pull actions build
strength, exponential decay drains it, and analytically integrated strength
differences move the knot. Timer matches bank ground held; Lives matches
re-centre after each pin and finish when either coop loses its last life.
The game specializes the shell's active-seat and elimination hooks for that
duel rule instead of changing the shared life pool. CPU birds use the same
pull path as humans, including its hard rate ceiling.

`pit/pit_view.gd` reads that state to animate twelve rigid-part chickens,
the rope, camera, crowd and pooled particles. Original mesh sources and
offline-authored WAV audio live with the game. Reduced motion parks the camera
and straightens the rope; the view is inert-safe headless. The menus retain
their warm dusk theme while the pit is deliberately sunny.

The manifest uses `CONTROL_STYLE_CUSTOM_KEYS`: its own rebindable action
clusters, a selectable CPU, and live keyboard instructions instead of
mouse/target prompts. It also ships the project's first store: rounds pay
**Feathers**, and `ui/hat_preview.tscn` shows a hen wearing each of the seven
hats on the shop shelf. The two coops are separate slots, so one purchase can
dress either side. It ships the project's first **gallery** too:
`ui/gallery_stage.tscn` puts nine exhibits on a turntable — both coops' birds
(wearing whatever the store has equipped), the bleacher bird, the barn, the pit,
the bleachers, the oak, the bunting, and the whole showground behind the *Chicken
Run* achievement. Every one is built by the same `ChickenRig` and `Scenery` calls
the match uses, so the display case can never drift from the game. See the game's
`DESIGN.md`, `AGENTS.md` and regression
scripts for the model/view contract and authoring commands. Its earlier
React/Three.js prototype is no longer kept in a `web` folder.

The opening preserves the old prototype's `IntroScene`: the same recording
(`assets/intro-narration.mp3`) and the same words. The web build crawled them
past in one block; here they are cards that fade from one to the next, like
`scenes/boot/intro.tscn` and Dead Metal Jam's opening, so all three openings in
the project read as the same product.

The cards are timed **to the recording, not to a guess**. Each entry in
`cue_times` is an offset into the clip taken from the middle of one of its own
pauses, so a card never turns over mid-word, and no card is up for less than
`MIN_CARD_SECONDS`. `tools/measure_intro_cues.py` is what produced them:

```bash
python tools/measure_intro_cues.py games/chicken_pit/assets/intro-narration.mp3 cards.txt
```

It decodes the audio with ffmpeg, finds every pause, and fits one card per line
of `cards.txt` to them — merging the shortest neighbours when the recording
leaves no room to read them, which is why eleven cards carry twelve sentences.
The cues belong to *that* recording: replace the clip and re-run the tool, which
is what `chicken_pit_intro_test.gd` is checking when it asserts every cue still
fits inside the stream. If `cards` and `cue_times` ever fall out of step,
`_build_cues()` warns and spaces the cards evenly rather than dropping any — a
transcript that skips a line is worse than one that is slightly out of time.

The web build also looped a 45-second clip under a 50-second animation, so the
narration restarted over its own last lines; the total runtime here is read
from `narration.get_length()`. And the browser needed a *Start Game!* button to
satisfy its autoplay policy, which Godot does not.

The cards are the narration's transcript, which is what makes a 45-second
voice-over acceptable: the story is never sound-only, and it survives the music
bus being turned down. The transition is a cross-fade, so reduced motion keeps
every card and every cue and only drops the small scale-in.

### Anti-Chess — a self-paced 3D match

`games/anti_chess/` uses the same isolated 3D viewport and inherited 2D shell
for a jade-and-brass chess table. Solo offers White or Black against the CPU;
White always starts, even when that is the CPU. Local multiplayer is exclusively
two humans. The solo camera faces the chosen colour at a frontal angle; local
play uses a true overhead view. Right drag or held arrows orbit in solo and pan
without tilting locally; the wheel zooms, Home resets and F flips. WASD/Enter
and mouse/touch selection share the same legal-move path.

Captures are compulsory. Kings are ordinary pieces, there is no check or
castling, and a player wins by having no pieces or no legal moves. The pure
model includes en passant, five explicit promotion choices (including king),
repetition and fifty-move draws. The seeded CPU spreads its search over frames,
and pause, replay and exit cancel or suspend pending work.

The manifest opts out of arcade Timer/Lives rules. The HUD shows pieces left,
results show pieces given away, and winner copy follows the model rather than
comparing material. Solo P1 always owns the human's chosen colour across the HUD,
results, stats, achievements and scorecards. Colour and CPU difficulty change
next match, including on replay. Original batched geometry, vector art, short
offline-authored sounds and the menu skin live in the folder. Separate solo/local
instruction videos show their respective camera and controls. See the game's
`README.md` for rules, asset authoring and graphical/headless regression commands.

Its scaffold-backed **Store** offers six free piece palettes and unlockable
Bronze, Silver, Gold, Platinum and faceted Diamond finishes. Completed matches
pay Coins for participation and pieces given away, plus a bonus for beating the
CPU by the actual chess win rule. Independent P1 and P2/CPU finishes apply next
match, follow the human's chosen side, and persist through the shared `Store`.
The store portraits reuse the refined match models; player-colour rings, one
on White and two on Black, remain visible even when both finishes match.

### Anti Checkers - English giveaway checkers in 3D

`godot --path . -- --game=anti_checkers` launches a self-contained companion
to Anti-Chess, discovered by the same catalog. A real, isolated 3D viewport
renders an original walnut table and garnet/ivory checkers beneath `GameShell`.
Solo offers Red or Ivory against three CPU levels; Red always starts. Local
play is two humans sharing an overhead board. Mouse/touch, rebindable square
keys, orbit/pan, zoom, flip and reset all use the same legal-move path.

The node-free model uses 8 x 8 English/American rules: forward-only men,
short-range kings, globally compulsory captures and mandatory same-piece
jump chains. Any available capture may be chosen; no longest-chain rule
applies. Reaching the far row crowns a king and ends the turn. Having no
pieces or no legal move wins; capturing the opponent's final checker makes
the opponent win. Repetition and forty-move draws prevent endless king play.

The shared Timer/Lives choice is preserved but unused. A chain counts as one
turn in the ledger and statistics. Live scores count pieces left; results
count pieces given away while the winner follows the model. Solo P1 always
denotes the human, including Ivory. Original vector art, captioned sound cues,
standalone branding, achievements and two-sided scorecards stay game-owned.
The poster and complete written instructions do not require a tutorial video.
See `games/anti_checkers/README.md` for rules and focused regression commands.

### LaZer NFC - memory, physical tags and a real 3D laboratory

`godot --path . -- --game=lazer_nfc` follows the normal studio sting, skippable
laboratory briefing and main menu. The standalone Play button and collection
picker both reach `games/lazer_nfc/gameplay.tscn`, inherited from `GameShell`.
No new autoload or game-name branch is required. The game owns its battery
pool across growing memory rounds; the shell owns pause, results, achievements,
scorecards and Play Again.

A warm, handmade 3D toy laboratory gives the robots personality without
revealing the next answer. Listen to the whole sequence, then recall grey
robots against individual deadlines. Every colour has a shape and one of
seven original instruments; all fourteen dark/light variants also ship.
Combos, fast recalls, motion bonuses and double-bonus clean sweeps reward
practice. A wrong answer costs a battery without restarting the deadline;
an escape costs a battery and advances. At twelve robots the learned pattern
rolls forward with a fresh ending instead of repeating a solved melody forever.

The READY screen lets players learn every sound for free. Rebindable colour
keys default to 1-7 in spectrum order, with Q/E held for dark/light shades.
The first four active colours are red/yellow/green/blue, so their keys are
1/3/4/5. NFC-less devices immediately get a labelled colour pad with a shade
selector. Touch answers flag the run Assisted and halve its score once;
practice previews do not. Difficulty changes apply next experiment, while
voice, haptics, pad visibility, bindings and visual accessibility update live.

The **Android - LaZer NFC** preset preserves its user directory and portrait
feature overrides but no longer bypasses the framework boot scene.
The game-local v2 reader uses UID-only discovery, per-tag debounce, callback
age compensation and explicit pause/exit cancellation. Guided binding always
offers a keyboard/touch exit and merges its `ConfigFile` save without replacing
bad reads. A printable label sheet and reproducible audio/tutorial sources
live in the game folder. Build the native AAR and install Godot's Gradle export
template before exporting; see `games/lazer_nfc/README.md` and
`games/lazer_nfc/android/README.md`.

### Creep Code - an enchanted dungeon observatory

`godot --path . -- --game=creep_code` launches a solo ritual on **one persistent
3D stage**, transforming from Sunrail to Whisper Shaft to Echo Garden. There
is no hub or walking commute. Direct clicks/taps and rebindable keys shift a crystal
frame, choose a numbered listening seal or follow equal-cost garden walkways.
After each solve a keystone joins the constellation and the next mechanism
unfolds automatically. Interact skips a flourish without also arming the next
puzzle. The shaft is ready to listen on arrival; the garden's first wave is
automatic and can be revealed instantly. Retry keeps a revealed garden's
echoes. There is no jumping or combat.
The stage uses the full width on desktop and phone, with a compact, unboxed
bottom action row rather than a sidebar. The actual crystals, listening seals,
garden platforms and their numbers are clickable/tappable. The Grimoire action
opens rules and hints on demand, freezing puzzle time and input.

Its original dungeon meshes use weathered stone, aged brass, candles and
blue/violet runes: a circular dais, broken vault, old books, floating solar
crystals, a turning listening astrolabe and a blooming rune garden. Cached
procedural weathering, bounded local lights, soft candle modulation, orbiting
rings, keeper hops, sparks and curved keystone flights stay on the Compatibility
renderer. Reduced motion uses settled poses and short opacity-only handoffs;
effects-off removes particles and light pulses without removing useful
illumination. The game owns every asset and
uses no downloaded models or extra packages.

The game inherits `GameShell`, declares `custom_keys` and disables shell round
rules. Its three pure models own capacitor timing, comparison charges and the
shortest-route budget. A scene-owned `PuzzleManager` spans all ritual acts and
coordinates signals; it is deliberately not a project autoload. The isolated
3D viewport follows the same framework boundary as Chicken Pit, without
importing any other game's code.

Restoring each relay immediately unlocks its game-owned achievement, so
progress survives returning to the title or restarting the application.
Replays and failed attempts never revoke those flags. An incomplete save
prelights earned seals and resumes at the first missing relic; a complete save
starts a fresh full ritual without erasing its permanent achievements. The
completed constellation automatically reaches shared results and scorecards.
Scoring is explicitly **one point per different relic solved this visit, at
most three**; permanent seals and current constellation progress are separate.
Hints, retries and
failures cost no points, and speed earns no bonus. Only the armed Sunrail
counts down from 90 seconds; pause and the grimoire freeze that
budget. Shaft listens and garden crossings are charges, not seconds. The
results' elapsed time is informational.
There is one fixed configuration: 12 crystals, 15 listening seals/four questions
and a 5x5 garden/eight crossings, retaining the previous default balance.
There is no difficulty setting or solo setup prompt. Legacy difficulty values
are ignored without deleting saved progress. An untimed Sunrail assist and all
shared visual accessibility settings apply live. The standalone build has a
15-second, skippable opening demonstrating the actual evolving stage and
constellation behind the regular centered intro subtitles, not a side panel.
Its demonstration relays never touch saves. An astral-key title icon and
matching ritual poster also appear
through the existing theme and picker contracts; there is no prerecorded clip.

The keeper also has a **cosmetic outfit store**, declared entirely by its
manifest. Finishing a ritual banks one **Star Shard** per relic solved that
visit, capped at three. Warrior, ranger and wizard outfits each cost three
shards; the original keeper look is free. Purchases equip immediately, including
from pause, without changing puzzles or restarting the stage. Gameplay, the
opening and the rotating shop portraits share the same game-owned meshes and
weathered material. Wallets, ownership and the equipped outfit use the existing
merged `user://store.cfg`; previews respect reduced motion and never change
equipment themselves. The shop is reached from the standalone title screen or
the running game's pause menu.

The `Windows - Creep Code (standalone)` preset activates `creep_code`,
excludes the other games and development helpers, and reserves
`DeskCanSaw Games/Creep Code` as its stable user directory. Source launches
continue using the common development profile, just like the other games.
See `games/creep_code/README.md` for all six puzzle designs, the three
implemented mechanics, extension points and focused regression commands.

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
godot --path . -- --game=triangle_rush
godot --path . -- --game=desk_can_saw
godot --path . -- --game=chicken_pit
DCS_GAME=dead_metal_jam godot --path .     # same, for launchers that cannot pass args
godot --path . -- --game=all              # override the default pin with the collection
```

The checked-in `dcs/build/single_game_id` defaults to `desk_can_saw`.
The reserved `all` selector works with `--game`, `DCS_GAME`, and
`GameCatalog.restrict_to()`; it explicitly clears a lower-priority pin rather
than falling back to it. `clear_restriction()` restores the configured launch
selection, not necessarily the collection.

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

The rows that *are* shown speak in traits rather than titles. Their captions and
help text live in `settings_menu.gd`'s `SETTING_COPY` as neutral defaults, and
`_setting_text(key)` lets the pinned game reword any of them from its
`GameManifest.copy`:

| `copy` key | Neutral default |
| --- | --- |
| `setting_one_button_title` / `setting_one_button_help` | "One-button target select" |
| `setting_object_size_title` / `setting_object_size_help` | "Object size" |
| `setting_gameplay_speed_help` | "Slows the objects you chase next round." |
| `setting_audio_captions_help` | "Shows text for scoring, misses and countdown cues." |
| `setting_pad_speed_title` | "Pad cursor speed" |
| `setting_movement_scheme_title` | "Movement scheme" |
| `setting_target_button_title` | "Target %d button" |

If a caption you need only makes sense for your game, add a `copy` key — never
the game's name to the shared scene.

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

Dead Metal Jam and Chicken Pit provide two useful examples. Dead Metal Jam's
is a **staged demonstration** — the game's own actors walk out and are shot
with notes, so the opening teaches the verb before the menu appears. Chicken
Pit's is **narrated** — a recording plays while its transcript turns over in
cards timed to the recording's own pauses, so the opening tells the player
where the name came from. Both run their cards off a cue list stepped in
`_process` rather than a chained tween, which is what lets a headless test
drive the timeline; both keep a progress bar so the player can see the end
coming; both respect reduced motion; and both clear their own music in
`_finish()` (`AudioManager.stop_music()`), because the main menu's track is
optional and an opening that does not tidy up runs on underneath it.

If an opening carries speech, put the words on screen as well. Chicken Pit's
cards *are* the narration's transcript, which is what keeps a 45-second
voice-over from being sound-only — and it means the story still lands with the
music bus at zero.
Dead Metal Jam's — `games/dead_metal_jam/intro.gd` — is worth copying: it walks
the game's real `RustyClanky` actors across a stage so the opening cannot drift
away from the game, synthesises its own audio rather than adding sounds to
`AudioManager`, and honours reduced motion, intense visual effects and audio
captions.

Creep Code's `games/creep_code/intro.tscn` is a shorter, skippable **3D
awakening**. It reuses the actual dungeon and lights three demonstration
relays over 15 seconds, without connecting to progression saves. Its timeline
uses the standard intro's unboxed subtitle, skip button and progress track
over a full-width stage. It is directly driven by the expedition suite, and
the real-window view suite covers landscape, portrait and ultrawide framing.

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

The shared presentation reads it without naming a game:

- `background.gd` — shared screens instance it, so their gradient and glow
  follow the game. An optional `background_material` replaces the shader while
  retaining aspect correction and reduced motion. A gameplay scene can override
  its inherited backdrop with its own art instead.
- `main_menu.gd` — the rotating plaque takes `logo_texture_path`, tinted with
  `logo_color`, and its lights and slab take `light` and `plaque_color`. The
  logo is scaled to span the plaque, so any resolution or aspect fits. Optional
  `plaque_material` and `menu_motion` customize the surface and interaction feel.
- `router.gd` — at boot it hands `ThemeDB.get_project_theme()` to
  `GameTheme.restyle()` and puts the result on the root window, which every
  Control inherits. That swaps the studio accent for the game's wherever
  `dcs_theme.tres` uses it — focus rings, sliders, tab underlines — while
  leaving spacing, fonts and every neutral shade alone unless the game supplies
  a partial `ui_theme`, which is merged last into an independent runtime copy.
- `menu_screen.gd` and `game_shell.gd` — both call `GameTheme.restyle_tree()`
  on themselves in `_ready()`. A `Theme` only reaches what a scene left
  unstyled, and the HUD and the credits roll bake the accent into per-node
  `theme_override_*` entries, scene-local styleboxes and `ColorRect`s. The
  repaint walks the tree and substitutes exactly the studio accents, so the
  round timer, mode title, callouts and credit headings follow the game. Menus
  additionally opt into skinning scene-local widget styles while preserving
  authored padding; gameplay retains its semantic panel styles.
- `audio_manager.gd` — optional `ui_sounds` supplies focus, confirm and back
  streams. Omitted cues retain the original audio, and gameplay/achievement
  sounds are not replaced.

The optional presentation fields are:

| Field | Contract |
| --- | --- |
| `ui_theme: Theme` | Partial widget overrides. `MenuHeading` and `MenuSectionHeading` Label variations distinguish UI typography/colour from body text and player identity. Empty styles and border-only overlays retain their transparency. |
| `ui_sounds: GameUISoundBank` | `focus`, `click`, `back`, their dB gains, and `focus_cooldown_ms`. A focus `AudioStreamRandomizer` can provide non-repeating variants. All cues use the existing SFX bus. |
| `background_material: ShaderMaterial` | Supports `top_color`, `bottom_color`, `glow_color`, `aspect`, and `speed`; zero speed must freeze all decorative motion. Materials are duplicated per screen. |
| `plaque_material: Material` | Duplicated onto the title plaque; a `StandardMaterial3D` also receives `plaque_color`. |
| `menu_motion: GameTheme.MenuMotion` | `SPRING` retains the studio animation; `FIRM` uses non-overshooting button transitions and restrained plaque feedback. |
| `style_share_card: bool` | Opts the shared result card into the payload game's logo, palette and frozen backdrop, including in collection builds. Defaults to `false`, preserving existing cards. |

Share artwork remains game-owned through `GameManifest.share_art_scene_path`:
a `Control` scene implementing `configure(Dictionary)`. The shared card also
accepts `accuracy_caption`, `hits_caption`, and `combo_caption` alongside their
display values, plus `rematch_title` and `rematch_copy` for the panel shown
when there are no achievements. `qr_heading` and `qr_copy` describe the QR
destination, so a studio-homepage link need not promise per-run stats.
Omitted keys retain the default copy.

Keep these resources in the game's folder. Dead Metal Jam provides an example
with original SVG plates, a condensed variation of Godot's built-in font and
in-engine synthesized menu cues. No external fonts or sound downloads are needed.

Each game declares its own standalone look, selected automatically by
`--game=<id>` or the corresponding standalone export preset:

| Game | Standalone presentation |
| --- | --- |
| Triangle Rush | Mint neon over midnight blue, a rushing-triangle logo, chamfered buttons and panels, triangular toggles, a geometric backdrop and an etched plaque. Keeps the springy arcade menu motion. |
| Desk-Can-Saw | Safety yellow over warm wood and dark steel, a saw-and-can logo, raised workbench controls, mechanical toggles, pegboard and wood-grain scenery, and a timber plaque. Uses firm menu motion. |
| Dead Metal Jam | Amber stage lights over cold steel, textured metal plates, condensed headings and mechanical menu cues. Uses firm menu motion. |
| Chicken Pit | Cream and gold over turf shadow, barn-red boards, fairground bunting and an original full-colour toy-farm cover. Its share card uses the same frozen backdrop and portrait with pull/notch captions. Keeps the springy menu motion. |
| Anti-Chess | Jade, parchment and brass, an original chess crest, a restrained checkerboard backdrop and firm menu motion. The short opening teaches the reversed objective; scorecards use its own chess artwork. |
| Anti Checkers | Garnet, ivory and warm brass, original turned-checker artwork, a subdued checkered backdrop and firm menu motion. Its opening explains forced jumps and crowning; scorecards show both sides' giveaway totals. |

Triangle Rush and Desk-Can-Saw keep their visual resources under their own
`assets/` and `ui/` folders, with partial widget skins in `ui/menu_skin.tres`.
They retain the shared readable fonts and menu audio. Their low-contrast
backdrops remain aspect-correct from portrait to ultrawide, and reduced motion
freezes their decorative animation. No framework screen branches on a game ID,
and selecting either game inside the collection still uses the studio theme.

Triangle Rush's gameplay scene overrides the inherited background with a plain,
opaque navy `ColorRect`, leaving its faint player halos and target silhouettes
readable without the menu's geometric grid. Its menu theme is unchanged, and
the plain backdrop fills every viewport without taking input.

Focus audio stays on `focus_entered`, including mouse hover that moves focus,
and initial screen focus stays silent. Buttons whose navigation handler already
plays a cue use `metadata/ui_sound_handled = true` to avoid an extra confirm
when a custom bank is active.

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

That makes a standalone release **export configuration only**. Five games
already have a preset — *Windows — Triangle Rush / Desk-Can-Saw / Dead Metal Jam
/ Chicken Pit (standalone)* plus *Android — LaZer NFC* — each pinned by its own
feature tag, spelled as the initials of the game's id (`tr`, `dcs`, `dmj`, `cp`,
`lazer_nfc`). A preset carries the tag and drops the other games:

```ini
custom_features="dmj"
exclude_filter="games/triangle_rush/*, games/desk_can_saw/*"
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

The *Windows — DCS Collection* preset carries `custom_features="collection"`;
`build/single_game_id.collection=""` clears the source project's Desk-Can-Saw
default so that export still ships the full collection experience.

The user-dir override is **not optional**. Without it the standalone build
shares `user://` with the collection, so saves, settings and achievements
collide. Anti-Chess and Anti Checkers have no preset yet, but their tags are
already reserved in `project.godot` (`antichess`, `anticheckers`) precisely so
that whoever writes those presets cannot ship a build that quietly shares the
collection's save folder. Add the three `project.godot` overrides
(`build/single_game_id.<tag>`, `config/name.<tag>`,
`config/custom_user_dir_name.<tag>`) **before** the preset, not after.
Source runs, including the default Desk-Can-Saw launch and `--game`
overrides, keep the existing development user directory. The engine fixes it at
startup, so these runs still share the collection's save files. That is fine for
playtesting, and the reason the override belongs in the preset.

`export_presets.cfg` is tracked deliberately — an untracked preset file means
nobody else can reproduce a release. Keep credentials out of it; the Android
keystore path and password belong in the editor's
per-machine settings.

One caveat the feature-tag system cannot cover: `[editor_plugins] enabled` in
`project.godot` is a plain list, not a feature-overridable key, and it currently
names `res://games/lazer_nfc/android/plugin.cfg`. Every editor session and every
export loads it, including builds that ship no LaZer NFC, and a clone made
without `--recurse-submodules` will error on open because the file is inside a
submodule. If you add an editor plugin for a game, expect it to be global.

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
| `pit_pull_one_a/b/c` | Remappable; defaults to Q, W and E |
| `pit_pull_two_a/b/c` | Remappable; defaults to I, O and P |
| `ui_accept` / `ui_cancel` | Godot defaults (menu navigation and back) |

Gameplay keys can be changed under **Settings → Controls** — which only exists
while a game is running, because a key binding belongs to a game — and are
saved in `user://settings.cfg`; assigning an occupied key swaps the two
bindings within that game. Two different games may use the same key, since only
one of them is ever running.

Renaming a saved settings key is a migration, never an edit.
`Settings.load_settings()` ends in `_adopt_renamed_keys()`, which reads the old
key **only** when the new one is absent and leaves the old one on disk, so an
older build sharing the same `user://` keeps working.
`LEGACY_ONE_BUTTON_TARGETS_KEY` is the worked example — the one-button setting
was renamed off the first game that used it once it became a `targets`-style
option. Keep every legacy constant forever; deleting one silently resets
players.

A game with no `control_bindings` of its own
inherits the built-in set for its `control_style`, which is where Triangle Rush's
six target keys come from. Desk-Can-Saw declares four movement keys (the arrow
keys by default), Dead Metal Jam declares its octave and self-test keys, and
Chicken Pit declares three pull keys per coop.
Controller 1 controls Player 1 and Controller 2 controls Player 2. In the
`targets` control style they share three remappable target buttons (A, B and X
by default).
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
a sentence underneath restates the choice in plain words, and the target-game
CPU difficulty row lives inside the same card because it only applies to one
of the two answers. Multiplayer defaults to the CPU when the manifest offers
one, so a lone player can start without finding a second person first.
Target-game CPU opponents offer Easy
(Baby seed), Medium (Hard seed) and Hard (Impossible seed) profiles, which adjust
reaction time and accuracy. Custom-key games retain the human/CPU selector but
describe their own opponent and configure it through their declared Game
settings, without implying those target presets apply. Direct-movement games
share one screen between two humans; they and games with
`supports_cpu_opponent = false` hide the selector entirely. The
confirmation body scrolls, so the step survives portrait phones and the taller
CPU layout. Android and iOS builds expose single-player mode
only. Games may declare `solo_setup_choices` to ask meaningful questions before
a solo round: Anti-Chess uses this for White/Black without presenting a second
CPU/human question. Choices remain available when multiplayer is unavailable.

Where the player count has only one answer — a game that clears
`supports_single_player`, or a gated game with a single unlocked route — the
step collapses: the screen opens on the confirmation with no stepper and no
**Change Mode** button, and **Back** leaves for the game picker rather than
returning to a question with one option. Chicken Pit uses this; both ends of
its rope are always pulled, so only *who plays as Player 2* was ever a choice.

The instructions screen is shown after mode selection by default. Its
**Show instructions when starting a mode** toggle is persisted, and the same
preference can be restored under **Settings → Gameplay**.

It leads with a captioned walkthrough clip of a real round of the selected game
(`games/<id>/assets/video/tutorial.ogv`), which takes roughly two thirds of the body
width so the round is actually readable, alongside the control cards and rules
summary. A manifest's optional local video/poster overrides select footage for
human-vs-human play; Anti-Chess uses a separate overhead walkthrough.
Playback starts automatically and repeats on a loop so a viewer can keep
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
exclude filter, and `games/*/tools/*` for game-owned drivers, to keep recording
code out of shipped builds. The included presets exclude both.
The two score-chase walkthroughs demonstrate Timer rounds regardless of saved
preferences or a game's launch default; Dead Metal Jam's take uses three lives.
Chicken Pit's 3D take uses a scripted puller that rotates the game's own
`Q`/`W`/`E` bindings at a legal cadence so the rope trends one way over the
clip's length, and `$Qualities` in the recorder drops its encoder quality,
because grass, bunting and a moving camera otherwise cost Theora twice what a
2D clip does. It teaches the rhythm rather than staging a pin — the CPU bird is
seeded from the shell's RNG, so no scripted ending survives a re-record.
Anti-Chess supplies `games/anti_chess/tools/tutorial_driver.gd`, discovered by
convention rather than another shared gameplay branch. Its solo and local
variants become `tutorial.ogv` and `tutorial_local.ogv` in that game's own
`assets/video/`, each with a matching poster. `-Games anti_chess` records both
without touching
other games' clips. The driver uses real legal moves and explicitly labelled
practice positions to teach compulsory captures, promotion and giveaway wins.
Captures use a unique temporary directory and isolated user profile per recording
invocation, and only completed encodes replace the shipped media.
Recording overrides never persist to the player's settings.

The sample unlocks **Solo Starter** after the first completed single-player
round and **First Win** after Player 1's first multiplayer victory. A Player 2
win with at least 25 points awards **Race condition** instead — the joke is
losing the race you were leading, so a draw does not count. No game is gated:
every game the catalog discovers is listed in the picker from the first launch,
and Desk-Can-Saw offers both of its modes straight away. The framework keeps
`unlock_rule` and `hidden_until_unlocked` for a game that wants a gate, along
with the fanfare and visual celebration a first unlock triggers. Achievements
are stored in `user://achievements.cfg` and never regress after
later matches. Store wallets, purchases and equipped cosmetics live beside them
in `user://store.cfg`. All three files are written by merging into what is
already on disk, never by rebuilding them: a standalone build registers only its
own game's keys and must not delete another build's saved options, unlocks or
purchases out of a shared `user://`. The gallery writes nothing at all — a
museum has nothing to remember, so its only state is the manifest and whichever
achievements have opened its gated exhibits.

Focused regression checks can be run headlessly. The **12 framework suites**
in `tests/` cover the shell, the menus and every game the catalog discovers:

```bash
godot --headless --path . --script res://tests/accessibility_test.gd -- --game=all
godot --headless --path . --script res://tests/custom_keys_test.gd -- --game=all
godot --headless --path . --script res://tests/gallery_test.gd -- --game=all
godot --headless --path . --script res://tests/game_options_test.gd -- --game=all
godot --headless --path . --script res://tests/game_select_test.gd -- --game=all
godot --headless --path . --script res://tests/game_shell_test.gd -- --game=all
godot --headless --path . --script res://tests/instructions_video_test.gd -- --game=all
godot --headless --path . --script res://tests/lives_mode_test.gd -- --game=all
godot --headless --path . --script res://tests/share_card_test.gd -- --game=all
godot --headless --path . --script res://tests/single_game_test.gd -- --game=all
godot --headless --path . --script res://tests/store_test.gd -- --game=all
godot --headless --path . --script res://tests/visual_effects_test.gd -- --game=all
```

Each game owns the rest under `games/<id>/tests/` — 45 of them at the time of
writing, spread across Dead Metal Jam (14), Chicken Pit (9), LaZer NFC (9),
Anti-Chess (8), Anti Checkers (4), Desk-Can-Saw (2) and Triangle Rush (1).
Counts drift as games grow, so enumerate the folders rather than trusting a
list. `*_fixture.gd` files are helpers, not suites:

```powershell
Get-ChildItem tests\*.gd, games\*\tests\*.gd |
  Where-Object { $_.Name -notlike '*_fixture.gd' } |
  ForEach-Object {
    $rel = "res://" + ((Resolve-Path -Relative $_.FullName) -replace '^\.\\','' -replace '\\','/')
    & godot --headless --path . --script $rel -- --game=all | Out-Null
    "{0} -> {1}" -f $_.Name, $LASTEXITCODE
  }
```

Run the suite against the full collection with `--game=all`: several checks
assert values that specific games declare, so they cannot pass in a standalone
run. `custom_keys_test.gd` uses an in-memory manifest to check CPU selection,
rebound action hints and style-specific controller rows without saving settings;
it also supports standalone launches. `single_game_test.gd` passes in both,
so a standalone build can still verify its own path. It exercises each declared
theme on the real title screen: logo tint, widget skin, flat-button text contrast,
plaque materials, backdrop aspect correction and the reduced-motion switch.

Five game-owned suites need a **real graphics window** and deliberately exit 1
under `--headless`, where they guard `DisplayServer.get_name() == "headless"`
and say so. Run them without `--headless`, and never read their headless exit
code as a regression:

- `games/anti_chess/tests/board_view_test.gd` — portrait/wide framing, square
  picking, modal UI and the full-board draw budget. Optional
  `--anti-chess-capture-dir=<absolute directory>` saves rendered examples.
- `games/anti_checkers/tests/board_view_test.gd` — the equivalent coverage, with
  optional `--anti-checkers-capture-dir=<absolute directory>` output.
- `games/chicken_pit/tests/pit_view_test.gd` — the 3D pit's `SubViewport`.
- `games/lazer_nfc/tests/lazer_nfc_layout_test.gd` — its responsive layout.
- `games/creep_code/tests/observatory_view_test.gd` — all three relics and the
  finale, camera framing, direct mesh/number input, compact bottom controls,
  persistent stage/constellation, effects and the regular-subtitle opening
  in landscape, portrait and ultrawide. It also covers the outfit models,
  rotating portraits and responsive shop with native-size text/touch controls.
  Optional `--creep-capture-dir=<absolute directory>` saves actual gameplay
  and intro frames.

Run tests sequentially and use an isolated user profile for host tests that
exercise persistence or complete real rounds.

The FPS counter is available under **Settings → Display** and is drawn by
`Router`, so it stays visible across scenes without each game implementing its
own counter.

## Placeholder assets

- `assets/images/dcs_logo.png` — the real DeskCanSaw Games logo.
- `assets/audio/ui_click.wav`, `ui_focus.wav`, `ui_back.wav` — synthesised UI
  blips generated for this template; replace them with your own.
- `games/<id>/assets/video/tutorial.ogv` and `tutorial_poster.webp` — generated
  from the placeholder games by `tools/record_tutorials.ps1`; re-record them once
  your own game replaces the sample.
- `icon.svg` — a simple placeholder mark, not the finished studio icon.

The theme uses Godot's default font. To use your own, drop a `.ttf`/`.otf` in
`assets/fonts/`, then set it as the theme's default font in
`ui/theme/dcs_theme.tres`.
