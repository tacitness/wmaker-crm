#!/bin/sh
# ============================================================================
# entrypoint.sh — bring up a headless GNU Window Maker
# ----------------------------------------------------------------------------
# Starts a virtual X server (Xvfb) and Window Maker on it. The documented way
# to start "Xvfb + wmaker": just run this image.
#
#   No args  → exec wmaker in the foreground (container lives as long as the WM).
#   With args→ start Xvfb + wmaker in the background, then exec "$@". This is how
#              a downstream image (e.g. ai-mcp) runs its own process against an
#              already-running desktop:  CMD ["ai-mcp", "--serve"].
#
# Env: DISPLAY (default :99), SCREEN_GEOMETRY (default 1280x800x24).
# ============================================================================
set -eu

: "${DISPLAY:=:99}"
: "${SCREEN_GEOMETRY:=1280x800x24}"
export DISPLAY

log() { echo "[wmaker-headless] $*" >&2; }

# Start the virtual framebuffer X server.
log "starting Xvfb on $DISPLAY ($SCREEN_GEOMETRY)"
Xvfb "$DISPLAY" -screen 0 "$SCREEN_GEOMETRY" -nolisten tcp &
XVFB_PID=$!

# Wait for the X socket to appear (no extra deps needed for the probe).
dpy_num="${DISPLAY#:}"
dpy_num="${dpy_num%%.*}"
i=0
while [ ! -S "/tmp/.X11-unix/X${dpy_num}" ]; do
	i=$((i + 1))
	if [ "$i" -gt 100 ]; then
		log "Xvfb did not come up on $DISPLAY after 10s"
		exit 1
	fi
	if ! kill -0 "$XVFB_PID" 2>/dev/null; then
		log "Xvfb exited during startup"
		exit 1
	fi
	sleep 0.1
done
log "X server is up"

if [ "$#" -eq 0 ]; then
	# Foreground: the window manager IS the container's main process.
	log "exec wmaker (foreground)"
	exec wmaker
fi

# Background WM, then hand off to the supplied command.
log "starting wmaker in the background"
wmaker &
log "exec: $*"
exec "$@"
