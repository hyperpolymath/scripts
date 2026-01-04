#!/bin/bash
# SPDX-License-Identifier: AGPL-3.0-or-later
# Check repos with local changes

repos=(
  asdfghj bebop-v-ffi disinfo-nesy-detector disinfo-nsai-detector
  doit-ssg drift-ssg flathub flight-ssg forth-estate-ssg
  git-eco-bot idaptik-dlc-reversible idaptiky january-ssg kith
  macports-ports nano-aida nano-ruber parallel-press-ssg poly-db-mcp
  poly-iac-mcp poly-observability-mcp poly-secret-mcp project-wharf
  rhodium-standard-repositories-fix robot-repo-bot shift-ssg
  sinople-wharf svalinn-ecosystem synapse-release template-repo
  union-policy-parsers webforge-ssg winget-pkgs wordpress-wharf
  wp-audit-toolkit yocaml-ssg zotero-nsai
)

for repo in "${repos[@]}"; do
  if [ -d "$HOME/repos/$repo/.git" ]; then
    echo "=== $repo ==="
    cd "$HOME/repos/$repo"
    git status --short 2>/dev/null | head -8
    echo ""
  fi
done
