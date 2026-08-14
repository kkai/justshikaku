# Teaching

The product differentiator, modeled on Good Sudoku: detect what the player
knows, teach named techniques in context, remove busywork. The engine solves
alongside play; when the player is stuck it names the next technique *they*
need, on *their* board.

## The hint ladder

Four levels, strictly escalating; each tap of Hint climbs one rung. Errors are
checked first at every level — a hint about technique while the board holds a
wrong rectangle is a lie of omission.

1. **Nudge** — "There's a prime strip you can place." Names the technique
   family only. `focusCells` empty.
2. **Technique** — the technique's name and one-sentence rule, still no
   location. `focusCells` empty.
3. **Highlight** — the clue/cells involved light up. `showsArgument` becomes
   true: the drawn argument plays.
4. **Resolution** — the move itself, with Apply. Apply goes through
   `applyStep`, which also materialises claim marks, so elimination-only
   steps visibly do something.

Invariants (all family-tested):
- A withheld (paywalled) hint never calls `recordHint` — penalising mastery
  for a hint the player never saw poisons their progress the moment they pay.
- `HintPolicy.errorsOnly | .full` is the free/paid line (see MONETIZATION.md).
- `unaided` is the caller's to declare: `!appliedHint && game.claimMasteryCredit(at:)`.
- Mastery credit survives undo (place/undo/place ≡ fresh deduction).

## The drawn argument

`ArgumentOverlay` renders `ExplanationData` with a rectangle vocabulary,
staggered by `Motion.argumentStagger`:

- **T2/T3** — each eliminated candidate ghosts in faint and is struck with a
  diagonal slash in sequence; the survivor pulses, then settles.
- **T4** — all live candidates layer in translucent; where they all overlap,
  opacity accumulates and the claimed cells burn in; foreign candidates
  through those cells strike out.
- **T5** — spotlight the cell; other clues' failed reaches ghost in
  struck-through; the lone reacher's candidates ghost in clean.
- **T6** — the offending candidate ghosts in; the cell it would strand
  flashes with a no-reacher mark; the candidate strikes out.
- **T7** — `RegionOutline` draws the corridor; area figures appear as a short
  count ("room of 7 — best fits total 5"); the candidate strikes out.
- **Resolution** — the rectangle draws itself with an animated stroke starting
  at the clue's corner (deterministic start vertex, the family lesson).

Eliminations strike **specific ghost rectangles**, never a generic wash — the
player must see *which* placements died (the family learned this as
"strike the candidate glyphs, not a bar across the cell").

## Tutorial and lessons

- **Rules tutorial** — interactive, on a hand-authored 5×5: draw your first
  mat, see the area rule, finish a tiny board. Free, complete, skippable
  ("Skip, I know Shikaku").
- **Technique lessons** — one per technique, on hand-authored boards where
  that technique is the only available move. `TutorialScript` DSL; boards in
  `TutorialPuzzles.swift`; premise pinned by `TutorialFixtureTests` (if
  detector precedence changes and a lesson board stops exercising its
  technique, a test says so — not a player).
- **Practice drills** — timed runs of a single technique.
  `bakedBoardsThatDemonstrateTheirTechnique` records which baked boards
  actually exercise what they claim, surfaced in code, not hidden behind a
  test exemption.
- **Mastery** — per technique: seen → practiced → learned (unaided uses).
  Mastery-locked rows are `.disabled`; paywalled rows stay tappable and
  present the paywall.

## Copy

Every player-facing string — nudges, rules, details, resolutions, tutorial
script, lesson copy, paywall blurbs — lives in `TechniqueContent.swift`. The
engine never holds a string; every context-dependent branch degrades to
`rule(for:)` rather than emitting a sentence with a hole. The humanizer pass
runs over this one file (plus Settings/Stats/Paywall copy) before ship.

Voice: plain, warm, second person, no exclamation marks, no gamification
slang. The app explains like a good teacher at a kitchen table, not a coach
on a stage.
