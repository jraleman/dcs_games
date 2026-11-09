"""Exercise Unix tool entry points without Godot, speech tools or real saves."""

from __future__ import annotations

import json
import os
from pathlib import Path
import shutil
import subprocess
import sys
import tempfile
import time
import unittest
import wave


PROJECT = Path(__file__).resolve().parents[2]
SCRIPTS = (
    "tools/record_tutorials.sh",
    "tools/capture_screens.sh",
    "games/tifo_beato/tools/validate.sh",
    "games/lazer_nfc/tools/bake_voice.sh",
)
MOCK_TOOL = r'''#!/usr/bin/env python3
from array import array
import json
import math
import os
from pathlib import Path
import sys
import time
import wave

args = sys.argv[1:]
tool = Path(sys.argv[0]).name.split()[0]

def option(name):
    for index, argument in enumerate(args):
        if argument == name:
            return args[index + 1]
        if argument.startswith(name + "="):
            return argument[len(name) + 1:]
    return None

step = "run"
if tool == "godot":
    step = "import" if "--import" in args else "capture"
    if option("--script") and not option("--capture-out"):
        step = option("--script").rsplit("/", 1)[-1]
    if "--import" in args:
        step = "import"
elif tool == "ffmpeg":
    step = "poster" if "-frames:v" in args else "encode"
record = {
    "tool": tool, "arguments": args,
    "HOME": os.environ["HOME"],
    "APPDATA": os.environ.get("APPDATA"),
    "XDG_DATA_HOME": os.environ.get("XDG_DATA_HOME"),
    "marker": (Path(os.environ["HOME"]) / ".dcs_capture_profile").is_file(),
}
if option("--path"):
    project = Path(option("--path")) / "project.godot"
    record["project"] = project.read_text() if project.is_file() else ""
with open(os.environ["MOCK_LOG"], "a") as log:
    log.write(json.dumps(record) + "\n")
if os.environ.get("MOCK_FAIL") == f"{tool}:{step}":
    print("Requested mock tool failure.", file=sys.stderr)
    sys.exit(7)
if os.environ.get("MOCK_HANG") == step:
    time.sleep(30)
if os.environ.get("MOCK_ERROR") == step:
    print("SCRIPT ERROR: Requested engine diagnostic.", file=sys.stderr)
if step == "saves_test.gd":
    print("ERROR: ConfigFile parse error at user://saves_test_backups_123/"
          "triangle_rush/unreadable.cfg:0: Unexpected EOF while parsing simple tag.",
          file=sys.stderr)

if tool == "godot":
    if option("--write-movie"):
        Path(option("--write-movie")).write_bytes(b"movie")
    if option("--capture-list"):
        Path(option("--capture-list")).write_text("triangle_rush\ntuki_tuki\n")
    if option("--capture-out"):
        output = Path(option("--capture-out"))
        output.mkdir(parents=True)
        (output / "001_main_menu.png").write_bytes(b"frame")
        (output / "screens.txt").write_text(
            "001_main_menu.png\tmain_menu.tscn\n# warning: mock warning\n")
        Path(option("--log-file")).write_text("mock Godot log\n")
elif tool == "espeak":
    frequency = 330 * int(os.environ.get("MOCK_VOICE_VARIANT", "1"))
    samples = array("h", (
        round(12000 * math.sin(2 * math.pi * frequency * frame / 22050))
        for frame in range(4410)
    ))
    with wave.open(option("-w"), "wb") as output:
        output.setnchannels(1)
        output.setsampwidth(2)
        output.setframerate(22050)
        output.writeframes(samples.tobytes())
elif tool == "ffmpeg":
    destination = Path(args[-1])
    if destination.suffix == ".wav":
        with wave.open(option("-i"), "rb") as source:
            samples = array("h", source.readframes(source.getnframes()))
        resampled = array("h", (value for sample in samples for value in (sample, sample)))
        with wave.open(str(destination), "wb") as output:
            output.setnchannels(int(option("-ac")))
            output.setsampwidth(2)
            output.setframerate(int(option("-ar")))
            output.writeframes(resampled.tobytes())
    else:
        destination.write_bytes(b"encoded media")
'''


@unittest.skipUnless(os.name == "posix", "Run with Python on Linux/macOS.")
class ShellScriptsTest(unittest.TestCase):
    def setUp(self) -> None:
        self.temporary = tempfile.TemporaryDirectory(prefix="dcs shell scripts ")
        self.addCleanup(self.temporary.cleanup)
        self.root = Path(self.temporary.name)
        self.project = self.root / "project with spaces"
        for folder in (
            "assets", "autoload", "games", "scenes", "scripts", "tests",
            "third_party", "tools", "ui",
        ):
            (self.project / folder).mkdir(parents=True)
        for name in ("default_bus_layout.tres", "icon.svg", "export_presets.cfg"):
            (self.project / name).write_text("fixture\n")
        (self.project / "project.godot").write_text(
            '[application]\n'
            'config/custom_user_dir_name="DeskCanSaw Games/DCS Base Game"\n'
            '[gui]\ntheme/custom="res://ui/theme/dcs_theme.tres"\n',
        )
        (self.project / "tests" / "saves_test.gd").touch()
        for relative in (*SCRIPTS, "games/lazer_nfc/tools/bake_colors.py"):
            destination = self.project / relative
            destination.parent.mkdir(parents=True, exist_ok=True)
            shutil.copy2(PROJECT / relative, destination)
        self.tools = self.root / "executables with spaces"
        self.tools.mkdir()
        for name in ("godot", "ffmpeg", "espeak"):
            tool = self.tools / f"{name} stub"
            tool.write_text(MOCK_TOOL)
            tool.chmod(0o755)
        self.work = self.root / "temporary profiles"
        self.work.mkdir()
        self.log = self.root / "calls.jsonl"
        self.environment = os.environ.copy()
        self.environment.update(
            PYTHON=sys.executable, GODOT=str(self.tools / "godot stub"),
            TMPDIR=str(self.work), MOCK_LOG=str(self.log),
            HOME=str(self.root / "real home"),
        )

    def run_script(
        self, script: str, *arguments: str, **environment: str,
    ) -> subprocess.CompletedProcess[str]:
        return subprocess.run(
            ["bash", str(self.project / script), *arguments],
            cwd=self.root, env={**self.environment, **environment},
            text=True, stdout=subprocess.PIPE, stderr=subprocess.STDOUT,
            timeout=30,
        )

    def calls(self, tool: str) -> list[dict]:
        return [
            item for line in self.log.read_text().splitlines()
            if (item := json.loads(line))["tool"] == tool
        ]

    def assert_success(self, result: subprocess.CompletedProcess[str]) -> None:
        self.assertEqual(result.returncode, 0, result.stdout)

    def test_help_needs_no_external_tools(self) -> None:
        for script in SCRIPTS:
            with self.subTest(script=script):
                self.assert_success(self.run_script(script, "--help", GODOT="missing"))
        self.assertFalse(self.log.exists())

    def test_tutorial_variants_alias_and_explicit_quality(self) -> None:
        result = self.run_script(
            SCRIPTS[0], "--ffmpeg", str(self.tools / "ffmpeg stub"),
            "--games", "TUKI_TUKI,anti_chess,chicken_pit",
            "--variants", "local", "--quality", "9",
        )
        self.assert_success(result)
        for folder, suffix in (
            ("tuki-tuki_agents", "_local"), ("anti_chess", "_local"),
            ("chicken_pit", ""),
        ):
            bank = self.project / "games" / folder / "assets" / "video"
            self.assertTrue((bank / f"tutorial{suffix}.ogv").is_file())
            self.assertTrue((bank / f"tutorial{suffix}_poster.webp").is_file())
            self.assertFalse((bank / "tutorial_local_local.ogv").exists())
        for call in self.calls("ffmpeg"):
            arguments = call["arguments"]
            if "-q:v" in arguments:
                self.assertEqual(arguments[arguments.index("-q:v") + 1], "9")
        for call in self.calls("godot"):
            self.assertEqual(call["HOME"], call["XDG_DATA_HOME"])
            self.assertNotEqual(call["HOME"], self.environment["HOME"])
        self.assertEqual(list(self.work.iterdir()), [])

    def test_failed_poster_keeps_shipped_tutorial(self) -> None:
        video = self.project / "games/chicken_pit/assets/video"
        video.mkdir(parents=True)
        shipped = video / "tutorial.ogv"
        shipped.write_bytes(b"previous tutorial")
        result = self.run_script(
            SCRIPTS[0], "--ffmpeg", str(self.tools / "ffmpeg stub"),
            "--games", "chicken_pit", MOCK_FAIL="ffmpeg:poster",
        )
        self.assertNotEqual(result.returncode, 0)
        self.assertEqual(shipped.read_bytes(), b"previous tutorial")
        encode = self.calls("ffmpeg")[0]["arguments"]
        self.assertEqual(encode[encode.index("-q:v") + 1], "5")
        self.assertEqual(list(self.work.iterdir()), [])

    def test_screens_use_catalog_order_and_private_profiles(self) -> None:
        output = self.root / "screens with spaces"
        result = self.run_script(
            SCRIPTS[1], "--games", "TUKI_TUKI,triangle_rush,TRIANGLE_RUSH",
            "--output-dir", str(output), "--resolution", "640x360",
            "--no-scroll-pages",
        )
        self.assert_success(result)
        self.assertTrue((output / ".gdignore").is_file())
        captures = [
            call for call in self.calls("godot")
            if any(arg.startswith("--capture-out=") for arg in call["arguments"])
        ]
        self.assertEqual(len(captures), 3)
        for call, selector in zip(captures, ("triangle_rush", "tuki_tuki", "all")):
            self.assertIn(f"--game={selector}", call["arguments"])
            self.assertIn("--no-scroll-pages", call["arguments"])
            self.assertIn("--capture-size=640x360", call["arguments"])
            self.assertTrue(call["marker"])
            self.assertEqual(call["HOME"], call["APPDATA"])
            self.assertEqual(call["HOME"], call["XDG_DATA_HOME"])
            self.assertFalse(Path(call["HOME"]).exists())
        self.assertEqual(list(self.work.iterdir()), [])

    def test_screens_reject_unknown_games_and_report_engine_failure(self) -> None:
        output = self.root / "screens"
        result = self.run_script(
            SCRIPTS[1], "--games", "unknown", "--output-dir", str(output),
        )
        self.assertNotEqual(result.returncode, 0)
        self.assertIn("Unknown game", result.stdout)
        self.assertFalse(output.exists())
        result = self.run_script(
            SCRIPTS[1], "--games", "triangle_rush", "--skip-collection",
            "--output-dir", str(output), MOCK_FAIL="godot:capture",
        )
        self.assertNotEqual(result.returncode, 0)
        self.assertIn("exit code 7", result.stdout)
        self.assertEqual(list(self.work.iterdir()), [])

    def test_validation_checks_diagnostics_and_keeps_reports(self) -> None:
        result = self.run_script(
            SCRIPTS[2], "--suites", "sound,model", "--framework", "--window",
            MOCK_ERROR="model_test.gd",
        )
        self.assertNotEqual(result.returncode, 0)
        workspace, = self.work.glob("tifo_beato_validation_*")
        report = json.loads((workspace / "logs/results.json").read_text())
        results = {item["Name"]: item for item in report}
        self.assertTrue(results["import"]["Passed"])
        self.assertFalse(results["tifo_model"]["Passed"])
        self.assertEqual(results["tifo_model"]["ExitCode"], 0)
        self.assertTrue(results["saves_test"]["Passed"])
        self.assertTrue(results["curva_view"]["Passed"])
        self.assertTrue((workspace / "games").is_symlink())
        calls = self.calls("godot")
        self.assertIn('theme/custom=""', calls[0]["project"])
        self.assertIn('theme/custom="res://', calls[1]["project"])
        self.assertNotIn("--headless", calls[-1]["arguments"])
        for call in calls:
            self.assertEqual(call["HOME"], str(workspace / "user-data"))

    def test_validation_timeout_stops_the_child_and_keeps_logs(self) -> None:
        started = time.monotonic()
        result = self.run_script(
            SCRIPTS[2], "--suites", "sound", "--timeout-seconds", "1",
            MOCK_HANG="sound_test.gd",
        )
        self.assertNotEqual(result.returncode, 0)
        self.assertLess(time.monotonic() - started, 8)
        self.assertIn("exceeded 1 seconds", result.stdout)
        workspace, = self.work.glob("tifo_beato_validation_*")
        self.assertTrue((workspace / "logs/tifo_sound.stdout.log").is_file())

    def test_voice_finishing_and_read_only_reproducibility_check(self) -> None:
        destination = self.root / "voice preview"
        arguments = (
            "--espeak-ng", str(self.tools / "espeak stub"),
            "--ffmpeg", str(self.tools / "ffmpeg stub"),
            "--destination", str(destination),
        )
        self.assert_success(self.run_script(SCRIPTS[3], *arguments))
        for name in ("ready", "round_20", "number_1000", "bind_violet_dark"):
            with wave.open(str(destination / f"{name}.wav"), "rb") as voice:
                self.assertEqual(
                    (voice.getnchannels(), voice.getsampwidth(), voice.getframerate()),
                    (1, 2, 44100),
                )
                self.assertGreater(voice.getnframes(), 0)
        contents = {path.name: path.read_bytes() for path in destination.iterdir()}
        self.assert_success(self.run_script(SCRIPTS[3], *arguments, "--check"))
        result = self.run_script(
            SCRIPTS[3], *arguments, "--check", MOCK_VOICE_VARIANT="2",
        )
        self.assertNotEqual(result.returncode, 0)
        self.assertIn("non-reproducible WAV", result.stdout)
        self.assertEqual(
            contents, {path.name: path.read_bytes() for path in destination.iterdir()},
        )
        self.assertEqual(list(self.work.iterdir()), [])


if __name__ == "__main__":
    unittest.main()
