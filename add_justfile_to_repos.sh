#!/bin/bash
# Script to add Justfile to repos that don't have it
# Also creates hardlink in .machine_readable/contractiles/

REPO_ROOT="/home/hyperpolymath/developer/repos"
ALL_REPOS_FILE="$REPO_ROOT/all_repos.txt"
TEMPLATE_JUSTFILE="$REPO_ROOT/rsr-template-repo/Justfile"

add_justfile() {
    local repo_path="$1"
    local repo_name=$(basename "$repo_path")
    
    echo "Processing: $repo_name"
    
    # Check if Justfile already exists
    if [ -f "$repo_path/Justfile" ]; then
        echo "  ✅ Already has Justfile"
        # Create hardlink if it doesn't exist
        local contractiles_dir="$repo_path/.machine_readable/contractiles"
        if [ ! -f "$contractiles_dir/Justfile" ] && [ -d "$contractiles_dir" ]; then
            ln "$repo_path/Justfile" "$contractiles_dir/Justfile" 2>/dev/null && \
                echo "  Added: hardlink to Justfile in .machine_readable/contractiles/"
        fi
        return 0
    fi
    
    # Copy template Justfile
    cp "$TEMPLATE_JUSTFILE" "$repo_path/Justfile"
    echo "  Added: Justfile"
    
    # Create .machine_readable/contractiles if it doesn't exist
    mkdir -p "$repo_path/.machine_readable/contractiles"
    
    # Create hardlink
    ln "$repo_path/Justfile" "$repo_path/.machine_readable/contractiles/Justfile" 2>/dev/null && \
        echo "  Added: hardlink to Justfile in .machine_readable/contractiles/"
    
    echo "  ✅ Justfile added to $repo_name"
}

# Main logic
echo "Starting Justfile rollout..."
echo ""

count=0
while IFS= read -r repo_path; do
    # Skip .lake/packages and .git directories
    if [[ "$repo_path" == *"\.lake/packages"* ]] || [[ "$repo_path" == *"/\.git/"* ]]; then
        continue
    fi
    
    # Check if it's a git repo
    if [ -d "$repo_path/.git" ]; then
        add_justfile "$repo_path"
        ((count++))
    fi
done < "$ALL_REPOS_FILE"

echo ""
echo "Processed $count repositories"
echo "Justfile rollout complete!"
