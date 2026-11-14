#!/bin/bash
# Generates 6.9" App Store screenshots (1320x2868) into docs/appstore/screenshots.
# Usage: ios/scripts/screenshots.sh [simulator-udid]   (default: first available "iPhone 17 Pro Max")
set -euo pipefail
cd "$(dirname "$0")/../.."
ROOT="$PWD"
OUT="${OUT:-$ROOT/docs/appstore/screenshots}"
BUNDLE=$(grep -m1 'PRODUCT_BUNDLE_IDENTIFIER = com' ios/BetterHalf.xcodeproj/project.pbxproj | sed -E 's/.*= (.*);/\1/')
GROUP=$(grep -o 'group\.[a-z0-9.]*' ios/Config/BetterHalf.entitlements | head -1)
UDID="${1:-$(xcrun simctl list devices available | grep -m1 'iPhone 17 Pro Max' | grep -oE '[0-9A-F-]{36}')}"
DD="${TMPDIR:-/tmp}/betterhalf-screenshots-dd"   # outside iCloud folders (codesign dislikes xattrs)

echo "▶ simulator $UDID, bundle $BUNDLE"
xcrun simctl boot "$UDID" 2>/dev/null || true
xcrun simctl bootstatus "$UDID" -b >/dev/null
xcrun simctl ui "$UDID" appearance light
xcrun simctl status_bar "$UDID" override --time "9:41" --batteryState charged --batteryLevel 100 --wifiBars 3 --cellularMode active --cellularBars 4

echo "▶ building"
xcodebuild -project ios/BetterHalf.xcodeproj -scheme BetterHalf -configuration Debug \
  -destination "id=$UDID" -derivedDataPath "$DD" -quiet build
xcrun simctl uninstall "$UDID" "$BUNDLE" 2>/dev/null || true
xcrun simctl install "$UDID" "$DD/Build/Products/Debug-iphonesimulator/BetterHalf.app"
xcrun simctl launch "$UDID" "$BUNDLE" >/dev/null; sleep 2; xcrun simctl terminate "$UDID" "$BUNDLE" || true

echo "▶ seeding demo data"
G=$(xcrun simctl get_app_container "$UDID" "$BUNDLE" "$GROUP")
python3 -I - "$G/betterhalf.json" <<'PY'
import json, sys, time, datetime as dt
today = dt.date.today(); k = lambda d: d.isoformat(); now = time.time()
state = {
  "v": 1, "me": "小明", "partner": "小红",
  "startDate": k(today - dt.timedelta(days=519)),           # today is day 520 💕
  "moments": [
    {"id": "m1", "date": k(today), "text": "下班一起去吃了那家排队两小时的火锅，值了！", "mood": "🍜", "by": "me"},
    {"id": "m2", "date": k(today - dt.timedelta(days=9)), "text": "第一次一起看海，风好大，她说想每年都来一次", "mood": "🥰", "by": "partner"},
    {"id": "m3", "date": k(today - dt.timedelta(days=30)), "text": "团子第一次学会握手 🐾", "mood": "😂", "by": "me"},
    {"id": "m4", "date": k(today.replace(year=today.year - 1)), "text": "第一次约会，紧张到把奶茶洒了一身", "mood": "😭", "by": "me"},
  ],
  "anniversaries": [
    {"id": "a1", "name": "小红生日", "date": k((today + dt.timedelta(days=12)).replace(year=1998)), "yearly": True},
    {"id": "a2", "name": "第一次旅行", "date": k((today + dt.timedelta(days=47)).replace(year=today.year - 1)), "yearly": True},
  ],
  "bucket": [
    {"id": "b1", "text": "一起看一次日出", "done": True, "doneAt": k(today - dt.timedelta(days=40))},
    {"id": "b2", "text": "一起去一次海边", "done": True, "doneAt": k(today - dt.timedelta(days=9))},
    {"id": "b3", "text": "一起养一只宠物", "done": True, "doneAt": k(today - dt.timedelta(days=120))},
    {"id": "b4", "text": "来一次说走就走的旅行", "done": False},
    {"id": "b5", "text": "一起看 100 部电影", "done": False},
  ],
  "decisions": [{"id": "d1", "name": "今天吃什么", "options": ["火锅", "日料", "烧烤", "麻辣烫", "家常菜", "披萨"]}],
  "answers": {k(today): {"me": "你在我加班时偷偷送来的那杯热可可", "partner": "每次吵架后你都先来抱我"}},
  "pets": [{"id": "p1", "name": "团子", "species": "🐱", "createdAt": now - 86400 * 120,
            "lastFed": now - 1800, "lastPetted": now - 600, "affection": 26, "personality": "粘人精、吃货"}],
  "profileUpdatedAt": now,
}
json.dump(state, open(sys.argv[1], "w"), ensure_ascii=False)
PY

mkdir -p "$OUT"
shoot() { # tab filename
  xcrun simctl terminate "$UDID" "$BUNDLE" 2>/dev/null || true
  xcrun simctl launch "$UDID" "$BUNDLE" -BHTab "$1" >/dev/null
  sleep 4
  xcrun simctl io "$UDID" screenshot "$OUT/$2.png" >/dev/null
  echo "  ✓ $2.png"
}
echo "▶ capturing"
shoot home 01-home
shoot memories 02-memories
shoot pet 03-pet
shoot talk 04-daily-question
shoot play 05-decide
xcrun simctl status_bar "$UDID" clear
echo "Done → $OUT"
