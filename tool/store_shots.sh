#!/bin/zsh
# Nimmt eine Spielszene für den Store auf: iPhone 6,9", de und en.
# Mit FS_SHOT_PAD=1 zusätzlich iPad 13".
# Aufruf: tool/store_shots.sh <name> <wartezeit s> <dart-defines …>
set -e
NAME=$1; WAIT=$2; shift 2
PHONE=C832E67B-5A37-4297-9ECB-27D9A69406CC   # iPhone 17 Pro Max, 1320×2868
PAD=5CB55359-AF55-40FD-9978-FA45A10CF234     # iPad Pro 13" (M5), 2064×2752
OUT=store_assets/screenshots
DEVS=($PHONE); [[ -n $FS_SHOT_PAD ]] && DEVS+=($PAD)
DEFS=(); for d in "$@"; do DEFS+=(--dart-define=$d); done
flutter build ios --simulator --debug --dart-define=FS_ADS=off "${DEFS[@]}" | tail -1
for D in $DEVS; do
  xcrun simctl boot $D 2>/dev/null || true
  xcrun simctl bootstatus $D >/dev/null
  xcrun simctl status_bar $D override --time "9:41" --batteryState charged --batteryLevel 100 --cellularBars 4 --wifiBars 3
  xcrun simctl install $D build/ios/iphonesimulator/Runner.app
done
for L in de en; do
  LOC=de_DE; [[ $L == en ]] && LOC=en_US
  for D in $DEVS; do
    xcrun simctl terminate $D com.floebn.flipstack 2>/dev/null || true
    xcrun simctl launch $D com.floebn.flipstack -AppleLanguages "($L)" -AppleLocale $LOC >/dev/null
  done
  python3 -c "import time; time.sleep($WAIT)"
  mkdir -p $OUT/$L/iphone_6_9
  xcrun simctl io $PHONE screenshot $OUT/$L/iphone_6_9/$NAME.png 2>/dev/null
  if [[ -n $FS_SHOT_PAD ]]; then
    mkdir -p $OUT/$L/ipad_13
    xcrun simctl io $PAD screenshot $OUT/$L/ipad_13/$NAME.png 2>/dev/null
  fi
done
ls $OUT/*/*/$NAME.png
