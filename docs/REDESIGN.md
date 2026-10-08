# Toybox Workshop visual redesign

Screwcraft is now a cheerful toy-making adventure with original illustrations,
chunky dimensional controls, glossy layered puzzles and coordinated menus.
The user's colorful casual-game direction supersedes the original muted
workshop styling. These changes are implemented in the playable Godot project.

## World and palette

**Pip**, an original golden fox-like maker with plum ear tips, a pink forelock
and aqua overalls, welcomes players and celebrates their progress. The illustrated
village uses rounded toy houses, winding paths, oversized spools and playful tools.
The home, winding Toybox Trail, collectible cabinet, paint shop and victory screen
share that world. Detailed scenery stays outside the active puzzle surface.

| Role | Color |
| --- | --- |
| Primary actions | Pink `#ED4F9A` |
| Secondary actions | Aqua `#28C9D4` |
| Structure and trim | Purple `#8452DB` |
| Text and outlines | Deep ink `#36235F` |
| Rewards and highlights | Warm yellow `#FFCE57` |
| Light surfaces | White `#FFF9FF` and lavender `#EEE8FF` |

Lilita One provides friendly display lettering; Nunito Regular and ExtraBold
keep labels and instructions readable. Buttons have extruded edges, glints,
soft shadows and visible press travel. The two active destinations are molded
carry cases with handles and screw sockets, distinct from the smaller previews.
An enamel toy tray and a calm lavender mat frame the lacquered puzzle pieces.

Logical screw identities retain their symbols: red/circle, blue/diamond,
green/triangle, yellow/star, purple/square and teal/bars. The four saved finish IDs
map to Honey Pop, Berry Jam, Strawberry Fizz and Aqua Splash, preserving existing
purchases while updating their appearance.

## Feedback and progression

Screws turn and fly into their destination; cleared pieces release with a bounce.
Box completions flash, and the reward screen combines Pip's celebration pose,
confetti, the actual first-clear reward and chapter progress. Reduced motion
suppresses large flights and confetti while retaining the same information.

Original synthesized rubbery pops, gentle ratchets, bouncy releases, box sparkles
and a short victory fanfare reinforce those events. An optional marimba-and-bell
loop stays quiet. Sound and music remain independently configurable.

All 1,000 puzzles remain freely selectable on the paged Toybox Trail. The cabinet
shows collectible toys, and the paint shop uses illustrated paint bottles.
Undo, hints, Blueprint and the fixed order queue remain free and available.

## Review and fixes

The development team split illustration, board rendering, world navigation,
typography/audio and QA into specialist tasks. Review used the actual game scene
and exported Web runtime. Screenshots and reproducible commands are documented
in [QA.md](QA.md).

The review resulted in these fixes:

- Hold the previous HUD arrangement during screw flight so its destination stays
  visible until the screw lands. Logical state still commits and saves first.
- Retain illustration textures so the world remains visible after drawing.
- Shorten tutorial captions for small screens and give Home a clear PLAY action.
- Add Pip and a matching tip to short queue views.
- Separate paint bottles from purchase buttons and give trail nodes stronger
  color, depth and completion states.
- Use expanded window stretching and a matching background around the centered
  portrait layout, eliminating black bars on taller phone and tablet windows.

The reducer, campaign definitions, stable save IDs and first-clear reward ledger
are unchanged. The full automated campaign, persistence and UI regression suites
continue to pass. Rendered viewport review is separate from physical Android
and human enjoyment testing, which remain outstanding.

Artwork and font provenance are recorded in
[the asset manifest](../assets/ASSET_MANIFEST.md). Generated artwork is original;
no competitor artwork is included.
