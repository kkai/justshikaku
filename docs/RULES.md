# Shikaku — the rules

Shikaku (四角に切れ, "divide by squares"), also published as Rectangles or Divide
by Box. Popularised by Nikoli; the reference implementation this app was checked
against is de.puzzle-shikaku.com.

## The puzzle

A rectangular grid. Some cells hold a number (a **clue**).

**Divide the entire grid into rectangles so that:**

1. Every rectangle contains **exactly one clue**.
2. Each rectangle's **area in cells equals its clue's number**.
3. Rectangles **never overlap**.
4. Every cell belongs to some rectangle — **no gaps**.

Squares count as rectangles. That is the whole rule set; everything else in the
game is technique.

## Terms used throughout the codebase

- **Clue** — a numbered cell. `Puzzle.clues`.
- **Mat** — a committed rectangle (the tatami metaphor runs through the UI;
  the engine says `PlacedRect`).
- **Candidate** — a legal rectangle for a clue: right area, in bounds, contains
  that clue and no other. Candidate enumeration is the engine's foundation
  (see `TECHNIQUES.md`).
- **Region** — a connected component of cells not yet covered by a mat.

## Sizes and tiers

| Size | Free? | Notes |
|---|---|---|
| 5×5 | free | tutorial + gentle play |
| 7×7 | free | the free tier's ceiling |
| 10×10 | paid | |
| 12×12 | paid | the phone ceiling (~27pt cells on a 375pt width); 15×15 deferred to an iPad release |

Difficulty tiers: **gentle / steady / sharp / deep / severe** (family naming).
Difficulty is **never** gated by tier — a free player can play severe on 7×7
(Kakuro's rule: gating difficulty punishes the players most likely to buy).

Every shipped puzzle has exactly one solution and is fully solvable by the
taught techniques — enforced in `ShikakuGenerator.generate`, which is what makes
the hint guarantee real.

## Naming hygiene

"Shikaku" is the generic puzzle name (Nikoli's trademark is on specific puzzle
collections, not the genre term, matching how the family handled "Kakuro").
Avoid "Nikoli" anywhere in the app or store listing.
