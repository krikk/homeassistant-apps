#!/usr/bin/env bash
set -Eeuo pipefail

OPTIONS=/data/options.json
json() { jq -r "${1} // empty" "$OPTIONS"; }

log_level="$(json '.log_level')"; log_level="${log_level:-info}"
guacd_host="$(json '.guacd_host')"; guacd_host="${guacd_host:-71919c26-guacd}"
guacd_port="$(json '.guacd_port')"; guacd_port="${guacd_port:-4822}"
ssl="$(json '.ssl')"; ssl="${ssl:-false}"
certfile="$(json '.certfile')"; certfile="${certfile:-fullchain.pem}"
keyfile="$(json '.keyfile')"; keyfile="${keyfile:-privkey.pem}"

export DATA_DIR=/data
export PORT=8080
export LOG_LEVEL="$log_level"
export REMOTE_DESKTOP_ENGINE=guacd
export GUACD_HOST="$guacd_host"
export GUACD_PORT="$guacd_port"
export GUACD_TUNNEL_HOST=71919c26-termix
export GUACD_RECORDING_BACKEND_PATH=/share/termix/session_recordings/guacamole
export RDP_DRIVE_PATH=/share/termix/rdp-drive
export ENABLE_SSL="$ssl"

if [[ "$ssl" == "true" ]]; then
  if [[ ! -r "/ssl/$certfile" || ! -r "/ssl/$keyfile" ]]; then
    echo "SSL enabled but /ssl/$certfile or /ssl/$keyfile is missing" >&2
    exit 1
  fi
  export SSL_CERT_PATH="/ssl/$certfile"
  export SSL_KEY_PATH="/ssl/$keyfile"
fi

mkdir -p /data /share/termix/session_recordings/guacamole /share/termix/rdp-drive

# /app/data is a Docker VOLUME (mountpoint) in the upstream image and cannot be
# removed or replaced. Termix uses DATA_DIR=/data instead. One-time migration:
# copy existing data from /app/data if /data holds nothing but options.json.
if [[ -d /app/data ]] && [[ -n "$(ls -A /app/data 2>/dev/null)" ]]; then
  if [[ -z "$(find /data -mindepth 1 -maxdepth 1 ! -name options.json -print -quit)" ]]; then
    echo "Migrating existing data from /app/data to /data"
    cp -a /app/data/. /data/
  fi
fi

while IFS= read -r entry; do
  name="$(jq -r '.name // empty' <<<"$entry")"
  value="$(jq -r '.value // empty' <<<"$entry")"
  if [[ -n "$name" ]]; then
    echo "Setting custom environment variable: $name"
    export "$name=$value"
  fi
done < <(jq -c '.env_vars // [] | .[]' "$OPTIONS")

echo "Starting Termix on port 8080 (SSL: $ssl, guacd: $guacd_host:$guacd_port)"
exec docker-entrypoint.sh /entrypoint.sh
