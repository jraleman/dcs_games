# DeskCanSaw Game Base

A Godot 4 starting point for DeskCanSaw Games projects. It ships the parts every
game needs before it is a game: the studio sting, an intro, a main menu,
settings that persist, credits, a pause overlay and a placeholder gameplay
scene — all built to look right from a phone in portrait to an ultrawide
monitor.

Made with **Godot 4.7** (`gl_compatibility` renderer, so it exports to web and
mobile without changes).

## Running it

```bash
godot --path .            # or open project.godot in the editor
```

The first scene is `scenes/boot/studio_logo.tscn`; from there the flow is:

```
studio_logo  ──►  intro  ──►  main_menu  ──┬──►  mode_select  ──►  instructions  ──►  gameplay
 (skippable)   (skippable)                 │                         (optional)          │
                                           ├──►  settings_menu                         └──► pause_menu
                                           └──►  credits
```

## What's in the box

| Path | What it does |
| --- | --- |
| `scripts/game_info.gd` | Studio and game identity: title, tagline, intro cards, credits, palette. **Start here when renaming the game.** |
| `autoload/settings.gd` | Stores, persists (`user://settings.cfg`) and applies player settings. |
| `autoload/game_session.gd` | Holds the selected single-player or multiplayer configuration while moving between scenes. |
| `autoload/audio_manager.gd` | Music crossfades, an 8-voice SFX pool, bus volumes, UI and gameplay sound cues. |
| `autoload/achievement_manager.gd` | Persistent achievement registry and queued global achievement toasts. |
| `autoload/share_manager.gd` | Renders reusable 1200×630 session cards, downloads them on web and saves them for desktop sharing. |
| `autoload/router.gd` | `Router.goto(path)` — scene changes with a fade. Owns the top overlay layer (fade + FPS counter). |
| `ui/menu_screen.gd` | `MenuScreen` base class: UI sounds, focus handling, `ui_cancel` to go back, responsive margins. |
| `ui/responsive.gd` | Helpers for margins, portrait detection and content width. |
| `ui/theme/dcs_theme.tres` | The whole look: buttons, panels, sliders, tabs. |
| `ui/components/background.tscn` | Animated gradient backdrop (shader), aspect-corrected. |
| `ui/components/achievement_toast.tscn` | Small reusable unlock notification used by `AchievementManager`. |
| `ui/components/share_card.tscn` | Default score/achievement image; swap it or pass another scene to `ShareManager`. |
| `ui/components/share_preview.tscn` | Modal generated-image preview with close and open-original actions. |
| `ui/components/splash_motion.gd` | Lightweight animated geometry for logo stings and splash screens. |
| `scenes/game/gameplay.tscn` | Score game with single-player, local multiplayer and CPU-opponent modes. |
| `scenes/game/triangle_target.tscn` | Reusable owned target with inactive/highlighted states and tap/click activation. |

## Looking right on every screen

The project stretches a **1920x1080** base with `canvas_items` + `expand`, so a
viewport is never *narrower* than the base on one axis and simply shows more
space on the other. Layouts are written in those units and adapt at runtime:

- **`Settings._update_content_scale()`** scales the UI up on physically small
  windows (below ~700px tall), so text stays legible on a phone. The player can
  bias it further with *Settings → Display → Interface size*.
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

**Rename the game** — edit `scripts/game_info.gd` (`TITLE`, `TAGLINE`,
`INTRO_CARDS`, `CREDITS`) and `application/config/name` in `project.godot`.

**Replace the intro** — either edit the `cards` array on
`scenes/boot/intro.tscn`, or build a new scene and point
`studio_logo.tscn → next_scene` at it. The only contract is that it eventually
calls `Router.goto(next_scene)`.

**Add a setting** — add a key to `Settings.DEFAULTS`, handle it in
`Settings._apply()` (or let another node listen to `Settings.changed`), then add
a row to `scenes/menus/settings_menu.tscn` and wire it in
`settings_menu.gd::_connect_ui()`. Saving, loading and defaults come for free.

**Add music** — drop an `.ogg` in `assets/audio/`, then set the `music` export
on the main menu, intro or gameplay scene. Volume is already wired to the Music
bus and its slider. Call `AudioManager.play_music(stream)` anywhere else.

**Add an achievement** — define its title, description and short badge in
`GameInfo.ACHIEVEMENTS`, then call `AchievementManager.unlock("your_id")` at the
game-specific unlock point. Persistence, duplicate protection, audio and the
animated toast are automatic.

**Share a result** — call
`var result = await ShareManager.generate_score_image(session_data)`, then call
`ShareManager.show_preview(result)` after a successful result. The default card
expects result, score, accuracy, hits, combo and achievement fields, but any
scene with a `configure(Dictionary)` method can be passed as the second
argument. Web exports download the PNG; desktop exports save it under
`user://shares` and copy the saved path to the clipboard. The preview displays
the generated PNG and can open the saved original in the system image viewer;
the open action is hidden in browser exports.

**Tune the sample game** — the exported values on
`scenes/game/gameplay.gd` control both players' keys and colours, target speed,
round length, points, miss penalty, and CPU reaction speed/accuracy. The sample
keeps rules in `gameplay.gd` and target input / movement in
`triangle_target.gd`, so either part can be replaced independently.

**Hook up your own game** — replace `scenes/game/gameplay.tscn` (or point the
main menu's `play_scene` at your own scene). Keep a `CanvasLayer` for the HUD
and the `pause` action handling, and the pause overlay works as-is.

## Input actions

| Action | Bound to |
| --- | --- |
| `skip` | Space, Enter, left mouse button, gamepad A |
| `pause` | Esc, gamepad Start |
| `toggle_fullscreen` | F11 |
| `ui_accept` / `ui_cancel` | Godot defaults (menu navigation and back) |

The sample gameplay reads its displayed number keys directly, so changing its
target digits does not require adding Input Map actions. Player 1 defaults to
1/2/3 and Player 2 to 7/8/9. Single-player creates only Player 1's targets;
multiplayer lets Player 2 use those controls or hands the red side to the CPU.
Each active player has one bright target at a time: matching it earns a point,
while choosing one of that player's dim targets costs a point. Human-controlled
targets also accept mouse and touchscreen presses.

The instructions screen is shown after mode selection by default. Its
**Show instructions when starting a mode** toggle is persisted, and the same
preference can be restored under **Settings → Game**.

The sample unlocks **Solo Starter** after the first completed single-player
round and **First Win** after Player 1's first multiplayer victory. The FPS
counter is available under **Settings → Display** and is drawn by `Router`, so
it stays visible across scenes without each game implementing its own counter.

## Placeholder assets

- `assets/images/dcs_logo.png` — the real DeskCanSaw Games logo.
- `assets/audio/ui_click.wav`, `ui_focus.wav`, `ui_back.wav` — synthesised UI
  blips generated for this template; replace them with your own.
- `icon.svg` — a simple placeholder mark, not the finished studio icon.

The theme uses Godot's default font. To use your own, drop a `.ttf`/`.otf` in
`assets/fonts/`, then set it as the theme's default font in
`ui/theme/dcs_theme.tres`.
