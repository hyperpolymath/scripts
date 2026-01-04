#!/bin/bash
# SPDX-License-Identifier: AGPL-3.0-or-later
# Sync all repos in ~/repos

cd ~/repos || exit 1

for repo in */; do
    if [ -d "$repo/.git" ]; then
        echo -n "$repo: "
        cd "$repo"
        if git fetch --all -q 2>/dev/null && git pull -q 2>/dev/null; then
            echo "✓"
        else
            echo "⚠ (has local changes or conflicts)"
        fi
        cd ..
    fi
done
