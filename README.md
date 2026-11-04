# DCS Base Game

The Godot project lives in [`godot-base`](godot-base).

## Cloning

Seventeen of the nineteen game folders under `godot-base/games/` are Git submodules,
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
| `baloos_chase` | submodule — [jraleman/baloos_chase](https://github.com/jraleman/baloos_chase) |
| `capitans_walk` | submodule — [jraleman/capitans_walk](https://github.com/jraleman/capitans_walk) |
| `chicken_pit` | submodule — [jraleman/chicken_pit](https://github.com/jraleman/chicken_pit) |
| `creep_code` | submodule — [jraleman/creep_code](https://github.com/jraleman/creep_code) |
| `cube_trials` | submodule — [jraleman/cube_trials](https://github.com/jraleman/cube_trials) |
| `dead_metal_jam` | submodule — [jraleman/dead_metal_jam](https://github.com/jraleman/dead_metal_jam) |
| `dolces_adventure` | submodule — [jraleman/dolces_adventure](https://github.com/jraleman/dolces_adventure) |
| `florida_men` | submodule — [jraleman/florida_men](https://github.com/jraleman/florida_men) |
| `lazer_nfc` | submodule — [jraleman/lazer_nfc](https://github.com/jraleman/lazer_nfc) |
| `puppy_kraft` | submodule — [jraleman/puppy_kraft](https://github.com/jraleman/puppy_kraft) |
| `rastro` | submodule — [jraleman/rastro](https://github.com/jraleman/rastro) |
| `sailor_man` | submodule — [jraleman/sailor_man](https://github.com/jraleman/sailor_man) |
| `tifo_beato` | submodule — [jraleman/tifo_beato](https://github.com/jraleman/tifo_beato) |
| `tuki-tuki_agents` | submodule — [jraleman/tuki-tuki_agents](https://github.com/jraleman/tuki-tuki_agents) |
| `yacomio` | submodule — [jraleman/yacomio](https://github.com/jraleman/yacomio) |
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
