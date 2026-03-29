#!/usr/bin/env bash
# SPDX-License-Identifier: PMPL-1.0-or-later
# VeriSimDB Session Trace Helpers
# Usage: source this file or call functions directly
#
# verisimdb_trace "title" "body" — create a session trace octad
# verisimdb_decision "name" "chosen" "reason" — log a decision
# verisimdb_query "search term" — search past traces
# verisimdb_status — show instance status

VERISIMDB_WORK="http://localhost:8096"

verisimdb_status() {
    curl -s "$VERISIMDB_WORK/health" | python3 -m json.tool 2>/dev/null || echo "VeriSimDB work instance not running. Start with: systemctl --user start verisimdb-work.service"
}

verisimdb_trace() {
    local title="$1"
    local body="$2"
    local date=$(date +%Y-%m-%d)
    curl -s -X POST "$VERISIMDB_WORK/octads" \
        -H "Content-Type: application/json" \
        -d "{
            \"title\": \"$title\",
            \"body\": \"$body\",
            \"types\": [\"session-trace\"],
            \"metadata\": {\"date\": \"$date\", \"agent\": \"claude\"},
            \"provenance\": {\"event_type\": \"created\", \"actor\": \"claude\", \"description\": \"Session trace\"}
        }"
}

verisimdb_decision() {
    local name="$1"
    local chosen="$2"
    local reason="$3"
    local date=$(date +%Y-%m-%dT%H:%M:%S)
    curl -s -X POST "$VERISIMDB_WORK/octads" \
        -H "Content-Type: application/json" \
        -d "{
            \"title\": \"Decision: $name\",
            \"body\": \"Chosen: $chosen. Reason: $reason\",
            \"types\": [\"decision-trace\", \"007-branch\"],
            \"metadata\": {\"decision\": \"$name\", \"chosen\": \"$chosen\", \"timestamp\": \"$date\"},
            \"provenance\": {\"event_type\": \"created\", \"actor\": \"claude\", \"description\": \"007 decision trace\"}
        }"
}

verisimdb_query() {
    local term="$1"
    curl -s "$VERISIMDB_WORK/search/text?q=$term" 2>/dev/null
}

verisimdb_list() {
    curl -s "$VERISIMDB_WORK/octads" | python3 -m json.tool 2>/dev/null
}
