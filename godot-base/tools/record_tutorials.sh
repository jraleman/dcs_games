#!/usr/bin/env bash
# Linux/macOS counterpart of record_tutorials.ps1; needs Python 3.10+, Godot and ffmpeg.
set -euo pipefail
script_dir="$(cd -- "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
exec "${PYTHON:-python3}" - "$script_dir/.." "$@" <<'PY'
from __future__ import annotations

import argparse
import os
from pathlib import Path
import shutil
import signal
import subprocess
import sys
import tempfile


PROJECT = Path(sys.argv.pop(1)).resolve()
GAMES = (
    "triangle_rush", "desk_can_saw", "dead_metal_jam", "chicken_pit",
    "anti_chess", "lazer_nfc", "anti_checkers", "creep_code", "cube_trials",
    "dolces_adventure", "sailor_man", "tifo_beato", "tuki_tuki", "yacomio",
    "florida_men", "rastro", "capitans_walk", "puppy_kraft", "baloos_chase", "asmr_doctor",
)
# Seconds, uniform crop scale, left and top; match record_tutorials.ps1.
POSTER_FRAMES = {
    "triangle_rush": ("19.3", "0.64", "0.23", "0.08"),
    "desk_can_saw": ("6.0", "0.65", "0.16", "0.035"),
    "dead_metal_jam": ("7.5", "0.70", "0.12", "0.055"),
    "chicken_pit": ("7.0", "0.74", "0.13", "0.035"),
    "anti_chess": ("8.8", "0.73", "0.135", "0.025"),
    "anti_chess_local": ("8.1", "0.72", "0.14", "0.035"),
    "lazer_nfc": ("4.3", "0.60", "0.20", "0.045"),
    "anti_checkers": ("7.3", "0.70", "0.15", "0.035"),
    "creep_code": ("24.3", "0.60", "0.20", "0.055"),
    "cube_trials": ("18.8", "0.72", "0.12", "0.035"),
    "dolces_adventure": ("14.1", "0.62", "0.13", "0.115"),
    "sailor_man": ("12.2", "0.64", "0.18", "0.115"),
    "tifo_beato": ("42.3", "0.70", "0.13", "0.035"),
    "tuki_tuki": ("20.9", "0.60", "0.20", "0.155"),
    "tuki_tuki_local": ("20.9", "0.60", "0.20", "0.155"),
    "yacomio": ("44.3", "0.52", "0.04", "0.18"),
    "florida_men": ("161.7", "0.68", "0.16", "0.055"),
    "rastro": ("12.9", "0.63", "0.015", "0.04"),
    "capitans_walk": ("9.1", "0.68", "0.085", "0.08"),
    "puppy_kraft": ("34.5", "0.60", "0.045", "0.145"),
    "baloos_chase": ("5.5", "0.38", "0.32", "0.14"),
    "asmr_doctor": ("10.0", "0.49", "0.07", "0.18"),
}
QUALITIES = {
    "chicken_pit": 5, "lazer_nfc": 5, "anti_checkers": 6,
    "creep_code": 5, "cube_trials": 5, "rastro": 5,
}


def executable(value: str) -> str:
    found = shutil.which(os.path.expanduser(value))
    if found is None:
        raise FileNotFoundError(f"Cannot run '{value}'; supply an executable path.")
    return found


def selections(values: list[str]) -> list[str]:
    return list(dict.fromkeys(
        item.strip().lower()
        for value in values for item in value.split(",") if item.strip()
    ))


def run_tool(arguments: list[str], environment: dict[str, str]) -> None:
    process = subprocess.Popen(
        arguments, env=environment, start_new_session=True,
    )
    try:
        code = process.wait()
    finally:
        if process.poll() is None:
            try:
                os.killpg(process.pid, signal.SIGKILL)
            except ProcessLookupError:
                pass
            process.wait()
    if code != 0:
        raise subprocess.CalledProcessError(code, arguments)


def assert_output(path: Path) -> None:
    if not path.is_file() or path.stat().st_size == 0:
        raise RuntimeError(f"The tool did not create a nonempty file at '{path}'.")


def main() -> None:
    parser = argparse.ArgumentParser(
        description="Record tutorials and posters without touching player saves.",
    )
    parser.add_argument("--godot", default=os.environ.get("GODOT") or "godot")
    parser.add_argument("--ffmpeg", default="ffmpeg")
    parser.add_argument("--fps", type=int, default=30)
    parser.add_argument("--capture-resolution", default="1280x720")
    parser.add_argument("--output-scale", default="960:540")
    parser.add_argument("--quality", type=int)
    parser.add_argument("--posters-only", action="store_true",
                        help="Refresh stills from existing videos; Godot is not needed.")
    parser.add_argument("--games", nargs="+", default=list(GAMES))
    parser.add_argument("--variants", nargs="+", default=["solo", "local"])
    args = parser.parse_args()
    games = selections(args.games)
    variants = selections(args.variants)
    if not games or any(game not in GAMES for game in games):
        parser.error(f"--games must select from: {', '.join(GAMES)}")
    if not variants or any(value not in ("solo", "local") for value in variants):
        parser.error("--variants must select solo, local, or both")
    if args.fps <= 0:
        parser.error("--fps must be positive")
    if args.quality is not None and not 0 <= args.quality <= 10:
        parser.error("--quality must be between 0 and 10")

    godot = executable(args.godot) if not args.posters_only else None
    ffmpeg = executable(args.ffmpeg)
    with tempfile.TemporaryDirectory(prefix="dcs_tutorial_capture_") as temporary:
        work = Path(temporary)
        profile = work / "user-data"
        profile.mkdir()
        environment = os.environ.copy()
        # macOS uses HOME; Linux uses XDG_DATA_HOME. Only children adopt them.
        environment.update(
            HOME=str(profile), APPDATA=str(profile), XDG_DATA_HOME=str(profile),
        )
        for game in games:
            folder = "tuki-tuki_agents" if game == "tuki_tuki" else game
            target = PROJECT / "games" / folder / "assets" / "video"
            dual_variant = game in ("anti_chess", "tuki_tuki")
            for variant in variants if dual_variant else [None]:
                suffix = "_local" if variant == "local" else ""
                key = game + suffix
                label = f"{game} ({variant})" if variant is not None else game
                avi = work / f"tutorial_{key}.avi"
                ogv = work / f"tutorial_{key}.ogv"
                poster = work / f"tutorial_{key}_poster.webp"
                quality = args.quality
                if quality is None:
                    quality = 7 if dual_variant else QUALITIES.get(game, 7)

                if args.posters_only:
                    ogv = target / f"tutorial{suffix}.ogv"
                    assert_output(ogv)
                else:
                    print(f"Recording {label} ...", flush=True)
                    arguments = [
                        godot, "--path", str(PROJECT),
                        "--resolution", args.capture_resolution,
                        "--fixed-fps", str(args.fps), "--write-movie", str(avi),
                        "res://tools/tutorial_capture.tscn", "++", f"--game={game}",
                    ]
                    if variant is not None:
                        arguments.append(f"--tutorial-variant={variant}")
                    run_tool(arguments, environment)
                    assert_output(avi)

                    print(f"Encoding {label} ...", flush=True)
                    run_tool([
                        ffmpeg, "-y", "-hide_banner", "-loglevel", "error",
                        "-i", str(avi), "-an",
                        "-vf", f"scale={args.output_scale}:flags=lanczos",
                        "-r", str(args.fps), "-c:v", "libtheora",
                        "-q:v", str(quality), str(ogv),
                    ], environment)
                    assert_output(ogv)
                    print(f"  -> tutorial{suffix}.ogv "
                          f"({ogv.stat().st_size / (1024 * 1024):.2f} MB)", flush=True)

                at, scale, left, top = POSTER_FRAMES[key]
                print(f"Poster for {label} ...", flush=True)
                run_tool([
                    ffmpeg, "-y", "-hide_banner", "-loglevel", "error",
                    "-ss", at, "-i", str(ogv), "-frames:v", "1",
                    "-vf", (f"crop=iw*{scale}:ih*{scale}:iw*{left}:ih*{top},"
                            "scale=960:540:flags=lanczos"),
                    "-c:v", "libwebp", "-quality", "90", str(poster),
                ], environment)
                assert_output(poster)
                target.mkdir(parents=True, exist_ok=True)
                if not args.posters_only:
                    shutil.move(str(ogv), str(target / f"tutorial{suffix}.ogv"))
                    avi.unlink()
                shutil.move(
                    str(poster), str(target / f"tutorial{suffix}_poster.webp"),
                )
                print(f"  -> tutorial{suffix}_poster.webp", flush=True)
    print("Done.")


try:
    main()
except (OSError, RuntimeError, subprocess.CalledProcessError) as error:
    print(f"Tutorial recording failed: {error}", file=sys.stderr)
    sys.exit(1)
except KeyboardInterrupt:
    print("Tutorial recording interrupted.", file=sys.stderr)
    sys.exit(130)
PY
