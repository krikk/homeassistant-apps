#!/bin/sh
set -eu

OPTIONS=/data/options.json
GUACD_BIN=/opt/guacamole/sbin/guacd

level=""
if [ -r "$OPTIONS" ]; then
  level="$(sed -n 's/.*"log_level"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/p' "$OPTIONS" | head -n 1 || true)"
fi
level="${level:-info}"

case "$level" in
  trace|debug|info|warning|error) ;;
  *)
    echo "Invalid log_level '$level', falling back to info" >&2
    level=info
    ;;
esac

mkdir -p /share/termix/session_recordings/guacamole /share/termix/rdp-drive

if [ ! -x "$GUACD_BIN" ]; then
  GUACD_BIN="$(command -v guacd || true)"
fi
if [ -z "$GUACD_BIN" ]; then
  echo "guacd binary not found" >&2
  exit 1
fi

echo "Starting guacd (log level: $level) on 0.0.0.0:4822"
exec "$GUACD_BIN" -b 0.0.0.0 -l 4822 -f -L "$level"
