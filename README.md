# Screwcraft

A calm, original screw-sorting puzzle for portrait phones, built with **Godot 4.7.2 Standard / typed GDScript**. Remove colorful screws from illustrated wooden pieces, pack matching orders, and reveal a little workshop keepsake.

The finite campaign contains **1,000 distinct, stored levels**, each with geometry, a fixed order queue, and a winning replay verified through the actual gameplay reducer. These are generated and validated designs; they have not been individually human playtested.

## Play

Open `project.godot` in **Godot 4.7.2** and press **F5**. There are no third-party Godot plugins or online runtime dependencies.

Prepared builds are in:

- `builds/android/Screwcraft-debug.apk` — Android 7.0+ / API 24, ARM64 and x86_64, development-signed.
- `builds/linux/Screwcraft.x86_64` — Linux desktop executable.
- `builds/web/` — complete WebGL export; serve this directory through HTTP.

On the prepared cloud machine:

```bash
./tools/godot.sh --path .             # run the game with a graphical display
./tools/godot.sh --editor --path .    # edit the project
```

To install the exact engine and matching export templates on a fresh Linux machine:

```bash
python3 tools/setup_toolchain.py --android
./tools/godot.sh --headless --editor --path . --import
./tools/run_tests.sh
./tools/export.sh --android
```

Python 3.11+, HTTPS access to the official Godot releases, and a writable tool directory are required by the installer. Android export also needs Java 21. The default tool directory is `/workspace/.tools`; override `SCREWCRAFT_TOOL_ROOT` for another machine. The installer verifies publisher checksums and keeps TLS verification enabled. See [platform notes](docs/QA.md).

## How it plays

- Tap an exposed screw. Matching screws go directly into one of two active three-screw boxes.
- Other colors wait in five buffer spaces. They automatically transfer when a matching box arrives.
- Clear every screw from a piece to reveal the layer beneath it. Full storage still allows direct matches.
- Undo restores an entire move, including automatic cascades. Hints verify a winning continuation from the current position.
- Blueprint reveals the layered arrangement without changing it. The full fixed order queue is always inspectable.
- A first clear earns one collection stamp and 20 cosmetic coins. Five clears complete a chapter; finishes cost 100 coins. Replays never duplicate rewards.

Every puzzle is freely selectable from the shelf. There are no lives, countdowns, ads, purchases, accounts, or required network connection. Color symbols are always visible. Sound, music, vibration, and reduced motion are individually configurable.

Desktop shortcuts: **U** undo, **H** hint, **B** Blueprint, **Esc** settings/back. Touch and mouse controls share the same rules.

## Implementation

| Area | Location |
| --- | --- |
| Immutable reducer, invariants, bounded solver | `scripts/core/puzzle_reducer.gd` |
| Session, whole-move undo, verified hints | `scripts/session/game_session.gd` |
| A/B checksummed saves and reward ledger | `scripts/services/save_service.gd` |
| Portrait shell, navigation, settings, progression | `scripts/ui/app.gd` |
| Original procedural wooden board and symbols | `scripts/ui/board_view.gd`, `scripts/ui/craft_draw.gd` |
| Complete campaign and geometry catalogue | `content/levels/campaign.json`, `content/art_catalog.json` |
| Reproducible level generation | `tools/generate_campaign.py` |
| Original synthesized sound and bundled fonts | `assets/audio/`, `assets/fonts/` |
| Supplied reference documents and fixture | `docs/reference/` |

Logical moves commit and save before animation begins. The solver calls the same reducer as gameplay. Limited searches return `UNKNOWN_LIMIT`; a legal move alone is never advertised as a winning hint. Local saves retain settled attempts and undo history, preserve permanent progress across content changes, and recover from an invalid A/B slot.

## Validation and limits

Run `./tools/run_tests.sh` for the golden fixture, every campaign witness, random alternative choices, persistence, UI lifecycle, audio, Blueprint geometry, and negative geometry controls. Reports are generated in `builds/reports/`. Optional rendered browser checks use `node tools/web_smoke.cjs` with Playwright, Chromium, and a locally served Web export.

See [QA evidence](docs/QA.md), [level authoring](docs/LEVEL_AUTHORING.md), [design decisions](docs/DESIGN.md), [shared contracts](docs/CONTRACTS.md), and [asset provenance](assets/ASSET_MANIFEST.md).

Rendered captures: [first puzzle](docs/screenshots/gameplay.png), [level 1,000](docs/screenshots/level-1000.png), [workshop](docs/screenshots/workshop.png), and [360px touch viewport](docs/screenshots/phone.png).

Android APK integrity, desktop execution, and browser interactions are tested. **No physical Android phone was attached**, so hardware performance, haptics, cutouts, and Android suspension still need device testing. The catalogue needs human difficulty and enjoyment testing before a production release. The APK uses a development certificate; store publishing and release signing remain owner-controlled.

Existing cloud checkouts are already isolated. Use this checkout directly rather than creating an additional worktree for ordinary development.
