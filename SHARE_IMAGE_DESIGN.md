# Share Image Design Proposal

**Status:** Godot implementation complete; public score publishing pending  
**Scope:** Upgrade the game's generated result pictures and connect each picture to a public game-stats page.

## Objective

Create share pictures that feel like promotional game art rather than a generic
score dashboard. Each picture should:

- Make the result feel exciting and worth sharing.
- Encourage viewers to play and try to beat the displayed result.
- Show the game's name prominently.
- Display `deskcansaw.com` clearly.
- Include a reliable QR code that opens the shared run's public stats page.
- Work in both Godot desktop and web exports.
- Remain reusable across DeskCanSaw games while giving each game its own visual identity.

## Feasibility

The picture generator should remain in Godot. The project already has the
necessary foundation:

- `godot-base/autoload/share_manager.gd` renders a 1200 x 630 scene through a
  `SubViewport` and exports it as a PNG.
- `godot-base/ui/components/share_card.tscn` defines the existing score card.
- Desktop exports save pictures under `user://shares`.
- Web exports download the generated PNG.

Godot does not provide QR generation in its core API. A vetted, pure-GDScript QR
encoder can generate a Godot `Image` without native dependencies, which keeps
the feature compatible with desktop and web exports.

The remaining non-Godot component is the public score publishing and stats
page. Godot now accepts a configurable `stats_url`, creates its QR code, and
renders that code into the exported picture without requiring a networking
implementation.

## Visual Direction

### Core composition

Continue using a 1200 x 630 landscape image so the result works well in social
previews and messaging applications.

The composition should contain:

1. **Game identity:** A large game title and recognizable logo, not a small
   utility header.
2. **Challenge headline:** Result-aware copy such as
   `I scored 12,450 in Desk-Can-Saw - can you beat it?`
3. **Action artwork:** A game-specific hero scene occupying most of the card.
4. **Hero result:** One oversized score or versus result with strong contrast.
5. **Supporting stats:** At most three immediately understandable stats, such
   as accuracy, best combo, and hits.
6. **QR call to action:** A dedicated panel labeled
   `Scan to view this run and play`.
7. **Visible website:** `deskcansaw.com` displayed beside the QR code as a
   readable fallback, not hidden in fine-print footer text.

### Style

- Use dramatic diagonal composition, layered depth, bright accent lighting,
  impact shapes, sparks, trails, and controlled glow.
- Preserve enough empty space around the score and QR code for immediate
  readability.
- Use the winning player or game mode's accent color to personalize the card.
- Treat achievements as celebratory badges only when they strengthen the
  result story; do not let them compete with the score.
- Keep all important text readable when the picture is reduced to 600 x 315.

### Game-specific variants

**Desk-Can-Saw**

- Feature a diagonal chainsaw cutting through cans.
- Use sparks, split-can silhouettes, speed streaks, and the electric-yellow
  accent already present in the game.
- Place the score near the impact point so the action leads the eye toward it.

**Triangle Rush**

- Feature glowing targets moving through trails toward a highlighted active
  target.
- Use target geometry, player colors, and speed lines to communicate urgency.
- Present multiplayer scores as a clear head-to-head challenge.

Both variants should inherit from a shared branded card structure rather than
duplicating export, QR, and layout behavior.

## QR Code Design

The QR code should contain a short public URL:

```text
https://deskcansaw.com/stats/<short-id>
```

Requirements:

- Render at approximately 222 px in the 1200 x 630 source image
  (`ShareQrCode.DEFAULT_IMAGE_SIZE`).
- Use dark modules on a solid light background.
- Preserve a four-module quiet zone on every side.
- Use medium error correction and nearest-neighbor texture filtering. The
  shorter matrix proved more reliable after social-preview downscaling than a
  denser high-correction matrix.
- Do not place a logo over the QR modules.
- Keep the encoded URL short so the module grid remains easy to scan.
- Keep the URL at 42 UTF-8 bytes or less.
- Validate scanning after resizing and representative social-media compression.

If creation of the public stats record fails, the game must report the failure
and allow a retry. It must not generate a QR code pointing to a nonexistent
record.

## Public Stats Page

Each shared run should receive an immutable, public record. The page should show:

- Game title and mode.
- Result or winner.
- Score or multiplayer score line.
- Accuracy, hits, misses, and best combo where applicable.
- Earned achievements.
- Date of the run.
- A prominent **Play Now** action.
- Social metadata suitable for linking the same generated share picture.

The public record should contain game data only. It should not include local
paths, device information, or other personal data.

### Suggested API contract

```http
POST /api/shared-results
Content-Type: application/json
```

Example request:

```json
{
  "schema_version": 1,
  "game_id": "desk_can_saw",
  "game_title": "Desk-Can-Saw",
  "mode": "Solo",
  "result": "Round Complete",
  "scores": [12450],
  "accuracy": 92,
  "hits": 48,
  "misses": 4,
  "best_combo": 17,
  "achievements": ["Solo Starter"]
}
```

Example response:

```json
{
  "id": "Ab3kP9xQ",
  "stats_url": "https://deskcansaw.com/stats/Ab3kP9xQ"
}
```

The service should validate and bound all numeric and text fields, rate-limit
creation, generate non-sequential identifiers, and render unknown or expired
records as explicit not-found pages.

## Godot Data Flow

1. The round finishes and the game builds a raw, typed result payload.
2. The payload supplies either a published per-run `stats_url` or the configured
   short per-game route.
3. `ShareManager` validates the URL and generates its QR `ImageTexture`.
4. The texture and display payload are passed to the appropriate share-card
   scene.
5. `ShareManager` renders the card through its existing `SubViewport`.
6. The scorecard panel shows that rendered card inline, so the picture *is* the
   score summary the player reads.
7. **Save Image** re-renders and exports it through the existing desktop save or
   web download behavior.

When score publishing is connected, its only required handoff to this flow is
the immutable per-run `stats_url`. Invalid URLs and QR failures return explicit
errors through the current share status UI rather than silently substituting a
homepage link.

## Implemented Godot Changes

| Area | Implemented change |
|---|---|
| `godot-base/scripts/game_info.gd` | Added stable game IDs and centralized short stats URL configuration. |
| `godot-base/scripts/share_qr_code.gd` | Added URL validation and scan-safe QR `Image`/`ImageTexture` generation. |
| `godot-base/third_party/greaby_qrcode` | Vendored the MIT GDScript QR encoder needed by desktop and web exports. |
| `godot-base/autoload/share_manager.gd` | Validates the stats URL and supplies cards with the URL, website and QR texture. |
| Shared card scene | Added promotional score hierarchy, challenge copy, website and dedicated QR information panel. |
| Desk-Can-Saw card art | Added procedural chainsaw, can, spark and impact artwork. |
| Triangle Rush card art | Added procedural targets, trails, glows and urgency artwork. |
| Game payloads | Added stable IDs, short stats routes and raw numeric score fields for future publishing. |
| Tests | Added QR, URL, information-panel, card-fit and game-variant regression coverage. |

The card now adapts the existing procedural gameplay language into static
share-safe artwork, keeping each exported picture consistent with its game.

## Implementation Phases

1. **Completed - visual card:** Godot renders branded variants for representative
   solo, multiplayer and achievement results.
2. **Completed - QR integration:** The project generates and scan-tests short
   stats URLs entirely in GDScript.
3. **Pending - web companion:** Publish result records and public stats routes
   on `deskcansaw.com`.
4. **Pending - publisher wiring:** Replace each payload's per-game default URL
   with the immutable per-run URL returned by the publishing implementation.

## Fallback Architecture

If persistent public storage is not desired, the stats page could decode a
compact result payload embedded directly in the URL. That would allow a static
website and remove the result-creation API.

This is a secondary option because it:

- Produces longer, denser QR codes.
- Makes URLs less attractive when copied.
- Allows viewers to alter unsigned result data.
- Limits future additions such as leaderboards, moderation, and retention rules.

A short server-backed result ID is therefore the preferred architecture.

## Acceptance Criteria

- Every generated picture includes the correct game name.
- `deskcansaw.com` is plainly readable without scanning the QR code.
- The QR code opens the exact public stats record for the pictured run.
- The picture uses recognizable game action and reads as promotional artwork.
- The score or versus result is the dominant data element.
- The QR code scans from the original PNG and a 600 x 315 resized copy.
- Solo, multiplayer, long result text, and achievement combinations do not
  overflow or obscure the QR code.
- Desktop exports still save the PNG and can reopen the original.
- Web exports still download the PNG.
- The scorecard panel renders the card without writing a file.
- Network, API, QR, rendering, and save failures produce clear user-facing
  errors.
- No public stats record contains device or personal information.
