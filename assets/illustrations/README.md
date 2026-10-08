# Toybox Workshop illustration kit

Original artwork created for Screwcraft's October 2026 visual redesign with OpenAI image generation. The generation brief specified a cheerful toy-making world with pink, aqua, purple and warm yellow, original character designs, no text, no logos and no third-party character or game assets. The supplied competitor screenshots informed the broad quality target only; their artwork was not copied into these files.

| Asset | Dimensions / format | Intended use |
|---|---|---|
| `pip.png` | 1254 × 1254, RGBA PNG | Full-body original mascot: golden fox toy maker, plum ear tips, pink forelock, aqua overalls, purple screwdriver; menu and help companion. |
| `pip_victory.png` | 1254 × 1254, RGBA PNG | Same mascot celebrating with a golden star screw prize; victory and reward screens. |
| `toy_world.png` | 1024 × 1536, RGB PNG | Portrait toy village with screw architecture, colorful spools, winding golden path, calm sky and lavender plaza for UI overlays. Preserve aspect ratio; use cropping or cover fitting. |
| `../art/icon_toybox.png` | 1254 × 1254, RGB PNG | Square app icon: Pip holding glossy pink and aqua screws against purple. Godot may scale this source for platform exports. |

`pip_victory.png` and the app icon were generated using the original `pip.png` as the character reference to maintain a consistent identity. The village was generated from the same art direction. All images were visually inspected before integration. Both mascot files have real transparent backgrounds, not a baked transparency grid or black matte.

These are presentation-only assets. No game state, screw identity, selection target, blocker relationship or win condition is stored in an image. Critical text and navigation remain live Godot UI; no text or button art is baked into the village.

Generation source identifiers (for provenance, not runtime dependencies):

- Pip: `exec-d158fa29-30db-4ba7-8592-633fa88e2ff7.png`
- World: `exec-f1cf4714-89f5-4543-86a7-93244d453f61.png`
- Celebration: `exec-e7d750a3-bd2f-48e9-b2d7-aba52c555e6a.png`
- App icon: `exec-2c52a842-39d8-49ae-9072-a312869d40bf.png`

The complete images are included in the repository and work offline. No image generation service, network download or extra plugin is required to run the game.
