#!/bin/bash

# boj-unify-repos.sh
# Safely attaches repositories to the BoJ Server / Casket build pipeline.
# Replaces legacy Jekyll workflows with the unified boj-build trigger.

WORKSPACE="/var$REPOS_DIR"

find "$WORKSPACE" -maxdepth 2 -name ".git" -type d | while read -r gitdir; do
    repo_path=$(dirname "$gitdir")
    repo_name=$(basename "$repo_path")
    
    # Skip boj-server itself and scripts
    if [ "$repo_name" == "boj-server" ] || [ "$repo_name" == "scripts" ]; then
        continue
    fi
    
    cd "$repo_path" || continue

    # 1. Initialize metadata structure
    mkdir -p .machine_readable/{anchors,policies,bot_directives}

    # 2. Add the ANCHOR.a2ml if it doesn't exist
    if [ ! -f ".machine_readable/anchors/ANCHOR.a2ml" ]; then
        cat <<ANCHOR > .machine_readable/anchors/ANCHOR.a2ml
# ⚓ ANCHOR: $repo_name
# This is the canonical authority for the $repo_name repository.

id: "org.hyperpolymath.$repo_name"
version: "1.0.0"
clade: "unknown"
status: "active"

# SSG Configuration (Unified boj-server build)
ssg:
  engine: "casket"
  output_dir: "public"
  boj_trigger: true
  cartridge: "ssg-mcp"

# Relationships
parents:
  - "org.hyperpolymath.boj-server"
ANCHOR
    fi

    # 3. Add the unified GitHub Action
    mkdir -p .github/workflows
    cat <<ACTION > .github/workflows/boj-build.yml
name: BoJ Server Build Trigger

on:
  push:
    branches: [ main, master ]
  workflow_dispatch:

jobs:
  trigger-boj:
    runs-on: ubuntu-latest
    steps:
      - name: Checkout
        uses: actions/checkout@v4

      - name: Trigger BoJ Server (Casket/ssg-mcp)
        run: |
          # Send a secure trigger to boj-server to build this repository
          curl -X POST "http://boj-server.local:7700/cartridges/ssg-mcp/build" \
            -H "Content-Type: application/json" \
            -d "{\"repo\": \"\${{ github.repository }}\", \"branch\": \"\${{ github.ref_name }}\", \"engine\": \"casket\"}"
        continue-on-error: true
ACTION

    echo "Unified: $repo_name"

done
