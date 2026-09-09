"""Measure where the cards of a narrated intro should turn over.

Chicken Pit's opening shows a card per sentence of its narration, and each card
is due at an absolute offset into the recording (`cue_times` in
`games/chicken_pit/intro.gd`). Those offsets are measured from the recording's
own pauses so a card never turns over mid-word — which means replacing the clip
means measuring it again. This is the tool that does it.

    python tools/measure_intro_cues.py <audio> <transcript.txt>

`<transcript.txt>` is one card per line, in the order it is spoken; blank lines
are ignored. The output is the GDScript array to paste into `cue_times`.

How it works: ffmpeg decodes the audio to mono PCM, the script finds every
pause, estimates where each card would start if the speaker never changed pace,
then assigns the boundaries to real pauses in order — closest fit first, with a
bias toward longer pauses and a floor on how briefly a card may be up. Cards are
merged when the recording leaves no room to read them.

Development-only; ffmpeg must be on PATH. Keep out of export presets.
"""

from __future__ import annotations

import array
import subprocess
import sys
import tempfile
from pathlib import Path

RATE = 8000
WIN = 0.01  # 10 ms analysis window
MIN_CARD = 2.6  # must match MIN_CARD_SECONDS in the intro script
MIN_GAP = 0.15  # shortest pause worth turning a card in
MAX_DRIFT = 2.8  # how far a cue may sit from the even-pace estimate


def envelope(audio: Path) -> list[float]:
    """Peak amplitude per analysis window, 0..1."""
    with tempfile.TemporaryDirectory() as work:
        raw_path = Path(work) / "narration.raw"
        subprocess.run(
            ["ffmpeg", "-hide_banner", "-loglevel", "error", "-y", "-i", str(audio),
             "-ac", "1", "-ar", str(RATE), "-f", "s16le", str(raw_path)],
            check=True,
        )
        samples = array.array("h")
        samples.frombytes(raw_path.read_bytes())
    if sys.byteorder == "big":
        samples.byteswap()

    step = int(RATE * WIN)
    return [
        max(abs(v) for v in samples[i : i + step]) / 32768.0
        for i in range(0, len(samples) - step, step)
    ]


def segment(env: list[float]) -> tuple[float, float, list[tuple[float, float]]]:
    """Return where speech starts and ends, and every pause between."""
    ordered = sorted(env)
    threshold = ordered[int(len(ordered) * 0.90)] * 0.25

    runs: list[tuple[bool, float, float]] = []
    state, start = env[0] > threshold, 0
    for i, value in enumerate(env):
        now = value > threshold
        if now != state:
            runs.append((state, start * WIN, i * WIN))
            state, start = now, i
    runs.append((state, start * WIN, len(env) * WIN))

    voiced = [r for r in runs if r[0]]
    if not voiced:
        raise SystemExit("no speech found in the recording")
    speech_start, speech_end = voiced[0][1], voiced[-1][2]
    gaps = [
        ((a + b) / 2.0, b - a)
        for on, a, b in runs
        if not on and b - a >= MIN_GAP and a > speech_start and b < speech_end
    ]
    return speech_start, speech_end, gaps


def solve(cards, speech_start, speech_end, gaps):
    """Assign each card after the first to a pause, in order, or None."""
    span = speech_end - speech_start
    per_char = span / sum(len(c) for c in cards)
    estimate, cursor = [], speech_start
    for card in cards:
        estimate.append(cursor)
        cursor += len(card) * per_char
    targets = estimate[1:]

    inf = float("inf")
    best = [[inf] * (len(gaps) + 1) for _ in range(len(targets) + 1)]
    back = [[-1] * (len(gaps) + 1) for _ in range(len(targets) + 1)]
    best[0][0] = 0.0
    for i in range(len(targets)):
        for j in range(len(gaps) + 1):
            if best[i][j] == inf:
                continue
            previous = gaps[j - 1][0] if j else speech_start
            for k in range(j, len(gaps)):
                mid, length = gaps[k]
                if mid - previous < MIN_CARD:
                    continue
                drift = abs(mid - targets[i])
                if drift > MAX_DRIFT:
                    continue
                # A longer pause is a more convincing place to turn the card.
                cost = best[i][j] + drift * drift - min(length, 0.9) * 1.5
                if cost < best[i + 1][k + 1]:
                    best[i + 1][k + 1], back[i + 1][k + 1] = cost, j

    row = best[len(targets)]
    feasible = [
        j for j in range(len(gaps) + 1)
        if row[j] < inf
        and speech_end - (gaps[j - 1][0] if j else speech_start) >= MIN_CARD
    ]
    if not feasible:
        return None
    end = min(feasible, key=lambda j: row[j])

    chosen, i, j = [], len(targets), end
    while i > 0:
        chosen.append(gaps[j - 1][0])
        j = back[i][j]
        i -= 1
    chosen.reverse()
    return [speech_start] + chosen, estimate


def main() -> None:
    if len(sys.argv) != 3:
        raise SystemExit(__doc__)
    audio, transcript = Path(sys.argv[1]), Path(sys.argv[2])

    cards = [
        line.strip()
        for line in transcript.read_text(encoding="utf-8").splitlines()
        if line.strip()
    ]
    if len(cards) < 2:
        raise SystemExit("the transcript needs at least two cards")

    speech_start, speech_end, gaps = segment(envelope(audio))
    print(
        f"speech {speech_start:.2f} -> {speech_end:.2f}s, "
        f"{len(gaps)} pauses of {MIN_GAP}s or more"
    )

    result = solve(cards, speech_start, speech_end, gaps)
    while result is None and len(cards) > 3:
        # Merge the pair whose combined text is shortest — the two the
        # recording is least likely to have left room for.
        at = min(range(len(cards) - 1), key=lambda i: len(cards[i]) + len(cards[i + 1]))
        cards[at : at + 2] = [cards[at] + "\n" + cards[at + 1]]
        result = solve(cards, speech_start, speech_end, gaps)
    if result is None:
        raise SystemExit("could not fit the transcript to the recording")

    cues, estimate = result
    print(f"\n{len(cards)} cards:\n")
    for i, (cue, card) in enumerate(zip(cues, cards)):
        stop = cues[i + 1] if i + 1 < len(cues) else speech_end
        drift = cue - estimate[i]
        flat = card.replace("\n", " / ")
        print(f"{cue:6.2f}  ({stop - cue:4.1f}s, {drift:+.2f} vs even pace)  {flat[:60]}")

    print("\n@export var cue_times: Array[float] = [")
    for row in range(0, len(cues), 6):
        print("\t" + ", ".join(f"{c:.2f}" for c in cues[row : row + 6]) + ",")
    print("]")
    if any("\n" in card for card in cards):
        print("\nSome cards were merged; copy the text above into `cards` as well.")


if __name__ == "__main__":
    main()
