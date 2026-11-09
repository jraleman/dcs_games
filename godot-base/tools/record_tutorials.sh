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
    "florida_men", "rastro",
)
POSTER_TIMES = {
    "triangle_rush": "6.2", "desk_can_saw": "10.8", "dead_metal_jam": "13.4",
    "chicken_pit": "9.0", "anti_chess": "9.8", "anti_chess_local": "9.8",
    "lazer_nfc": "5.0", "anti_checkers": "12.6", "creep_code": "5.2",
    "cube_trials": "7.0", "sailor_man": "8.5", "tifo_beato": "22.0",
    "tuki_tuki": "7.0", "tuki_tuki_local": "7.0", "yacomio": "8.0",
    "florida_men": "15.8", "rastro": "8.0",
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

    godot = executable(args.godot)
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

                run_tool([
                    ffmpeg, "-y", "-hide_banner", "-loglevel", "error",
                    "-ss", POSTER_TIMES.get(key, "6.0"), "-i", str(ogv),
                    "-frames:v", "1", "-vf", "scale=640:360:flags=lanczos",
                    "-c:v", "libwebp", "-quality", "82", str(poster),
                ], environment)
                assert_output(poster)
                target.mkdir(parents=True, exist_ok=True)
                shutil.move(str(ogv), str(target / f"tutorial{suffix}.ogv"))
                shutil.move(
                    str(poster), str(target / f"tutorial{suffix}_poster.webp"),
                )
                avi.unlink()
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
