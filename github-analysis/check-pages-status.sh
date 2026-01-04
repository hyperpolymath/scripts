#!/bin/bash
# SPDX-License-Identifier: AGPL-3.0-or-later
# Check which repos have GitHub Pages enabled

echo "=== PAGES NOT ENABLED (will fail) ==="
repos=$(gh repo list hyperpolymath --limit 50 --json name -q ".[].name")

for repo in $repos; do
  # Check if Pages workflow exists
  has_workflow=$(gh api "repos/hyperpolymath/$repo/contents/.github/workflows/jekyll-gh-pages.yml" 2>/dev/null)
  if [ -n "$has_workflow" ]; then
    # Check if Pages is enabled
    pages_status=$(gh api "repos/hyperpolymath/$repo/pages" 2>/dev/null)
    if [ -z "$pages_status" ]; then
      echo "$repo - has workflow but Pages NOT enabled"
    fi
  fi
done
