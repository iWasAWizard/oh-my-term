#!/usr/bin/env bash
#
# The install test CI runs on every platform: install every component into
# $HOME, install again to prove it changes nothing, then run doctor and the
# smoke test. It writes into $HOME, so run it with a throwaway one:
#
#   HOME="$(mktemp -d)" ./scripts/ci-install.sh
#
# Environment variables:
#   OMT_SETUP_BASH   the bash that runs setup.sh (default: bash on PATH).
#                    CI sets /bin/bash on macOS to get bash 3.2.
#   OMT_OFFLINE=1    link only, no downloads (setup.sh reads this itself)

set -euo pipefail

repo_root="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
# shellcheck source=lib/install.sh
. "${repo_root}/lib/install.sh"

bash_bin="${OMT_SETUP_BASH:-bash}"
export OMT_SMOKE_BASH="${OMT_SMOKE_BASH:-$bash_bin}"

setup() {
    "$bash_bin" "${repo_root}/setup.sh" --no-chsh "$@"
}

# Backups are named <file>.bak.<timestamp>. A second install must not add any.
count_backups() {
    find "$HOME" -maxdepth 4 -name '*.bak.*' -not -path "${HOME}/Library/*" 2>/dev/null | wc -l | tr -d ' '
}

printf 'bash for setup.sh: %s\n' "$("$bash_bin" -c 'printf %s "$BASH_VERSION"')"

log "First install"
# pi is linked only. Installing omp pulls in bun or a Homebrew tap, which is not what this tests.
setup bash zsh vim nvim screen tmux git ssh gdb cli tools
setup --offline pi
before="$(count_backups)"

log "Second install"
setup bash zsh vim nvim screen tmux git ssh gdb cli tools
setup --offline pi
after="$(count_backups)"
if [ "$before" != "$after" ]; then
    die "the second install created $((after - before)) backup file(s), so it is not idempotent"
fi

log "Doctor"
setup doctor

log "Smoke test"
"${repo_root}/scripts/smoke.sh"
