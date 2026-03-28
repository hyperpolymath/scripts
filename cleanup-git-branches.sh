#!/bin/bash

# cleanup-git-branches.sh
# Safely prunes and deletes merged branches across all repositories in the workspace.
# Excludes protected branches: main, master, gh-pages, and branches containing 'docs'.

WORKSPACE="/var$REPOS_DIR"
PROTECTED_PATTERN="^(main|master|gh-pages|.*docs.*)$"
REMOTE_EXCLUDE_PATTERN="^(origin/HEAD|origin/main|origin/master|origin/gh-pages|.*docs.*)$"

echo "Starting workspace-wide Git branch cleanup..."

find "$WORKSPACE" -maxdepth 2 -name ".git" -type d | while read -r gitdir; do
    repo_path=$(dirname "$gitdir")
    repo_name=$(basename "$repo_path")
    cd "$repo_path" || continue

    echo "--- Checking $repo_name ---"

    # 1. Sync remote metadata and prune deleted tracking branches
    # This fixes "broken ref" warnings.
    git fetch origin --prune >/dev/null 2>&1

    # 2. Determine default branch
    main_branch=$(git symbolic-ref refs/remotes/origin/HEAD 2>/dev/null | sed 's@^refs/remotes/origin/@@')
    [ -z "$main_branch" ] && main_branch=$(git branch --list main master | head -n 1 | sed 's/* //')
    [ -z "$main_branch" ] && main_branch="main"

    # 3. Cleanup LOCAL merged branches
    # grep -Ev filters out the current branch (*), the default branch, and protected branches.
    merged_locals=$(git branch --merged "$main_branch" | grep -v "^\*" | grep -Ev "$PROTECTED_PATTERN" | tr -d ' ')

    if [ -n "$merged_locals" ]; then
        for branch in $merged_locals; do
            echo "  Deleting merged local branch: $branch"
            git branch -d "$branch" >/dev/null 2>&1
        done
    fi

    # 4. Cleanup REMOTE merged branches (optional/safe mode)
    # We only delete remote branches that have been merged into origin/main.
    merged_remotes=$(git branch -r --merged "origin/$main_branch" | grep "origin/" | grep -Ev "$REMOTE_EXCLUDE_PATTERN" | sed 's/origin\///' | tr -d ' ')

    if [ -n "$merged_remotes" ]; then
        for branch in $merged_remotes; do
            # Only delete if it's clearly a personal feature branch (optional)
            echo "  Note: Remote branch '$branch' is merged on GitHub. (Skipping auto-delete for safety)."
        done
    fi

done

echo "Cleanup complete."
