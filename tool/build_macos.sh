#!/usr/bin/env bash
# Build & run Screen Widget on macOS, with live progress.
#
#   ./tool/build_macos.sh              debug build, then launch the app
#   ./tool/build_macos.sh release      release build, then show it in Finder
#   ./tool/build_macos.sh --skip-analyze
#
# Every step's full output goes to build/logs/<step>.log. The % shown for a
# step is estimated from how long that step took last time (first build: elapsed time only).
# Written for the bash 3.2 that ships with macOS.

set -u
cd "$(dirname "$0")/.."

MODE=debug
ANALYZE=1
for a in "$@"; do
  case "$a" in
    release|--release) MODE=release ;;
    debug|--debug) MODE=debug ;;
    --skip-analyze) ANALYZE=0 ;;
    -h|--help) sed -n '2,10p' "$0"; exit 0 ;;
    *) echo "Unknown option: $a"; exit 2 ;;
  esac
done

LOG_DIR="build/logs"
TIMES="build/.build_times"
mkdir -p "$LOG_DIR"
touch "$TIMES"

TTY=0; [ -t 1 ] && TTY=1
if [ $TTY -eq 1 ]; then
  B=$'\033[1m'; D=$'\033[2m'; R=$'\033[31m'; G=$'\033[32m'; Y=$'\033[33m'; C=$'\033[36m'; N=$'\033[0m'; CLR=$'\r\033[K'
else
  B=; D=; R=; G=; Y=; C=; N=; CLR=""
fi
SPIN=('⠋' '⠙' '⠹' '⠸' '⠼' '⠴' '⠦' '⠧' '⠇' '⠏')
TOTAL=6
BUILD_START=$(date +%s)

fmt_time() { printf "%02d:%02d" $(($1 / 60)) $(($1 % 60)); }

prev_time() { awk -v k="$1" '$1==k {print $2}' "$TIMES" | tail -n 1; }

save_time() {
  grep -v "^$1 " "$TIMES" > "$TIMES.tmp" 2>/dev/null || true
  echo "$1 $2" >> "$TIMES.tmp"
  mv "$TIMES.tmp" "$TIMES"
}

# Progress bar for the whole build: $1 = progress in 1/1000ths.
bar() {
  local filled=$(($1 * 24 / 1000)) out="" i=0
  while [ $i -lt 24 ]; do
    if [ $i -lt $filled ]; then out="$out█"; else out="$out░"; fi
    i=$((i + 1))
  done
  printf "%s" "$out"
}

# Last meaningful line of a log, trimmed to fit the terminal.
last_line() {
  local cols=${COLUMNS:-$(tput cols 2>/dev/null || echo 100)}
  local width=$((cols - 62)); [ $width -lt 20 ] && width=20
  grep -v '^[[:space:]]*$' "$1" 2>/dev/null | tail -n 1 | tr -d '\r' | sed 's/^[[:space:]]*//' | cut -c1-$width
}

# run_step <index> <key> <title> <command...>
run_step() {
  local idx=$1 key=$2 title=$3; shift 3
  local log="$LOG_DIR/$key.log"
  local start prev el pct frac line i=0 rc
  start=$(date +%s)
  prev=$(prev_time "$key")
  : > "$log"
  ("$@") > "$log" 2>&1 &
  local pid=$!
  while kill -0 "$pid" 2>/dev/null; do
    el=$(( $(date +%s) - start ))
    pct=""; frac=0
    if [ -n "$prev" ] && [ "$prev" -gt 0 ]; then
      frac=$((el * 1000 / prev)); [ $frac -gt 990 ] && frac=990
      pct=" ~$((frac / 10))%"
    fi
    if [ $TTY -eq 0 ]; then sleep 0.5; continue; fi
    line=$(last_line "$log")
    printf "%s%s %s [%d/%d] %-18s %s%s%s%s  %s%s%s" "$CLR" "$C${SPIN[$((i % 10))]}$N" "$(bar $(( ((idx - 1) * 1000 + frac) / TOTAL )))" \
      "$idx" "$TOTAL" "$title" "$B" "$(fmt_time $el)" "$N" "$pct" "$D" "$line" "$N"
    i=$((i + 1))
    sleep 0.2
  done
  wait "$pid"; rc=$?
  el=$(( $(date +%s) - start ))
  if [ $rc -eq 0 ]; then
    save_time "$key" "$el"
    printf "%s%s✓%s [%d/%d] %-18s %s%s\n" "$CLR" "$G" "$N" "$idx" "$TOTAL" "$title" "$(fmt_time $el)" ""
    return 0
  fi
  printf "%s%s✗%s [%d/%d] %-18s %s  %sfailed (exit %d)%s\n\n" "$CLR" "$R" "$N" "$idx" "$TOTAL" "$title" "$(fmt_time $el)" "$R" "$rc" "$N"
  echo "${B}Last lines of the log:${N}"
  grep -v '^[[:space:]]*$' "$log" | tail -n 30 | sed 's/^/  /'
  echo
  echo "Full log: ${B}$log${N}"
  exit $rc
}

skip_step() { printf "%s–%s [%d/%d] %-18s %s%s%s\n" "$D" "$N" "$1" "$TOTAL" "$2" "$D" "$3" "$N"; }

check_tools() {
  command -v flutter >/dev/null || { echo "Flutter is not installed: https://docs.flutter.dev/get-started/install/macos"; return 1; }
  command -v xcodebuild >/dev/null || { echo "Xcode is not installed (App Store → Xcode, then: sudo xcode-select -s /Applications/Xcode.app)"; return 1; }
  command -v pod >/dev/null || { echo "CocoaPods is not installed: brew install cocoapods  (or: sudo gem install cocoapods)"; return 1; }
  flutter --version
  flutter config --enable-macos-desktop
}

# `open` only brings an already-running copy to the front, so quit any running
# Screen Widget (including pop-out windows) first; otherwise you'd keep seeing the old build.
launch_app() {
  if pgrep -x screen_widget >/dev/null; then
    echo "Closing the running Screen Widget…"
    pkill -x screen_widget || true
    for _ in 1 2 3 4 5 6 7 8 9 10; do pgrep -x screen_widget >/dev/null || break; sleep 0.3; done
    pkill -9 -x screen_widget 2>/dev/null || true
  fi
  open -n "$1"
}

compile() {
  bash tool/fix_macos_target.sh
  flutter build macos "--$MODE"
}

echo
echo "${B}Screen Widget${N} · macOS · $MODE build"
echo

run_step 1 tools "Checking tools" check_tools

if [ -d macos/Runner ]; then
  skip_step 2 "Project setup" "already set up"
else
  run_step 2 setup "Project setup" bash tool/setup_macos.sh
fi

run_step 3 packages "Getting packages" flutter pub get

if [ $ANALYZE -eq 1 ]; then
  run_step 4 analyze "Checking code" flutter analyze --no-fatal-infos --no-fatal-warnings
else
  skip_step 4 "Checking code" "skipped"
fi

run_step 5 "compile_$MODE" "Compiling ($MODE)" compile

if [ "$MODE" = release ]; then CONFIG=Release; else CONFIG=Debug; fi
APP=$(ls -d build/macos/Build/Products/$CONFIG/*.app 2>/dev/null | head -n 1)
[ -z "$APP" ] && APP=$(ls -d build/macos/Build/Products/*/*.app 2>/dev/null | head -n 1)

if [ "$MODE" = release ]; then
  run_step 6 reveal "Opening in Finder" open -R "$APP"
else
  run_step 6 launch "Launching app" launch_app "$APP"
fi

TOTAL_EL=$(( $(date +%s) - BUILD_START ))
echo
printf "%s✓ Done in %s%s  %s%s%s\n" "$G" "$(fmt_time $TOTAL_EL)" "$N" "$D" "$APP" "$N"
echo "${D}Tip: for hot reload while editing, use: flutter run -d macos${N}"
