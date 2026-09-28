#!/usr/bin/env bash
# Resolve Helm dependencies and (re)write Chart.lock. Commit the lock files.
set -euo pipefail
cd "$(dirname "$0")/.."
for chart in platform/*/Chart.yaml apps/*/Chart.yaml; do
  [ -f "$chart" ] || continue
  dir=$(dirname "$chart")
  echo "==> $dir"
  helm dependency update "$dir"
done
