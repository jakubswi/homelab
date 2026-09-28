#!/usr/bin/env bash
# Create a SealedSecret without ever writing plaintext to disk.
# usage: scripts/seal-secret.sh <namespace> <secret-name> <out-file> <key1> [key2 ...]
# Example:
#   scripts/seal-secret.sh cert-manager cloudflare-api-token \
#     platform/cert-manager/templates/cloudflare-api-token.sealed.yaml api-token
set -euo pipefail
[ $# -ge 4 ] || { sed -n '2,7p' "$0"; exit 1; }
ns=$1; name=$2; out=$3; shift 3
args=()
for key in "$@"; do
  read -rsp "Value for ${key}: " val; echo
  args+=("--from-literal=${key}=${val}")
done
kubectl create secret generic "$name" -n "$ns" "${args[@]}" --dry-run=client -o yaml \
  | kubeseal --controller-name sealed-secrets-controller --controller-namespace sealed-secrets --format yaml > "$out"
echo "Wrote $out. Commit and push it."
