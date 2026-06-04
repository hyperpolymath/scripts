<!--
SPDX-License-Identifier: MPL-2.0
Copyright (c) Jonathan D.A. Jewell <j.d.a.jewell@open.ac.uk>
-->
# Changelog

All notable changes to `scripts` will be documented in this file.

This file is generated from conventional commits by the
[`changelog-reusable.yml`](https://github.com/hyperpolymath/standards/blob/main/.github/workflows/changelog-reusable.yml)
workflow (`hyperpolymath/standards#206`). Adopt the workflow in this repo's CI to keep this file in sync automatically — see
[`templates/cliff.toml`](https://github.com/hyperpolymath/standards/blob/main/templates/cliff.toml)
for the canonical config.

The format follows [Keep a Changelog](https://keepachangelog.com/en/1.1.0/);
this project aims to follow [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

### Added

- feat: migrate bookmark scripts from Python to Julia
- feat: add stapeln.toml container definition
- feat: deploy UX Manifesto infrastructure
- feat: add CLADE.a2ml — clade taxonomy declaration
- feat(ci): enable Hypatia scanning
- feat: add hyperpolymath utility scripts

### Fixed

- fix(ci): sync hypatia-scan.yml to canonical (#47)
- fix(ci): build Hypatia escript from repo root (estate dogfood drift)
- fix(ci): Phase-2 fleet submission must not fail the security gate (#46)
- fix(ci): move secret-scanner Cargo.toml gate from job-level if: to step-level (#45)
- fix: replace deno -A with specific permission flags
- fix(scorecard): enforce granular permissions and add fuzzing placeholder
- fix(ci): Resolve workflow-linter self-matching and metadata issues
- fix: correct email jonathan.jewell → j.d.a.jewell
- fix(license): SPDX AGPL-3.0 → PMPL-1.0-or-later in dotfiles
- fix: apply safety triangle fixes (recipe-heredoc-to-install,recipe-shell-quote-vars)

### Changed

- refactor: reboot-tracker.ts → .mjs (TS types stripped) (#42)
- refactor: migrate 6SCM → 6A2 (.scm → .a2ml format)

### Documentation

- docs: add EXPLAINME.adoc — prove-it file backing README claims
- docs: add CONTRIBUTING.md
- docs: add checkpoint files for state tracking

### CI

- build(deps): bump dtolnay/rust-toolchain from efa25f7f19611383d5b0ccf2d1c8914531636bf9 to 3c5f7ea28cd621ae0bf5283f0e981fb97b8a7af9 (#49)
- build(deps): bump github/codeql-action from 4.32.6 to 4.36.0 (#50)
- build(deps): bump actions/github-script from 8.0.0 to 9.0.0 (#51)
- build(deps): bump trufflesecurity/trufflehog from 3.93.8 to 3.95.3 (#52)
- build(deps): bump actions/upload-artifact from 4.6.2 to 7.0.1 (#53)

## Pre-history

Prior commits to this file's introduction are recorded in git history but not formally classified into Keep-a-Changelog sections. To backfill, run `git cliff -o CHANGELOG.md` locally using the canonical [`cliff.toml`](https://github.com/hyperpolymath/standards/blob/main/templates/cliff.toml) — this is one-shot mechanical work.

---

<!-- This file was seeded by the 2026-05-26 estate tech-debt audit follow-up (Row-2 Phase 3); see [`hyperpolymath/standards/docs/audits/2026-05-26-estate-documentation-debt.md`](https://github.com/hyperpolymath/standards/blob/main/docs/audits/2026-05-26-estate-documentation-debt.md). -->
