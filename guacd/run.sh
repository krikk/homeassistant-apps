#!/bin/sh
set -eu
level="$(sed -n 's/.*"log_level"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/p' /data/options.json 2>/dev/null || true)"
level="${level:-info}"
mkdir -p /share/termix/session_recordings/guacamole /share/termix/rdp-drive
export GUACD_RECORDING_PATH=/share/termix/session_recordings/guacamole GUACD_DRIVE_PATH=/share/termix/rdp-drive
exec guacd -b 0.0.0.0 -l 4822 -f -L "$level"
