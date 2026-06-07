#!/bin/bash
# Remove old contractile subdirectories (adjust/, bust/, intend/, must/, trust/) 
# when new flat structure exists in .machine_readable/contractiles/

REPO_ROOT="/home/hyperpolymath/developer/repos"
ALL_REPOS_FILE="$REPO_ROOT/all_repos.txt"

remove_old_subdirs() {
    local repo_path="$1"
    local repo_name=$(basename "$repo_path")
    
    # Check if new flat structure exists
    if [ -d "$repo_path/.machine_readable/contractiles" ]; then
        # Check for old subdirectories in contractiles/ (if it exists)
        if [ -d "$repo_path/contractiles" ]; then
            for subdir in adjust bust dust intend must trust; do
                if [ -d "$repo_path/contractiles/$subdir" ]; then
                    echo "Removing old: $repo_name/contractiles/$subdir/"
                    rm -rf "$repo_path/contractiles/$subdir"
                fi
            done
            # Check if contractiles/ is now empty
            if [ -z "$(ls -A "$repo_path/contractiles/" 2>/dev/null)" ]; then
                echo "Removing empty: $repo_name/contractiles/"
                rm -rf "$repo_path/contractiles"
            fi
        fi
        
        # Also check for old subdirectories in .machine_readable/contractiles/
        for subdir in adjust bust dust intend must trust; do
            if [ -d "$repo_path/.machine_readable/contractiles/$subdir" ]; then
                echo "Removing old: $repo_name/.machine_readable/contractiles/$subdir/"
                rm -rf "$repo_path/.machine_readable/contractiles/$subdir"
            fi
        done
    fi
}

echo "Starting old contractile subdirectory removal..."
echo ""

count=0
while IFS= read -r repo_path; do
    # Skip .lake/packages and .git directories
    if [[ "$repo_path" == *"\.lake/packages"* ]] || [[ "$repo_path" == *"/\.git/"* ]]; then
        continue
    fi
    
    # Check if it's a git repo
    if [ -d "$repo_path/.git" ]; then
        remove_old_subdirs "$repo_path"
        ((count++))
    fi
done < "$ALL_REPOS_FILE"

echo ""
echo "Processed $count repositories"
echo "Old subdirectory removal complete!"
