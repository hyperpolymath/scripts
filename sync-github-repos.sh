#!/bin/bash
# SPDX-License-Identifier: AGPL-3.0-or-later
# Sync all GitHub repos locally

set -euo pipefail

REPO_DIR="${HOME}/repos"
mkdir -p "$REPO_DIR"

echo "=== Fetching repo list from GitHub ==="
REPOS=$(gh repo list --limit 200 --json name,sshUrl --jq '.[] | "\(.name)|\(.sshUrl)"')

TOTAL=$(echo "$REPOS" | wc -l)
CLONED=0
PULLED=0
FAILED=0

echo "Found $TOTAL repos on GitHub"
echo ""

while IFS='|' read -r name url; do
    target="${REPO_DIR}/${name}"

    if [[ -d "$target/.git" ]]; then
        echo "[PULL] $name"
        if git -C "$target" pull --ff-only 2>/dev/null; then
            ((PULLED++))
        else
            echo "  -> Pull failed, trying fetch..."
            git -C "$target" fetch --all 2>/dev/null || true
            ((PULLED++))
        fi
    else
        echo "[CLONE] $name"
        if git clone --depth 1 "$url" "$target" 2>/dev/null; then
            ((CLONED++))
        else
            echo "  -> Clone failed: $name"
            ((FAILED++))
        fi
    fi
done <<< "$REPOS"

echo ""
echo "=== Summary ==="
echo "Cloned: $CLONED"
echo "Pulled: $PULLED"
echo "Failed: $FAILED"
echo "Total:  $TOTAL"
