# Screwcraft: design decisions and review guide

This is an original, offline toy-making puzzle for portrait phones. The player's
job is to reveal a playful creation by sorting exposed screws into color and
symbol matched toolboxes. Cheerful illustrations and tactile feedback support
a relaxed pace with room to experiment and recover. Enjoyment remains a
playtesting question.

## Authority and scope

The attached specification supplies the initial rules and visual direction. The
user's later instruction to build at least **1,000 levels** replaces its 30-level
release scope. `CONTRACTS.md` records the actual implementation contracts. Level
definitions include a witnessed solution; generated content must be described as
generated content, with validation evidence kept separate from human review.

The current campaign uses the classic rule set throughout. A level count does
not establish 1,000 distinct strategic lessons, 1,000 unique illustrations, or
1,000 human playtests. The reusable piece kit and fixed motifs make this content
volume feasible. More obstacle systems should wait for basic comprehension and
device testing.

The initial generated catalog contains 20,385 screws across twelve craft families,
with 6–30 screws and 1–4 layers per level. Its 606 distinct topology descriptors
are production descriptors, not proof of 606 graph-isomorphism classes. The
first three boards use bespoke sparse tutorial templates. Level 8 preserves the
supplied twelve-screw fixture's blocker graph and routing problem. The first
thirty match the supplied briefs' color inventories. See `LEVEL_VALIDATION.json`
and the production reducer replay results for machine validation.

Winning witnesses reach settled buffer occupancies of zero in 3 levels, one in
202, two in 400, three in 213, and four in 182. These are observed witness maxima,
not proven minimum buffer requirements or measured difficulty. Difficulty tags
express the intended warm-up/practice/variation/challenge/recovery rhythm and
should be checked with players before being treated as a calibrated rating.

## The decisions that make a puzzle

Two boxes accept three screws apiece. Five buffer spaces hold other colors.
Two previews and the entire inspectable queue let a player plan ahead. A direct
box match remains legal with five screws already buffered. Box replacement and
FIFO buffer transfers finish before the game checks for a win or no legal moves.
This distinction needs especially clear feedback; a full buffer is not a loss.

Depth communicates access. A screw's explicit blockers decide whether it is
available, and a piece clears when its last attached screw leaves. Visual overlap
must agree with those relationships. Animation decorates a committed move; it
cannot unlock a screw or change the destination.

Free Undo restores a whole move including all automatic transfers. A solver hint
is a proven continuation from the current position; an unavailable hint is
reported honestly. Blueprint and queue inspection cost nothing. These tools are
part of the learning loop, not scarce resources.

## Onboarding and pacing targets

Start at the first puzzle and teach through short contextual sentences. The
catalog introduces matching in level 1, plate clearance in level 2, using the
buffer in level 3, automatic transfers in level 4, and queue inspection in level
5. Blueprint and Undo/full-buffer routing arrive in levels 7 and 8. Keep the first
exposed choices sparse. The lesson tags establish intent; the actual opening
still needs observation with new players to establish what they understand.

| Situation | Suggested language |
| --- | --- |
| First puzzle | Match screws to their boxes. |
| A screw waits | It waits here until its box arrives. |
| Covered target | Remove the piece above first. |
| Five buffered screws | Buffer full. Ready box matches still work. |
| No legal moves | No moves available. Undo or start again. |
| Search limit | Hint unavailable right now. Try Blueprint or Undo. |
| Previously completed puzzle | Complete again, just for the pleasure of it. |

Opening lessons should take roughly 20–45 seconds, early puzzles 1–2.5 minutes,
and later challenges 2–4 minutes. These are hypotheses rather than measurements.
Longer levels should add a planning choice or an interesting reveal, not simply
more repeated tapping. Interleave a demanding board with a clearer, more open
composition. A later campaign of generated variants needs sampled human review
to find repetition, narrow forced sequences, and accidental difficulty spikes.

## Visual and interaction language

The Toybox Workshop redesign replaces the original muted workshop style with
an illustrated toy-making adventure. Pip is an original golden fox-like maker
with a pink forelock and aqua overalls. Bright pink, aqua, purple and warm yellow
coordinate the toy village, carry-case destinations, lacquered pieces, dimensional
buttons, paint shop and celebrations. A pearl-lavender mat keeps the gameplay
area calm. Color is always paired with a symbol: red circle, blue diamond,
green triangle, yellow star, purple square, and teal bars. Stable color IDs and
symbols retain their rule meaning through every cosmetic finish.

Lilita One provides friendly chunky headings; Nunito Regular and ExtraBold
handle instructions, counters and controls. All three fonts ship with licenses.
Active toolboxes are larger and stronger than previews. Occupied holding spaces
remain distinguishable from vacancies. The illustrated home, winding trail,
collectible cabinet, paint-bottle shop and reward screen share the same world.

At 720 × 1280 logical units, a 360 dp-wide display halves the logical dimensions.
Consequently, a 64-unit diameter is only 32 dp. Board picking uses a 48-unit
radius and nearest-exposed-target disambiguation; major controls use 96 logical
units. Physical phone review is still needed to establish actual touch comfort.
Do not fix difficult taps by shrinking later screws or overlapping tap regions.
Increase spacing, improve nearest-target selection, or recompose the board.

The first tap response should feel immediate. Decorative dust must not hold
input. Reduced motion should keep the same information with fades and short
transitions. One modal owns input, and closing it returns to the same state.

## Audio identity

All shipped sounds are original deterministic synthesis, with source in
`assets/audio/generate_audio.py`. Rubbery button pops, gentle ratcheting turns,
bouncy releases and box sparkles make the toy world tactile. Three small
variations per common action avoid exact repetition without wild pitch changes.
Pip's victory fanfare lasts 2.25 seconds. The optional 19.2-second original
marimba-and-bell loop is mixed quietly on its own Music bus.

`AudioService` has independent UI, SFX, and Music buses under Master. Sound and
music settings are independent. A six-voice pool and 70 ms event coalescing keep
cascades from becoming loud stacks. Pause stops transient voices and pauses the
ambience; resume respects the stored toggles. Audio has no model authority.
The masters are mono PCM16 at 48 kHz and have headroom; device-speaker audition
and interruption testing are still required.

## Rewards without pressure

A first clear earns 20 cosmetic coins once per stable level ID. A basic skin
costs 100 coins, so the first five clears afford one. Repeat clears preserve the
original reward; the result screen must not imply another grant. The mathematical
maximum for 1,000 unique first clears is 20,000 coins. A small initial skin set
will not absorb that full balance, and no larger economy is implied.

Album progress groups five distinct first clears into a milestone. Keep results
to one screen with a dominant Next action. Do not interrupt play with a wallet,
energy, timer, sale, or extra reward popup. Do not award stars for minimum taps:
every successful route removes the same screw inventory. Cosmetic ownership
must never gate the campaign, Undo, hints, or inspection.

## Review that remains necessary

Automated witnesses prove that an encoded puzzle can be solved. They do not prove
it is enjoyable, visually understandable, or easy to tap. Use fresh players on
phones for the first five lessons, and sample every content family and difficulty
band. Observe whether players can explain why a screw is blocked and why a full
buffer can still allow a move. Record confusion, voluntary retries, accidental
taps, and undo recovery. Treat session length as ambiguous, not proof of fun.

Physical-device checks should cover small and tall screens, a tablet, safe areas,
touch target size, system Back, background/resume, headphones and speakers,
mute toggles, reduced motion, and color/symbol recognition. Record what was
actually tried in `QA.md`; do not infer these results from a desktop screenshot.
