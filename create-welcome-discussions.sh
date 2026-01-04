#!/bin/bash
# SPDX-License-Identifier: AGPL-3.0-or-later
# Create welcome discussions for repos that don't have one

create_welcome_discussion() {
    local repo="$1"

    echo -n "Creating welcome discussion for $repo: "

    # Get repo ID
    local repo_id
    repo_id=$(gh api graphql -f query='query { repository(owner: "hyperpolymath", name: "'"$repo"'") { id } }' --jq '.data.repository.id' 2>/dev/null)

    if [[ -z "$repo_id" || "$repo_id" == "null" ]]; then
        echo "SKIP (could not get repo ID)"
        return 1
    fi

    # Get Announcements category ID
    local cat_id
    cat_id=$(gh api graphql -f query='query { repository(owner: "hyperpolymath", name: "'"$repo"'") { discussionCategories(first: 10) { nodes { id name } } } }' --jq '.data.repository.discussionCategories.nodes[] | select(.name == "Announcements") | .id' 2>/dev/null)

    if [[ -z "$cat_id" || "$cat_id" == "null" ]]; then
        echo "SKIP (could not get category ID)"
        return 1
    fi

    # Create discussion body as JSON
    local title="Welcome to $repo Discussions!"
    local body="Welcome! This is the official discussion space for **$repo**.

## How to Use

- **Announcements**: Project updates from maintainers
- **Q&A**: Ask questions and get help
- **Ideas**: Suggest new features
- **Show and tell**: Share what you've built

Please be respectful and follow our community guidelines."

    # Create the discussion
    local result
    result=$(gh api graphql \
        -F repositoryId="$repo_id" \
        -F categoryId="$cat_id" \
        -F title="$title" \
        -F body="$body" \
        -f query='
mutation($repositoryId: ID!, $categoryId: ID!, $title: String!, $body: String!) {
  createDiscussion(input: {
    repositoryId: $repositoryId
    categoryId: $categoryId
    title: $title
    body: $body
  }) {
    discussion {
      id
      title
    }
  }
}' 2>&1)

    if echo "$result" | grep -q '"title"'; then
        echo "OK"
        return 0
    else
        local err
        err=$(echo "$result" | jq -r '.errors[0].message // "unknown error"' 2>/dev/null || echo "$result")
        echo "FAILED: $err"
        return 1
    fi
}

# List of repos needing welcome discussions
repos=(
    "mustfile" "network-dashboard" "bgp-backbone-lab"
    "flatracoon-os" "hesiod-dns-map" "ipv6-site-enforcer" "ipfs-overlay"
    "zerotier-k8s-link" "twingate-helm-deploy" "explicit-trust-plane" "theoneshow"
    "wp-resurrect" "docudactyl" "rhodibot" "anchor.scm" "funfriendly-git"
    "git-dispatcher" "total-upgrade" "dnfinition" "nickel-augmented" "seambot"
    "bebop-v-ffi" "claude-gecko-browser-extension" "amethe" "total-recall"
    "git-secure" "avatar-fabrication-facility" "snapcreate" "dei-ssg"
    "poly-proof-mcp" "tyrano-ssg" "vladik-ssg" "ultimatum-ssg" "repo-customiser"
    "ephapax-playground" "reliquary-ssg" "tiamat-ssg" "tripos-ssg"
    "developer-ecosystem" "neural-foundations" "cccp" "reasonably-good-token-vault"
    "neurosym-scm"
)

echo "Creating welcome discussions for ${#repos[@]} repos..."
echo ""

success=0
failed=0

for repo in "${repos[@]}"; do
    if create_welcome_discussion "$repo"; then
        ((success++))
    else
        ((failed++))
    fi
done

echo ""
echo "Done. Success: $success, Failed: $failed"
