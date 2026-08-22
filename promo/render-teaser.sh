#!/bin/zsh
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
PROMO="$ROOT/promo"
DERIVED="$PROMO/.derived"
APP_ID="Hakketjak.Nuts---Numbers"
SCHEME="Nuts & Numbers"
PROJECT="$ROOT/Nuts & Numbers.xcodeproj"

mkdir -p "$PROMO/frames/iphone" "$PROMO/frames/ipad" "$PROMO/contact-sheets"

phone_sim="${PROMO_PHONE_SIM:-iPhone 17}"
pad_sim="${PROMO_PAD_SIM:-iPad Pro 11-inch (M5)}"

echo "Building Debug for Simulator…"
xcodebuild \
  -project "$PROJECT" \
  -scheme "$SCHEME" \
  -configuration Debug \
  -destination "generic/platform=iOS Simulator" \
  -derivedDataPath "$DERIVED" \
  CODE_SIGNING_ALLOWED=NO \
  build

APP=$(find "$DERIVED" -name "Nuts & Numbers.app" -path "*Debug-iphonesimulator*" | head -n 1)
if [[ -z "$APP" ]]; then
  echo "Could not find built app in $DERIVED" >&2
  exit 1
fi
echo "App: $APP"

render_one() {
  local sim_name="$1"
  local size="$2"
  local out_name="$3"
  local frames_dir="$4"

  echo "Booting $sim_name…"
  xcrun simctl boot "$sim_name" >/dev/null 2>&1 || true
  xcrun simctl bootstatus "$sim_name" -b

  echo "Installing…"
  xcrun simctl install "$sim_name" "$APP"

  echo "Launching teaser $size…"
  xcrun simctl terminate "$sim_name" "$APP_ID" >/dev/null 2>&1 || true
  xcrun simctl spawn "$sim_name" log stream --style compact --predicate 'eventMessage CONTAINS "PROMO_TRAILER"' >/tmp/promo-trailer-log.txt 2>/dev/null &
  local log_pid=$!

  xcrun simctl launch "$sim_name" "$APP_ID" -PromoTrailer "-PromoSize=$size"

  local data
  data=$(xcrun simctl get_app_container "$sim_name" "$APP_ID" data)
  local marker="$data/Documents/promo-trailer-ready.txt"
  echo "Waiting for $marker"
  local waited=0
  while [[ ! -f "$marker" ]]; do
    sleep 2
    waited=$((waited + 2))
    if [[ $waited -gt 420 ]]; then
      echo "Timed out waiting for teaser $size" >&2
      kill "$log_pid" >/dev/null 2>&1 || true
      exit 1
    fi
    if (( waited % 20 == 0 )); then
      echo "  still rendering… ${waited}s"
    fi
  done
  kill "$log_pid" >/dev/null 2>&1 || true

  local src
  src=$(head -n 1 "$marker")
  echo "Export: $src"
  cp "$src" "$PROMO/$out_name"
  rm -f "$marker"

  if command -v ffmpeg >/dev/null 2>&1; then
    ffmpeg -y -i "$PROMO/$out_name" -vf "fps=2" "$frames_dir/frame-%03d.png" >/dev/null 2>&1
    ffmpeg -y -i "$PROMO/$out_name" -vf "select='not(mod(n\\,15))',scale=160:-1,tile=8x4" \
      "$PROMO/contact-sheets/${out_name%.mp4}.png" >/dev/null 2>&1 || true
    ffprobe -v error -show_entries format=duration,size -show_entries stream=width,height,avg_frame_rate,codec_name \
      -of default=noprint_wrappers=1 "$PROMO/$out_name"
  fi
}

render_one "$phone_sim" "886x1920" "claw-math-app-store-teaser-886x1920.mp4" "$PROMO/frames/iphone"
render_one "$pad_sim" "1200x1600" "claw-math-app-store-teaser-1200x1600.mp4" "$PROMO/frames/ipad"

echo "Done. Files in $PROMO"
ls -lh "$PROMO"/*.mp4
