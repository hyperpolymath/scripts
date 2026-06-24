#!/bin/bash
# Script to add CODEOWNERS, MAINTAINERS.adoc, GOVERNANCE.adoc to repos that need them
# Usage: ./add_governance_to_repos.sh

set -e

REPO_ROOT="/home/hyperpolymath/developer/repos"
TEMPLATES_DIR="$REPO_ROOT/standards/templates"
ALL_REPOS_FILE="$REPO_ROOT/all_repos.txt"

# Function to add governance docs to a single repo
add_governance_to_repo() {
    local repo_path="$1"
    local repo_name=$(basename "$repo_path")
    
    echo "Processing: $repo_name"
    
    # Check if repo already has governance docs
    if [ -f "$repo_path/GOVERNANCE.adoc" ] && \
       [ -f "$repo_path/MAINTAINERS.adoc" ] && \
       [ -f "$repo_path/.github/CODEOWNERS" ]; then
        echo "  ✅ Already has all governance docs"
        return 0
    fi
    
    # Create .github directory if it doesn't exist
    mkdir -p "$repo_path/.github"
    
    # Copy CODEOWNERS
    if [ ! -f "$repo_path/.github/CODEOWNERS" ]; then
        cp "$TEMPLATES_DIR/CODEOWNERS" "$repo_path/.github/CODEOWNERS"
        echo "  Added: .github/CODEOWNERS"
    fi
    
    # Copy MAINTAINERS.adoc
    if [ ! -f "$repo_path/MAINTAINERS.adoc" ]; then
        cp "$TEMPLATES_DIR/MAINTAINERS.adoc" "$repo_path/MAINTAINERS.adoc"
        echo "  Added: MAINTAINERS.adoc"
    fi
    
    # Copy GOVERNANCE.adoc
    if [ ! -f "$repo_path/GOVERNANCE.adoc" ]; then
        cp "$TEMPLATES_DIR/GOVERNANCE.adoc" "$repo_path/GOVERNANCE.adoc"
        echo "  Added: GOVERNANCE.adoc"
    fi
    
    echo "  ✅ Governance docs added to $repo_name"
}

# Main logic
echo "Starting governance docs rollout..."
echo ""

# Read all repos from file
while IFS= read -r repo_path; do
    # Skip .lake/packages and .git directories
    if [[ "$repo_path" == *"\.lake/packages"* ]] || [[ "$repo_path" == *"/\.git/"* ]]; then
        continue
    fi
    
    # Check if it's a git repo
    if [ -d "$repo_path/.git" ]; then
        add_governance_to_repo "$repo_path"
    fi
done < "$ALL_REPOS_FILE"

echo ""
echo "Governance docs rollout complete!"
