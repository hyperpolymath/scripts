#!/bin/bash
# SPDX-License-Identifier: AGPL-3.0-or-later
# Analyze GitHub workflow failures across hyperpolymath org

repos=$(gh repo list hyperpolymath --limit 50 --json name -q ".[].name")

for repo in $repos; do
  gh run list --repo "hyperpolymath/$repo" --status failure --limit 5 --json name -q ".[].name" 2>/dev/null
done | sort | uniq -c | sort -rn | head -20
