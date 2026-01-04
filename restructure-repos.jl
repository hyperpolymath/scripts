#!/usr/bin/env julia
# SPDX-License-Identifier: MPL-2.0
# SPDX-FileCopyrightText: 2025 Hyperpolymath
#
# Repository Restructuring Script
# Implements the Hyperpolymath standard directory structure

using Dates

const REPOS_DIR = "/var/home/hyper/repos"

# =============================================================================
# Directory Structure Constants
# =============================================================================

const NEW_STRUCTURE = """
Repository Standard Structure:

ROOT/
├── README.adoc                    # Primary documentation (human)
├── ROADMAP.adoc                   # Project roadmap (human)
├── LICENSE.txt                    # Symlink to licenses/MPL-2.0-EN.txt (GitHub compat)
├── SECURITY.md                    # Security policy (GitHub requires .md)
├── CONTRIBUTING.md                # Contribution guide (GitHub requires .md)
├── CODE_OF_CONDUCT.md             # Code of conduct (GitHub requires .md)
├── ANCHOR.scm                     # [TEMPORARY] Drop-in intervention file
│
├── licenses/                      # All license files
│   ├── MPL-2.0-EN.txt             # MPL-2.0 in English
│   ├── MPL-2.0-NL.txt             # MPL-2.0 in Dutch
│   ├── PALIMPSEST-EN.txt          # Palimpsest philosophy in English
│   └── PALIMPSEST-NL.txt          # Palimpsest philosophy in Dutch
│
├── tasks/                         # Build system files (visible, not hidden)
│   ├── Justfile                   # Task runner recipes
│   └── Mustfile                   # Deployment state contract
│
├── docs/
│   ├── machines/
│   │   └── MACHINE-READABLE-STRUCTURE.adoc
│   └── [other human documentation in .adoc]
│
├── .github/
│   ├── FUNDING.yml                # Sponsors configuration
│   └── workflows/                 # CI/CD workflows
│
└── .machine_readable/
    ├── 6scm/                      # SCM Format Family
    │   ├── META.scm
    │   ├── STATE.scm
    │   ├── ECOSYSTEM.scm
    │   ├── PLAYBOOK.scm
    │   ├── AGENTIC.scm
    │   └── NEUROSYM.scm
    │
    ├── anchoring/                 # Processed ANCHOR.scm files
    │
    ├── reproducibility/           # Reproducible builds
    │   ├── guix.scm
    │   └── flake.nix
    │
    └── config/                    # NCL configuration files
"""

# =============================================================================
# Templates
# =============================================================================

const README_ADOC_TEMPLATE = """
// SPDX-License-Identifier: MPL-2.0
// SPDX-FileCopyrightText: 2025 Hyperpolymath
= {{PROJECT}}
:doctype: book
:toc: left
:toclevels: 3
:icons: font

image:https://img.shields.io/badge/license-MPL--2.0-blue.svg[MPL-2.0,link="https://mozilla.org/MPL/2.0/"]
image:https://img.shields.io/badge/philosophy-Palimpsest-purple.svg[Palimpsest,link="https://github.com/hyperpolymath/palimpsest-license"]

== Overview

{{PROJECT}} is part of the https://github.com/hyperpolymath[Hyperpolymath] ecosystem.

== Quick Start

[source,bash]
----
git clone https://github.com/hyperpolymath/{{PROJECT}}.git
cd {{PROJECT}}
just deps
just run
----

== Documentation

* link:docs/[Documentation]
* link:ROADMAP.adoc[Roadmap]
* https://github.com/hyperpolymath/{{PROJECT}}/wiki[Wiki]

== License

This project is licensed under https://mozilla.org/MPL/2.0/[MPL-2.0] with the https://github.com/hyperpolymath/palimpsest-license[Palimpsest] philosophical framework.

== Contributing

See link:CONTRIBUTING.md[CONTRIBUTING.md] for guidelines.
"""

const ROADMAP_ADOC_TEMPLATE = """
// SPDX-License-Identifier: MPL-2.0
// SPDX-FileCopyrightText: 2025 Hyperpolymath
= {{PROJECT}} Roadmap
:doctype: article
:toc: left
:icons: font

== Overview

This document outlines the development roadmap for {{PROJECT}}.

== Current Phase

See `.machine_readable/6scm/STATE.scm` for current project state.

== Milestones

=== v1.0 - Initial Release

* [ ] Core functionality
* [ ] Documentation
* [ ] Test coverage
* [ ] CI/CD pipeline

=== Future

* [ ] Additional features
* [ ] Performance optimization
* [ ] Extended integrations

== Contributing

See link:CONTRIBUTING.md[CONTRIBUTING.md] for how to contribute to the roadmap.
"""

const JUSTFILE_TEMPLATE = """
# SPDX-License-Identifier: MPL-2.0
# SPDX-FileCopyrightText: 2025 Hyperpolymath
# Justfile for {{PROJECT}}
# Run 'just' to see available recipes

set shell := ["bash", "-uc"]
set positional-arguments

# Default recipe - show help
default:
    @just --list

# =============================================================================
# Development
# =============================================================================

# Install dependencies
deps:
    @echo "Installing dependencies..."

# Build the project
build:
    @echo "Building..."

# Run the project
run *args:
    @echo "Running..."

# =============================================================================
# Quality
# =============================================================================

# Run all quality checks
quality: fmt lint test

# Format code
fmt:
    @echo "Formatting..."

# Lint code
lint:
    @echo "Linting..."

# Run tests
test:
    @echo "Testing..."

# =============================================================================
# CI/CD
# =============================================================================

# Full CI pipeline
ci: quality build

# Validate RSR compliance
validate-rsr:
    @echo "Validating RSR compliance..."

# =============================================================================
# Utilities
# =============================================================================

# Clean build artifacts
clean:
    @echo "Cleaning..."

# Show project info
info:
    @echo "Project: {{PROJECT}}"
    @echo "Structure: Hyperpolymath Standard"
"""

const MUSTFILE_TEMPLATE = """
; SPDX-License-Identifier: MPL-2.0
; SPDX-FileCopyrightText: 2025 Hyperpolymath
; Mustfile - Deployment State Contract for {{PROJECT}}
;
; This file declares what MUST be true for successful deployment.
; See: https://github.com/hyperpolymath/mustfile

(mustfile
  (version "1.0")
  (project "{{PROJECT}}")

  (preconditions
    (tests-pass #t)
    (lint-pass #t)
    (build-success #t))

  (postconditions
    (deployed #t)
    (health-check #t))

  (invariants
    (no-secrets-in-repo #t)
    (license-present #t)
    (documentation-current #t)))
"""

const FUNDING_YML_TEMPLATE = """
# SPDX-License-Identifier: MPL-2.0
# SPDX-FileCopyrightText: 2025 Hyperpolymath
github: [hyperpolymath]
"""

# 6SCM Templates (updated paths)
const META_SCM_TEMPLATE = """
; SPDX-License-Identifier: MPL-2.0
; SPDX-FileCopyrightText: 2025 Hyperpolymath
; META.scm - Architecture Decisions and Development Practices
; Spec: https://github.com/hyperpolymath/meta-scm

(meta
  (version "1.0")
  (schema-version "1.0.0")
  (project "{{PROJECT}}")

  (architecture-decisions
    (adr-001
      (title "Repository Structure")
      (status "accepted")
      (date "{{DATE}}")
      (context "Need standardized structure across all repos")
      (decision "Use Hyperpolymath standard with .machine_readable/")
      (consequences "Consistent tooling, clean root directory")))

  (development-practices
    (languages
      (allowed '(rescript deno rust gleam nickel guile julia))
      (banned '(typescript nodejs go python-general)))
    (build-system "justfile-mustfile-nickel")
    (documentation "adoc-for-humans scm-for-machines")
    (licensing "mpl-2.0-with-palimpsest"))

  (repository-requirements
    (required-files
      '("README.adoc" "ROADMAP.adoc" "LICENSE.txt"
        "SECURITY.md" "CONTRIBUTING.md" "CODE_OF_CONDUCT.md"))
    (required-directories
      '("tasks" "docs/machines" ".machine_readable/6scm"
        ".machine_readable/anchoring" ".machine_readable/reproducibility"))
    (6scm-location ".machine_readable/6scm/")
    (sha-preference
      (current "sha1")
      (preferred "sha256")
      (migrate-when "github-supports-sha256"))))
"""

const STATE_SCM_TEMPLATE = """
; SPDX-License-Identifier: MPL-2.0
; SPDX-FileCopyrightText: 2025 Hyperpolymath
; STATE.scm - Project State Tracking
; Location: .machine_readable/6scm/STATE.scm

(state
  (version "1.0")
  (project "{{PROJECT}}")
  (updated "{{DATE}}")

  (current-phase "active")
  (completion-percentage 0)

  (recent-changes
    ((date "{{DATE}}")
     (action "restructured")
     (details "Applied Hyperpolymath standard structure")))

  (next-actions
    ((priority "high")
     (action "implement-core-functionality"))))
"""

const ECOSYSTEM_SCM_TEMPLATE = """
; SPDX-License-Identifier: MPL-2.0
; SPDX-FileCopyrightText: 2025 Hyperpolymath
; ECOSYSTEM.scm - Ecosystem Positioning
; Location: .machine_readable/6scm/ECOSYSTEM.scm

(ecosystem
  (version "1.0")
  (project "{{PROJECT}}")
  (updated "{{DATE}}")

  (position-in-ecosystem
    (organization "hyperpolymath")
    (category "{{CATEGORY}}")
    (role "{{ROLE}}"))

  (related-projects
    ((name "standards")
     (relationship "follows")
     (url "https://github.com/hyperpolymath/standards")))

  (satellite-management
    (note "Check for -ssg, -mcp, -scm, -ffi satellites")
    (last-checked "{{DATE}}")
    (satellites '())))
"""

const PLAYBOOK_SCM_TEMPLATE = """
; SPDX-License-Identifier: MPL-2.0
; SPDX-FileCopyrightText: 2025 Hyperpolymath
; PLAYBOOK.scm - Executable Operational Plans
; Location: .machine_readable/6scm/PLAYBOOK.scm
; Spec: https://github.com/hyperpolymath/playbook-scm

(playbook
  (version "1.0")
  (project "{{PROJECT}}")

  (plays
    (setup
      (description "Initial project setup")
      (steps
        '("Clone repository"
          "Run 'just deps'"
          "Run 'just build'")))

    (development
      (description "Development workflow")
      (steps
        '("Create feature branch"
          "Make changes"
          "Run 'just quality'"
          "Commit and push"
          "Create PR")))

    (release
      (description "Release process")
      (steps
        '("Update version"
          "Update STATE.scm"
          "Tag release"
          "Push tags")))))
"""

const AGENTIC_SCM_TEMPLATE = """
; SPDX-License-Identifier: MPL-2.0
; SPDX-FileCopyrightText: 2025 Hyperpolymath
; AGENTIC.scm - AI Agent Interaction Patterns
; Location: .machine_readable/6scm/AGENTIC.scm
; Spec: https://github.com/hyperpolymath/agentic-scm

(agentic
  (version "1.0")
  (project "{{PROJECT}}")

  (agent-permissions
    (read-allowed #t)
    (write-allowed #t)
    (execute-allowed #t))

  (context-files
    '(".claude/CLAUDE.md"
      ".machine_readable/6scm/META.scm"
      ".machine_readable/6scm/STATE.scm"))

  (intervention-protocol
    (anchor-location "root")
    (archive-location ".machine_readable/anchoring/")
    (naming-convention "ANCHOR-[purpose]-[date]-[superintendent].scm")))
"""

const NEUROSYM_SCM_TEMPLATE = """
; SPDX-License-Identifier: MPL-2.0
; SPDX-FileCopyrightText: 2025 Hyperpolymath
; NEUROSYM.scm - Symbolic Semantics and Proof Obligations
; Location: .machine_readable/6scm/NEUROSYM.scm
; Spec: https://github.com/hyperpolymath/neurosym-scm

(neurosym
  (version "1.0")
  (project "{{PROJECT}}")

  (symbolic-bindings
    (project-name "{{PROJECT}}")
    (organization "hyperpolymath"))

  (proof-obligations
    (license-compliance #t)
    (security-policy #t)
    (documentation-complete #t))

  (semantic-constraints
    (no-banned-languages #t)
    (spdx-headers-present #t)))
"""

const GUIX_SCM_TEMPLATE = """
; SPDX-License-Identifier: MPL-2.0
; SPDX-FileCopyrightText: 2025 Hyperpolymath
; guix.scm - GNU Guix Package Definition
; Location: .machine_readable/reproducibility/guix.scm

(use-modules (guix packages)
             (guix gexp)
             (guix git-download)
             ((guix licenses) #:prefix license:))

(package
  (name "{{PROJECT}}")
  (version "0.1.0")
  (source (local-file "../../.." "{{PROJECT}}-source"
                      #:recursive? #t))
  (build-system gnu-build-system)
  (synopsis "{{PROJECT}} - Part of Hyperpolymath ecosystem")
  (description "{{PROJECT}} from the Hyperpolymath organization.")
  (home-page "https://github.com/hyperpolymath/{{PROJECT}}")
  (license license:mpl2.0))
"""

const FLAKE_NIX_TEMPLATE = """
# SPDX-License-Identifier: MPL-2.0
# SPDX-FileCopyrightText: 2025 Hyperpolymath
# flake.nix - Nix Flake (fallback for non-Guix environments)
# Location: .machine_readable/reproducibility/flake.nix
{
  description = "{{PROJECT}} - Part of Hyperpolymath ecosystem";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    flake-utils.url = "github:numtide/flake-utils";
  };

  outputs = { self, nixpkgs, flake-utils }:
    flake-utils.lib.eachDefaultSystem (system:
      let
        pkgs = nixpkgs.legacyPackages.\${system};
      in
      {
        devShells.default = pkgs.mkShell {
          buildInputs = with pkgs; [
            just
            deno
          ];
        };
      }
    );
}
"""

# =============================================================================
# Helper Functions
# =============================================================================

function get_date()
    return Dates.format(now(), "yyyy-mm-dd")
end

function replace_placeholders(template::String, project::String; category="tool", role="utility")
    result = replace(template, "{{PROJECT}}" => project)
    result = replace(result, "{{PROJECT_UPPER}}" => uppercase(replace(project, "-" => "_")))
    result = replace(result, "{{DATE}}" => get_date())
    result = replace(result, "{{CATEGORY}}" => category)
    result = replace(result, "{{ROLE}}" => role)
    return result
end

function ensure_dir(path::String)
    if !isdir(path)
        mkpath(path)
        println("  Created: $path")
    end
end

function write_if_missing(filepath::String, content::String; overwrite=false)
    if !isfile(filepath) || overwrite
        write(filepath, content)
        println("  Written: $filepath")
        return true
    else
        println("  Exists:  $filepath")
        return false
    end
end

function move_file(src::String, dst::String)
    if isfile(src)
        ensure_dir(dirname(dst))
        mv(src, dst, force=true)
        println("  Moved: $src -> $dst")
        return true
    end
    return false
end

function delete_file(filepath::String)
    if isfile(filepath)
        rm(filepath)
        println("  Deleted: $filepath")
        return true
    end
    return false
end

# =============================================================================
# Restructuring Functions
# =============================================================================

function restructure_repo(repo_path::String; dry_run=false)
    project = basename(repo_path)
    println("\n=== Restructuring: $project ===")

    if dry_run
        println("  [DRY RUN - no changes will be made]")
    end

    # 1. Create directory structure
    println("\n  Creating directory structure...")
    dirs = [
        joinpath(repo_path, "tasks"),
        joinpath(repo_path, "docs", "machines"),
        joinpath(repo_path, ".machine_readable", "6scm"),
        joinpath(repo_path, ".machine_readable", "anchoring"),
        joinpath(repo_path, ".machine_readable", "reproducibility"),
        joinpath(repo_path, ".machine_readable", "config"),
        joinpath(repo_path, ".github"),
    ]

    if !dry_run
        for dir in dirs
            ensure_dir(dir)
        end
    end

    # 2. Move existing SCM files to .machine_readable/6scm/
    println("\n  Moving SCM files to .machine_readable/6scm/...")
    scm_files = ["META.scm", "STATE.scm", "ECOSYSTEM.scm",
                 "PLAYBOOK.scm", "AGENTIC.scm", "NEUROSYM.scm"]

    for scm in scm_files
        # Check root
        root_path = joinpath(repo_path, scm)
        # Check .meta directory
        meta_path = joinpath(repo_path, ".meta", scm)
        # Check old .machine_readable
        old_mr_path = joinpath(repo_path, ".machine_readable", scm)

        dest_path = joinpath(repo_path, ".machine_readable", "6scm", scm)

        if !dry_run
            if isfile(root_path) && !isfile(dest_path)
                move_file(root_path, dest_path)
            elseif isfile(meta_path) && !isfile(dest_path)
                move_file(meta_path, dest_path)
            elseif isfile(old_mr_path) && !isfile(dest_path)
                move_file(old_mr_path, dest_path)
            end
        end
    end

    # 3. Move Justfile/Mustfile to tasks/
    println("\n  Moving build files to tasks/...")
    build_files = [
        ("justfile", "Justfile"),
        ("Justfile", "Justfile"),
        ("mustfile", "Mustfile"),
        ("Mustfile", "Mustfile"),
    ]

    if !dry_run
        for (src_name, dst_name) in build_files
            src_path = joinpath(repo_path, src_name)
            dst_path = joinpath(repo_path, "tasks", dst_name)
            if isfile(src_path) && !isfile(dst_path)
                move_file(src_path, dst_path)
            end
        end
    end

    # 4. Move reproducibility files
    println("\n  Moving reproducibility files...")
    repro_files = [
        ("guix.scm", "guix.scm"),
        ("flake.nix", "flake.nix"),
        ("flake.lock", "flake.lock"),
    ]

    if !dry_run
        for (src_name, dst_name) in repro_files
            src_path = joinpath(repo_path, src_name)
            dst_path = joinpath(repo_path, ".machine_readable", "reproducibility", dst_name)
            if isfile(src_path) && !isfile(dst_path)
                move_file(src_path, dst_path)
            end
        end
    end

    # 5. Remove Jekyll files
    println("\n  Removing Jekyll files...")
    jekyll_files = [
        "_config.yml",
        "Gemfile",
        "Gemfile.lock",
        ".github/workflows/jekyll.yml",
        ".github/workflows/jekyll-gh-pages.yml",
    ]

    if !dry_run
        for jf in jekyll_files
            delete_file(joinpath(repo_path, jf))
        end
    end

    # 6. Create/update required files
    println("\n  Creating required files...")

    if !dry_run
        # Root files
        write_if_missing(joinpath(repo_path, "README.adoc"),
                        replace_placeholders(README_ADOC_TEMPLATE, project))
        write_if_missing(joinpath(repo_path, "ROADMAP.adoc"),
                        replace_placeholders(ROADMAP_ADOC_TEMPLATE, project))

        # tasks/
        write_if_missing(joinpath(repo_path, "tasks", "Justfile"),
                        replace_placeholders(JUSTFILE_TEMPLATE, project))
        write_if_missing(joinpath(repo_path, "tasks", "Mustfile"),
                        replace_placeholders(MUSTFILE_TEMPLATE, project))

        # .github/
        write_if_missing(joinpath(repo_path, ".github", "FUNDING.yml"),
                        FUNDING_YML_TEMPLATE)

        # docs/machines/
        write_if_missing(joinpath(repo_path, "docs", "machines", "MACHINE-READABLE-STRUCTURE.adoc"),
                        read("/var/home/hyper/scripts/templates/docs/machines/MACHINE-READABLE-STRUCTURE.adoc", String))

        # 6SCM files
        write_if_missing(joinpath(repo_path, ".machine_readable", "6scm", "META.scm"),
                        replace_placeholders(META_SCM_TEMPLATE, project))
        write_if_missing(joinpath(repo_path, ".machine_readable", "6scm", "STATE.scm"),
                        replace_placeholders(STATE_SCM_TEMPLATE, project))
        write_if_missing(joinpath(repo_path, ".machine_readable", "6scm", "ECOSYSTEM.scm"),
                        replace_placeholders(ECOSYSTEM_SCM_TEMPLATE, project))
        write_if_missing(joinpath(repo_path, ".machine_readable", "6scm", "PLAYBOOK.scm"),
                        replace_placeholders(PLAYBOOK_SCM_TEMPLATE, project))
        write_if_missing(joinpath(repo_path, ".machine_readable", "6scm", "AGENTIC.scm"),
                        replace_placeholders(AGENTIC_SCM_TEMPLATE, project))
        write_if_missing(joinpath(repo_path, ".machine_readable", "6scm", "NEUROSYM.scm"),
                        replace_placeholders(NEUROSYM_SCM_TEMPLATE, project))

        # Reproducibility files
        write_if_missing(joinpath(repo_path, ".machine_readable", "reproducibility", "guix.scm"),
                        replace_placeholders(GUIX_SCM_TEMPLATE, project))
        write_if_missing(joinpath(repo_path, ".machine_readable", "reproducibility", "flake.nix"),
                        replace_placeholders(FLAKE_NIX_TEMPLATE, project))
    end

    # 7. Remove duplicate/old files
    println("\n  Cleaning up old files...")
    old_files = [
        ".meta",  # Old directory
        "README.md",  # If README.adoc exists
        "ROADMAP.md",  # If ROADMAP.adoc exists
    ]

    if !dry_run
        # Remove .meta directory if empty or SCM files moved
        meta_dir = joinpath(repo_path, ".meta")
        if isdir(meta_dir) && isempty(readdir(meta_dir))
            rm(meta_dir, recursive=true)
            println("  Removed empty: $meta_dir")
        end
    end

    println("\n  ✓ Restructuring complete for $project")
end

# =============================================================================
# Main Entry Point
# =============================================================================

function main()
    args = ARGS

    if isempty(args)
        println("Usage: julia restructure-repos.jl [--dry-run] [--repo NAME] [--all]")
        println("")
        println("Options:")
        println("  --dry-run    Preview changes without applying")
        println("  --repo NAME  Process single repository")
        println("  --all        Process all repositories in $REPOS_DIR")
        return
    end

    dry_run = "--dry-run" in args

    if "--all" in args
        repos = filter(d -> isdir(joinpath(REPOS_DIR, d, ".git")), readdir(REPOS_DIR))
        println("Processing $(length(repos)) repositories...")
        for repo in repos
            restructure_repo(joinpath(REPOS_DIR, repo), dry_run=dry_run)
        end
    elseif "--repo" in args
        idx = findfirst(x -> x == "--repo", args)
        if idx !== nothing && idx < length(args)
            repo_name = args[idx + 1]
            repo_path = joinpath(REPOS_DIR, repo_name)
            if isdir(repo_path)
                restructure_repo(repo_path, dry_run=dry_run)
            else
                println("Repository not found: $repo_path")
            end
        end
    end
end

main()
