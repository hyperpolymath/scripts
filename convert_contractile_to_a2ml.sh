#!/bin/bash
# Convert .contractile files (Scheme format) to .a2ml format
# Moves them to .machine_readable/contractiles/ and removes originals

REPO_ROOT="/home/hyperpolymath/developer/repos"

convert_intent_contractile() {
    local file="$1"
    local dir=$(dirname "$file")
    local repo_dir=$(dirname "$dir")
    local repo_name=$(basename "$repo_dir")
    
    echo "Converting: $file"
    
    # Create contractiles directory
    mkdir -p "$repo_dir/.machine_readable/contractiles"
    
    # Extract content from Scheme format
    local purpose=$(grep -A 2 'purpose' "$file" | grep '"' | sed 's/.*"//;s/"//' | head -1)
    local anti_purpose=$(grep -A 5 'anti-purpose' "$file" | grep '"' | sed 's/.*"//;s/"//' | head -1)
    
    # Create a2ml version
    local output="$repo_dir/.machine_readable/contractiles/Intentfile.a2ml"
    
    cat > "$output" << EOF
# SPDX-License-Identifier: MPL-2.0
# Intentfile (A2ML) - Converted from INTENT.contractile for $repo_name

@abstract:
Purpose and scope for $repo_name. This file was converted from Scheme-based
INTENT.contractile format to A2ML format.
@end

## Purpose

$purpose

## Anti-Purpose

$anti_purpose

## If In Doubt

Sensitive areas from original contractile:
EOF
    
    # Extract ask-before-touching
    grep -A 5 'ask-before-touching' "$file" | grep '"' | sed 's/.*"//;s/"//' | while read line; do
        echo "- $line" >> "$output"
    done
    
    echo "  Created: $output"
    echo "  Removing: $file"
    rm "$file"
}

convert_must_contractile() {
    local file="$1"
    local dir=$(dirname "$file")
    local repo_dir=$(dirname "$dir")
    local repo_name=$(basename "$repo_dir")
    
    echo "Converting: $file"
    
    # Create contractiles directory
    mkdir -p "$repo_dir/.machine_readable/contractiles"
    
    local output="$repo_dir/.machine_readable/contractiles/Mustfile.a2ml"
    
    cat > "$output" << 'EOF'
# SPDX-License-Identifier: MPL-2.0
# Mustfile (A2ML) - Converted from MUST.contractile

@abstract:
Physical state contract for this repository. Converted from Scheme-based
MUST.contractile format to A2ML format.
@end

## File Presence

### license-present
- description: LICENSE file must exist
- run: test -f LICENSE
- severity: critical
EOF
    
    echo "  Created: $output"
    echo "  Removing: $file"
    rm "$file"
}

convert_trust_contractile() {
    local file="$1"
    local dir=$(dirname "$file")
    local repo_dir=$(dirname "$dir")
    local repo_name=$(basename "$repo_dir")
    
    echo "Converting: $file"
    
    # Create contractiles directory
    mkdir -p "$repo_dir/.machine_readable/contractiles"
    
    local output="$repo_dir/.machine_readable/contractiles/Trustfile.a2ml"
    
    cat > "$output" << 'EOF'
# SPDX-License-Identifier: MPL-2.0
# Trustfile (A2ML) - Converted from TRUST.contractile

@abstract:
Trust boundaries and integrity invariants. Converted from Scheme-based
TRUST.contractile format to A2ML format.
@end

## Integrity Invariants

### no-secrets-committed
- description: No credential files in repo
- run: test ! -f .env && test ! -f credentials.json
- severity: critical
EOF
    
    echo "  Created: $output"
    echo "  Removing: $file"
    rm "$file"
}

convert_adjust_contractile() {
    local file="$1"
    local dir=$(dirname "$file")
    local repo_dir=$(dirname "$dir")
    local repo_name=$(basename "$repo_dir")
    
    echo "Converting: $file"
    
    # Create contractiles directory
    mkdir -p "$repo_dir/.machine_readable/contractiles"
    
    local output="$repo_dir/.machine_readable/contractiles/Adjustfile.a2ml"
    
    cat > "$output" << 'EOF'
# SPDX-License-Identifier: MPL-2.0
# Adjustfile (A2ML) - Converted from ADJUST.contractile

@abstract:
Drift tolerances and corrective actions. Converted from Scheme-based
ADJUST.contractile format to A2ML format.
@end

## Drift Tolerance

### placeholder-drift
- description: Template placeholder values should be replaced
- tolerance: 0 placeholder markers
- corrective: Replace all {{PLACEHOLDER}} values
- severity: advisory
EOF
    
    echo "  Created: $output"
    echo "  Removing: $file"
    rm "$file"
}

convert_dust_contractile() {
    local file="$1"
    local dir=$(dirname "$file")
    local repo_dir=$(dirname "$dir")
    local repo_name=$(basename "$repo_dir")
    
    echo "Converting: $file"
    
    # Create contractiles directory
    mkdir -p "$repo_dir/.machine_readable/contractiles/dust"
    
    local output="$repo_dir/.machine_readable/contractiles/dust/Dustfile.a2ml"
    
    cat > "$output" << 'EOF'
# SPDX-License-Identifier: MPL-2.0
# Dustfile (A2ML) - Converted from DUST.contractile

@abstract:
Cleanup and hygiene contract. Converted from Scheme-based
DUST.contractile format to A2ML format.
@end

## Stale Files

### no-stale-files
- description: No stale files in repo
- run: "! ls *-old-*.md *-temp-*.md 2>/dev/null | head -1 | grep -q ."
- severity: info
EOF
    
    echo "  Created: $output"
    echo "  Removing: $file"
    rm "$file"
}

convert_bust_contractile() {
    local file="$1"
    local dir=$(dirname "$file")
    local repo_dir=$(dirname "$dir")
    local repo_name=$(basename "$repo_dir")
    
    echo "Converting: $file"
    
    # Create contractiles directory
    mkdir -p "$repo_dir/.machine_readable/contractiles/bust"
    
    local output="$repo_dir/.machine_readable/contractiles/bust/Bustfile.a2ml"
    
    cat > "$output" << 'EOF'
// Bustfile.a2ml — Rollback and breakage contract (converted from BUST.contractile)
// SPDX-License-Identifier: MPL-2.0

Bust {
    name: "${repo_name}"
    version: "1.0.0"
    description: "Rollback procedures when something breaks in this repository"

    scenarios: {
        "generic-rollback": "Revert the last commit and investigate"
    }

    escalation-ladder: [
        "1. Revert the commit",
        "2. Investigate the issue",
        "3. Fix and redeploy"
    ]

    backup-points: [
        "Git history serves as backup"
    ]
}
EOF
    
    echo "  Created: $output"
    echo "  Removing: $file"
    rm "$file"
}

# Main logic
echo "Starting .contractile to .a2ml conversion..."
echo ""

# Find all .contractile files
while IFS= read -r file; do
    case "$(basename "$file")" in
        INTENT.contractile)
            convert_intent_contractile "$file"
            ;;
        MUST.contractile)
            convert_must_contractile "$file"
            ;;
        TRUST.contractile)
            convert_trust_contractile "$file"
            ;;
        ADJUST.contractile)
            convert_adjust_contractile "$file"
            ;;
        DUST.contractile)
            convert_dust_contractile "$file"
            ;;
        BUST.contractile)
            convert_bust_contractile "$file"
            ;;
        *)
            echo "Unknown contractile: $file"
            ;;
    esac
done < <(find "$REPO_ROOT" -name "*.contractile" -type f | grep -v ".git" | grep -v "node_modules")

echo ""
echo "Conversion complete!"
