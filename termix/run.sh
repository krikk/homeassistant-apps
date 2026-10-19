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
export DATA_DIR=/data PORT=8080 LOG_LEVEL="$log_level" REMOTE_DESKTOP_ENGINE=guacd GUACD_HOST="$guacd_host" GUACD_PORT="$guacd_port" GUACD_TUNNEL_HOST=71919c26-termix
export GUACD_RECORDING_BACKEND_PATH=/share/termix/session_recordings/guacamole RDP_DRIVE_PATH=/share/termix/rdp-drive ENABLE_SSL="$ssl"
mkdir -p /data /share/termix/session_recordings/guacamole /share/termix/rdp-drive
if [[ ! -L /app/data ]]; then
  if [[ -d /app/data ]]; then
    find /app/data -mindepth 1 -maxdepth 1 -exec mv -t /data -- {} +
  fi
  rm -rf /app/data
  ln -s /data /app/data
fi
while IFS= read -r entry; do
  name="$(jq -r '.name // empty' <<<"$entry")"; value="$(jq -r '.value // empty' <<<"$entry")"
  [[ -n "$name" ]] && export "$name=$value"
done < <(jq -c '.env_vars // [] | .[]' "$OPTIONS")
exec docker-entrypoint.sh /entrypoint.sh
