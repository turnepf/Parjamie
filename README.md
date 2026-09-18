# Parjamie

A two-player cross-and-circle race game for iPhone, iPad and Mac, themed as a welding shop.

**[Get it on the App Store](https://apps.apple.com/app/parjamie/id6812052207)** — free, no ads, no
accounts, no data collected.

Race four welding helmets a side out of their bay, once around a diamond-plate steel track
and up the home column. Shelter on the safe squares, weld two helmets into a blockade
nobody can pass, and throw sparks by sending an opponent back to the start. It plays by the
rules of [Pachisi](https://en.wikipedia.org/wiki/Pachisi), the traditional cross-and-circle
race game that originated in India, with two dice.

## Playing

- **Two devices** — one hosts, the other joins over the local network. No internet, no accounts.
- **One device** — pass the phone back and forth, both names on the board.
- **Vs the computer** — Sparky is still learning; Torch is a seasoned pro.

Turn hints, a How to play guide, and a House rules screen with ten optional rule changes
(entry number, exact or bounce home, the three-doubles penalty, capture and home bonuses,
blockades, quick start, must capture, shuffled safe spots). The host's rules decide the game.

## How it is put together

Three pieces, with the rules kept well away from the interface:

| Module | What it does |
|---|---|
| `Sources/ParjamieEngine` | The board, the rules, the scoreboard and the computer opponent. Pure value types and pure functions — no UI, no networking, no clock. |
| `Sources/ParjamieNet` | Bonjour discovery, the framed TCP link, and `MatchSession`, which owns the match. |
| `App/Sources` | SwiftUI. Draws the board and the welding shop, and reads its state from `MatchSession`. |

**The host owns the game.** It holds the only dice cup and the only authority to change
state; a guest asks for a roll or a move and redraws from the snapshot it gets back. Every
requested move is re-checked against `Rules.legalMoves` on the host before it is applied, so
the two boards cannot disagree and a guest cannot play an illegal move. Snapshots carry a
version and only ever move forward, so a late arrival never rewinds the board.

Messages travel behind a four-byte length header, since TCP is a stream rather than a
sequence of messages. `MessageFraming.Parser` reassembles them.

## Building

Needs Xcode with an Apple developer account signed in, and
[XcodeGen](https://github.com/yonaskolb/XcodeGen) (`brew install xcodegen`).

```sh
swift test        # the engine and framing tests, no Xcode project needed
xcodegen generate # rebuild Parjamie.xcodeproj from project.yml
```

`Parjamie.xcodeproj` is generated. Change `project.yml` rather than the project file, then
regenerate. One bundle ID, `net.parjamie.game`, covers iPhone, iPad and Mac (Catalyst) as a
universal purchase.

## Releasing

```sh
scripts/testflight.sh
```

Bumps the build number, regenerates the project, runs the tests, then archives and uploads
both the iOS and Mac builds. Builds reach the internal testing group once Apple finishes
processing. Submitting for review is a separate, deliberate step in App Store Connect.

`scripts/app-store-screenshots.sh` stages the App Store screenshot scenes.

## What's where

| Path | What |
|---|---|
| `App/` | The SwiftUI app, its assets, sounds and `Info.plist` |
| `Sources/` | The two Swift packages, `ParjamieEngine` and `ParjamieNet` |
| `Tests/` | 72 tests: rules, board geometry, house rules, hints, scoreboard, framing, naming |
| `docs/` | The support and privacy pages served at [turnepf.github.io/Parjamie](https://turnepf.github.io/Parjamie/), plus the App Store listing text |
| `scripts/` | TestFlight upload, screenshot staging, export options |
| `project.yml` | XcodeGen input — the real project definition |
| `CLAUDE.md` | The two standing rules for this project: the naming rule and the welding shop theme |

## Naming

`Tests/ParjamieEngineTests/NamingTests.swift` fails the build if the trademarked name of a
modern commercial game in this family turns up anywhere in the project — code, comments,
tests, docs or the project file. It stores SHA-256 fingerprints rather than the words
themselves, so no such spelling is in this repository. Write Pachisi, "the race home", or
"cross-and-circle game" instead.

## License

MIT. See [LICENSE](LICENSE).
