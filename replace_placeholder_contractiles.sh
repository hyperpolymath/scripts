#!/bin/bash
# Replace placeholder/generic contractile files with fresh copies from rsr-template-repo

REPO_ROOT="/home/hyperpolymath/developer/repos"
ALL_REPOS_FILE="$REPO_ROOT/all_repos.txt"
TEMPLATE_DIR="$REPO_ROOT/rsr-template-repo/.machine_readable/contractiles"

replace_placeholders() {
    local repo_path="$1"
    local repo_name=$(basename "$repo_path")
    local contractiles_dir="$repo_path/.machine_readable/contractiles"
    
    if [ ! -d "$contractiles_dir" ]; then
        return 0
    fi
    
    has_placeholder=false
    for file in Intentfile Mustfile Trustfile Adjustfile; do
        a2ml_file="$contractiles_dir/${file}.a2ml"
        if [ -f "$a2ml_file" ]; then
            if grep -q "Placeholder\|Converted from\|{{ " "$a2ml_file" 2>/dev/null; then
                echo "Replacing placeholder: $repo_name/${file}.a2ml"
                cp "$TEMPLATE_DIR/${file}.a2ml" "$a2ml_file"
                has_placeholder=true
            fi
        fi
    done
    
    if [ "$has_placeholder" = true ]; then
        echo "  ✅ Replaced placeholders in $repo_name"
    fi
}

echo "Starting placeholder contractile replacement..."
echo ""

count=0
while IFS= read -r repo_path; do
    # Skip .lake/packages and .git directories
    if [[ "$repo_path" == *"\.lake/packages"* ]] || [[ "$repo_path" == *"/\.git/"* ]]; then
        continue
    fi
    
    # Check if it's a git repo
    if [ -d "$repo_path/.git" ]; then
        replace_placeholders "$repo_path"
        ((count++))
    fi
done < "$ALL_REPOS_FILE"

echo ""
echo "Processed $count repositories"
echo "Placeholder replacement complete!"
