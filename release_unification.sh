#!/bin/bash

# release_unification.sh
# Performs a mass commit and push for the Big Unification across all repositories.

WORKSPACE="/var$REPOS_DIR"
COMMIT_MSG="chore: Big Unification — attach to BoJ Server / Casket architecture"

echo "Starting mass push for the Big Unification..."

find "$WORKSPACE" -maxdepth 2 -name ".git" -type d | while read -r gitdir; do
    repo_path=$(dirname "$gitdir")
    repo_name=$(basename "$repo_path")
    
    # Skip boj-server (already pushed) and scripts
    if [ "$repo_name" == "boj-server" ] || [ "$repo_name" == "scripts" ]; then
        continue
    fi
    
    cd "$repo_path" || continue

    echo "--- Processing $repo_name ---"

    # 1. Check for changes
    if [ -n "$(git status --porcelain)" ]; then
        echo "  Committing changes..."
        git add .
        git commit -m "$COMMIT_MSG"
    else
        echo "  No changes to commit."
    fi

    # 2. Push to origin
    BRANCH=$(git rev-parse --abbrev-ref HEAD)
    echo "  Pushing $repo_name ($BRANCH)..."
    if ! git push origin "$BRANCH" --force; then
        echo "  Push failed, trying --set-upstream..."
        git push --set-upstream origin "$BRANCH" --force
    fi

done

echo "Mass release complete."
