#!/usr/bin/env bash
# Headless ConnectIQ simulator runner. Executed INSIDE the monkey-run FHS
# sandbox (which puts every GTK/webkit/GL lib the simulator needs on
# /usr/lib, including a -Bsymbolic freetype — see flake.nix).
#
# Boots the simulator under Xvfb, pushes a compiled .prg with monkeydo,
# verifies the app loads and runs on the target device, and captures a
# screenshot of the simulator window into OUTDIR. The simulator draws the
# device screen with plain X11/cairo, so software rendering under Xvfb is
# all it needs — no GPU required.
set -uo pipefail

PRG=${1:?usage: ciq-sim-run PRG DEVICE [OUTDIR] [run|test]}
DEVICE=${2:?missing DEVICE}
OUTDIR=${3:-.}
MODE=${4:-run}
: "${SDK_HOME:?SDK_HOME unset — run via 'nix develop -c make simcheck'}"

mkdir -p "$OUTDIR"

# Hide the desktop session's Wayland socket: GDK prefers Wayland and would
# otherwise open the simulator window on the developer's desktop instead of
# our Xvfb display.
XDG_RUNTIME_DIR=$(mktemp -d)
export XDG_RUNTIME_DIR

DISPLAY_NUM=99
while [ -e "/tmp/.X$DISPLAY_NUM-lock" ] || [ -e "/tmp/.X11-unix/X$DISPLAY_NUM" ]; do
  DISPLAY_NUM=$((DISPLAY_NUM + 1))
done

Xvfb ":$DISPLAY_NUM" -screen 0 1400x1100x24 -ac >"$OUTDIR/xvfb.log" 2>&1 &
XVFB_PID=$!
cleanup() {
  pkill -f "$SDK_HOME/bin/simulator" 2>/dev/null
  kill "$XVFB_PID" 2>/dev/null
  wait 2>/dev/null
  rm -f "/tmp/.X$DISPLAY_NUM-lock"
}
trap cleanup EXIT
sleep 1

export DISPLAY=":$DISPLAY_NUM"
export GTK_IM_MODULE=gtk-im-context-simple XMODIFIERS=""
export LIBGL_ALWAYS_SOFTWARE=1 GALLIUM_DRIVER=llvmpipe
export LD_LIBRARY_PATH="$SDK_HOME/bin"
twm >/dev/null 2>&1 &

echo "== launching simulator (connectiq) on :$DISPLAY_NUM =="
"$SDK_HOME/bin/connectiq" >"$OUTDIR/connectiq.log" 2>&1 &
for _ in $(seq 1 30); do
  pgrep -f "$SDK_HOME/bin/simulator" >/dev/null 2>&1 && break
  sleep 1
done
if ! pgrep -f "$SDK_HOME/bin/simulator" >/dev/null 2>&1; then
  echo "FAIL: simulator did not start" >&2
  tail -20 "$OUTDIR/connectiq.log" >&2
  exit 2
fi
sleep 6

shot() { # shot <file> — capture the simulator window (fallback: full root),
         # retrying until the frame has real content (device art still
         # loading compresses to a nearly-empty PNG)
  local wid attempt
  for attempt in 1 2 3 4 5 6; do
    wid=$(xdotool search --name "CIQ Simulator" 2>/dev/null | head -1)
    [ -n "$wid" ] && xdotool windowactivate "$wid" 2>/dev/null
    import -window "${wid:-root}" "$1" 2>/dev/null
    [ "$(stat -c%s "$1" 2>/dev/null || echo 0)" -gt 30000 ] && return 0
    sleep 4
  done
  return 0
}

echo "== monkeydo $(basename "$PRG") $DEVICE ($MODE) =="
if [ "$MODE" = "test" ]; then
  timeout 60 "$SDK_HOME/bin/monkeydo" "$PRG" "$DEVICE" -t >"$OUTDIR/monkeydo.log" 2>&1
  shot "$OUTDIR/$DEVICE.png"
else
  # In run mode the app stays resident; let it boot, screenshot it, stop.
  "$SDK_HOME/bin/monkeydo" "$PRG" "$DEVICE" >"$OUTDIR/monkeydo.log" 2>&1 &
  MD=$!
  sleep 10
  shot "$OUTDIR/$DEVICE.png"
  kill "$MD" 2>/dev/null
fi
[ -s "$OUTDIR/$DEVICE.png" ] && echo "screenshot: $OUTDIR/$DEVICE.png"

echo "== monkeydo output =="
cat "$OUTDIR/monkeydo.log"

# A device/resource mismatch surfaces as a load error from monkeydo; a clean
# boot leaves the app's own startup prints (and no error markers).
if grep -qiE 'error|exception|could not|cannot|no such|unable to' "$OUTDIR/monkeydo.log"; then
  echo "FAIL: monkeydo reported an error for $DEVICE" >&2
  exit 1
fi
echo "PASS: $DEVICE booted the app in the simulator"
