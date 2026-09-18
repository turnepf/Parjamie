# App Store listing

The text entered in App Store Connect for Parjamie. Keep this file in step with what is
live there, and never mention the commercial game this is based on by name.

## App information

- **Name:** Parjamie
- **Subtitle (30):** Welding-shop race home game
- **Category:** Games · Board, Family
- **Content rights:** No third-party content
- **Age rating:** 4+ (no objectionable content, no unrestricted web access, no gambling)
- **Copyright:** 2026 Patrick Turner
- **Price:** Free, all countries and regions
- **Support URL:** https://turnepf.github.io/Parjamie/
- **Marketing URL:** https://turnepf.github.io/Parjamie/
- **Privacy policy URL:** https://turnepf.github.io/Parjamie/privacy.html
- **App privacy:** Data Not Collected

## Promotional text (170)

Roll, race and weld your helmets home. Play a friend on two phones, pass one phone around, or take on Torch, the computer welder.

## Description

Strike an arc and race your welding helmets home in Parjamie, a classic cross-and-circle dice game set in a welding shop.

Roll the dice, bring your helmets out of their bay, run them once around the diamond-plate board, and weld every one of them home before your opponent does. Land on the other player's helmet to send it back. Shelter on the purple safe squares. Weld two helmets together into a blockade nobody can pass. Win, and you earn a stamped Certified Welder plate.

PLAY YOUR WAY
• Two devices: host a game and have a friend join from their own iPhone, iPad or Mac nearby. No accounts and no internet needed.
• One device: pass the phone back and forth, with both names on the board.
• Vs computer: take on Sparky, who is still learning, or Torch, a seasoned pro.

LEARN AS YOU GO
• Step-by-step hints on every turn, with outlines showing exactly where each helmet will land
• A How to play guide with a key to every square on the board
• Tap a helmet that can't move and Parjamie tells you why

HOUSE RULES
Play the classic rules or make them your own: bring helmets out on a 5, a 6, or a 1 or 6, bounce back from home, shuffle the safe spots, quick start, must capture, and more. Whoever hosts picks the rules for both players.

THE WELDING SHOP
• Sparks fly on every capture, with an arc crackle and a buzz you can feel
• Overheat on three doubles in a row
• A scoreboard that remembers every game, kept in step across both devices

No ads. No tracking. No data collected.

## Keywords (100)

board game,dice,race,two player,pachisi,family,welding,local multiplayer,classic,strategy,cross

## Review notes

Parjamie is a two-player board game. Everything runs on device; there are no accounts, servers or in-app purchases.

To review it on a single device, tap "Vs computer" on the start screen and choose Sparky (easy) or Torch (hard), or tap "Together" to play both sides on one device. Turn on "Hints" (on by default) for turn-by-turn guidance.

Two-device play uses Bonjour on the local network: on one device tap "Host a game", on the other tap "Join a game" and pick the host. The Local Network permission prompt is used only to find the other player's device.

On the Mac (Mac Catalyst) build, the app carries both the network.client and network.server sandbox entitlements because either device in a match can be the "host": hosting starts an NWListener that advertises over Bonjour and accepts the incoming connection from the other player's device (network.server), while joining a hosted game browses for it and dials out with NWConnection (network.client). Both are peer-to-peer between the two players' own devices on their local network — there is no internet-facing server, no listening service reachable from outside that network, and no data leaves the local network.

Keep that paragraph in the macOS notes. The first macOS submission was rejected under
guideline 2.4.5 by an automated check that saw `com.apple.security.network.server` with no
matching functionality; spelling the hosting behavior out in the Mac notes is what cleared
it. The entitlements are correct as they stand — `MatchSession` creates an `NWListener` when
hosting — so nothing in the binary needed to change. The live Mac notes also say "click" and
"on a single Mac" where the iOS notes say "tap" and "on a single device".
