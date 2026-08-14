# Just Shikaku

An iPhone app that teaches you to play Shikaku, the rectangle puzzle: divide
the grid into rectangles so each one holds exactly one number, and that number
is its area.

Website and privacy policy: <https://kaikunze.de/justshikaku/>

## What is in here

| Directory | Purpose |
|---|---|
| `Shikaku/App` | @main, navigation, home, stats, settings |
| `Shikaku/Engine` | pure Swift: candidate enumeration, the seven-technique logical solver, uniqueness backtracker, puzzle generator |
| `Shikaku/Game` | the board, the drag-to-draw gesture, the play screen |
| `Shikaku/Teaching` | hint ladder, drawn arguments, rules tutorial, lessons, drills, mastery |
| `Shikaku/Design` | theme (the tatami room), motion tokens, haptics |
| `Shikaku/Store` | the one-time unlock |
| `ShikakuTests` | Swift Testing suite |
| `Tools/EngineCheck` | CLI harness: differential candidate tests, generation properties, difficulty calibration — runs in seconds without a simulator |
| `AppStore` | screenshots driver, metadata, IAP art, submission runbook |
| `docs` | rules, techniques, teaching, architecture, engineering notes |

## Engine notes

Every shipped puzzle is provably unique and fully solvable by the taught
technique ladder; both proofs run inside `generate()` before a board is ever
returned. The harness compiles the engine as a CLI
(`swiftc -O -o /tmp/enginecheck Shikaku/Engine/*.swift Tools/EngineCheck/*.swift`)
and replays about 2,400 checks, including candidate enumeration verified
against brute force.
