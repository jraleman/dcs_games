#!/usr/bin/env bash
# Linux/macOS counterpart of capture_screens.ps1; needs Python 3.10+ and Godot.
set -euo pipefail
script_dir="$(cd -- "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
exec "${PYTHON:-python3}" - "$script_dir/.." "$@" <<'PY'
from __future__ import annotations

import argparse
from datetime import datetime
import os
from pathlib import Path
import re
import shutil
import signal
import subprocess
import sys
import tempfile
import time


PROJECT = Path(sys.argv.pop(1)).resolve()
CAPTURE_SCRIPT = "res://tools/capture_screens.gd"
PROFILE_MARKER = ".dcs_capture_profile"
KILL_GRACE_SECONDS = 120


def run_godot(
    executable: str, arguments: list[str], profile: Path, seconds: int,
) -> int:
    environment = os.environ.copy()
    environment.update(
        HOME=str(profile), APPDATA=str(profile), XDG_DATA_HOME=str(profile),
    )
    process = subprocess.Popen(
        [executable, *arguments], env=environment, start_new_session=True,
    )
    try:
        try:
            return process.wait(timeout=seconds)
        except subprocess.TimeoutExpired:
            return -1
    finally:
        if process.poll() is None:
            try:
                os.killpg(process.pid, signal.SIGKILL)
            except ProcessLookupError:
                pass
            process.wait()


def new_profile(work: Path, name: str) -> Path:
    profile = work / f"profile-{name}"
    profile.mkdir()
    (profile / PROFILE_MARKER).touch()
    return profile


def main() -> int:
    parser = argparse.ArgumentParser(
        description="Capture standalone and collection screens in private profiles.",
    )
    parser.add_argument("--godot", default=os.environ.get("GODOT") or "godot")
    parser.add_argument("--games", nargs="+", default=[])
    parser.add_argument("--skip-collection", action="store_true")
    parser.add_argument("--resolution", default="1280x720")
    parser.add_argument("--output-dir", type=Path)
    parser.add_argument("--no-scroll-pages", action="store_true")
    parser.add_argument("--timeout-seconds", type=int, default=900)
    args = parser.parse_args()
    if re.fullmatch(r"[1-9]\d*x[1-9]\d*", args.resolution) is None:
        parser.error("--resolution must be WIDTHxHEIGHT with positive dimensions")
    if not 60 <= args.timeout_seconds <= 86400:
        parser.error("--timeout-seconds must be between 60 and 86400")
    godot = shutil.which(os.path.expanduser(args.godot))
    if godot is None:
        raise FileNotFoundError(f"Cannot run '{args.godot}'; pass --godot PATH.")
    output = args.output_dir or (
        PROJECT / "build" / "screenshots" / datetime.now().strftime("%Y%m%d-%H%M%S")
    )
    output = output.expanduser().resolve()

    with tempfile.TemporaryDirectory(prefix="dcs_screen_capture_") as temporary:
        work = Path(temporary)
        game_list = work / "games.txt"
        code = run_godot(godot, [
            "--headless", "--path", str(PROJECT), "--script", CAPTURE_SCRIPT,
            "--", "--game=all", f"--capture-list={game_list}",
        ], new_profile(work, "discovery"), 300)
        if code != 0 or not game_list.is_file():
            raise RuntimeError(f"Could not list the games (Godot exit code {code}).")
        known = [
            value.strip() for value in game_list.read_text().splitlines()
            if value.strip()
        ]
        if not known:
            raise RuntimeError("The catalog found no games.")
        selected = {
            item.strip().casefold()
            for value in args.games for item in value.split(",") if item.strip()
        }
        unknown = selected - {game.casefold() for game in known}
        if unknown:
            parser.error(f"Unknown game id(s): {', '.join(sorted(unknown))}. "
                         f"Known: {', '.join(known)}")
        games = [
            game for game in known if not selected or game.casefold() in selected
        ]

        logs = output / "logs"
        logs.mkdir(parents=True, exist_ok=True)
        (output / ".gdignore").touch()
        runs = [(game, game) for game in games]
        if not args.skip_collection:
            runs.append(("collection", "all"))
        results = []
        for name, selector in runs:
            run_dir = output / name
            log = logs / f"{name}.log"
            profile = new_profile(work, name)
            arguments = [
                "--path", str(PROJECT), "--resolution", args.resolution,
                "--log-file", str(log), "--script", CAPTURE_SCRIPT, "--",
                f"--game={selector}", f"--capture-out={run_dir}",
                f"--capture-profile={profile}",
                f"--capture-size={args.resolution}",
                f"--capture-timeout={args.timeout_seconds}",
            ]
            if args.no_scroll_pages:
                arguments.append("--no-scroll-pages")
            print(f"Capturing {name} ...", flush=True)
            started = time.monotonic()
            code = run_godot(
                godot, arguments, profile,
                args.timeout_seconds + KILL_GRACE_SECONDS,
            )
            minutes = (time.monotonic() - started) / 60
            screens = len(list(run_dir.glob("*.png")))
            index = run_dir / "screens.txt"
            warnings = sum(
                line.startswith("# warning:")
                for line in index.read_text().splitlines()
            ) if index.is_file() else 0
            if code == -1:
                print(f"WARNING: {name} did not quit in time and was stopped; "
                      f"see {log}.", file=sys.stderr)
            elif code != 0:
                print(f"WARNING: {name} ended with exit code {code}; "
                      f"see {index} and {log}.", file=sys.stderr)
            else:
                print(f"  -> {screens} screens in {minutes:.1f} min, "
                      f"{warnings} warnings", flush=True)
            results.append((name, code, screens, warnings, minutes))

        print("\nRun                  ExitCode Screens Warnings Minutes")
        for name, code, screens, warnings, minutes in results:
            print(f"{name:20} {code:8} {screens:7} {warnings:8} {minutes:7.1f}")
        print(f"Screenshots are in {output}")
        return 1 if any(result[1] != 0 for result in results) else 0


try:
    sys.exit(main())
except (OSError, RuntimeError) as error:
    print(f"Screenshot capture failed: {error}", file=sys.stderr)
    sys.exit(1)
except KeyboardInterrupt:
    print("Screenshot capture interrupted.", file=sys.stderr)
    sys.exit(130)
PY
