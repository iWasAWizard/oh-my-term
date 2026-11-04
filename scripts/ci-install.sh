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
#   OMT_SKIP_TOOLS   outside CI this defaults to 1, because the tools component
#                    installs starship and fzf with Homebrew, which is not
#                    limited to $HOME. Set it to 0 to test that too.

set -euo pipefail

repo_root="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
# shellcheck source=lib/install.sh
. "${repo_root}/lib/install.sh"

# setup.sh honors these, and a value left over in your shell would send the test
# to your real Oh My Zsh, Neovim and omp directories instead of $HOME.
unset ZSH ZSH_CUSTOM XDG_CONFIG_HOME XDG_DATA_HOME OMP_AGENT_DIR

real_home="$(eval "printf '%s' ~$(id -un)")"
if [ -z "${CI:-}" ] && [ "$HOME" = "$real_home" ]; then
    die "this would install into your real home. Use a throwaway one: HOME=\"\$(mktemp -d)\" $0"
fi
if [ -z "${CI:-}" ]; then
    export OMT_SKIP_TOOLS="${OMT_SKIP_TOOLS:-1}"
fi

bash_bin="${OMT_SETUP_BASH:-bash}"
export OMT_SMOKE_BASH="${OMT_SMOKE_BASH:-$bash_bin}"

setup() {
    "$bash_bin" "${repo_root}/setup.sh" --no-chsh "$@"
}

# Backups are named <file>.bak.<timestamp>. A second install must not add any.
count_backups() {
    find "$HOME" -maxdepth 4 -name '*.bak.*' -not -path "${HOME}/Library/*" 2>/dev/null | wc -l | tr -d ' '
}

# shellcheck disable=SC2016 # $BASH_VERSION must expand in the bash being tested, not here
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
