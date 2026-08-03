# DeskCanSaw Game Base

A Godot 4 starting point for DeskCanSaw Games projects. It ships the parts every
game needs before it is a game: the studio sting, an intro, a main menu,
settings that persist, credits, a pause overlay and a placeholder gameplay
scene — all built to look right from a phone in portrait to an ultrawide
monitor.

Made with **Godot 4.6** (`gl_compatibility` renderer, so it exports to web and
mobile without changes).

## Running it

```bash
godot --path .            # or open project.godot in the editor
```

The first scene is `scenes/boot/studio_logo.tscn`; from there the flow is:

```
studio_logo  ──►  intro  ──►  main_menu  ──┬──►  gameplay  ──►  pause_menu ──► settings (overlay)
 (skippable)   (skippable)                 ├──►  settings_menu
                                           └──►  credits
```

## What's in the box

| Path | What it does |
| --- | --- |
| `scripts/game_info.gd` | Studio and game identity: title, tagline, intro cards, credits, palette. **Start here when renaming the game.** |
| `autoload/settings.gd` | Stores, persists (`user://settings.cfg`) and applies player settings. |
| `autoload/audio_manager.gd` | Music crossfades, an 8-voice SFX pool, bus volumes, UI sounds. |
| `autoload/router.gd` | `Router.goto(path)` — scene changes with a fade. Owns the top overlay layer (fade + FPS counter). |
| `ui/menu_screen.gd` | `MenuScreen` base class: UI sounds, focus handling, `ui_cancel` to go back, responsive margins. |
| `ui/responsive.gd` | Helpers for margins, portrait detection and content width. |
| `ui/theme/dcs_theme.tres` | The whole look: buttons, panels, sliders, tabs. |
| `ui/components/background.tscn` | Animated gradient backdrop (shader), aspect-corrected. |
| `scenes/game/gameplay.tscn` | Placeholder — delete the bouncing triangle, keep the HUD/pause wiring. |

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

**Hook up your game** — replace `scenes/game/gameplay.tscn` (or point the main
menu's `play_scene` at your own scene). Keep a `CanvasLayer` for the HUD and the
`pause` action handling, and the pause overlay works as-is.

## Input actions

| Action | Bound to |
| --- | --- |
| `skip` | Space, Enter, left mouse button, gamepad A |
| `pause` | Esc, gamepad Start |
| `toggle_fullscreen` | F11 |
| `ui_accept` / `ui_cancel` | Godot defaults (menu navigation and back) |

## Placeholder assets

- `assets/images/dcs_logo.png` — the real DeskCanSaw Games logo.
- `assets/audio/ui_click.wav`, `ui_focus.wav`, `ui_back.wav` — synthesised UI
  blips generated for this template; replace them with your own.
- `icon.svg` — a simple placeholder mark, not the finished studio icon.

The theme uses Godot's default font. To use your own, drop a `.ttf`/`.otf` in
`assets/fonts/`, then set it as the theme's default font in
`ui/theme/dcs_theme.tres`.
