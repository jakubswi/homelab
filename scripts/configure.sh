#!/usr/bin/env bash
# usage: scripts/configure.sh <domain> <github-user> [lan-prefix, default 192.168.1]
set -euo pipefail
cd "$(dirname "$0")/.."
DOMAIN=${1:?usage: configure.sh <domain> <github-user> [lan-prefix e.g. 192.168.1]}
GH_USER=${2:?usage: configure.sh <domain> <github-user> [lan-prefix]}
LAN=${3:-192.168.1}

files=$(grep -rIlE 'example\.com|jakubswi|192\.168\.1\.' \
  --exclude-dir=.git --exclude-dir=charts --exclude=configure.sh . || true)
while IFS= read -r f; do
  [[ -z "$f" ]] && continue
  sed -i.bak -e "s/example\.com/${DOMAIN}/g" -e "s/jakubswi/${GH_USER}/g" "$f"
  if [[ "$LAN" != "192.168.1" ]]; then
    sed -i.bak -e "s/192\.168\.1\./${LAN}./g" "$f"
  fi
done <<< "$files"
find . -name '*.bak' -not -path './.git/*' -delete
echo "Done: domain=${DOMAIN} github=${GH_USER} lan=${LAN}.x"
echo "Review with 'git diff', then commit and push BEFORE running 'make bootstrap'."
