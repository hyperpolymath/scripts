#!/bin/bash
# SPDX-License-Identifier: AGPL-3.0-or-later
# Find repos with bad editorconfig-checker SHA

repos=$(gh repo list hyperpolymath --limit 50 --json name -q ".[].name")
BAD_SHA="8c9b118d446fce7e6410b6c0a3ce2f83bd04e97a"

for repo in $repos; do
  content=$(gh api "repos/hyperpolymath/$repo/contents/.github/workflows/quality.yml" -q '.content' 2>/dev/null | base64 -d 2>/dev/null)
  if echo "$content" | /usr/bin/grep -q "$BAD_SHA"; then
    echo "$repo"
  fi
done
