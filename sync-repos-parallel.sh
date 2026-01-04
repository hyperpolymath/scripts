#!/bin/bash
REPO_DIR="${HOME}/repos"
mkdir -p "$REPO_DIR"

echo "Fetching repo list..."
gh repo list --limit 500 --json name,sshUrl --jq '.[] | .name + "|" + .sshUrl' > /tmp/repos.txt

TOTAL=$(wc -l < /tmp/repos.txt)
echo "Found $TOTAL repos"

sync_repo() {
    local line="$1"
    local name="${line%%|*}"
    local url="${line##*|}"
    local target="${REPO_DIR}/${name}"

    if [[ -d "$target/.git" ]]; then
        echo "[OK] $name (exists)"
    else
        if git clone --depth 1 -q "$url" "$target" 2>/dev/null; then
            echo "[OK] $name (cloned)"
        else
            echo "[FAIL] $name"
        fi
    fi
}

export -f sync_repo
export REPO_DIR

cat /tmp/repos.txt | xargs -P 8 -I {} bash -c 'sync_repo "$@"' _ {}

echo ""
echo "Done! Repos in $REPO_DIR:"
ls "$REPO_DIR" | wc -l
