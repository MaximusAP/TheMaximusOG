#!/usr/bin/env bash
set -euo pipefail

: "${TECHNITIUM_API_URL:?}"
: "${TECHNITIUM_API_TOKEN:?}"
: "${TECHNITIUM_ZONE:?}"
: "${APP_HOST:?}"
: "${NPM_IP:?}"

RECORD_NAME="${APP_HOST%.${TECHNITIUM_ZONE}}"

# Technitium API versions can differ. These endpoints match the common v2-style
# DNS API pattern. Adjust parameter names if your installed version differs.
COMMON=(--fail --silent --show-error --get)

response="$(curl "${COMMON[@]}" \
  --data-urlencode "token=${TECHNITIUM_API_TOKEN}" \
  --data-urlencode "domain=${APP_HOST}" \
  "${TECHNITIUM_API_URL}/zones/records/get" 2>/dev/null || true)"

if printf '%s' "$response" | grep -q "${NPM_IP}"; then
  echo "Technitium A record already correct: ${APP_HOST} -> ${NPM_IP}"
  exit 0
fi

# Delete stale A record when present, then add the desired value.
curl "${COMMON[@]}" \
  --data-urlencode "token=${TECHNITIUM_API_TOKEN}" \
  --data-urlencode "domain=${APP_HOST}" \
  --data-urlencode "type=A" \
  "${TECHNITIUM_API_URL}/zones/records/delete" >/dev/null 2>&1 || true

curl "${COMMON[@]}" \
  --data-urlencode "token=${TECHNITIUM_API_TOKEN}" \
  --data-urlencode "domain=${APP_HOST}" \
  --data-urlencode "zone=${TECHNITIUM_ZONE}" \
  --data-urlencode "type=A" \
  --data-urlencode "ipAddress=${NPM_IP}" \
  --data-urlencode "ttl=300" \
  --data-urlencode "overwrite=true" \
  "${TECHNITIUM_API_URL}/zones/records/add" >/dev/null

echo "Technitium A record configured: ${APP_HOST} -> ${NPM_IP}"
