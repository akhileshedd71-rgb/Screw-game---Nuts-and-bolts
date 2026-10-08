# Finite campaign authoring and validation

The campaign contains **1,000 complete levels** in `content/levels/campaign.json`.
The app never invents a puzzle at runtime. Each level has a stable campaign ID,
revision, fixed order queue, complete plate and screw geometry, explicit blockers,
color identities, a reference solution, and a SHA-256 content hash.

The first three levels are deliberately sparse tutorial templates. Level 8
preserves the supplied two-green-caps fixture's exact graph and queue, with new
geometry that expresses those relationships. Every one of the first 30 levels
preserves its brief's exact per-color inventory; other geometric and difficulty
briefs remain design intentions, rather than a claim that all proposed learning
outcomes have been demonstrated in a playtest.

## Construction

Run `python3 tools/generate_campaign.py` to reproduce the checked-in catalogue.
It uses a stable per-level Python random seed, bounded geometric families, and a
constructive winning sequence; it does not accept arbitrary random boards.

1. Choose the level's fixed color inventory, order queue and difficulty rhythm.
2. Allocate fasteners to one to four layers of nonintersecting plate groups.
3. Place bevelled wooden plates with readable targets; nested layers leave an
   edge visible. Derive every logical blocker directly from the geometry.
4. Choose an exposed screw-removal order from the resulting access graph.
5. Assign colors along that order using a conservation-aware routing simulation.
   Temporary buffer pressure follows the level's warm-up, practice, variation,
   challenge or recovery role. The simulation respects oldest-box priority,
   immediate replacement, and eligible FIFO buffer transfers.
6. Store the complete definition and witness. Independently replay the result
   through the actual Godot reducer before accepting the campaign.

Twelve visual families accompany the campaign: flower, sailboat, bird, windmill,
butterfly, house, lantern, signpost, star, tree, fish and keepsake. Family drawings
are presentation; explicit plate blockers decide access. Difficulty varies order
queues, mixed-color ownership, access dependencies, repeats and buffer pressure.
It does not only increase screw count. Five-level groups include recovery boards.

## Measured checks

`python3 tools/validate_geometry.py` writes `docs/LEVEL_VALIDATION.json` and checks:

- Exactly 1,000 stable IDs, complete inventories and exactly one owner per screw.
- Three screws per ordered box, for each color separately.
- Full head containment with at least 28 logical pixels to the owner's edge.
- Every visually covering plate is exactly a declared blocker; no head is partly
  covered by another plate, including plates on its own layer.
- Potentially simultaneous exposed centers are at least 58 logical pixels apart.
- Target centers fit the 640 × 600 reference board's safe bounds.
- Every move in every reference route is geometrically exposed.
- Checked-in content hashes and the first 30 exact brief inventories.

`tests/test_reducer.gd` performs the separate, authoritative test: all 1,000
reference routes run through `PuzzleReducer`, each accepted transaction satisfies
state invariants, and each final state must be WON. The supplied fixture also
checks its stuck fork, recovery and full-buffer direct match behavior.

The catalogue currently contains 20,385 screws, 6–30 per level, across one to four
layers. There are 606 distinct coarse topology descriptors; this counts sorted
layer/ownership/blocker-degree profiles, **not** a graph-isomorphism proof. The
reference routes have measured settled peak buffer occupancy from zero to four.
These are witness-path peaks, not proven minimum required capacity.

## Review boundaries

These are algorithmically constructed and machine-validated levels, not a claim
of 1,000 individually human-authored or human-playtested puzzles. Geometry checks
cannot establish fun, phone readability, perceived difficulty or comfortable
thumb use. Those require human playtests and physical Android review. The shipping
catalogue records `human_playtest_verified: false` and
`phone_readability_verified: false` explicitly rather than inventing evidence.

Designers can replace any definition while preserving its stable campaign ID and
incrementing revision; rerun both validators after editing. Avoid changing the
classic rules to rescue a difficult puzzle. Reauthor the queue, colors or access
graph instead, and keep a new proven no-purchase witness.
