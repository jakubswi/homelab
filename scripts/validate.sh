#!/usr/bin/env bash
# Render every platform/app directory and validate the output with kubeconform.
# Needs: helm, kubectl (for kustomize), kubeconform.
set -euo pipefail
cd "$(dirname "$0")/.."

KC=(kubeconform -strict -ignore-missing-schemas -summary
  -schema-location default
  -schema-location 'https://raw.githubusercontent.com/datreeio/CRDs-catalog/main/{{.Group}}/{{.ResourceKind}}_{{.ResourceAPIVersion}}.json')

fail=0
for dir in platform/* apps/* clusters/home bootstrap/argocd; do
  [ -d "$dir" ] || continue
  name=$(basename "$dir")
  if [ -f "$dir/Chart.yaml" ]; then
    echo "==> $dir"
    helm dependency update "$dir" >/dev/null
    out=$(helm template "$name" "$dir" --namespace "$name" --include-crds \
      --api-versions monitoring.coreos.com/v1 \
      --api-versions monitoring.coreos.com/v1/ServiceMonitor) || { fail=1; continue; }
  elif [ -f "$dir/kustomization.yaml" ]; then
    echo "==> $dir"
    out=$(kubectl kustomize "$dir") || { fail=1; continue; }
  elif compgen -G "$dir/*.yaml" >/dev/null; then
    echo "==> $dir"
    out=$(for f in "$dir"/*.yaml; do echo '---'; cat "$f"; done)
  else
    continue
  fi
  echo "$out" | "${KC[@]}" - || fail=1
done
exit $fail
