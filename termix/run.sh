#!/usr/bin/env bash
set -Eeuo pipefail

readonly OPTIONS=/data/options.json
readonly HA_HTTP_PORT=8080
readonly HA_HTTPS_PORT=8443

die() {
  echo "ERROR: $*" >&2
  exit 1
}

# Preserve false values; only null/missing values become empty strings.
json() {
  jq -r "${1} | if . == null then empty else . end" "$OPTIONS"
}

[[ -r "$OPTIONS" ]] || die "Cannot read $OPTIONS"

# Validate before using process substitution, whose failures would otherwise
# not reliably terminate the main shell.
jq -e '
  type == "object" and
  (
    (.env_vars // []) |
    type == "array" and
    all(.[];
      type == "object" and
      (.name | type == "string") and
      (.value | type == "string")
    )
  )
' "$OPTIONS" >/dev/null || die "Invalid options.json or env_vars"

log_level="$(json '.log_level')"
log_level="${log_level:-info}"

guacd_host="$(json '.guacd_host')"
guacd_host="${guacd_host:-71919c26-guacd}"

guacd_port="$(json '.guacd_port')"
guacd_port="${guacd_port:-4822}"

ssl="$(json '.ssl')"
ssl="${ssl:-false}"

certfile="$(json '.certfile')"
certfile="${certfile:-fullchain.pem}"

keyfile="$(json '.keyfile')"
keyfile="${keyfile:-privkey.pem}"

export DATA_DIR=/data
export PORT="$HA_HTTP_PORT"
export SSL_PORT="$HA_HTTPS_PORT"
export LOG_LEVEL="$log_level"
export REMOTE_DESKTOP_ENGINE=guacd
export GUACD_HOST="$guacd_host"
export GUACD_PORT="$guacd_port"
export GUACD_TUNNEL_HOST=71919c26-termix
export GUACD_RECORDING_BACKEND_PATH=/share/termix/session_recordings/guacamole
export RDP_DRIVE_PATH=/share/termix/rdp-drive
export ENABLE_SSL="$ssl"

# Apply custom environment variables before evaluating the final SSL state.
while IFS= read -r entry; do
  name="$(jq -r '.name' <<<"$entry")"
  value="$(jq -r '.value' <<<"$entry")"

  [[ "$name" =~ ^[a-zA-Z_][a-zA-Z0-9_]*$ ]] \
    || die "Invalid environment variable name: $name"

  case "$name" in
    PORT|SSL_PORT)
      die "$name is reserved by the add-on. Configure external ports in Home Assistant under Network."
      ;;
  esac

  echo "Setting custom environment variable: $name"
  export "$name=$value"
done < <(jq -c '.env_vars // [] | .[]' "$OPTIONS")

# Use exactly the same boolean representation as the upstream entrypoint.
case "${ENABLE_SSL-}" in
  true|false)
    ssl="$ENABLE_SSL"
    ;;
  *)
    die "ENABLE_SSL must be exactly 'true' or 'false'."
    ;;
esac

# Internal ports are fixed. Home Assistant controls host-side port mappings.
export PORT="$HA_HTTP_PORT"
export SSL_PORT="$HA_HTTPS_PORT"

run_uid="${PUID:-1000}"
run_gid="${PGID:-1000}"

[[ "$run_uid" =~ ^[0-9]+$ ]] \
  || die "PUID must be a non-negative integer."

[[ "$run_gid" =~ ^[0-9]+$ ]] \
  || die "PGID must be a non-negative integer."

mkdir -p \
  /data \
  /share/termix/session_recordings/guacamole \
  /share/termix/rdp-drive

# /app/data is a Docker VOLUME in the upstream image and cannot be replaced.
# One-time migration if /data contains nothing except options.json.
if [[ -d /app/data ]] && [[ -n "$(ls -A /app/data)" ]]; then
  if [[ -z "$(find /data -mindepth 1 -maxdepth 1 \
    ! -name options.json -print -quit)" ]]; then
    echo "Migrating existing data from /app/data to /data"
    cp -a /app/data/. /data/
  fi
fi

# Home Assistant creates these directories as root, but upstream normally
# drops privileges to PUID:PGID. Only change entries with incorrect ownership.
fix_owner() {
  local dir="$1"
  local changed

  changed="$(
    find "$dir" \( ! -user "$run_uid" -o ! -group "$run_gid" \) \
      -exec chown -h "$run_uid:$run_gid" {} + -print | wc -l
  )"

  if [[ "$changed" -gt 0 ]]; then
    echo "Fixed ownership of $changed entries in $dir (UID $run_uid, GID $run_gid)"
  fi
}

fix_owner /data
fix_owner /share/termix
chmod u+rwx /data /share/termix

# The copied certificates are runtime files, not application backup data.
ssl_dir=/run/termix-ssl
rm -rf "$ssl_dir"

if [[ "$ssl" == "true" ]]; then
  src_cert="/ssl/$certfile"
  src_key="/ssl/$keyfile"

  [[ -f "$src_cert" && -r "$src_cert" ]] \
    || die "SSL enabled but certificate $src_cert is missing or unreadable."

  [[ -f "$src_key" && -r "$src_key" ]] \
    || die "SSL enabled but private key $src_key is missing or unreadable."

  # Restrict permissions from the moment the private key is copied.
  (
    umask 077

    mkdir -p "$ssl_dir"
    cp "$src_cert" "$ssl_dir/fullchain.pem"
    cp "$src_key" "$ssl_dir/privkey.pem"

    chown -R "$run_uid:$run_gid" "$ssl_dir"
    chmod 0750 "$ssl_dir"
    chmod 0644 "$ssl_dir/fullchain.pem"
    chmod 0600 "$ssl_dir/privkey.pem"
  )

  # Certificate paths are managed by the add-on when SSL is enabled.
  export SSL_CERT_PATH="$ssl_dir/fullchain.pem"
  export SSL_KEY_PATH="$ssl_dir/privkey.pem"

  echo "Using SSL certificate $src_cert and key $src_key (copied for UID $run_uid)"
  echo "Starting Termix with HTTPS on internal port $SSL_PORT; HTTP is disabled."
else
  echo "Starting Termix with HTTP on internal port $PORT; HTTPS is disabled."
fi

echo "guacd endpoint: ${GUACD_HOST}:${GUACD_PORT}"
echo "External ports are configured in Home Assistant under Network."

exec docker-entrypoint.sh /entrypoint.sh
