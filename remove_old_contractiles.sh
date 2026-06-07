#!/bin/bash
# Remove old contractiles/ directories that are now duplicated by .machine_readable/contractiles/

REPO_ROOT="/home/hyperpolymath/developer/repos"
ALL_REPOS_FILE="$REPO_ROOT/all_repos.txt"

remove_old_contractiles() {
    local repo_path="$1"
    local repo_name=$(basename "$repo_path")
    
    # Check if .machine_readable/contractiles exists (new structure)
    if [ -d "$repo_path/.machine_readable/contractiles" ]; then
        # Check if old contractiles/ exists in root
        if [ -d "$repo_path/contractiles" ]; then
            echo "Removing old contractiles/ from: $repo_name"
            rm -rf "$repo_path/contractiles"
            echo "  ✅ Removed old contractiles/"
        fi
    fi
}

echo "Starting old contractiles/ removal..."
echo ""

count=0
while IFS= read -r repo_path; do
    # Skip .lake/packages and .git directories
    if [[ "$repo_path" == *"\.lake/packages"* ]] || [[ "$repo_path" == *"/\.git/"* ]]; then
        continue
    fi
    
    # Check if it's a git repo
    if [ -d "$repo_path/.git" ]; then
        remove_old_contractiles "$repo_path"
        ((count++))
    fi
done < "$ALL_REPOS_FILE"

echo ""
echo "Processed $count repositories"
echo "Old contractiles/ removal complete!"
