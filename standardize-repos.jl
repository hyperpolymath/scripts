# SPDX-License-Identifier: AGPL-3.0-or-later
# Repository Standardization Script
# Ensures all repos have required dotfiles, SCM files, and Justfile-Mustfile system

using Dates

const REPOS_DIR = expanduser("~/repos")
const DRY_RUN = "--dry-run" in ARGS
const SINGLE_REPO = let
    for arg in ARGS
        if !startswith(arg, "-")
            break
        end
    end
    result = nothing
    for arg in ARGS
        if !startswith(arg, "-")
            result = arg
            break
        end
    end
    result
end

# Satellite relationship patterns
const SATELLITE_PATTERNS = Dict(
    "-ssg" => "poly-ssg",
    "-mcp" => "poly-mcps",
    "-scm" => "standards",
    "-ffi" => "zig-polyglot-extract-ffi"
)

# ============================================================================
# Templates
# ============================================================================

const GITIGNORE = """
# SPDX-License-Identifier: AGPL-3.0-or-later
# RSR-compliant .gitignore

# OS & Editor
.DS_Store
Thumbs.db
*.swp
*.swo
*~
.idea/
.vscode/

# Build
/target/
/_build/
/build/
/dist/
/out/
/zig-out/
/zig-cache/

# Dependencies
/node_modules/
/vendor/
/deps/
/.elixir_ls/

# Rust
# Cargo.lock  # Keep for binaries

# Elixir
/cover/
/doc/
*.ez
erl_crash.dump

# Julia
*.jl.cov
*.jl.mem
/Manifest.toml

# ReScript
/lib/bs/
/.bsb.lock

# Python (SaltStack only)
__pycache__/
*.py[cod]
.venv/

# Ada/SPARK
*.ali
/obj/
/bin/

# Haskell
/.stack-work/
/dist-newstyle/

# Chapel
*.chpl.tmp.*

# Secrets
.env
.env.*
*.pem
*.key
secrets/

# Test/Coverage
/coverage/
htmlcov/

# Logs
*.log
/logs/

# Temp
/tmp/
*.tmp
*.bak
"""

const GITATTRIBUTES = """
# SPDX-License-Identifier: AGPL-3.0-or-later
# RSR-compliant .gitattributes

* text=auto eol=lf

# Source
*.rs    text eol=lf diff=rust
*.ex    text eol=lf diff=elixir
*.exs   text eol=lf diff=elixir
*.jl    text eol=lf
*.res   text eol=lf
*.resi  text eol=lf
*.ada   text eol=lf diff=ada
*.adb   text eol=lf diff=ada
*.ads   text eol=lf diff=ada
*.hs    text eol=lf
*.chpl  text eol=lf
*.scm   text eol=lf
*.ncl   text eol=lf
*.nix   text eol=lf
*.zig   text eol=lf

# Docs
*.md    text eol=lf diff=markdown
*.adoc  text eol=lf
*.txt   text eol=lf

# Data
*.json  text eol=lf
*.yaml  text eol=lf
*.yml   text eol=lf
*.toml  text eol=lf

# Config
.gitignore     text eol=lf
.gitattributes text eol=lf
.editorconfig  text eol=lf
.tool-versions text eol=lf
justfile       text eol=lf
Makefile       text eol=lf
Containerfile  text eol=lf

# Scripts
*.sh   text eol=lf

# Binary
*.png   binary
*.jpg   binary
*.gif   binary
*.pdf   binary
*.woff2 binary
*.zip   binary
*.gz    binary

# Lock files
Cargo.lock  text eol=lf -diff
flake.lock  text eol=lf -diff
"""

const EDITORCONFIG = """
# SPDX-License-Identifier: AGPL-3.0-or-later
# https://editorconfig.org

root = true

[*]
charset = utf-8
end_of_line = lf
indent_size = 2
indent_style = space
insert_final_newline = true
trim_trailing_whitespace = true

[*.md]
trim_trailing_whitespace = false

[*.adoc]
trim_trailing_whitespace = false

[*.rs]
indent_size = 4

[*.zig]
indent_size = 4

[*.ada]
indent_size = 3

[*.adb]
indent_size = 3

[*.ads]
indent_size = 3

[*.ex]
indent_size = 2

[*.exs]
indent_size = 2

[*.hs]
indent_size = 2

[*.res]
indent_size = 2

[*.resi]
indent_size = 2

[*.ncl]
indent_size = 2

[*.scm]
indent_size = 2

[*.nix]
indent_size = 2

[Justfile]
indent_style = space
indent_size = 4

[justfile]
indent_style = space
indent_size = 4

[Makefile]
indent_style = tab
"""

const TOOL_VERSIONS = """
# SPDX-License-Identifier: AGPL-3.0-or-later
# asdf version management
# Run 'asdf install' to install all tools

# Primary runtime
deno 2.1.4

# Build tools
just 1.36.0
"""

const META_REQUIRED_FILES = """
# Required Repository Files

The following files **MUST** be present and kept up-to-date in every repository:

## Mandatory Dotfiles

| File | Purpose |
|------|---------|
| `.gitignore` | Exclude build artifacts, secrets, and temp files |
| `.gitattributes` | Enforce LF line endings and diff settings |
| `.editorconfig` | Consistent editor settings across IDEs |
| `.tool-versions` | asdf version pinning for reproducible builds |

## Mandatory SCM Files

| File | Purpose |
|------|---------|
| `META.scm` | Architecture decisions, development practices |
| `STATE.scm` | Project state, phase, milestones |
| `ECOSYSTEM.scm` | Ecosystem positioning, related projects |
| `PLAYBOOK.scm` | Executable plans, procedures |
| `AGENTIC.scm` | AI agent operational gating |
| `NEUROSYM.scm` | Symbolic semantics, proof obligations |

## Build System

| File | Purpose |
|------|---------|
| `justfile` | Task runner (replaces Makefile) |
| `Mustfile` | Deployment state contract |

**IMPORTANT**: Makefiles are FORBIDDEN. Use `just` for all tasks.

## Validation

These files are checked by:
- CI workflow validation
- Pre-commit hooks (when configured)
- Repository standardization scripts

## Updates

When updating these files:
1. Use templates from `rsr-template-repo` as reference
2. Ensure SPDX license header is present
3. Test changes locally before pushing
4. Keep language-specific sections relevant to the repo

## See Also

- [RSR (Rhodium Standard Repositories)](https://github.com/hyperpolymath/rhodium-standard-repositories)
- [Mustfile Specification](https://github.com/hyperpolymath/mustfile)
- [SCM Format Family](https://github.com/hyperpolymath/meta-scm)
"""

function meta_scm_template(project::String)
    return """
;; SPDX-License-Identifier: AGPL-3.0-or-later
;; META.scm - Architecture Decisions and Development Practices
;; $(project)

(define-module ($(replace(project, "-" => "_")) meta)
  #:export (architecture-decisions
            development-practices
            design-rationale
            repository-requirements))

(define architecture-decisions
  '())

(define development-practices
  '((code-style
     (formatter . "deno fmt")
     (linter . "deno lint"))
    (versioning
     (scheme . "Semantic Versioning 2.0.0"))
    (documentation
     (format . "AsciiDoc"))
    (security
     (spdx-required . #t)
     (sha-pinning . #t))))

(define design-rationale
  '())

;; IMPORTANT: These requirements must always be kept up to date
(define repository-requirements
  '((mandatory-dotfiles
     ".gitignore"
     ".gitattributes"
     ".editorconfig"
     ".tool-versions")
    (mandatory-scm-files
     "META.scm"
     "STATE.scm"
     "ECOSYSTEM.scm"
     "PLAYBOOK.scm"
     "AGENTIC.scm"
     "NEUROSYM.scm")
    (build-system
     (task-runner . "justfile")
     (state-contract . "Mustfile")
     (forbidden . ("Makefile")))
    (meta-directory
     ".meta/REQUIRED-FILES.md")
    (satellite-management
     (check-frequency . "on-new-repo")
     (sync-ecosystem . #t)
     (note . "When adding satellites, update ECOSYSTEM.scm in both parent and satellite"))))
"""
end

function state_scm_template(project::String)
    today = Dates.format(now(), "yyyy-mm-dd")
    return """
;; SPDX-License-Identifier: AGPL-3.0-or-later
;; STATE.scm - Project State and Progress
;; $(project)

(define-module ($(replace(project, "-" => "_")) state)
  #:export (metadata
            project-context
            current-position
            route-to-mvp
            blockers-and-issues
            critical-next-actions
            session-history))

(define metadata
  '((version . "1.0.0")
    (schema-version . "1.0")
    (created . "$(today)")
    (updated . "$(today)")
    (project . "$(project)")
    (repo . "hyperpolymath/$(project)")))

(define project-context
  '((name . "$(project)")
    (tagline . "")
    (tech-stack . ())))

(define current-position
  '((phase . "planning")
    (overall-completion . 0)
    (components . ())
    (working-features . ())))

(define route-to-mvp
  '((milestones . ())))

(define blockers-and-issues
  '((critical . ())
    (high . ())
    (medium . ())
    (low . ())))

(define critical-next-actions
  '((immediate . ())
    (this-week . ())
    (this-month . ())))

(define session-history
  '())
"""
end

function detect_satellite_parent(project::String)
    for (suffix, parent) in SATELLITE_PATTERNS
        if endswith(project, suffix) && project != parent
            return parent
        end
    end
    return nothing
end

function detect_satellites(repo_path::String, project::String)
    satellites = String[]
    # Check for satellite-repos directory
    sat_dir = joinpath(repo_path, "satellite-repos")
    if isdir(sat_dir)
        for entry in readdir(sat_dir)
            if isdir(joinpath(sat_dir, entry))
                push!(satellites, entry)
            end
        end
    end
    return satellites
end

function ecosystem_scm_template(project::String; parent=nothing, satellites=String[])
    parent_section = if !isnothing(parent)
        """
  (satellite-of . "$(parent)")
  (satellite-relationship
   (parent-repo . "hyperpolymath/$(parent)")
   (role . "implementation")
   (sync-required . #t))
"""
    else
        ""
    end

    satellites_section = if !isempty(satellites)
        sat_list = join(["\"$(s)\"" for s in satellites], " ")
        """
  (satellites . ($(sat_list)))
  (satellite-note . "Satellite repos must be kept in sync. Check ECOSYSTEM.scm in each satellite.")
"""
    else
        ""
    end

    return """
;; SPDX-License-Identifier: AGPL-3.0-or-later
;; ECOSYSTEM.scm - Ecosystem Positioning
;; $(project)
;;
;; IMPORTANT: Satellite relationships must be kept up to date.
;; When adding/removing satellites, update this file and the satellite's ECOSYSTEM.scm.

(ecosystem
  (version . "1.0.0")
  (name . "$(project)")
  (type . "component")
  (purpose . "")

  (position-in-ecosystem
   (category . "")
   (layer . ""))
$(parent_section)$(satellites_section)
  (related-projects . ())

  (what-this-is . ())

  (what-this-is-not . ())

  ;; Maintenance note: Review satellite relationships when:
  ;; - Adding new repos with similar suffix patterns (-ssg, -mcp, -scm, -ffi)
  ;; - Removing or archiving repos
  ;; - Changing the portfolio structure
  (maintenance-checks
   (satellite-sync . "Ensure parent and satellite ECOSYSTEM.scm files are consistent")
   (portfolio-review . "Verify all satellites are listed in parent repo")))
"""
end

function playbook_scm_template(project::String)
    return """
;; SPDX-License-Identifier: AGPL-3.0-or-later
;; PLAYBOOK.scm - Executable Plans and Procedures
;; $(project)

(define-module ($(replace(project, "-" => "_")) playbook)
  #:export (playbook))

(define playbook
  '((version . "1.0.0")
    (name . "$(project)")
    (procedures . ())
    (alerts . ())
    (runbooks . ())))
"""
end

function agentic_scm_template(project::String)
    return """
;; SPDX-License-Identifier: AGPL-3.0-or-later
;; AGENTIC.scm - AI Agent Operational Gating
;; $(project)

(define-module ($(replace(project, "-" => "_")) agentic)
  #:export (agentic-config))

(define agentic-config
  '((version . "1.0.0")
    (name . "$(project)")
    (entropy-budget . 0.3)
    (allowed-operations . (read analyze suggest))
    (forbidden-operations . ())
    (gating-rules . ())))
"""
end

function neurosym_scm_template(project::String)
    return """
;; SPDX-License-Identifier: AGPL-3.0-or-later
;; NEUROSYM.scm - Symbolic Semantics and Proof Obligations
;; $(project)

(define-module ($(replace(project, "-" => "_")) neurosym)
  #:export (neurosym-config))

(define neurosym-config
  '((version . "1.0.0")
    (name . "$(project)")
    (proof-obligations . ())
    (invariants . ())
    (type-constraints . ())))
"""
end

function justfile_template(project::String)
    return """
# SPDX-License-Identifier: AGPL-3.0-or-later
# $(project) - Justfile
# https://just.systems/man/en/

set shell := ["bash", "-uc"]
set dotenv-load := true
set positional-arguments := true

# Project metadata
project := "$(project)"
version := "0.1.0"

# ═══════════════════════════════════════════════════════════════════════════════
# DEFAULT & HELP
# ═══════════════════════════════════════════════════════════════════════════════

# Show all available recipes
default:
    @just --list --unsorted

# Show project info
info:
    @echo "Project: {{project}}"
    @echo "Version: {{version}}"

# ═══════════════════════════════════════════════════════════════════════════════
# BUILD
# ═══════════════════════════════════════════════════════════════════════════════

# Build the project
build:
    @echo "Building {{project}}..."

# Clean build artifacts
clean:
    @echo "Cleaning..."

# ═══════════════════════════════════════════════════════════════════════════════
# TEST & QUALITY
# ═══════════════════════════════════════════════════════════════════════════════

# Run tests
test:
    @echo "Running tests..."

# Run linter
lint:
    @echo "Linting..."

# Format code
fmt:
    @echo "Formatting..."

# Run all quality checks
quality: fmt lint test

# ═══════════════════════════════════════════════════════════════════════════════
# VALIDATION
# ═══════════════════════════════════════════════════════════════════════════════

# Validate RSR compliance
validate-rsr:
    @echo "Validating RSR compliance..."
    @test -f .gitignore || (echo "Missing .gitignore" && exit 1)
    @test -f .gitattributes || (echo "Missing .gitattributes" && exit 1)
    @test -f .editorconfig || (echo "Missing .editorconfig" && exit 1)
    @test -f .tool-versions || (echo "Missing .tool-versions" && exit 1)
    @test -f META.scm || (echo "Missing META.scm" && exit 1)
    @test -f STATE.scm || (echo "Missing STATE.scm" && exit 1)
    @test -f ECOSYSTEM.scm || (echo "Missing ECOSYSTEM.scm" && exit 1)
    @test -f PLAYBOOK.scm || (echo "Missing PLAYBOOK.scm" && exit 1)
    @test -f AGENTIC.scm || (echo "Missing AGENTIC.scm" && exit 1)
    @test -f NEUROSYM.scm || (echo "Missing NEUROSYM.scm" && exit 1)
    @test ! -f Makefile || (echo "Makefile forbidden - use justfile" && exit 1)
    @echo "RSR validation passed!"

# Validate STATE.scm syntax
validate-state:
    @echo "Validating STATE.scm..."
    @test -f STATE.scm && echo "STATE.scm exists" || echo "STATE.scm missing"

# Update STATE.scm timestamp
state-touch:
    @echo "Updating STATE.scm timestamp..."
    @[ -f STATE.scm ] && sed -i 's/(updated . "[^"]*")/(updated . "'\$(date +%Y-%m-%d)'")/' STATE.scm || true

# ═══════════════════════════════════════════════════════════════════════════════
# CI
# ═══════════════════════════════════════════════════════════════════════════════

# Run full CI pipeline locally
ci: quality validate-rsr
    @echo "CI pipeline passed!"
"""
end

const MUSTFILE = """
# SPDX-License-Identifier: AGPL-3.0-or-later
# Mustfile - deployment state contract
# See: https://github.com/hyperpolymath/mustfile

version: 1

checks:
  - name: lint
    run: just lint
  - name: test
    run: just test
  - name: format
    run: just fmt
"""

# ============================================================================
# Helper Functions
# ============================================================================

function run_cmd(cmd::Cmd; capture=false)
    if DRY_RUN
        println("  [DRY-RUN] ", cmd)
        return true, ""
    end
    try
        if capture
            output = read(cmd, String)
            return true, output
        else
            run(cmd)
            return true, ""
        end
    catch e
        return false, string(e)
    end
end

function file_exists(path::String)
    return isfile(path)
end

function dir_exists(path::String)
    return isdir(path)
end

function write_if_missing(path::String, content::String; force=false)
    if !force && file_exists(path)
        return false
    end
    if DRY_RUN
        println("  [DRY-RUN] Would write: ", path)
        return true
    end
    mkpath(dirname(path))
    write(path, content)
    return true
end

function delete_if_exists(path::String)
    if !file_exists(path)
        return false
    end
    if DRY_RUN
        println("  [DRY-RUN] Would delete: ", path)
        return true
    end
    rm(path)
    return true
end

# ============================================================================
# Main Standardization
# ============================================================================

function standardize_repo(repo_path::String)
    project = basename(repo_path)
    println("\n═══ Standardizing: $project ═══")

    if !dir_exists(joinpath(repo_path, ".git"))
        println("  ⚠ Not a git repo, skipping")
        return
    end

    cd(repo_path) do
        changes = String[]

        # Dotfiles
        if write_if_missing(".gitignore", GITIGNORE)
            push!(changes, ".gitignore")
        end
        if write_if_missing(".gitattributes", GITATTRIBUTES)
            push!(changes, ".gitattributes")
        end
        if write_if_missing(".editorconfig", EDITORCONFIG)
            push!(changes, ".editorconfig")
        end
        if write_if_missing(".tool-versions", TOOL_VERSIONS)
            push!(changes, ".tool-versions")
        end

        # .meta directory
        if write_if_missing(".meta/REQUIRED-FILES.md", META_REQUIRED_FILES)
            push!(changes, ".meta/REQUIRED-FILES.md")
        end

        # Detect satellite relationships
        parent = detect_satellite_parent(project)
        satellites = detect_satellites(repo_path, project)

        if !isnothing(parent)
            println("  📡 Satellite of: $parent")
        end
        if !isempty(satellites)
            println("  🛰️  Has satellites: ", join(satellites, ", "))
        end

        # SCM files
        if write_if_missing("META.scm", meta_scm_template(project))
            push!(changes, "META.scm")
        end
        if write_if_missing("STATE.scm", state_scm_template(project))
            push!(changes, "STATE.scm")
        end
        if write_if_missing("ECOSYSTEM.scm", ecosystem_scm_template(project; parent=parent, satellites=satellites))
            push!(changes, "ECOSYSTEM.scm")
        end
        if write_if_missing("PLAYBOOK.scm", playbook_scm_template(project))
            push!(changes, "PLAYBOOK.scm")
        end
        if write_if_missing("AGENTIC.scm", agentic_scm_template(project))
            push!(changes, "AGENTIC.scm")
        end
        if write_if_missing("NEUROSYM.scm", neurosym_scm_template(project))
            push!(changes, "NEUROSYM.scm")
        end

        # Build system
        if write_if_missing("justfile", justfile_template(project))
            push!(changes, "justfile")
        end
        if write_if_missing("Mustfile", MUSTFILE)
            push!(changes, "Mustfile")
        end

        # Delete Makefile if present
        if delete_if_exists("Makefile")
            push!(changes, "Makefile (deleted)")
        end

        if isempty(changes)
            println("  ✓ Already compliant")
        else
            println("  Changes: ", join(changes, ", "))

            if !DRY_RUN
                # Stage and commit
                run_cmd(`git add -A`)
                success, _ = run_cmd(`git commit -m "chore: standardize repo with RSR dotfiles and SCM files

Added/updated:
$(join(["- $c" for c in changes], "\n"))

🤖 Generated with [Claude Code](https://claude.ai/code)"`)

                if success
                    println("  ✓ Committed")
                end
            end
        end
    end
end

function get_all_repos()
    repos = String[]
    for entry in readdir(REPOS_DIR)
        path = joinpath(REPOS_DIR, entry)
        if isdir(path) && isdir(joinpath(path, ".git"))
            push!(repos, path)
        end
    end
    return repos
end

function main()
    println("═══════════════════════════════════════════════════════════════════")
    println("Repository Standardization Script")
    println("═══════════════════════════════════════════════════════════════════")
    DRY_RUN && println("MODE: DRY RUN (no changes will be made)")
    println()

    if !isnothing(SINGLE_REPO)
        path = joinpath(REPOS_DIR, SINGLE_REPO)
        if isdir(path)
            standardize_repo(path)
        else
            println("Repo not found: $path")
        end
    else
        repos = get_all_repos()
        println("Found $(length(repos)) repositories")

        for repo in repos
            standardize_repo(repo)
        end
    end

    println("\n═══════════════════════════════════════════════════════════════════")
    println("Done!")
    println("═══════════════════════════════════════════════════════════════════")
end

main()
