#!/bin/bash
# SPDX-License-Identifier: AGPL-3.0-or-later
# Find repos using 'actions' language in CodeQL (which is invalid)

repos=$(gh repo list hyperpolymath --limit 50 --json name -q ".[].name")

for repo in $repos; do
  content=$(gh api "repos/hyperpolymath/$repo/contents/.github/workflows/codeql.yml" -q '.content' 2>/dev/null | base64 -d 2>/dev/null)
  if echo "$content" | /usr/bin/grep -q "language:.*actions"; then
    echo "$repo"
  fi
done
