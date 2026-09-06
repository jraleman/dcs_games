# AGENTS.md — DCS Games

Guidance for AI coding agents working in this repository.

## What this repository is

A **reusable Godot 4.7 base project** (`godot-base/`) for DeskCanSaw Games,
plus the games built on it. The base ships everything a game needs *before* it
is a game: studio sting, intro, main menu, persistent settings, credits, pause
overlay, achievements, responsive UI, share-image generation and audio.

Three games currently live in it:

| Game | ID | Folder |
| --- | --- | --- |
| Triangle Rush | `triangle_rush` | `godot-base/games/triangle_rush/` |
| Desk-Can-Saw | `desk_can_saw` | `godot-base/games/desk_can_saw/` |
| Dead Metal Jam | `dead_metal_jam` | `godot-base/games/dead_metal_jam/` |

> Triangle Rush and Desk-Can-Saw were previously `target_rush` and
> `slice_and_slash`. Those ids are gone — no alias, no migration — so a
> `user://` written by an older build keeps its progress under the old strings
> and reads as a fresh save. The one thing that did *not* move is
> `config/custom_user_dir_name.tr`, which still says `Target Rush` because it
> names the folder those saves live in.

Renderer is `gl_compatibility` so the project exports to web and mobile
unchanged. Keep it that way: do not introduce Forward+/Vulkan-only features.

## Layout

```
README.md                  # points at godot-base
SHARE_IMAGE_DESIGN.md      # spec for the shareable score card + QR contract
godot-base/
  project.godot            # autoloads, input actions, [share] stats URLs
  autoload/                # Settings, AudioManager, Router, GameSession,
                           #   AchievementManager, ShareManager  (load order matters)
  scripts/                 # StudioInfo, GameManifest, GameCatalog, GameUnlockRule,
                           #   GameTheme, GameShell, ShareQrCode
                           #   (class_name globals, not autoloads)
  ui/                      # MenuScreen, Responsive, theme, reusable components
  scenes/boot/             # studio_logo, intro
  scenes/game/             # game_shell.tscn — the round/HUD scene games inherit
  scenes/menus/            # main_menu, mode_select, instructions, settings, credits, pause
  games/<id>/              # one folder per game: game.gd manifest, scenes, actors, tests
  tests/                   # framework-wide headless SceneTree regression scripts
  tools/                   # dev-only tutorial recorder (exclude from export presets)
  third_party/greaby_qrcode/  # vendored MIT QR encoder — keep LICENSE intact
  assets/                  # audio, images, tutorial videos
```

## Commands

Run everything from `godot-base/`. Godot is **not** installed in every dev
environment — check before assuming a command will run.

```bash
godot --path .                       # run the game (or open project.godot)
godot --path . -- --game=dead_metal_jam   # run one game as a standalone build
godot --headless --path . --import   # reimport assets and refresh the class cache
```

Tests are standalone headless `SceneTree` scripts, run one at a time. All eleven
must exit 0:

```bash
godot --headless --path . --script res://games/desk_can_saw/tests/desk_can_saw_test.gd
godot --headless --path . --script res://games/desk_can_saw/tests/desk_can_saw_scene_test.gd
godot --headless --path . --script res://tests/visual_effects_test.gd
godot --headless --path . --script res://tests/accessibility_test.gd
godot --headless --path . --script res://games/triangle_rush/tests/triangle_rush_options_test.gd
godot --headless --path . --script res://tests/share_card_test.gd
godot --headless --path . --script res://tests/instructions_video_test.gd
godot --headless --path . --script res://tests/game_shell_test.gd
godot --headless --path . --script res://tests/lives_mode_test.gd
godot --headless --path . --script res://tests/game_options_test.gd
godot --headless --path . --script res://tests/single_game_test.gd
```

Dead Metal Jam adds six of its own:

```bash
godot --headless --path . --script res://games/dead_metal_jam/tests/pitch_detector_test.gd
godot --headless --path . --script res://games/dead_metal_jam/tests/note_router_test.gd
godot --headless --path . --script res://games/dead_metal_jam/tests/playing_techniques_test.gd
godot --headless --path . --script res://games/dead_metal_jam/tests/latency_calibration_test.gd
godot --headless --path . --script res://games/dead_metal_jam/tests/encounter_test.gd
godot --headless --path . --script res://games/dead_metal_jam/tests/intro_test.gd
```

`tests/game_shell_test.gd` iterates `GameCatalog.all()`, so every game is
covered automatically — do not add a per-game copy of it. `tests/game_options_test.gd`
does the same for a game's declared `tunables` and `control_bindings`, and
`tests/single_game_test.gd` pins the catalog to each game in turn to check the
standalone path, including that every `intro_scene_path` a manifest declares
loads and leads somewhere, that the main-menu settings screen exposes that
game's Controls and Game tabs, that the credits roll is that game's own
while a collection build points at each game instead, and that a declared
`GameTheme` reaches the plaque and the shared theme. Run the suite unpinned:
several tests assert
values that a specific game declares, so only `single_game_test.gd` passes under
`--game`.

There is no linter, formatter or CI configured. Match the existing style by hand.

Re-record tutorial clips only when gameplay visuals or captions change:

```bash
pwsh tools/record_tutorials.ps1 -Godot /path/to/godot
```

## The framework / game boundary (read before adding a game)

This is the most important rule in the repository. Games are **self-contained
folders** under `res://games/<id>/`; `GameCatalog` discovers them at startup by
loading `games/*/game.gd` and calling its `static func manifest()`.

**Adding a game must not require editing framework code.** If you find yourself
adding `if game_id == "..."` to anything under `autoload/`, `scenes/` or `ui/`,
add data to `GameManifest` instead.

**What a game owns** (all declared on its `GameManifest`):

| Field | Purpose |
| --- | --- |
| `id`, `title`, `tagline`, `menu_order` | Identity and main-menu ordering |
| `gameplay_scene_path` | The scene `Router` loads to play |
| `intro_scene_path` | The game's own opening, played instead of the framework intro — **only** in a build that ships this game alone |
| `credits` | The game's own credits sections (`StudioInfo.CREDITS` shape); they lead the credits roll in a standalone build |
| `theme` | A `GameTheme`: logo plus accent/background colours, worn by every screen in a standalone build |
| `achievements` | Registered and persisted by `AchievementManager` |
| `copy` | Overrides menu/instructions wording; omitted keys fall back to neutral text |
| `tunables` | Player-facing options (slider/toggle/choice) stored and clamped by `Settings`, rendered as rows on the in-game Game tab |
| `control_bindings` | Rebindable keys, rendered on the in-game Controls tab; empty means "inherit my `control_style`'s built-ins" |
| `control_style` | `targets` or `direct_movement` — menus branch on this *trait*, never on a game name |
| `unlock_rule`, `hidden_until_unlocked` | Gate the game behind progress elsewhere |
| `share_art_style`, `stats_url` | Share-card art variant and QR link |
| `tutorial_video_path`, `tutorial_poster_path` | Instructions-screen media |
| `supports_multiplayer`, `supports_cpu_opponent` | Mode availability |

`tunables` and `control_bindings` are declared in a constants-only
`games/<id>/<prefix>_options.gd` (`TriangleRushOptions`, `DeskCanSawOptions`,
`DmjOptions`) so headless tests can import the keys without touching an
autoload. The game's scenes read the same constants back through `Settings`.

**Settings tabs**: Audio · Display · Accessibility · Gameplay · **Controls** ·
**Game**. The last two configure one game, so in a collection build they only
exist while a round is running — `pause_menu.gd` sets
`settings_menu.game_context_id` between `instantiate()` and `add_child()`, and
the main menu leaves it empty, which hides both tabs. In a **standalone build**
`_resolve_game_context()` adopts the only game in the catalog, so both tabs are
on the main menu too; `_configure_style_rows()` then hides rows elsewhere that
suit only the other `control_style`. Their rows are generated from the
manifest, so **a new game's options need no scene edit**.

**Key APIs**

- `GameCatalog.current()` / `.select(id)` / `.all()` / `.available()` —
  which game is active. Never ask "is this Desk-Can-Saw?".
- `GameCatalog.single_game_id()` / `.restrict_to(id)` / `.is_single_game_build()`
  — standalone builds. A catalog holding one game *is* the standalone product,
  so the pin lives in one place: the project setting `dcs/build/single_game_id`
  (feature-overridable per export preset), `--game=<id>` after `--`, or
  `DCS_GAME`. Never add a second way to hide a game.
- `GameCatalog.intro_scene_path(fallback)` — the opening `studio_logo.gd` hands
  over to. Returns a game's `intro_scene_path` only when the catalog holds one
  game; a collection has not chosen a game yet, so it gets the framework intro.
- `credits.gd` follows the same rule for `GameManifest.credits`: one game in
  the catalog rolls that game's credits, a collection names the games it ships
  and sends the player to each game's own.
- `GameCatalog.theme()` — never null. The pinned game's `GameTheme` in a
  standalone build, `GameTheme.studio_default()` otherwise. Read by
  `background.gd` (every screen), `main_menu.gd` (the rotating logo plaque)
  and `router.gd`, which restyles the project theme onto the root window so
  every Control inherits the game's accent. `MenuScreen` and `GameShell` also
  call `theme().restyle_tree(self)` in `_ready()`, because a `Theme` cannot
  reach the accents baked into `theme_override_*` entries, scene-local
  styleboxes and `ColorRect`s. Player colours are excluded on purpose —
  telling P1 from P2 is an accessibility contract.
- `AchievementManager.record_round(source_game_id, result)` — offers every
  finished round to **every** game's `GameUnlockRule`, so "playing A unlocks B"
  needs no framework change. Rules filter by `source_game_id` themselves.
- `Settings.tunable(key)` / `.tunable_bool(key)` / `.tunable_choice(key)` /
  `.tunable_min(key)` / `.tunable_max(key)` — read a game-declared option.
  `Settings` never hardcodes a game's numbers.
- `Settings.binding_keycode(key)` / `.set_binding_key(key, code, game_id)` /
  `.control_bindings_for_game(id)` / `.movement_summary_for_game(id, sep, fallback)`
  — a game's own keys. Conflicts are scoped to one game; two games may share a key.
- `manifest.text(key, fallback)` — screen copy with a neutral default.

## `GameShell` — the shared round loop

A gameplay scene is an **inherited scene** of `scenes/game/game_shell.tscn`
with a script that `extends GameShell` (`scripts/game_shell.gd`). Neither game
folder depends on the other; both are ~8-line inherited scenes that only set
`script` and their own exports.

The shell owns the countdown, round timer, HUD, results panel, stats panel,
pause overlay, share payload/preview, screen shake, confetti, achievement
recording and every accessibility setting. A game overrides `game_id()` plus
whichever hooks it needs — all others have working neutral defaults.

| Hook | Purpose |
| --- | --- |
| `game_id()` | **Required.** Returns the manifest id; the shell resolves everything else from it. |
| `_prepare_session()` | Read `GameSession` before the first round |
| `_build_playfield()` | Spawn actors under `%Playfield` |
| `_begin_first_round()` | Custom opening timing |
| `_load_round_settings()` | Read the game's `Settings.tunable(...)` values (call `super()`) |
| `_reset_round_state()` | Clear per-round state before the countdown |
| `_activate_round()` | Start motion when the countdown clears |
| `_update_round(delta)` | Per-frame gameplay |
| `_handle_gameplay_input(event)` | Gameplay input; `pause` is already consumed |
| `_finish_round()` | Settle scores when time runs out |
| `_round_totals()` / `_player_stats(index)` | Feed the results and stats panels |
| `_describe_round_outcome()` / `_round_highlight_summary()` | Results copy |
| `_award_round_achievements(result)` | Unlock the game's own achievements |
| `_spawn_round_confetti()` | Custom celebration |
| `_playfield_bounds()` | Play area, if not the whole viewport |
| `_configure_mode_ui()` | Extra 1P/2P/CPU HUD wiring (call `super()`) |
| `_on_player_labels_changed()` / `_on_controls_changed()` | React to accessibility settings |
| `_on_game_setting_changed(key)` | React to one of the game's tunables changing live |

Shell notes:

- The round can run on a countdown or on a pool of lives
  (*Settings → Game → Round mode*, stored as `game/round_mode` +
  `game/starting_lives`). The shell owns the whole pool; a game only reports
  its own mistakes with `_lose_life(player_index)` and skips eliminated players
  with `_player_is_out(player_index)`. Both no-op in timer mode, so **a game
  must never branch on the round mode**. Use `_lives_rule_note()` for HUD copy
  and `_round_length_phrase()` instead of hardcoding "in 60 seconds".
- The playfield node is `%Playfield` (it was `%Targets` before the extraction);
  tests reference it by that unique name.
- `%ModeTitle` is always filled from `GameManifest.title` — never hardcode it.
- `screen_shake_decay` is an `@export` so a game can tune feel from its `.tscn`
  instead of subclassing behaviour.
- Seven HUD widgets have duplicate node names (`Caption`, `Versus`, `Title`,
  the player cards) and are therefore reached with `$Path` rather than
  `%UniqueName`. That is the one documented exception to the `%` rule; renaming
  them would rewrite dozens of `parent=` paths.

**Known remaining coupling** (fix opportunistically, do not extend):

- `audio_manager.gd` synthesises chainsaw/can SFX for Desk-Can-Saw.
- `share_card_art.gd` draws both games' art variants.

**Stays generic (safe to reuse as-is):** `router.gd`, `responsive.gd`,
`menu_screen.gd`, `game_shell.gd`, `game_shell.tscn`, `dcs_theme.tres`,
`background`, `splash_motion`, `achievement_toast`, `audio_caption`,
`player_avatar`, `share_preview`, `share_qr_code`, `studio_logo`, `intro`,
`game_catalog.gd`, `game_manifest.gd`, `game_unlock_rule.gd`, and the
persistence/toast core of `AchievementManager`, `Settings` and `AudioManager`.

## Conventions

**GDScript**
- Tabs for indentation. Soft limit ~100 columns; most lines stay under 88.
- Static typing everywhere: `var x := 0`, `func f(a: int) -> String:`.
- `##` doc comments on every script and public function; explain *why*, not what.
- `snake_case` members, `_leading_underscore` for private, `SCREAMING_CASE` consts.
- `@onready var _node: Type = %UniqueName` — use scene-unique names, not `$Path`.
- Prefer signals over polling; prefer `Resource`/`const` dictionaries over
  scattered literals.

**Scenes & UI**
- Change scenes with `Router.goto(path)`, never `change_scene_to_file()`.
  `Router` owns the fade and the always-on-top overlay layer.
- Gameplay scenes inherit `scenes/game/game_shell.tscn`; do not author a
  parallel HUD/results shell.
- Menus extend `MenuScreen` and override `_on_layout_changed(size)` for
  responsive work; `Responsive` provides margin/portrait/width helpers.
- Animate anchored controls with `modulate` and `scale` (centred `pivot_offset`)
  — **never** `position`, which bakes offsets and breaks on the next resize.
- Every layout must survive portrait phone through ultrawide. Long content goes
  in a `ScrollContainer`.

**Accessibility (non-negotiable — the project already honours all of these)**
- Respect `Settings.reduced_motion_enabled()`: freeze ambient/decorative motion,
  keep essential gameplay movement, use opacity-only fades.
- Respect the intense-visual-effects setting for flashes and screen shake.
- Never encode meaning in colour alone; keep the P1/P2 labels working.
- Add an audio caption for any meaningful sound-only event.

**Persistence**
- Settings → `user://settings.cfg`; achievements/progression →
  `user://achievements.cfg`. Both via `ConfigFile`.
- Both saves **merge into the stored file** rather than rebuilding it. A build
  only registers the keys of the games it ships, so rewriting from the registry
  would delete an absent game's options and unlocks out of a shared `user://`.
- `application/config/custom_user_dir_name` must be unique per derived game and
  then **stable forever** — changing it strands player saves.

**Share cards**
- Stats URLs must be ≤ 42 UTF-8 bytes or the QR stops scanning after the card
  is downscaled to 600×315. Per-game defaults live under `[share]` in
  `project.godot`; see `SHARE_IMAGE_DESIGN.md`.
- Any scene with `configure(Dictionary)` can be passed to
  `ShareManager.generate_score_image()`.

## Gotchas

- Autoload order in `project.godot` is deliberate (`Settings` before
  `AudioManager`/`Router`). Do not reorder.
- `StudioInfo`, `GameCatalog`, `GameManifest`, `GameUnlockRule` and `GameTheme`
  are `class_name` globals, **not** autoloads. `GameCatalog` is a *static* registry
  on purpose: autoload names are unavailable at compile time to other autoloads
  and to headless test scripts, and `AchievementManager` and the catalog need
  each other.
- **Headless `--script` runs compile the test script and its direct
  dependencies before autoloads exist.** In those files you may reference an
  autoload's *constants* (`Settings.SAVE_PATH`) but not the autoload *instance*.
  Resolve it from the tree instead: `get_root().get_node_or_null("Settings")`,
  then use `.call("method", ...)`. Any `class_name` script a test imports must
  likewise avoid autoload instances — that is why every `<prefix>_options.gd`
  (`triangle_rush_options.gd`, `desk_can_saw_options.gd`, `dmj_options.gd`) is
  constants-only. `GameShell` is
  the other side of this rule: it *does* use autoload instances, so a test must
  never name `GameShell` (no `is GameShell`, no typed parameter). Load the
  scene at runtime and poke it with `call`/`get`/`has_method`.
- After adding a `class_name`, run `--import` before the tests, or the global
  class cache will not know it.
- Setting `min_value`/`max_value` on a `Range` re-emits `value_changed`. Do it
  while the screen's `_syncing` guard is set, or the pre-sync value is written
  back to disk. A generated slider sets its bounds *before* connecting the
  signal, for the same reason.
- A test that opens `settings_menu.tscn` must assign `game_context_id` before
  `add_child()` if it needs the Controls or Game tab; `_ready()` is what builds
  them. Generated widgets are not scene-unique names — reach them through the
  screen's `_option_controls` / `_option_values` / `_binding_buttons`.
- `Settings` now restores manifest-declared options from `settings.cfg` (it
  used to save them and never read them back). A test that changes one must put
  it back, or it leaks into every later run.
- Prefer `float` accessors over `Vector2` for setting ranges — `Vector2` is
  32-bit and silently corrupts stored values.
- Achievement and unlock flags must never regress after a later match.
- Progression keys in `user://achievements.cfg` are globally unique strings
  (e.g. `desk_can_saw_solo_qualified`); keep them stable so saves survive.
- Mobile exports are single-player only (`GameSession.multiplayer_available()`).
- Quit is hidden on web and mobile.
- `tools/*` is development-only; keep it out of export presets.
- Do not edit files under `third_party/` except to update the vendored library,
  and keep the MIT `LICENSE` in place.

## Working agreements

- Keep `godot-base/README.md` accurate — it is the authoring guide, and it is
  detailed. Update it in the same change as any behaviour it describes.
- Prefer editing existing scenes/scripts over creating parallel ones.
- When you cannot run Godot to verify a change, say so explicitly rather than
  claiming the change is tested.
