#!/bin/bash
# SPDX-License-Identifier: AGPL-3.0-or-later
# Initialize wiki with standard structure for a repo

REPO="${1:-}"

if [[ -z "$REPO" ]]; then
    echo "Usage: $0 <repo-name>"
    exit 1
fi

WIKI_DIR="/tmp/wiki-init-$$"
mkdir -p "$WIKI_DIR"
cd "$WIKI_DIR" || exit 1

echo "Initializing wiki for hyperpolymath/$REPO..."

# Clone wiki repo (creates if doesn't exist when you push)
if ! git clone "git@github.com:hyperpolymath/$REPO.wiki.git" wiki 2>/dev/null; then
    # Wiki doesn't exist yet, create it
    mkdir wiki
    cd wiki
    git init
    git remote add origin "git@github.com:hyperpolymath/$REPO.wiki.git"
else
    cd wiki
fi

# Get repo description for context
DESCRIPTION=$(gh repo view "hyperpolymath/$REPO" --json description --jq '.description // "No description available"' 2>/dev/null)

# Create Home.md
cat > Home.md << EOF
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

# Create _Sidebar.md for navigation
cat > _Sidebar.md << EOF
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

# Create _Footer.md
cat > _Footer.md << EOF
---
*[View on GitHub](https://github.com/hyperpolymath/$REPO) | [Report Issue](https://github.com/hyperpolymath/$REPO/issues/new) | [Discussions](https://github.com/hyperpolymath/$REPO/discussions)*
EOF

# Create Getting-Started.md
cat > Getting-Started.md << EOF
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

# Create FAQ.md
cat > FAQ.md << EOF
# Frequently Asked Questions

## General

### What is $REPO?

$DESCRIPTION

### Where can I get help?

- [GitHub Discussions](https://github.com/hyperpolymath/$REPO/discussions) - Community help
- [Issues](https://github.com/hyperpolymath/$REPO/issues) - Bug reports

## Troubleshooting

*Add common issues and solutions here.*
EOF

# Create Architecture.md
cat > Architecture.md << EOF
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

# Create Contributing.md
cat > Contributing.md << EOF
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

Use [GitHub Discussions](https://github.com/hyperpolymath/$REPO/discussions) for questions.
EOF

# Create API-Reference.md
cat > API-Reference.md << EOF
# API Reference

*This page documents the public API of $REPO.*

## Overview

See the project source code and inline documentation for detailed API information.

## Functions/Methods

*Document public functions and methods here.*

## Configuration

*Document configuration options here.*
EOF

# Commit and push
git add -A
if git diff --cached --quiet 2>/dev/null; then
    echo "No changes to commit"
else
    git commit -m "Initialize wiki with standard structure"
    if git push -u origin master 2>/dev/null || git push -u origin main 2>/dev/null; then
        echo "Wiki initialized successfully for $REPO"
    else
        echo "Failed to push wiki for $REPO"
    fi
fi

# Cleanup
cd /
rm -rf "$WIKI_DIR"
