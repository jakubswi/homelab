#!/usr/bin/env bash
# Pin GitHub Actions in .github/workflows/ to full 40-char commit SHAs with tag comments.
# Usage: ./scripts/pin-actions.sh

set -euo pipefail
cd "$(dirname "$0")/.."

declare -A SHA_CACHE

resolve_sha() {
  local owner="$1"
  local repo="$2"
  local ref="$3"
  local cache_key="${owner}/${repo}@${ref}"

  if [[ -v "SHA_CACHE[$cache_key]" ]]; then
    echo "${SHA_CACHE[$cache_key]}"
    return 0
  fi

  local url="https://github.com/${owner}/${repo}.git"
  local sha=""

  # Resolve lightweight or annotated tags (dereferenced ^{} commit appears last)
  sha=$(git ls-remote --tags "$url" "refs/tags/${ref}" "refs/tags/${ref}^{}" 2>/dev/null | tail -n 1 | awk '{print $1}')

  # Fallback to branch ref if not found as a tag
  if [[ -z "$sha" ]]; then
    sha=$(git ls-remote --heads "$url" "refs/heads/${ref}" 2>/dev/null | tail -n 1 | awk '{print $1}')
  fi

  SHA_CACHE["$cache_key"]="$sha"
  echo "$sha"
}

shopt -s nullglob
workflows=(.github/workflows/*.yml .github/workflows/*.yaml)
shopt -u nullglob

if [[ ${#workflows[@]} -eq 0 ]]; then
  echo "No workflow files found in .github/workflows/"
  exit 0
fi

for wf in "${workflows[@]}"; do
  echo "==> Processing ${wf}..."
  tmp_file=$(mktemp)
  updated=0

  while IFS= read -r line || [[ -n "$line" ]]; do
    prefix=""
    action=""
    current_sha=""
    ref=""
    suffix=""

    # Match already-pinned line: uses: owner/repo@<40-hex> # <tag>
    if [[ "$line" =~ ^([[:space:]]*-?[[:space:]]*uses:[[:space:]]*)([^@[:space:]]+)@([0-9a-fA-F]{40})[[:space:]]*#[[:space:]]*([^[:space:]]+)(.*)$ ]]; then
      prefix="${BASH_REMATCH[1]}"
      action="${BASH_REMATCH[2]}"
      current_sha="${BASH_REMATCH[3]}"
      ref="${BASH_REMATCH[4]}"
      suffix="${BASH_REMATCH[5]}"
    # Match unpinned tag/branch line: uses: owner/repo@<tag>
    elif [[ "$line" =~ ^([[:space:]]*-?[[:space:]]*uses:[[:space:]]*)([^@[:space:]]+)@([^[:space:]#]+)(.*)$ ]]; then
      prefix="${BASH_REMATCH[1]}"
      action="${BASH_REMATCH[2]}"
      ref="${BASH_REMATCH[3]}"
      suffix="${BASH_REMATCH[4]}"
    fi

    # Skip non-uses lines, local actions (./...), docker:// images, or bare SHAs without a tag comment
    if [[ -z "$action" || "$action" == ./* || "$action" == docker://* || "$ref" =~ ^[0-9a-fA-F]{40}$ ]]; then
      printf '%s\n' "$line" >> "$tmp_file"
      continue
    fi

    IFS='/' read -r owner repo _ <<< "$action"
    resolved_sha=$(resolve_sha "$owner" "$repo" "$ref")

    if [[ -z "$resolved_sha" ]]; then
      echo "  [Warn] Could not resolve ${action}@${ref}, leaving unchanged."
      printf '%s\n' "$line" >> "$tmp_file"
      continue
    fi

    if [[ "$current_sha" != "$resolved_sha" ]]; then
      echo "  [Pin]  ${action}@${ref} -> ${resolved_sha}"
      updated=1
    fi

    printf '%s%s@%s # %s%s\n' "$prefix" "$action" "$resolved_sha" "$ref" "$suffix" >> "$tmp_file"
  done < "$wf"

  if [[ "$updated" -eq 1 ]]; then
    cat "$tmp_file" > "$wf"
  fi
  rm -f "$tmp_file"
done

echo "Done! Review changes with 'git diff .github/workflows/'."
