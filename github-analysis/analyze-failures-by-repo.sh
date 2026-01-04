#!/bin/bash
# SPDX-License-Identifier: AGPL-3.0-or-later
# Get repos failing for each major workflow type

echo "=== WORKFLOW SECURITY LINTER FAILURES ==="
repos=$(gh repo list hyperpolymath --limit 50 --json name -q ".[].name")
for repo in $repos; do
  count=$(gh run list --repo "hyperpolymath/$repo" --status failure --limit 10 --json name -q '[.[] | select(.name == "Workflow Security Linter")] | length' 2>/dev/null)
  if [[ "$count" -gt 0 ]]; then
    echo "$repo: $count"
  fi
done

echo ""
echo "=== CODE QUALITY FAILURES ==="
for repo in $repos; do
  count=$(gh run list --repo "hyperpolymath/$repo" --status failure --limit 10 --json name -q '[.[] | select(.name == "Code Quality")] | length' 2>/dev/null)
  if [[ "$count" -gt 0 ]]; then
    echo "$repo: $count"
  fi
done

echo ""
echo "=== CODEQL SECURITY ANALYSIS FAILURES ==="
for repo in $repos; do
  count=$(gh run list --repo "hyperpolymath/$repo" --status failure --limit 10 --json name -q '[.[] | select(.name == "CodeQL Security Analysis")] | length' 2>/dev/null)
  if [[ "$count" -gt 0 ]]; then
    echo "$repo: $count"
  fi
done

echo ""
echo "=== OPENSSF SCORECARD ENFORCER FAILURES ==="
for repo in $repos; do
  count=$(gh run list --repo "hyperpolymath/$repo" --status failure --limit 10 --json name -q '[.[] | select(.name == "OpenSSF Scorecard Enforcer")] | length' 2>/dev/null)
  if [[ "$count" -gt 0 ]]; then
    echo "$repo: $count"
  fi
done

echo ""
echo "=== MIRROR TO GIT FORGES FAILURES ==="
for repo in $repos; do
  count=$(gh run list --repo "hyperpolymath/$repo" --status failure --limit 10 --json name -q '[.[] | select(.name == "Mirror to Git Forges")] | length' 2>/dev/null)
  if [[ "$count" -gt 0 ]]; then
    echo "$repo: $count"
  fi
done

echo ""
echo "=== GITHUB PAGES FAILURES ==="
for repo in $repos; do
  count=$(gh run list --repo "hyperpolymath/$repo" --status failure --limit 10 --json name -q '[.[] | select(.name == "GitHub Pages")] | length' 2>/dev/null)
  if [[ "$count" -gt 0 ]]; then
    echo "$repo: $count"
  fi
done

echo ""
echo "=== SECRET-SCANNER FAILURES ==="
for repo in $repos; do
  count=$(gh run list --repo "hyperpolymath/$repo" --status failure --limit 10 --json name -q '[.[] | select(.name == ".github/workflows/secret-scanner.yml")] | length' 2>/dev/null)
  if [[ "$count" -gt 0 ]]; then
    echo "$repo: $count"
  fi
done
