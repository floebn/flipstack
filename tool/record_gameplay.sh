#!/bin/zsh
# Nimmt die App im iPhone-17-Pro-Max-Simulator als Video auf (ohne Ton).
# Aufruf: tool/record_gameplay.sh <zieldatei.mov> <sekunden> <dart-defines …>
# Umgebung: FS_REC_LANG=de|en (Vorgabe de), FS_REC_NOBUILD=1 nutzt den letzten
# Build erneut. Selbstspiel schaltet man mit FS_AUTOPLAY=true als Define ein.
set -e
OUT=$1; SECS=$2; shift 2
D=C832E67B-5A37-4297-9ECB-27D9A69406CC
L=${FS_REC_LANG:-de}; LOC=de_DE; [[ $L == en ]] && LOC=en_US
DEFS=(); for d in "$@"; do DEFS+=(--dart-define=$d); done
if [[ -z $FS_REC_NOBUILD ]]; then
  flutter build ios --simulator --debug --dart-define=FS_ADS=off "${DEFS[@]}" | tail -1
fi
xcrun simctl boot $D 2>/dev/null || true
xcrun simctl bootstatus $D >/dev/null
xcrun simctl status_bar $D override --time "9:41" --batteryState charged --batteryLevel 100 --cellularBars 4 --wifiBars 3
xcrun simctl install $D build/ios/iphonesimulator/Runner.app
xcrun simctl terminate $D com.floebn.flipstack 2>/dev/null || true
xcrun simctl io $D recordVideo --codec=h264 --force "$OUT" >/dev/null 2>&1 &
REC=$!
python3 -c "import time; time.sleep(1.5)"
xcrun simctl launch $D com.floebn.flipstack -AppleLanguages "($L)" -AppleLocale $LOC >/dev/null
python3 -c "import time; time.sleep($SECS)"
kill -INT $REC
python3 -c "import time; time.sleep(3)"
ls -la "$OUT"
