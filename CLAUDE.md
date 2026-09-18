# Parjamie

A two-player cross-and-circle race game for iPhone, installed directly from Xcode.

Parjamie is an implementation of **Pachisi**, the traditional cross-and-circle race
game that originated in India — <https://en.wikipedia.org/wiki/Pachisi>. Its rules are
centuries old and in the public domain: four pawns a side race out of the nest, once
around a cruciform track and up the home column, sheltering on safe squares, forming
blockades and sending opponents back on a capture.

## Rules for this project

- **Never use the trademarked names of the modern commercial games in this family**, or
  any close spelling of one. Those names belong to the companies that own them. This
  applies to on-screen text, the home screen name, the icon, code comments, test names,
  commit messages, and documentation. Name the real ancestor instead — Pachisi — or
  describe the game as "the race home" or a "cross-and-circle game".
  `Tests/ParjamieEngineTests/NamingTests.swift` fails if a forbidden spelling shows up
  in the project.
- **The look is a welding shop on the traditional cross-and-circle layout** (Jamie is a professional welder). Diamond-plate steel track, a weld bead around the cross, tack-weld crosses on violet heat-tint safe squares (a shield badge marks a helmet sitting on one), painted floor bays with hazard brackets for the nests, a bolted flange with torch flames at home, welding-helmet pawns whose lenses light up when movable, and machined steel dice. Game moments are welding-themed too: blockades drawn as welded together, spark bursts on captures, "Overheated!" for three doubles, and a "Certified Welder" plate for the winner. Avoid the trade dress of the commercial adaptations: a square board with solid colored corner circles, their logos, or their box art.
