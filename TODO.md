# TODO

## Shared-framework architecture review (2026-11-05)

Scope: shared framework and cross-game contracts only; individual game
implementations were excluded.

Validation: source-based review only; Godot runtime tests were not run.
File locations refer to the reviewed snapshot.

- [ ] **[P2] Failed merge reads can overwrite cross-game progress.**

  Locations: `godot-base\autoload\store.gd:650-653`,
  `godot-base\autoload\settings.gd:1027`, and
  `godot-base\autoload\achievement_manager.gd:335`.

  `ConfigFile.load()` errors are ignored before saving. If an existing file
  cannot be read or parsed, the subsequent write can replace other games'
  purchases, balances, settings, or achievements.

  Follow-up: abort writes on read errors other than `ERR_FILE_NOT_FOUND` in
  all three merge writers, and report the failure.

- [ ] **[P2] Binding Pause to A breaks controller menu confirmation.**

  Location: `godot-base\scenes\menus\pause_menu.gd:33-40`.

  Settings permits A as Pause, but A also supplies `ui_accept`. The pause
  handler consumes it before GUI controls receive it, so confirming
  Settings/Store/Gallery resumes gameplay or closes the overlay instead.

  Follow-up: preserve GUI confirmation precedence or disallow Pause mappings
  that collide with menu confirmation.

- [ ] **[P2] Conflict swapping can create a forbidden Pause binding.**

  Location: `godot-base\autoload\settings.gd:965-967`.

  Reproduction: assign Target 1 to D-pad Up, then reassign it to Start. The
  conflict swap moves Pause onto D-pad Up despite its explicit prohibition.
  Startup repair then resets the controller layout, losing customization.

  Follow-up: validate both assignments before changing either setting, and
  reject swaps that would produce an illegal mapping.
