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
godot --path .                         # standalone Desk-Can-Saw, also the editor default
godot --path . -- --game=triangle_rush  # launch a different standalone game
godot --path . -- --game=dead_metal_jam
godot --path . -- --game=chicken_pit
godot --path . -- --game=all            # launch the full collection
```

Ordinary launches show only Desk-Can-Saw and default to three lives. A saved
round-mode choice or starting-lives preference still wins. The collection's
Triangle Rush unlock path remains unchanged; standalone Desk-Can-Saw is always
playable.

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
| `scripts/game_catalog.gd` | `GameCatalog` static registry — discovers `games/*/game.gd` and tracks the selected game. |
| `scripts/game_unlock_rule.gd` | `GameUnlockRule` base class for gating a game behind progress in another. |
| `scripts/game_shell.gd` | `GameShell` base class — the shared round loop, HUD, results/stats panels, pause, sharing and accessibility plumbing every game inherits. |
| `scenes/game/game_shell.tscn` | The matching reusable scene: HUD, results panel, stats panel and an empty `%Playfield` for your game to fill. |
| `autoload/settings.gd` | Stores, persists (`user://settings.cfg`) and applies player settings, including game-declared tunables. |
| `autoload/game_session.gd` | Holds player count, CPU configuration and controller assignment while moving between scenes, and reports gamepad presence via `gamepad_connected()` / `gamepad_availability_changed`. |
| `autoload/audio_manager.gd` | Music crossfades, an 8-voice SFX pool, bus volumes, UI/gameplay sound cues and semantic audio-caption requests. |
| `autoload/achievement_manager.gd` | Persistent achievement registry, per-game unlock progression and queued global achievement toasts. |
| `autoload/share_manager.gd` | Renders reusable 1200×630 session cards, downloads them on web and saves them for desktop sharing. |
| `autoload/router.gd` | `Router.goto(path)` — scene changes with a fade. Owns the top overlay layer (fade + FPS counter). `start_selected_game()` is the single definition of "begin the selected game", shared by the title screen and the picker. |
| `scenes/menus/game_select.tscn` | The picker the **Play** button opens: one card per available game, built from `GameCatalog.available()`. Reached only when there is more than one game to choose from. |
| `ui/menu_screen.gd` | `MenuScreen` base class: UI sounds, focus handling, `ui_cancel` to go back, responsive margins. |
| `ui/responsive.gd` | Helpers for margins, portrait detection and content width. |
| `ui/theme/dcs_theme.tres` | Base buttons, panels, sliders and tabs. A standalone `GameTheme` can recolour it and merge a game-owned partial skin. |
| `ui/components/background.tscn` | Animated gradient backdrop (shader), aspect-corrected and tinted by the current `GameTheme`. |
| `ui/components/achievement_toast.tscn` | Small reusable unlock notification used by `AchievementManager`. |
| `ui/components/audio_caption.tscn` | Reusable gameplay caption panel for important sound-only events. |
| `ui/components/game_card.tscn` | One game on the picker: looping muted walkthrough clip as a thumbnail, poster fallback, name, tagline and Play button. A view only — it reads no autoload. |
| `ui/components/player_avatar.gd` | Drawn placeholder for per-player portrait art; set `portrait` to swap in a real texture. |
| `ui/components/share_card.tscn` | Default score/achievement image; swap it or pass another scene to `ShareManager`. |
| `ui/components/share_preview.tscn` | Modal generated-image preview with close and open-original actions. |
| `ui/components/splash_motion.gd` | Lightweight animated geometry for logo stings and splash screens. |
| `games/triangle_rush/` | Triangle Rush: manifest, gameplay scene, targets, options, arcade theme and its own tests. |
| `games/desk_can_saw/` | Desk-Can-Saw: manifest, gameplay scene, cans, chainsaw cursor, unlock rule, workshop theme and its own tests. |
| `games/dead_metal_jam/` | Dead Metal Jam: manifest, pitch-detection instrument input, encounters, its own intro and theme, and its own tests. |
| `games/chicken_pit/` | Chicken Pit: a real 3D toy-farm tug-of-war inside the 2D shell, with deterministic pulling, three CPU birds, Timer/Lives rules, original models/audio, and its own regression coverage. |
| `tools/tutorial_capture.tscn` | Development-only recorder: plays a real round with a scripted demo player and captioned steps for the instructions video. |
| `tools/record_tutorials.ps1` | Records both tutorial clips through Godot's Movie Maker and encodes them to `assets/video/*.ogv` plus poster frames. |
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
  rebindable pull keys in Chicken Pit. Options apply
  from the next round and stack with the Gameplay assists (size and speed
  multiply, extra time is added on top), so they can make a game harder as well
  as easier.
- **One-button Triangle Rush** lets any of a player's assigned keys or mapped
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
   - `supports_multiplayer`, `supports_cpu_opponent` — whether a second seat
     and a CPU opponent are offered. Direct movement keeps its two-human setup;
     custom keys can offer either a human or the CPU. A custom-key game's CPU
     tuning belongs in its own `tunables`, read by the game from `Settings`;
     the shared target-game difficulty picker is hidden. Use
     `cpu_opponent_description`, `instructions_cpu_summary` and
     `instructions_cpu_controls` in `copy` to explain that opponent. CPU
     instructions otherwise use the solo summary and generic automatic-play
     wording. A CPU is a multiplayer session with an automatic second seat,
     not `GameSession.is_single_player()`.
   - `default_lives_mode` — defaults new rounds to lives when no round-mode
     preference has been saved; omitted means Timer.
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
mouse/target prompts. See the game's `DESIGN.md`, `AGENTS.md` and regression
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

Two games declare one, and they are worth reading as a pair. Dead Metal Jam's
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

Keep these resources in the game's folder. Dead Metal Jam provides an example
with original SVG plates, a condensed variation of Godot's built-in font and
in-engine synthesized menu cues. No external fonts or sound downloads are needed.

All four games declare their own standalone look, selected automatically by
`--game=<id>` or the corresponding standalone export preset:

| Game | Standalone presentation |
| --- | --- |
| Triangle Rush | Mint neon over midnight blue, a rushing-triangle logo, chamfered buttons and panels, triangular toggles, a geometric backdrop and an etched plaque. Keeps the springy arcade menu motion. |
| Desk-Can-Saw | Safety yellow over warm wood and dark steel, a saw-and-can logo, raised workbench controls, mechanical toggles, pegboard and wood-grain scenery, and a timber plaque. Uses firm menu motion. |
| Dead Metal Jam | Amber stage lights over cold steel, textured metal plates, condensed headings and mechanical menu cues. Uses firm menu motion. |
| Chicken Pit | Straw and evening barn light over churned dirt, with a barn-red highlight and a chicken silhouette. Colours only so far — no menu skin or materials yet. Keeps the springy menu motion. |

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

That makes a standalone release **export configuration only**. All four games
already have a preset — *Windows — Triangle Rush / Desk-Can-Saw / Dead Metal Jam
/ Chicken Pit (standalone)* — each pinned by its own feature tag, spelled as the
initials of the game's id (`tr`, `dcs`, `dmj`, `cp`). A preset carries the tag
and drops the other games:

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
collide. Source runs, including the default Desk-Can-Saw launch and `--game`
overrides, keep the existing development user directory. The engine fixes it at
startup, so these runs still share the collection's save files. That is fine for
playtesting, and the reason the override belongs in the preset.

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
| `pit_pull_one_a/b/c` | Remappable; defaults to Q, W and E |
| `pit_pull_two_a/b/c` | Remappable; defaults to I, O and P |
| `ui_accept` / `ui_cancel` | Godot defaults (menu navigation and back) |

Gameplay keys can be changed under **Settings → Controls** — which only exists
while a game is running, because a key binding belongs to a game — and are
saved in `user://settings.cfg`; assigning an occupied key swaps the two
bindings within that game. Two different games may use the same key, since only
one of them is ever running. A game with no `control_bindings` of its own
inherits the built-in set for its `control_style`, which is where Triangle Rush's
six target keys come from. Desk-Can-Saw declares four movement keys (the arrow
keys by default), Dead Metal Jam declares its octave and self-test keys, and
Chicken Pit declares three pull keys per coop.
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
The two score-chase walkthroughs demonstrate Timer rounds regardless of saved
preferences or a game's launch default; Dead Metal Jam's take uses three lives.
Recording overrides never persist to the player's settings.

The sample unlocks **Solo Starter** after the first completed single-player
round and **First Win** after Player 1's first multiplayer victory.
In the collection, Desk-Can-Saw is completely hidden until the player either
scores at least 25 in a solo Triangle Rush round or wins a multiplayer round as Player 1
with at least 25 points (Medium difficulty when the opponent is the CPU). Its
first unlock triggers a dedicated fanfare and visual celebration. The
Desk-Can-Saw's mode selector only shows the matching unlocked route: solo,
local multiplayer, or both after both Triangle Rush conditions have been
completed. A Player 2 win with at least 25 points awards **Race condition** but
does not satisfy Player 1's multiplayer requirement. These flags and
achievements are stored in `user://achievements.cfg` and never regress after
later matches. Both files are written by merging into what is already on disk,
never by rebuilding them: a standalone build registers only its own game's keys
and must not delete another build's saved options or unlocks out of a shared
`user://`.

Focused regression checks can be run headlessly:

```bash
godot --headless --path . --script res://games/desk_can_saw/tests/desk_can_saw_test.gd -- --game=all
godot --headless --path . --script res://games/desk_can_saw/tests/desk_can_saw_scene_test.gd -- --game=all
godot --headless --path . --script res://tests/visual_effects_test.gd -- --game=all
godot --headless --path . --script res://tests/accessibility_test.gd -- --game=all
godot --headless --path . --script res://games/triangle_rush/tests/triangle_rush_options_test.gd -- --game=all
godot --headless --path . --script res://games/chicken_pit/tests/chicken_pit_options_test.gd -- --game=all
godot --headless --path . --script res://games/chicken_pit/tests/chicken_pit_intro_test.gd -- --game=all
godot --headless --path . --script res://tests/share_card_test.gd -- --game=all
godot --headless --path . --script res://tests/instructions_video_test.gd -- --game=all
godot --headless --path . --script res://tests/custom_keys_test.gd -- --game=all
godot --headless --path . --script res://tests/game_shell_test.gd -- --game=all
godot --headless --path . --script res://tests/lives_mode_test.gd -- --game=all
godot --headless --path . --script res://tests/game_options_test.gd -- --game=all
godot --headless --path . --script res://tests/game_select_test.gd -- --game=all
godot --headless --path . --script res://tests/single_game_test.gd -- --game=all
```

Run the suite against the full collection with `--game=all`: several checks
assert values that specific games declare, so they cannot pass in a standalone
run. `custom_keys_test.gd` uses an in-memory manifest to check CPU selection,
rebound action hints and style-specific controller rows without saving settings;
it also supports standalone launches. `single_game_test.gd` passes in both,
so a standalone build can still verify its own path. It exercises each declared
theme on the real title screen: logo tint, widget skin, flat-button text contrast,
plaque materials, backdrop aspect correction and the reduced-motion switch.

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
