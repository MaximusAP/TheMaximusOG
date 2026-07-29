#!/usr/bin/env bash
set -euo pipefail

: "${NPM_API_URL:?}"
: "${NPM_USERNAME:?}"
: "${NPM_PASSWORD:?}"
: "${APP_HOST:?}"
: "${NPM_FORWARD_IP:?}"
: "${NPM_FORWARD_PORT:?}"

TOKEN_RESPONSE="$(curl --fail --silent --show-error \
  -H 'Content-Type: application/json' \
  --data "$(python3 -c 'import json,os; print(json.dumps({"identity":os.environ["NPM_USERNAME"],"secret":os.environ["NPM_PASSWORD"]}))')" \
  "${NPM_API_URL}/tokens")"

TOKEN="$(TOKEN_RESPONSE="$TOKEN_RESPONSE" python3 -c \
  'import json,os; print(json.loads(os.environ["TOKEN_RESPONSE"])["token"])')"

AUTH_HEADER="Authorization: Bearer ${TOKEN}"

EXISTING="$(curl --fail --silent --show-error \
  -H "${AUTH_HEADER}" \
  "${NPM_API_URL}/nginx/proxy-hosts")"

HOST_ID="$(EXISTING="$EXISTING" APP_HOST="$APP_HOST" python3 -c '
import json, os
for item in json.loads(os.environ["EXISTING"]):
    if os.environ["APP_HOST"] in item.get("domain_names", []):
        print(item.get("id", ""))
        break
')"

PAYLOAD="$(APP_HOST="$APP_HOST" \
  NPM_FORWARD_IP="$NPM_FORWARD_IP" \
  NPM_FORWARD_PORT="$NPM_FORWARD_PORT" \
  python3 -c '
import json, os
print(json.dumps({
    "domain_names": [os.environ["APP_HOST"]],
    "forward_scheme": "http",
    "forward_host": os.environ["NPM_FORWARD_IP"],
    "forward_port": int(os.environ["NPM_FORWARD_PORT"]),
    "access_list_id": 0,
    "certificate_id": 0,
    "ssl_forced": False,
    "caching_enabled": False,
    "block_exploits": True,
    "advanced_config": "",
    "allow_websocket_upgrade": True,
    "http2_support": False,
    "hsts_enabled": False,
    "hsts_subdomains": False,
    "enabled": True,
    "locations": []
}))
')"

if [[ -n "$HOST_ID" ]]; then
  curl --fail --silent --show-error \
    -X PUT \
    -H "${AUTH_HEADER}" \
    -H 'Content-Type: application/json' \
    --data "$PAYLOAD" \
    "${NPM_API_URL}/nginx/proxy-hosts/${HOST_ID}" >/dev/null

  echo "NPM proxy host updated: ${APP_HOST} -> ${NPM_FORWARD_IP}:${NPM_FORWARD_PORT}"
else
  curl --fail --silent --show-error \
    -X POST \
    -H "${AUTH_HEADER}" \
    -H 'Content-Type: application/json' \
    --data "$PAYLOAD" \
    "${NPM_API_URL}/nginx/proxy-hosts" >/dev/null

  echo "NPM proxy host created: ${APP_HOST} -> ${NPM_FORWARD_IP}:${NPM_FORWARD_PORT}"
fi
