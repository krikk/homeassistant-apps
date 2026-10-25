#!/usr/bin/env bash
set -Eeuo pipefail

die() {
  echo "::error::$*" >&2
  exit 1
}

: "${BASE_SHA:?Missing BASE_SHA}"
: "${SOURCE_SHA:?Missing SOURCE_SHA}"
: "${RELEASE_BRANCH:?Missing RELEASE_BRANCH}"
: "${GHCR_USER:?Missing GHCR_USER}"
: "${GHCR_PASSWORD:?Missing GHCR_PASSWORD}"
: "${GITHUB_REPOSITORY:?Missing GITHUB_REPOSITORY}"

[[ "$(git rev-parse HEAD)" == "$SOURCE_SHA" ]] \
  || die "Checkout does not match pinned source commit."

declare -A versions
declare -A images
declare -A existing
declare -A local_tags

tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT

read_version() {
  python3 - "$1" <<'PY'
import re
import sys
from pathlib import Path

text = Path(sys.argv[1]).read_text()
matches = re.findall(
    r"^version:[ \t]*(\d+\.\d+\.\d+(?:-\d+)?)[ \t]*$",
    text,
    re.MULTILINE,
)
if len(matches) != 1:
    raise SystemExit(f"Invalid or missing version in {sys.argv[1]}")
print(matches[0])
PY
}

check_main() {
  git fetch origin main
  [[ "$(git rev-parse origin/main)" == "$BASE_SHA" ]] \
    || die "main changed during the release. Merge main into the release branch and retry."
}

# Query the registry explicitly: authentication/network failures must never
# be mistaken for an absent version tag.
manifest_exists() {
  local package="$1"
  local version="$2"
  local token status

  token="$(
    curl --fail --silent --show-error \
      --retry 3 \
      --user "$GHCR_USER:$GHCR_PASSWORD" \
      --get \
      --data-urlencode "service=ghcr.io" \
      --data-urlencode "scope=repository:${package}:pull" \
      https://ghcr.io/token \
      | jq -er '.token // .access_token'
  )"

  status="$(
    curl --silent --show-error \
      --retry 3 \
      --output "$tmp/manifest.json" \
      --write-out '%{http_code}' \
      --header "Authorization: Bearer $token" \
      --header \
        'Accept: application/vnd.oci.image.index.v1+json, application/vnd.docker.distribution.manifest.list.v2+json, application/vnd.oci.image.manifest.v1+json, application/vnd.docker.distribution.manifest.v2+json' \
      "https://ghcr.io/v2/${package}/manifests/${version}"
  )"

  case "$status" in
    200) return 0 ;;
    404) return 1 ;;
    *)
      cat "$tmp/manifest.json" >&2
      die "Registry lookup failed for ${package}:${version}: HTTP $status"
      ;;
  esac
}

owner="${GITHUB_REPOSITORY%%/*}"
owner="${owner,,}"

for app in termix guacd; do
  versions["$app"]="$(read_version "$app/config.yaml")"
  images["$app"]="ghcr.io/${owner}/homeassistant-app-${app}"
  local_tags["$app"]="ha-release-${app}:${SOURCE_SHA}"

  # Prevent accidentally publishing to a different image than HA pulls.
  declared_image="$(
    sed -nE 's/^image:[[:space:]]*([^[:space:]]+)[[:space:]]*$/\1/p' \
      "$app/config.yaml"
  )"

  [[ "$declared_image" == "${images[$app]}" ]] \
    || die "$app/config.yaml image does not match ${images[$app]}"

  package="${owner}/homeassistant-app-${app}"
  reference="${images[$app]}:${versions[$app]}"

  if manifest_exists "$package" "${versions[$app]}"; then
    existing["$app"]=true

    # An unchanged app may keep its existing immutable version.
    if git diff --quiet "$BASE_SHA" "$SOURCE_SHA" -- "$app"; then
      echo "$app: unchanged; keeping existing $reference"
      continue
    fi

    # Allow retrying the exact same release commit after a partial failure.
    docker pull --platform linux/amd64 "$reference"

    published_revision="$(
      docker image inspect "$reference" \
        --format '{{ index .Config.Labels "org.opencontainers.image.revision" }}'
    )"

    [[ "$published_revision" == "$SOURCE_SHA" ]] \
      || die "$reference already exists. Bump the app version; existing version tags are immutable."

    echo "$app: exact release commit already published; reusing $reference"
  else
    existing["$app"]=false
    echo "$app: preparing new $reference"
  fi
done

# Build all missing images before publishing any of them.
for app in termix guacd; do
  if [[ "${existing[$app]}" == true ]]; then
    continue
  fi

  docker buildx build \
    --platform linux/amd64 \
    --load \
    --label "org.opencontainers.image.source=https://github.com/${GITHUB_REPOSITORY}" \
    --label "org.opencontainers.image.revision=${SOURCE_SHA}" \
    --label "org.opencontainers.image.version=${versions[$app]}" \
    --tag "${local_tags[$app]}" \
    "./$app"
done

check_main

# Publish immutable version tags only after all builds succeeded.
for app in termix guacd; do
  if [[ "${existing[$app]}" == true ]]; then
    continue
  fi

  package="${owner}/homeassistant-app-${app}"
  reference="${images[$app]}:${versions[$app]}"

  # Detect tags created outside this serialized workflow.
  if manifest_exists "$package" "${versions[$app]}"; then
    die "$reference appeared during the build. Refusing to overwrite it."
  fi

  docker tag "${local_tags[$app]}" "$reference"
  docker push "$reference"
done

check_main

# This is a normal, non-force push. Concurrent changes to main make it fail.
git push origin "${SOURCE_SHA}:refs/heads/main"

# Update floating tags only after main references published version tags.
for app in termix guacd; do
  docker buildx imagetools create \
    --tag "${images[$app]}:latest" \
    "${images[$app]}:${versions[$app]}"
done

{
  echo "## Release published"
  echo
  echo "- Branch: \`$RELEASE_BRANCH\`"
  echo "- Commit: \`$SOURCE_SHA\`"
  echo "- Termix: \`${versions[termix]}\`"
  echo "- guacd: \`${versions[guacd]}\`"
} >> "${GITHUB_STEP_SUMMARY:-/dev/null}"