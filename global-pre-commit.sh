#!/bin/bash
# .git/hooks/pre-commit
# Global Enforcer Hook for License and Architecture Policies

# 1. License Check
# Determine if this is a SHARED (AGPL) or OWNED (MPL) repo
REMOTE_URL=$(git remote get-url origin 2>/dev/null)
DIR_NAME=$(basename "$(pwd)")

if [[ "$REMOTE_URL" == *"JoshuaJewell"* || "$DIR_NAME" == boj-* || "$DIR_NAME" == bofj-* ]]; then
    EXPECTED_LICENSE="AGPL-3.0-or-later"
    # Shared repos components retain original, so we only check the root LICENSE or new files?
    # User said: "regardless of whether I own it... should always be AGPL-3.0-or-later for the repo"
    # "with the components retaining their original licences"
    # So for shared, we just verify root LICENSE exists.
    if ! grep -q "Affero General Public License" LICENSE 2>/dev/null; then
        echo "ERROR: Shared repository must have AGPL-3.0-or-later LICENSE file."
        exit 1
    fi
else
    EXPECTED_LICENSE="MPL-2.0"
    EXPECTED_OWNER="Jonathan D.A. Jewell <j.d.a.jewell@open.ac.uk>"
    
    # Check staged files for SPDX header
    STAGED_FILES=$(git diff --cached --name-only --diff-filter=ACM | grep -E '\.(zig|ex|idr|eph|py|js|ts|rs|c|h|adoc|md)$')
    
    for file in $STAGED_FILES; do
        if ! grep -q "SPDX-License-Identifier: $EXPECTED_LICENSE" "$file"; then
            echo "ERROR: File $file is missing correct SPDX-License-Identifier: $EXPECTED_LICENSE"
            exit 1
        fi
        if ! grep -q "$EXPECTED_OWNER" "$file"; then
            echo "ERROR: File $file is missing correct Owner: $EXPECTED_OWNER"
            exit 1
        fi
    done
fi

# 2. No C Policy
# "Strict No C policy... All APIs and FFIs MUST be written in Zig."
# Exception: bidirectional adapters in specific repos.
if [[ "$DIR_NAME" != "proven" && "$DIR_NAME" != "boj-server-cartridges" ]]; then
    STAGED_C_FILES=$(git diff --cached --name-only --diff-filter=ACM | grep -E '\.c$')
    if [ -n "$STAGED_C_FILES" ]; then
        echo "ERROR: Strict No C Policy. C files are not allowed in this repository."
        echo "Offending files: $STAGED_C_FILES"
        exit 1
    fi
fi

# 3. SNIFs Policy
# "NEVER use raw NIFs. ALWAYS use SNIFs (Safe NIFs)"
STAGED_BEAM_FILES=$(git diff --cached --name-only --diff-filter=ACM | grep -E '\.(ex|exs|erl)$')
for file in $STAGED_BEAM_FILES; do
    if grep -qE "erlang:load_nif|:erlang\.load_nif" "$file"; then
        echo "ERROR: Raw NIFs are forbidden. Use SNIFs (Safe NIFs) from the snifs repository."
        exit 1
    fi
done

# 4. Idris 2 ABI Policy
# "ABIs and capability matchers MUST always be formally verified in Idris 2."
# (Basic check: if an ABI file is added, it should be .idr)
STAGED_ABI_FILES=$(git diff --cached --name-only --diff-filter=ACM | grep -i "abi")
for file in $STAGED_ABI_FILES; do
    if [[ "$file" != *.idr && "$file" != *.zig ]]; then
        # Zig is allowed for the FFI bridge
        if [[ "$file" != *.adoc && "$file" != *.md ]]; then
            echo "WARNING: ABI definition found in non-Idris/Zig file: $file"
        fi
    fi
done

exit 0
