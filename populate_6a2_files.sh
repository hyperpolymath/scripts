#!/bin/bash
# Populate 6a2/ files with proper content from rsr-template-repo

REPO_ROOT="/home/hyperpolymath/developer/repos"
ALL_REPOS_FILE="$REPO_ROOT/all_repos.txt"
TEMPLATE_DIR="$REPO_ROOT/rsr-template-repo/.machine_readable/6a2"

populate_6a2() {
    local repo_path="$1"
    local repo_name=$(basename "$repo_path")
    local a2ml_6a2_dir="$repo_path/.machine_readable/6a2"
    
    if [ ! -d "$a2ml_6a2_dir" ]; then
        return 0
    fi
    
    has_placeholder=false
    for file in META ECOSYSTEM STATE PLAYBOOK AGENTIC NEUROSYM; do
        a2ml_file="$a2ml_6a2_dir/${file}.a2ml"
        template_file="$TEMPLATE_DIR/${file}.a2ml"
        
        if [ -f "$template_file" ]; then
            # Check if file exists and is placeholder
            if [ -f "$a2ml_file" ]; then
                if grep -q "Placeholder for $repo_name" "$a2ml_file" 2>/dev/null; then
                    echo "Replacing placeholder: $repo_name/6a2/${file}.a2ml"
                    cp "$template_file" "$a2ml_file"
                    has_placeholder=true
                fi
            else
                # File doesn't exist, create it from template
                echo "Creating: $repo_name/6a2/${file}.a2ml"
                cp "$template_file" "$a2ml_file"
                has_placeholder=true
            fi
        fi
    done
    
    if [ "$has_placeholder" = true ]; then
        echo "  ✅ Updated 6a2/ files for $repo_name"
    fi
}

echo "Starting 6a2/ file population..."
echo ""

count=0
while IFS= read -r repo_path; do
    # Skip .lake/packages and .git directories
    if [[ "$repo_path" == *"\.lake/packages"* ]] || [[ "$repo_path" == *"/\.git/"* ]]; then
        continue
    fi
    
    # Check if it's a git repo
    if [ -d "$repo_path/.git" ]; then
        populate_6a2 "$repo_path"
        ((count++))
    fi
done < "$ALL_REPOS_FILE"

echo ""
echo "Processed $count repositories"
echo "6a2/ file population complete!"
