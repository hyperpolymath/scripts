#!/bin/bash
# Script to ensure contractiles structure exists in all repos
# Creates .machine_readable/ with proper directory structure and files

REPO_ROOT="/home/hyperpolymath/developer/repos"
ALL_REPOS_FILE="$REPO_ROOT/all_repos.txt"
TEMPLATE_REPO="$REPO_ROOT/rsr-template-repo"

# Source directory for template files
TEMPLATE_CONTRACTILES="$TEMPLATE_REPO/.machine_readable/contractiles"

ensure_contractiles() {
    local repo_path="$1"
    local repo_name=$(basename "$repo_path")
    
    echo "Processing: $repo_name"
    
    # Create .machine_readable directory if it doesn't exist
    mkdir -p "$repo_path/.machine_readable"
    
    # Create 6a2 directory
    mkdir -p "$repo_path/.machine_readable/6a2/anchors"
    
    # Create contractiles directory
    mkdir -p "$repo_path/.machine_readable/contractiles/bust"
    mkdir -p "$repo_path/.machine_readable/contractiles/dust"
    
    # Create self-validating directory
    mkdir -p "$repo_path/.machine_readable/self-validating/k9-svc"
    mkdir -p "$repo_path/.machine_readable/self-validating/examples"
    
    # Create bot_directives directory
    mkdir -p "$repo_path/.machine_readable/bot_directives"
    
    # Copy template contractile files if they don't exist
    local contractiles_dir="$repo_path/.machine_readable/contractiles"
    
    if [ ! -f "$contractiles_dir/Intentfile.a2ml" ]; then
        cp "$TEMPLATE_CONTRACTILES/Intentfile.a2ml" "$contractiles_dir/Intentfile.a2ml"
        echo "  Copied: Intentfile.a2ml"
    fi
    
    if [ ! -f "$contractiles_dir/Mustfile.a2ml" ]; then
        cp "$TEMPLATE_CONTRACTILES/Mustfile.a2ml" "$contractiles_dir/Mustfile.a2ml"
        echo "  Copied: Mustfile.a2ml"
    fi
    
    if [ ! -f "$contractiles_dir/Trustfile.a2ml" ]; then
        cp "$TEMPLATE_CONTRACTILES/Trustfile.a2ml" "$contractiles_dir/Trustfile.a2ml"
        echo "  Copied: Trustfile.a2ml"
    fi
    
    if [ ! -f "$contractiles_dir/Adjustfile.a2ml" ]; then
        cp "$TEMPLATE_CONTRACTILES/Adjustfile.a2ml" "$contractiles_dir/Adjustfile.a2ml"
        echo "  Copied: Adjustfile.a2ml"
    fi
    
    if [ ! -f "$contractiles_dir/bust/Bustfile.a2ml" ]; then
        cp "$TEMPLATE_CONTRACTILES/bust/Bustfile.a2ml" "$contractiles_dir/bust/Bustfile.a2ml"
        echo "  Copied: bust/Bustfile.a2ml"
    fi
    
    if [ ! -f "$contractiles_dir/dust/Dustfile.a2ml" ]; then
        cp "$TEMPLATE_CONTRACTILES/dust/Dustfile.a2ml" "$contractiles_dir/dust/Dustfile.a2ml"
        echo "  Copied: dust/Dustfile.a2ml"
    fi
    
    # Create placeholder 6a2 files if they don't exist
    local a2ml_6a2_dir="$repo_path/.machine_readable/6a2"
    
    for file in META ECOSYSTEM STATE PLAYBOOK AGENTIC NEUROSYM; do
        if [ ! -f "$a2ml_6a2_dir/${file}.a2ml" ]; then
            # Create minimal placeholder
            cat > "$a2ml_6a2_dir/${file}.a2ml" << EOF
# SPDX-License-Identifier: MPL-2.0
# ${file}.a2ml - Placeholder for ${repo_name}
# TODO: Replace with actual content for this repository

@abstract:
Placeholder ${file}.a2ml for ${repo_name}. Customize with project-specific content.
@end

# Add project-specific ${file} definitions here
EOF
            echo "  Created: 6a2/${file}.a2ml (placeholder)"
        fi
    done
    
    echo "  ✅ Structure created for $repo_name"
}

# Main logic
echo "Starting contractiles structure rollout..."
echo ""

count=0
while IFS= read -r repo_path; do
    # Skip .lake/packages and .git directories
    if [[ "$repo_path" == *"\.lake/packages"* ]] || [[ "$repo_path" == *"/\.git/"* ]]; then
        continue
    fi
    
    # Check if it's a git repo
    if [ -d "$repo_path/.git" ]; then
        ensure_contractiles "$repo_path"
        ((count++))
    fi
done < "$ALL_REPOS_FILE"

echo ""
echo "Processed $count repositories"
echo "Contractiles structure rollout complete!"
