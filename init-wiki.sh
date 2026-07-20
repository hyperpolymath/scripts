#!/bin/bash
# SPDX-License-Identifier: MPL-2.0
# Initialize (seed) a repository wiki with a standard structure.
#
# GitHub has no REST/GraphQL API to create a wiki or its first page: the backing
# `<repo>.wiki.git` repo is created lazily, only once a page is saved. This script
# is the estate work-around — it enables the wiki, then seeds it over git.
#
# Usage:
#   init-wiki.sh <repo>                # owner defaults to $WIKI_OWNER or "hyperpolymath"
#   init-wiki.sh <owner>/<repo>        # explicit owner (e.g. metadatastician/paint-type)
#
# Auth:
#   - If GH_TOKEN or GITHUB_TOKEN is set (CI / GitHub App installation token), the
#     wiki remote uses HTTPS token auth. Otherwise it falls back to SSH.
#
# Idempotent: existing wiki pages are never overwritten — only missing pages are added.

set -euo pipefail

ARG="${1:-}"
if [[ -z "$ARG" ]]; then
    echo "Usage: $0 <repo>|<owner>/<repo>" >&2
    exit 1
fi

# Parse owner/repo (owner optional).
if [[ "$ARG" == */* ]]; then
    OWNER="${ARG%%/*}"
    REPO="${ARG##*/}"
else
    OWNER="${WIKI_OWNER:-hyperpolymath}"
    REPO="$ARG"
fi
SLUG="$OWNER/$REPO"

# Token-aware wiki remote (App/CI token → HTTPS; else SSH).
TOKEN="${GH_TOKEN:-${GITHUB_TOKEN:-}}"
if [[ -n "$TOKEN" ]]; then
    WIKI_REMOTE="https://x-access-token:${TOKEN}@github.com/${SLUG}.wiki.git"
else
    WIKI_REMOTE="git@github.com:${SLUG}.wiki.git"
fi

WIKI_DIR="$(mktemp -d "${TMPDIR:-/tmp}/wiki-init-XXXXXX")"
cleanup() { rm -rf "$WIKI_DIR"; }
trap cleanup EXIT

echo "Initializing wiki for ${SLUG}..."

# Step 1 — ensure the wiki feature is enabled (no-op if already on). Without this,
# the .wiki.git remote may not exist server-side and the push below 404s.
if ! gh api -X PATCH "repos/${SLUG}" -F has_wiki=true >/dev/null 2>&1; then
    echo "warning: could not confirm has_wiki=true via API (insufficient scope?); continuing" >&2
fi

cd "$WIKI_DIR"

# Step 2 — clone the wiki repo; if it has never been initialized, start it locally.
if git clone "$WIKI_REMOTE" wiki 2>/dev/null; then
    cd wiki
else
    echo "Wiki repo not yet initialized server-side; creating first commit locally."
    mkdir wiki && cd wiki
    git init -q
    git remote add origin "$WIKI_REMOTE"
fi

DESCRIPTION=$(gh repo view "$SLUG" --json description --jq '.description // "No description available"' 2>/dev/null || echo "No description available")

# write_page <filename> — reads heredoc from stdin; writes only if the page is
# absent, so re-runs never clobber human-edited wiki pages.
write_page() {
    local file="$1"
    if [[ -e "$file" ]]; then
        echo "  skip (exists): $file"
        cat >/dev/null   # drain heredoc
        return
    fi
    cat > "$file"
    echo "  add: $file"
}

write_page Home.md << EOF
# $REPO

$DESCRIPTION

## Quick Links

- [User Guide](_Sidebar#for-users)
- [Developer Guide](_Sidebar#for-developers)
- [FAQ](FAQ)

## Getting Started

See the [Getting Started](Getting-Started) guide to begin using this project.

## Contributing

See the [Contributing](Contributing) guide for developer information.
EOF

write_page _Sidebar.md << EOF
### $REPO Wiki

**For Users**
- [Home](Home)
- [Getting Started](Getting-Started)
- [FAQ](FAQ)

**For Developers**
- [Architecture](Architecture)
- [Contributing](Contributing)
- [API Reference](API-Reference)
EOF

write_page _Footer.md << EOF
---
*[View on GitHub](https://github.com/$SLUG) | [Report Issue](https://github.com/$SLUG/issues/new) | [Discussions](https://github.com/$SLUG/discussions)*
EOF

write_page Getting-Started.md << EOF
# Getting Started

## Prerequisites

Check the project README for prerequisites.

## Installation

See the main repository README for installation instructions.

## First Steps

1. Clone the repository
2. Install dependencies
3. Run the project

## Next Steps

- Check the [FAQ](FAQ) for common questions
- Read the [Architecture](Architecture) for understanding the codebase
EOF

write_page FAQ.md << EOF
# Frequently Asked Questions

## General

### What is $REPO?

$DESCRIPTION

### Where can I get help?

- [GitHub Discussions](https://github.com/$SLUG/discussions) - Community help
- [Issues](https://github.com/$SLUG/issues) - Bug reports

## Troubleshooting

*Add common issues and solutions here.*
EOF

write_page Architecture.md << EOF
# Architecture

## Overview

This document describes the architecture of $REPO.

## Directory Structure

See the repository for the current directory structure.

## Key Components

*Document key components and their interactions here.*

## Design Decisions

See the project's META.scm or ADR files for architectural decisions.
EOF

write_page Contributing.md << EOF
# Contributing

Thank you for your interest in contributing to $REPO!

## Development Setup

1. Fork the repository
2. Clone your fork
3. Create a feature branch
4. Make your changes
5. Submit a pull request

## Code Standards

- Follow the project's existing code style
- Add tests for new functionality
- Update documentation as needed

## Pull Request Process

1. Ensure all tests pass
2. Update relevant documentation
3. Request review from maintainers

## Getting Help

Use [GitHub Discussions](https://github.com/$SLUG/discussions) for questions.
EOF

write_page API-Reference.md << EOF
# API Reference

*This page documents the public API of $REPO.*

## Overview

See the project source code and inline documentation for detailed API information.

## Functions/Methods

*Document public functions and methods here.*

## Configuration

*Document configuration options here.*
EOF

# Step 3 — commit and push. Wikis default to the `master` branch; detect the current one.
git add -A
if git diff --cached --quiet 2>/dev/null; then
    echo "No changes to commit (wiki already seeded)."
    exit 0
fi
git commit -q -m "Initialize wiki with standard structure"

BRANCH="$(git symbolic-ref --short HEAD 2>/dev/null || echo master)"
if PUSH_ERR="$(git push -u origin "$BRANCH" 2>&1)"; then
    echo "Wiki initialized successfully for ${SLUG}."
    exit 0
fi

# Push failed — surface the real reason and the lazy-init fallback.
echo "Failed to push wiki for ${SLUG}." >&2
echo "$PUSH_ERR" >&2
if echo "$PUSH_ERR" | grep -qiE 'not found|does not exist'; then
    cat >&2 <<MSG

The wiki repo has never been initialized server-side, and pushing does not create
it on this account/repo. GitHub only creates <repo>.wiki.git after the FIRST page
is saved through the web UI — there is no API for it (see the open feature request).

Fallback: create the first page once, then re-run this script:
  1. Open https://github.com/${SLUG}/wiki  and click "Create the first page" -> Save.
  2. Re-run: $0 ${SLUG}
Or drive that single UI step with the estate browser-automation agent.
MSG
fi
exit 1
