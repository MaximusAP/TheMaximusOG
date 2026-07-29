#!/usr/bin/env bash
set -euo pipefail

: "${PROJECT_NAME:?}"
: "${NAMESPACE:?}"
: "${REPLICAS:?}"
: "${FULL_IMAGE:?}"
: "${APP_HOST:?}"
: "${INGRESS_CLASS:?}"

rm -rf rendered-k8s
mkdir -p rendered-k8s

for file in k8s/*.yaml; do
  output="rendered-k8s/$(basename "$file")"
  sed \
    -e "s|__PROJECT_NAME__|${PROJECT_NAME}|g" \
    -e "s|__NAMESPACE__|${NAMESPACE}|g" \
    -e "s|__REPLICAS__|${REPLICAS}|g" \
    -e "s|__FULL_IMAGE__|${FULL_IMAGE}|g" \
    -e "s|__APP_HOST__|${APP_HOST}|g" \
    -e "s|__INGRESS_CLASS__|${INGRESS_CLASS}|g" \
    "$file" > "$output"
done

if grep -R '__[A-Z_]*__' rendered-k8s; then
  echo "Unresolved manifest placeholders found."
  exit 1
fi
