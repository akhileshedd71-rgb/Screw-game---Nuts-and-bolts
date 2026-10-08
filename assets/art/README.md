# Original vector craft kit

The editable art masters are `scripts/ui/craft_draw.gd` and `scripts/ui/board_view.gd`. They render directly through Godot CanvasItem drawing commands, so there are no baked image exports or external illustration dependencies. All illustrations and materials were made for this project. Revision: 1.

| Stable asset | Master | Logical dimensions | Pivot / attachment area |
|---|---|---|---|
| `screw_red_circle`, `screw_blue_diamond`, `screw_green_triangle`, `screw_yellow_star`, `screw_purple_square`, `screw_teal_bars` | `CraftDraw.screw` | 48 × 48 default, scalable | Center; 24 radius visible head |
| Same six identity symbols | `CraftDraw.symbol` | 20 × 20 default, scalable | Center; permanent identity palette |
| `socket` | `CraftDraw.socket` | 42 × 42 default | Center |
| `ui_home`, `ui_undo`, `ui_hint`, `ui_blueprint`, `ui_settings`, `ui_close`, `ui_check`, `ui_next`, `ui_back`, `ui_lock`, `ui_sound`, `ui_coin` | `CraftDraw.icon` | 56 × 56 default, scalable | Center |
| `stamp_flower`, `stamp_sailboat`, `stamp_bird`, `stamp_windmill`, `stamp_butterfly`, `stamp_house`, `stamp_lantern`, `stamp_signpost`, `stamp_star`, `stamp_tree`, `stamp_fish`, `stamp_keepsake` | `CraftDraw.motif` | 200 × 200 at scale 100 | Center |
| `board_beech` | `BoardView._draw_backing` | 640 × 600 | Upper left; quiet play area inset 24 |
| `plate_material_0` through `plate_material_3` | `BoardView._draw_plate` | Definition polygon | Polygon coordinates authoritative; generated grain cached per plate |
| `hole` | `BoardView._draw_hole` | 20 × 20 | Original fastener center |
| `hint_ring`, `lift_spark`, `plate_release` | `BoardView` | Runtime animation | Center / plate polygon centroid |
| `app_icon` | `assets/art/icon.svg` | 512 × 512; PNG exports at 192 and 512 | Center; crossed beech planks, red circle and blue diamond |
| `adaptive_foreground`, `adaptive_background` | Matching SVG masters in this directory | 432 × 432 PNG | Foreground inset to Android safe center; sage background |

Plate footprints and screw attachment centers come from each immutable level's `polygon` and `position` fields. Bevels inset the authoritative footprint by 3.5 logical units. Shadows are cosmetic and never used for hit testing or blocker checks. The beech, walnut, rose, and sage cosmetic palettes preserve the six identity colors.

The blueprint separates coincident screws for inspection, draws their original attachment tethers and dashed blocker relationships, and never accepts a game move. Reduced motion removes extraction/release motion and makes hint emphasis static.

All source is resolution-independent and editable. UI uses antialiased vector edges and no texture atlases. Physical phone target-size verification is recorded separately from desktop screenshots.

Re-export app icons with Inkscape, for example:

```sh
inkscape assets/art/icon.svg --export-type=png --export-filename=assets/art/icon_192.png --export-width=192 --export-height=192
inkscape assets/art/icon.svg --export-type=png --export-filename=assets/art/icon_512.png --export-width=512 --export-height=512
inkscape assets/art/adaptive_foreground.svg --export-type=png --export-filename=assets/art/adaptive_foreground.png --export-width=432 --export-height=432
inkscape assets/art/adaptive_background.svg --export-type=png --export-filename=assets/art/adaptive_background.png --export-width=432 --export-height=432
```

Board selection uses the nearest eligible center within 48 logical units. This gives a 48 dp target diameter when 720 logical units occupy 360 dp. Overlapping eligible regions are resolved by nearest center; physical-device ergonomics still need validation. The optional external flight presenter lets the application animate directly to a matching order or buffer while the board retains its independent plate release input gate.
