# DCS Base Game

The Godot project lives in [`godot-base`](godot-base).

## Cloning

Twelve of the fourteen game folders under `godot-base/games/` are Git submodules,
so clone this repository with them:

```bash
git clone --recurse-submodules git@github.com:jraleman/dcs_games.git
```

In an existing checkout, fetch them with:

```bash
git submodule update --init --recursive
```

| Game folder | Where it lives |
| --- | --- |
| `anti_checkers` | submodule — [jraleman/anti_checkers](https://github.com/jraleman/anti_checkers) |
| `anti_chess` | submodule — [jraleman/anti_chess](https://github.com/jraleman/anti_chess) |
| `capitans_walk` | submodule — [jraleman/capitans_walk](https://github.com/jraleman/capitans_walk) |
| `chicken_pit` | submodule — [jraleman/chicken_pit](https://github.com/jraleman/chicken_pit) |
| `creep_code` | submodule — [jraleman/creep_code](https://github.com/jraleman/creep_code) |
| `cube_trials` | submodule — [jraleman/cube_trials](https://github.com/jraleman/cube_trials) |
| `dead_metal_jam` | submodule — [jraleman/dead_metal_jam](https://github.com/jraleman/dead_metal_jam) |
| `dolces_adventure` | submodule — [jraleman/dolces_adventure](https://github.com/jraleman/dolces_adventure) |
| `lazer_nfc` | submodule — [jraleman/lazer_nfc](https://github.com/jraleman/lazer_nfc) |
| `puppy_kraft` | submodule — [jraleman/puppy_kraft](https://github.com/jraleman/puppy_kraft) |
| `sailor_man` | submodule — [jraleman/sailor_man](https://github.com/jraleman/sailor_man) |
| `tifo_beato` | submodule — [jraleman/tifo_beato](https://github.com/jraleman/tifo_beato) |
| `desk_can_saw` | this repository |
| `triangle_rush` | this repository |

Every game owns its own assets, including any instructions walkthrough clip at
`godot-base/games/<id>/assets/video/tutorial.ogv`. A game can instead ship a
poster and written instructions, as Creep Code and Cube Trials do. `godot-base/assets/` holds
only the shared UI audio and images. A change that spans a submodule and the
host is therefore two commits: one inside the game repository, then the updated
gitlink here.

See [`AGENTS.md`](AGENTS.md) for the framework/game boundary and
[`SHARE_IMAGE_DESIGN.md`](SHARE_IMAGE_DESIGN.md) for the share-card contract.
