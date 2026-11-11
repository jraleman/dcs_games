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
godot --path . -- --game=cube_trials
godot --path . -- --game=dolces_adventure
godot --path . -- --game=sailor_man     # toy-canal voice/Remo duel, not the finished voyage
godot --path . -- --game=capitans_walk  # seeded Park grey box, keyboard/pad/touch; not the finished game
godot --path . -- --game=tifo_beato     # original terrace rhythm career and two-human hot seat
godot --path . -- --game=tuki_tuki      # Venezuelan DDR-style solo practice/story and local battles
godot --path . -- --game=yacomio        # five-era 3D evolution, offline resources, cosmetic store and leaps
godot --path . -- --game=florida_men     # 24-space party board, six 3D minigames, 1-4 humans and CPU guests
godot --path . -- --game=rastro          # 3D car garage; customization only, no competitions yet
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
                                           ├──►  saves          (something saved only)
                                           └──►  credits
```

The title screen offers a single **Play** button. Where it lands depends on
what the build actually has to offer, and the rule is the same one the rest of
the framework follows: never ask a question with one answer. With more than one
game available it opens `scenes/menus/game_select.tscn`, where every game stands
as a cartridge in a long console rack, dressed in its own `GameTheme`. The
cartridge in hand is lifted out of the rack and its label window plays that
game's walkthrough clip; choosing it seats it in the slot, as the title screen
seats its own, before the same setup route. A standalone build — or a
collection in which everything else is still locked — has nothing to pick, so
**Play** selects that game and goes straight on to mode select or instructions.

The title screen uses the slim, translucent rows and restrained typography from
`main-menu.png` and `references.png` at the repository root. The right-hand
showcase is an original 3D console and cartridge, not a background screenshot:
**Play** seats the branded cartridge before handing off to the same router.
Navigation is locked during insertion. Reduced motion uses only a short opacity
fade, including when enabled partway through the animation. The console moves
above the actions in portrait; short screens scroll the action list with focus.
Taglines remain in title tooltips and accessibility descriptions rather than
adding another paragraph. Store and Gallery still appear only for games that
declare them. **Saves** appears in any build as soon as a game it offers has
progress or a backup; see *Saves and backups*.

Menu toggles use compact, translucent tracks and square thumbs rather than the
old bright pills. Thumb position and check/minus marks distinguish On and Off
without relying on colour; disabled states are dimmed and focus stays outlined.
The `MenuToggle` theme role keeps authored Settings rows, game-declared boolean
options and the instructions preference consistent in every build, while its
active indicator follows the game's accent. No new motion or setting changes
are involved.

The picker borrows the title screen's look: the same backdrop, heading, slim
glass buttons and focus bar, with the backdrop's glow, the focus bar and the
details taking on the accent of the cartridge in hand.
Its details strip keeps the one-line tagline and mode chips of that one game,
below the rack or, on a short landscape screen, beside it; the accessible Play
button names the game it starts, and only the cartridge in hand shows a preview
badge. Left and right browse from the cartridge or from Play, so a pad player
never has to leave the button that starts a game; the rack also follows the
arrow buttons, a sideways drag and the mouse wheel, and stops at either end.
Mode select takes the same look through two steps. **Select Mode** offers glass
cards, each with an icon, a one-line description and a player-count chip such as
**1 PLAYER** or **2–3 PLAYERS**, under the game's name as an accent eyebrow.
Setup then lists the **Level**, **Player** and character rows, with any
declared `icon` art beside a title. For a game with a
`character_preview_scene_path` it stands the pick on a lit plinth
(`ui/components/setup_stage.gd`) whose ring wears the seat's colour, beside an
accent **Start** button. Portrait stacks the rows over the plinth and gives the
rows the height they need. On a header too narrow for the game's whole name,
**Details** and **Back** fold down to their icons and keep their words as
accessible names.
Mode setup keeps player identities, choices and controller bindings visible;
**Details** reveals the longer game-authored notes without adding another setup
step or changing any saved options. Both setup steps scroll when needed, and
touch-target scaling applies even to games without character or level choices.
The whole briefing and Details scroll with the setup choices, keeping focus
visible after reflow. Narrow identity/picker pairs stack, and short landscape
windows use the compact heading caps and wrapping Start labels too.

## What's in the box

| Path | What it does |
| --- | --- |
| `scripts/studio_info.gd` | Studio identity: project title, tagline, intro cards, credits, palette. **Start here when renaming the project.** |
| `scripts/game_manifest.gd` | `GameManifest` resource — everything the framework needs to know about one game (scene, copy, achievements, tunables, share art). |
| `scripts/game_catalog.gd` | `GameCatalog` static registry — discovers `games/*/game.gd`, skipping `_`- and `.`-prefixed archive/private folders, and tracks the selected game. |
| `scripts/game_unlock_rule.gd` | `GameUnlockRule` base class for gating a game behind progress in another. |
| `scripts/game_saves.gd` | `GameSaves` static helper — what one game's save holds (its achievements, store wallet and declared `save_files`), and deleting, backing up and restoring it without touching another game or any option. |
| `scripts/game_shell.gd` | `GameShell` base class — the shared round loop, HUD, results/stats panels, pause, sharing and accessibility plumbing every game inherits. |
| `scenes/game/game_shell.tscn` | The matching reusable scene: HUD, results panel, stats panel and an empty `%Playfield` for your game to fill. |
| `autoload/settings.gd` | Stores, persists (`user://settings.cfg`) and applies player settings, including game-declared tunables. |
| `autoload/game_session.gd` | Holds player count, CPU configuration and controller assignment while moving between scenes, and reports gamepad presence via `gamepad_connected()` / `gamepad_availability_changed`. |
| `autoload/audio_manager.gd` | Music crossfades, an 8-voice SFX pool, bus volumes, UI/gameplay sound cues and semantic audio-caption requests. |
| `autoload/achievement_manager.gd` | Persistent achievement registry, per-game unlock progression and queued global achievement toasts. |
| `autoload/store.gd` | Per-game cosmetics store: wallets, purchases, equipped slots and round payouts, persisted to `user://store.cfg`. |
| `autoload/share_manager.gd` | Renders reusable 1200×630 session cards, downloads them on web and saves them for desktop sharing. |
| `autoload/router.gd` | `Router.goto(path)` — scene changes with a fade. Owns the top overlay layer (fade + FPS counter). `start_selected_game()` is the single definition of "begin the selected game", shared by the title screen and the picker. |
| `scenes/menus/game_select.tscn` | The picker the **Play** button opens: a carousel of cartridges in a console rack, one per available game, built from `GameCatalog.available()`, with the chosen one's details and Play beside or below it. Reached only when there is more than one game to choose from. |
| `scenes/menus/store.tscn` | The shop: one card per item a game declares in `store_items`, grouped by heading. Reached from the title screen in a standalone build and from the pause menu in any build. |
| `scenes/menus/gallery.tscn` | The museum: one plinth per entry in `gallery_exhibits`, turned and zoomed on a game-owned stage scene. Reached from the same two places as the store. |
| `scenes/menus/saves.tscn` | The save manager behind the title screen's **Saves** button: a card per game with progress or a backup — every such game in a collection, only its own in a standalone build — with Back up, Delete save and each backup's Restore and Delete. |
| `ui/menu_screen.gd` | `MenuScreen` base class: UI sounds, focus handling, `ui_cancel` to go back, responsive margins. |
| `ui/responsive.gd` | Helpers for margins, portrait detection and content width. |
| `ui/theme/dcs_theme.tres` | Base buttons, panels, sliders and tabs. A standalone `GameTheme` can recolour it and merge a game-owned partial skin. |
| `ui/components/background.tscn` | Animated gradient backdrop (shader), aspect-corrected and tinted by the current `GameTheme`. |
| `ui/components/cartridge_console.gd` | Original menu console, cartridge shell and controller meshes. Exposes insertion progress and a stationary reduced-motion pose; the title screen owns navigation. |
| `ui/components/achievement_toast.tscn` | Small reusable unlock notification used by `AchievementManager`. |
| `ui/components/audio_caption.tscn` | Reusable gameplay caption panel for important sound-only events. |
| `ui/components/game_card.tscn` | One game on the picker, drawn as a cartridge in that game's `GameTheme`: logo, plaque label, mode chips and a label window that shows the poster and plays the looping, muted walkthrough clip only while it is the cartridge in hand. A view only — it reads no autoload. |
| `ui/components/cartridge_shelf.gd` | The console rack the picker's cartridges stand in, drawn as a layer behind and a layer in front of them: slots lit in each game's accent, an LED pager, and a power light the seating animation switches on. Either end can run off screen. |
| `ui/components/store_item_card.gd` | One cosmetic on the shop shelf: preview, price, lock reason and a button per slot it can be worn in. A view only — it reads no autoload and moves no money. |
| `ui/components/player_avatar.gd` | Drawn placeholder for per-player portrait art; set `portrait` to swap in a real texture. |
| `ui/components/setup_stage.gd` | The lit plinth mode select stands a game's character preview on: drawn floor, turntable and a ring in the seat's colour, plus a caption naming the pick. It places the preview itself and reads no autoload. |
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
| `games/cube_trials/` | Cube Trials: selectable Cube, Sonata and CR-V models over deterministic side-view suspension physics; solo or two/three-player hot seat, five plugs, four checkpoints, crash-only lives and keyboard/gamepad/multitouch controls. |
| `games/dolces_adventure/` | Dolce's Adventure: Dolce's side-scrolling run, five timed stages, procedural models, Treats store and gallery. The pre-release rename uses only the new identifiers; older development saves are not migrated. |
| `games/sailor_man/` | Sailor Man prototype: five free toy-canal skiff-practice arenas, seeded Culebra self-echo or two-human hot seat, weighted judges, per-seat voice profiles, track-driven world ribbons, opt-in microphone, keyboard/gamepad/multitouch Remo, frozen share cards, eleven free gallery exhibits, actual P1/P2 setup launch previews and earned-Balboas toy cosmetics; real voices and the finished voyage remain pending. |
| `games/tifo_beato/` | Tifo Beato: terrace rhythm career and hot seat, Away days, Derby week, curated Chant Creator, local-midnight Daily Derby and read-only Best Moments; optional microphone/Buttons, original Compatibility toys/audio, store/gallery/frozen shares and tutorial. Hardware and owner review remain pending. |
| `games/tuki-tuki_agents/` | Tuki Tuki: native DDR-style rhythm play, five synthesized songs, four champions, story/culture pages and simultaneous two-human battles; the catalog ID is `tuki_tuki`. |
| `games/yacomio/` | YaComio!: solo, five-era 3D evolution with 24 upgrades, offline resources, milestone events, cosmetic store, free gallery, player-paced intro, journal and optional prestige. |
| `games/florida_men/` | Florida Men: a 24-space party board and six original procedural 3D minigames; 1-4 local humans, CPU-filled seats, cosmetic hats, free gallery, frozen shares and a recorded complete-party tutorial. |
| `games/rastro/` | Rastro: untimed solo 3D garage with all three original car types available, free paint/wheels/tires/suspension/engine customization, per-car saves and validated portable JSON builds. Competitions, driving and Cube Trials loading are future work. Keyboard, gamepad and touch inspection; Windows/Web/Android/iOS presets use the `rastro` feature and a stable separate save directory. |
| `games/capitans_walk/` | Capitan's Walk grey box: solo, node-free 120 Hz walker/dog/leash physics, sixteen seeded Park templates with puddles/slopes, telegraphed sprinkler/jogger/flock/friendly-dog encounters, safe rings, physical play/greeting sniffs, happiness and banked rhythm points; rebindable keyboard, fixed analogue gamepad, independent multitouch with three handed layouts, classic/Easy legs, four live assists, instant restart and an original keyboard walkthrough. Automated events reach identical shared results through all three adapters; a real motor walk reaches a generated jogger at 52.09 m. Physical hardware and the three-person playtest remain unverified. Pickups, surprise events/bosses, final 3D art and progression remain later work. |
| `tools/tutorial_capture.tscn` | Development-only recorder: plays a real round with a scripted demo player and captioned steps for the instructions video. |
| `tools/record_tutorials.ps1`, `tools/record_tutorials.sh` | Records each game's tutorial clip through Godot's Movie Maker and encodes it to that game's own `games/<id>/assets/video/tutorial.ogv` plus a poster frame. |
| `tools/measure_intro_cues.py` | Development-only: finds the pauses in a narration recording and prints the `cue_times` array a card-based intro needs. |
| `tools/capture_screens.ps1`, `tools/capture_screens.sh` | Development-only: saves a PNG of every screen each game reaches, standalone and in the collection, for review. Runs `tools/capture_screens.gd`, which loads the walk itself from `tools/capture_screens_tour.gd`. |

## Cross-platform tools

Every PowerShell (`.ps1`) script has a same-named Bash (`.sh`) counterpart,
including game-owned tools. Use PowerShell on Windows or Bash on Linux/macOS;
the Bash entry points work with macOS's Bash 3.2 and require **Python 3.10+**.
Set `PYTHON` to choose its interpreter. Scripts resolve their project paths
from their own location, not the current working directory, and accept quoted
executable/output paths containing spaces. Run a Bash script with `--help` for
its options; lists accept comma-separated or space-separated values.
If Godot is not on macOS's PATH, pass its app-bundle executable with `--godot`,
for example `/Applications/Godot.app/Contents/MacOS/Godot`.

From `godot-base/`:

```bash
bash tools/record_tutorials.sh --godot godot --games anti_chess --variants local
bash tools/capture_screens.sh --godot godot --games chicken_pit,cube_trials --skip-collection
bash games/tifo_beato/tools/validate.sh --godot godot --suites sound,model,scene
bash games/lazer_nfc/tools/bake_voice.sh --destination /tmp/lazer-voice-preview
python3 tools/tests/shell_scripts_test.py
```

Recording needs ffmpeg with Theora/WebP encoders; screenshots and recordings
need a real graphics window. The Unix voice baker additionally needs offline
**eSpeak NG** and ffmpeg. It produces a different synthesized voice from the
Windows Microsoft Zira bank; the example writes a separate preview bank, not
the shipped audio. Its `--check` compares against a bank baked with the same
voice/engine version. See LaZer NFC's README for voice authoring options.

Bash capture/recording/validation launches give their tool children a private
`HOME`, `XDG_DATA_HOME` and `APPDATA`, covering macOS and Linux save locations
without changing the caller's environment. Validation keeps its logs; media
tools remove their private intermediate/profile directories even on failure.
The tool regression tests use fake executables and temporary projects, so they
need neither Godot nor speech/audio tools and never replace shipped assets.

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
  label-window clip on its poster frame, stops its rack sliding and bobbing,
  and swaps its cartridge seating for the same opacity-only fade.
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
  Target and Pause buttons swap only when both resulting assignments are legal;
  a swap that would move Pause onto the D-pad is refused without changing either
  binding. Paused screens give GUI confirmation priority, so A still operates
  focused menu buttons even when it is also assigned to Pause.
- **`MenuScreen.refresh_layout()`** recomputes margins from the live viewport
  on every resize and calls `_on_layout_changed(size)`, which screens override.
  The main menu uses it to switch between a left-aligned poster layout in
  landscape and a centred console-above-actions stack in portrait. Its action
  list follows keyboard/gamepad focus when a short viewport needs scrolling.
- Long content (the settings tabs, the credits roll) lives in `ScrollContainer`s,
  so nothing is ever unreachable on a small screen.
- The background shader is driven by `UV` and gets the current aspect ratio from
  `ui/components/background.gd`, so its glows stay round on any window shape.

Anchored controls are animated with `modulate` and `scale` (with a centred
pivot), never `position` — moving an anchored control bakes its offsets in and
breaks the layout on the next resize.

### Screenshots for review

`tools/capture_screens.ps1` or `tools/capture_screens.sh` saves a PNG of every
screen a player can reach, so
a layout change can be reviewed in one folder instead of by clicking through
every game:

```powershell
pwsh tools\capture_screens.ps1 -Godot C:\path\to\godot.exe
pwsh tools\capture_screens.ps1 -Godot godot -Games chicken_pit, cube_trials -SkipCollection
```

On Linux/macOS:

```bash
bash tools/capture_screens.sh --godot godot
bash tools/capture_screens.sh --games chicken_pit,cube_trials --skip-collection --resolution 1280x720
```

It runs `res://tools/capture_screens.gd` once per game as a standalone build
(`--game=<id>`), then once as the collection (`--game=all`), each in a real
1280x720 window (`-Resolution` changes it). A run walks the screens in the
order a player meets them: the studio sting and opening, the title screen,
every settings tab, the store, each gallery exhibit, the saves screen and its
confirmations, and the credits. A standalone run then plays every mode the
game offers (solo, then local two-player): setup, briefing, the round, the
pause overlay, results, the stats panel and the share card. The collection run
keeps the shared screens plus one picker frame per cartridge. Lists longer
than the window are kept a page at a time, and one that opens scrolled down is
also kept from its top, as `_p1`; `-NoScrollPages` keeps one frame per screen.

Output goes to the gitignored `build/screenshots/<timestamp>/`, or
`-OutputDir`: one folder per run of `NNN_<screen>.png` in the order visited, a
`screens.txt` naming each file's scene followed by the run's notes and
warnings, and each run's Godot log under `logs/`. The wrapper exits 1 when a
run fails, or is stopped after `-TimeoutSeconds`.

Every run starts from a fresh, throwaway profile in which every achievement
and unlock rule is met and every shop can afford its whole catalogue, so gated
levels, characters, exhibits and items are on screen. A game's own
`save_files` stay fresh, so its first-run screens are kept too, unless its hook
seeds them (below). Real saves are never read or written: the tour refuses to
seed a profile the wrapper did not make. A round is ended the way its timer
would end it, with fixed scores, so results match from run to run;
`screens.txt` labels those frames `tour-set scores`. Keep the window visible
while it runs.

Progress only one game records, and screens only it knows how to reach, such
as a lobby's sub-pages or a mid-round event, come from an optional
`games/<folder>/tools/screen_tour.gd`, discovered by convention like the
tutorial drivers, so the shared tour never branches on a game id. Only a
standalone run loads it. Every method is optional and may be a coroutine:
`seed_profile() -> String` writes the game's own progress into the throwaway
profile before the opening, and a returned line is added to the notes;
`screens(mode) -> Array` lists screen ids, or dictionaries with `id`, `phase`
(`lobby`, `round` or `results`) and `settle` seconds; `enter(scene, id) -> bool`
shows one on the running game scene, and false skips it; `leave(scene, id)` puts
the game back. Tifo Beato's hook seeds a finished career, so its later grounds,
lobby rivals and every gallery exhibit are open.

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
the short caption, descriptive tooltips and direct inspection gestures all
follow. See *A gallery of your own*.

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
   - `max_local_players` — defaults to 2; set 3 or 4 to offer additional local humans.
     Capacity is bounded by the shared blue/red/green player palette. CPU
     sessions remain two-seat and mobile remains solo. `GameSession.player_count()`
     reports the active count; `configure_multiplayer(controller, difficulty, players)`
     accepts the new optional count without changing existing two-argument calls.
   - `local_multiplayer_turns` — marks a hot-seat game, using one shared set of
     driving/action keys and an ordered roster in setup and instructions. The
     game owns turn scheduling and calls the shell's `_end_round()` only after
     all turns; this flag does not create split-screen or run multiple scenes.
   - `characters` — an optional `Array[Dictionary]` of stable `id`, `title` and
     `description` entries. Each human gets a character picker in solo or local
     setup, including solo-only platforms. `GameSession.character_for_player(index)`
     returns a defensive copy; `set_character_for_player(index, id)` validates
     the seat, roster ID and optional `requires_achievement` gate. Locked choices
     stay listed with `locked_description` help; defaults only use unlocked entries.
     Choices are session-local, independent and may
     repeat. Optional `character_preview_scene_path` creates a game-owned
     `Control` with `configure(Dictionary)`; the entry includes `player_index`,
     `multiplayer` and `player_color` alongside the character data. The setup
     screen stands it on its plinth. The rect it is given is twice the
     plinth's radius wide, at a 1.7:1 aspect, and its bottom edge lies 0.2 of
     that radius in front of the plinth's centre. Frame the subject to stand on
     that edge with a little floor margin. The screen sets previews to ignore
     the mouse.
   - `levels` — optional `Array[Dictionary]` entries with `id`, `title`,
     `description`, and the same optional achievement gate as characters.
     Setup offers one shared level in solo or multiplayer.
     `GameSession.selected_level()` returns a defensive copy and
     `set_level(id)` rejects locked or unknown IDs. The choice is session-local;
     achievements persist unlocks. Games still own terrain and completion rules.
     Levels and characters may each add an optional `icon`, a texture path the
     setup row and its list show beside the title. A level still or a
     character badge suits it. A missing file warns and leaves a text row. The
     `copy` keys `level_label` and `character_label` rename the rows'
     headings, for example to "Car"; `mode_select_title` renames the first
     step.
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
   - `save_files` — progress the game keeps in `user://` files of its own, so
     the Saves screen backs it up, restores it and deletes it with the rest of
     the save. Achievements and the store wallet are covered already. See
     *Saves and backups*.
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
and the picker behind it builds one cartridge from `GameCatalog.available()`, in
`menu_order`, so a new game appears as soon as its manifest does — and
disappears again behind an `unlock_rule` until earned. The cartridge wears the
game's `GameTheme` — logo, accent and plaque label — and its label window plays
the same `tutorial_video_path` clip the instructions screen uses while it is the
cartridge in hand, falling back to `tutorial_poster_path` and then to a labelled
placeholder, so a game with no recording yet still gets a cartridge of the right
shape. Only the cartridge in hand ever decodes its clip.

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
build's purchases. Missing files are created; any other merge-read error aborts
the write with a warning and leaves the existing file untouched. Ownership never
regresses, and an equipped id the build does not recognise falls back to the
slot's `default` rather than being dropped.

The **Store** button appears wherever the shop has a game to serve: on the title
screen of a standalone build, and on the pause overlay of any build while a
round with a store is running. Both hide themselves otherwise, so declaring no
store costs nothing. `tests/store_test.gd` walks `GameCatalog.all()`, so your
shop is covered the moment the manifest declares it.

### A gallery of your own

The gallery gives the models a game is made of room to breathe: a grouped
exhibit list on the left, a large transparent turntable on the right and just
the selected exhibit's title beneath it. Portrait layouts put the model first
and a scrollable exhibit drawer below. There is no on-screen manipulation
toolbar or persistent instruction paragraph. Full descriptions and facts live
in the exhibit tooltips and accessibility text; the selected title also offers
input help on hover, without covering a model as the player inspects it.

Like the store it is pure data, and unlike the store it has **no autoload**: a
shop has a wallet to protect, a museum has an opening time and a door. Two
manifest fields turn it on, and both are required:

- **`gallery_exhibits`** — what is on the plinths, in order. Each entry needs an
  `id` (unique within the game) and a `title`. Add `description` and `facts` (an
  array of short specification lines) for the tooltips and accessibility text,
  `heading` to group consecutive entries, `badge` for the text-only fallback,
  optional game-owned rendering metadata such as `color`, and
  `requires_achievement` to leave an exhibit **listed but not viewable** until
  it is earned — a collection reads as something to
  finish rather than something the game is hiding. For progress the game owns
  outside achievements, `available` defaults to true; explicit `false` leaves
  the entry locked even with no achievement id or reason. `locked_description`
  explains the gate, with a generic fallback when absent. Availability and
  achievement gates both apply; true does not bypass an unmet achievement.
- **`gallery_stage_scene_path`** — the `Control` scene that actually draws a
  model. This is the one piece a game writes itself, because only the game knows
  what its models are.

The stage contract mirrors `share_art_scene_path` and `store_preview_scene_path`:

| Method | Required | Meaning |
| --- | --- | --- |
| `configure(exhibit: Dictionary)` | expected | Put this exhibit on the plinth. A stage without it is a mistake the screen survives rather than a crash: `gallery.gd` warns once and falls back to the exhibit's badge. |
| `set_view(yaw: float, pitch: float, zoom: float)` | no | Yaw and pitch are **offsets in radians from the exhibit's own default framing**; `zoom` is a magnification where `1.0` is that framing. Without it the screen does not advertise or accept orbit/zoom gestures. |
| `set_auto_spin(enabled: bool)` | no | The screen has already checked reduced motion before calling. |

Positive yaw walks the camera anticlockwise around the model, matching a drag
to the right. Positive pitch raises the camera. The shared screen advances yaw
for automatic rotation; `set_auto_spin` also notifies stages that have their
own ambient motion. A stage without either motion method has no inspection
focus stop or dead gesture hints.

All inspection actions are available directly with the mouse: **drag** to
rotate, **scroll** to zoom, **double-click** to reset and **right-click** to
pause/resume auto-spin. Touch supports drag, pinch, double-tap reset and a
two-finger tap for auto-spin. With the viewer focused, keyboard users have
W/A/S/D, +/-, R (or Home) and Space; controller users have the right stick,
shoulders, Y and X respectively. Arrows, d-pad and Tab retain ordinary menu
navigation, and leaving the viewer or window clears held inspection input.

Reduced motion parks the turntable and prevents auto-spin from being re-enabled
until that setting is turned off. The title's tooltip and the viewer's
accessibility description explain this; manual inspection still works.

`games/chicken_pit/ui/gallery_stage.gd` is the worked example: a request-driven
`SubViewport` turntable that builds every exhibit from the same `ChickenRig` and
`Scenery` calls a match uses — including the hats the player bought in the store
— and frames each one automatically from its bounding cylinder, so a new exhibit
needs no hand-measured camera distance.

The **Gallery** button follows the store's rule exactly: the title screen of a
standalone build, and the pause overlay of any build while a round with a
gallery is running. `tests/gallery_test.gd` walks `GameCatalog.all()` and covers
declarations, optional stage methods, direct input, responsive asset space,
focus scrolling, reduced motion, unlocks and both menu entry points.

### Saves and backups

The title screen's **Saves** button opens `scenes/menus/saves.tscn`, where a
player backs up, restores or deletes one game's progress without touching any
other. Most games declare nothing for it: a game's save is its share of the
achievements and store wallet the framework already keeps for it.

- **What a save holds.** The game's unlocked achievements; its store points,
  purchases and worn items; and the files it lists in `save_files`. Options are
  never part of a save — `settings.cfg` keeps every game's tunables and key
  bindings beside the player's display and accessibility choices, and deleting
  progress is not a request to lose those. Unlock progress toward a *gated*
  game is left out too: it records play in another game, and an unlock must
  never regress.
- **`save_files`** — progress a game keeps in files of its own, each as
  `{ "path": "user://…", "title": …, "description": … }`. Every entry is named
  on the card, copied into a backup, put back on restore and deleted with the
  rest of the save, so list progress only: a calibration, a cache or a log is
  not something a player expects **Delete save** to take. A path must be a plain
  file under `user://`; the three shared files, folders and the backups folder
  are refused with a single warning. Chicken Pit declares its match history and
  LaZer NFC its tag labels. Dead Metal Jam's microphone calibration is left out
  on purpose.
- **Which games are listed** — `GameSaves.managed_games()`: every
  `GameCatalog.available()` game with progress on this device or a backup to
  return to, in `menu_order`. A collection (`--game=all`) lists every game with
  something saved and a standalone build only its own; neither the screen nor
  the menu asks which kind of build it is. The button hides itself when that
  list is empty. Unlike Store and Gallery it appears in a collection too,
  because one screen manages every game, and it is not on the pause overlay, so
  a restore can never change a save under a running round.
- **Backups** are one `ConfigFile` per snapshot in
  `user://save_backups/<game_id>/`, holding only that game's data, listed
  newest first by the time they were made. **Back up** is the only action that
  cannot lose progress, so it is the only one that does not ask first.
  **Delete save**, **Restore** and deleting a backup each confirm, with focus on
  **Cancel** and Escape closing the question rather than the screen. A restore
  replaces every part the backup captured — an achievement unlocked since is
  locked again, a file created since is removed — stages the game's own files
  beside their targets so a full disk leaves the current save as it was, and
  never writes a file the game no longer declares. Deleting a save keeps its
  backups. A backup from a newer build or another game, or a damaged one, stays
  listed with the reason, so it can still be deleted.
- **Open save folder** reveals `user://` in the desktop file manager; web and
  mobile builds hide it.

`AchievementManager` and `Store` each provide the four calls `GameSaves`
(`scripts/game_saves.gd`) composes — `save_summary`, `export_save`, `erase_save`
and `import_save`, all taking the game id. Like every other save they merge into
the stored file, so a restore in one build never deletes another build's keys,
and a restored achievement raises no toast: it puts old progress back rather
than earning anything. `tests/saves_test.gd` walks `GameCatalog.all()`, so a
new declaration is validated as soon as it exists.

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

### Cube Trials - the very unreasonable commute

`godot --path . -- --game=cube_trials` launches **Cube Trials**, an original
**2.5D** physics-driving game inspired by elastic-suspension trials games:
a real 3D environment and car, with the original side-view controls and rules.
Start with the **Nissan Cube** on **Level 1 - Copper Creek**. Completing it
unlocks **Level 2 - Sunset Ridge** and the **Hyundai Sonata**; completing Level 2
unlocks **Level 3 - Alpine Pass** and the **Honda CR-V**. Choose an unlocked
level and car in the shared setup screen. All three original, unbranded Blender models are
playable, with their own proportions, five damage stages, working lights and
real cabins. Engine power, grip, jump and suspension tuning are shared;
`vehicle_profiles.gd` supplies each car's physical dimensions and contacts.
The long, low sedan needs a hop over sharp crests. The three handcrafted
courses have distinct terrain, signs, pickups, checkpoints and garages:
Copper Creek has six gaps, Sunset Ridge four and Alpine Pass seven.
All use the unchanged Compatibility renderer. No Elasto Mania levels,
code, artwork or audio are included, and the models imply no manufacturer
affiliation or endorsement.

Play solo or select **two or three local humans**. Hot seat runs **P1 -> P2 -> P3**,
not simultaneous driving: blue, red and green paint identify the current
driver. Each player chooses a car and gets a complete, independent five-life
run. Release-gated handoffs freeze the clock, finishers rank by adjusted time,
and final standings include everyone. The garage pays once after all turns,
using the best score. Any finisher earns the selected level's completion unlock
after the final turn; abandoning a match grants no progression.
Replay restarts the whole roster on the same level, and **Levels & cars** on
results returns to setup. Solo retains factory
or purchased paint; wheel finishes work in both modes. Gallery still shows
the pristine cars once earned, and each preview/share portrait uses the actual selected model.

Collect all **five numbered spark plugs**, then brake inside the garage.
Checkpoints only activate when all earlier plugs are collected, so
a recovery cannot strand a missing pickup across the quarry. Roof strikes and
falls spend one of five lives and recover automatically while lives remain;
manual recovery costs time but not a life. Pickups survive recovery, which
adds **five seconds**. The fifth crash ends that driver's run. The clock starts
on the first drive, tilt or jump input and pauses with the shared shell.
There is no time limit; the trial owns its crash-only lives rather than using
the generic arcade pool (`uses_shell_round_rules = false`).

| Input | Action |
| --- | --- |
| W / S | Throttle / reverse |
| A / D | Tilt nose up / down |
| Space | Jump; release before the next hop |
| Shift | Brake |
| R | Recover to the last checkpoint (+5 seconds) |
| Escape | Shared pause menu |
| C / camera icon / gamepad R3 | Cycle Side, Chase and actual-cabin Cockpit |
| Gamepad RT / LT, left stick, A, B, Y, Start | Throttle / reverse, tilt, jump, brake, recover, pause |
| On-screen pedals, tilt and jump buttons | Mouse or independent simultaneous touch contacts |

Hot-seat drivers share these rebound keys. A seat uses its assigned controller
when available, otherwise the first pad can be passed between players.

Keyboard bindings are generated from `cube_trials_options.gd` and can be rebound.
Its **Game** tab exposes live air-control strength, engine sound and day/night toggles.
Reduced motion parks clouds, water ripples, pickup/flag motion and dust, and
removes camera smoothing; driving, wheel rotation, suspension travel and
necessary camera tracking remain. The shallow-angle camera also keeps the
quarry landing visible. Intense effects independently suppress tire dust.
Meaningful sounds also have visible feedback and audio captions.

Gold is an adjusted time of **65 seconds or less**, Silver is **95 or less**,
and any other finish earns Bronze. Each plug scores 1,000 points; finishing
adds `max(0, 3000 - ceil(adjusted_seconds * 30))`, plus banked flip points.
Five persistent achievements reward the three level deliveries, a no-recovery
run and Gold. Assists do not block achievements. Existing Copper Creek completion
saves already open Level 2 and the Sonata, but not Level 3 or the CR-V.
Replay starts fresh runs with the same selected level and cars; settings, achievements
and garage purchases persist between app sessions.

`course.gd` is the single source of all three routes, pickups, checkpoints and unlock milestones.
`trial_state.gd` integrates suspension, traction, collision impulses and tilt
at 120 Hz independently of render FPS, unchanged by the 3D upgrade.
`course_view.gd` owns an isolated `SubViewport`, three camera modes and
clipped texture without moving the shared HUD. `world/copper_creek.gd`
extrudes the exact collision profile, including the open quarry gap;
`world/cube_model.gd` poses the chassis and both complete axles from that state.
`world/mesh_builder.gd` batches original geometry into lit surfaces, and
`cube_art.gd` supplies their palette and daylight. No other game's models or
helpers are imported. The 3D view uses 4x MSAA and caps its render target to
1920x1600 while matching the window's physical pixel density.

The share card uses the same car in its own 3D studio viewport. Its icon,
picker poster and the setup screen's level stills are captures of these actual
meshes and routes, not a second interpretation of the car. Regenerate them with
a real graphics window, from `godot-base` (append `--only=levels` for just the
level stills):

```powershell
godot --path . --script res://games/cube_trials/tools/capture_art.gd -- --game=cube_trials
```

The capture tool is development-only and excluded from exports. The game owns
its meshes, synthesized engine/cues, intro, poster, credits and share art.
Its manifest supplies all registration; no framework game-name branch is needed.

The **Windows - Cube Trials (standalone)** export uses the `cube_trials` feature
tag and stable `DeskCanSaw Games/Cube Trials` save directory. The collection
includes it automatically; existing standalone presets exclude it. As with other
source launches, `--game=cube_trials` selects the catalog, not a separate save
profile.

## Dolce's Adventure

`games/dolces_adventure/` is an original solo side-scrolling platformer for
Dolce, a small chihuahua mix: run, variable-height jump, stomp pests and eat
burgers across five biomes. Endless runs use seeded authored chunks; five
fixed stages end at food trucks and unlock in sequence. Distance is relative
to the chosen start; stage clear times use model time. Assists do not block
achievements.

A node-free 120 Hz model drives procedural 3D meshes in an isolated viewport
under `GameShell`. The game owns its Treats cosmetics, outfit portraits,
gallery, intro, synthesized cues/captions and real Stage 1 walkthrough. Touch
supports independent fingers, genuine double-tap sprint and persistent
one-time Auto-run onboarding. Keyboard actions are rebindable; arrows and
gamepad controls are fixed extras approved for v1.

Launch with `--game=dolces_adventure`, adding `--dolce-seed=42` to replay an
endless course. The **Windows - Dolce's Adventure (standalone)** export
carries `dolces_adventure`, version `1.0.0`, and the approved permanent
`DeskCanSaw Games/Dolce's Adventure` user directory. Its external EXE/PCK
pair lives in `build\dolces_adventure`; other games, tests and development
tools are excluded. The collection includes Dolce; all other standalone
presets exclude it. Source game selection still shares the host development
save profile.

Read the game's `AGENTS.md`, `DESIGN.md`, `TODO.md` and `README.md` for
controls, isolated tests, records and art capture. Its thirteen suites cover
model rules, fairness, progression, gestures, real gameplay and rendered
layouts; `dolce_view_test.gd` requires a graphics window. Human/device
playtests are separate from those automated checks.
Godot 4.7.2 builds of both presets passed exact-PCK headless/rendered checks
and native Windows boots. The unsigned standalone distribution is
`build\dolces_adventure\DolcesAdventure-v1.0.0-windows-x86_64.zip`.
Its feature-specific version also reaches the shared title footer through
`StudioInfo.version()`; the collection's version remains unchanged.

## Sailor Man - toy-canal practice duel

`games/sailor_man/` supplies a playable best-of-three prototype duel and a
node-free scorer for Aliento, Quiebre, Altura, Remate and answer-only Eco,
a continuous 100 Hz microphone pipeline, and an opt-in workbench inside
`GameShell`. Launch with `--game=sailor_man`: **Start duel** faces one
explicitly synthetic practice skiff, with weighted judges, numbered paddles,
alternating calls and an answerer-wins-ties rule. **Practice arena** in the
shared setup freely selects Gatún, Lago Gatún, Corte Culebra, Pedro Miguel or
Miraflores & the Pacific; no voyage gates or progress are implemented. Win two
tandas, then enter shell results and replay in the same arena. Lock clocks pause
inside performances; Ready and a 250 ms cue/tail guard gate player input.

Shared **Multiplayer** setup offers two-human hot seat in all five practice
arenas, with no chamber timeout, including locks. P1 calls tanda one; P2 answers
and leads tanda two. Named/coloured P1/P2 pass cards select each singer's
profile/source independently for the session, including rematches, without
changing the saved source default. Neither selection opens hardware; every
completed turn/Repeat stops capture and the next mic turn needs explicit Enable.
Soundcheck Save/use applies only to that seat, without reparenting/restarting
checked capture. Both actual scores/winners reach shell results. Rest counts
are per singer; free Repeat uses only the completed caller's contour/profile
as a neutral tone, not recorded voice. Listening deadlines and judge/tie/decider
rules are unchanged. Water stays at its initial height in human lock matches.
Full Practice and self-echo remain solo entries; mobile remains solo.

Standalone boot shows three player-paced practice cards using the actual
static lock and launches, with **Next**/**Done**, always-available **Skip**,
Escape and controller navigation. Done/Skip lead to the normal title, not a
match. No narration, microphone activation, profile/performance reads,
campaign story or new save is introduced; collection boot keeps the framework
intro. The shared written **Guide** now explains Aliento, Quiebre, Altura,
Remate (including grito) and answer-only Eco as game simplifications, retaining
actual mode rules and rebound keys. Comfort, Quiet Mode, no extra-volume
reward and provisional unmeasured microphone bands stay explicit.

One **Practice launch** setup entry displays each human's actual launch and
plain toy crew on the shared plinth. Focusing P1/P2 changes canonical paint,
plaque and identity ring, not scoring or voice. The isolated transparent
Compatibility view is static, renders only the featured seat, reads no
profile/performance data and writes no saves. Equipped cosmetic ids come from Store;
this is not the production captain roster.
Compact arena summaries stay mode-neutral; Details explains the solo clocks
versus untimed hot seat.

The shared **Store** offers twelve original toy cosmetics: four free defaults
and eight paid hats/pennants/lower-hull finishes/bow ornaments. Eight stable
`p1_`/`p2_` slots keep human equipment independent, while ownership and the
per-game Balboas wallet are shared in `user://store.cfg`. Buy once to equip
either/both singers; auto-equip chooses the first matching still-default slot.
Normally completed duels pay `round(best human's accumulated judge points / 10)`;
hot seat uses the higher human total, not their sum or rival points. Ordinary
solo synthetic-skiff wins add five; echo/hot seat have no win bonus. Losses
still earn conversion; workbench, seeds, unfinished/abandoned duels and timeouts
pay nothing. Results bank once and display the payout. Existing minimum
one-point valid paddles mean a completed silent three-judge loss can earn one
Balboa. The actual play/setup/gallery rigs wear human outfits; the skiff/echo
remains plain and finished share cards freeze cosmetic ids. No traditional
dress/pattern, cultural gate, new save file or framework game-name branch is added.

Original batched launches, gates, rail-mounted mulas, tropical banks and plain
crew/crowd replace the primitive lock. Both boats stay framed as the camera
eases toward the singer; an admitted, profile-relative contour unrolls over
the water without rewarding amplitude or bridging silence. Review diamonds
use existing scorer evidence. Reduced motion parks framing/bobbing/waves, not
water or pitch; effects-off omits diamonds, and hidden views stop rendering.
Gatún rises and Pedro Miguel descends with the four-minute chamber clock.
Lake, Cut and Pacific practice are untimed between turns, including their free
once-only Repeat; the listening deadlines remain bounded. Pacific uses five
actual judges, HUD paddles and 50-point turn maxima. The other locations add
jungle islands/howlers/ships, red-earth terraces/cable bridge and an arched
bridge/skyline/causeway/festival boats. Their setup icons come from these same
meshes via the game-owned `tools/capture_art.gd`. Real place names are
owner-approved without authority branding; these are toy interpretations,
not factual/cultural reconstructions.

Culebra's ready card also offers **Challenge your echo**, separate from skiff
practice. A fresh unscored seed uses the same guarded input window; its copied
frames, source profile and Quiet Mode become a fixed opponent in best-of-three.
Every echo/repeat waits 600 ms before returning as a contour and softer neutral
synthetic tone, never recorded/live mic audio. Pause restarts the delay and
same take; ECHO labels identify it on the boat/paddles/results. Replay requires
a fresh seed and opens no microphone. No seed tracks or mode choice persist,
no seed points inflate results, and no voyage encounter/progression is implied.

The shell's **See Scores** previews a frozen 1200x630 share card; explicit
**Save Image** writes/downloads the same PNG. Hot seat features both humans'
original blue/red launches, P1/P2 labels and each singer's highest accepted
normalized-turn contour with actual paddles; ties keep the first. Solo/echo
feature only P1, not the synthetic rival or seed. Judge/tanda points, best scores,
total Quiebres and longest Aliento are truthful; silence, no completed turn,
incomplete duels and development scorer sessions stay distinct. Art is static
and hidden views stop rendering. Only transient geometry/scalar captions enter
artwork, with frozen cosmetic ids; no PCM, pitch-frame/profile files or PNG text/EXIF
metadata are exported.
The QR opens the studio homepage under **Discover more games**, explicitly
without a public run record. Campaign/captain artwork and publishing are not
implemented.

The standalone title/pause **Gallery** displays eleven free current exhibits:
P1's launch, synthetic skiff, human pair, mula, gate, howler and five practice
dioramas. These reuse the actual match builders, not recorded/culturally
reviewed crews or campaign-gated assets. The shared viewer owns mouse/touch/
keyboard/controller orbit, zoom, reset and auto-spin through `set_view`.
The static isolated Compatibility stage needs only `configure` and `set_view`;
it has no independent spin loop or redundant `set_auto_spin`. Reduced motion
parks auto-spin, hidden stages stop rendering, and no voice/profile/performance
data, audio players or persistence enter the gallery. Recorded rivals, dredge/
whole-canal exhibits and achievement gates remain future campaign work.

Original game-owned horn, water, applause, paddle and mula effects use SFX.
Judge feedback is limited to Remo between turns; filling water and mula bells
belong to locks only. Selecting Microphone
already silences it before Enable. Reference/repeat, guard, listening,
Soundcheck, Practice and pause have no canal effects; completion stops capture
before its final cues. Title music is stopped. Combined sound captions reuse
the shell widget in the visible duel layout, even with muted SFX; the persistent
YA header leaves the compact listening ribbon clear. Cruise music, production
voices and physical acoustic-tail validation remain open.

Remo needs no microphone: choose **Ready**, wait for **YA!**, hold Space,
glide with W/S or arrows, press J
for Quiebre and K for Remate. Gamepad and independent multitouch also feed
the same 100 Hz frames/scorer. The keys are rebindable, the ribbon keeps a
reference for Eco, and an explicitly synthetic tone previews pitch. Solo's **Practice**
keeps the original full scorer and its reference/examples workflow. Starting
Remo disconnects capture; unfinished turns are discarded on pause, focus loss
or source change without losing the previous reference.

The game-owned pre-duel **Soundcheck** measures Room/Speak/Low/High/Call and
saves named scalar profiles in `user://sailor_man_voice.cfg`, never PCM or
tracks. It is calibration, not a `save_files` entry. Only explicit Enable
opens hardware; opening setup or selecting a saved profile does not. Back,
pause/focus loss and failure preserve the earlier file and pending answer.
Auto/Microphone/Remo is the saved default; human card choices are session-local.
Auto prefers an available calibrated device, otherwise Remo, and also falls
back on capture failure. Narrow active
layouts prioritize the ribbon and independent touch controls over the canal view.

Missing/unanalyzable audio does not count as a zero-score call. A four-second
buffer stall aborts a listening window; cancellation drops the partial track
without replacing a previously scored reference.

For local recording comparisons, its dev-only `tools/analyse_takes.gd` reads
WAVs through the same PCM pipeline and emits provisional scores/evidence,
with optional reference-based Eco and explicit failure exits. It neither
captures audio nor saves tracks/profiles; see the game's README for commands.

Quiet Mode uses measured speaking RMS and bypasses the carrying-level gate.
Optional session-local rest reminders offer water/rest or Remo between duels
after six voiced mic turns in ten minutes, never force a choice. Longer windows,
sensitivity and reminders are declared options. Live web analysis is bounded,
including queued Stop/deadline draining. Recorded rival crews, Culebra's campaign
echo encounter, cruise music and campaign progression are not implemented.
Future campaign-aware hot-seat access is undecided.
Physical microphones/permissions, authentic saloma recordings and cultural
review are unverified. The owner authorized Remo and the duel assuming success;
the real-recording gate is still unchecked.
The prototype has an original SVG icon and a synthetic complete-duel walkthrough
to satisfy the catalog's presentation contracts, not finished game art or a
configured standalone export. Read its own `README.md`, `AGENTS.md`, `DESIGN.md`
and `TODO.md` before extending it.

## Tifo Beato - Ninety minutes. No silence.

`godot --path . -- --game=tifo_beato` opens the original terrace rhythm game.
Shared setup chooses a ground/curva section; first entry opens the game's own
railway, not a running round. Career, Quick, Workshop and Chant wars live there.
Five star-gated grounds, five sections and 24 original chant Resources drive
seeded football, life/morale/rally, Fury, power-ups, tifos and six chaos events.
Football results never gate promotion. The real saved workshop banner appears
in the mosaic, giant banner and frozen share cards, including its mishaps.

The five expanded pages add bus/station/hostile Away days, bounded best-only
Derby week rituals, live classified-event Chant Creator (curated lyrics,
sixteenth-grid editor, eight slots and checked offline musical codes),
local-midnight Daily Derby and twelve read-only numeric Best Moments.
Daily freezes its date/seed/ground/group/modifier/rival through a complete
match and shares its local best/streak/assist badge. Replay seeks the real 3D
view without input capture, scoring, payout or progress writes.

Buttons are the privacy-first default. F/J Beat, Space Shout, A/S/D relative
LOW/MID/HIGH, Q Fury and E power are rebindable; gamepad and independent touch
contacts feed the same 100 Hz classifier/judge as optional mic and CPU.
Soundcheck requests capture only after Start and saves numeric measurements,
never PCM. Denied/digital-silence capture closes explicitly and leaves Buttons
usable. Quiet Mode uses speaking level with fixed carry-equivalent scoring;
timing trim adds to each seat's profile and caps the total to -100..400 ms.
Known output shares that compensated clock. Rival audio never crosses judged
onsets/Holds/Rests: an unsafe late cue keeps its caption without sound.

Desktop hot seat offers Duel (echo actual calls), Two Capos (alternate verses
with shared life/Fury) and Split the Stands (same P1 chart/seed in full turns).
Blue/red named cards require old contacts to release, preserve late input and
give the next player two guide beats. Results/payout wait for the set's final
turn. Quick/hot seat never advance the career; practice pays no Tokens.
The Creator also offers an unranked identical-chart successive challenge.
Short practice has no Fury/power-up chart rewrites. Mobile remains solo.

Original Compatibility toy models supply match/setup/store/gallery/share art,
eleven captured PNGs, a five-card player-paced intro and the real 64-second
silent tutorial. Twenty-one achievements, six cosmetic slots/22 items and
28 base gallery exhibits plus the saved banner are declared by the manifest.
Synthesis is the approved v1 audio direction; the commentator is caption-only.

Six headless suites and a required-window `curva_view_test.gd` cover actual
events through every complete mode, numeric privacy/calibration, safe timing,
merged progress, model framing, touch targets, post-input layouts and all five
story cards, the new workbench/replay layouts and original travel/ritual scenes.
From the game folder, `tools\validate.ps1 -Godot <executable>
-Suites @('sound','model','scene','flow','post_v1','post_v1_flow') -Window
-Framework` runs them in an isolated project/profile.
Linux/macOS uses `bash tools/validate.sh --godot godot
--suites sound,model,scene,flow,post_v1,post_v1_flow --window --framework`.
All fifteen shared framework suites pass, including the collection tutorial
decoder. Tifo's actual Instructions video decodes on native and exported web.

Windows/Web/Android/iOS presets use feature `tifo_beato` and the permanent
`DeskCanSaw Games/Tifo Beato` user directory, excluding other games/tests/tools.
Windows release boot and production-pack gameplay, browser portrait touch/
desktop keyboard complete matches and deny-only mic recovery are verified.
Android ARM64 debug packaging is verified, not device execution; iOS still
needs Apple provisioning/tooling. Owner melody/rival/content review and physical
microphone, speaker, pad/touch and mobile certification remain release gates.
Read the game's README/DESIGN/TODO; milestones 0-15 are implemented, while
online/stretch features remain outside this scope.

## Tuki Tuki - the Venezuelan Rhythm Revolution

`games/tuki-tuki_agents/` is a native module discovered as `tuki_tuki`, not a
second Godot project. Its React/Three.js implementation and Vite/npm artifacts
have been removed. Shared setup selects one of five songs and four champions;
the game-owned scrolling briefing selects a supported difficulty and solo
Story/Practice, or starts two simultaneous local humans on the same seeded chart.
Story, cultural styles and biographies remain skippable.

Its standalone opening is a short, skippable 3D rhythm demonstration with
on-screen text and synthesized audio; collection boot keeps the shared intro.
The actual champion rigs also dress shared setup previews and the cosmetic
outfit/shoe store. Completed songs earn Beat Tokens once, with independent
P1/P2 equipment that applies live without changing rhythm state. The free
gallery displays all four champions, arrow meshes and the actual venue.
Song completion, combo, weighted accuracy and local-battle achievements use
the shared registry; no song, champion or gallery model is progression-gated.

Original synthesized tracks preserve the web prototype's generated-beat approach;
the old referenced music/images were not bundled. Track credits and champions
are fictional. Judgement follows compensated audible playback with 22/64/106 ms
windows, independent of visual scroll speed. Song length owns completion, while
`GameShell` owns HUD, pause/settings, results, stats, replay and sharing.
Keyboard rebinding and independent on-screen touch pads are supported; gamepad
gameplay and hold notes are not. The original Compatibility meshes, pooled arrows,
live accessibility preferences and physical-sized controls remain game-owned.

The `tuki_tuki` feature provides standalone name/icon/save-directory overrides
and Windows/Web presets; the Web preset is non-threaded. Its three headless
suites cover complete deterministic charts, generated PCM/audio pause, and real
solo/local scene behavior. `stage_view_test.gd` requires a graphics window and
checks actual rendering and framing from portrait to ultrawide. Human timing
feel, physical touch hardware and device-specific audio calibration are not
replaced by those automated checks.
The Instructions screen has distinct, captioned solo/local walkthroughs recorded
from real native inputs. Re-record them with
`pwsh tools\record_tutorials.ps1 -Godot godot -Games tuki_tuki`; the tool resolves
the historical folder independently of the stable catalog ID.

## YaComio! - Small beginnings, a world of possibilities

`games/yacomio/` is a native Godot module discovered as `yacomio`. Its React/npm
scaffold has been removed. The port keeps the playable prototype's economy:
1 EP per active second, 5 EP per tap, RNA for 10 EP (+1 EP/s), and DNA
Replication for 50 EP (+3 EP/s). Either upgrade may be purchased first, once.
Its solo, untimed timeline now crosses microbes, photosynthesis, complex life,
terrestrial ecosystems and human civilization with 24 upgrades and seven
resources. Day/night and three timed milestone events integrate analytically
over unlimited away time; offline resources never grant cosmetic tokens or
advance an era. Pause and journal time are suspended.

The inherited `GameShell` supplies pause, settings and accessibility. The HUD
counts EP generated this visit separately from the spendable colony balance.
Buttons accept mouse/touch and focus navigation; M/1/2/3/E/J are rebindable
shortcuts. Original procedural Compatibility models are shared across gameplay,
the five-card player-paced intro, eight cosmetic store entries, nine free
gallery exhibits and frozen journal shares. One Spore Token per 100 actual
active EP is reconciled from saved lifetime earnings minus immutable cosmetic
prices, preventing duplicate awards. A confirmed leap after civilization
resets evolution but keeps tokens, cosmetics and achievements, adding +25%
permanent production per completed timeline. Continue resumes the colony.
The share QR is explicitly the studio website, not public colony statistics.
Every resource mutation saves `user://yacomio.cfg`, declared in `save_files` for
the shared Saves screen. Damaged/newer saves disable play without being
overwritten, and failed writes are reported in-game. Old browser saves are not
imported. Native version-1 saves retain their EP and RNA/DNA without invented
historical tokens or offline rewards.

The `yacomio` feature defines standalone branding and a stable, separate
`DeskCanSaw Games/YaComio` save directory. Windows and non-threaded Web presets
ship this module without the other games or development scripts. Its state,
scene and window-required rendered suites under `games/yacomio/tests/` cover
full progression, events, offline/fractional accounting, migration, real
controls, cancelled/confirmed prestige, cosmetics, actual rasterized models,
shares and portrait-to-ultrawide layout. Its silent, captioned walkthrough earns
RNA/DNA/membranes and reaches photosynthesis through real bound keys; re-record with
`pwsh tools\record_tutorials.ps1 -Godot godot -Games yacomio`.
Physical touch/controller hardware and human balance review remain unverified.

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
theme.light = Color("ffe3a8")         # key light on the cartridge
theme.background_top = Color("241a12")
theme.background_bottom = Color("0b0806")
game.theme = theme
```

The shared presentation reads it without naming a game:

- `background.gd` — shared screens instance it, so their gradient and glow
  follow the game. An optional `background_material` replaces the shader while
  retaining aspect correction and reduced motion. A gameplay scene can override
  its inherited backdrop with its own art instead.
- `main_menu.gd` — the cartridge takes `logo_texture_path`, tinted with
  `logo_color`; its label and lights take `plaque_color` and `light`. The
  logo fits the label at any resolution or aspect. The existing `plaque_material`
  name is retained for compatibility and still accepts game-owned materials.
  `menu_motion` controls the subtle idle focus response, never a whole-console spin.
- `router.gd` — at boot it hands `ThemeDB.get_project_theme()` to
  `GameTheme.restyle()` and puts the result on the root window, which every
  Control inherits. That swaps the studio accent for the game's wherever
  `dcs_theme.tres` uses it — focus rings, menu toggles, sliders, tab underlines — while
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
| `ui_theme: Theme` | Partial widget overrides. `MenuHeading` and `MenuSectionHeading` distinguish headings from body text and player identity. `NavigationButton` and `MenuToggle` keep shared menu actions and switches translucent and square-edged independently of ordinary Button/CheckButton skins; games may explicitly override either role. Empty styles and border-only overlays retain their transparency. |
| `ui_sounds: GameUISoundBank` | `focus`, `click`, `back`, their dB gains, and `focus_cooldown_ms`. A focus `AudioStreamRandomizer` can provide non-repeating variants. All cues use the existing SFX bus. |
| `background_material: ShaderMaterial` | Supports `top_color`, `bottom_color`, `glow_color`, `aspect`, and `speed`; zero speed must freeze all decorative motion. Materials are duplicated per screen. |
| `plaque_material: Material` | Duplicated onto the cartridge label; a `StandardMaterial3D` also receives `plaque_color`. Existing declarations need no migration. |
| `menu_motion: GameTheme.MenuMotion` | `SPRING` allows a small idle cartridge tilt; `FIRM` halves that focus response. Both use the same non-overshooting insertion, stationary console and reduced-motion fade. |
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
| Triangle Rush | Mint neon over midnight blue, a rushing-triangle logo, chamfered buttons and panels, a geometric backdrop and an etched cartridge label. Uses a gentle cartridge focus tilt. |
| Desk-Can-Saw | Safety yellow over warm wood and dark steel, a saw-and-can logo, raised workbench controls, pegboard and wood-grain scenery, and a timber cartridge label. Uses firm menu motion. |
| Dead Metal Jam | Amber stage lights over cold steel, textured metal plates, condensed headings and mechanical menu cues. Uses firm menu motion. |
| Chicken Pit | Cream and gold over turf shadow, barn-red boards, fairground bunting and an original full-colour toy-farm cover. Its share card uses the same frozen backdrop and portrait with pull/notch captions. Uses a gentle cartridge focus tilt. |
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

That makes a standalone release **export configuration only**. Windows
standalone presets cover Triangle Rush, Desk-Can-Saw, Dead Metal Jam,
Chicken Pit, Creep Code, Cube Trials, Dolce's Adventure and Tifo Beato;
LaZer NFC has Android and iOS presets, and Tifo Beato also has Web/Android/iOS.
Each is pinned by its own feature tag (`tr`, `dcs`, `dmj`, `cp`, `creep_code`,
`cube_trials`, `dolces_adventure`, `lazer_nfc`, `tifo_beato`).
A preset carries the tag and drops the other games:

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
confirm the roster, any declared level and characters and the controller
assignment. **Back** on the second step returns to the first.
Games opt into additional seats with `max_local_players = 3` or `4`; the count
selector, green P3/golden P4 cards, instructions and results follow that
capacity. Existing games remain two-player by default. Optional extra-seat
copy uses `player_three_control_description` / `instructions_player_three_controls`
and the equivalent `player_four` keys.
Each mode card states its player count in a chip, so it never rests on its icon
alone, and **Details** adds its labelled `P1`/`P2`/`CPU` roster. The chosen
card keeps a **SELECTED** badge and a one-line summary of what pressing Start
would launch, and the confirmation step tags every seat with a `PlayerAvatar`
portrait placeholder plus a **HUMAN**/**CPU** role.
The Player 2 seat is picked with an explicit two-option control —
**A Second Player** or **The CPU** — rather than an unlabelled switch. The armed
option carries a tick in its own label so the answer survives a greyscale screen,
a sentence underneath restates the choice in plain words, and the target-game
CPU difficulty row lives inside the same card because it only applies to one
of the two answers. The two options stack on a screen too narrow to show both
in full with a tick, so arming one never reflows the pair.
Multiplayer defaults to the CPU when the manifest offers
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

`scripts/player_identity.gd` provides the shared P1/P2/P3/P4 colors and labels.
`GameSession.player_name(index)`, `player_color(index)` and
`controller_assignments_changed` expose the same identities and assignments
to game-owned UI. Opt-in target games get P3's default **4 / 5 / 6** and P4's
number-pad **1 / 2 / 3** actions; legacy target games retain their six actions
and saved key bindings.
`Settings.CONTROL_ACTIONS` remains the original six; use
`control_actions_for_player(index)` for capacity-aware input.

`GameShell` preserves `PLAYER_COUNT = 2`, the P1/P2 node aliases and existing
two-score hook signatures for compatibility. New games use
`_active_player_indices()`, `_active_scores()` and `player_stats_panel(index)`
instead of assuming that constant describes the current roster. HUD, lives,
results, statistics, replay and sharing include every active seat. Round/share
data adds complete `player_scores`/`score_values`, names, colors and count,
while retaining the original first-two-score fields. The default Store payout
considers all scores once, rather than awarding one wallet grant per player.

Florida Men always exposes four active participants, including CPU guests,
while shared setup still counts humans only. It owns the board/minigame match,
opts out of shell timer/lives rules and grants Sunshine Tokens only after a
completed party. Its node-free 120 Hz minigames, original Compatibility meshes,
input adapter and music stay in its game folder. See its README for rules,
controls, tutorial recording and the four standalone presets.

Where the player count has only one answer — a game that clears
`supports_single_player`, or a gated game with a single unlocked route — the
step collapses: the screen opens on the confirmation with no stepper, and
**Back** leaves for the game picker rather than returning to a question with
one option. Chicken Pit uses this; both ends of
its rope are always pulled, so only *who plays as Player 2* was ever a choice.

The instructions screen is shown after mode selection by default. Its compact
**Show on start** toggle keeps the existing `game/show_instructions` preference;
its tooltip and accessibility name retain the full explanation. The same
preference can be restored under **Settings → Gameplay**.

The opening view gives the captioned gameplay walkthrough
(`games/<id>/assets/video/tutorial.ogv`) the whole content area, fitted at 16:9
without cropping. Only the game/mode, selected side or level/character roster,
time and Restart sit around it. **Guide** replaces the video with a scrollable
briefing containing the complete manifest headline, summary, per-player controls
and rules; **Watch** returns to the clip. Reading pauses hidden playback and
returning resumes it only if it was running before and Reduced motion is off.
An explicit pause stays paused. No game-specific text is discarded or guessed
from another game's rules.
Back, Guide/Watch, the preference and Start stay outside the scrolling content.
Controls and text use physical UI units, including on the expanded phone canvas,
and still honor the player's UI scale. Player cards stack when space is limited.
Footer wrapping measures actual action widths. Very short logical screens use
a one-row context and **On start**, retaining full tooltip/accessibility text,
so the written Guide keeps usable scroll space and whole Start/Back actions
at enlarged UI sizes.

All nine current games ship a recording and matching poster. A manifest's
optional local video/poster overrides select footage for
human-vs-human play; Anti-Chess uses a separate overhead walkthrough.
Playback starts automatically and repeats on a loop so a viewer can keep
watching without replaying it manually. There are no separate Play/Pause
buttons: click or tap the picture, or focus it and press keyboard/controller
confirm, to pause or resume. A focus outline and accessible help make that
interaction discoverable; **Restart** still rewinds the clip.
**Reduced motion** opts out of autoplay and looping: an
endlessly restarting clip is exactly the kind of unrequested repeated movement
that setting exists to suppress, so the clip parks on its poster with an explicit
**Watch again** prompt instead. If a
clip is missing, the full guide opens immediately and there is no dead Watch
button, so a game can still be authored without footage. Live Reduced motion
changes stop automatic playback and cancel a pending resume from the guide.

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
placeholder can sit at 64 units in a mode card and 48 in the instructions guide.
The
tag is drawn onto the placeholder so a card never identifies its player by
colour alone, and it is mirrored into `accessibility_description` for screen
readers.

`instructions_video_test.gd` checks the quiet opening, guide disclosure,
preserved playback state, native mouse/touch/confirm input, missing-media
fallback and all nine game themes at desktop, phone, short-landscape,
ultrawide and enlarged-UI sizes. Run it with a real graphics window and
`--instructions-capture-dir=<absolute directory>` after `--` to save both views.

Re-record the clips after changing gameplay visuals or the tutorial captions:

```bash
bash tools/record_tutorials.sh --godot /path/to/godot
godot --headless --path . --import
```

Or on Windows:

```powershell
pwsh tools/record_tutorials.ps1 -Godot /path/to/godot
godot --headless --path . --import
```

`tools/tutorial_capture.tscn` loads the actual gameplay scene, drives it with a
scripted demo player and overlays numbered step captions, so the clips can never
drift from how the game really behaves. `tools/record_tutorials.ps1` and
`tools/record_tutorials.sh` run that
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
Anti Checkers, Creep Code and Cube Trials supply the same game-owned driver
interface. Their takes cover a labelled checkers jump-chain/crowning/giveaway
lesson, the complete six-relic ritual, and a real driving segment with jumps,
checkpoints, all three cameras and recovery respectively. Cube Trials demonstrates
the delivery goal without pretending to complete the course. Drivers feed the
real scene's input paths and reject takes that miss their required milestones.
The optional `_set_capture_inset(bottom)` hook reserves room for captions without
changing normal play. Record only one game's footage with, for example,
`pwsh tools\record_tutorials.ps1 -Godot godot -Games creep_code`.
Dolce's Adventure records its real Stage 1 with
`pwsh tools\record_tutorials.ps1 -Godot godot -Games dolces_adventure`.
Tifo Beato uses its own real-event driver for a 64-second Buttons performance:
`pwsh tools\record_tutorials.ps1 -Godot godot -Games tifo_beato`.
The shared recorder captures only the game viewport and intentionally drops
the clip's audio behind the Instructions screen's existing menu music.
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
purchases out of a shared `user://`. The Saves screen's backups live beside
them in `user://save_backups/<game_id>/`, one file per snapshot holding only
that game's progress. The gallery writes nothing at all — a
museum has nothing to remember, so its only state is the manifest and whichever
achievements have opened its gated exhibits.

Focused regression checks can be run headlessly. The **15 framework suites**
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
godot --headless --path . --script res://tests/local_players_test.gd -- --game=all
godot --headless --path . --script res://tests/main_menu_test.gd -- --game=all
godot --headless --path . --script res://tests/saves_test.gd -- --game=all
godot --headless --path . --script res://tests/share_card_test.gd -- --game=all
godot --headless --path . --script res://tests/single_game_test.gd -- --game=all
godot --headless --path . --script res://tests/store_test.gd -- --game=all
godot --headless --path . --script res://tests/visual_effects_test.gd -- --game=all
```

Each game owns the rest under `games/<id>/tests/`. Counts drift as games grow,
so enumerate the folders rather than trusting a list. Cube Trials owns
`cube_trials_test.gd` (fixed-step physics, recoveries and a complete input-only
drive), `cube_trials_scene_test.gd` (live rebinding, multitouch, pause, assists,
results and achievements), `cube_trials_3d_test.gd` (volumetric bodywork, normals,
wheel/strut poses, exact terrain alignment, 3D pickups and effects),
`reference_models_test.gd` (all exported model contracts),
`cube_trials_multiplayer_test.gd` (every playable car, real deliveries,
independent turns, handoffs, standings and one payout), and the three graphical
suites below. `cube_trials_levels_test.gd` requires a fresh isolated profile
and covers new-route drives, geometry, sequential car/level unlocks, failed and
abandoned runs, hot-seat progression, replay and save reloads.
`tests/local_players_test.gd` checks opt-in capacity, gated characters and levels,
controllers, generated P3 UI, key binding compatibility, lives and share data.
`*_fixture.gd` files are helpers, not suites:

```powershell
Get-ChildItem tests\*.gd, games\*\tests\*.gd |
  Where-Object { $_.Name -notlike '*_fixture.gd' } |
  ForEach-Object {
    $rel = "res://" + ((Resolve-Path -Relative $_.FullName) -replace '^\.\\','' -replace '\\','/')
    & godot --headless --path . --script $rel -- --game=all | Out-Null
    "{0} -> {1}" -f $_.Name, $LASTEXITCODE
  }
```

Dolce's Adventure owns twelve headless suites plus `dolce_view_test.gd`
below. They cover manifest, physics, rules, pests, records, chunk fairness,
streaming, fixed stages, rig, audio, routed gestures and the real shell scene.
The scene suite snapshots and restores settings, achievements, store and run
records; still use an isolated profile because these are real rounds.

Sailor Man owns seventeen prototype suites: `saloma_scorer_test.gd`,
`voice_normalisation_test.gd`, `voice_pipeline_test.gd`, `remo_source_test.gd`,
`duel_state_test.gd`, `duel_scene_test.gd`, `sailor_scene_test.gd`,
`voice_calibration_test.gd`, `soundcheck_scene_test.gd`, `sailor_audio_test.gd`,
`gallery_scene_test.gd`, `art_capture_test.gd`, `character_preview_test.gd`,
`store_test.gd`, `onboarding_test.gd`
plus `canal_view_test.gd` and `share_card_test.gd`.
The first fifteen support headless runs; canal/share-card suites require graphics.
Also run all three scene suites, gallery, art capture, setup previews, store
and onboarding with a real window: ten windowed checks in total, including
phone through ultrawide and normal/150% UI.
Its buffered
microphone fixture tests actual PCM through the UI/source/scorer without
opening hardware. Simulated Remo key/pad/touch events also exercise the real
viewport, preview, Eco and pause/resume; ideal Remo/normalized sung fixtures
score within 5%. Duel checks play complete wins/losses through the real sources,
scorer, judges and shell results, and guard turn admission, buffered silence,
retry and the native arena's camera/render budget. Human cases cover both
actual winners, five Pacific judges, per-seat 160/280 Hz PCM/calibration/source/
rest, fresh P2 Soundcheck Save/adoption, caller-relative free Repeat and both
handoffs/live/reviews across all eight layouts, including focus scrolling and
actual P2 touch/gamepad input. Calibration checks cover
scalar round-trips/failure preservation, actual synthesized PCM through the
wizard, capture handoff, Quiet Mode, bounded finishing, saved source fallback
and optional rest actions. Canal checks cover both singers/water endpoints,
actual paint/contour pixels, labels, hidden rendering, pause and accessibility;
the measured maximum is 23 draw calls against a 60-draw budget. This is not a
substitute for physical-device or salomero QA.
Audio checks guard original PCM headroom/seams, owned playback, quiet input
contexts, event-derived once-only captions with muted SFX and actual visible
verdict captions from phone to ultrawide without shrinking active input.
Share checks cover accepted-best selection/ties, per-seat frozen PCM geometry,
privacy, silent/incomplete/scorer labels and seed/rival exclusion. Nine native
card cases verify complete boats, actual gold/paint pixels, readable/static
layout, hidden-view shutdown and reversible human/solo/other-game reuse, with
5 measured draws per portrait against a 20-draw limit. All 27 full/half PNG and
quality-75 half JPEG QR variants decoded; all 18 PNGs had no text/EXIF chunks.
Actual shell preview/Save/direct-preview pixels matched. Default checks do not
save or touch the clipboard; optional `--sailor-test-save` requires an isolated
profile and preserving/restoring the desktop clipboard.
Gallery checks use the actual list/stage, exact match meshes, canonical/error
configuration, voice/audio/save isolation and actual mouse/pad/touch camera
input. Its native matrix has 88 exhibit/size/UI renders, complete model/landmark
framing and visible launch pixels, with a maximum of 13 draws; reset, shared
auto-spin, reduced-motion parking and hidden rendering are also verified.
Art checks verify the captured transparent model icon, real CLI failures and
selector/default regeneration without overwriting checked-in art. Native checks
preserve all five arena stills, inspect gold/blue at 512/64/32px, and verify
actual title/picker/share branding with two measured icon draws. The game-owned
`tools/capture_art.gd` regenerates icon and arena previews; `--only=icon` /
`--only=levels` limit outputs and `--output-dir=<directory>` redirects them.
These remain original prototype models, not recorded or culturally reviewed
campaign assets or standalone export configuration.
Shop checks use actual Buy/P2 Equip controls, real save reload, exact file/state
restoration and other-game/voice/audio isolation. All twelve items run on both
rigs (24 model cases); native checks render 24 shelf previews, eight shop
size/UI layouts and complete decorated match/setup/gallery/frozen-share framing,
with three maximum preview draws against ten. Damaged equipment fails visibly
and recovers without stale art. Seven actual completed duels test payout,
rounding, human-only totals, bonus exclusions and duplicate settlement.

Run the suite against the full collection with `--game=all`: several checks
assert values that specific games declare, so they cannot pass in a standalone
run. `custom_keys_test.gd` uses an in-memory manifest to check CPU selection,
rebound action hints and style-specific controller rows without saving settings;
it also supports standalone launches. `single_game_test.gd` passes in both,
so a standalone build can still verify its own path. It exercises each declared
theme on the real title screen: logo tint, widget skin, flat-button text contrast,
cartridge-label materials, backdrop aspect correction and the reduced-motion switch.
`main_menu_test.gd` checks real menu layouts and 44px touch targets from a
320px phone to ultrawide, optional setup details, insertion before routing,
duplicate-input guards, standalone/collection destinations and reduced motion
both before and during launch. `game_select_test.gd` does the same for the
picker's rack: a cartridge per available game, browsing by key, pad, arrow,
drag and wheel that stops at either end, a single live preview, layouts from a
portrait phone to ultrawide, and a seating (or reduced-motion fade) that starts
the game exactly once. `saves_test.gd` validates every declared `save_files`
entry, then deletes, backs up and restores one game without touching another,
refuses newer, foreign and damaged backups, and checks the Saves screen from a
320px phone to ultrawide, its confirmation's focus and Escape handling, and the
title-screen entry in collection and standalone builds. It copies every file a
save can reach first and writes each back byte for byte, and keeps its backups
in a folder of its own, so a run never changes a player's saves.

The suites below require a **real graphics window** or add rendered checks
when run with one. Window-only suites deliberately exit 1 under `--headless`,
where they guard `DisplayServer.get_name() == "headless"` and say so; never
read that intentional headless exit code as a regression:

- `games/anti_chess/tests/board_view_test.gd` — portrait/wide framing, square
  picking, modal UI and the full-board draw budget. Optional
  `--anti-chess-capture-dir=<absolute directory>` saves rendered examples.
- `games/anti_checkers/tests/board_view_test.gd` — the equivalent coverage, with
  optional `--anti-checkers-capture-dir=<absolute directory>` output.
- `games/chicken_pit/tests/pit_view_test.gd` — the 3D pit's `SubViewport`.
- `games/florida_men/tests/party_view_test.gd` — real board/minigame pixels,
  isolated worlds, four-seat HUDs and desktop/portrait/short-landscape/ultrawide
  framing. Optional `--capture-dir=<absolute directory>` saves review frames.
- `games/lazer_nfc/tests/lazer_nfc_layout_test.gd` — its responsive layout.
- `games/creep_code/tests/observatory_view_test.gd` — all three relics and the
  finale, camera framing, direct mesh/number input, compact bottom controls,
  persistent stage/constellation, effects and the regular-subtitle opening
  in landscape, portrait and ultrawide. It also covers the outfit models,
  rotating portraits and responsive shop with native-size text/touch controls.
  Optional `--creep-capture-dir=<absolute directory>` saves actual gameplay
  and intro frames.
- `games/cube_trials/tests/cube_trials_view_test.gd` — actual 3D geometry and brown bodywork,
  landscape/portrait/ultrawide layouts, minimum physical touch-target sizes,
  an input-driven quarry jump, results, 3D share art and the standalone title.
  It also measures the real viewport's 200-draw/120,000-triangle budget.
  Optional `--cube-capture-dir=<absolute directory>` saves rendered examples.
- `games/cube_trials/tests/cube_trials_camera_test.gd` — all perspectives,
  full-course framing, each damaged cockpit and night parking. Run separately
  with `--cube-vehicle=cube_car`, `cube_sonata` and `cube_crv`. Select a route with
  `--cube-level=copper_creek`, `sunset_ridge` or `alpine_pass`.
- `games/cube_trials/tests/cube_trials_multiplayer_view_test.gd` — routed
  gated level/character selection, blue/red/green car previews, handoffs and complete
  three-player HUDs, results and share image. Requires a fresh isolated profile.
- `games/dolces_adventure/tests/dolce_view_test.gd` — actual pixels and
  whole-body framing from 320px phones to ultrawide, multitouch targets,
  Auto-run tip docking, long scores, large UI, Full, captions and airborne
  poses. Optional `--dolce-view-captures=<absolute directory>` saves frames.
- `games/sailor_man/tests/canal_view_test.gd` — all five practice arenas,
  complete launches/source-relative ribbons in both singer framings and water
  endpoints, 40 phone-to-ultrawide size/UI cases, actual paint/contour/landmark
  pixels and labels, <60 draws (measured maximum 23), real pause, hidden-view
  shutdown and accessibility preferences.
  Optional `--sailor-capture-dir=<absolute directory>` saves rendered examples.
- `games/sailor_man/tests/share_card_test.gd` — nine frozen result cards,
  including both human winners, Pacific, a real decider, solo/echo/silent/
  incomplete/scorer outcomes and a display-only width stress fixture. Actual
  gold contours, player paint, full framing, static/reused/hidden views and
  <20 draws per portrait (measured maximum 5).
  Optional `--sailor-share-capture-dir=<absolute directory>` saves full/half
  PNG and quality-75 half JPEG for QR decoding and PNG metadata checks.
  `--sailor-test-save` tests the real explicit PNG action; use isolated user
  data and preserve/restore the desktop clipboard, which receives the image path.
- `games/sailor_man/tests/gallery_scene_test.gd` — also supports headless
  configuration/mesh/isolation checks. With a window it renders all eleven
  free exhibits in 88 phone-to-ultrawide size/UI cases, checks actual launch
  pixels and complete framing, <60 draws (measured maximum 13), real viewer
  mouse/pad/touch input, reset, auto-spin/reduced motion and hidden-render shutdown.
  Optional `--sailor-gallery-capture-dir=<absolute directory>` saves examples.
- `games/sailor_man/tests/art_capture_test.gd` — also supports headless PNG
  and CLI rejection checks. With a window it verifies actual icon/level/default
  regeneration, transparent full geometry, 512/64/32px gold/blue pixels, <10
  draws (measured 2) and real title/picker/share theme integration.
  Optional `--sailor-icon-capture-dir=<absolute directory>` saves inspections.
- `games/sailor_man/tests/character_preview_test.gd` — also supports headless
  real collection/standalone solo/hot-seat configuration, canonical mesh reuse,
  rejection/recovery and audio/save isolation. With a window it checks 25
  setup cases, including compact expanded Details, actual focused pickers and
  Start visibility, full framing, paint/face/plaque pixels, static/hidden views
  and <10 draws (measured maximum 3).
  Optional `--sailor-setup-capture-dir=<absolute directory>` saves UI/model captures.
- `games/sailor_man/tests/store_test.gd` — also supports headless purchases,
  independent equipment/shared ownership, persistence, canonical mesh reuse,
  frozen outfits and error recovery. With a window it checks 24 shelf previews,
  eight shop layouts, whole scroll-focused controls and complete decorated
  match/setup/gallery/share framing, with <10 preview draws (measured maximum 3).
  Optional `--sailor-store-capture-dir=<absolute directory>` saves inspections.
- `games/sailor_man/tests/onboarding_test.gd` — also supports headless pacing,
  actual input/Router exits, five-mark Guide/rebinding, live Reduced motion and
  audio/save isolation. With a window it checks 40 layouts for opening cards
  and solo/hot-seat Guides, readable/reachable copy, whole actions, complete
  actual model framing/pixels and <60 draws (measured maximum 12). Seven title routes include
  incoming-transition and duplicate-input guards.
  Optional `--sailor-onboarding-capture-dir=<absolute directory>` saves examples.

Run tests sequentially and use an isolated user profile for host tests that
exercise persistence or complete real rounds.

The FPS counter is available under **Settings → Display** and is drawn by
`Router`, so it stays visible across scenes without each game implementing its
own counter.

- `games/tifo_beato/tests/curva_view_test.gd` — original live stadiums/cast/
  effects/cameras, complete gallery/store/frozen-share geometry, real keyboard/
  touch play, post-input portrait/short-landscape layouts and 30 five-card intro
  layouts at normal/enlarged UI scales. Final visible+shadow draws measured 32
  against a budget of 90. Headless `sound`, `model`, `scene` and `flow` suites
  plus the separate platform Node fixture cover the non-rendering contracts.

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
