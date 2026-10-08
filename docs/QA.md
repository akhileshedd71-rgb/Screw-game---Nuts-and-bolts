# Verification and platform notes

The implementation is tested with **Godot 4.7.2 Standard**, official build `ed1daf0bf`, and matching official export templates. Both downloaded archives were checked against the official release's SHA512 manifest over verified HTTPS. No network request is required during play.

## Reproduce

From the repository root:

```bash
python3 tools/setup_toolchain.py --android  # only needed to install/refresh tools
./tools/run_tests.sh
./tools/export.sh --android
```

The toolchain installs in `/workspace/.tools`; override `SCREWCRAFT_TOOL_ROOT` if needed. `tools/godot.sh` provides writable XDG directories and selects the pinned engine. `GODOT_BIN` can select an existing engine, but use 4.7.2 for matching exports. Existing checkouts are already isolated: do not create an extra Git worktree for normal development.

Desktop development needs Godot only. Exporting Android also requires Java 21 (the prepared machine has `/usr/lib/jvm/java-21-openjdk-amd64`). `JAVA_HOME` and `ANDROID_HOME` override local paths. `tools/configure_android.py` writes local Godot editor paths and standard debug signing settings; production signing keys are not part of this project. Android tools are verified using Google's repository metadata before extraction. Current standard APK packaging uses SDK Build Tools 36.0.0 and does not need a Gradle build or external plugins.

## Executed automated checks

| Check | Result |
| --- | --- |
| Production reducer and supplied golden fixture | 1,007 cases, 67,338 assertions, 20,418 accepted transitions; zero failures |
| Entire finite campaign | All 1,000 definitions valid, all stored routes reach WON using the production Godot reducer, conservation checked after every move |
| Difficulty metadata | Measured settled peak buffer occupancy equals stored witness metadata for all 1,000 routes |
| Random alternative fixture choices | 500 seeded runs, 5,170 transitions; 334 wins and 166 correctly settled stuck outcomes; invariants preserved |
| Persistence/session | 97 checks covering A/B recovery, corruption/truncation, future schema protection, stale writers, resume, whole-transaction undo, hints, reward deduplication, cosmetics and settings |
| Actual App UI navigation and lifecycle | 80 assertions in five groups: modal ownership, terminal recovery, replay, pause/resume, Back, rapid tap gating and STUCK Blueprint |
| Audio resources and service | Imported WAV/font assets, six-voice bound, event coalescing, independent toggles, pause/resume, music loop and buses |
| Geometry and quotas | All 1,000 levels pass; exact first-30 brief inventories retained |
| Board inspection geometry | All 1,000 Blueprint layouts expose 20,385 identities without overlaps; model hashes unchanged |
| Geometry negative controls | Four deliberate defects rejected: off-board anchor, missing visual blocker, overlapping exposed targets, wrong color quota |
| Native Linux exported build | Started the packaged executable headlessly for 120 frames without engine errors |
| Android APK integrity | APK signing schemes v2/v3, 16KB native-page ZIP alignment, package identity and VIBRATE permission verified |
| Rendered browser interaction | Seven checks pass with zero engine/browser errors: actual pointer/touch input, visual Undo restoration, persisted move after runtime reload, and result controls after Collection → Workshop → Continue |

Browser checks ran in Chromium with software WebGL at 720×1280 and a 360×800 mobile viewport using actual touch events. Screenshots include the first puzzle, victory, collection, workshop, level two, catalogue page 40, level 1,000, Blueprint, and settings. `node tools/web_smoke.cjs` reproduces this against a served Web export; `builds/reports/web-smoke.json` records the outcome. Viewport emulation is not physical-device testing.

The fixture tests compare the supplied independent golden states, including FIFO order, full buffer with a legal direct match, a double cascade, wrong fork into STUCK, recovery, and terminal victory. They also check pure reducer inputs, duplicate command rejection, invalid content, canonical buffer ordering, honest solver budget exhaustion, and replay of a solver-generated continuation from the current state. JSON numeric types are normalized for golden comparisons; screw/container order remains significant.

Campaign replay results are generated at `builds/reports/reducer.json`; level geometry results are in `docs/LEVEL_VALIDATION.json`. There are 1,000 unique content hashes and 606 topology descriptors. A descriptor count is not a graph-isomorphism proof or evidence of human enjoyment. Difficulty metadata records a known route's peak buffer occupancy, not minimum required capacity.

## Build outputs

- `builds/android/Screwcraft-debug.apk`: installable Android debug build, package `org.screwcraft.puzzle`, version 0.1.0, ARM64 and x86_64. Minimum Android API 24; target API 36.
- `builds/linux/Screwcraft.x86_64`: Linux x86_64 executable with embedded game resources.
- `builds/web/index.html` plus neighboring files: WebGL build using the non-threaded template. Serve the whole directory through HTTP; opening the HTML as a local file is unsupported. Raw campaign JSON is explicitly included in every export.

`builds/Screwcraft-linux.zip` and `builds/Screwcraft-web.zip` bundle the current exports; `builds/SHA256SUMS` records artifact hashes.

Generated builds, reports and local signing material are excluded from version control. The APK uses a standard development certificate and is intended for testing; store publication requires the owner's release signing configuration.

## Remaining physical and human validation

No physical Android phone was attached. Desktop/browser screenshots and software rendering cannot establish phone frame pacing, thermals, safe-area behavior across cutouts, tactile haptics, speaker mix, app suspension by Android, or touch comfort at actual device scale. Verify those on representative phones before declaring device support. No human usability or campaign pacing study has been completed. The 1,000 stored levels are generated, geometrically validated, and replay validated; they are not individually human playtested.

Suggested device session: play levels 1–10 without explanation; inspect level 8's Undo recovery and full buffer direct match; suspend during a screw flight, relaunch, and verify one settled move; complete and replay a level to check one reward; turn reduced motion and audio/haptics toggles on/off; inspect portrait phones and tablets; exercise Android Back; and confirm long-session temperature and frame pacing.
