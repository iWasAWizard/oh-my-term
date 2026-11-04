#!/usr/bin/env bash
#
# Starts each installed program with the oh-my-term config and fails if the
# config prints an error. A program that is not installed is skipped. Run it
# after setup.sh. It reads the config from $HOME and writes nothing there.
#
#   OMT_SMOKE_BASH   the bash to test (default: bash on PATH)

set -euo pipefail

repo_root="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
# shellcheck source=lib/install.sh
. "${repo_root}/lib/install.sh"

bash_bin="${OMT_SMOKE_BASH:-bash}"
# What an interactive shell prints when a config line is broken. Complaints about
# having no terminal ("no job control") are expected under CI and do not match.
shell_errors='command not found|no such file|syntax error|parse error|bad substitution|not an identifier|unknown option'
failures=0

pass() {
    printf '  [ok  ] %s\n' "$*"
}

fail() {
    printf '  [FAIL] %s\n' "$*"
    failures=$((failures + 1))
}

skip() {
    printf '  [skip] %s\n' "$*"
}

# smoke_shell NAME BIN: start an interactive shell and exit at once
smoke_shell() {
    local name="$1"
    local bin="$2"
    local out status=0

    out="$("$bin" -i -c 'exit 0' </dev/null 2>&1)" || status=$?
    if [ "$status" -ne 0 ]; then
        fail "${name} exited with status ${status}"
        printf '%s\n' "$out" | head -n 10 | sed 's/^/         /'
    elif printf '%s\n' "$out" | grep -Eiq "$shell_errors"; then
        fail "${name} printed errors while loading the config"
        printf '%s\n' "$out" | grep -Ei "$shell_errors" | head -n 10 | sed 's/^/         /'
    else
        pass "${name} loads the config"
    fi
}

smoke_tmux() {
    local sock="omt-smoke-$$"
    local msgs

    TERM="${TERM:-xterm-256color}" tmux -L "$sock" -f "${HOME}/.tmux.conf" new-session -d
    msgs="$(tmux -L "$sock" show-messages 2>&1)" || true
    tmux -L "$sock" kill-server 2>/dev/null || true
    if printf '%s\n' "$msgs" | grep -Eiq 'error|unknown|invalid|not found'; then
        fail "tmux reported problems in the config"
        printf '%s\n' "$msgs" | head -n 10 | sed 's/^/         /'
    else
        pass "tmux loads the config"
    fi
}

smoke_nvim() {
    local out

    out="$(nvim --headless -c 'qa!' </dev/null 2>&1)" || true
    if [ -n "$out" ]; then
        fail "nvim printed output while loading the config"
        printf '%s\n' "$out" | head -n 10 | sed 's/^/         /'
    else
        pass "nvim loads the config"
    fi
}

printf 'oh-my-term smoke test\n'
if have "$bash_bin"; then
    smoke_shell "bash" "$bash_bin"
else
    skip "bash ($bash_bin) not found"
fi
if have zsh; then smoke_shell "zsh" zsh; else skip "zsh is not installed"; fi
if have tmux; then smoke_tmux; else skip "tmux is not installed"; fi
if have nvim; then smoke_nvim; else skip "nvim is not installed"; fi

[ "$failures" -eq 0 ]
