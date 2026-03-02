#!/bin/bash
# SPDX-License-Identifier: PMPL-1.0-or-later
# Sync all git repos in the canonical hyperpolymath repos directory.
# Fetches all remotes, then attempts a fast-forward pull.
# Reports errors per-repo without stopping the batch.

REPO_DIR="$HOME/Documents/hyperpolymath-repos"

cd "$REPO_DIR" || { echo "ERROR: Cannot cd to $REPO_DIR"; exit 1; }

ok=0
warn=0
fail=0

for repo in */; do
    if [ -d "$repo/.git" ]; then
        echo -n "$repo: "
        cd "$repo"

        # Fetch all remotes, capture errors but don't abort
        fetch_err=$(git fetch --all -q 2>&1)
        fetch_rc=$?

        # Attempt pull (fast-forward only to avoid surprise merges)
        pull_err=$(git pull --ff-only -q 2>&1)
        pull_rc=$?

        if [ $fetch_rc -eq 0 ] && [ $pull_rc -eq 0 ]; then
            echo "OK"
            ((ok++))
        elif [ $pull_rc -ne 0 ]; then
            echo "PULL-FAIL: $pull_err"
            ((warn++))
        else
            echo "FETCH-FAIL: $fetch_err"
            ((fail++))
        fi

        cd ..
    fi
done

echo ""
echo "--- Summary ---"
echo "OK: $ok  Warnings: $warn  Failures: $fail"
