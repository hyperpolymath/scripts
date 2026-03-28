#!/usr/bin/env bash
# SPDX-License-Identifier: PMPL-1.0-or-later
# Check API/ABI/FFI language compliance across repositories

set -euo pipefail

REPOS_BASE="${REPOS_BASE:-/var$REPOS_DIR}"
LOG_FILE="/tmp/language-compliance-$(date +%Y%m%d).log"

echo "=== Language Compliance Check ===" | tee "$LOG_FILE"
echo "Started: $(date)" | tee -a "$LOG_FILE"
echo "" | tee -a "$LOG_FILE"

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
    
    echo "Checking: $repo_name" | tee -a "$LOG_FILE"
    
    # Check for non-V APIs (exclude internal scripts)
    if find "$repo_path" -name "*.ex" -o -name "*.exs" | grep -q .; then
        echo "  ✓ Elixir found - checking API compliance" | tee -a "$LOG_FILE"
        # Elixir repos should use V for external APIs
        if [ ! -f "$repo_path/api/vlang" ] && find "$repo_path" -name "*.ex" | head -1 | grep -q .; then
            echo "  ⚠️  Potential API violation: Elixir repo without V API layer" | tee -a "$LOG_FILE"
            ((API_VIOLATIONS++))
            ((violations++))
        fi
    fi
    
    # Check for non-Idris2 ABIs
    if find "$repo_path" -name "*.zig" | grep -q .; then
        echo "  ✓ Zig found - checking ABI compliance" | tee -a "$LOG_FILE"
        # Zig repos should use Idris2 for ABIs
        if [ ! -f "$repo_path/abi/idris2" ] && find "$repo_path" -name "*.zig" | head -1 | grep -q .; then
            echo "  ⚠️  Potential ABI violation: Zig repo without Idris2 ABI layer" | tee -a "$LOG_FILE"
            ((ABI_VIOLATIONS++))
            ((violations++))
        fi
    fi
    
    # Check for non-Zig FFIs
    if find "$repo_path" -name "*.c" -o -name "*.h" | grep -q .; then
        echo "  ⚠️  Potential FFI violation: C headers found" | tee -a "$LOG_FILE"
        echo "     Should use Zig with C compatibility layer only" | tee -a "$LOG_FILE"
        ((FFI_VIOLATIONS++))
        ((violations++))
    fi
    
    # Check for proper C compatibility warnings
    if grep -r "c_compat" "$repo_path" 2>/dev/null | grep -q .; then
        if ! grep -r "compileError.*C.*compatibility" "$repo_path" 2>/dev/null | grep -q .; then
            echo "  ⚠️  C compatibility without proper warnings" | tee -a "$LOG_FILE"
            ((FFI_VIOLATIONS++))
            ((violations++))
        fi
    fi
    
    if [ $violations -eq 0 ]; then
        echo "  ✅ Compliant" | tee -a "$LOG_FILE"
        ((COMPLIANT_REPOS++))
    else
        echo "  ❌ $violations violations found" | tee -a "$LOG_FILE"
    fi
    
    ((TOTAL_REPOS++))
    echo "" | tee -a "$LOG_FILE"
}

# Export function for parallel execution
export -f check_repo
export REPOS_BASE

# Find all repositories
echo "Scanning repositories in $REPOS_BASE..." | tee -a "$LOG_FILE"

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
echo "" | tee -a "$LOG_FILE"
echo "=== Summary ===" | tee -a "$LOG_FILE"
echo "Total repositories: $TOTAL_REPOS" | tee -a "$LOG_FILE"
echo "Compliant: $COMPLIANT_REPOS" | tee -a "$LOG_FILE"
echo "" | tee -a "$LOG_FILE"
echo "Violations:" | tee -a "$LOG_FILE"
echo "  API (non-V): $API_VIOLATIONS" | tee -a "$LOG_FILE"
echo "  ABI (non-Idris2): $ABI_VIOLATIONS" | tee -a "$LOG_FILE"
echo "  FFI (non-Zig): $FFI_VIOLATIONS" | tee -a "$LOG_FILE"
echo "" | tee -a "$LOG_FILE"

COMPLIANCE_PERCENT=$(( (COMPLIANT_REPOS * 100) / TOTAL_REPOS ))
echo "Compliance: $COMPLIANCE_PERCENT%" | tee -a "$LOG_FILE"

if [ $COMPLIANCE_PERCENT -ge 90 ]; then
    echo "Status: ✅ PASSING" | tee -a "$LOG_FILE"
    exit 0
elif [ $COMPLIANCE_PERCENT -ge 70 ]; then
    echo "Status: ⚠️  WARNING" | tee -a "$LOG_FILE"
    exit 1
else
    echo "Status: ❌ FAILING" | tee -a "$LOG_FILE"
    exit 2
fi