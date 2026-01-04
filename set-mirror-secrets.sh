#!/bin/bash
# SPDX-License-Identifier: AGPL-3.0-or-later
# set-mirror-secrets.sh - Set mirror secrets and variables on all repos

set -e

GITLAB_KEY="$HOME/.ssh/gitlab_mirror"
BITBUCKET_KEY="$HOME/.ssh/bitbucket_mirror"
CODEBERG_KEY="$HOME/.ssh/codeberg_mirror"
SOURCEHUT_KEY="$HOME/.ssh/sourcehut_mirror"

# Get all repos
REPOS=$(gh repo list hyperpolymath --limit 200 --json name --jq '.[].name')

echo "Found $(echo "$REPOS" | wc -l) repos"
echo

SUCCESS=0
FAILED=0

for repo in $REPOS; do
    echo "Processing: $repo"

    # Set secrets
    if gh secret set GITLAB_SSH_KEY --repo "hyperpolymath/$repo" < "$GITLAB_KEY" 2>/dev/null && \
       gh secret set BITBUCKET_SSH_KEY --repo "hyperpolymath/$repo" < "$BITBUCKET_KEY" 2>/dev/null && \
       gh secret set CODEBERG_SSH_KEY --repo "hyperpolymath/$repo" < "$CODEBERG_KEY" 2>/dev/null && \
       gh secret set SOURCEHUT_SSH_KEY --repo "hyperpolymath/$repo" < "$SOURCEHUT_KEY" 2>/dev/null; then

        # Set variables
        gh variable set GITLAB_MIRROR_ENABLED --repo "hyperpolymath/$repo" --body "true" 2>/dev/null || true
        gh variable set BITBUCKET_MIRROR_ENABLED --repo "hyperpolymath/$repo" --body "true" 2>/dev/null || true
        gh variable set CODEBERG_MIRROR_ENABLED --repo "hyperpolymath/$repo" --body "true" 2>/dev/null || true
        gh variable set SOURCEHUT_MIRROR_ENABLED --repo "hyperpolymath/$repo" --body "true" 2>/dev/null || true

        echo "  ✓ Done"
        SUCCESS=$((SUCCESS + 1))
    else
        echo "  ✗ Failed"
        FAILED=$((FAILED + 1))
    fi
done

echo
echo "=========================================="
echo "Summary: $SUCCESS succeeded, $FAILED failed"
