#!/usr/bin/env bash
# TODO: Replace repo placeholders with your real values.
# usage: scripts/configure.sh <domain> <github-user> [lan-prefix, default 192.168.1]
set -euo pipefail
cd "$(dirname "$0")/.."
DOMAIN=${1:?usage: configure.sh <domain> <github-user> [lan-prefix e.g. 192.168.1]}
GH_USER=${2:?usage: configure.sh <domain> <github-user> [lan-prefix]}
LAN=${3:-192.168.1}

files=$(grep -rIlE 'example\.com|YOUR_GITHUB_USER|192\.168\.1\.' \
  --exclude-dir=.git --exclude-dir=charts --exclude=configure.sh . || true)
for f in $files; do
  sed -i.bak -e "s/example\.com/${DOMAIN}/g" -e "s/YOUR_GITHUB_USER/${GH_USER}/g" "$f"
  if [ "$LAN" != "192.168.1" ]; then
    sed -i.bak -e "s/192\.168\.1\./${LAN}./g" "$f"
  fi
done
find . -name '*.bak' -not -path './.git/*' -delete
echo "Done: domain=${DOMAIN} github=${GH_USER} lan=${LAN}.x"
echo "Review with 'git diff', then commit and push BEFORE running 'make bootstrap'."
