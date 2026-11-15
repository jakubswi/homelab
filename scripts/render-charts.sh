#!/usr/bin/env bash
# Register Helm repositories from Chart.yaml files, build dependencies, and render manifests.
# Usage: ./scripts/render-charts.sh [output_dir]

set -euo pipefail
cd "$(dirname "$0")/.."

OUT_DIR="${1:-.rendered}"
mkdir -p "$OUT_DIR"

# Discover and register all HTTP(S) Helm chart repositories referenced in Chart.yaml files
idx=0
while IFS= read -r repo; do
  [ -n "$repo" ] || continue
  helm repo add --force-update "ci-repo-${idx}" "$repo" >/dev/null
  idx=$((idx + 1))
done < <(
  {
    grep -hE '^[[:space:]]*repository:[[:space:]]*["'\'']?https?://' apps/*/Chart.yaml platform/*/Chart.yaml 2>/dev/null \
      | sed -E 's/^[[:space:]]*repository:[[:space:]]*["'\'']?([^"'\''[:space:]]+)["'\'']?.*/\1/' \
      | sort -u
  } || true
)

if [ "$idx" -gt 0 ]; then
  helm repo update >/dev/null
fi

for chart in apps/* platform/*; do
  [ -d "$chart" ] && [ -f "$chart/Chart.yaml" ] || continue
  name=$(basename "$chart")

  if [ -f "$chart/Chart.lock" ]; then
    helm dependency build "$chart" >/dev/null
  else
    helm dependency update "$chart" >/dev/null
  fi

  helm template "$name" "$chart" --namespace "$name" --skip-tests \
    --api-versions monitoring.coreos.com/v1 \
    --api-versions monitoring.coreos.com/v1/ServiceMonitor > "${OUT_DIR}/${name}.yaml"
done
