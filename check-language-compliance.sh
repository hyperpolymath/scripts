#!/usr/bin/env bash
# SPDX-License-Identifier: MPL-2.0
# Check API/ABI/FFI language compliance across repositories

set -euo pipefail

REPOS_BASE="${REPOS_BASE:-/var$REPOS_DIR}"
# Per-user XDG state, not /tmp: this log is a kept, dated compliance report
# (copied to stdout for the whole run), and a world-writable /tmp path
# with a predictable name lets another local user pre-create or tamper with
# it (CWE-377). Not a launcher, so no PID file and no launch-scaffolder/
# segment here.
case "${XDG_STATE_HOME:-}" in
    /*) STATE_DIR="$XDG_STATE_HOME/scripts/language-compliance" ;;
    *) STATE_DIR="$HOME/.local/state/scripts/language-compliance" ;;
esac
SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"

# The logger opens the report once using a verified directory descriptor.
{

echo "=== Language Compliance Check ==="
echo "Started: $(date)"
echo ""

# Initialize counters
API_VIOLATIONS=0
ABI_VIOLATIONS=0
FFI_VIOLATIONS=0
COMPLIANT_REPOS=0
TOTAL_REPOS=0

# Check a single repository
check_repo() {
    local repo_path="$1"
    local repo_name="$(basename "$repo_path")"
    local violations=0
    
    echo "Checking: $repo_name"
    
    # Check for non-V APIs (exclude internal scripts)
    if find "$repo_path" -name "*.ex" -o -name "*.exs" | grep -q .; then
        echo "  ✓ Elixir found - checking API compliance"
        # Elixir repos should use V for external APIs
        if [ ! -f "$repo_path/api/vlang" ] && find "$repo_path" -name "*.ex" | head -1 | grep -q .; then
            echo "  ⚠️  Potential API violation: Elixir repo without V API layer"
            ((API_VIOLATIONS++))
            ((violations++))
        fi
    fi
    
    # Check for non-Idris2 ABIs
    if find "$repo_path" -name "*.zig" | grep -q .; then
        echo "  ✓ Zig found - checking ABI compliance"
        # Zig repos should use Idris2 for ABIs
        if [ ! -f "$repo_path/abi/idris2" ] && find "$repo_path" -name "*.zig" | head -1 | grep -q .; then
            echo "  ⚠️  Potential ABI violation: Zig repo without Idris2 ABI layer"
            ((ABI_VIOLATIONS++))
            ((violations++))
        fi
    fi
    
    # Check for non-Zig FFIs
    if find "$repo_path" -name "*.c" -o -name "*.h" | grep -q .; then
        echo "  ⚠️  Potential FFI violation: C headers found"
        echo "     Should use Zig with C compatibility layer only"
        ((FFI_VIOLATIONS++))
        ((violations++))
    fi
    
    # Check for proper C compatibility warnings
    if grep -r "c_compat" "$repo_path" 2>/dev/null | grep -q .; then
        if ! grep -r "compileError.*C.*compatibility" "$repo_path" 2>/dev/null | grep -q .; then
            echo "  ⚠️  C compatibility without proper warnings"
            ((FFI_VIOLATIONS++))
            ((violations++))
        fi
    fi
    
    if [ $violations -eq 0 ]; then
        echo "  ✅ Compliant"
        ((COMPLIANT_REPOS++))
    else
        echo "  ❌ $violations violations found"
    fi
    
    ((TOTAL_REPOS++))
    echo ""
}

# Export function for parallel execution
export -f check_repo
export REPOS_BASE

# Find all repositories
echo "Scanning repositories in $REPOS_BASE..."

# Check core repositories first
for repo in hypatia gitbot-fleet ".git-private-farm"; do
    if [ -d "$REPOS_BASE/$repo" ]; then
        check_repo "$REPOS_BASE/$repo"
    fi
done

# Check other repositories in parallel
find "$REPOS_BASE" -maxdepth 1 -type d ! -name "." ! -name ".." ! -name ".git*" ! -name "nextgen-databases" ! -name "developer-ecosystem" | while read -r repo_dir; do
    check_repo "$repo_dir"
done

# Summary
echo ""
echo "=== Summary ==="
echo "Total repositories: $TOTAL_REPOS"
echo "Compliant: $COMPLIANT_REPOS"
echo ""
echo "Violations:"
echo "  API (non-V): $API_VIOLATIONS"
echo "  ABI (non-Idris2): $ABI_VIOLATIONS"
echo "  FFI (non-Zig): $FFI_VIOLATIONS"
echo ""

COMPLIANCE_PERCENT=$(( (COMPLIANT_REPOS * 100) / TOTAL_REPOS ))
echo "Compliance: $COMPLIANCE_PERCENT%"

if [ $COMPLIANCE_PERCENT -ge 90 ]; then
    echo "Status: ✅ PASSING"
    exit 0
elif [ $COMPLIANCE_PERCENT -ge 70 ]; then
    echo "Status: ⚠️  WARNING"
    exit 1
else
    echo "Status: ❌ FAILING"
    exit 2
fi

} | julia --startup-file=no --history-file=no \
    "$SCRIPT_DIR/check-language-compliance-log.jl" "$STATE_DIR" "$(date +%Y%m%d).log"
