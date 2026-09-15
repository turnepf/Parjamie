#!/bin/zsh
# Captures the App Store screenshots from the staged debug scenes.
#
# Usage: scripts/app-store-screenshots.sh <simulator-udid> <prefix> [output-dir]
# Use an iPhone 17 Pro Max (6.9") and an iPad Pro 13-inch simulator. Build the Debug app
# for that simulator first. The iPhone set is also saved at 1284 × 2778 for the 6.5" slot.
set -u
SIM=$1; PREFIX=$2; OUT=${3:-screenshots}
BID=net.parjamie.game
mkdir -p $OUT

xcrun simctl status_bar $SIM override --time 9:41 --batteryState charged --batteryLevel 100 --wifiBars 3 --cellularBars 4

shot() {
  xcrun simctl terminate $SIM $BID >/dev/null 2>&1; sleep 2
  xcrun simctl launch $SIM $BID -seenWelcomeTour YES -seenHowToPlay YES -playerName Alex "$@" >/dev/null
}
snap() { sleep $2; xcrun simctl io $SIM screenshot $OUT/$PREFIX-$1.png >/dev/null; }

shot -shotGame;   snap 1-game 8
shot -shotWin;    snap 2-win 8
shot;             snap 3-lobby 6
shot -shotScores; snap 4-scores 7
shot -shotRules;  snap 5-rules 7
shot -shotGuide;  snap 6-guide 7
xcrun simctl status_bar $SIM clear

if [[ $PREFIX == iphone ]]; then
  for f in $OUT/iphone-*.png; do
    magick $f -resize 1284x -gravity center -crop 1284x2778+0+0 +repage -quality 92 ${f%.png}-6.5.jpg
  done
fi
ls $OUT
