#!/bin/bash
WORKSPACE="/var$REPOS_DIR"

find "$WORKSPACE" -maxdepth 2 -name ".git" -type d | while read -r gitdir; do
    repo_path=$(dirname "$gitdir")
    repo_name=$(basename "$repo_path")
    
    if [ "$repo_name" == "boj-server" ] || [ "$repo_name" == "scripts" ]; then
        continue
    fi
    
    workflow="$repo_path/.github/workflows/boj-build.yml"
    
    if [ -f "$workflow" ]; then
        # Update the curl URL and the JSON payload to match the standard Class 1 'invoke' pattern
        sed -i 's|/cartridges/ssg-mcp/build|/cartridges/ssg-mcp/invoke|g' "$workflow"
        sed -i 's|"repo": "|"tool": "build", "args": "{\\"repo\\": \\"|g' "$workflow"
        sed -i 's|"}"|\\"}"}|g' "$workflow"
        
        echo "Fixed Class 1 URL for: $repo_name"
    fi
done
