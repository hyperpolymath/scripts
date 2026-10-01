#!/usr/bin/env bash
# SPDX-License-Identifier: MPL-2.0
set -euo pipefail

repo_dir="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
fixture=$(mktemp -d)
trap 'rm -rf -- "$fixture"' EXIT
logger="$repo_dir/check-language-compliance-log.jl"
log_name="$(date +%Y%m%d).log"

# Print all arguments as a failure message to stderr and exit the test with status 1.
fail() { echo "FAIL: $*" >&2; exit 1; }

# Write a sample report through $logger using $1 as the state directory and
# $log_name as the filename. Forward logger output and return the pipeline status.
run_logger() {
    printf 'report\n' | julia --startup-file=no --history-file=no "$logger" "$1" "$log_name"
}

# Assert that logging to state directory $1 fails without writing to stdout.
# Capture output under $fixture; use $2 to describe the rejected case on failure.
reject() {
    if run_logger "$1" > "$fixture/stdout" 2> "$fixture/stderr"; then
        fail "accepted $2"
    fi
    [[ ! -s "$fixture/stdout" ]] || fail "wrote output for $2"
}

# Exercise real shell-to-logger wiring. The existing scanner exits 1 on its
# first counter increment under set -e; this test checks logging up to that point.
for selection in unset empty relative absolute; do
    case_dir="$fixture/$selection"
    mkdir -p "$case_dir/home" "$case_dir/repos" "$case_dir/cwd"
    (
        cd "$case_dir/cwd"
        export HOME="$case_dir/home" REPOS_BASE="$case_dir/repos"
        case "$selection" in
            unset) unset XDG_STATE_HOME ;;
            empty) export XDG_STATE_HOME='' ;;
            relative) export XDG_STATE_HOME='relative-state' ;;
            absolute) export XDG_STATE_HOME="$case_dir/absolute state" ;;
        esac
        bash "$repo_dir/check-language-compliance.sh"
    ) > "$case_dir/stdout" 2> "$case_dir/stderr" && fail 'expected existing scanner exit 1'
    state="$case_dir/home/.local/state/scripts/language-compliance"
    [[ "$selection" != absolute ]] || state="$case_dir/absolute state/scripts/language-compliance"
    [[ -f "$state/$log_name" ]] || fail "missing report for $selection"
    cmp "$case_dir/stdout" "$state/$log_name"
    grep -q '✅ Compliant' "$state/$log_name"
    [[ ! -e "$case_dir/cwd/relative-state" ]] || fail 'used relative XDG state'
    [[ $(stat -c %a "$state") == 700 ]] || fail 'directory permissions'
    [[ $(stat -c %a "$state/$log_name") == 600 ]] || fail 'log permissions'
done

state="$fixture/state/scripts/language-compliance"
(umask 000; run_logger "$state") > "$fixture/stdout"
[[ $(stat -c %a "$state") == 700 ]] || fail 'permissive umask exposed directory'
[[ $(stat -c %a "$state/$log_name") == 600 ]] || fail 'permissive umask exposed log'
printf 'old report longer than new\n' > "$state/$log_name"
chmod 755 "$state"
chmod 644 "$state/$log_name"
run_logger "$state" > "$fixture/stdout"
cmp "$fixture/stdout" "$state/$log_name"
[[ $(cat "$state/$log_name") == report ]] || fail 'did not truncate existing safe log'
[[ $(stat -c %a "$state") == 700 ]] || fail 'did not restrict existing directory'
[[ $(stat -c %a "$state/$log_name") == 600 ]] || fail 'did not restrict existing log'

rm "$state/$log_name"
printf 'untouched\n' > "$fixture/target"
ln -s "$fixture/target" "$state/$log_name"
reject "$state" 'symlink log'
[[ $(cat "$fixture/target") == untouched ]] || fail 'changed symlink target'
rm "$state/$log_name"
ln "$fixture/target" "$state/$log_name"
reject "$state" 'hard-linked log'
[[ $(cat "$fixture/target") == untouched ]] || fail 'changed hard link target'
rm "$state/$log_name"
mkfifo "$state/$log_name"
if timeout 10 bash -c 'printf report | julia --startup-file=no "$1" "$2" "$3"' _ "$logger" "$state" "$log_name"; then
    fail 'accepted FIFO'
else
    [[ $? != 124 ]] || fail 'blocked on FIFO'
fi
rm "$state/$log_name"
mkdir "$state/$log_name"
reject "$state" 'directory log'
rmdir "$state/$log_name"

mv "$state" "$state.saved"
ln -s "$state.saved" "$state"
reject "$state" 'symlink state directory'
rm "$state"
mv "$state.saved" "$state"
mv "$fixture/state/scripts" "$fixture/state/scripts.saved"
ln -s "$fixture/state/scripts.saved" "$fixture/state/scripts"
reject "$state" 'symlink parent directory'
rm "$fixture/state/scripts"
mv "$fixture/state/scripts.saved" "$fixture/state/scripts"

# Optional privilege is only for constructing foreign-owned attack fixtures.
if [[ $(id -u) != 0 ]] && sudo -n true 2>/dev/null; then
    chmod 777 "$state"
    sudo -n chown 0 "$state"
    reject "$state" 'foreign-owned directory'
    [[ $(stat -c %a "$state") == 777 ]] || fail 'changed foreign directory mode'
    sudo -n chown "$(id -u)" "$state"
    printf 'foreign\n' > "$state/$log_name"
    chmod 666 "$state/$log_name"
    sudo -n chown 0 "$state/$log_name"
    reject "$state" 'foreign-owned log'
    [[ $(cat "$state/$log_name") == foreign ]] || fail 'truncated foreign log'
    sudo -n chown "$(id -u)" "$state/$log_name"
else
    echo 'SKIP: foreign ownership fixtures require non-root user with passwordless sudo'
fi

# Once opened, replacing the directory pathname must not redirect later writes.
rm -f "$state/$log_name"
mkfifo "$fixture/input"
julia --startup-file=no "$logger" "$state" "$log_name" < "$fixture/input" > "$fixture/stdout" &
logger_pid=$!
exec 4> "$fixture/input"
printf 'first\n' >&4
for ((attempt=0; attempt<100; attempt++)); do
    [[ -f "$state/$log_name" ]] && [[ $(cat "$state/$log_name") == first ]] && break
    sleep 0.1
done
[[ -f "$state/$log_name" ]] && [[ $(cat "$state/$log_name") == first ]] || fail 'logger not ready'
mv "$state" "$state.saved"
mkdir "$fixture/replacement"
printf 'untouched\n' > "$fixture/replacement/$log_name"
ln -s "$fixture/replacement" "$state"
printf 'second\n' >&4
exec 4>&-
wait "$logger_pid"
[[ $(cat "$fixture/replacement/$log_name") == untouched ]] || fail 'reopened replaced path'
printf 'first\nsecond\n' > "$fixture/expected"
cmp "$fixture/expected" "$state.saved/$log_name"
cmp "$fixture/expected" "$fixture/stdout"

echo 'PASS: compliance state and logging regressions'
